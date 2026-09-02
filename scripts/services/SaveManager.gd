extends Node

class_name SaveManager

signal profile_loaded(profile: PlayerProfile, source: String)
signal profile_saved(profile: PlayerProfile)
signal profile_recovered(source: String)
signal save_failed(reason: String)

const PROFILE_PATH: String = "user://profile.json"
const BACKUP_PATH: String = "user://profile.json.bak"
const TEMP_PATH: String = "user://profile.json.tmp"

const LOAD_SOURCE_PRIMARY: String = "primary"
const LOAD_SOURCE_BACKUP: String = "backup"
const LOAD_SOURCE_NEW: String = "new"

var profile: PlayerProfile
var save_path: String = PROFILE_PATH
var backup_path: String = BACKUP_PATH
var temp_path: String = TEMP_PATH
var last_load_source: String = ""
var last_error: String = ""
var last_corrupt_path: String = ""


func _ready() -> void:
	# Keep loading lazy. A fresh process should not create a profile merely by
	# opening the game; the first committed result (or an explicit get_profile)
	# will initialize and persist it. This also keeps editor tools and tests from
	# touching the player's save slot as a side effect of scene startup.
	profile = null


## Intended for tests and alternate save slots. Call it before load_profile().
func configure_paths(
	new_save_path: String,
	new_backup_path: String = "",
	new_temp_path: String = ""
) -> void:
	var normalized := new_save_path.strip_edges()
	if normalized.is_empty():
		return
	save_path = normalized
	backup_path = new_backup_path.strip_edges()
	if backup_path.is_empty():
		backup_path = "%s.bak" % save_path
	temp_path = new_temp_path.strip_edges()
	if temp_path.is_empty():
		temp_path = "%s.tmp" % save_path


## Alias for callers that use the more explicit profile_path terminology.
func configure_profile_path(new_profile_path: String) -> void:
	configure_paths(new_profile_path)


func get_profile_path() -> String:
	return save_path


func get_backup_path() -> String:
	return backup_path


func get_temp_path() -> String:
	return temp_path


func get_profile() -> PlayerProfile:
	if profile == null:
		return load_profile()
	return profile


func create_new_profile(save_immediately: bool = true) -> PlayerProfile:
	var fresh_profile := PlayerProfile.new()
	if save_immediately:
		if save_profile(fresh_profile):
			return profile
		return fresh_profile
	profile = fresh_profile
	last_load_source = LOAD_SOURCE_NEW
	return profile


## Load order: primary -> backup -> a fresh profile. A corrupt primary is
## quarantined before a recovered or fresh profile is written back.
func load_profile() -> PlayerProfile:
	last_error = ""
	last_corrupt_path = ""

	var primary_result := _read_profile_file(save_path)
	if primary_result.ok:
		profile = primary_result.profile
		last_load_source = LOAD_SOURCE_PRIMARY
		if primary_result.migrated and not save_profile(profile):
			push_warning("档案迁移成功，但写回新版档案失败：%s" % last_error)
		profile_loaded.emit(profile, last_load_source)
		return profile

	var primary_existed := FileAccess.file_exists(save_path)
	var backup_result := _read_profile_file(backup_path)
	if backup_result.ok:
		if primary_existed:
			last_corrupt_path = _quarantine_file(save_path)
		profile = backup_result.profile
		last_load_source = LOAD_SOURCE_BACKUP
		if not _write_primary_without_rotation(profile):
			push_warning("已从备份读取档案，但恢复主档失败：%s" % last_error)
		profile_recovered.emit(LOAD_SOURCE_BACKUP)
		profile_loaded.emit(profile, last_load_source)
		return profile

	if primary_existed:
		last_corrupt_path = _quarantine_file(save_path)
	if FileAccess.file_exists(backup_path):
		_quarantine_file(backup_path)

	profile = PlayerProfile.new()
	last_load_source = LOAD_SOURCE_NEW
	if not _write_primary_without_rotation(profile):
		push_warning("无法创建新档案：%s" % last_error)
	profile_loaded.emit(profile, last_load_source)
	return profile


## Compatibility name used by callers that do not care whether a profile was
## loaded from disk or created for the first time.
func load_or_create_profile() -> PlayerProfile:
	return load_profile()


func load_or_create() -> PlayerProfile:
	return load_profile()


## Atomic-style save: write and validate a temporary file, keep the previous
## primary as backup, then replace the primary. The in-memory profile is only
## updated after the file transaction succeeds.
func save_profile(profile_to_save: PlayerProfile = null) -> bool:
	var source := profile_to_save if profile_to_save != null else profile
	if source == null:
		source = PlayerProfile.new()

	last_error = ""
	if not _ensure_parent_directory(save_path):
		return _fail("无法创建存档目录")
	_cleanup_temp_file()

	if not _write_profile_file(temp_path, source):
		_cleanup_temp_file()
		return false
	var validation := _read_profile_file(temp_path)
	if not validation.ok:
		_cleanup_temp_file()
		return _fail("临时存档校验失败：%s" % str(validation.error))

	var had_primary := FileAccess.file_exists(save_path)
	if had_primary:
		_remove_file_if_exists(backup_path)
		var backup_error := _copy_file(save_path, backup_path)
		if backup_error != OK:
			_cleanup_temp_file()
			return _fail("无法备份旧档案（错误码 %d）" % backup_error)
		var remove_error := _remove_file_if_exists(save_path)
		if remove_error != OK:
			_cleanup_temp_file()
			return _fail("无法替换旧档案（错误码 %d）" % remove_error)

	var promote_error := _move_file(temp_path, save_path)
	if promote_error != OK:
		if had_primary and FileAccess.file_exists(backup_path):
			_copy_file(backup_path, save_path)
		_cleanup_temp_file()
		return _fail("无法提交临时存档（错误码 %d）" % promote_error)

	# The first successful save also gets a recovery copy.
	if not FileAccess.file_exists(backup_path):
		var first_backup_error := _copy_file(save_path, backup_path)
		if first_backup_error != OK:
			push_warning("主档已保存，但首次备份失败（错误码 %d）" % first_backup_error)

	if profile == null:
		profile = source.duplicate_profile()
	elif profile != source:
		profile.copy_from(source)
	profile.schema_version = PlayerProfile.CURRENT_SCHEMA_VERSION
	profile_saved.emit(profile)
	return true


func save() -> bool:
	return save_profile()


## Commit is idempotent by run_id. Rewards are copied to a candidate profile,
## persisted, and only then applied to the live profile object.
func commit_victory(
	session: BattleSession,
	target_profile: PlayerProfile = null
) -> bool:
	if session == null:
		return _fail("无法提交空战局")
	var target := target_profile if target_profile != null else get_profile()
	if target == null:
		return _fail("没有可用的玩家档案")

	if session.get_status() == BattleSession.STATUS_COMMITTED:
		# A committed transaction is a successful no-op. Returning true keeps
		# retries safe for callers that may receive the victory signal twice,
		# while the run_id guard below still prevents duplicate rewards.
		return true
	if target.last_committed_run_id == session.get_run_id():
		session.mark_committed()
		return true
	if not session.can_commit():
		return _fail("只有胜利且尚未提交的战局才能结算")

	var candidate := target.duplicate_profile()
	if not candidate.apply_battle_session(session):
		return _fail("战局奖励无法应用到档案")
	if not save_profile(candidate):
		return false

	if target != profile:
		target.copy_from(candidate)
	session.mark_committed()
	return true


func commit_session(
	session: BattleSession,
	target_profile: PlayerProfile = null
) -> bool:
	return commit_victory(session, target_profile)


## Failed, abandoned, or restarted runs never touch permanent storage.
func discard_session(session: BattleSession) -> bool:
	if session == null:
		return false
	return session.mark_discarded()


func discard_battle_session(session: BattleSession) -> bool:
	return discard_session(session)


func finish_defeat(session: BattleSession, defeat_result: Dictionary = {}) -> bool:
	if session == null:
		return false
	if session.is_in_progress() and not session.mark_defeat(defeat_result):
		return false
	return discard_session(session)


## 结算转盘入账（阶段 8 提交 2）：胜利结算页抽奖结果直接写档（物品/碎片/科技点）。
## 失败作废由"仅胜利结算页出现转盘"保证；单次入账由 UI 单次点击保证（同 run 不重复出现）。
func commit_settlement_reward(result: Dictionary) -> bool:
	if not result is Dictionary or result.is_empty():
		return false
	var candidate := get_profile().duplicate_profile()
	match str(result.get("kind", "")):
		"item":
			candidate.add_item(str(result.get("item_id", "")), int(result.get("amount", 0)))
		"shards":
			candidate.add_character_shards(str(result.get("character_id", "")), int(result.get("amount", 0)))
		"tech_points":
			candidate.add_tech_points(int(result.get("amount", 0)))
		_:
			return false
	# save_profile 成功后内部已同步内存 profile（profile.copy_from(candidate)）。
	return save_profile(candidate)


func _read_profile_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "文件不存在"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "无法打开文件（错误码 %d）" % FileAccess.get_open_error()}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return {"ok": false, "error": "文件为空"}
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"ok": false, "error": "根节点不是 JSON 对象或 JSON 已损坏"}
	var migration := _migrate_to_current(parsed)
	if not migration.ok:
		return migration
	return {
		"ok": true,
		"profile": PlayerProfile.from_dict(migration.data),
		"migrated": migration.migrated,
		"error": "",
	}


func _write_profile_file(path: String, source: PlayerProfile) -> bool:
	if not _ensure_parent_directory(path):
		return _fail("无法创建存档目录")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _fail("无法写入 %s（错误码 %d）" % [path, FileAccess.get_open_error()])
	var json_text := JSON.stringify(source.to_dict(), "\t", false)
	file.store_string(json_text)
	file.flush()
	file.close()
	return true


func _write_primary_without_rotation(source: PlayerProfile) -> bool:
	last_error = ""
	_cleanup_temp_file()
	if not _write_profile_file(temp_path, source):
		return false
	var validation := _read_profile_file(temp_path)
	if not validation.ok:
		_cleanup_temp_file()
		return _fail("恢复临时档校验失败：%s" % str(validation.error))
	var remove_error := _remove_file_if_exists(save_path)
	if remove_error != OK:
		_cleanup_temp_file()
		return _fail("无法移除损坏主档（错误码 %d）" % remove_error)
	var promote_error := _move_file(temp_path, save_path)
	if promote_error != OK:
		_cleanup_temp_file()
		return _fail("无法恢复主档（错误码 %d）" % promote_error)
	if not FileAccess.file_exists(backup_path):
		_copy_file(save_path, backup_path)
	return true


## v1 → v2（阶段 8·提交 6，职业级转职树落地）：旧角色绑定转职 ID 已废弃删除，
## promotion_path 一律清空，玩家按职业级转职树（6 职业 × 一转 → 二转 2 分支）重新转职。
func _migrate_v1_to_v2(old_data: Dictionary) -> Dictionary:
	var data := old_data.duplicate(true)
	var characters: Dictionary = {}
	if data.get("characters", {}) is Dictionary:
		characters = data.get("characters", {}).duplicate(true)
	for character_id in characters.keys():
		var entry = characters[character_id]
		if not entry is Dictionary:
			continue
		entry = entry.duplicate(true)
		entry["promotion_path"] = []
		characters[character_id] = entry
	data["schema_version"] = 2
	data["characters"] = characters
	return data


## Migration entry point. Add one version step at a time as schemas evolve.
func _migrate_to_current(raw_data: Dictionary) -> Dictionary:
	var data := raw_data.duplicate(true)
	var version := _read_schema_version(data)
	if version < 0:
		return {"ok": false, "error": "schema_version 无效"}
	if version > PlayerProfile.CURRENT_SCHEMA_VERSION:
		return {"ok": false, "error": "存档版本高于当前游戏版本"}
	var migrated := false
	while version < PlayerProfile.CURRENT_SCHEMA_VERSION:
		match version:
			0:
				data = _migrate_v0_to_v1(data)
				version = 1
				migrated = true
			1:
				data = _migrate_v1_to_v2(data)
				version = 2
				migrated = true
			_:
				return {"ok": false, "error": "缺少从版本 %d 开始的迁移器" % version}
	if not _validate_current_shape(data):
		return {"ok": false, "error": "存档字段类型无效"}
	return {"ok": true, "data": data, "migrated": migrated, "error": ""}


func _migrate_v0_to_v1(old_data: Dictionary) -> Dictionary:
	var data := old_data.duplicate(true)
	var characters: Dictionary = {}
	if data.get("characters", {}) is Dictionary:
		characters = data.get("characters", {}).duplicate(true)

	var owned = data.get("owned_characters", [])
	if owned is Array:
		for value in owned:
			var character_id := str(value).strip_edges()
			if not character_id.is_empty() and not characters.has(character_id):
				characters[character_id] = {}

	var legacy_exp = data.get("character_exp", {})
	if legacy_exp is Dictionary:
		for key in legacy_exp.keys():
			var character_id := str(key).strip_edges()
			if character_id.is_empty():
				continue
			var entry = characters.get(character_id, {})
			if not entry is Dictionary:
				entry = {}
			entry = entry.duplicate(true)
			entry["total_exp"] = legacy_exp[key]
			characters[character_id] = entry

	var stage_progress: Dictionary = {}
	if data.get("stage_progress", {}) is Dictionary:
		stage_progress = data.get("stage_progress", {}).duplicate(true)
	var completed_stages = data.get("completed_stages", [])
	if completed_stages is Array:
		for value in completed_stages:
			var stage_id := str(value).strip_edges()
			if not stage_id.is_empty():
				stage_progress[stage_id] = {"completed": true, "status": "completed"}

	data["schema_version"] = 1
	data["characters"] = characters
	data["stage_progress"] = stage_progress
	if not data.get("items", {}) is Dictionary:
		data["items"] = {}
	if not data.get("gacha_state", {}) is Dictionary:
		data["gacha_state"] = {}
	data["last_committed_run_id"] = str(data.get("last_committed_run_id", ""))
	data.erase("owned_characters")
	data.erase("character_exp")
	data.erase("completed_stages")
	return data


func _read_schema_version(data: Dictionary) -> int:
	if not data.has("schema_version"):
		return 0
	var value = data["schema_version"]
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return int(value)
	return -1


func _validate_current_shape(data: Dictionary) -> bool:
	if _read_schema_version(data) != PlayerProfile.CURRENT_SCHEMA_VERSION:
		return false
	for key in ["characters", "stage_progress", "items", "gacha_state"]:
		if data.has(key) and not data[key] is Dictionary:
			return false
	return true


func _ensure_parent_directory(path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path)
	var directory := absolute_path.get_base_dir()
	if directory.is_empty() or DirAccess.dir_exists_absolute(directory):
		return true
	return DirAccess.make_dir_recursive_absolute(directory) == OK


func _copy_file(from_path: String, to_path: String) -> Error:
	return DirAccess.copy_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path)
	)


func _move_file(from_path: String, to_path: String) -> Error:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path)
	)


func _remove_file_if_exists(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup_temp_file() -> void:
	_remove_file_if_exists(temp_path)


func _quarantine_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var quarantine_path := "%s.corrupt.%d.%d" % [
		path,
		int(Time.get_unix_time_from_system()),
		Time.get_ticks_usec(),
	]
	var move_error := _move_file(path, quarantine_path)
	if move_error != OK:
		push_warning("无法隔离损坏档案 %s（错误码 %d）" % [path, move_error])
		return ""
	return quarantine_path


func _fail(reason: String) -> bool:
	last_error = reason
	save_failed.emit(reason)
	push_error("SaveManager: %s" % reason)
	return false
