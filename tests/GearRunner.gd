extends Node

var failures: Array[String] = []
var checks := 0
var _slot := ""
const HEROES := {"tiger_guard":"zhang_fei", "cavalry":"zhao_yun", "archer":"huang_zhong", "strategist":"zhuge_liang", "dancer":"diao_chan", "catapult":"huang_fu_song"}
const TOWER := preload("res://scenes/Tower.tscn")
const ENEMY := preload("res://scenes/Enemy.tscn")

func _ready() -> void:
	_slot = "user://.gear_test_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("GEAR: " + message)

func _near(a: float, b: float, message: String) -> void:
	_check(absf(a-b) < 0.001, "%s (%s / %s)" % [message, a, b])

func _tower(id: String, weapon: WeaponData, level: int = 1, rank: int = 0) -> Tower:
	var tower := TOWER.instantiate() as Tower
	add_child(tower)
	tower.set_process(false)
	tower.apply_character(GameFlow.load_character_data(id), {"level":level, "rank":rank, "weapon":weapon})
	return tower

func _run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	GameFlow.squad_character_ids = []
	GameFlow.clear_squad_relics()
	GameManager.reset(99999, 20, 1)
	_test_catalog()
	_test_inventory()
	_test_migration()
	_test_rewards(profile)
	_test_stats()
	_test_affix_values()
	await _test_ui()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("GEAR_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_catalog() -> void:
	_check(WeaponRegistry.IDS.size() == 12, "12款凡品")
	for profession in HEROES:
		var character := GameFlow.load_character_data(str(HEROES[profession]))
		var weapons := WeaponRegistry.for_character(character)
		_check(weapons.size() == 2, "职业双款 " + str(profession))
		for weapon in weapons:
			_check(weapon.is_valid() and weapon.rarity == ItemData.Rarity.COMMON and weapon.shop_price == 120, "合法凡品/价格 " + str(weapon.weapon_id))
			_check(weapon.icon != null and WeaponRegistry.effect_rows(weapon).size() == 2, "图徽与两词条")
			_check(GameFlow.load_item_data(str(weapon.weapon_id)) == weapon, "背包统一加载")
			var stage := GameFlow.load_stage_data(weapon.unlock_stage_id)
			_check(stage.first_clear_weapons.has(weapon), "掉落关与元数据同源")
	_near(float(WeaponRegistry.effect_rows(WeaponRegistry.get_weapon("equipment_mulberry_bow_1"))[1][1]), 60, "弹道显示60")

func _test_inventory() -> void:
	var p := PlayerProfile.new()
	for id in ["liu_bei", "zhang_fei", "zhou_wei", "guan_yu"]: p.unlock_character(id)
	var id := "equipment_ring_blade_1"
	_check(not p.set_character_weapon("zhang_fei", id), "未拥有拒绝")
	p.add_weapon(id)
	_check(p.set_character_weapon("zhang_fei", id), "免费装备")
	_check(p.weapon_count(id) == 1 and p.weapon_available(id) == 0, "持有含已装配")
	_check(not p.set_character_weapon("liu_bei", id), "一件不可供两将")
	_check(not p.set_character_weapon("guan_yu", id), "跨职业拒绝")
	p.add_weapon(id)
	_check(p.set_character_weapon("liu_bei", id), "重复件供同职业第二将")
	_check(p.set_character_weapon("zhang_fei", "") and p.weapon_available(id) == 1, "卸下不丢库存")
	p.add_weapon(id, 4)
	_check(p.weapon_count(id) == 3 and int(p.items.get("general_seal", 0)) == 6, "上限3超额3件转6将印")
	var before := p.to_dict()
	p.add_weapon("bad", 4)
	_check(p.to_dict() == before, "未知武器拒绝")
	var copy := p.duplicate_profile()
	_check(copy.to_dict() == p.to_dict(), "副本保留装配/库存")

func _test_migration() -> void:
	var raw := {"schema_version":8, "characters":{"zhang_fei":{"total_exp":1340, "rank":2, "skill_levels":{"char_dangyang_roar":8}, "weapon_id":"equipment_ring_blade_1"}, "liu_bei":{"weapon_id":"equipment_ring_blade_1"}, "guan_yu":{"weapon_id":"equipment_ring_blade_1"}, "zhou_wei":{"weapon_id":"equipment_ring_blade_1"}}, "weapons":{"equipment_ring_blade_1":2, "equipment_long_spear_1":1e100, "equipment_horn_bow_1":-5, "equipment_silk_bells_1":true, "unknown":3}, "items":{"skill_book":20}, "exp_pool":321}
	var migrated := ProfileStore._migrate_to_current(raw)
	_check(migrated.ok and migrated.data.schema_version == 9, "v8→v9")
	var p := PlayerProfile.from_dict(migrated.data)
	_check(p.weapon_count("equipment_long_spear_1") == 3 and p.weapons.size() == 2, "非法数量/未知ID归一")
	_check(p.get_character_weapon_id("guan_yu").is_empty() and p.get_character_weapon_id("zhou_wei").is_empty(), "职业与超配归一")
	_check(p.get_character_weapon_id("liu_bei") != "" and p.get_character_weapon_id("zhang_fei") != "", "排序保留合法占用")
	_check(p.get_character_exp("zhang_fei") == 1340 and p.get_character_rank("zhang_fei") == 2 and p.get_skill_level("zhang_fei", &"char_dangyang_roar") == 8 and p.exp_pool == 321, "成长数据不变")
	_check(PlayerProfile.from_dict(ProfileStore._migrate_to_current(p.to_dict()).data).to_dict() == p.to_dict(), "迁移幂等")
	var legacy := PlayerProfile.from_dict(ProfileStore._migrate_to_current({"schema_version":8, "characters":{"guan_yu":{}}, "stage_progress":{"ch01_s02":{"completed":true}}}).data)
	_check(legacy.weapons.is_empty() and legacy.get_character_weapon_id("guan_yu").is_empty(), "旧首通不补发")
	for key in ["yuanbao", "lord_exp", "shop_purchases", "talent_alloc"]: _check(not legacy.to_dict().has(key), "不预置0.9.4容器 " + key)
	_check(not ProfileStore._migrate_to_current({"schema_version":9, "weapons":[]}).ok, "当前schema错误容器拒绝")

func _test_rewards(p: PlayerProfile) -> void:
	GameFlow.selected_difficulty = Difficulty.HARD
	var stage := GameFlow.load_stage_data(&"ch01_s08")
	var session := BattleSession.new("ch01_s08", [], "gear_first")
	GameFlow.collect_stage_rewards(session, stage, true)
	_check(session.get_pending_weapons().size() == 3 and session.get_pending_weapons().values().all(func(v):return v == 1), "多款首通各1困难不翻倍")
	_check(p.weapons.is_empty(), "收集阶段不改live库存")
	var restored := BattleSession.from_dict(session.to_dict())
	_check(restored.get_pending_weapons() == session.get_pending_weapons(), "会话往返")
	session.mark_victory()
	var before := p.to_dict()
	ProfileStore._writes_blocked = true
	_check(not ProfileStore.commit_victory(session) and p.to_dict() == before and session.can_commit(), "保存失败不授予/保留重试")
	ProfileStore._writes_blocked = false
	_check(ProfileStore.commit_victory(session), "胜利提交")
	before = p.to_dict()
	_check(ProfileStore.commit_victory(session) and p.to_dict() == before, "重复提交不重发")
	var fail := BattleSession.new("ch01_s01")
	fail.add_weapon("equipment_ring_blade_1")
	fail.mark_defeat()
	_check(not p.apply_battle_session(fail), "失败不可提交")
	fail.mark_discarded()
	_check(fail.pending_weapons.is_empty(), "失败清账")
	var quit := BattleSession.new("ch01_s01")
	quit.add_weapon("equipment_ring_blade_1")
	quit.abandon()
	quit.clear_pending_rewards()
	_check(quit.pending_weapons.is_empty() and not p.apply_battle_session(quit), "退出清账")
	var repeat_stage := stage.duplicate() as StageData
	repeat_stage.repeat_weapon_drop_chance = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var repeat_session := BattleSession.new("ch01_s08")
	GameFlow.collect_stage_rewards(repeat_session, repeat_stage, false, rng)
	_check(repeat_session.pending_weapons.is_empty(), "0%不掉落")
	repeat_stage.repeat_weapon_drop_chance = 1
	GameFlow.collect_stage_rewards(repeat_session, repeat_stage, true, rng)
	_check(repeat_session.pending_weapons.size() == 3, "旧首通/困难不得再次保底，以重复规则补件")
	for id in repeat_session.pending_weapons: p.add_weapon(str(id), 10)
	var seals := int(p.items.get("general_seal", 0))
	repeat_session.mark_victory()
	_check(ProfileStore.commit_victory(repeat_session) and int(p.items.get("general_seal", 0)) == seals + 6 + int(repeat_session.pending_loot.get("general_seal", 0)), "满仓3款各折算2困难不翻倍（材料独立）")
	repeat_stage.repeat_weapon_drop_chance = 0.3
	var hits := 0
	var mixed := 0
	for i in range(300):
		var s := BattleSession.new("ch01_s08")
		GameFlow.collect_stage_rewards(s, repeat_stage, false, rng)
		hits += s.pending_weapons.size()
		if s.pending_weapons.size() in [1, 2]: mixed += 1
	_check(hits > 220 and hits < 330 and mixed > 100, "30%每款独立掷点（固定seed）")
	GameFlow.selected_difficulty = Difficulty.NORMAL

func _test_stats() -> void:
	for id in WeaponRegistry.IDS:
		var weapon := WeaponRegistry.get_weapon(id)
		var hero := str(HEROES[str(weapon.profession_id)])
		var character := GameFlow.load_character_data(hero)
		for rank in [0, 2, 5]:
			var stats := character.compute_stats_at(40, rank, null, 0, {}, {}, weapon)
			var tower := _tower(hero, weapon, 40, rank)
			_near(tower.damage, stats.damage, "装备攻击同源 " + id)
			_near(tower.range_radius, stats.range, "装备射程同源 " + id)
			_near(tower.crit_rate, stats.crit_rate, "装备暴击同源 " + id)
			_near(tower.crit_damage, stats.crit_damage, "装备爆伤同源 " + id)
			_near(tower.skill_amp, stats.skill_amp, "装备增幅同源 " + id)
			_near(tower.bullet_speed, stats.projectile_speed, "装备弹道同源 " + id)
			for i in range(3): tower.apply_battle_rank(0)
			var battle_stats := character.compute_stats_at(40, rank, null, 3, {}, {}, weapon)
			_near(tower.damage, battle_stats.damage, "局内攻击同源 " + id)
			_near(tower.range_radius, battle_stats.range, "局内射程同源 " + id)
			_near(tower.skill_amp, battle_stats.skill_amp, "局内增幅同源 " + id)
			remove_child(tower)
			tower.queue_free()
	var zhao := GameFlow.load_character_data("zhao_yun")
	var spear := WeaponRegistry.get_weapon("equipment_long_spear_1")
	var guarded := zhao.compute_stats_at(40, 2, null, 0, {"attack":9999}, {}, spear)
	_check(int(guarded.damage) > 9999, "成长保障不吞掉装备基础加值")
	var bare := zhao.compute_stats_at(1)
	var equipped := zhao.compute_stats_at(1, 0, null, 0, {}, {}, spear)
	_check(equipped.damage == bare.damage + 6, "固定攻击基础值")
	_near(equipped.crit_rate, bare.crit_rate + 0.04, "暴击同层")
	var t := _tower("zhuge_liang", WeaponRegistry.get_weapon("equipment_ritual_staff_1"))
	var enemy := ENEMY.instantiate() as Enemy
	var path := Path2D.new()
	path.curve = Curve2D.new()
	path.curve.add_point(Vector2.ZERO)
	path.curve.add_point(Vector2(1000, 0))
	add_child(path)
	path.add_child(enemy)
	enemy.set_process(false)
	enemy.tags = []
	_check(t.finalize_damage(100, enemy, DamageTypes.MAGIC) == 108 and t.finalize_damage(100, enemy, DamageTypes.PHYSICAL) == 100, "魔法8%只加对应类型L1")
	t.apply_character(GameFlow.load_character_data("zhuge_liang"), {"weapon":WeaponRegistry.get_weapon("equipment_bamboo_banner_1"), "rank":5})
	_near(t.get_armor_penetration().ratios.weapon, 0.2, "武器穿甲不受增幅放大")
	enemy.armor = 100
	_check(enemy._apply_armor(1000, DamageTypes.PHYSICAL, {"weapon":0.2, "skill":0.3}, 2) == int(round(1000.0 * 50.0 / (100.0 * 0.8 * 0.7 - 2 + 50))), "跨源乘算后固定穿透")
	var hp := enemy.current_hp
	enemy.take_damage(10, &"zhuge_liang", DamageTypes.MAGIC, {"weapon":0.2}, 0, true, t)
	_check(hp - enemy.current_hp == 10, "固定DoT不吃护甲穿甲/类型增伤")
	remove_child(t)
	t.queue_free()
	path.queue_free()
	var rage := _tower("zhao_yun", WeaponRegistry.get_weapon("equipment_horse_sword_1"))
	rage._tech_rage_gain_pct = 0.2
	rage.gain_rage(10)
	_near(rage.rage, 13, "装备/科技怒气同层")
	remove_child(rage)
	rage.queue_free()
	var liu := _tower("liu_bei", WeaponRegistry.get_weapon("equipment_bone_mace_1"))
	var base_gain := float(liu._gain_per_hit) + 10.0 * liu._gain_per_damage
	liu.notify_aoe_damage_dealt(10)
	_near(liu.rage, base_gain + 1, "骨朵实际普攻命中在基础积怒上+1")
	liu.notify_aoe_damage_dealt(0)
	_near(liu.rage, base_gain + 1, "空爆不积怒")
	liu.grant_rage_flat(10)
	_near(liu.rage, base_gain + 11, "固定返怒不吃装备倍率")
	remove_child(liu)
	liu.queue_free()

func _test_ui() -> void:
	var p := ProfileStore.get_profile()
	p.unlock_character("zhang_fei")
	p.add_weapon("equipment_ring_blade_1")
	# Panels are built directly by the hub; instantiate scripts to match that path.
	var panel = (load("res://scripts/ui_screens/panels/DevelopPanel.gd") as GDScript).new()
	add_child(panel)
	panel._select_character("zhang_fei")
	panel._refresh()
	_check(panel._tab_container.get_tab_count() == 4, "养成四页签")
	ProfileStore._writes_blocked = true
	var before := p.to_dict()
	_check(not panel._equip_weapon("zhang_fei", "equipment_ring_blade_1") and p.to_dict() == before, "换装保存失败不改live")
	ProfileStore._writes_blocked = false
	_check(panel._equip_weapon("zhang_fei", "equipment_ring_blade_1") and p.get_character_weapon_id("zhang_fei") == "equipment_ring_blade_1", "换装保存成功")
	panel.queue_free()
	await get_tree().process_frame
	var enc = (load("res://scripts/ui_screens/panels/EncyclopediaPanel.gd") as GDScript).new()
	add_child(enc)
	enc._select_character("zhang_fei")
	before = p.to_dict()
	enc._sim_weapon_id = "equipment_ring_blade_1"
	enc._on_sim_changed()
	await get_tree().process_frame
	_check(p.to_dict() == before and enc._weapon_tab.find_children("WeaponCard_*", "Button", true, false).size() == 2, "百科双款预览不写档")
	enc.queue_free()
	await get_tree().process_frame

func _test_affix_values() -> void:
	var cases := [
		["zhang_fei", "equipment_ring_blade_1", "damage", 5.0, false],
		["zhang_fei", "equipment_ring_blade_1", "crit_damage", 0.15, false],
		["zhuge_liang", "equipment_ritual_staff_1", "damage", 6.0, false],
		["huang_zhong", "equipment_horn_bow_1", "range", 0.10, true],
		["diao_chan", "equipment_silk_bells_1", "range", 0.08, true],
		["diao_chan", "equipment_silk_bells_1", "skill_amp", 0.10, false],
		["diao_chan", "equipment_clay_flute_1", "range", 15.0, false],
		["huang_zhong", "equipment_mulberry_bow_1", "projectile_speed", 60.0, false],
	]
	for entry in cases:
		var c := GameFlow.load_character_data(str(entry[0]))
		var bare := c.compute_stats_at(1)
		var equipped := c.compute_stats_at(1, 0, null, 0, {}, {}, WeaponRegistry.get_weapon(str(entry[1])))
		var key := str(entry[2])
		var expected := float(bare[key]) * (1.0 + float(entry[3])) if entry[4] else float(bare[key]) + float(entry[3])
		_near(float(equipped[key]), expected, "独立词条值 " + str(entry[1]) + key)
	for entry in [["equipment_thunder_cart_1", 0.08], ["equipment_wood_mortar_1", 0.12]]:
		var tower := _tower("huang_fu_song", WeaponRegistry.get_weapon(str(entry[0])))
		_near(tower.splash_radius(90), 90.0 * (1.0 + float(entry[1])), "实际溅射半径 " + str(entry[0]))
		remove_child(tower)
		tower.queue_free()
	for entry in [["zhao_yun", "equipment_horse_sword_1"], ["zhang_fei", "equipment_bone_mace_1"], ["zhuge_liang", "equipment_bamboo_banner_1"], ["huang_zhong", "equipment_mulberry_bow_1"], ["diao_chan", "equipment_clay_flute_1"], ["huang_fu_song", "equipment_wood_mortar_1"]]:
		var tower := _tower(str(entry[0]), WeaponRegistry.get_weapon(str(entry[1])), 1, 2)
		_near(SkillRegistry.strength(tower, tower._ultimate_id), 1.06 + tower._character_data.per_rank_skill_amp * 2, "动态技能包含装备6% " + str(entry[1]))
		remove_child(tower)
		tower.queue_free()
	var zhao := GameFlow.load_character_data("zhao_yun")
	var base := zhao.compute_stats_at(1, 2)
	var equipped := zhao.compute_stats_at(1, 2, null, 0, {}, {}, WeaponRegistry.get_weapon("equipment_horse_sword_1"))
	_near(float(equipped.crit_damage) - float(base.crit_damage), zhao.skill_param(&"trait_dragon_spirit", "crit_damage") * 0.06, "装备增幅放大常驻龙魂")
	var shooter := _tower("huang_zhong", WeaponRegistry.get_weapon("equipment_mulberry_bow_1"))
	var bullet := shooter.instantiate_bullet(null)
	_check(bullet != null, "装备实际弹道生成")
	if bullet != null:
		_near(bullet.speed, GameFlow.load_character_data("huang_zhong").projectile_speed + 60, "实际弹道速度+60")
		bullet.queue_free()
	remove_child(shooter)
	shooter.queue_free()
