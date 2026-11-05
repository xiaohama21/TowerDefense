extends "res://tests/SkillKitRunner.gd"

var checks := 0

func _check(ok: bool, message: String) -> void:
	checks += 1
	super._check(ok, message)

func _run() -> void:
	ProfileStore.create_new_profile(false)
	GameFlow.squad_character_ids = []
	GameFlow.clear_squad_relics()
	GameManager.reset(99999, 20, 1)
	_path = Path2D.new()
	_path.curve = Curve2D.new()
	_path.curve.add_point(Vector2.ZERO)
	_path.curve.add_point(Vector2(2000, 0))
	add_child(_path)
	_test_growth_and_costs()
	_test_refunds()
	_test_forced_and_poison()
	_clear()
	_test_rage_caps()
	_clear()
	_test_slow_sources()
	_clear()
	_test_boss_resistance()
	_clear()
	_path.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("SKILL_BALANCE_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_growth_and_costs() -> void:
	var expected := {"passive_warm_wine": ["guan_yu", "speed_bonus", .308], "passive_yanhan": ["zhang_fei", "kill_rage", 4.62], "trait_vanguard": ["zhou_wei", "penetration", .231], "passive_worship_moon": ["diao_chan", "skill_amp", .086], "passive_momentum": ["zhuge_liang", "amp_cap", .172]}
	for id in expected:
		var entry: Array = expected[id]
		_check(is_equal_approx(SkillRegistry.effect_value(GameFlow.load_character_data(entry[0]), StringName(id), entry[1], 10, 0), entry[2]), "满级预算 " + id)
	for character_id in GameFlow.get_all_character_ids():
		var hero := GameFlow.load_character_data(character_id)
		for id in hero.get_skill_ids():
			var total := 0
			for level in range(1, 10): total += SkillRegistry.upgrade_cost(level, id)
			_check(total == (9 if str(id) in SkillRegistry.CHEAP_SKILLS else 25), "逐技能总书耗 " + str(id))
	var profile := PlayerProfile.new()
	profile.unlock_character("guan_yu")
	profile.characters.guan_yu.rank = 2
	profile.characters.guan_yu.skill_levels.passive_warm_wine = 9
	profile.add_item("skill_book", 1)
	_check(profile.skill_upgrade_status("guan_yu", &"passive_warm_wine") == "升级" and profile.upgrade_skill("guan_yu", &"passive_warm_wine") and profile.items.skill_book == 0, "实际升级按1本扣款")
	var moon := _tower("diao_chan", 2, {"passive_worship_moon": 10})
	moon.apply_battle_rank(0); moon.apply_battle_rank(0); moon.apply_battle_rank(0)
	_check(is_equal_approx(moon.skill_amp - moon._base_skill_amp, .086), "拜月战斗不自乘")
	_clear()

func _test_refunds() -> void:
	var raw := {"schema_version": 11, "items": {"skill_book": 7, "general_seal": 9}, "characters": {}, "exp_pool": 77}
	for character_id in GameFlow.get_all_character_ids():
		var levels := {}
		for id in GameFlow.load_character_data(character_id).get_skill_ids(): levels[str(id)] = 10
		raw.characters[character_id] = {"rank": 5, "skill_levels": levels, "total_exp": LevelCurve.exp_total_for_level(100), "talent_alloc": {}}
	var before := raw.duplicate(true)
	var result: Dictionary = ProfileStore._migrate_to_current(raw)
	_check(result.ok and result.data.items.skill_book == 119, "七项满级共退112本")
	_check(raw == before and result.data.characters == before.characters and result.data.items.general_seal == 9 and result.data.exp_pool == 77, "迁移副本并保留等级/进度")
	_check(ProfileStore._migrate_to_current(result.data).data == result.data, "schema12重复加载不再退款")
	var partial := {"schema_version": 11, "items": {"skill_book": 0}, "characters": {"guan_yu": {"rank": 2, "skill_levels": {"passive_warm_wine": 5, "foreign": 10}}, "zhang_fei": {"rank": 1, "skill_levels": {"passive_yanhan": 10}}, "zhou_wei": {"rank": 2, "skill_levels": {"trait_vanguard": 999}}, "zhuge_liang": {"rank": 2, "skill_levels": {"passive_momentum": 2.5}}, "missing": {"rank": 5, "skill_levels": {"passive_warm_wine": 10}}}}
	_check(ProfileStore._migrate_to_current(partial).data.items.skill_book == 2, "部分退款且未知/未解锁/非法无返书")
	_check(ProfileStore._migrate_to_current({"schema_version":11,"characters":{"guan_yu":{"rank":2,"skill_levels":{"passive_warm_wine":10}}}}).data.items.skill_book == 16, "缺少items字段仍补齐退款")
	var file := FileAccess.open(_slot, FileAccess.WRITE)
	file.store_string(JSON.stringify(before)); file.close()
	ProfileStore.profile = null
	var loaded := ProfileStore.load_profile()
	_check(loaded.items.skill_book == 119 and FileAccess.file_exists(_slot + ".bak"), "旧档落盘与备份")
	ProfileStore.profile = null
	_check(ProfileStore.load_profile().items.skill_book == 119, "重启加载不重复退款")
	var saved := FileAccess.get_file_as_string(_slot)
	ProfileStore._writes_blocked = true
	var candidate := loaded.duplicate_profile()
	candidate.items.skill_book += 50
	_check(not ProfileStore.save_profile(candidate) and FileAccess.get_file_as_string(_slot) == saved and ProfileStore.profile.items.skill_book == 119, "拒绝保存不修改磁盘或live")
	ProfileStore._writes_blocked = false
	_check(not ProfileStore._migrate_to_current({"schema_version": 13}).ok, "高版本不迁移退款")

func _test_forced_and_poison() -> void:
	var guan := _tower("guan_yu", 2, {"passive_green_dragon_stance": 10})
	guan.crit_damage = 2.0
	guan.skill_amp = 5.0
	_check(guan.attack_hit_damage(100, .99) == 100, "非必暴击保持")
	guan.skill_hit_counter = 2
	_check(guan.attack_hit_damage(100, .99) == 254, "必暴Lv10为254且不吃技能增幅")
	guan.skill_hit_counter = 3
	guan.crit_rate = .5
	_check(guan.attack_hit_damage(100, 0) == 200, "普通随机暴击不获得青龙势增伤")
	var sun := _tower("huang_zhong", 2, {"passive_sentry": 10})
	sun.skill_amp = 0.0
	var enemy := _enemy(1000, Vector2(100, 0), 999)
	enemy.apply_vulnerability(3, 99)
	SkillRegistry.on_attack_hit(sun, enemy, 1)
	_check(is_equal_approx(enemy.poison_dps, 25.4), "真实施加毒秒伤25.4")
	for i in range(150): enemy._tick_status_damage(.02)
	_check(enemy.current_hp == 924 and enemy.poison_dps == 0, "三秒76伤害，小数累计且绕过甲/易伤")
	var hero := GameFlow.load_character_data("guan_yu")
	_check(is_equal_approx(SkillRegistry.effect_value(hero, &"passive_green_dragon_stance", "forced_bonus_per_level", 10, 5), .27), "必暴面板27%")
	_check(SkillRegistry.format_effect_value("poison_dps",25.4) == "25.4/秒", "面板保留小数")

func _test_rage_caps() -> void:
	var guan := _tower("guan_yu", 0)
	guan.gain_rage_for_attack(50)
	_check(is_equal_approx(guan.rage, 9), "低伤积怒不变")
	guan.rage = 0; guan.gain_rage_for_attack(10000)
	_check(is_equal_approx(guan.rage, 16), "高伤单次4+12")
	guan.rage = 0; guan.notify_aoe_damage_dealt(10000)
	_check(is_equal_approx(guan.rage, 16), "AOE一次积怒")
	var zhao := _tower("zhao_yun", 0)
	zhao.gain_rage_for_attack(10000)
	_check(is_equal_approx(zhao.rage, 20), "赵云独立4+16上限")
	guan.rage = 0; guan._tech_rage_gain_pct = .2; guan.gain_rage_for_attack(10000)
	_check(is_equal_approx(guan.rage, 19.2), "封顶后合法倍率")
	guan.grant_rage_flat(10)
	_check(is_equal_approx(guan.rage, 29.2), "固定返怒不受伤害封顶")
	var victim := _enemy()
	guan.rage = 0; guan.target = victim
	SkillRegistry.execute_ultimate(&"char_green_dragon", guan)
	_check(guan.rage == 0, "非击杀技能不重复积怒")

func _test_slow_sources() -> void:
	var enemy := _enemy()
	enemy.apply_slow(.4, 2, "zhang:ultimate")
	for i in range(500):
		enemy._process(.02)
		if i % 12 == 0: enemy.apply_slow(.92, .5, "zhuge:aura")
	_check(is_equal_approx(enemy.slow_factor, .92), "弱源不延长强源")
	enemy._process(.6)
	_check(enemy.slow_factor == 1 and not enemy.is_controlled(), "所有来源到期恢复")
	enemy.apply_slow(.4, 2)
	enemy.apply_slow(.92, 10)
	enemy._process(2.01)
	_check(is_equal_approx(enemy.slow_factor, .92), "无source兼容强弱独立")
	var tower := _tower("zhuge_liang", 1)
	var key := SkillRegistry.slow_source(tower, &"trait_star_gazer")
	var clone := _tower("zhuge_liang", 1)
	_check(key != SkillRegistry.slow_source(clone, &"trait_star_gazer"), "同将多塔来源独立")
	enemy.apply_slow(.3, 1, key)
	tower.queue_free()
	enemy._process(.5)
	_check(is_equal_approx(enemy.slow_factor, .3), "卖塔已施加状态保留剩余时长")
	enemy._process(.6)
	_check(is_equal_approx(enemy.slow_factor, .92), "卖塔不再续期强减速")

func _test_boss_resistance() -> void:
	for phase in [1, 2, 3, 4]:
		var enemy := _enemy()
		enemy.tags.assign([&"boss"]); enemy.phase_index = phase
		var factor := 1.0 if phase == 1 else (.7 if phase == 2 else .4)
		enemy.apply_slow(.4, 10, "test")
		enemy.apply_poison(25.4, 10, "huang_zhong")
		enemy.apply_burn(20, 10)
		enemy.apply_vulnerability(.3, 10)
		enemy.apply_reveal(10)
		enemy.apply_stun(10)
		enemy.apply_fear(10)
		for remaining in [enemy._slow_time_left, enemy._poison_time_left, enemy._burn_time_left, enemy._vulnerability_time_left, enemy._forced_reveal_left, enemy._stun_time_left, enemy._fear_time_left]:
			_check(is_equal_approx(remaining, 10 * factor), "Boss七状态阶段时长 P%d" % phase)
		_check(is_equal_approx(enemy.poison_dps,25.4) and enemy.burn_dps == 20 and is_equal_approx(enemy.slow_factor,.4), "阶段只减时长 P%d" % phase)
	var chained := _enemy()
	chained.tags.assign([&"boss"]); chained.phase_index = 3
	chained.apply_fear(1, .4, 2, "zhang:ultimate")
	chained._process(.401)
	_check(is_equal_approx(chained._slow_time_left, .8), "恐惧随附减速只折减一次")
	var normal := _enemy(); normal.phase_index = 3; normal.apply_slow(.4, 10)
	_check(normal._slow_time_left == 10, "普通敌人无Boss阶段抗性")
