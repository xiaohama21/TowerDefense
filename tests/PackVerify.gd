extends Node

## 打包产物验证场景（PackVerify）：模拟"全新机器、无 Godot 环境、首次运行"——
## 无存档创建新档、初始武将发放、编队角色链路（SquadSelect 同款）与全量资源完整性。
## 用法（开发态或打包 exe 均可）：
##   Godot --headless --scene res://tools/PackVerify.tscn
## 输出 PACK_VERIFY_OK / PACK_VERIFY_FAIL，退出码 0 / 1。

var failures: Array[String] = []
var details: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 隔离存档路径：验证过程不触碰真实玩家存档；每次先清空保证"全新环境"语义。
	var isolate_dir := "user://pack_verify"
	for file_name in ["profile.json", "profile.json.bak", "profile.json.tmp"]:
		var isolate_path: String = isolate_dir + "/" + file_name
		if FileAccess.file_exists(isolate_path):
			DirAccess.remove_absolute(isolate_path)
	ProfileStore.configure_profile_path(isolate_dir + "/profile.json")
	_run()
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(label: String, ok: bool) -> void:
	if ok:
		details.append("PASS  " + label)
	else:
		failures.append(label)
		details.append("FAIL  " + label)


func _scan_tres_ids(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	for entry in ResourceLoader.list_directory(dir_path):
		if entry.ends_with(".tres"):
			result.append(entry.trim_suffix(".tres"))
	result.sort()
	return result


func _run() -> void:
	_check("全新环境：user:// 下无存档", not FileAccess.file_exists(ProfileStore.get_profile_path()))
	_check("开始游戏：创建新档成功", GameFlow.start_new_game())
	var profile := ProfileStore.get_profile()
	_check("初始武将入库（刘备/关羽）", profile != null and profile.has_character("liu_bei") and profile.has_character("guan_yu"))
	_check("幂等：重复调用不重复发放", _initial_characters_idempotent(profile))
	_check("编队角色链路（SquadSelect 同款）", _squad_select_link(profile))
	_check("全量角色/职业/转职资源", _characters_integrity())
	_check("全量关卡/波次/敌人资源", _stages_integrity())
	_check("羁绊/遗物/道具/科技/数值/模板资源", _misc_integrity())
	print("PACK_VERIFY_%s" % ("OK" if failures.is_empty() else "FAIL"))
	print("DETAILS:")
	for line in details:
		print("  " + line)
	if not failures.is_empty():
		print("FAILURES:")
		for line in failures:
			print("  " + line)


func _initial_characters_idempotent(profile: PlayerProfile) -> bool:
	var before := profile.get_owned_character_ids().size()
	GameFlow.ensure_initial_characters(profile)
	return profile.get_owned_character_ids().size() == before


## 复刻 SquadSelect._load_owned_characters：已拥有 id → 加载 CharacterData，null 静默跳过。
func _squad_select_link(profile: PlayerProfile) -> bool:
	if profile == null:
		return false
	var owned := profile.get_owned_character_ids()
	var loaded: Array[CharacterData] = []
	var missing: Array[String] = []
	for character_id in owned:
		var character_data := GameFlow.load_character_data(character_id)
		if character_data != null:
			loaded.append(character_data)
		else:
			missing.append(character_id)
	details.append("编队可用角色=%d（已拥有=%d，加载失败=%s）" % [loaded.size(), owned.size(), str(missing)])
	var has_liu_bei := false
	var has_guan_yu := false
	for character_data in loaded:
		if character_data.character_id == &"liu_bei":
			has_liu_bei = true
		if character_data.character_id == &"guan_yu":
			has_guan_yu = true
	return loaded.size() >= 2 and has_liu_bei and has_guan_yu


func _characters_integrity() -> bool:
	var missing: Array[String] = []
	for character_id in GameFlow.get_all_character_ids():
		var character_data := GameFlow.load_character_data(character_id)
		if character_data == null:
			missing.append(character_id)
			continue
		if character_data.profession == null:
			missing.append(character_id + ".profession")
		if character_data.display_name.is_empty():
			missing.append(character_id + ".display_name")
		for promotion_id in character_data.promotion_ids:
			if GameFlow.load_promotion_data(promotion_id) == null:
				missing.append("%s->promotion:%s" % [character_id, promotion_id])
	var profession_ids := _scan_tres_ids("res://resources/professions")
	details.append("角色=%d、职业=%d（%s）" % [GameFlow.get_all_character_ids().size(), profession_ids.size(), str(profession_ids)])
	details.append("角色/职业/转职缺失=%s" % str(missing))
	return missing.is_empty()


func _stages_integrity() -> bool:
	var missing: Array[String] = []
	var chapter := GameFlow.get_chapter()
	if chapter == null:
		missing.append("chapter_01")
		return false
	var stage_count := 0
	var enemy_set: Dictionary = {}
	for stage in GameFlow.get_sorted_stages(chapter):
		stage_count += 1
		if stage.waves.is_empty():
			missing.append("%s.waves" % stage.stage_id)
		if stage.dialogue == null or stage.dialogue.lines.is_empty():
			missing.append("%s.dialogue" % stage.stage_id)
		if stage.path_points.size() < 2:
			missing.append("%s.path" % stage.stage_id)
		for wave in stage.waves:
			for spawn in wave.spawn_groups:
				if spawn.enemy == null:
					missing.append("%s.wave%d.enemy" % [stage.stage_id, wave.wave_number])
					continue
				var resolved := spawn.enemy.resolved()
				if resolved == null or resolved.max_hp <= 0:
					missing.append("%s.wave%d.enemy:%s.resolved" % [stage.stage_id, wave.wave_number, spawn.enemy.enemy_id])
				enemy_set[str(spawn.enemy.enemy_id)] = true
	details.append("关卡=%d（%s~%s）" % [stage_count, chapter.chapter_id, stage_count])
	details.append("波次引用敌人=%s" % str(enemy_set.keys()))
	details.append("关卡/波次/敌人缺失=%s" % str(missing))
	return missing.is_empty()


func _misc_integrity() -> bool:
	var missing: Array[String] = []
	var bonds := GameFlow.get_all_bonds()
	if bonds.is_empty():
		missing.append("bonds")
	for bond in bonds:
		if bond.member_ids.is_empty():
			missing.append("bond:%s" % bond.bond_id)
	var relic_ids := _scan_tres_ids("res://resources/battle_relics")
	for relic_id in relic_ids:
		if GameFlow.load_battle_relic_data(relic_id) == null:
			missing.append("battle_relic:%s" % relic_id)
	var item_ids := _scan_tres_ids("res://resources/items")
	for item_id in item_ids:
		if load("res://resources/items/%s.tres" % item_id) == null:
			missing.append("item:%s" % item_id)
	if load("res://resources/tech/tech_tree.tres") == null:
		missing.append("tech_tree")
	if load("res://resources/balance/game_balance.tres") == null:
		missing.append("game_balance")
	if load("res://resources/enemy_templates/heavy_cavalry.tres") == null:
		missing.append("heavy_cavalry_template")
	details.append("羁绊=%d、局内遗物=%d、道具=%d" % [bonds.size(), relic_ids.size(), item_ids.size()])
	details.append("羁绊/遗物/道具/科技/数值/模板缺失=%s" % str(missing))
	return missing.is_empty()
