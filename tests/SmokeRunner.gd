extends Node

var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SMOKE_TEST: %s" % message)


func _run() -> void:
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
	var boss := enemy_manager.spawn_enemy("boss") as Enemy
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
	var wave_enemies := get_tree().get_nodes_in_group("enemies")
	_check(wave_enemies.size() == 1, "测试波次应生成一只敌人")
	if not wave_enemies.is_empty():
		(wave_enemies[0] as Enemy).take_damage(9999)
	for _i in range(5):
		await get_tree().process_frame
	_check(GameManager.current_wave == 1 and not GameManager.is_wave_active, "击杀最后一只敌人后应完成波次")

	_finish()


func _finish() -> void:
	get_tree().paused = false
	if failures.is_empty():
		print("SMOKE_TEST_OK")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_FAILED: %d" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)
