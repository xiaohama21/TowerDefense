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


func is_victory() -> bool:
	return status == STATUS_VICTORY or status == STATUS_COMMITTED


func is_defeat() -> bool:
	return status == STATUS_DEFEAT or status == STATUS_DISCARDED


func is_terminal() -> bool:
	return status != STATUS_IN_PROGRESS


func can_commit() -> bool:
	return status == STATUS_VICTORY


func add_xp(character_id: String, amount: int) -> int:
	if not is_in_progress() or amount <= 0:
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
	if not is_in_progress() or amount <= 0:
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
	if not is_in_progress():
		return false
	var key := relic_id.strip_edges()
	if key.is_empty() or pending_relics.has(key):
		return false
	pending_relics.append(key)
	return true


func get_pending_relics() -> Array[String]:
	return pending_relics.duplicate()


func add_unlock(character_id: String) -> bool:
	if not is_in_progress():
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
	return true


func clear_pending_rewards() -> void:
	pending_xp_by_character.clear()
	pending_loot.clear()
	pending_unlocks.clear()
	pending_relics.clear()


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
