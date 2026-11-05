extends Node

var failures: Array[String] = []
var _slot := ""
var _path: Path2D
const TOWER_SCENE := preload("res://scenes/Tower.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

func _ready() -> void:
	_slot = "user://.skill_kit_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("SKILL_KIT: " + message)

func _tower(id: String, rank: int = 2, levels: Dictionary = {}) -> Tower:
	var tower := TOWER_SCENE.instantiate() as Tower
	add_child(tower)
	tower.set_process(false)
	tower.apply_character(GameFlow.load_character_data(id), {"level": 1, "rank": rank, "skill_levels": levels})
	tower.global_position = Vector2(300, 300)
	tower.crit_rate = 0.0
	return tower

func _enemy(hp: int = 100000, offset: Vector2 = Vector2(80, 0), armor: int = 0) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.max_hp = hp
	enemy.armor = armor
	enemy.speed = 0.0
	enemy.reward = 0
	enemy.kill_xp = 8
	_path.add_child(enemy)
	enemy.set_process(false)
	enemy.global_position = Vector2(300, 300) + offset
	return enemy

func _clear() -> void:
	for child in get_children():
		if child is Tower or child is Bullet:
			remove_child(child)
			child.queue_free()
	for child in _path.get_children():
		_path.remove_child(child)
		child.queue_free()

func _run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	GameFlow.squad_character_ids = []
	GameFlow.clear_squad_relics()
	GameManager.reset(99999, 20, 1)
	_path = Path2D.new()
	_path.curve = Curve2D.new()
	_path.curve.add_point(Vector2.ZERO)
	_path.curve.add_point(Vector2(2000, 0))
	add_child(_path)
	_test_registration(profile)
	_test_levels_and_migration(profile)
	_test_hit_rules()
	_clear()
	_test_white_rage()
	_clear()
	_test_damage_pipeline()
	_clear()
	await _test_sold_projectile()
	_clear()
	_test_auras()
	_clear()
	_test_fixed_status()
	_clear()
	_test_all_ultimates()
	_clear()
	_test_probability_and_kills()
	_clear()
	_test_permanent_preview()
	_clear()
	await _test_ui_transaction()
	_path.queue_free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("SKILL_KIT_RESULT: %s failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_registration(profile: PlayerProfile) -> void:
	var all: Array = []
	for id in GameFlow.get_all_character_ids():
		var character := GameFlow.load_character_data(id)
		profile.unlock_character(id)
		_check(character.passive_ids.size() == 2 and character.get_skill_ids().size() == 3, id + "三技能")
		var configured: Array[String] = []
		for skill in character.get_skill_ids(): configured.append(str(skill))
		_check(configured == SkillRegistry.KITS[id], id + "资源与注册一致")
		for skill in character.get_skill_ids():
			_check(SkillRegistry.is_known(skill) and not all.has(skill), "技能唯一注册 " + str(skill))
			all.append(skill)
			var rows := SkillRegistry.effect_rows(character, skill, 1, 0.0)
			_check(not rows.is_empty(), "技能数值描述 " + str(skill))
			for row in rows:
				for cell in row: _check(UITheme.hud_icon(cell[0]) != null, "效果图徽 " + str(skill))
		_check(not character.is_skill_unlocked(character.passive_ids[0], 0) and character.is_skill_unlocked(character.passive_ids[0], 1), id + "绿色门")
		_check(not character.is_skill_unlocked(character.passive_ids[1], 1) and character.is_skill_unlocked(character.passive_ids[1], 2), id + "紫色门")
		_check(character.is_skill_unlocked(character.ultimate_id, 0), id + "大招白阶")
	_check(all.size() == 27, "完整27技能")

func _test_levels_and_migration(profile: PlayerProfile) -> void:
	var passive := &"passive_green_dragon_stance"
	var ultimate := &"char_green_dragon"
	profile.add_item("skill_book", 100)
	var before := profile.to_dict()
	_check(not profile.upgrade_skill("guan_yu", passive) and profile.to_dict() == before, "未解锁技能原子拒绝")
	_check(not profile.upgrade_skill("guan_yu", &"char_burn_camp") and profile.to_dict() == before, "他将技能拒绝")
	_check(not profile.upgrade_skill("missing", ultimate), "未拥有拒绝")
	var spent := 0
	for level in range(1, 10):
		var cost := SkillRegistry.upgrade_cost(level)
		spent += cost
		_check(profile.upgrade_skill("guan_yu", ultimate) and profile.get_skill_level("guan_yu", ultimate) == level + 1, "升级 " + str(level))
	_check(spent == 25 and int(profile.items.skill_book) == 75, "25本总消耗")
	before = profile.to_dict()
	_check(not profile.upgrade_skill("guan_yu", ultimate) and profile.to_dict() == before, "满级拒绝")
	_check(is_equal_approx(SkillRegistry.level_multiplier(10), 1.27), "升级倍率")
	var extremes := SkillRegistry.normalize_levels("guan_yu", {"char_green_dragon": 1e100, "passive_green_dragon_stance": true, "passive_warm_wine": NAN})
	_check(extremes.char_green_dragon == 10 and extremes.passive_green_dragon_stance == 1 and extremes.passive_warm_wine == 1, "大数先夹取，布尔与NaN回落")
	_check(SkillRegistry.normalize_levels("guan_yu", {"char_green_dragon": "999999999999999999999999999999"}).char_green_dragon == 10, "整数文本先夹取")
	var raw := {"schema_version": 7, "characters": {"guan_yu": {"total_exp": 1340, "rank": 2, "skill_levels": {"char_green_dragon": 8, "passive_green_dragon_stance": -10, "passive_warm_wine": "bad", "foreign": 99}}}, "items": {"skill_book": 50}, "military_merit": 99, "exp_pool": 123}
	var migrated: Dictionary = ProfileStore._migrate_to_current(raw)
	_check(migrated.ok and migrated.data.schema_version == PlayerProfile.CURRENT_SCHEMA_VERSION, "技能迁移至当前schema")
	var values: Dictionary = migrated.data.characters.guan_yu.skill_levels
	_check(values == {"char_green_dragon": 8, "passive_green_dragon_stance": 1, "passive_warm_wine": 1}, "非法归一与有效等级保留")
	_check(ProfileStore._migrate_to_current(migrated.data).data == migrated.data, "迁移幂等")
	var loaded := PlayerProfile.from_dict(migrated.data)
	_check(ProfileStore.save_profile(loaded), "技能存盘")
	ProfileStore.profile = null
	var reloaded := ProfileStore.load_profile()
	_check(reloaded.get_skill_level("guan_yu", ultimate) == 8 and reloaded.military_merit == 99 and reloaded.exp_pool == 123, "存盘往返")

func _test_hit_rules() -> void:
	var guan := _tower("guan_yu", 1)
	var first := _enemy()
	var next := _enemy(100000, Vector2(100, 0))
	guan.crit_rate = 0.0
	_check(guan.attack_hit_damage(100, 0.99) == 100, "第一击不强制")
	guan.notify_attack_damage_dealt(first, 100)
	_check(guan.attack_hit_damage(100, 0.99) == 100, "第二击不强制")
	guan.notify_attack_damage_dealt(next, 100)
	_check(guan.attack_hit_damage(100, 0.99) == int(round(100 * guan.crit_damage)), "换目标第三击仍必暴击")
	var bullet := Bullet.new()
	bullet.source_tower = guan
	bullet.counts_as_attack = true
	bullet.target = null
	add_child(bullet)
	bullet._physics_process(0.01)
	_check(guan.skill_hit_counter == 2, "空弹不计")
	guan.notify_attack_damage_dealt(first, 100)
	_check(guan.attack_hit_damage(100, 0.99) == 100, "第四击不强制")
	var huang := _tower("huang_zhong", 2)
	_check(is_equal_approx(SkillRegistry.attack_multiplier(huang, first), 1.0), "连续首次无加成")
	for i in range(8): huang.notify_attack_damage_dealt(first, 10)
	_check(is_equal_approx(SkillRegistry.attack_multiplier(huang, first), 1.3), "连续普攻封顶")
	_check(is_equal_approx(SkillRegistry.attack_multiplier(huang, next), 1.0), "换目标当前击无加成")
	huang.notify_attack_damage_dealt(next, 10)
	_check(is_equal_approx(SkillRegistry.attack_multiplier(huang, next), 1.05), "换目标重计")
	_check(first.poison_dps == 20, "哨戒固定毒")

func _test_auras() -> void:
	var receiver := _tower("guan_yu", 0)
	var base := receiver.damage
	var sources: Array[Tower] = []
	for i in range(4): sources.append(_tower("liu_bei", 2))
	receiver.refresh_aura_damage_bonus()
	var per_layer := 3.0 * 1.03
	_check(receiver.damage == int(round(base + per_layer * 3)), "仁德3层固定攻击")
	_check(is_equal_approx(receiver.crit_rate, 0.05 + 0.05 * 1.03 * 2), "砥砺2层")
	sources[0].global_position = Vector2(1000, 300)
	sources[1].global_position = Vector2(1000, 300)
	receiver.refresh_aura_damage_bonus()
	_check(receiver.damage == int(round(base + per_layer * 2)), "离开覆盖即时移除")
	sources[2].queue_free()
	receiver.refresh_aura_damage_bonus()
	_check(receiver.damage == int(round(base + per_layer)), "回收立即移除")
	var diao := _tower("diao_chan", 1)
	diao.battle_rank = 3
	_check(not diao._is_in_dancer_reveal_aura(), "拜月未解锁不破隐")
	diao.apply_character(GameFlow.load_character_data("diao_chan"), {"rank": 2})
	diao.battle_rank = 3
	diao._recalc_skill_stats()
	_check(diao._is_in_dancer_reveal_aura() and is_equal_approx(diao.skill_amp, 0.08), "拜月解锁与增幅")

func _test_white_rage() -> void:
	for id in SkillRegistry.KITS:
		_clear()
		var tower := _tower(id, 0)
		var enemy := _enemy()
		enemy.global_position = tower.global_position + Vector2(maxf(80, tower._min_range + 20), 0)
		var ally := _tower("guan_yu", 0)
		ally.global_position += Vector2(30, 0)
		tower.target = enemy
		BehaviorRegistry.execute_attack(tower.get_behavior_id(), tower, enemy)
		tower.flush_pending_combat_steps()
		for node in get_children():
			if node is Bullet: node._physics_process(1.0)
		_check(tower.rage > 0.0, "白阶实际普攻积怒 " + id)
		tower.rage = 100
		tower._manual_ultimate_mode = true
		_check(tower.cast_ultimate_manual(), "白阶满怒可释放 " + id)
		tower.flush_pending_combat_steps()
	_clear()
	var liu := _tower("liu_bei", 1)
	var receiver := _tower("guan_yu", 0)
	receiver.global_position += Vector2(30, 0)
	var rage_before := liu.rage
	SkillRegistry.tick(liu, 0.25)
	_check(liu.rage == rage_before, "刘备光环不重复积怒")

func _test_damage_pipeline() -> void:
	var tower := _tower("zhang_fei", 2, {"char_dangyang_roar": 10})
	tower.refresh_aura_damage_bonus()
	tower.skill_amp = 0.4
	tower.crit_rate = 0.75
	var enemy := _enemy()
	var before := enemy.current_hp
	_check(SkillRegistry.execute_ultimate(&"char_dangyang_roar", tower), "实际高等级大招")
	_check(before - enemy.current_hp == int(round(tower.damage * 1.27 * 1.4)), "实际技能伤害只应用一次升级和增幅，不暴击")
	_check(is_equal_approx(enemy._fear_time_left, 1.4) and is_equal_approx(enemy._fear_follow_slow_duration, 2.8), "增幅放大时长，升级不放大时长")
	tower.crit_rate = 0.0
	_check(tower.attack_hit_damage(tower.finalize_damage(tower.damage, enemy, DamageTypes.PHYSICAL, false), 0.99) == tower.damage, "普攻排除技能升级和增幅")
	_clear()
	var guan := _tower("guan_yu", 0)
	guan.refresh_aura_damage_bonus()
	var first := _enemy(100)
	first.apply_vulnerability(0.5, 10)
	var second := _enemy(10000, Vector2(90, 0))
	second.apply_vulnerability(0.25, 10)
	var amount := guan.damage * 2
	var carry := amount - ceili(100.0 / 1.5)
	guan.target = first
	guan.rage = 100
	guan._manual_ultimate_mode = true
	_check(guan.cast_ultimate_manual(), "易伤溢血三拍")
	guan.flush_pending_combat_steps()
	var expected := int(round(float(amount + carry) * 1.25)) + int(round(float(amount) * 1.25))
	_check(first.is_dead and 10000 - second.current_hp == expected, "三拍溢血与每个目标易伤只结算一次")

func _test_sold_projectile() -> void:
	var tower := _tower("huang_zhong", 0)
	tower.crit_rate = 0.0
	var victim := _enemy()
	var bullet := tower.instantiate_bullet(victim)
	bullet.damage = 100
	bullet.counts_as_attack = true
	bullet.set_physics_process(false)
	remove_child(tower)
	tower.queue_free()
	await get_tree().process_frame
	var before := victim.current_hp
	bullet._physics_process(1.0)
	_check(before - victim.current_hp == 100 and victim.damage_contributors.get("huang_zhong", 0) == 100, "卖塔后在途弹道真实命中与归属")

func _test_fixed_status() -> void:
	var victim := _enemy(10000, Vector2(80, 0), 10000)
	victim.apply_vulnerability(0.5, 99)
	victim.apply_poison(20, 3, "huang_zhong")
	victim._tick_status_damage(5)
	_check(victim.current_hp == 9940 and victim.poison_dps == 0, "固定毒绕过护甲易伤且时长夹取")
	victim.apply_burn(10, 0.5)
	victim._tick_status_damage(3)
	_check(victim.current_hp == 9935 and victim.burn_dps == 0, "最后不足一帧灼烧")
	victim.apply_burn(20, 1)
	victim._tick_status_damage(0.5)
	_check(victim.current_hp == 9925, "分帧固定伤害")
	victim._tick_status_damage(0.5)
	_check(victim.current_hp == 9915, "累积与到期")
	var session := BattleSession.new("fixed_status")
	GameManager.set_battle_session(session)
	var kill := _enemy(10, Vector2(100, 0), 999)
	kill.apply_poison(20, 1, "huang_zhong")
	kill._tick_status_damage(0.5)
	_check(kill.is_dead and int(session.get_pending_xp_by_character().get("huang_zhong", 0)) > 0, "固定毒击杀经验归属")

func _test_all_ultimates() -> void:
	for id in SkillRegistry.KITS:
		_clear()
		var tower := _tower(id)
		var enemy := _enemy()
		enemy.global_position = tower.global_position + Vector2(maxf(80, tower._min_range + 20), 0)
		var ally := _tower("guan_yu", 0)
		ally.global_position += Vector2(30, 0)
		tower.target = enemy
		var hp := enemy.current_hp
		tower.rage = 100
		_check(tower._try_cast_ultimate(), "大招可施放 " + id)
		tower.flush_pending_combat_steps()
		_check(tower.rage < 100, "大招耗怒 " + id)
		if id in ["liu_bei", "diao_chan"]:
			_check(ally.attack_speed_buff > 1.0, "辅助大招 " + id)
		elif id == "huang_zhong":
			_check(enemy.get_vulnerability_multiplier() > 1.0 and tower.crit_rate > 0.0 and tower.damage > tower._base_damage, "定军三项与易伤")
			tower._tick_skill_stat_buffs(100)
			_check(tower.damage == tower._base_damage, "定军增益到期")
		else: _check(enemy.current_hp < hp, "伤害大招 " + id)
		if id == "guan_yu": _check(tower.skill_hit_counter == 0 and tower.attack_speed_buff > 1.0, "三拍不计普攻并触发温酒")
		if id == "zhang_fei": _check(enemy._fear_time_left > 0.0 and enemy._fear_follow_slow_duration > 0.0, "恐惧后减速")
		if id == "zhuge_liang": _check(enemy._forced_reveal_left > 0.0, "全图命中现形")
	_clear()
	var guan := _tower("guan_yu", 0)
	var enemy := _enemy(10)
	var second := _enemy(10, Vector2(90, 0))
	var third := _enemy(10, Vector2(100, 0))
	guan.target = enemy
	guan.rage = 100
	_check(guan._try_cast_ultimate(), "三拍溢血开招")
	guan.flush_pending_combat_steps()
	_check(enemy.is_dead and second.is_dead and third.is_dead and is_equal_approx(guan.rage, 45.0), "三拍溢血与最多45返怒")
	_clear()
	var zhuge := _tower("zhuge_liang", 2)
	var hidden := _enemy(10000, Vector2(1000, 0))
	hidden.stealth = true
	_check(not hidden.is_visible_to(zhuge), "全图隐藏起态")
	_check(zhuge._try_cast_ultimate() and hidden.is_visible_to(zhuge), "全图破隐不依赖当前索敌")
	hidden._process(6)
	_check(not hidden.is_visible_to(zhuge), "现形到期恢复")
	_clear()
	var fire := _tower("huang_fu_song", 2)
	var burning := _enemy(10)
	var neighbor := _enemy()
	burning.apply_burn(10, 3, fire)
	var hp := neighbor.current_hp
	burning.take_damage(10, "other", DamageTypes.TRUE)
	_check(neighbor.current_hp < hp, "灼烧死亡爆燃")

func _test_probability_and_kills() -> void:
	var zhang := _tower("zhang_fei", 2)
	var second := _tower("zhang_fei", 2)
	zhang._skill_params["trait_yanyan_roar"]["chance"] = 1.0
	var enemy := _enemy()
	var hp := enemy.current_hp
	SkillRegistry.on_attack_hit(zhang, enemy, 1)
	_check(enemy.current_hp < hp and enemy._fear_time_left > 0.0 and zhang.skill_hit_counter == 1, "概率参数与无递归命中")
	var kill := _enemy(1)
	zhang.rage = 0
	second.rage = 0
	zhang.deal_damage(kill, 10)
	_check(is_equal_approx(zhang.rage, 3.09) and second.rage == 0, "同将击杀只返实际塔")

func _test_permanent_preview() -> void:
	for id in ["huang_fu_song", "zhao_yun", "zhuge_liang"]:
		var tower := _tower(id, 2)
		var character := GameFlow.load_character_data(id)
		var stats := character.compute_stats_at(1, 2)
		tower.refresh_aura_damage_bonus()
		_check(tower.damage == stats.damage and is_equal_approx(tower.range_radius, stats.range) and is_equal_approx(tower.crit_damage, stats.crit_damage), "常驻数值预览同源 " + id)
		if id == "zhao_yun": _check(float(tower.get_armor_penetration().ratios.get(id, 0.0)) > 0.0, "龙魂穿甲")
		if id == "huang_fu_song": _check(tower.splash_radius(70) > 70, "烈焰溅射")
	var char := GameFlow.load_character_data("zhang_fei")
	var tower := _tower("zhang_fei", 2, {"char_dangyang_roar": 10})
	_check(is_equal_approx(SkillRegistry.strength(tower, &"char_dangyang_roar"), 1.27 * 1.03) and is_equal_approx(SkillRegistry.duration(tower, &"char_dangyang_roar", "fear_duration"), 1.03), "升级与增幅单乘，升级不改时长")
	_check(char.skill_param(&"char_dangyang_roar", "mult") == 1.0, "共享资源未被升级污染")

func _test_ui_transaction() -> void:
	var profile := ProfileStore.create_new_profile(false)
	profile.unlock_character("guan_yu")
	profile.add_item("skill_book", 100)
	ProfileStore.save_profile(profile)
	var panel = load("res://scripts/ui_screens/panels/DevelopPanel.gd").new()
	add_child(panel)
	await get_tree().process_frame
	panel._select_character("guan_yu")
	panel._refresh()
	var cards: Array = panel._skill_tab.find_children("SkillCard_*", "PanelContainer", true, false)
	_check(cards.size() == 3, "养成三卡")
	ProfileStore._writes_blocked = true
	panel._upgrade_skill("guan_yu", &"char_green_dragon", 1)
	_check(profile.get_skill_level("guan_yu", &"char_green_dragon") == 1 and profile.items.skill_book == 100, "保存失败材料和等级回滚")
	ProfileStore._writes_blocked = false
	panel._upgrade_skill("guan_yu", &"char_green_dragon", 1)
	_check(profile.get_skill_level("guan_yu", &"char_green_dragon") == 2 and profile.items.skill_book == 99, "升级原子提交")
	panel._upgrade_skill("guan_yu", &"char_green_dragon", 1)
	_check(profile.items.skill_book == 99, "重复旧点击不扣书")
	panel.queue_free()
	await get_tree().process_frame
