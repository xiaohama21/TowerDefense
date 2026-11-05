extends "res://tests/BenchmarkRunner.gd"

## 0.9.7天赋强度实测：L100红阶，技能Lv1，真实60秒攻击/怒气/技能，护甲20。
## 合法单树20点与均摊三树40点+首套武器；状态/穿甲/目标条件进入真实管线。
var rows: Array = []
var prior_manual := false

func _run() -> void:
	ProfileStore.create_new_profile(false)
	GameFlow.clear_squad_relics(); GameFlow.squad_character_ids = []
	GameFlow.selected_difficulty = Difficulty.NORMAL
	prior_manual = GameFlow.is_gameplay_flag_enabled("manual_ultimate")
	GameFlow.set_gameplay_flag("manual_ultimate", false)
	GameManager.reset(1000000, 999, 1)
	_build_environment()
	for id in ["guan_yu", "zhang_fei", "huang_zhong", "huang_fu_song", "zhao_yun", "zhou_wei", "zhuge_liang"]:
		var options: Array[String] = ["bare"]
		options.append_array(TalentRegistry.tree_ids(id)); options.append("mixed_gear_talents")
		var collected := {}
		for sample in range(SAMPLES):
			GameManager.gold = 1000000
			var groups: Array = []
			for count in [1, 3]:
				for option in options:
					var group := _make_group(id, 5, count, 1000000, 20, [&"yellow_turban", &"elite"] as Array[StringName])
					var loadout := _loadout(id, option)
					(group.tower as Tower).apply_character(GameFlow.load_character_data(id), loadout)
					group["key"] = "%s.%s.%d" % [id, option, count]
					group["option"] = option; group["count"] = count; group["points"] = TalentRegistry.spent(loadout.talent_alloc)
					groups.append(group)
			seed(20261105 + sample)
			_simulate_window(groups)
			for group in groups:
				if not collected.has(group.key): collected[group.key] = {"hero": id, "option": group.option, "targets": group.count, "points": group.points, "damage": [], "ultimates": []}
				collected[group.key].damage.append(float(_group_damage(group)) / WINDOW_SECONDS)
				collected[group.key].ultimates.append(group.ult_count)
			await _teardown_window()
		for key in collected:
			var row: Dictionary = collected[key]
			row["dps"] = _avg(row.damage); row["ults"] = _avg(row.ultimates)
			var base_key := "%s.bare.%d" % [id, row.targets]
			row["ratio"] = float(row.dps) / _avg(collected[base_key].damage)
			_check(row.dps > 0 and is_finite(row.ratio), "输出组合有效 " + key)
			rows.append(row)
		print("TALENT_DAMAGE_HERO " + id)
	await _support_rows()
	var report_path := "res://build/talent_combat_balance_latest.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-path="): report_path = argument.trim_prefix("--report-path=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"program": ProjectSettings.get_setting("application/config/version"), "level": 100, "rank": 5, "skill_level": 1, "seconds": WINDOW_SECONDS, "samples": SAMPLES, "armor": 20, "target_tags": ["elite", "yellow_turban"], "rows": rows, "failures": failures}, "\t")); file.close()
	for child in get_children(): child.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_profile_file + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_profile_file + suffix))
	GameFlow.set_gameplay_flag("manual_ultimate", prior_manual)
	print("TALENT_BALANCE_RESULT: %s rows=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", rows.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _loadout(id: String, option: String) -> Dictionary:
	var profile := PlayerProfile.new()
	profile.unlock_character(id, {"total_exp": LevelCurve.exp_total_for_level(100), "rank": 5})
	var trees := TalentRegistry.tree_ids(id)
	if option == "mixed_gear_talents":
		for point in range(40): _spend(profile, id, trees[point % trees.size()], 1)
		var weapons := WeaponRegistry.for_character(GameFlow.load_character_data(id))
		if not weapons.is_empty():
			profile.add_weapon(str(weapons[0].weapon_id)); profile.set_character_weapon(id, str(weapons[0].weapon_id))
	elif option != "bare": _spend(profile, id, option, 20)
	_check(TalentRegistry.spent(profile.get_talent_alloc(id)) <= 40, "点数预算合法")
	return GameFlow.get_battle_loadout(profile, id)

func _spend(profile: PlayerProfile, id: String, tree_id: String, budget: int) -> void:
	var left := budget
	for node in TalentRegistry.get_tree_data(tree_id).nodes:
		var key := str(node.id)
		while left > 0 and profile.talent_allocation_status(id, key) == "分配":
			_check(profile.allocate_talent(id, key, int(profile.get_talent_alloc(id).get(key, 0))), "合法天赋分配")
			left -= 1

func _support_rows() -> void:
	for id in ["liu_bei", "diao_chan"]:
		var measured := {}
		for option in ["bare", "mixed_gear_talents"]:
			var values: Array = []
			for sample in range(SAMPLES):
				GameManager.gold = 1000000
				var group := _make_support_group(id, 5)
				(group.support_tower as Tower).apply_character(GameFlow.load_character_data(id), _loadout(id, option))
				var groups: Array = [group, {"tower": group.support_tower, "dummies": [], "character_id": id, "remaining": 0.0, "ult_count": 0, "respawn_hp": 0, "respawn_timer": 0.0}]
				seed(20261105 + sample)
				_simulate_window(groups)
				values.append(float(_group_damage(group)) / WINDOW_SECONDS)
				await _teardown_window()
			measured[option] = _avg(values)
			rows.append({"hero": id, "option": option, "receiver": "guan_yu_L1_white", "receiver_dps": measured[option], "ratio": measured[option] / measured.bare, "damage": values})
		_check(measured.mixed_gear_talents >= measured.bare, "辅助组合提升接收者输出 " + id)
