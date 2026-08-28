extends Node

## Stage 0 contract checks. This runner is intentionally separate from the
## playable smoke test so persistence checks never affect the normal scene.

const DATA_SCRIPT_PATHS := [
	"res://scripts/data/ProfessionData.gd",
	"res://scripts/data/CharacterData.gd",
	"res://scripts/data/EnemyData.gd",
	"res://scripts/data/EnemySpawnData.gd",
	"res://scripts/data/WaveData.gd",
	"res://scripts/data/ItemData.gd",
	"res://scripts/data/ItemAmountData.gd",
	"res://scripts/data/StageData.gd",
	"res://scripts/data/ChapterData.gd",
	"res://scripts/data/PromotionData.gd",
]

const PROFILE_PATH := "res://scripts/data/PlayerProfile.gd"
const BATTLE_SESSION_PATHS := [
	"res://scripts/services/BattleSession.gd",
	"res://scripts/data/BattleSession.gd",
]
const SAVE_MANAGER_PATH := "res://scripts/services/SaveManager.gd"

var failures: Array[String] = []
var _profile_file := ""
var _profile_backup_file := ""
var _profile_temp_file := ""
var _original_profile: PackedByteArray = PackedByteArray()
var _original_backup: PackedByteArray = PackedByteArray()
var _original_temp: PackedByteArray = PackedByteArray()
var _had_profile := false
var _had_backup := false
var _had_temp := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Use a unique, disposable slot so the test never touches the player's
	# normal user://profile.json. The SaveManager supports path overrides for
	# precisely this kind of isolated integration test.
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	# user:// is required: SaveManager rotates the primary file into a backup
	# with DirAccess.copy/rename, which is not supported reliably under
	# res:// (crashes with signal 11 on Windows). The file names are unique per
	# run and are restored/removed in _restore_profile_files(), so the player's
	# real profile is never touched. STAGE0_SAVE_DIR lets sandboxed/headless
	# runs redirect the disposable slot to a writable directory.
	var save_dir := OS.get_environment("STAGE0_SAVE_DIR").strip_edges()
	if save_dir.is_empty():
		_profile_file = "user://.stage0_runner_%s.json" % nonce
	else:
		_profile_file = "%s/.stage0_runner_%s.json" % [save_dir, nonce]
	_profile_backup_file = "%s.bak" % _profile_file
	_profile_temp_file = "%s.tmp" % _profile_file
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("STAGE0_TEST: %s" % message)


func _run() -> void:
	_snapshot_profile_files()
	_test_data_resources()
	_test_player_profile()
	_test_battle_session_contract()
	_test_save_manager_corruption_fallback()
	_restore_profile_files()
	_finish()


func _test_data_resources() -> void:
	for path in DATA_SCRIPT_PATHS:
		_check(ResourceLoader.exists(path), "数据脚本不存在: %s" % path)
		var script := load(path) as Script
		_check(script != null, "数据脚本无法加载: %s" % path)
		if script != null:
			var resource = script.new()
			_check(resource is Resource, "数据类无法实例化为 Resource: %s" % path)

	var profession_script := load("res://scripts/data/ProfessionData.gd") as Script
	var character_script := load("res://scripts/data/CharacterData.gd") as Script
	var enemy_script := load("res://scripts/data/EnemyData.gd") as Script
	var spawn_script := load("res://scripts/data/EnemySpawnData.gd") as Script
	var wave_script := load("res://scripts/data/WaveData.gd") as Script
	var item_script := load("res://scripts/data/ItemData.gd") as Script
	var amount_script := load("res://scripts/data/ItemAmountData.gd") as Script
	var stage_script := load("res://scripts/data/StageData.gd") as Script
	var chapter_script := load("res://scripts/data/ChapterData.gd") as Script
	var promotion_script := load("res://scripts/data/PromotionData.gd") as Script
	if profession_script == null or character_script == null or enemy_script == null \
			or spawn_script == null or wave_script == null or item_script == null \
			or amount_script == null or stage_script == null or chapter_script == null \
			or promotion_script == null:
		return

	var profession = profession_script.new()
	profession.profession_id = &"cavalry"
	profession.display_name = "骑兵"
	_check(profession.is_valid(), "ProfessionData 基础数据应有效")

	var character = character_script.new()
	character.character_id = &"guan_yu"
	character.display_name = "关羽"
	character.profession = profession
	_check(character.is_valid(), "CharacterData 基础数据应有效")

	var enemy = enemy_script.new()
	enemy.enemy_id = &"yellow_turban_soldier"
	enemy.display_name = "黄巾步卒"
	_check(enemy.is_valid(), "EnemyData 基础数据应有效")

	var spawn = spawn_script.new()
	spawn.enemy = enemy
	spawn.count = 3
	spawn.spawn_interval = 0.25
	_check(spawn.is_valid(), "EnemySpawnData 基础数据应有效")

	var wave = wave_script.new()
	wave.wave_id = &"ch01_s01_w01"
	wave.wave_number = 1
	wave.spawn_groups.append(spawn)
	_check(wave.is_valid(), "WaveData 基础数据应有效")

	var item = item_script.new()
	item.item_id = &"gacha_token"
	item.display_name = "求贤令"
	_check(item.is_valid(), "ItemData 基础数据应有效")

	var amount = amount_script.new()
	amount.item = item
	amount.amount = 1
	_check(amount.is_valid(), "ItemAmountData 基础数据应有效")

	var stage = stage_script.new()
	stage.stage_id = &"ch01_s01"
	stage.chapter_id = &"chapter_01"
	stage.display_name = "涿郡起兵"
	stage.waves.append(wave)
	stage.first_clear_rewards.append(amount)
	_check(stage.is_valid(), "StageData 基础数据应有效")

	var chapter = chapter_script.new()
	chapter.chapter_id = &"chapter_01"
	chapter.chapter_number = 1
	chapter.display_name = "黄巾之乱"
	chapter.stages.append(stage)
	_check(chapter.is_valid(), "ChapterData 基础数据应有效")

	var promotion = promotion_script.new()
	promotion.promotion_id = &"guan_yu_charger"
	promotion.display_name = "突击骑"
	promotion.required_level = 10
	_check(promotion.is_valid(), "PromotionData 基础数据应有效")


func _test_player_profile() -> void:
	if not ResourceLoader.exists(PROFILE_PATH):
		_check(false, "PlayerProfile.gd 不存在")
		return
	var script := load(PROFILE_PATH) as Script
	_check(script != null, "PlayerProfile.gd 无法加载")
	if script == null:
		return
	var profile = script.new()
	_check(profile != null, "PlayerProfile 无法实例化")
	if profile == null:
		return

	_check(profile.unlock_character("guan_yu"), "新角色应能解锁")
	_check(not profile.unlock_character("guan_yu"), "重复解锁角色应被拒绝")
	_check(profile.add_character_exp("guan_yu", 25) == 25, "角色经验应累加")
	_check(profile.get_character_exp("guan_yu") == 25, "角色经验读取错误")
	_check(profile.add_item("gacha_token", 2) == 2, "物品数量应累加")
	_check(profile.mark_stage_completed("ch01_s01"), "关卡完成状态应能写入")

	var encoded: Dictionary = profile.to_dict()
	_check(int(encoded.get("schema_version", 0)) > 0, "存档应包含 schema_version")
	_check(encoded.get("characters", {}).has("guan_yu"), "存档应包含稳定角色 ID")
	var restored = script.new()
	restored.load_dict(encoded)
	_check(restored.get_character_exp("guan_yu") == 25, "PlayerProfile 往返序列化丢失经验")
	_check(restored.items.get("gacha_token", 0) == 2, "PlayerProfile 往返序列化丢失物品")
	_check(restored.stage_progress.get("ch01_s01", {}).get("completed", false), "PlayerProfile 往返序列化丢失关卡状态")

	var duplicate = profile.duplicate_profile()
	profile.add_character_exp("guan_yu", 5)
	_check(duplicate.get_character_exp("guan_yu") == 25, "duplicate_profile 应为深拷贝")


func _test_battle_session_contract() -> void:
	var script := _load_first_script(BATTLE_SESSION_PATHS)
	if script == null:
		_check(false, "BattleSession.gd 不存在或无法加载")
		return
	var session = script.new()
	_check(session != null, "BattleSession 无法实例化")
	if session == null:
		return

	# Keep this test tolerant of constructor details while requiring the public
	# transaction methods and the no-commit-before-victory rule.
	if session.get("stage_id") != null:
		session.stage_id = "ch01_s01"
	if session.get("run_id") != null:
		session.run_id = "stage0-test-run"
	_check(session.has_method("add_xp"), "BattleSession 应提供 add_xp")
	_check(session.has_method("mark_victory"), "BattleSession 应提供 mark_victory")
	_check(session.has_method("mark_defeat"), "BattleSession 应提供 mark_defeat")
	if not session.has_method("add_xp") or not session.has_method("mark_victory"):
		return
	session.add_xp("guan_yu", 30)
	if session.has_method("get_pending_xp_by_character"):
		var pending: Dictionary = session.get_pending_xp_by_character()
		_check(int(pending.get("guan_yu", 0)) == 30, "BattleSession 应暂存角色经验")
	var session_is_victory := false
	if session.has_method("is_victory"):
		session_is_victory = session.is_victory()
	_check(not session_is_victory, "未结算 BattleSession 不应是胜利")

	var profile_script := load(PROFILE_PATH) as Script
	if profile_script != null:
		var profile = profile_script.new()
		profile.unlock_character("guan_yu")
		_check(profile.get_character_exp("guan_yu") == 0, "战斗前角色经验应为 0")
		if session.has_method("mark_victory"):
			session.mark_victory()
			_check(profile.apply_battle_session(session), "胜利 BattleSession 应能提交")
			_check(profile.get_character_exp("guan_yu") == 30, "胜利提交后应获得暂存经验")
			_check(not profile.apply_battle_session(session), "同一 run_id 不应重复提交经验")

	# Defeat is a separate transaction and must never apply pending XP.
	var defeat = script.new()
	if defeat != null:
		if defeat.get("stage_id") != null:
			defeat.stage_id = "ch01_s01"
		if defeat.get("run_id") != null:
			defeat.run_id = "stage0-defeat-run"
		if defeat.has_method("add_xp"):
			defeat.add_xp("huang_zhong", 99)
		if defeat.has_method("mark_defeat"):
			defeat.mark_defeat()
		if profile_script != null:
			var defeat_profile = profile_script.new()
			defeat_profile.unlock_character("huang_zhong")
			_check(not defeat_profile.apply_battle_session(defeat), "失败 BattleSession 不应提交经验")
			_check(defeat_profile.get_character_exp("huang_zhong") == 0, "失败后角色经验必须回滚")


func _test_save_manager_corruption_fallback() -> void:
	if not ResourceLoader.exists(SAVE_MANAGER_PATH):
		_check(false, "SaveManager.gd 不存在")
		return
	var script := load(SAVE_MANAGER_PATH) as Script
	_check(script != null, "SaveManager.gd 无法加载")
	if script == null:
		return
	var profile_script := load(PROFILE_PATH) as Script
	if profile_script == null:
		return
	var profile = profile_script.new()
	profile.unlock_character("save_probe")
	profile.add_character_exp("save_probe", 17)

	var manager = script.new()
	_check(manager != null, "SaveManager 无法实例化")
	if manager == null:
		return
	if manager.has_method("configure_paths"):
		manager.configure_paths(_profile_file, _profile_backup_file, _profile_temp_file)
	else:
		_check(false, "SaveManager 应提供 configure_paths 以支持独立存档槽")
		return
	var saved = manager.save_profile(profile) if manager.has_method("save_profile") else false
	_check(bool(saved), "SaveManager.save_profile 应成功")
	var loaded = manager.load_profile() if manager.has_method("load_profile") else null
	_check(loaded != null, "SaveManager 应能读取刚写入的存档")
	if loaded != null and loaded.has_method("get_character_exp"):
		_check(loaded.get_character_exp("save_probe") == 17, "SaveManager 往返存档丢失角色经验")

	# A malformed primary file should fall back to the backup or a clean profile.
	var file := FileAccess.open(_profile_file, FileAccess.WRITE)
	if file != null:
		file.store_string("{ definitely not valid json")
		file.close()
	var recovered = manager.load_profile() if manager.has_method("load_profile") else null
	_check(recovered != null, "主存档损坏时应回退并返回可用档案")
	if recovered != null and recovered.has_method("get_character_exp"):
		var recovered_exp: int = int(recovered.get_character_exp("save_probe"))
		_check(recovered_exp == 17, "主档损坏时应从备份恢复角色经验")
	if manager.get("last_load_source") != null:
		_check(manager.last_load_source == "backup", "主档损坏时加载来源应标记为 backup")

	# SaveManager must persist a victory exactly once and discard defeat rewards.
	var battle_script := _load_first_script(BATTLE_SESSION_PATHS)
	if battle_script != null and manager.has_method("commit_victory"):
		var commit_profile = profile_script.new()
		commit_profile.unlock_character("commit_probe")
		var victory_session = battle_script.new()
		if victory_session.get("stage_id") != null:
			victory_session.stage_id = "ch01_s01"
		if victory_session.get("run_id") != null:
			victory_session.run_id = "commit-run"
		if victory_session.get("deployed_character_ids") != null:
			victory_session.deployed_character_ids.append("commit_probe")
		victory_session.add_xp("commit_probe", 41)
		victory_session.add_loot("gacha_token", 1)
		_check(victory_session.mark_victory(), "胜利战局应能标记")
		_check(manager.commit_victory(victory_session, commit_profile), "SaveManager 应提交胜利战局")
		_check(commit_profile.get_character_exp("commit_probe") == 41, "胜利提交应写入角色经验")
		_check(manager.commit_victory(victory_session, commit_profile), "重复提交同一战局应保持幂等成功")
		_check(commit_profile.get_character_exp("commit_probe") == 41, "重复提交不应重复增加经验")

		var defeat_session = battle_script.new()
		if defeat_session.get("stage_id") != null:
			defeat_session.stage_id = "ch01_s01"
		if defeat_session.get("run_id") != null:
			defeat_session.run_id = "defeat-run"
		defeat_session.add_xp("commit_probe", 99)
		defeat_session.mark_defeat()
		_check(not manager.commit_victory(defeat_session, commit_profile), "失败战局不可通过胜利接口提交")
		_check(commit_profile.get_character_exp("commit_probe") == 41, "失败战局不应改变永久经验")


func _load_first_script(paths: Array) -> Script:
	for path in paths:
		if ResourceLoader.exists(path):
			var candidate := load(path) as Script
			if candidate != null:
				return candidate
	return null


func _snapshot_profile_files() -> void:
	_had_profile = FileAccess.file_exists(_profile_file)
	_had_backup = FileAccess.file_exists(_profile_backup_file)
	_had_temp = FileAccess.file_exists(_profile_temp_file)
	_original_profile = _read_bytes(_profile_file)
	_original_backup = _read_bytes(_profile_backup_file)
	_original_temp = _read_bytes(_profile_temp_file)


func _restore_profile_files() -> void:
	_restore_file(_profile_file, _had_profile, _original_profile)
	_restore_file(_profile_backup_file, _had_backup, _original_backup)
	_restore_file(_profile_temp_file, _had_temp, _original_temp)
	# SaveManager quarantines malformed files with a suffix. Remove only files
	# belonging to this unique test slot.
	var absolute_dir := ProjectSettings.globalize_path(_profile_file.get_base_dir())
	var dir := DirAccess.open(absolute_dir)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		var prefix := "%s.corrupt." % _profile_file.get_file()
		while not entry.is_empty():
			if not dir.current_is_dir() and entry.begins_with(prefix):
				DirAccess.remove_absolute(absolute_dir.path_join(entry))
			entry = dir.get_next()
		dir.list_dir_end()


func _read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _restore_file(path: String, existed: bool, bytes: PackedByteArray) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(bytes)
			file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	get_tree().paused = false
	if failures.is_empty():
		print("STAGE0_TEST_OK")
		get_tree().quit(0)
	else:
		print("STAGE0_TEST_FAILED: %d" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)
