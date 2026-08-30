extends Node

var failures: Array[String] = []
var warnings: Array[String] = []


var _profile_file := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 隔离存档槽：测试直开 Main.tscn 会触发初始武将写档与等级查询，
	# 不得读写玩家真实存档（模式同 FlowRunner/Stage0Runner）。
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.smoke_runner_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SMOKE_TEST: %s" % message)


func _run() -> void:
	_check_resource_integrity()
	# 测试消耗品（v0.15.1）：练兵令应为 CONSUMABLE 且可加载。
	var exp_scroll := load("res://resources/items/exp_scroll.tres") as ItemData
	_check(exp_scroll != null and exp_scroll.item_type == ItemData.ItemType.CONSUMABLE,
		"练兵令应为可用的消耗品道具")

	# 阶段 6（v0.17.0）：多分支转职图结构——关羽一转 → 武圣/青龙骑双分支。
	var promo_charger := load("res://resources/promotions/guan_yu_charger.tres") as PromotionData
	var promo_wusheng := load("res://resources/promotions/guan_yu_wusheng.tres") as PromotionData
	var promo_qinglong := load("res://resources/promotions/guan_yu_qinglong.tres") as PromotionData
	_check(promo_charger != null and promo_wusheng != null and promo_qinglong != null, "关羽二转分支资源应齐全")
	if promo_charger and promo_wusheng and promo_qinglong:
		_check(promo_charger.next_promotion_ids.size() == 2
			and promo_charger.next_promotion_ids.has(&"guan_yu_wusheng")
			and promo_charger.next_promotion_ids.has(&"guan_yu_qinglong"), "突击骑应配置武圣/青龙骑两个二转分支")
		_check(str(promo_wusheng.parent_id) == "guan_yu_charger"
			and str(promo_qinglong.parent_id) == "guan_yu_charger", "二转候选 parent 应指向突击骑")
		_check(promo_wusheng.ultimate_multiplier > 1.0
			and promo_qinglong.attack_interval_multiplier < 1.0, "武圣应强化大招、青龙骑应强化攻速")

	# 阶段 6（v0.17.0）：羁绊试点——资源齐全、桃园满员激活 +5%、五虎将缺员预览不激活。
	var taoyuan := load("res://resources/bonds/taoyuan_oath.tres") as BondData
	var five_tigers := load("res://resources/bonds/five_tigers.tres") as BondData
	_check(taoyuan != null and taoyuan.is_valid(), "桃园结义羁绊配置应有效")
	_check(five_tigers != null and five_tigers.is_valid(), "五虎将羁绊配置应有效")
	_check(GameFlow.get_squad_bond_damage_bonus([]) == 0.0, "空编队羁绊加成应为 0")
	_check(is_equal_approx(GameFlow.get_squad_bond_damage_bonus(["liu_bei", "guan_yu", "zhang_fei"]), 0.05),
		"桃园结义三人同队攻击应 +5%")
	_check(GameFlow.get_squad_bond_damage_bonus(["guan_yu", "zhang_fei", "zhao_yun", "huang_zhong"]) == 0.0,
		"五虎将缺马超（预览）不应激活加成")

	# 阶段 6（v0.17.0）：转职候选图——未转职给一转，突击骑给两个二转分支。
	var stage6_profile := ProfileStore.get_profile()
	if stage6_profile != null:
		stage6_profile.ensure_character("guan_yu")
		stage6_profile.set_promotion_path("guan_yu", [])
		var first_round := GameFlow.get_promotion_candidates(stage6_profile, "guan_yu")
		_check(first_round.size() == 1 and str(first_round[0].promotion_id) == "guan_yu_charger",
			"未转职关羽应只有一转候选")
		stage6_profile.set_promotion_path("guan_yu", ["guan_yu_charger"])
		var second_round := GameFlow.get_promotion_candidates(stage6_profile, "guan_yu")
		_check(second_round.size() == 2, "突击骑应提供两个二转分支候选")
		stage6_profile.set_promotion_path("guan_yu", ["guan_yu_charger", "guan_yu_wusheng"])
		var second_active := GameFlow.get_active_promotion(stage6_profile, "guan_yu")
		_check(second_active != null and str(second_active.promotion_id) == "guan_yu_wusheng",
			"二转后生效转职应为路径末位（武圣）")
		var stage6_guan_yu := load("res://resources/characters/guan_yu.tres") as CharacterData
		if stage6_guan_yu != null and second_active != null:
			var wusheng_stats := stage6_guan_yu.compute_stats_at(20, second_active)
			var wusheng_expected := int(round((stage6_guan_yu.base_damage + stage6_guan_yu.damage_growth_per_level * 19) * 1.35))
			_check(int(wusheng_stats["damage"]) == wusheng_expected,
				"二转武圣伤害倍率应生效（×1.35，含 20 级成长）")
		# 还原共享存档状态，避免污染后续建塔用例（塔伤害断言基于未转职）。
		stage6_profile.set_promotion_path("guan_yu", [])

	# 阶段 6 提交 2（v0.18.0）：数值配置中心化——game_balance 可加载且 LevelCurve/Difficulty 生效。
	var balance := GameBalance.get_balance()
	_check(balance != null and balance.is_valid(), "game_balance 中心配置应有效")
	_check(LevelCurve.max_level() == 30 and LevelCurve.exp_total_for_level(10) == 1440,
		"等级曲线应读中心配置（30 级封顶、10 级 1440 经验）")
	_check(is_equal_approx(Difficulty.enemy_hp_mult(Difficulty.HARD), 1.4)
		and is_equal_approx(Difficulty.reward_mult(Difficulty.HARD), 1.6)
		and is_equal_approx(Difficulty.material_mult(Difficulty.HARD), 2.0),
		"难度倍率应读中心配置（困难 1.4/1.6/2.0）")

	# 阶段 6 提交 2（v0.18.0）：敌人模板——模板可加载、哨兵字段继承、显式字段覆盖。
	var heavy_cavalry := load("res://resources/enemy_templates/heavy_cavalry.tres") as EnemyTemplateData
	_check(heavy_cavalry != null and heavy_cavalry.is_valid(), "高护甲骑兵模板应可加载")
	if heavy_cavalry != null:
		var derived := EnemyData.new()
		derived.enemy_id = &"smoke_derived"
		derived.display_name = "模板派生测试敌"
		derived.template = heavy_cavalry
		# 哨兵约定（ENEMIES.md）：0/空字段继承模板值。
		derived.max_hp = 0
		derived.move_speed = 0.0
		derived.armor = -1
		derived.damage_to_base = 0
		derived.currency_reward = 0
		derived.kill_xp = 0
		derived.body_color = Color(0, 0, 0, 0)
		derived.body_size = Vector2.ZERO
		var merged := derived.resolved()
		_check(merged != derived and merged.max_hp == 180 and merged.move_speed == 145.0 and merged.armor == 20,
			"模板派生应继承血量/速度/护甲")
		_check(merged.currency_reward == 14 and merged.kill_xp == 12 and merged.damage_to_base == 2,
			"模板派生应继承奖励与漏怪伤害")
		var overridden := EnemyData.new()
		overridden.enemy_id = &"smoke_overridden"
		overridden.display_name = "模板覆盖测试敌"
		overridden.template = heavy_cavalry
		overridden.max_hp = 300
		overridden.armor = 0
		var merged2 := overridden.resolved()
		_check(merged2.max_hp == 300 and merged2.armor == 0, "显式字段应覆盖模板值")

	# 阶段 6 提交 2（v0.18.0）：科技树配置化——9 项可加载、加成汇总来自配置。
	var tech_items := TechTree.get_items()
	_check(tech_items.size() == 9, "科技树配置应含 9 项（三分支）")
	# 独立临时档案验证加成，避免解锁污染共享存档（后续伤害断言不受 +6% 影响）。
	var tech_profile := PlayerProfile.new()
	tech_profile.add_tech_points(10)
	tech_profile.unlock_tech("mil_dmg_1", 1)
	tech_profile.unlock_tech("mil_dmg_2", 2)
	_check(TechTree.get_tech_bonuses(tech_profile).get("damage_pct", 0) == 6,
			"军事分支加成应来自配置（精兵 2% + 老兵 4%）")

	# 装饰素材（v0.16.0，GDD 5.7 第三步）：assets/decor 纹理应齐全。
	for decor_name in ["tree", "rock", "banner", "torch"]:
		_check(ResourceLoader.exists("res://assets/decor/%s.png" % decor_name),
			"装饰素材 %s.png 应存在" % decor_name)

	# 音效库（v0.16.0）：全部音效已合成且播放不报错（headless 走哑音频）。
	_check(SfxLibrary.get_synthesized_count() == SfxLibrary.SFX_IDS.size(),
		"音效库应合成本阶段全部音效")
	SfxLibrary.play(&"attack", -30.0)
	SfxLibrary.play(&"skill", -30.0)
	SfxLibrary.play(&"ultimate", -30.0)
	SfxLibrary.play(&"victory", -30.0)

	var packed := load("res://scenes/Main.tscn") as PackedScene
	_check(packed != null, "Main.tscn 无法加载")
	if packed == null:
		_finish()
		return

	# 测试直开战斗场景时 GameFlow 未选关，Main 回退到默认教学关。
	var stage_data := load("res://resources/stages/chapter_01/ch01_s01.tres") as StageData
	_check(stage_data != null, "默认关卡数据应可加载")

	var main := packed.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(GameManager.gold == stage_data.starting_currency, "初始金币应来自关卡配置（starting_currency）")
	_check(GameManager.lives == stage_data.starting_lives, "初始生命应来自关卡配置（starting_lives）")
	_check(get_tree().get_nodes_in_group("build_slots").size() == stage_data.build_slot_count, "建造位数量应与关卡配置一致")

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
		# 显式控制金币，用例不依赖关卡初始金币的具体数值。
		build_manager.selected_character = guan_yu
		GameManager.gold = guan_yu.build_cost
		build_manager._on_build_requested(slots[0])
		build_manager._on_build_requested(slots[0])
		await get_tree().process_frame
		_check(GameManager.gold == 0, "建造关羽后金币应扣除其造价")
		build_manager.selected_character = liu_bei
		build_manager._on_build_requested(slots[1])
		build_manager._on_build_requested(slots[2])
		build_manager._on_build_requested(slots[2])
		await get_tree().process_frame
		_check(tower_manager.get_child_count() == 1, "金币不足时不应生成第二座塔")
		_check(slots[0].occupied and not slots[1].occupied and not slots[2].occupied, "建造位占用状态错误")
		GameManager.gold = 9999
		build_manager._on_build_requested(slots[1])
		build_manager._on_build_requested(slots[1])
		await get_tree().process_frame
		_check(tower_manager.get_child_count() == 2 and slots[1].occupied, "金币充足时应能建造第二座塔")
		# 两次点击确认（v0.12.3 简化）：第一次进入待确认，第二次确认建造。
		build_manager._on_build_requested(slots[3])
		_check(slots[3].get("pending") == true, "点选建造位后应进入待确认状态")
		build_manager._on_build_requested(slots[3])
		await get_tree().process_frame
		_check(slots[3].occupied, "再次点击同一建造位应确认建造")
		var extra_tower := tower_manager.get_child(tower_manager.get_child_count() - 1) as Tower
		if extra_tower:
			extra_tower.queue_free()
			slots[3].reset_slot()
			await get_tree().process_frame
		# 预锁位解锁（v0.14.1，GDD 5.1）：消耗金币解锁后即可正常建造，且不重复扣费。
		var locked_slot := slots[4] as BuildSlot
		locked_slot.locked = true
		locked_slot.unlock_cost = 50
		locked_slot._unlocked_in_battle = false
		GameManager.gold = 50
		build_manager._on_unlock_requested(locked_slot)
		await get_tree().process_frame
		_check(GameManager.gold == 0 and not locked_slot.is_locked(), "预锁位应消耗金币解锁")
		build_manager._on_unlock_requested(locked_slot)
		await get_tree().process_frame
		_check(GameManager.gold == 0, "已解锁位不应重复扣费")
		locked_slot.locked = false
		locked_slot._unlocked_in_battle = false

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
	boss_data.tags = [&"boss"]
	# Boss 演出（v0.15.0）：生成即发 boss_entered 信号（横幅/血条强化）。
	var boss_entered_names: Array[String] = []
	GameManager.boss_entered.connect(func(name: String) -> void: boss_entered_names.append(name))
	var boss := enemy_manager.spawn_enemy_from_data(boss_data) as Enemy
	await get_tree().process_frame
	_check(boss != null and boss.current_hp == 800, "Boss 应以 800 HP 初始化")
	_check(boss_entered_names.size() == 1 and boss_entered_names[0] == "冒烟测试 Boss",
		"Boss 生成应触发 boss_entered 信号（横幅演出）")
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
	_check(first_tower.is_swinging(), "骑兵攻击应触发挥击动作（无弹道）")
	_check(boss.current_hp < 800, "骑兵近战攻击应对 Boss 造成伤害")
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

	# 局内升级/回收（GDD 5.4）：费用 = 造价×0.8×次数，返还 = 总投入×0.6（向上取整）。
	var zhang_fei := load("res://resources/characters/zhang_fei.tres") as CharacterData
	_check(zhang_fei != null and stage_data != null, "张飞与关卡数据应可加载")
	if zhang_fei != null and stage_data != null and slots.size() >= 3:
		# 波次测试把 GameManager 推到了终局状态，先复位再验证局内建造/升级。
		GameManager.reset(9999, 20, stage_data.waves.size())
		build_manager.selected_character = zhang_fei
		build_manager._on_build_requested(slots[2])
		build_manager._on_build_requested(slots[2])
		await get_tree().process_frame
		var spear_tower := tower_manager.get_child(tower_manager.get_child_count() - 1) as Tower
		_check(spear_tower != null and slots[2].occupied, "张飞塔应建造成功")
		if spear_tower != null:
			var upgrade_cost_1 := spear_tower.get_upgrade_cost(stage_data.upgrade_cost_factor)
			_check(upgrade_cost_1 == ceili(zhang_fei.build_cost * 0.8), "第一次升级费用应为造价×0.8")
			_check(tower_manager.upgrade_tower(spear_tower, stage_data), "金币充足时应能升级")
			_check(spear_tower.battle_level == 1, "升级后局内等级应为 1")
			_check(spear_tower.damage == int(round(zhang_fei.base_damage * 1.25)), "升级后伤害应为 +25%")
			_check(tower_manager.upgrade_tower(spear_tower, stage_data), "第二次升级应成功")
			_check(spear_tower.battle_level == stage_data.max_inbattle_upgrade_level, "升级应止步于本关上限")
			_check(not tower_manager.upgrade_tower(spear_tower, stage_data), "超过上限后升级应失败")

			# 近战行为集成（剑客）（GDD modules/BEHAVIORS.md melee_thrust）：
			# 直伤一次带骑兵标签的轻骑，验证 15% 克制与近战无弹道。
			var cavalry_data := load("res://resources/enemies/yellow_turban/yellow_turban_cavalry.tres") as EnemyData
			var melee_target := enemy_manager.spawn_enemy_from_data(cavalry_data) as Enemy
			_check(melee_target != null, "近战用例应能生成轻骑")
			if melee_target != null:
				melee_target.set_process(false)
				melee_target.global_position = spear_tower.global_position + Vector2(60, 0)
				spear_tower.target = melee_target
				spear_tower.attack()
				# 刘备塔在场：仁德光环使其他塔伤害 +8%（v0.11.2 特性生效）
				var benevolence := 1.08
				_check(
					melee_target.current_hp == melee_target.max_hp - int(round(spear_tower.damage * 1.15 * benevolence)),
					"剑客近战直伤应含 15% 骑兵克制与 8% 仁德光环"
				)
				_check(spear_tower.is_swinging(), "近战攻击应触发挥击动作而非枪口闪光")
				melee_target.die(false)

			var invested := spear_tower.total_invested
			var refund := spear_tower.get_sell_refund(stage_data.sell_refund_ratio)
			_check(refund == ceili(invested * 0.6), "回收返还应为总投入×0.6（向上取整）")
			var gold_before_sell := GameManager.gold
			_check(tower_manager.sell_tower(spear_tower, stage_data), "回收应成功")
			_check(GameManager.gold == gold_before_sell + refund, "回收后应返还金币")
			_check(not slots[2].occupied, "回收后建造槽应可复用")

	# 等级曲线（GDD modules/NUMBERS.md 10.1）
	_check(LevelCurve.exp_total_for_level(10) == 1440, "10 级累计经验应为 1440")
	_check(LevelCurve.level_from_total_exp(0) == 1, "0 经验应为 1 级")
	_check(LevelCurve.level_from_total_exp(1439) == 9 and LevelCurve.level_from_total_exp(1440) == 10,
		"等级应按累计经验推导")
	_check(LevelCurve.level_from_total_exp(999999) == LevelCurve.max_level(), "等级不应超过上限")

	# 等级与转职属性应用（GDD 4.4/4.5）：伤害 = (基础 + 成长×(级-1)) × 转职倍率
	var charger := load("res://resources/promotions/guan_yu_charger.tres") as PromotionData
	_check(charger != null and not charger.item_costs.is_empty(), "一转配置应含材料消耗")
	GameManager.reset(9999, 20, stage_data.waves.size())
	var leveled_tower: Tower = tower_manager.build_tower(Vector2(60, 640), guan_yu, null, {"level": 10, "promotion": charger})
	_check(leveled_tower != null, "应以等级/转职参数建造武将塔")
	if leveled_tower:
		var expected_damage := int(round((guan_yu.base_damage + guan_yu.damage_growth_per_level * 9) * charger.damage_multiplier))
		_check(leveled_tower.damage == expected_damage, "10 级 + 突击骑伤害应为 %d" % expected_damage)
		_check(is_equal_approx(leveled_tower.attack_cooldown, guan_yu.attack_interval * charger.attack_interval_multiplier),
			"转职攻速倍率应生效")
		leveled_tower.queue_free()
	var fresh_tower: Tower = tower_manager.build_tower(Vector2(140, 640), guan_yu, null, {"level": 1})
	_check(fresh_tower != null and fresh_tower.damage == guan_yu.base_damage, "1 级无转职应为基础伤害")
	if fresh_tower:
		fresh_tower.queue_free()

	# 投石车（v0.11.1）：职业倍率、min_range 门控、抛射 AOE。
	var huang_fu_song := load("res://resources/characters/huang_fu_song.tres") as CharacterData
	_check(huang_fu_song != null, "皇甫嵩数据应可加载")
	if huang_fu_song != null:
		var catapult_tower: Tower = tower_manager.build_tower(Vector2(60, 100), huang_fu_song, null, {"level": 1})
		_check(catapult_tower != null, "应能建造投石车")
		if catapult_tower:
			_check(catapult_tower.damage == 136 and catapult_tower.range_radius == 360.0
				and is_equal_approx(catapult_tower.attack_cooldown, 2.4),
				"投石车应按 .tres 绝对值配置（136 伤/360 程/2.4s 攻速）")
			catapult_tower.set_process(false)
			var close_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
			close_enemy.set_process(false)
			close_enemy.global_position = catapult_tower.global_position + Vector2(100, 0)
			_check(catapult_tower.find_target() == null, "投石车应无法选取最小射程内的目标")
			var aoe_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
			aoe_target.set_process(false)
			aoe_target.global_position = catapult_tower.global_position + Vector2(250, 0)
			_check(catapult_tower.find_target() == aoe_target, "投石车应能选取射程内且不小于最小射程的目标")
			# 抛射 AOE：预判落点附近的第二只敌人同时受创。
			# 用 300HP 伍长做靶（投石车 136 伤会秒杀步卒，导致目标被释放）。
			var sergeant_data := load("res://resources/enemies/yellow_turban/yellow_turban_sergeant.tres") as EnemyData
			var splash_enemy := enemy_manager.spawn_enemy_from_data(sergeant_data) as Enemy
			splash_enemy.set_process(false)
			splash_enemy.global_position = aoe_target.global_position + Vector2(60, 0)
			var aoe_bearer := enemy_manager.spawn_enemy_from_data(sergeant_data) as Enemy
			aoe_bearer.set_process(false)
			aoe_bearer.global_position = aoe_target.global_position
			catapult_tower.target = aoe_bearer
			catapult_tower.attack()
			for _i in range(80):
				await get_tree().physics_frame
			_check(is_instance_valid(aoe_bearer) and aoe_bearer.current_hp < aoe_bearer.max_hp,
				"抛射应命中预判落点附近的目标")
			_check(is_instance_valid(splash_enemy) and splash_enemy.current_hp < splash_enemy.max_hp,
				"落点范围伤害应波及邻近敌人")
			catapult_tower.queue_free()

	# 剑客职业克制（GDD 4.2，profession_id=pikeman）：对 cavalry 标签敌人伤害 +15%。
	_check(is_equal_approx(
		BehaviorRegistry.get_profession_counter(&"pikeman", [&"cavalry"] as Array[StringName]), 1.15
	), "剑客对骑兵标签应有 1.15 克制倍率")
	_check(is_equal_approx(
		BehaviorRegistry.get_profession_counter(&"pikeman", [&"infantry"] as Array[StringName]), 1.0
	), "剑客对步兵标签应无克制")
	_check(is_equal_approx(
		BehaviorRegistry.get_profession_counter(&"cavalry", [&"cavalry"] as Array[StringName]), 1.0
	), "其他职业不应触发剑客克制")

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

	# 落后补正（GDD 4.4/10.6）：编队平均 3 级（关羽 5 / 刘备 1）时，1 级武将经验 ×1.4。
	var rb_profile := ProfileStore.get_profile()
	rb_profile.add_character_exp("guan_yu", LevelCurve.exp_total_for_level(5))
	var rb_session := BattleSession.new("smoke_rb_stage")
	GameManager.set_battle_session(rb_session)
	rb_session.deployed_character_ids.assign(["guan_yu", "liu_bei"])
	var rb_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
	if rb_enemy:
		rb_enemy.take_damage(9999, "liu_bei")
		_check(int(rb_session.get_pending_xp_by_character().get("liu_bei", 0)) == 10,
			"落后补正后 1 级武将两笔共得 10 点经验（名义 8 × 1.4，逐笔向下取整）")
		rb_enemy.queue_free()

	# 怒气系统（v0.11.2）：命中积怒（命中 4 + 伤害×0.1）→ 满 100 手动触发大招 → 清零。
	var rage_tower: Tower = tower_manager.build_tower(Vector2(60, 640), guan_yu, null, {"level": 1})
	_check(rage_tower != null, "应能建造怒气用例武将塔")
	if rage_tower != null:
		rage_tower.set_process(false)
		# 移除刘备塔以隔离仁德光环对伤害断言的影响
		for node in tower_manager.get_children():
			var t := node as Tower
			if t != null and t.character_id == "liu_bei":
				t.queue_free()
		await get_tree().process_frame
		# 武生特性：精英标签目标伤害 +25%（64 × 1.25 = 80）
		var rage_target := enemy_manager.spawn_enemy_from_data(load("res://resources/enemies/yellow_turban/yellow_turban_sergeant.tres") as EnemyData) as Enemy
		rage_target.set_process(false)
		rage_target.global_position = rage_tower.global_position + Vector2(120, 0)
		rage_tower.target = rage_target
		rage_tower.attack()
		_check(is_equal_approx(rage_tower.rage, 12.0), "命中积怒应为 4 + 伤害×0.1（武生对精英 +25% → 80 伤）")
		rage_tower.rage = 100.0
		var ult_target := enemy_manager.spawn_enemy_from_data(load("res://resources/enemies/yellow_turban/yellow_turban_sergeant.tres") as EnemyData) as Enemy
		ult_target.set_process(false)
		ult_target.global_position = rage_tower.global_position + Vector2(120, 0)
		rage_tower.target = ult_target
		_check(rage_tower._try_cast_ultimate(), "满怒应能释放大招（突击斩杀）")
		print("PROBE ult_hp=", ult_target.current_hp, " power=", rage_tower.ultimate_power(), " rage=", rage_tower.rage)
		_check(ult_target.current_hp == 300 - 240, "斩杀应造成 3×普攻并含武生特性（240）")
	# ===== v0.15.0 技能注册表与演出测试（GDD modules/BEHAVIORS.md B.3.5） =====
	# 注册表完整性：九名武将一转各配一个技能。
	_check(SkillRegistry.SKILL_NAMES.size() == 9 and SkillRegistry.KNOWN_SKILLS.size() == 9,
		"技能注册表应登记 9 个技能")
	_check(SkillRegistry.get_skill_name(&"charge") == "蓄力" and SkillRegistry.get_skill_name(&"wisdom") == "奇谋",
		"技能显示名应可查询")
	# 档位系数：s = 1 + 0.1 × min(battle_level/5, 4)。
	var tier_tower: Tower = tower_manager.build_tower(Vector2(240, 640), guan_yu, null, {"level": 1})
	_check(tier_tower != null, "应能建造档位系数用例塔")
	if tier_tower:
		tier_tower.set_process(false)
		tier_tower.battle_level = 4
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_tower), 1.0), "4 级档位系数应为 1.0")
		tier_tower.battle_level = 5
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_tower), 1.1), "5 级档位系数应为 1.1")
		tier_tower.battle_level = 20
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_tower), 1.4), "20 级档位系数应封顶 1.4")
		tier_tower.queue_free()
	# charge（关羽·突击骑）：大招击杀返怒 50% × s。
	var charge_tower: Tower = tower_manager.build_tower(Vector2(240, 640), guan_yu, null, {"level": 10, "promotion": charger})
	_check(charge_tower != null and charge_tower.has_skill(&"charge"), "突击骑应持有 charge 技能")
	if charge_tower:
		charge_tower.set_process(false)
		_check(is_equal_approx(charge_tower.kill_rage_refund(), 50.0), "charge 基准返怒应为 50")
		charge_tower.battle_level = 5
		_check(is_equal_approx(charge_tower.kill_rage_refund(), 55.0), "charge 5 级返怒应为 55")
		charge_tower.battle_level = 20
		_check(is_equal_approx(charge_tower.kill_rage_refund(), 70.0), "charge 20 级返怒应封顶 70")
		charge_tower.battle_level = 0
		var charge_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		charge_target.set_process(false)
		charge_target.global_position = charge_tower.global_position + Vector2(120, 0)
		charge_tower.target = charge_target
		charge_tower.rage = 100.0
		_check(charge_tower._try_cast_ultimate(), "满怒大招应能释放")
		_check(is_equal_approx(charge_tower.rage, 50.0), "大招击杀应返怒 50（先清怒再返还）")
		charge_tower.battle_level = 5
		charge_tower.rage = 100.0
		var charge_target_2 := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		charge_target_2.set_process(false)
		charge_target_2.global_position = charge_tower.global_position + Vector2(120, 0)
		charge_tower.target = charge_target_2
		_check(charge_tower._try_cast_ultimate(), "5 级满怒大招应能释放")
		_check(is_equal_approx(charge_tower.rage, 55.0), "5 级 charge 击杀返怒应为 55")
		charge_tower.queue_free()
	# siege（皇甫嵩·折冲将军）：对精英/Boss 伤害 +10% × s。
	var siege_promo := load("res://resources/promotions/huang_fu_song_zhechong.tres") as PromotionData
	var siege_tower: Tower = tower_manager.build_tower(Vector2(340, 640), huang_fu_song, null, {"level": 10, "promotion": siege_promo})
	var sergeant_data := load("res://resources/enemies/yellow_turban/yellow_turban_sergeant.tres") as EnemyData
	_check(siege_tower != null and siege_tower.has_skill(&"siege"), "折冲将军应持有攻城锤技能")
	if siege_tower:
		siege_tower.set_process(false)
		var siege_elite := enemy_manager.spawn_enemy_from_data(sergeant_data) as Enemy
		var siege_soldier := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		siege_elite.set_process(false)
		siege_soldier.set_process(false)
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(siege_tower, siege_elite), 1.1),
			"攻城锤对精英应 ×1.1")
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(siege_tower, siege_soldier), 1.0),
			"攻城锤对普通目标应无加成")
		siege_tower.battle_level = 5
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(siege_tower, siege_elite), 1.11),
			"攻城锤 5 级对精英应 ×1.11")
		siege_elite.queue_free()
		siege_soldier.queue_free()
		siege_tower.queue_free()
	# wisdom（诸葛亮·卧龙）：大招范围 +10% × s。
	var zhuge_liang := load("res://resources/characters/zhuge_liang.tres") as CharacterData
	var wisdom_promo := load("res://resources/promotions/zhuge_liang_wolong.tres") as PromotionData
	var wisdom_tower: Tower = tower_manager.build_tower(Vector2(460, 640), zhuge_liang, null, {"level": 10, "promotion": wisdom_promo})
	_check(wisdom_tower != null and wisdom_tower.has_skill(&"wisdom"), "卧龙应持有奇谋技能")
	if wisdom_tower:
		wisdom_tower.set_process(false)
		_check(is_equal_approx(wisdom_tower.ultimate_aoe_radius(100.0), 110.0), "奇谋大招范围应 +10%")
		wisdom_tower.battle_level = 5
		_check(is_equal_approx(wisdom_tower.ultimate_aoe_radius(100.0), 111.0), "奇谋 5 级大招范围应 +11%")
		wisdom_tower.battle_level = 20
		_check(is_equal_approx(wisdom_tower.ultimate_aoe_radius(100.0), 114.0), "奇谋 20 级大招范围应封顶 +14%")
		wisdom_tower.queue_free()
	# dragon_rush（赵云·龙骧卫）：击杀蓄力，下一次伤害 +25% × s 一次性消耗。
	var zhao_yun := load("res://resources/characters/zhao_yun.tres") as CharacterData
	var dragon_promo := load("res://resources/promotions/zhao_yun_dragon_guard.tres") as PromotionData
	var dragon_tower: Tower = tower_manager.build_tower(Vector2(560, 640), zhao_yun, null, {"level": 10, "promotion": dragon_promo})
	_check(dragon_tower != null and dragon_tower.has_skill(&"dragon_rush"), "龙骧卫应持有龙突技能")
	if dragon_tower:
		dragon_tower.set_process(false)
		var dragon_kill := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		dragon_kill.set_process(false)
		dragon_kill.take_damage(9999, "zhao_yun")
		await get_tree().process_frame
		_check(is_equal_approx(dragon_tower.get("_next_attack_bonus"), 0.25), "龙突击杀后应蓄力 +25%")
		var dragon_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		dragon_target.set_process(false)
		_check(dragon_tower.finalize_damage(dragon_tower.damage, dragon_target) == int(round(dragon_tower.damage * 1.25)),
			"龙突下一次伤害应 +25%")
		_check(is_equal_approx(dragon_tower.get("_next_attack_bonus"), 0.0), "龙突应一次性消耗")
		dragon_target.queue_free()
		dragon_tower.queue_free()
	# ferocity/steady（张飞/黄忠）：概率追加伤害，多次命中必触发且为整数倍。
	var ferocity_promo := load("res://resources/promotions/zhang_fei_vanguard.tres") as PromotionData
	var steady_promo := load("res://resources/promotions/huang_zhong_sharpshooter.tres") as PromotionData
	var huang_zhong := load("res://resources/characters/huang_zhong.tres") as CharacterData
	var skill_tank := EnemyData.new()
	skill_tank.enemy_id = &"smoke_skill_tank"
	skill_tank.display_name = "技能木桩"
	skill_tank.max_hp = 10000
	skill_tank.move_speed = 0.0
	skill_tank.currency_reward = 0
	skill_tank.kill_xp = 0
	skill_tank.damage_to_base = 0
	skill_tank.body_color = Color.GRAY
	skill_tank.body_size = Vector2(40, 40)
	var ferocity_tower: Tower = tower_manager.build_tower(Vector2(660, 640), zhang_fei, null, {"level": 10, "promotion": ferocity_promo})
	_check(ferocity_tower != null and ferocity_tower.has_skill(&"ferocity"), "蛇矛先锋应持有凶威技能")
	if ferocity_tower:
		ferocity_tower.set_process(false)
		var ferocity_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		ferocity_target.set_process(false)
		var ferocity_before := ferocity_target.current_hp
		for _i in range(300):
			SkillRegistry.on_attack_hit(ferocity_tower, ferocity_target, ferocity_tower.damage)
		var ferocity_loss := ferocity_before - ferocity_target.current_hp
		_check(ferocity_loss > 0, "凶威应在多次命中中触发追加伤害")
		_check(ferocity_loss % int(round(ferocity_tower.damage * 0.5)) == 0,
			"凶威追加伤害应为 0.5× 普攻的整数倍")
		ferocity_target.queue_free()
		ferocity_tower.queue_free()
	var steady_tower: Tower = tower_manager.build_tower(Vector2(660, 640), huang_zhong, null, {"level": 10, "promotion": steady_promo})
	_check(steady_tower != null and steady_tower.has_skill(&"steady"), "神射手应持有稳射技能")
	if steady_tower:
		steady_tower.set_process(false)
		var steady_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		steady_target.set_process(false)
		var steady_before := steady_target.current_hp
		for _i in range(300):
			SkillRegistry.on_attack_hit(steady_tower, steady_target, steady_tower.damage)
		var steady_loss := steady_before - steady_target.current_hp
		_check(steady_loss > 0, "稳射应在多次命中中触发追加伤害")
		_check(steady_loss % int(round(steady_tower.damage * 0.6)) == 0,
			"稳射追加伤害应为 0.6× 普攻的整数倍")
		steady_target.queue_free()
		steady_tower.queue_free()
	# 大招模式（v0.15.0）：手动满怒待发，自动满怒即放；均触发专属视觉。
	var mode_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
	mode_tank.set_process(false)
	mode_tank.global_position = Vector2(180, 640)
	GameFlow.set_gameplay_flag("manual_ultimate", true)
	var manual_tower: Tower = tower_manager.build_tower(Vector2(60, 640), guan_yu, null, {"level": 1})
	_check(manual_tower != null and bool(manual_tower.get("_manual_ultimate_mode")), "手动开关应使新塔进入手动模式")
	if manual_tower:
		manual_tower.set_process(false)
		manual_tower.target = mode_tank
		manual_tower.rage = 100.0
		manual_tower._process(0.016)
		_check(manual_tower.is_ultimate_ready(), "手动模式满怒应待发")
		_check(is_equal_approx(manual_tower.rage, 100.0), "手动模式满怒不应自动释放")
		_check(manual_tower.cast_ultimate_manual(), "手动释放应成功")
		_check(is_equal_approx(manual_tower.rage, 0.0), "手动释放后怒气应清零")
		_check(float(manual_tower.get("_ult_visual_time")) > 0.0, "手动释放应触发大招视觉")
		manual_tower.queue_free()
	GameFlow.set_gameplay_flag("manual_ultimate", false)
	var auto_tower: Tower = tower_manager.build_tower(Vector2(140, 640), guan_yu, null, {"level": 1})
	_check(auto_tower != null and not bool(auto_tower.get("_manual_ultimate_mode")), "默认模式应满怒即放")
	if auto_tower:
		auto_tower.set_process(false)
		auto_tower.target = mode_tank
		auto_tower.rage = 100.0
		# 攻击在冷却中：_process 不会同帧普攻，避免大招清怒后再积怒。
		auto_tower.attack_timer.start(1.0)
		auto_tower._process(0.016)
		_check(is_equal_approx(auto_tower.rage, 0.0), "自动模式满怒应即放并清怒")
		_check(float(auto_tower.get("_ult_visual_time")) > 0.0, "自动释放应触发大招视觉")
		auto_tower.queue_free()
	mode_tank.queue_free()
	# command（刘备·仁德统军）：150px 内友方伤害 +4% × s。
	var commander_promo := load("res://resources/promotions/liu_bei_commander.tres") as PromotionData
	var commander_tower: Tower = tower_manager.build_tower(Vector2(760, 640), liu_bei, null, {"level": 10, "promotion": commander_promo})
	var command_ally_in: Tower = tower_manager.build_tower(Vector2(820, 640), guan_yu, null, {"level": 1})
	var command_ally_out: Tower = tower_manager.build_tower(Vector2(1040, 640), guan_yu, null, {"level": 1})
	_check(commander_tower != null and commander_tower.has_skill(&"command"), "仁德统军应持有统军令技能")
	if commander_tower and command_ally_in and command_ally_out:
		commander_tower.set_process(false)
		command_ally_in.set_process(false)
		command_ally_out.set_process(false)
		var command_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		command_target.set_process(false)
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(command_ally_in, command_target), 1.04),
			"统军令应使射程内友方伤害 +4%")
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(command_ally_out, command_target), 1.0),
			"统军令对射程外友方应无加成")
		commander_tower.battle_level = 5
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(command_ally_in, command_target), 1.044),
			"统军令 5 级应 +4.4%")
		command_target.queue_free()
	commander_tower.queue_free()
	command_ally_in.queue_free()
	command_ally_out.queue_free()
	# 舞娘光环（v0.11.2）：脉冲增益友方攻速、辅助积怒与贡献经验。
	var diao_chan := load("res://resources/characters/diao_chan.tres") as CharacterData
	_check(diao_chan != null, "貂蝉数据应可加载")
	if diao_chan != null:
		var support_session := BattleSession.new("smoke_support")
		GameManager.set_battle_session(support_session)
		var dancer_tower: Tower = tower_manager.build_tower(Vector2(60, 100), diao_chan, null, {"level": 1})
		var ally_tower: Tower = tower_manager.build_tower(Vector2(140, 100), guan_yu, null, {"level": 1})
		_check(dancer_tower != null and ally_tower != null, "应能建造舞娘与友方塔")
		if dancer_tower != null and ally_tower != null:
			dancer_tower.set_process(false)
			dancer_tower.attack()
			_check(is_equal_approx(ally_tower.attack_speed_buff, 1.2), "光环脉冲应使友方攻速 buff +20%")
			# 射程内 2 名友方（出战塔 + 编队用例塔）：积怒 = (触发 6 + 覆盖 2×2) × 月幕自增 1.2 = 12
			_check(is_equal_approx(dancer_tower.rage, 12.0), "辅助积怒应含触发/覆盖并受月幕 +20%")
			var pending: Dictionary = support_session.get_pending_xp_by_character()
			_check(int(pending.get("diao_chan", 0)) == 6, "辅助贡献经验应为 4 + 覆盖 2 = 6")
		if dancer_tower:
			dancer_tower.queue_free()
		if ally_tower:
			ally_tower.queue_free()

	_finish()


func _finish() -> void:
	get_tree().paused = false
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = _profile_file + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
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
		elif resource is BondData:
			_check((resource as BondData).is_valid(), "BondData 无效: %s" % path)

	for promotion_id in promotions:
		var promotion: PromotionData = promotions[promotion_id]
		for next_id in promotion.next_promotion_ids:
			_check(promotions.has(str(next_id)),
				"转职 %s 引用了不存在的下一转职 %s" % [promotion_id, next_id])

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

