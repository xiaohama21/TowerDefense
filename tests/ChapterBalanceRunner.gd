extends "res://tests/BenchmarkRunner.gd"

const ENEMY_MANAGER := preload("res://scripts/EnemyManager.gd")
var chapter_rows: Array = []
var chapter_manager: Node
var chapter_path: Path2D
var chapter_fork: Path2D
var chapter_stage: StageData
var slots: Array[Vector2] = []
var chapter_groups: Array = []
var squad: Array[String] = []
var chapter_level := 20
var spend := 0
var build_index := 0
var next_economy := 0.0
var seed_offset := 0

func _run() -> void:
	ProfileStore.create_new_profile(false)
	GameFlow.clear_squad_relics()
	GameFlow.selected_difficulty = Difficulty.NORMAL
	var prior_manual := GameFlow.is_gameplay_flag_enabled("manual_ultimate")
	GameFlow.set_gameplay_flag("manual_ultimate", false)
	for stage_number in range(1, 9):
		for level in [20, 30]:
			await _simulate_stage(stage_number, level)
	var report_path := "res://build/chapter_balance_latest.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-path="): report_path = argument.trim_prefix("--report-path=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"program": ProjectSettings.get_setting("application/config/version"), "rank": 1, "skill_level": 1, "equipment": "none", "talents": "none", "supplies": "none", "difficulty": "normal", "delta": VIRTUAL_DELTA, "rows": chapter_rows}, "\t")); file.close()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_profile_file + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_profile_file + suffix))
	GameFlow.set_gameplay_flag("manual_ultimate", prior_manual)
	print("CHAPTER_BALANCE_RESULT: %s rows=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", chapter_rows.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _simulate_stage(number: int, level: int) -> void:
	chapter_stage = GameFlow.load_stage_data(StringName("ch01_s%02d" % number))
	chapter_level = level
	GameManager.reset(chapter_stage.starting_currency, chapter_stage.starting_lives, chapter_stage.waves.size())
	GameManager.set_battle_session(BattleSession.new(chapter_stage.stage_id))
	var choices := [["guan_yu", "liu_bei"], ["guan_yu", "liu_bei"], ["guan_yu", "zhang_fei", "liu_bei"], ["guan_yu", "huang_zhong", "huang_fu_song", "liu_bei"], ["guan_yu", "huang_zhong", "huang_fu_song", "diao_chan"], ["guan_yu", "zhou_wei", "huang_fu_song", "huang_zhong"], ["zhao_yun", "zhou_wei", "huang_fu_song", "huang_zhong"], ["guan_yu", "zhao_yun", "huang_fu_song", "zhuge_liang"]]
	squad.assign(choices[number - 1]); GameFlow.squad_character_ids.assign(squad)
	chapter_path = _new_path("Path2D", chapter_stage.path_points)
	if not chapter_stage.fork_path_points.is_empty(): chapter_fork = _new_path("ForkPath", chapter_stage.fork_path_points)
	chapter_manager = ENEMY_MANAGER.new(); chapter_manager.name = "EnemyManager"; add_child(chapter_manager)
	chapter_manager.path = chapter_path; chapter_manager.fork_path = chapter_fork; chapter_manager.set_process(false)
	_tower_manager = TOWER_MANAGER_SCRIPT.new(); add_child(_tower_manager)
	var road := GridBackground.derive_road_cells(chapter_stage.path_points)
	road.append_array(GridBackground.derive_road_cells(chapter_stage.fork_path_points))
	slots.clear()
	for position in chapter_stage.build_slot_positions:
		var cell := Vector2i(floori(position.x / 80), floori(position.y / 80))
		if not road.has(cell) and not chapter_stage.forbidden_cells.has(cell): slots.append(position)
	chapter_groups.clear(); spend = 0; build_index = 0; next_economy = 0
	seed(20261105 + number + seed_offset)
	var seconds := 0.0
	var cleared := 0
	var waves: Array = []
	for wave in chapter_stage.waves:
		if GameManager.lives <= 0: break
		_check(GameManager.start_wave(), "正常开波 " + str(chapter_stage.stage_id))
		var schedule: Array = []
		var spawn_time := 0.0
		for group in wave.spawn_groups:
			for i in range(group.count):
				schedule.append({"at": spawn_time, "enemy": group.enemy})
				spawn_time += group.spawn_interval
		var cursor := 0
		var wave_time := 0.0
		while wave_time < 400 and GameManager.lives > 0:
			while cursor < schedule.size() and float(schedule[cursor].at) <= wave_time:
				chapter_manager.spawn_enemy_from_data(schedule[cursor].enemy); cursor += 1
			if wave_time >= next_economy:
				_use_budget(); next_economy = wave_time + .5
			_drive_groups(chapter_groups, VIRTUAL_DELTA)
			_drive_bullets(VIRTUAL_DELTA)
			chapter_manager._process(VIRTUAL_DELTA)
			for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
				node.set_process(false); node._process(VIRTUAL_DELTA)
			GameManager._process(VIRTUAL_DELTA)
			wave_time += VIRTUAL_DELTA
			if cursor >= schedule.size() and get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP).is_empty(): break
		seconds += wave_time; next_economy = 0
		waves.append({"wave": cleared + 1, "seconds": wave_time, "lives": GameManager.lives, "gold": GameManager.gold})
		if GameManager.lives <= 0 or wave_time >= 400: break
		GameManager.gold += wave.completion_currency
		GameManager.wave_completed(); cleared += 1
		await get_tree().process_frame
	var row := {"stage": str(chapter_stage.stage_id), "level": level, "squad": squad.duplicate(), "cleared": cleared, "waves": chapter_stage.waves.size(), "victory": cleared == chapter_stage.waves.size() and GameManager.lives > 0, "lives": GameManager.lives, "seconds": seconds, "gold": GameManager.gold, "spent": spend, "towers": chapter_groups.size(), "wave_results": waves}
	_validate_stage_row(row)
	chapter_rows.append(row); print("CHAPTER_ROW " + JSON.stringify(row))
	for child in get_children(): child.queue_free()
	await get_tree().process_frame
	chapter_fork = null; chapter_groups.clear()

func _validate_stage_row(row: Dictionary) -> void:
	_check(row.victory and GameManager.gold >= 0, "首章合法预算通关 %s Lv%d" % [chapter_stage.stage_id, row.level])

func _new_path(label: String, points: Array[Vector2]) -> Path2D:
	var path := Path2D.new(); path.name = label; path.curve = Curve2D.new()
	for point in points: path.curve.add_point(point)
	add_child(path); return path

func _use_budget() -> void:
	if chapter_groups.size() < chapter_stage.recommended_tower_count and not slots.is_empty():
		var id := squad[build_index % squad.size()]
		var hero := GameFlow.load_character_data(id)
		if GameManager.gold >= hero.build_cost:
			var best := 0; var score := -1.0
			var stats := hero.compute_stats_at(chapter_level, 1)
			for i in range(slots.size()):
				var coverage := 0.0
				for path in [chapter_path, chapter_fork]:
					if path == null: continue
					var length: float = path.curve.get_baked_length()
					for j in range(int(length / 40)):
						var distance: float = slots[i].distance_to(path.curve.sample_baked(j * 40.0))
						if distance <= float(stats.range) and distance >= float(stats.min_range): coverage += 1.0
				if coverage > score: score = coverage; best = i
			var tower: Tower = _tower_manager.build_tower(slots[best], hero, null, {"level": chapter_level, "rank": 1})
			tower.process_mode = Node.PROCESS_MODE_DISABLED
			chapter_groups.append({"tower": tower, "remaining": 0.0, "ult_count": 0})
			spend += hero.build_cost; build_index += 1; slots.remove_at(best)
			return
	if chapter_groups.size() >= chapter_stage.recommended_tower_count or slots.is_empty():
		for entry in chapter_groups:
			var tower: Tower = entry.tower
			var before := GameManager.gold
			if _tower_manager.upgrade_tower(tower, chapter_stage): spend += before - GameManager.gold; return
