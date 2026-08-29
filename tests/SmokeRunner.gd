extends Node

var failures: Array[String] = []
var warnings: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SMOKE_TEST: %s" % message)


func _run() -> void:
	_check_resource_integrity()

	var packed := load("res://scenes/Main.tscn") as PackedScene
	_check(packed != null, "Main.tscn 无法加载")
	if packed == null:
		_finish()
		return

	var main := packed.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(GameManager.gold == 100, "初始金币应为 100")
	_check(GameManager.lives == 20, "初始生命应为 20")
	_check(get_tree().get_nodes_in_group("build_slots").size() == 10, "应有 10 个建造位")

	var slots := get_tree().get_nodes_in_group("build_slots")
	var build_manager := main.get_node("BuildManager")
	var tower_manager := main.get_node("TowerManager")
	var guan_yu := load("res://resources/characters/guan_yu.tres") as CharacterData
	var liu_bei := load("res://resources/characters/liu_bei.tres") as CharacterData
	build_manager.selected_character = guan_yu
	var enemy_path := main.get_node("Path2D") as Path2D
	for slot in slots:
		var closest_local: Vector2 = enemy_path.curve.get_closest_point(enemy_path.to_local(slot.global_position))
		var distance_to_path: float = slot.global_position.distance_to(enemy_path.to_global(closest_local))
		_check(distance_to_path >= 70.0 and distance_to_path <= 170.0, "建造位应贴着网格道路（80/160 像素）")
	if slots.size() >= 3:
		build_manager._on_build_requested(slots[0])
		await get_tree().process_frame
		_check(GameManager.gold == 100 - guan_yu.build_cost, "建造关羽后金币应扣除其造价")
		build_manager.selected_character = liu_bei
		build_manager._on_build_requested(slots[1])
		build_manager._on_build_requested(slots[2])
		await get_tree().process_frame
		_check(tower_manager.get_child_count() == 1, "金币不足时不应生成第二座塔")
		_check(slots[0].occupied and not slots[1].occupied and not slots[2].occupied, "建造位占用状态错误")
		GameManager.gold = 9999
		build_manager._on_build_requested(slots[1])
		await get_tree().process_frame
		_check(tower_manager.get_child_count() == 2 and slots[1].occupied, "金币充足时应能建造第二座塔")

	var enemy_manager := main.get_node("EnemyManager")
	# 程序化构造 EnemyData，替代旧的硬编码 spawn_enemy("boss")。
	var boss_data := EnemyData.new()
	boss_data.enemy_id = &"smoke_boss"
	boss_data.display_name = "冒烟测试 Boss"
	boss_data.max_hp = 800
	boss_data.move_speed = 40.0
	boss_data.currency_reward = 50
	boss_data.kill_xp = 100
	boss_data.damage_to_base = 5
	boss_data.body_color = Color.PURPLE
	boss_data.body_size = Vector2(60, 60)
	var boss := enemy_manager.spawn_enemy_from_data(boss_data) as Enemy
	await get_tree().process_frame
	_check(boss != null and boss.current_hp == 800, "Boss 应以 800 HP 初始化")
	if boss:
		boss.set_process(false)
		boss.global_position = tower_manager.get_child(0).global_position + Vector2(30, 0)

	var first_tower := tower_manager.get_child(0) as Tower
	_check(first_tower.damage == guan_yu.base_damage, "塔伤害应来自武将数据")
	_check(first_tower.character_id == guan_yu.character_id, "塔应记录武将 ID")
	var second_tower := tower_manager.get_child(1) as Tower
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	first_tower._on_selection_area_input_event(get_viewport(), click, 0)
	_check(first_tower.is_selected and not second_tower.is_selected, "点击塔后应显示该塔范围")
	second_tower._on_selection_area_input_event(get_viewport(), click, 0)
	_check(not first_tower.is_selected and second_tower.is_selected, "切换塔时只能保留一个范围")
	second_tower._on_selection_area_input_event(get_viewport(), click, 0)
	_check(not second_tower.is_selected, "再次点击已选塔应关闭范围")
	await get_tree().process_frame
	_check(first_tower.find_target() == boss, "塔应锁定射程内 Boss")
	first_tower.target = boss
	first_tower.attack()
	for _i in range(20):
		await get_tree().physics_frame
	_check(boss.current_hp < 800, "子弹应对 Boss 造成伤害")
	if is_instance_valid(boss):
		boss.die(false)

	var wave_manager := main.get_node("WaveManager")
	var soldier := load("res://resources/enemies/yellow_turban/yellow_turban_soldier.tres") as EnemyData
	var spawn := EnemySpawnData.new()
	spawn.enemy = soldier
	spawn.count = 1
	spawn.spawn_interval = 0.0
	var wave := WaveData.new()
	wave.wave_id = &"smoke_wave"
	wave.wave_number = 1
	wave.spawn_groups = [spawn]
	wave_manager.configure_waves([wave])
	GameManager.total_waves = 1
	wave_manager.start_wave(0)
	await get_tree().process_frame
	_check(GameManager.is_wave_active, "开波后应进入战斗状态")
	var wave_enemies := get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP)
	_check(wave_enemies.size() == 1, "测试波次应生成一只敌人")
	if not wave_enemies.is_empty():
		(wave_enemies[0] as Enemy).take_damage(9999)
	for _i in range(5):
		await get_tree().process_frame
	_check(GameManager.current_wave == 1 and not GameManager.is_wave_active, "击杀最后一只敌人后应完成波次")

	# 击杀经验归属（GDD 4.4）：步卒 kill_xp=8，关羽最后一击应得 50%+均分 = 6，
	# 刘备参与伤害应得均分 = 2。
	var xp_session := BattleSession.new("smoke_xp_stage")
	GameManager.set_battle_session(xp_session)
	var xp_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
	_check(xp_enemy != null, "经验归属用例应能生成敌人")
	if xp_enemy:
		xp_enemy.take_damage(30, "liu_bei")
		xp_enemy.take_damage(9999, "guan_yu")
		var pending_xp: Dictionary = xp_session.get_pending_xp_by_character()
		_check(int(pending_xp.get("guan_yu", 0)) == 6, "最后一击武将应获得 6 点经验（4 + 均分 2）")
		_check(int(pending_xp.get("liu_bei", 0)) == 2, "参与伤害武将应获得均分 2 点经验")

	_finish()


func _finish() -> void:
	get_tree().paused = false
	for warning in warnings:
		print("SMOKE_TEST_WARN: %s" % warning)
	if failures.is_empty():
		print("SMOKE_TEST_OK")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_FAILED: %d" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)


## 资源完整性扫描（GDD 阶段 3 验收项"无配置缺失报错"）：全量加载
## resources/ 下 .tres 并校验跨资源引用。指向尚未创建内容的前向引用
## （如角色解锁关卡未建）只记警告；引用到任何位置都不存在的 ID 记为失败。
func _check_resource_integrity() -> void:
	var characters: Dictionary = {}
	var promotions: Dictionary = {}
	var stages: Dictionary = {}
	var items: Dictionary = {}
	for path in _collect_resource_paths("res://resources"):
		var resource := load(path) as Resource
		if resource == null:
			_check(false, "资源加载失败: %s" % path)
			continue
		if resource is CharacterData:
			var character := resource as CharacterData
			_check(character.is_valid(), "CharacterData 无效: %s" % path)
			_check(character.profession != null, "角色缺少职业引用: %s" % path)
			characters[str(character.character_id)] = character
		elif resource is EnemyData:
			_check((resource as EnemyData).is_valid(), "EnemyData 无效: %s" % path)
		elif resource is StageData:
			var stage := resource as StageData
			_check(stage.is_valid(), "StageData 无效: %s" % path)
			stages[str(stage.stage_id)] = stage
		elif resource is PromotionData:
			var promotion := resource as PromotionData
			_check(promotion.is_valid(), "PromotionData 无效: %s" % path)
			_check(promotion.target_profession != null, "转职缺少目标职业: %s" % path)
			promotions[str(promotion.promotion_id)] = promotion
		elif resource is ProfessionData:
			var profession := resource as ProfessionData
			_check(profession.is_valid(), "ProfessionData 无效: %s" % path)
			_check(not profession.behavior_id.is_empty(), "职业缺少 behavior_id: %s" % path)
		elif resource is ItemData:
			var item := resource as ItemData
			_check(item.is_valid(), "ItemData 无效: %s" % path)
			items[str(item.item_id)] = item
		elif resource is ItemAmountData:
			_check((resource as ItemAmountData).is_valid(), "ItemAmountData 缺少道具引用: %s" % path)
		elif resource is WaveData:
			_check((resource as WaveData).is_valid(), "WaveData 无效: %s" % path)
		elif resource is ChapterData:
			_check((resource as ChapterData).is_valid(), "ChapterData 无效: %s" % path)

	for character_id in characters:
		var character: CharacterData = characters[character_id]
		for promotion_id in character.promotion_ids:
			_check(promotions.has(str(promotion_id)),
				"角色 %s 引用了不存在的转职 %s" % [character_id, promotion_id])
		if not character.unlock_stage_id.is_empty() and not stages.has(str(character.unlock_stage_id)):
			warnings.append("角色 %s 的解锁关卡 %s 尚未创建" % [character_id, character.unlock_stage_id])
	for stage_id in stages:
		var stage: StageData = stages[stage_id]
		for prereq in stage.prerequisite_stage_ids:
			_check(stages.has(str(prereq)),
				"关卡 %s 引用了不存在的前置关卡 %s" % [stage_id, prereq])
		for unlock_id in stage.first_clear_unlock_character_ids:
			_check(characters.has(str(unlock_id)),
				"关卡 %s 首通解锁了不存在的角色 %s" % [stage_id, unlock_id])
		for reward in stage.first_clear_rewards + stage.repeat_clear_rewards:
			if reward != null and reward.item != null and not items.has(str(reward.item.item_id)):
				_check(false, "关卡 %s 掉落了未注册道具 %s" % [stage_id, reward.item.item_id])
	for promotion_id in promotions:
		var promotion: PromotionData = promotions[promotion_id]
		for next_id in promotion.next_promotion_ids:
			_check(promotions.has(str(next_id)),
				"转职 %s 引用了不存在的后续转职 %s" % [promotion_id, next_id])


func _collect_resource_paths(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_check(false, "无法打开资源目录: %s" % dir_path)
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var full_path := dir_path + "/" + entry
		if dir.current_is_dir():
			if not entry.begins_with("."):
				result.append_array(_collect_resource_paths(full_path))
		elif entry.ends_with(".tres"):
			result.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return result
