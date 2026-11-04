extends Node

var checks := 0
var failures: Array[String] = []
var slot := ""

func _ready() -> void:
	slot = "user://.roster_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(slot)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("ROSTER: " + message)

func _run() -> void:
	var expected := {
		"huang_zhong": ["孙尚香", &"wu", ["弓腰姬", "淬毒箭", "枭姬奋威"], "鹊画弓"],
		"zhou_wei": ["典韦", &"wei", ["破阵双戟", "古之恶来", "宛城死战"], "双铁戟"],
	}
	var counts := {&"wei":0, &"shu":0, &"wu":0, &"qun":0}
	for id in GameFlow.get_all_character_ids(): counts[GameFlow.load_character_data(str(id)).faction] += 1
	_check(counts == {&"wei":1, &"shu":5, &"wu":1, &"qun":2}, "四阵营分布")
	for id in expected:
		var hero := GameFlow.load_character_data(id)
		var old := load("res://tests/fixtures/roster_0.9.6.0/%s.tres" % id) as CharacterData
		_check(hero.character_id == old.character_id and hero.display_name == expected[id][0] and hero.faction == expected[id][1], "稳定键与新身份 " + id)
		_check(hero.get_skill_ids() == old.get_skill_ids() and hero.skill_params == old.skill_params, "技能ID及全部效果参数不变 " + id)
		_check(hero.profession == old.profession and hero.unlock_stage_id == old.unlock_stage_id and hero.talent_tree_ids == old.talent_tree_ids, "职业/解锁/天赋不变 " + id)
		for property in ["build_cost","base_damage","base_range","attack_interval","projectile_speed","attack_pct","range_pct_per_level","speed_pct_per_level","per_rank_crit_rate","per_rank_crit_damage","per_rank_skill_amp","rage_gain_mode"]:
			_check(hero.get(property) == old.get(property), "基础数值不变 " + id + " " + property)
		for level in [1,40,100]:
			for rank in [0,2,5]:
				_check(hero.compute_stats_at(level,rank) == old.compute_stats_at(level,rank), "实际属性不变 " + id + " Lv%d rank%d" % [level,rank])
		var ids := hero.get_skill_ids()
		for index in range(ids.size()): _check(SkillRegistry.get_skill_name(ids[index]) == expected[id][2][index], "技能名称 " + id)
		var relic := GameFlow.get_relic_for_character(id)
		_check(relic != null and relic.is_valid() and relic.display_name == expected[id][3] and not relic.is_optional_slot(), "专属信物归属 " + id)
		_check(relic.effect_lines().is_empty() and hero.compute_stats_at(40,2,relic) == hero.compute_stats_at(40,2), "新信物不改变属性 " + id)
		_check(UITheme.hud_icon_sized(str(relic.relic_id),34) != null, "新信物图标 " + id)
	_check(GameFlow.get_optional_relics().size() == 2, "可选信物仍为原两件")
	for entry in [[&"ch01_s03", "huang_zhong", "孙尚香"], [&"ch01_s05", "zhou_wei", "典韦"]]:
		var stage := GameFlow.load_stage_data(entry[0])
		_check(stage.dialogue.lines.size() == 3 and stage.dialogue.lines[0].speaker == entry[2] and stage.dialogue.lines[2].speaker == entry[2], "关卡对白新身份 " + str(entry[0]))
		_check(stage.first_clear_unlock_character_ids.has(StringName(entry[1])), "原关卡解锁键保持 " + str(entry[0]))
	var bond := load("res://resources/bonds/five_tigers.tres") as BondData
	_check(not bond.member_ids.has(&"huang_zhong") and bond.member_ids.has(&"huang_zhong_future") and is_equal_approx(bond.damage_bonus,0.06), "孙尚香不误计五虎，加成保持")
	_check(is_equal_approx(GameFlow.get_squad_bond_damage_bonus(["liu_bei","guan_yu","zhang_fei"]),0.05), "桃园加成保持")
	var p := PlayerProfile.from_dict({"schema_version":11,"characters":{
		"huang_zhong":{"total_exp":LevelCurve.exp_total_for_level(40),"rank":2,"skill_levels":{"trait_hundred_step":6,"passive_sentry":5,"char_dingjun":4},"talent_alloc":{"physical_burst.slash":2},"weapon_id":"equipment_horn_bow_1","relic_optional":"relic_taiping_yaoshu"},
		"zhou_wei":{"total_exp":LevelCurve.exp_total_for_level(35),"rank":3,"skill_levels":{"trait_vanguard":7,"char_death_fight":6,"ultimate_death_fight":5},"talent_alloc":{"armor_break.sunder":2}}
	},"squad_character_ids":["huang_zhong","zhou_wei"],"weapons":{"equipment_horn_bow_1":1},"relics":{"relic_taiping_yaoshu":true}})
	var before := p.to_dict()
	_check(ProfileStore.save_profile(p), "旧档保存")
	var restored := ProfileStore.get_profile()
	_check(restored.to_dict() == before and PlayerProfile.CURRENT_SCHEMA_VERSION == 11, "旧档全部进度及schema保持")
	for id in expected:
		_check(restored.characters[id].skill_levels == p.characters[id].skill_levels and restored.get_talent_alloc(id) == p.get_talent_alloc(id), "技能等级/天赋继承 " + id)
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._show_panel(&"develop")
	var develop = hub._panels[&"develop"]
	for id in expected:
		develop._select_character(id)
		develop._refresh()
		_check(develop._detail_name_label.text == expected[id][0], "养成旧档显示新姓名 " + id)
		_check(develop._exclusive_relic_preview.find_child("ExclusiveRelicName",true,false).text.contains(expected[id][3]), "养成信物新名称 " + id)
	hub._show_panel(&"encyclopedia")
	var enc = hub._panels[&"encyclopedia"]
	for id in expected:
		enc._apply_faction_filter(expected[id][1])
		_check(enc._character_buttons.size() == 1 and enc._selected_character_id == id, "魏吴筛选新身份 " + id)
		_check(enc._header_name_label.text == expected[id][0], "百科姓名 " + id)
		_check(enc._relic_tab.find_child("ExclusiveRelicName",true,false).text.contains(expected[id][3]), "百科新信物 " + id)
	_check(restored.to_dict() == before, "查看与筛选不改变旧档")
	hub.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(slot + suffix))
	print("ROSTER_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
