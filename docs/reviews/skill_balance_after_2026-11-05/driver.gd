extends "res://tests/BenchmarkRunner.gd"

var audit_config: Dictionary = {}
var audit_results: Array = []
var probe_results: Dictionary = {}

func _build_tower(character_base: String, rank: int, origin: Vector2) -> Tower:
	var character := load(CHARACTER_DIR + character_base + ".tres") as CharacterData
	var levels: Dictionary = {}
	for id in character.get_skill_ids(): levels[str(id)] = int(audit_config.get("skill_level", 1))
	levels.merge(audit_config.get("overrides", {}), true)
	var tower: Tower = _tower_manager.build_tower(origin, character, null, {"level": int(audit_config.get("level", CharacterRank.LEVELS[rank])), "rank": rank, "skill_levels": levels, "weapon": WeaponRegistry.get_weapon(str(audit_config.get("weapon", ""))), "talent_alloc": audit_config.get("talent_alloc",{})})
	tower.process_mode = Node.PROCESS_MODE_DISABLED
	for i in range(int(audit_config.get("battle_rank", 0))): tower.apply_battle_rank(0)
	return tower

func _run() -> void:
	ProfileStore.create_new_profile(false)
	GameFlow.squad_character_ids = []
	GameFlow.clear_squad_relics()
	GameManager.reset(999999, 20, 1)
	_build_environment()
	await _probes()
	var ids := ["guan_yu", "zhang_fei", "huang_zhong", "huang_fu_song", "zhuge_liang", "zhao_yun", "zhou_wei"]
	for id in ids:
		for count in [1, 3]:
			for setup in [{"level":1,"rank":0,"skill_level":1},{"level":20,"rank":1,"skill_level":1},{"level":40,"rank":2,"skill_level":1},{"level":100,"rank":5,"skill_level":1},{"level":100,"rank":5,"skill_level":10}]:
				await _measure(id, setup, count, 20)
		var character := GameFlow.load_character_data(id)
		for skill in character.get_skill_ids():
			await _measure(id, {"level":40,"rank":2,"skill_level":1,"overrides":{str(skill):10}}, 1, 20)
		if id in ["guan_yu","zhao_yun","zhou_wei"]:
			for armor in [0, 60]: await _measure(id, {"level":100,"rank":5,"skill_level":10}, 1, armor)
		if id in ["zhao_yun","huang_fu_song","zhuge_liang"]:
			for count in [5, 10]: await _measure(id, {"level":40,"rank":2,"skill_level":1}, count, 20)
	for id in ["", "liu_bei", "diao_chan"]:
		for battle in [0, 3]:
			for skill_level in [1,10]: await _support(id,battle,skill_level)
	var result := {"program":"0.9.6.3","seconds":WINDOW_SECONDS,"samples":SAMPLES,"delta":VIRTUAL_DELTA,"probes":probe_results,"measurements":audit_results}
	var file := FileAccess.open("res://docs/reviews/skill_balance_after_2026-11-05.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_profile_file + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_profile_file + suffix))
	print("AUDIT_COMPLETE rows=%d" % audit_results.size())
	get_tree().quit()

func _measure(id: String, setup: Dictionary, count: int, armor: int) -> void:
	audit_config = setup
	var damages: Array = []
	var ults: Array = []
	var attack := 0
	var interval := 0.0
	var fear_ticks := 0
	for sample in range(SAMPLES):
		seed(20261105 + sample)
		var group := _make_group(id,int(setup.rank),count,10000000,armor,[] as Array[StringName])
		# Keep every target in range, with 10px spacing. No target dies.
		var tower: Tower = group.tower
		attack = tower.damage
		interval = tower.attack_cooldown
		var middle := tower.global_position.x + maxf(tower.range_radius * 0.65, tower._min_range + 10.0)
		middle = minf(middle, tower.global_position.x + tower.range_radius - 10.0)
		for i in range(count):
			var enemy: Enemy = group.dummies[i]
			if setup.has("target_hp_ratio"): enemy.current_hp = roundi(enemy.max_hp * float(setup.target_hp_ratio))
			var x := middle - float(count - 1 - i) * 10.0
			enemy.set_meta("bench_home_x", x)
			enemy.set_meta("bench_home_pos", Vector2(x,tower.global_position.y))
			enemy.progress = x
			enemy.global_position = Vector2(x,tower.global_position.y)
		for tick in range(WINDOW_TICKS):
			_drive_groups([group],VIRTUAL_DELTA)
			_drive_dummies([group],VIRTUAL_DELTA)
			_drive_bullets(VIRTUAL_DELTA)
			if id == "zhang_fei" and (group.dummies[0] as Enemy)._fear_time_left > 0.0: fear_ticks += 1
			_reanchor_dummies([group])
		damages.append(float(_group_damage(group))/WINDOW_SECONDS)
		ults.append(group.ult_count)
		await _teardown_window()
	var row := {"character":id,"setup":setup,"targets":count,"armor":armor,"attack":attack,"interval":interval,"dps":_avg(damages),"dps_samples":damages,"ults":_avg(ults),"ult_samples":ults,"fear_uptime":float(fear_ticks)/(WINDOW_TICKS*SAMPLES)}
	audit_results.append(row)
	print("AUDIT_ROW "+JSON.stringify(row))

func _support(id: String, battle: int, skill_level: int, followers: int = 3) -> void:
	audit_config = {"level":40,"battle_rank":battle,"skill_level":skill_level}
	var damages: Array = []
	var ult_counts: Array = []
	for sample in range(SAMPLES):
		seed(20261105+sample)
		var group := _make_group("guan_yu",2,1,10000000,20,[] as Array[StringName])
		var groups := [group]
		for i in range(followers - 1):
			var ally := _build_tower("guan_yu",2,(group.tower as Tower).global_position+Vector2(0,15*(i+1)))
			ally.target=group.dummies[0]
			groups.append({"tower":ally,"dummies":[],"remaining":0.0,"ult_count":0,"respawn_hp":0})
		if not id.is_empty():
			var support := _build_tower(id,2,(group.tower as Tower).global_position+Vector2(0,-20))
			support.target=group.dummies[0]
			groups.append({"tower":support,"dummies":[],"remaining":0.0,"ult_count":0,"respawn_hp":0})
		_simulate_window(groups)
		var damage := 0
		for value in (group.dummies[0] as Enemy).damage_contributors.values(): damage+=int(value)
		damages.append(float(damage)/WINDOW_SECONDS)
		ult_counts.append(groups.back().ult_count if not id.is_empty() else 0)
		await _teardown_window()
	var row := {"support":id,"battle_rank":battle,"skill_level":skill_level,"followers":followers,"level":40,"rank":2,"armor":20,"team_dps":_avg(damages),"support_ults":_avg(ult_counts),"dps_samples":damages}
	audit_results.append(row)
	print("AUDIT_ROW "+JSON.stringify(row))

func _probes() -> void:
	var zero_growth: Dictionary = {}
	for id in ["guan_yu","huang_zhong"]:
		var skill := "passive_green_dragon_stance" if id=="guan_yu" else "passive_sentry"
		var character := GameFlow.load_character_data(id)
		zero_growth[skill] = {"lv1":SkillRegistry.effect_breakdown(character,StringName(skill),1,0),"lv10":SkillRegistry.effect_breakdown(character,StringName(skill),10,0)}
	probe_results.zero_growth = zero_growth
	var enemy := _spawn_dummy(_paths[0],300,100000,0,[] as Array[StringName])
	enemy.apply_slow(0.4,2.0)
	for i in range(500):
		enemy._process(0.02)
		if i % 12 == 0: enemy.apply_slow(0.92,0.5)
	probe_results.weak_slow_refresh = {"after_seconds":10,"expected_factor":0.92,"actual_factor":enemy.slow_factor,"remaining":enemy._slow_time_left}
	await _teardown_window()
