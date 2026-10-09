extends RefCounted

class_name BattleSession

## BattleSession is deliberately independent from GameManager. It is the
## transaction-like, in-memory ledger for one stage attempt. Nothing in this
## object is permanent until SaveManager commits a victorious session.
const CURRENT_SCHEMA_VERSION: int = 1
const STATUS_IN_PROGRESS: String = "in_progress"
const STATUS_VICTORY: String = "victory"
const STATUS_DEFEAT: String = "defeat"
const STATUS_ABANDONED: String = "abandoned"
const STATUS_COMMITTED: String = "committed"
const STATUS_DISCARDED: String = "discarded"

var schema_version: int = CURRENT_SCHEMA_VERSION
var run_id: String = ""
var stage_id: String = ""
var deployed_character_ids: Array[String] = []
var pending_xp_by_character: Dictionary = {}
var pending_loot: Dictionary = {}
var pending_unlocks: Array[String] = []
## 首通信物（v0.13）：通关后写入存档 relics。
var pending_relics: Array[String] = []
## 科技点（v0.14.1）：通关后写入存档 tech_points（首通+2/重复+1，按难度材料倍率）。
var pending_tech_points: int = 0
## 经验池注入基数（✅ 0.8.15 / NUMBERS 10.14）：本局实际发出的击杀经验总量
## （GameManager 按难度 reward_mult 结算后的值逐笔累计；不含落后补正增量）。
var kill_xp_base: int = 0
## 经验池注入量（✅ 0.8.15）：胜利结算时按 finalize_exp_pool_injection() 定值，
## 随战局提交写入存档 exp_pool；失败 / 放弃 / 崩溃作废。
var pending_exp_pool: int = 0
## 军功暂存（✅ 0.8.16 / NUMBERS 10.15）：击杀结算按难度 merit_mult **精确累计**（困难 ×1.5），
## 读取 / 写档时 roundi 取整——全章 1242 → 困难 1863（若逐笔取整则被放大到 2228，1~3 的小整数
## 逐笔取整额外偏 +19.6%，与 NUMBERS 10.15「×1.5」难度杠杆不符）；
## 胜利结算由 PlayerProfile.apply_battle_session 写档；失败 / 放弃 / 崩溃清零不带出。
var pending_merit_exact: float = 0.0
var result: Dictionary = {}
var status: String = STATUS_IN_PROGRESS
var started_at_unix: int = 0
var finished_at_unix: int = 0


func _init(
	initial_stage_id: String = "",
	initial_deployed_character_ids: Array = [],
	initial_run_id: String = ""
) -> void:
	run_id = initial_run_id.strip_edges()
	if run_id.is_empty():
		run_id = _generate_run_id()
	stage_id = initial_stage_id.strip_edges()
	deployed_character_ids = _normalize_string_array(initial_deployed_character_ids)
	started_at_unix = int(Time.get_unix_time_from_system())


static func create(
	initial_stage_id: String = "",
	initial_deployed_character_ids: Array = []
) -> BattleSession:
	return BattleSession.new(initial_stage_id, initial_deployed_character_ids)


static func from_dict(data: Dictionary) -> BattleSession:
	var session := BattleSession.new()
	session.load_dict(data)
	return session


func load_dict(data: Dictionary) -> void:
	if not data is Dictionary:
		return
	schema_version = _coerce_non_negative_int(data.get("schema_version", CURRENT_SCHEMA_VERSION))
	if schema_version <= 0:
		schema_version = CURRENT_SCHEMA_VERSION
	run_id = str(data.get("run_id", "")).strip_edges()
	if run_id.is_empty():
		run_id = _generate_run_id()
	stage_id = str(data.get("stage_id", "")).strip_edges()
	deployed_character_ids = _normalize_string_array(data.get("deployed_character_ids", []))
	pending_xp_by_character = _normalize_amount_dictionary(data.get("pending_xp_by_character", {}))
	pending_loot = _normalize_amount_dictionary(data.get("pending_loot", {}))
	pending_unlocks = _normalize_string_array(data.get("pending_unlocks", []))
	pending_relics = _normalize_string_array(data.get("pending_relics", []))
	pending_tech_points = _coerce_non_negative_int(data.get("pending_tech_points", 0))
	kill_xp_base = _coerce_non_negative_int(data.get("kill_xp_base", 0))
	pending_exp_pool = _coerce_non_negative_int(data.get("pending_exp_pool", 0))
	pending_merit_exact = float(_coerce_non_negative_int(data.get("pending_merit", 0)))
	result = data.get("result", {}).duplicate(true) if data.get("result", {}) is Dictionary else {}
	status = _normalize_status(str(data.get("status", STATUS_IN_PROGRESS)))
	started_at_unix = _coerce_non_negative_int(data.get("started_at_unix", 0))
	finished_at_unix = _coerce_non_negative_int(data.get("finished_at_unix", 0))


func to_dict() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"run_id": run_id,
		"stage_id": stage_id,
		"deployed_character_ids": deployed_character_ids.duplicate(),
		"pending_xp_by_character": pending_xp_by_character.duplicate(true),
		"pending_loot": pending_loot.duplicate(true),
		"pending_unlocks": pending_unlocks.duplicate(),
		"pending_relics": pending_relics.duplicate(),
		"pending_tech_points": pending_tech_points,
		"kill_xp_base": kill_xp_base,
		"pending_exp_pool": pending_exp_pool,
		"pending_merit": get_pending_merit(),
		"result": result.duplicate(true),
		"status": status,
		"started_at_unix": started_at_unix,
		"finished_at_unix": finished_at_unix,
	}


func get_run_id() -> String:
	return run_id


func get_stage_id() -> String:
	return stage_id


func get_deployed_character_ids() -> Array[String]:
	return deployed_character_ids.duplicate()


func get_pending_xp_by_character() -> Dictionary:
	return pending_xp_by_character.duplicate(true)


func get_pending_loot() -> Dictionary:
	return pending_loot.duplicate(true)


func get_pending_unlocks() -> Array[String]:
	return pending_unlocks.duplicate()


func get_result() -> Dictionary:
	return result.duplicate(true)


func get_status() -> String:
	return status


func is_in_progress() -> bool:
	return status == STATUS_IN_PROGRESS

## 结算窗口（v0.21.1）：进行中或已胜利未提交的战局仍可累计战利品，
## 修复“先 mark_victory 再收集奖励”的顺序依赖。
func can_accumulate_rewards() -> bool:
	return status == STATUS_IN_PROGRESS or status == STATUS_VICTORY


func is_victory() -> bool:
	return status == STATUS_VICTORY or status == STATUS_COMMITTED


func is_defeat() -> bool:
	return status == STATUS_DEFEAT or status == STATUS_DISCARDED


func is_terminal() -> bool:
	return status != STATUS_IN_PROGRESS


func can_commit() -> bool:
	return status == STATUS_VICTORY


func add_xp(character_id: String, amount: int) -> int:
	if not can_accumulate_rewards() or amount <= 0:
		return _coerce_non_negative_int(pending_xp_by_character.get(character_id.strip_edges(), 0))
	var key := character_id.strip_edges()
	if key.is_empty():
		return 0
	var next_amount := _coerce_non_negative_int(pending_xp_by_character.get(key, 0)) + amount
	pending_xp_by_character[key] = next_amount
	return next_amount


func add_character_xp(character_id: String, amount: int) -> int:
	return add_xp(character_id, amount)


func add_participation_xp(character_ids: Array, amount: int) -> void:
	if amount <= 0:
		return
	for character_id in character_ids:
		add_xp(str(character_id), amount)


func add_loot(item_id: String, amount: int) -> int:
	if not can_accumulate_rewards() or amount <= 0:
		return _coerce_non_negative_int(pending_loot.get(item_id.strip_edges(), 0))
	var key := item_id.strip_edges()
	if key.is_empty():
		return 0
	var next_amount := _coerce_non_negative_int(pending_loot.get(key, 0)) + amount
	pending_loot[key] = next_amount
	return next_amount


func add_drop(item_id: String, amount: int) -> int:
	return add_loot(item_id, amount)


## 首通信物授予（去重）。
func add_relic(relic_id: String) -> bool:
	if not can_accumulate_rewards():
		return false
	var key := relic_id.strip_edges()
	if key.is_empty() or pending_relics.has(key):
		return false
	pending_relics.append(key)
	return true


func get_pending_relics() -> Array[String]:
	return pending_relics.duplicate()


## 击杀经验基数累计（✅ 0.8.15）：GameManager.enemy_died 按难度倍率缩放后逐笔上报，
## 作为经验池注入公式的「本局击杀经验总量」项。
func add_kill_xp_base(amount: int) -> int:
	if not can_accumulate_rewards() or amount <= 0:
		return kill_xp_base
	kill_xp_base += amount
	return kill_xp_base


## 经验池注入定值（✅ 0.8.15 / NUMBERS 10.14）：胜利结算窗口内调用一次——
## 注入 = roundi((击杀经验总量 + participant_xp × 出战人数) × 50%)，四舍五入取整；
## 不扣减武将自身所得（纯增量）；非胜利窗口调用返回当前值不做修改。
func finalize_exp_pool_injection(participant_xp: int) -> int:
	if not can_accumulate_rewards():
		return pending_exp_pool
	var per_member := _coerce_non_negative_int(participant_xp)
	var headcount := deployed_character_ids.size()
	var total := kill_xp_base + per_member * headcount
	pending_exp_pool = roundi(total * 0.5)
	return pending_exp_pool


func get_pending_exp_pool() -> int:
	return pending_exp_pool


## 军功累计（✅ 0.8.16 / NUMBERS 10.15）：GameManager.enemy_died 按难度 merit_mult 缩放后逐笔上报
## （困难 ×1.5、与击杀经验 ×1.6 分账）；内部累计精确值、读取时 roundi 取整（见 pending_merit_exact 注释）。
func add_merit_scaled(base_amount: int, multiplier: float) -> int:
	if not can_accumulate_rewards() or base_amount <= 0:
		return get_pending_merit()
	pending_merit_exact += float(base_amount) * maxf(multiplier, 0.0)
	return get_pending_merit()


## 固定值加军功（不吃难度倍率；用例 / 调试入口）。
func add_merit(amount: int) -> int:
	return add_merit_scaled(amount, 1.0)


func get_pending_merit() -> int:
	return roundi(pending_merit_exact)


## 科技点暂存（GDD modules/NUMBERS.md 10.7）：通关后随战局提交写档。
func add_tech_points(amount: int) -> int:
	if not can_accumulate_rewards() or amount <= 0:
		return pending_tech_points
	pending_tech_points += amount
	return pending_tech_points


func get_pending_tech_points() -> int:
	return pending_tech_points


func add_unlock(character_id: String) -> bool:
	if not can_accumulate_rewards():
		return false
	var key := character_id.strip_edges()
	if key.is_empty() or pending_unlocks.has(key):
		return false
	pending_unlocks.append(key)
	return true


func mark_victory(victory_result: Dictionary = {}) -> bool:
	if status == STATUS_VICTORY or status == STATUS_COMMITTED:
		return true
	if not is_in_progress():
		return false
	status = STATUS_VICTORY
	result = victory_result.duplicate(true)
	finished_at_unix = int(Time.get_unix_time_from_system())
	return true


func mark_defeat(defeat_result: Dictionary = {}) -> bool:
	if status == STATUS_DEFEAT or status == STATUS_DISCARDED:
		return true
	if not is_in_progress():
		return false
	status = STATUS_DEFEAT
	result = defeat_result.duplicate(true)
	finished_at_unix = int(Time.get_unix_time_from_system())
	return true


func abandon() -> bool:
	if status == STATUS_ABANDONED or status == STATUS_DISCARDED:
		return true
	if not is_in_progress():
		return false
	status = STATUS_ABANDONED
	finished_at_unix = int(Time.get_unix_time_from_system())
	return true


func mark_committed() -> bool:
	if status == STATUS_COMMITTED:
		return true
	if status != STATUS_VICTORY:
		return false
	status = STATUS_COMMITTED
	return true


func mark_discarded() -> bool:
	if status == STATUS_DISCARDED:
		return true
	if status == STATUS_COMMITTED:
		return false
	status = STATUS_DISCARDED
	pending_xp_by_character.clear()
	pending_loot.clear()
	pending_unlocks.clear()
	pending_relics.clear()
	pending_tech_points = 0
	kill_xp_base = 0
	pending_exp_pool = 0
	pending_merit_exact = 0.0
	return true


func clear_pending_rewards() -> void:
	pending_xp_by_character.clear()
	pending_loot.clear()
	pending_unlocks.clear()
	pending_relics.clear()
	pending_tech_points = 0
	kill_xp_base = 0
	pending_exp_pool = 0
	pending_merit_exact = 0.0


static func _generate_run_id() -> String:
	return "run_%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]


func _normalize_status(value: String) -> String:
	match value:
		STATUS_IN_PROGRESS, STATUS_VICTORY, STATUS_DEFEAT, STATUS_ABANDONED, STATUS_COMMITTED, STATUS_DISCARDED:
			return value
		_:
			return STATUS_IN_PROGRESS


func _normalize_string_array(value) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item).strip_edges()
			if not text.is_empty() and not output.has(text):
				output.append(text)
	return output


func _normalize_amount_dictionary(value) -> Dictionary:
	var output: Dictionary = {}
	if not value is Dictionary:
		return output
	for raw_key in value.keys():
		var key := str(raw_key).strip_edges()
		var amount := _coerce_non_negative_int(value[raw_key])
		if not key.is_empty() and amount > 0:
			output[key] = amount
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

