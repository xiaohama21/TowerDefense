extends Node

var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("MAP_ROUTE: " + message)

func _ready() -> void:
	ProfileStore.configure_paths("user://.map_route_tests.json")
	call_deferred("run")

func run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	for id in ["guan_yu","liu_bei"]: profile.unlock_character(id)
	ProfileStore.save_profile(profile)
	GameFlow.squad_character_ids.assign(["guan_yu","liu_bei"])
	GameFlow.clear_squad_relics()
	GameFlow.set_gameplay_flag("skip_dialogue",true)
	GameFlow.set_gameplay_flag("auto_next_wave",false)
	GameFlow.selected_difficulty = Difficulty.NORMAL
	var soldier := load("res://resources/enemies/yellow_turban/yellow_turban_soldier.tres") as EnemyData
	for number in range(1,9):
		var id := StringName("ch01_s%02d" % number)
		GameFlow.selected_stage_id = id
		var stage := GameFlow.load_stage_data(id)
		var issues: Array[String] = []
		check(MapValidator.validate_stage(stage,issues),str(id)+" route validation: "+str(issues))
		var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		add_child(main)
		await get_tree().process_frame
		var manager = main.enemy_manager
		check(manager.paths.size() == stage.get_paths().size(),str(id)+" every route registered")
		var roads := GridBackground.derive_stage_road_cells(stage)
		for route_id in stage.get_paths():
			var points: Array[Vector2] = []
			points.assign(stage.get_paths()[route_id])
			var cells := GridBackground.trace_road_cells(points)
			for cell in cells: check(cell.y >= 1 and cell.y <= 7,str(id)+" visible route cell "+str(cell))
			check(cells.back() == main.grid_background.base_cell,str(id)+" shared base: "+str(route_id))
			var enemy: Enemy = manager.spawn_enemy_from_data(soldier,route_id)
			check(enemy.get_parent() == manager.paths[route_id],str(id)+" explicit route "+str(route_id))
			var path: Path2D = manager.paths[route_id]
			for fraction in [.2,.45,.7,.9]:
				enemy.progress = path.curve.get_baked_length()*fraction
				check(enemy.position.distance_to(path.curve.sample_baked(enemy.progress)) < .5,str(id)+" follows own route through intersections")
			enemy.queue_free()
		for pos in stage.build_slot_positions:
			var cell := Vector2i(floori(pos.x/80),floori(pos.y/80))
			check(not roads.has(cell) and not stage.forbidden_cells.has(cell),str(id)+" legal suggested build position")
		await get_tree().process_frame
		var cycle := stage.get_normal_path_ids()
		manager.reset_path_cycle()
		for i in range(12):
			var enemy: Enemy = manager.spawn_enemy_from_data(soldier,&"auto")
			check(enemy.get_parent() == manager.paths[cycle[i%cycle.size()]],str(id)+" deterministic split "+str(i))
			enemy.queue_free()
		manager.reset_path_cycle()
		var first: Enemy = manager.spawn_enemy_from_data(soldier,&"auto")
		check(first.get_parent() == manager.paths[cycle.front()],str(id)+" resets per wave")
		first.queue_free()
		await get_tree().process_frame
		# Exercise the real WaveManager and its path_id forwarding, with no timer delay.
		var wave := WaveData.new()
		var group := EnemySpawnData.new()
		group.enemy = soldier; group.count = 6; group.spawn_interval = 0; group.path_id = &"auto"
		var fixed := EnemySpawnData.new()
		fixed.enemy = soldier; fixed.count = 2; fixed.spawn_interval = 0; fixed.path_id = cycle.back()
		wave.spawn_groups.assign([group,fixed])
		main.wave_manager.configure_waves([wave])
		main.wave_manager.start_wave(0)
		var spawned: Array[Enemy] = manager.get_alive_enemies()
		check(spawned.size() == 8,str(id)+" real wave spawns all groups")
		check(manager._path_cursor == 6,str(id)+" real wave resets distribution counter")
		var actual_counts := {}
		var expected_counts := {}
		for i in range(6):
			var target: Path2D = manager.paths[cycle[i%cycle.size()]]
			expected_counts[target] = expected_counts.get(target,0)+1
		expected_counts[manager.paths[cycle.back()]] = expected_counts.get(manager.paths[cycle.back()],0)+2
		for enemy in spawned:
			actual_counts[enemy.get_parent()] = actual_counts.get(enemy.get_parent(),0)+1
			enemy.queue_free()
		check(actual_counts == expected_counts,str(id)+" real wave route distribution")
		await get_tree().process_frame
		if number == 4:
			var boss_data := load("res://resources/enemies/yellow_turban/yellow_turban_general.tres") as EnemyData
			var boss: Enemy = manager.spawn_enemy_from_data(boss_data,&"lower")
			boss.progress = 240
			manager._summon_guards(boss)
			for guard in manager.get_alive_enemies():
				if guard != boss:
					check(guard.get_parent() == boss.get_parent() and is_equal_approx(guard.progress,180),"summons follow the boss branch when no dedicated reinforcement route")
		if number == 3:
			check(GridBackground.trace_road_cells(stage.path_points).size() > GridBackground.derive_road_cells(stage.path_points).size(),"crossing keeps both visits in movement order")
		main.queue_free()
		await get_tree().process_frame
	var editor = preload("res://addons/map_editor/map_editor_window.gd").new()
	add_child(editor)
	editor._load_stage(GameFlow.load_stage_data(&"ch01_s08").resource_path)
	var paths_before: Dictionary = editor._stage.get_paths().duplicate(true)
	for index in range(editor._route_option.item_count):
		editor._route_option.select(index)
		editor._on_route_selected(index)
		var selected: StringName = editor._route_id
		var step_before: Dictionary = editor._stage.get_paths().duplicate(true)
		editor._regenerate_path_points()
		var original_points: Array[Vector2] = []
		original_points.assign(paths_before[selected])
		var edited_points: Array[Vector2] = []
		edited_points.assign(editor._stage.get_paths()[selected])
		check(GridBackground.trace_road_cells(edited_points) == GridBackground.trace_road_cells(original_points) and edited_points.front() == original_points.front() and edited_points.back() == original_points.back(),"editor preserves route geometry and offscreen endpoints "+str(selected))
		for other in paths_before:
			if other != selected: check(editor._stage.get_paths()[other] == step_before[other],"editing one branch preserves "+str(other))
	var snap: Dictionary = editor._snapshot()
	var saved_paths: Dictionary = editor._stage.get_paths().duplicate(true)
	editor._path_cells.pop_back()
	editor._regenerate_path_points()
	editor._restore_snapshot(snap)
	check(editor._stage.get_paths() == saved_paths,"undo restores all routes")
	var save_path := "user://.map_route_roundtrip.tres"
	check(editor._save_stage(save_path) == 0,"valid multi-route stage saves")
	var reloaded := load(save_path) as StageData
	check(reloaded.get_paths() == saved_paths and reloaded.normal_path_ids == editor._stage.normal_path_ids,"saved resource retains routes and distribution")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var invalid: StageData = editor._stage.duplicate(true)
	invalid.normal_path_ids.assign([&"missing"])
	check(not MapValidator.validate_stage(invalid,[]),"validator rejects unknown route distribution")
	invalid = editor._stage.duplicate(true)
	invalid.alternate_paths[&"lower"] = PackedVector2Array([Vector2(-40,280),Vector2(120,440)])
	check(not MapValidator.validate_stage(invalid,[]),"validator rejects diagonal disconnected branch")
	editor.queue_free()
	await get_tree().process_frame
	print("MAP_ROUTE_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
