extends RefCounted

class_name PlayerProfile

## The on-disk profile schema. Derived values such as level are intentionally
## calculated from total_exp by the caller and are not duplicated here.
const CURRENT_SCHEMA_VERSION: int = 1

var schema_version: int = CURRENT_SCHEMA_VERSION
var characters: Dictionary = {}
var stage_progress: Dictionary = {}
var items: Dictionary = {}
var gacha_state: Dictionary = {}
var last_committed_run_id: String = ""


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
	gacha_state = _normalize_dictionary(source.get("gacha_state", {}))
	last_committed_run_id = str(source.get("last_committed_run_id", ""))


func to_dict() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"characters": characters.duplicate(true),
		"stage_progress": stage_progress.duplicate(true),
		"items": items.duplicate(true),
		"gacha_state": gacha_state.duplicate(true),
		"last_committed_run_id": last_committed_run_id,
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
	gacha_state = other.gacha_state.duplicate(true)
	last_committed_run_id = other.last_committed_run_id


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
	entry["shards"] = _coerce_non_negative_int(entry.get("shards", 0))
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
	entry["shards"] = _coerce_non_negative_int(entry.get("shards", 0))
	characters[key] = entry
	return new_exp


func add_character_shards(character_id: String, amount: int) -> int:
	var key := character_id.strip_edges()
	if key.is_empty() or amount <= 0:
		return 0
	ensure_character(key)
	var entry = characters.get(key, {}).duplicate(true)
	entry["shards"] = _coerce_non_negative_int(entry.get("shards", 0)) + amount
	characters[key] = entry
	return entry["shards"]


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

	if session.has_method("get_pending_unlocks"):
		var raw_unlocks = session.get_pending_unlocks()
		if raw_unlocks is Array:
			for value in raw_unlocks:
				var character_id := str(value).strip_edges()
				if not character_id.is_empty():
					ensure_character(character_id)

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
		normalized["shards"] = _coerce_non_negative_int(normalized.get("shards", 0))
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
