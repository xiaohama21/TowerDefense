extends RefCounted

class_name PlayerProfile

## The on-disk profile schema. Derived values such as level are intentionally
## calculated from total_exp by the caller and are not duplicated here.
const CURRENT_SCHEMA_VERSION: int = 5
## v2（阶段 8·提交 6，职业级转职树落地）：旧档角色绑定转职路径作废，
## 统一按职业级转职树重新转职——加载迁移时清空所有 promotion_path（v0.28 拍板）。
## v3（阶段 8·提交 8 延伸·v0.33.1）：新增出战编队持久记忆 squad_character_ids / squad_relic_ids——
## 「确认出战」写入玩家档案，再次出征自动预填（旧档迁移为空数组，不预填）。
## v4（阶段 8·提交 14 / 0.8.14.0 信物重构，SAVE_DATA 8）：`characters[id].shards` 碎片字段删除；
## 信物双槽化——旧 `relic` 迁移为 `relic_exclusive`（专属槽占位、不参与计算），
## 生效位改 `relic_optional`（可选槽 = Boss 签名信物）。
## v5（阶段 8·提交 15 / 0.8.15.0 经验池重构，SAVE_DATA 8）：新增 `exp_pool`（经验池余额：
## 胜利结算额外注入、池内自由分配写入武将 total_exp；旧档迁移补 0、幂等）；
## `items.exp_scroll`（练兵令）残留数量随本次迁移清理（道具整体删除）。

var schema_version: int = CURRENT_SCHEMA_VERSION
var characters: Dictionary = {}
var stage_progress: Dictionary = {}
var items: Dictionary = {}
var relics: Array[String] = []
var gacha_state: Dictionary = {}
var tech_points: int = 0
var tech_unlocks: Array[String] = []
## 经验池余额（✅ 0.8.15 / NUMBERS 10.14）：只由胜利结算注入，不产出金币 / 材料 / 科技点。
var exp_pool: int = 0
var last_committed_run_id: String = ""
var squad_character_ids: Array[String] = []
var squad_relic_ids: Array[String] = []


func _init(initial_data: Dictionary = {}) -> void:
	if not initial_data.is_empty():
		load_dict(initial_data)


static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.load_dict(data)
	return profile


func load_dict(data: Dictionary) -> void:
	var source := data.duplicate(true)
	schema_version = _coerce_non_negative_int(source.get("schema_version", CURRENT_SCHEMA_VERSION))
	if schema_version <= 0:
		# SaveManager performs explicit migrations. Treating an omitted version as
		# the current in-memory shape keeps this class useful on its own as well.
		schema_version = CURRENT_SCHEMA_VERSION

	characters = _normalize_characters(source.get("characters", {}))
	stage_progress = _normalize_dictionary(source.get("stage_progress", {}))
	items = _normalize_dictionary(source.get("items", {}))
	# v5（0.8.15.0 防御性）：练兵令整体删除——旧档若残留（正式迁移在 SaveManager）就地清理。
	items.erase("exp_scroll")
	relics = _normalize_string_array(source.get("relics", []))
	tech_points = _coerce_non_negative_int(source.get("tech_points", 0))
	tech_unlocks = _normalize_string_array(source.get("tech_unlocks", []))
	exp_pool = _coerce_non_negative_int(source.get("exp_pool", 0))
	gacha_state = _normalize_dictionary(source.get("gacha_state", {}))
	last_committed_run_id = str(source.get("last_committed_run_id", ""))
	squad_character_ids = _normalize_string_array(source.get("squad_character_ids", []))
	squad_relic_ids = _normalize_string_array(source.get("squad_relic_ids", []))


func to_dict() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"characters": characters.duplicate(true),
		"stage_progress": stage_progress.duplicate(true),
		"items": items.duplicate(true),
		"relics": relics.duplicate(),
		"tech_points": tech_points,
		"tech_unlocks": tech_unlocks.duplicate(),
		"exp_pool": exp_pool,
		"gacha_state": gacha_state.duplicate(true),
		"last_committed_run_id": last_committed_run_id,
		"squad_character_ids": squad_character_ids.duplicate(),
		"squad_relic_ids": squad_relic_ids.duplicate(),
	}


func duplicate_profile() -> PlayerProfile:
	return PlayerProfile.from_dict(to_dict())


func copy_from(other: PlayerProfile) -> void:
	if other == null:
		return
	schema_version = other.schema_version
	characters = other.characters.duplicate(true)
	stage_progress = other.stage_progress.duplicate(true)
	items = other.items.duplicate(true)
	relics = other.relics.duplicate()
	tech_points = other.tech_points
	tech_unlocks = other.tech_unlocks.duplicate()
	exp_pool = other.exp_pool
	gacha_state = other.gacha_state.duplicate(true)
	last_committed_run_id = other.last_committed_run_id
	squad_character_ids = other.squad_character_ids.duplicate()
	squad_relic_ids = other.squad_relic_ids.duplicate()


func has_character(character_id: String) -> bool:
	return characters.has(character_id.strip_edges())


func get_owned_character_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in characters.keys():
		var character_id := str(key)
		if not character_id.is_empty():
			ids.append(character_id)
	ids.sort()
	return ids


func get_character(character_id: String) -> Dictionary:
	var key := character_id.strip_edges()
	var value = characters.get(key, {})
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func get_character_exp(character_id: String) -> int:
	var entry := get_character(character_id)
	return _coerce_non_negative_int(entry.get("total_exp", 0))


func unlock_character(character_id: String, initial_data: Dictionary = {}) -> bool:
	var key := character_id.strip_edges()
	if key.is_empty() or characters.has(key):
		return false
	var entry := initial_data.duplicate(true)
	entry["total_exp"] = _coerce_non_negative_int(entry.get("total_exp", 0))
	entry["promotion_path"] = _normalize_string_array(entry.get("promotion_path", []))
	entry["stars"] = _coerce_non_negative_int(entry.get("stars", 0))
	entry["relic_exclusive"] = str(entry.get("relic_exclusive", ""))
	entry["relic_optional"] = str(entry.get("relic_optional", ""))
	characters[key] = entry
	return true


func ensure_character(character_id: String) -> bool:
	var key := character_id.strip_edges()
	if key.is_empty():
		return false
	if characters.has(key):
		return true
	return unlock_character(key)


func add_character_exp(character_id: String, amount: int) -> int:
	var key := character_id.strip_edges()
	if key.is_empty() or amount <= 0:
		return get_character_exp(key)
	ensure_character(key)
	var entry = characters.get(key, {})
	if not entry is Dictionary:
		entry = {}
	entry = entry.duplicate(true)
	var new_exp := _coerce_non_negative_int(entry.get("total_exp", 0)) + amount
	entry["total_exp"] = new_exp
	entry["promotion_path"] = _normalize_string_array(entry.get("promotion_path", []))
	entry["stars"] = _coerce_non_negative_int(entry.get("stars", 0))
	entry["relic_exclusive"] = str(entry.get("relic_exclusive", ""))
	entry["relic_optional"] = str(entry.get("relic_optional", ""))
	characters[key] = entry
	return new_exp


## 武将当前星级（升星系统，GDD 4.8；升星自 v0.30.0 暂时移除，字段保留）。
func get_character_stars(character_id: String) -> int:
	return _coerce_non_negative_int(get_character(character_id).get("stars", 0))


## 武将某槽位已装配的信物 ID（GDD 4.8 双槽）：
## "optional" = 可选槽（生效位，Boss 签名信物）/ "exclusive" = 专属槽（本版锁住占位）。
func get_character_relic_id(character_id: String, slot: String = "optional") -> String:
	var key := "relic_exclusive" if slot == "exclusive" else "relic_optional"
	return str(get_character(character_id).get(key, ""))


## 信物持有/装备（GDD 4.8）。
func add_relic(relic_id: String) -> bool:
	var key := relic_id.strip_edges()
	if key.is_empty() or relics.has(key):
		return false
	relics.append(key)
	return true


func has_relic(relic_id: String) -> bool:
	return relics.has(relic_id.strip_edges())


## 装备可选信物槽（characters[id].relic_optional；仅限已持有的信物，空串为卸下）。
func set_character_relic(character_id: String, relic_id: String) -> bool:
	return _set_character_relic_slot(character_id, "optional", relic_id)


## 装配专属信物槽（characters[id].relic_exclusive，占位存储；本版不参与计算，无 UI 入口）。
func set_character_exclusive_relic(character_id: String, relic_id: String) -> bool:
	return _set_character_relic_slot(character_id, "exclusive", relic_id)


func _set_character_relic_slot(character_id: String, slot: String, relic_id: String) -> bool:
	var key := character_id.strip_edges()
	if key.is_empty():
		return false
	if not relic_id.strip_edges().is_empty() and not has_relic(relic_id):
		return false
	ensure_character(key)
	var entry = characters.get(key, {})
	if not entry is Dictionary:
		return false
	entry = entry.duplicate(true)
	entry["relic_exclusive" if slot == "exclusive" else "relic_optional"] = relic_id.strip_edges()
	characters[key] = entry
	return true


## 经验池（✅ 0.8.15 / CHARACTERS 4.4 / NUMBERS 10.14）——
## 余额读取。
func get_exp_pool() -> int:
	return exp_pool


## 注入经验池（胜利结算纯增量；数值由 BattleSession.finalize_exp_pool_injection 定值）。
func add_exp_pool(amount: int) -> int:
	exp_pool += maxi(amount, 0)
	return exp_pool


## 该武将是否可分配经验池（仅限已拥有、未满级；满级不可分配 —— CHARACTERS 4.4）。
func can_allocate_exp_pool(character_id: String) -> bool:
	var key := character_id.strip_edges()
	if key.is_empty() or not characters.has(key):
		return false
	return LevelCurve.level_from_total_exp(get_character_exp(key)) < LevelCurve.max_level()


## 分配经验池（不可逆）：余额不足 / 未拥有 / 满级一律拒绝（返回 false 且不改动任何状态），
## 成功即扣池并写入 characters[id].total_exp。写档由调用方（ProfileStore.save_profile）负责。
func allocate_exp_pool(character_id: String, amount: int) -> bool:
	var key := character_id.strip_edges()
	if amount <= 0 or exp_pool < amount:
		return false
	if not can_allocate_exp_pool(key):
		return false
	exp_pool -= amount
	add_character_exp(key, amount)
	return true


## 「直接升级」消耗（✅ 0.8.15）：升级到下一级所需经验差额；未拥有 / 已满级返回 0。
func exp_pool_level_up_cost(character_id: String) -> int:
	var key := character_id.strip_edges()
	if not can_allocate_exp_pool(key):
		return 0
	var total := get_character_exp(key)
	var level := LevelCurve.level_from_total_exp(total)
	return maxi(LevelCurve.exp_total_for_level(level + 1) - total, 0)


## 经验池「直接升级」（+1 级）：消耗 = 升级到下一级所需差额；余额不足 / 满级返回 false。
func level_up_with_exp_pool(character_id: String) -> bool:
	var cost := exp_pool_level_up_cost(character_id)
	return cost > 0 and allocate_exp_pool(character_id, cost)


## 科技点（阶段 4）：通关获取，科技树消费。
func add_tech_points(amount: int) -> void:
	tech_points += maxi(amount, 0)


func has_tech(tech_id: String) -> bool:
	return tech_unlocks.has(tech_id.strip_edges())


func unlock_tech(tech_id: String, cost: int) -> bool:
	var key := tech_id.strip_edges()
	if key.is_empty() or has_tech(key) or tech_points < cost:
		return false
	tech_points -= cost
	tech_unlocks.append(key)
	return true


## 求贤计数器（gacha_state 持久化）。
func get_gacha_pity() -> int:
	return _coerce_non_negative_int(gacha_state.get("pity_counter", 0))


func set_gacha_pity(value: int) -> void:
	gacha_state["pity_counter"] = maxi(value, 0)


func get_gacha_total() -> int:
	return _coerce_non_negative_int(gacha_state.get("total_pulls", 0))


func set_gacha_total(value: int) -> void:
	gacha_state["total_pulls"] = maxi(value, 0)


func set_promotion_path(character_id: String, promotion_path: Array) -> bool:
	var key := character_id.strip_edges()
	if key.is_empty():
		return false
	ensure_character(key)
	var entry = characters.get(key, {}).duplicate(true)
	entry["promotion_path"] = _normalize_string_array(promotion_path)
	characters[key] = entry
	return true


func add_item(item_id: String, amount: int) -> int:
	var key := item_id.strip_edges()
	if key.is_empty() or amount <= 0:
		return _coerce_non_negative_int(items.get(key, 0))
	var next_amount := _coerce_non_negative_int(items.get(key, 0)) + amount
	items[key] = next_amount
	return next_amount


## 消耗道具（转职扣料等）。数量不足时返回 false 且不做任何修改。
func spend_item(item_id: String, amount: int) -> bool:
	var key := item_id.strip_edges()
	if key.is_empty() or amount <= 0:
		return false
	var current := _coerce_non_negative_int(items.get(key, 0))
	if current < amount:
		return false
	items[key] = current - amount
	return true


func mark_stage_completed(stage_id: String, result: Dictionary = {}) -> bool:
	var key := stage_id.strip_edges()
	if key.is_empty():
		return false
	var previous = stage_progress.get(key, {})
	var entry: Dictionary
	if previous is Dictionary:
		entry = previous.duplicate(true)
	else:
		entry = {}
	entry["completed"] = true
	entry["status"] = "completed"
	if not result.is_empty():
		entry["last_result"] = result.duplicate(true)
	# 难度通关记录（GDD modules/NUMBERS.md 10.7，v0.14.1）：按难度分键，
	# 困难需标准通关解锁（GameFlow.is_difficulty_unlocked 读取）。
	if result.has("difficulty"):
		var difficulty_key := str(result.get("difficulty", "")).strip_edges()
		if not difficulty_key.is_empty():
			var difficulties: Dictionary = entry.get("difficulties", {}) if entry.get("difficulties", {}) is Dictionary else {}
			difficulties = difficulties.duplicate(true)
			difficulties[difficulty_key] = true
			entry["difficulties"] = difficulties
	stage_progress[key] = entry
	return true


## Apply a victorious BattleSession to this profile. The method performs only
## in-memory work; SaveManager wraps it in a save transaction.
func apply_battle_session(session: Object) -> bool:
	if session == null or not session.has_method("is_victory"):
		return false
	if not session.is_victory():
		return false
	if not session.has_method("get_run_id"):
		return false
	var run_id := str(session.get_run_id())
	if run_id.is_empty() or run_id == last_committed_run_id:
		return false

	var pending_xp: Dictionary = {}
	if session.has_method("get_pending_xp_by_character"):
		var raw_xp = session.get_pending_xp_by_character()
		if raw_xp is Dictionary:
			pending_xp = raw_xp
	for character_key in pending_xp.keys():
		var character_id := str(character_key).strip_edges()
		var amount := _coerce_non_negative_int(pending_xp[character_key])
		if not character_id.is_empty() and amount > 0:
			add_character_exp(character_id, amount)

	var pending_loot: Dictionary = {}
	if session.has_method("get_pending_loot"):
		var raw_loot = session.get_pending_loot()
		if raw_loot is Dictionary:
			pending_loot = raw_loot
	for item_key in pending_loot.keys():
		var item_id := str(item_key).strip_edges()
		var amount := _coerce_non_negative_int(pending_loot[item_key])
		if not item_id.is_empty() and amount > 0:
			add_item(item_id, amount)

	# 经验池注入（✅ 0.8.15）：胜利结算定值，纯增量写档（失败 / 放弃 / 崩溃不进此路径）。
	if session.has_method("get_pending_exp_pool"):
		var pending_pool: int = _coerce_non_negative_int(session.get_pending_exp_pool())
		if pending_pool > 0:
			add_exp_pool(pending_pool)

	# 科技点（GDD modules/NUMBERS.md 10.7，v0.14.1）：随战局提交写档。
	if session.has_method("get_pending_tech_points"):
		var pending_tech: int = _coerce_non_negative_int(session.get_pending_tech_points())
		if pending_tech > 0:
			tech_points += pending_tech

	if session.has_method("get_pending_unlocks"):
		var raw_unlocks = session.get_pending_unlocks()
		if raw_unlocks is Array:
			for value in raw_unlocks:
				var character_id := str(value).strip_edges()
				if not character_id.is_empty():
					ensure_character(character_id)

	if session.has_method("get_pending_relics"):
		var pending_relics = session.get_pending_relics()
		if pending_relics is Array:
			for relic_id in pending_relics:
				add_relic(str(relic_id))

	if session.has_method("get_stage_id"):
		var stage_id := str(session.get_stage_id()).strip_edges()
		if not stage_id.is_empty():
			var result: Dictionary = {}
			if session.has_method("get_result"):
				var raw_result = session.get_result()
				if raw_result is Dictionary:
					result = raw_result
			mark_stage_completed(stage_id, result)

	last_committed_run_id = run_id
	schema_version = CURRENT_SCHEMA_VERSION
	return true


func _normalize_characters(value) -> Dictionary:
	var output: Dictionary = {}
	if not value is Dictionary:
		return output
	for raw_key in value.keys():
		var character_id := str(raw_key).strip_edges()
		if character_id.is_empty():
			continue
		var entry = value[raw_key]
		var normalized: Dictionary
		if entry is Dictionary:
			normalized = entry.duplicate(true)
		else:
			normalized = {}
		normalized["total_exp"] = _coerce_non_negative_int(normalized.get("total_exp", 0))
		normalized["promotion_path"] = _normalize_string_array(normalized.get("promotion_path", []))
		normalized["stars"] = _coerce_non_negative_int(normalized.get("stars", 0))
		# v4（0.8.14）：碎片字段删除；旧 relic 键就地迁移为专属槽占位（防御性，正式迁移在 SaveManager）。
		normalized.erase("shards")
		var legacy_relic := str(normalized.get("relic", ""))
		normalized.erase("relic")
		if not normalized.has("relic_exclusive"):
			normalized["relic_exclusive"] = legacy_relic
		normalized["relic_exclusive"] = str(normalized.get("relic_exclusive", ""))
		normalized["relic_optional"] = str(normalized.get("relic_optional", ""))
		output[character_id] = normalized
	return output


func _normalize_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _normalize_string_array(value) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if not text.is_empty() and not output.has(text):
				output.append(text)
	return output


func _coerce_non_negative_int(value) -> int:
	var number := 0
	match typeof(value):
		TYPE_INT:
			number = value
		TYPE_FLOAT:
			number = int(value)
		TYPE_STRING:
			number = int(value) if str(value).is_valid_int() else 0
		_:
			number = 0
	return maxi(number, 0)

