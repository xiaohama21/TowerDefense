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

	# 阶段 8 提交 6（v0.31.0）：职业级转职树——骑兵树铁骑 → 玄甲（强化）/骁骑（新技能）双分支。
	var promo_iron := load("res://resources/promotions/cavalry_iron_rider.tres") as PromotionData
	var promo_heavy := load("res://resources/promotions/cavalry_heavy_armor.tres") as PromotionData
	var promo_raider := load("res://resources/promotions/cavalry_swift_raider.tres") as PromotionData
	_check(promo_iron != null and promo_heavy != null and promo_raider != null, "骑兵职业树二转分支资源应齐全")
	if promo_iron and promo_heavy and promo_raider:
		_check(promo_iron.next_promotion_ids.size() == 2
			and promo_iron.next_promotion_ids.has(&"cavalry_heavy_armor")
			and promo_iron.next_promotion_ids.has(&"cavalry_swift_raider"), "铁骑应配置玄甲/骁骑两个二转分支")
		_check(str(promo_heavy.parent_id) == "cavalry_iron_rider"
			and str(promo_raider.parent_id) == "cavalry_iron_rider", "二转候选 parent 应指向铁骑")
		_check(promo_heavy.ultimate_multiplier > 1.0
			and promo_heavy.damage_multiplier > promo_iron.damage_multiplier, "玄甲应强化大招与三围")
	# 同职业角色共享同一转职树（关羽/赵云均为骑兵，promotion_ids 应一致）。
	var guan_yu_data := load("res://resources/characters/guan_yu.tres") as CharacterData
	var zhao_yun_data := load("res://resources/characters/zhao_yun.tres") as CharacterData
	_check(guan_yu_data != null and zhao_yun_data != null
		and guan_yu_data.promotion_ids == zhao_yun_data.promotion_ids
		and not guan_yu_data.promotion_ids.is_empty(), "同职业角色应共享同一职业转职树")
	# 角色称号（v0.28 纯记录无机制）：原角色专属转职名保留展示。
	_check(guan_yu_data != null and guan_yu_data.titles == ["突击骑", "武圣", "青龙骑"],
		"关羽称号应保留原专属转职名（突击骑/武圣/青龙骑）")
	_check(zhao_yun_data != null and zhao_yun_data.titles == ["龙骧卫"], "赵云称号应为龙骧卫")

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

	# 阶段 8 提交 6（v0.31.0）：转职候选图——未转职给一转（铁骑），铁骑给两个二转分支。
	var stage6_profile := ProfileStore.get_profile()
	if stage6_profile != null:
		stage6_profile.ensure_character("guan_yu")
		stage6_profile.set_promotion_path("guan_yu", [])
		var first_round := GameFlow.get_promotion_candidates(stage6_profile, "guan_yu")
		_check(first_round.size() == 1 and str(first_round[0].promotion_id) == "cavalry_iron_rider",
			"未转职关羽应只有一转候选（铁骑）")
		stage6_profile.set_promotion_path("guan_yu", ["cavalry_iron_rider"])
		var second_round := GameFlow.get_promotion_candidates(stage6_profile, "guan_yu")
		_check(second_round.size() == 2, "铁骑应提供两个二转分支候选")
		stage6_profile.set_promotion_path("guan_yu", ["cavalry_iron_rider", "cavalry_heavy_armor"])
		var second_active := GameFlow.get_active_promotion(stage6_profile, "guan_yu")
		_check(second_active != null and str(second_active.promotion_id) == "cavalry_heavy_armor",
			"二转后生效转职应为路径末位（玄甲）")
		var stage6_guan_yu := load("res://resources/characters/guan_yu.tres") as CharacterData
		if stage6_guan_yu != null and second_active != null:
			var xuanjia_stats := stage6_guan_yu.compute_stats_at(20, second_active)
			var xuanjia_expected := int(round((stage6_guan_yu.base_damage + stage6_guan_yu.damage_growth_per_level * 19) * 1.35))
			_check(int(xuanjia_stats["damage"]) == xuanjia_expected,
				"二转玄甲伤害倍率应生效（×1.35，含 20 级成长）")
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
	_check(Difficulty.count() == 2 and Difficulty.name(Difficulty.NORMAL) == "标准"
		and Difficulty.name(Difficulty.HARD) == "困难"
		and Difficulty.key_name(Difficulty.NORMAL) == "normal",
		"难度应两档化（标准/困难，data-driven difficulty_presets，v0.31.2）")

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

	# 阶段 6 提交 2（v0.18.0）+ 阶段 8 提交 3：科技树配置化——四类分页、31 项、加成汇总来自配置。
	var tech_items := TechTree.get_items()
	_check(tech_items.size() == 31, "科技树配置应含 31 项（军略15/后勤5/工事3/将略8）")
	_check(TechTree.get_categories() == ["军略", "后勤", "工事", "将略"], "科技树应为四类分页（军略/后勤/工事/将略）")
	_check(TechTree.get_items_by_category("军略").size() == 15, "军略分类应含 15 项（职业强化）")
	# 独立临时档案验证加成，避免解锁污染共享存档（后续伤害断言不受 +6% 影响）。
	var tech_profile := PlayerProfile.new()
	tech_profile.add_tech_points(30)
	tech_profile.unlock_tech("mil_dmg_1", 1)
	tech_profile.unlock_tech("mil_dmg_2", 2)
	_check(TechTree.get_tech_bonuses(tech_profile).get("damage_pct", 0) == 6,
			"军事分支加成应来自配置（精兵 2% + 老兵 4%）")
	# 阶段 8 提交 3：职业分支/机制分支效果与无条件重置。
	tech_profile.unlock_tech("prof_tiger_guard_2", 2)
	tech_profile.unlock_tech("eco_wave_2", 2)
	tech_profile.unlock_tech("strat_refund_1", 1)
	var tech_bonuses := TechTree.get_tech_bonuses(tech_profile)
	_check(int(tech_bonuses.get("profession_tiger_guard_damage_pct", 0)) == 6, "虎贲职业加成应来自配置")
	_check(int(tech_bonuses.get("wave_reward_pct", 0)) == 40, "波次奖励科技应生效（+40%）")
	_check(int(tech_bonuses.get("sell_refund_pct", 0)) == 5, "回收率科技应生效（+5%）")
	var reset_refund := TechTree.reset_tech(tech_profile)
	_check(reset_refund == 8, "无条件重置应全额返还科技点（1+2+2+2+1）")
	_check(tech_profile.tech_unlocks.is_empty() and tech_profile.tech_points == 30,
		"重置后应清空科技并返还累计消耗")

	# 阶段 7（v0.19.0）：局内遗物——5 件可加载、汇总叠加、永久使用（v0.33.1，选带不消耗库存）、s08 掉落、fast_charger 配置。
	var battle_relic_ids: Array[String] = ["wolf_tooth", "iron_shield", "war_drums", "scout_eye", "provision_bag"]
	var loaded_relics := 0
	for relic_id in battle_relic_ids:
		var relic := GameFlow.load_battle_relic_data(relic_id)
		if relic != null and relic.is_valid():
			loaded_relics += 1
	_check(loaded_relics == 5, "局内遗物 5 件应全部可加载")
	var stage7_profile := ProfileStore.get_profile()
	if stage7_profile != null:
		for relic_id in battle_relic_ids:
			stage7_profile.add_item(relic_id, 1)
		_check(GameFlow.get_owned_relic_ids(stage7_profile).size() == 5, "背包应可枚举全部 5 件遗物")
		GameFlow.set_squad_relics(["wolf_tooth", "war_drums", "scout_eye", "provision_bag", "wolf_tooth"])
		var relic_bonuses := GameFlow.get_battle_relic_bonuses()
		_check(GameFlow.squad_relic_ids.size() == 4, "同 ID 遗物不应重复选带")
		_check(int(relic_bonuses["damage_bonus_pct"]) == 5 and int(relic_bonuses["start_gold"]) == 50,
			"遗物汇总应叠加伤害/初始金币")
		GameFlow.set_squad_relics(["iron_shield", "wolf_tooth"])
		var relic_bonuses_2 := GameFlow.get_battle_relic_bonuses()
		_check(int(relic_bonuses_2["base_hp_bonus"]) == 10 and int(relic_bonuses_2["damage_bonus_pct"]) == 5,
			"遗物汇总应叠加基地生命")
		_check(is_equal_approx(float(relic_bonuses["attack_interval_factor"]), 0.95)
			and int(relic_bonuses["range_bonus_pct"]) == 10, "遗物汇总应叠加攻速/射程")
		# ✅ v0.33.1：遗物改永久使用——选带不消耗库存（consume_squad_relics 已随 B-019 移除）。
		_check(int(stage7_profile.items.get("wolf_tooth", 0)) == 1
			and int(stage7_profile.items.get("iron_shield", 0)) == 1
			and int(stage7_profile.items.get("provision_bag", 0)) == 1,
			"遗物应永久使用——选带/结算均不消耗库存")
		GameFlow.clear_squad_relics()
	var stage7_cavalry := load("res://resources/enemies/yellow_turban/yellow_turban_cavalry.tres") as EnemyData
	_check(stage7_cavalry != null and stage7_cavalry.special_behavior_id == &"fast_charger",
		"黄巾轻骑应配置 fast_charger 行为")
	var s08_stage := load("res://resources/stages/chapter_01/ch01_s08.tres") as StageData
	var s08_has_wolf := false
	if s08_stage != null:
		for reward in s08_stage.first_clear_rewards:
			if reward != null and reward.item != null and str(reward.item.item_id) == "wolf_tooth":
				s08_has_wolf = true
	_check(s08_stage != null and s08_has_wolf, "s08 首通掉落应含狼牙符")

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
		# 阶段 8 提交 3（v0.23.0 拍板）：空地自由建造——非道路/非禁建/未占用网格两次点击确认。
		GameManager.gold = 9999
		build_manager.selected_character = guan_yu
		var free_cell := Vector2i(2, 6)
		var free_pos: Vector2 = build_manager.cell_center(free_cell)
		var before_free := tower_manager.get_child_count()
		build_manager._on_map_clicked(free_pos)
		_check(build_manager._pending_cell == free_cell, "点击空地应进入待确认网格")
		build_manager._on_map_clicked(free_pos)
		await get_tree().process_frame
		_check(tower_manager.get_child_count() == before_free + 1, "空地自由建造应成功建塔")
		build_manager.cancel_pending()
		build_manager._on_map_clicked(build_manager.cell_center(Vector2i(4, 3)))
		_check(build_manager._pending_cell == Vector2i(-1, -1), "道路格应拒绝建造")
		build_manager.cancel_pending()
		build_manager._on_map_clicked(build_manager.cell_center(Vector2i(0, 1)))
		_check(build_manager._pending_cell == Vector2i(-1, -1), "禁建地形应拒绝建造")
		build_manager.cancel_pending()
		var occupied_pos: Vector2 = tower_manager.get_child(0).global_position
		build_manager._on_map_clicked(occupied_pos)
		_check(build_manager._pending_cell == Vector2i(-1, -1), "已有防御塔网格应拒绝建造")
		build_manager.cancel_pending()

	# 可建格悬停预览（v0.33.2，BUGS B-021）：选中武将后，扫过可建空地显示、
	# 扫过道路/禁建/已占用格与地图外不显示。
	build_manager.cancel_pending()
	var hover_cell := Vector2i(-1, -1)
	for col in range(GridBackground.COLS):
		for row in range(GridBackground.ROWS):
			var candidate := Vector2i(col, row)
			if build_manager._road_cells.has(candidate) or build_manager._forbidden_cells.has(candidate):
				continue
			if build_manager._is_cell_occupied(candidate):
				continue
			hover_cell = candidate
			break
		if hover_cell.x >= 0:
			break
	_check(hover_cell.x >= 0, "冒烟地图应存在可建空地（B-021 用例前置）")
	if hover_cell.x >= 0:
		build_manager._update_hover_preview(build_manager.cell_center(hover_cell))
		_check(build_manager._preview != null and build_manager._preview.visible,
			"扫过可建空地应显示半透明绿色悬停预览（B-021）")
	var hover_road := Vector2i(-1, -1)
	for cell in build_manager._road_cells.keys():
		hover_road = cell as Vector2i
		break
	if hover_road.x >= 0:
		build_manager._update_hover_preview(build_manager.cell_center(hover_road))
		_check(not build_manager._preview.visible, "扫过道路格不应显示悬停预览（B-021）")
	build_manager._update_hover_preview(Vector2(10000, 10000))
	_check(not build_manager._preview.visible, "扫出地图外不应显示悬停预览（B-021）")
	build_manager.cancel_pending()
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
	# 阶段 8 提交 2（P0 3.3）：波次完成金币奖励。
	wave.completion_currency = 10
	wave_manager.configure_waves([wave])
	GameManager.total_waves = 1
	GameManager.reset_combo()
	var gold_before_wave := GameManager.gold
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
	# 击杀奖励（士兵 10 金）+ 波次奖励（completion_currency 10 金）。
	_check(GameManager.gold == gold_before_wave + 20,
		"波次完成应发放击杀奖励与 completion_currency（实际 +%d）" % (GameManager.gold - gold_before_wave))
	_check(GameManager.combo_count == 0 and GameManager.combo_tier == 0, "每波结束应清零连击")
	# 连击档位（P0 4.1）：5/10/15 连击进入 1/2/3 档，每波结束清零。
	GameManager._advance_combo()
	GameManager._advance_combo()
	GameManager._advance_combo()
	GameManager._advance_combo()
	GameManager._advance_combo()
	_check(GameManager.combo_count == 5 and GameManager.combo_tier == 1,
		"5 连击应进入连击档位 1（实际 count=%d tier=%d）" % [GameManager.combo_count, GameManager.combo_tier])
	for _i in range(5):
		GameManager._advance_combo()
	_check(GameManager.combo_tier == 2, "10 连击应进入连击档位 2（实际 tier=%d）" % GameManager.combo_tier)
	for _i in range(5):
		GameManager._advance_combo()
	_check(GameManager.combo_tier == 3, "15 连击应进入连击档位 3（实际 tier=%d）" % GameManager.combo_tier)
	GameManager.reset_combo()
	_check(GameManager.combo_count == 0 and GameManager.combo_tier == 0, "波次结束/重开应清零连击")

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
			_check(upgrade_cost_1 == ceili(zhang_fei.build_cost * 0.8), "第一次升阶费用应为造价×0.8")
			_check(tower_manager.upgrade_tower(spear_tower, stage_data), "金币充足时应能升阶")
			_check(spear_tower.battle_rank == 1, "升阶后局内阶数应为 1")
			_check(spear_tower.damage == int(round(zhang_fei.base_damage * 1.15)), "虎贲一阶伤害应为 +15%")
			_check(is_equal_approx(spear_tower.attack_cooldown, zhang_fei.attack_interval / 1.08), "虎贲一阶攻速应为 +8%")
			_check(is_equal_approx(spear_tower.range_radius, zhang_fei.base_range * 1.03), "虎贲一阶射程应为 +3%")
			_check(tower_manager.upgrade_tower(spear_tower, stage_data), "第二次升阶应成功")
			_check(tower_manager.upgrade_tower(spear_tower, stage_data), "第三次升阶应成功")
			_check(spear_tower.battle_rank == stage_data.max_inbattle_upgrade_level, "升阶应止步于本关上限")
			_check(not tower_manager.upgrade_tower(spear_tower, stage_data), "超过上限后升阶应失败")

			# 近战行为集成（虎贲）（GDD modules/BEHAVIORS.md melee_thrust）：
			# 直伤一次带骑兵标签的轻骑，验证 15% 克制与近战无弹道。
			var cavalry_data := load("res://resources/enemies/yellow_turban/yellow_turban_cavalry.tres") as EnemyData
			var melee_target := enemy_manager.spawn_enemy_from_data(cavalry_data) as Enemy
			_check(melee_target != null, "近战用例应能生成轻骑")
			if melee_target != null:
				melee_target.set_process(false)
				# 升阶测试已把塔升到满阶（rank 3），提高测试敌人血量避免被秒杀，
				# 保证克制/光环伤害断言可精确比较。
				melee_target.max_hp = 999
				melee_target.current_hp = 999
				melee_target.global_position = spear_tower.global_position + Vector2(60, 0)
				spear_tower.target = melee_target
				spear_tower.attack()
				# 刘备塔在场：仁德光环使其他塔伤害 +8%（v0.11.2 特性生效）
				var benevolence := 1.08
				_check(
					melee_target.current_hp == melee_target.max_hp - int(round(spear_tower.damage * 1.15 * benevolence)),
					"虎贲近战直伤应含 15% 骑兵克制与 8% 仁德光环"
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
		# 待删除的张飞塔会跑完最后一帧 _process（角色技能就绪时自动释放当阳桥，
		# 击退手动摆放的后续用例敌人）。先等一帧让 queue_free 生效，隔离后续用例。
		await get_tree().process_frame

	# 局内军需（阶段 8 提交 1，NUMBERS.md 10.9）：四件资源齐全、效果数值已配置。
	var supply_repair := load("res://resources/battle_supplies/repair.tres") as BattleSupplyData
	var supply_fire := load("res://resources/battle_supplies/fire_attack.tres") as BattleSupplyData
	var supply_drum := load("res://resources/battle_supplies/war_drum.tres") as BattleSupplyData
	var supply_slow := load("res://resources/battle_supplies/slow_down.tres") as BattleSupplyData
	_check(supply_repair != null and supply_fire != null and supply_drum != null and supply_slow != null, "四件军需资源应可加载")
	if supply_repair != null and supply_fire != null and supply_drum != null and supply_slow != null:
		_check(supply_repair.is_valid() and supply_fire.is_valid() and supply_drum.is_valid() and supply_slow.is_valid(), "军需资源配置应有效")
		_check(supply_repair.heal_amount == 10 and supply_fire.burn_dps > 0 and supply_drum.attack_speed_bonus > 0.0
			and supply_slow.slow_factor < 1.0, "军需效果数值应已配置")
	# 灼烧（火攻）：每秒 burn_dps 持续扣血，25/s × 3s = 75。
	var burn_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
	_check(burn_target != null, "灼烧用例应能生成敌人")
	if burn_target != null:
		burn_target.set_process(false)
		burn_target.current_hp = burn_target.max_hp
		burn_target.apply_burn(25, 3.0)
		for _i in range(60):
			burn_target._process(0.05)
		var burn_dealt := burn_target.max_hp - burn_target.current_hp
		_check(abs(burn_dealt - 75) <= 1, "灼烧 3 秒应造成约 75 点伤害（实际 %d）" % burn_dealt)
		burn_target.die(false)

	# 等级曲线（GDD modules/NUMBERS.md 10.1）
	_check(LevelCurve.exp_total_for_level(10) == 1440, "10 级累计经验应为 1440")
	_check(LevelCurve.level_from_total_exp(0) == 1, "0 经验应为 1 级")
	_check(LevelCurve.level_from_total_exp(1439) == 9 and LevelCurve.level_from_total_exp(1440) == 10,
		"等级应按累计经验推导")
	_check(LevelCurve.level_from_total_exp(999999) == LevelCurve.max_level(), "等级不应超过上限")

	# 等级与转职属性应用（GDD 4.4/4.5）：伤害 = (基础 + 成长×(级-1)) × 转职倍率
	var charger := load("res://resources/promotions/cavalry_iron_rider.tres") as PromotionData
	_check(charger != null and not charger.item_costs.is_empty(), "一转配置应含材料消耗")
	GameManager.reset(9999, 20, stage_data.waves.size())
	var leveled_tower: Tower = tower_manager.build_tower(Vector2(60, 640), guan_yu, null, {"level": 10, "promotion": charger})
	_check(leveled_tower != null, "应以等级/转职参数建造武将塔")
	if leveled_tower:
		var expected_damage := int(round((guan_yu.base_damage + guan_yu.damage_growth_per_level * 9) * charger.damage_multiplier))
		_check(leveled_tower.damage == expected_damage, "10 级 + 铁骑伤害应为 %d" % expected_damage)
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


	# 虎贲职业克制（GDD 4.2，profession_id=tiger_guard）：对 cavalry 标签敌人伤害 +15%。
	_check(is_equal_approx(
		BehaviorRegistry.get_profession_counter(&"tiger_guard", [&"cavalry"] as Array[StringName]), 1.15
	), "虎贲对骑兵标签应有 1.15 克制倍率")
	_check(is_equal_approx(
		BehaviorRegistry.get_profession_counter(&"tiger_guard", [&"infantry"] as Array[StringName]), 1.0
	), "虎贲对步兵标签应无克制")
	_check(is_equal_approx(
		BehaviorRegistry.get_profession_counter(&"cavalry", [&"cavalry"] as Array[StringName]), 1.0
	), "其他职业不应触发虎贲克制")

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
		_check(ult_target.current_hp == 300 - 240, "斩杀应造成 3×普攻并含武生特性（240）")
	# ===== v0.15.0 技能注册表与演出测试（GDD modules/BEHAVIORS.md B.3.5） =====
	# 职业技能显示名查询（注册表完整性由下方 v0.28.0 断言覆盖：每职业 1 技能共 6 个）。
	_check(SkillRegistry.get_skill_name(&"charge") == "蓄力" and SkillRegistry.get_skill_name(&"wisdom") == "奇谋",
		"技能显示名应可查询")
	# 档位系数：s = 1 + 0.1 × min(battle_rank/5, 4)。
	var tier_tower: Tower = tower_manager.build_tower(Vector2(240, 640), guan_yu, null, {"level": 1})
	_check(tier_tower != null, "应能建造档位系数用例塔")
	if tier_tower:
		tier_tower.set_process(false)
		tier_tower.battle_rank = 4
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_tower), 1.0), "4 级档位系数应为 1.0")
		tier_tower.battle_rank = 5
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_tower), 1.1), "5 级档位系数应为 1.1")
		tier_tower.battle_rank = 20
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_tower), 1.4), "20 级档位系数应封顶 1.4")
		tier_tower.queue_free()
	# 阶段 7（v0.19.0）：局内遗物伤害加成应进 finalize_damage 乘法区（狼牙符 +5%）。
	GameFlow.set_squad_relics(["wolf_tooth"])
	var relic_probe_tower: Tower = tower_manager.build_tower(Vector2(240, 640), guan_yu, null, {"level": 1})
	_check(relic_probe_tower != null, "应能建造遗物伤害探针塔")
	if relic_probe_tower != null:
		relic_probe_tower.set_process(false)
		var relic_probe_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		relic_probe_enemy.set_process(false)
		var expected_relic_damage := int(round(relic_probe_tower.damage * 1.05))
		_check(relic_probe_tower.finalize_damage(relic_probe_tower.damage, relic_probe_enemy) == expected_relic_damage,
			"狼牙符应使伤害 +5%")
		relic_probe_enemy.queue_free()
		relic_probe_tower.queue_free()
	GameFlow.clear_squad_relics()
	# charge（关羽·铁骑）：大招击杀返怒 50% × s。
	var charge_tower: Tower = tower_manager.build_tower(Vector2(240, 640), guan_yu, null, {"level": 10, "promotion": charger})
	_check(charge_tower != null and charge_tower.has_skill(&"charge"), "铁骑应持有 charge 技能")
	if charge_tower:
		charge_tower.set_process(false)
		_check(is_equal_approx(charge_tower.kill_rage_refund(), 50.0), "charge 基准返怒应为 50")
		charge_tower.battle_rank = 5
		_check(is_equal_approx(charge_tower.kill_rage_refund(), 55.0), "charge 5 级返怒应为 55")
		charge_tower.battle_rank = 20
		_check(is_equal_approx(charge_tower.kill_rage_refund(), 70.0), "charge 20 级返怒应封顶 70")
		charge_tower.battle_rank = 0
		var charge_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		charge_target.set_process(false)
		charge_target.global_position = charge_tower.global_position + Vector2(120, 0)
		charge_tower.target = charge_target
		charge_tower.rage = 100.0
		_check(charge_tower._try_cast_ultimate(), "满怒大招应能释放")
		_check(is_equal_approx(charge_tower.rage, 50.0), "大招击杀应返怒 50（先清怒再返还）")
		charge_tower.battle_rank = 5
		charge_tower.rage = 100.0
		var charge_target_2 := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		charge_target_2.set_process(false)
		charge_target_2.global_position = charge_tower.global_position + Vector2(120, 0)
		charge_tower.target = charge_target_2
		_check(charge_tower._try_cast_ultimate(), "5 级满怒大招应能释放")
		_check(is_equal_approx(charge_tower.rage, 55.0), "5 级 charge 击杀返怒应为 55")
		charge_tower.queue_free()
	# siege（皇甫嵩·霹雳车）：对精英/Boss 伤害 +10% × s。
	var siege_promo := load("res://resources/promotions/catapult_thunder.tres") as PromotionData
	var siege_tower: Tower = tower_manager.build_tower(Vector2(340, 640), huang_fu_song, null, {"level": 10, "promotion": siege_promo})
	var sergeant_data := load("res://resources/enemies/yellow_turban/yellow_turban_sergeant.tres") as EnemyData
	_check(siege_tower != null and siege_tower.has_skill(&"siege"), "霹雳车应持有破城技能")
	if siege_tower:
		siege_tower.set_process(false)
		var siege_elite := enemy_manager.spawn_enemy_from_data(sergeant_data) as Enemy
		var siege_soldier := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		siege_elite.set_process(false)
		siege_soldier.set_process(false)
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(siege_tower, siege_elite), 1.1),
			"破城对精英应 ×1.1")
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(siege_tower, siege_soldier), 1.0),
			"破城对普通目标应无加成")
		siege_tower.battle_rank = 5
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(siege_tower, siege_elite), 1.11),
			"破城 5 阶对精英应 ×1.11（档位按局内升阶）")
		siege_elite.queue_free()
		siege_soldier.queue_free()
		siege_tower.queue_free()
	# wisdom（诸葛亮·方士）：大招范围 +10% × s。
	var zhuge_liang := load("res://resources/characters/zhuge_liang.tres") as CharacterData
	var wisdom_promo := load("res://resources/promotions/strategist_mage.tres") as PromotionData
	var wisdom_tower: Tower = tower_manager.build_tower(Vector2(460, 640), zhuge_liang, null, {"level": 10, "promotion": wisdom_promo})
	_check(wisdom_tower != null and wisdom_tower.has_skill(&"wisdom"), "方士应持有奇谋技能")
	if wisdom_tower:
		wisdom_tower.set_process(false)
		_check(is_equal_approx(wisdom_tower.ultimate_aoe_radius(100.0), 110.0), "奇谋大招范围应 +10%")
		wisdom_tower.battle_rank = 5
		_check(is_equal_approx(wisdom_tower.ultimate_aoe_radius(100.0), 111.0), "奇谋 5 级大招范围应 +11%")
		wisdom_tower.battle_rank = 20
		_check(is_equal_approx(wisdom_tower.ultimate_aoe_radius(100.0), 114.0), "奇谋 20 级大招范围应封顶 +14%")
		wisdom_tower.queue_free()
	# 职业技能注册表（提交 7）：6 核心 + 6 二转新技能；龙突/凶威/斩获已移除。
	_check(SkillRegistry.KNOWN_SKILLS.size() == 12
		and SkillRegistry.KNOWN_SKILLS.has(&"charge") and SkillRegistry.KNOWN_SKILLS.has(&"command")
		and SkillRegistry.KNOWN_SKILLS.has(&"steady") and SkillRegistry.KNOWN_SKILLS.has(&"wisdom")
		and SkillRegistry.KNOWN_SKILLS.has(&"inspire") and SkillRegistry.KNOWN_SKILLS.has(&"siege")
		and SkillRegistry.KNOWN_SKILLS.has(&"assault") and SkillRegistry.KNOWN_SKILLS.has(&"guard")
		and SkillRegistry.KNOWN_SKILLS.has(&"chain_arrow") and SkillRegistry.KNOWN_SKILLS.has(&"mystic_gate")
		and SkillRegistry.KNOWN_SKILLS.has(&"echo") and SkillRegistry.KNOWN_SKILLS.has(&"tremor"),
		"职业技能应为 6 核心 + 6 二转新技能（提交 7）")
	_check(not SkillRegistry.KNOWN_SKILLS.has(&"dragon_rush")
		and not SkillRegistry.KNOWN_SKILLS.has(&"ferocity")
		and not SkillRegistry.KNOWN_SKILLS.has(&"bulwark"), "龙突/凶威/斩获应已移除")
	# 蓄力（赵云·铁骑）：大招击杀返怒 50%（基础，原龙突移除）。
	var zhao_yun := load("res://resources/characters/zhao_yun.tres") as CharacterData
	var dragon_promo := load("res://resources/promotions/cavalry_iron_rider.tres") as PromotionData
	var dragon_tower: Tower = tower_manager.build_tower(Vector2(560, 640), zhao_yun, null, {"level": 10, "promotion": dragon_promo})
	_check(dragon_tower != null and dragon_tower.has_skill(&"charge"), "铁骑应持有蓄力技能")
	if dragon_tower:
		dragon_tower.set_process(false)
		_check(is_equal_approx(dragon_tower.kill_rage_refund(), 50.0), "龙骧卫蓄力基础返怒应为 50%")
		_check(is_equal_approx(float(dragon_tower.get("_next_attack_bonus")), 0.0), "基础蓄力不应附带击杀下一击加成")
		dragon_tower.queue_free()
	# 蓄力+（关羽·玄甲）：二转强化线——大招击杀返怒 70%×s（SKILLS.md 4.1）。
	var heavy_promo := load("res://resources/promotions/cavalry_heavy_armor.tres") as PromotionData
	var heavy_tower: Tower = tower_manager.build_tower(Vector2(560, 640), guan_yu, null, {"level": 20, "promotion": heavy_promo})
	_check(heavy_tower != null and heavy_tower.has_skill(&"charge"), "玄甲应持有蓄力+技能")
	if heavy_tower:
		heavy_tower.set_process(false)
		_check(heavy_tower.get_skill_display_name(&"charge") == "蓄力+", "二转强化技能显示名应加 +")
		_check(is_equal_approx(heavy_tower.kill_rage_refund(), 70.0), "玄甲蓄力+基准返怒应为 70%")
		heavy_tower.battle_rank = 5
		_check(is_equal_approx(heavy_tower.kill_rage_refund(), 77.0), "玄甲 5 阶返怒应为 77%（档位按局内升阶）")
		heavy_tower.battle_rank = 20
		_check(is_equal_approx(heavy_tower.kill_rage_refund(), 98.0), "玄甲 20 阶返怒应封顶 98%")
		heavy_tower.queue_free()
	# 军旗（张飞·虎贲军）：常驻光环，周围 150px 友方伤害 +4%×s。
	var vanguard_promo := load("res://resources/promotions/tiger_guard_army.tres") as PromotionData
	var steady_promo := load("res://resources/promotions/archer_strong_bow.tres") as PromotionData
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
	var vanguard_tower: Tower = tower_manager.build_tower(Vector2(660, 640), zhang_fei, null, {"level": 10, "promotion": vanguard_promo})
	_check(vanguard_tower != null and vanguard_tower.has_skill(&"command"), "虎贲军应持有军旗技能")
	if vanguard_tower:
		vanguard_tower.set_process(false)
		var banner_ally: Tower = tower_manager.build_tower(Vector2(700, 640), guan_yu, null, {"level": 1})
		var banner_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		banner_target.set_process(false)
		if banner_ally:
			banner_ally.set_process(false)
			banner_ally.refresh_aura_damage_bonus()
			_check(is_equal_approx(float(banner_ally.get("_aura_damage_bonus")), 0.04),
				"军旗应使射程内友方伤害 +4%（收敛进光环伤害桶）")
			banner_ally.queue_free()
		banner_target.queue_free()
		vanguard_tower.queue_free()
		# 等一帧释放军旗塔，避免其光环污染稳射的伤害断言。
		await get_tree().process_frame
	# 稳射（黄忠·劲弓）：保底触发——每 5 次攻击必追加 0.6× 普攻伤害。
	var steady_tower: Tower = tower_manager.build_tower(Vector2(660, 640), huang_zhong, null, {"level": 10, "promotion": steady_promo})
	_check(steady_tower != null and steady_tower.has_skill(&"steady"), "劲弓应持有稳射技能")
	if steady_tower:
		steady_tower.set_process(false)
		var steady_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		steady_target.set_process(false)
		var steady_before := steady_target.current_hp
		for _i in range(300):
			SkillRegistry.on_attack_hit(steady_tower, steady_target, steady_tower.damage)
		var steady_loss := steady_before - steady_target.current_hp
		_check(steady_loss == 60 * int(round(steady_tower.damage * 0.6)),
			"稳射 300 次攻击应恰好触发 60 次（每 5 次保底）")
		_check(steady_loss % int(round(steady_tower.damage * 0.6)) == 0,
			"稳射追加伤害应为 0.6× 普攻的整数倍")
		steady_target.queue_free()
		steady_tower.queue_free()

	# 命中事件拆分（v0.31.4 / 0.8.6.2）：远程普攻发射不积怒，弹道命中造成伤害后才积怒；
	# 目标飞行中死亡则整发作废（不积怒、不计数）。
	var event_char := load("res://resources/characters/huang_zhong.tres") as CharacterData
	var event_tower: Tower = tower_manager.build_tower(Vector2(80, 700), event_char, null, {"level": 1})
	_check(event_tower != null, "应能建造命中事件用例塔（黄忠·弓箭手）")
	if event_tower != null:
		event_tower.set_process(false)
		event_tower.rage = 0.0
		var hit_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		hit_enemy.set_process(false)
		hit_enemy.global_position = event_tower.global_position + Vector2(120, 0)
		event_tower.target = hit_enemy
		event_tower.attack()
		_check(is_equal_approx(event_tower.rage, 0.0), "远程普攻发射瞬间不应积怒（v0.31.4）")
		var arrow: Bullet = null
		for child in event_tower.get_tree().current_scene.get_children():
			if child is Bullet and not child.is_queued_for_deletion() and (child as Bullet).source_tower == event_tower:
				arrow = child
				break
		_check(arrow != null, "发射后应存在飞行中的子弹")
		if arrow != null and is_instance_valid(hit_enemy):
			var expected_rage := 4.0 + float(arrow.damage) * 0.1
			arrow.max_lifetime = 60.0
			arrow._physics_process(10.0)
			_check(is_equal_approx(event_tower.rage, expected_rage),
				"子弹命中造成伤害后才应积怒（4 + 伤害×0.1）")
		# 目标飞行中死亡：该发作废、不积怒。
		event_tower.rage = 0.0
		var lost_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		lost_enemy.set_process(false)
		lost_enemy.global_position = event_tower.global_position + Vector2(120, 0)
		event_tower.target = lost_enemy
		event_tower.attack()
		var dud_arrow: Bullet = null
		for child in event_tower.get_tree().current_scene.get_children():
			if child is Bullet and not child.is_queued_for_deletion() and (child as Bullet).source_tower == event_tower:
				dud_arrow = child
				break
		if dud_arrow != null:
			dud_arrow.max_lifetime = 60.0
			lost_enemy.take_damage(99999, "other_tower")
			dud_arrow._physics_process(10.0)
			_check(is_equal_approx(event_tower.rage, 0.0), "目标飞行中死亡，子弹作废不应积怒（v0.31.4）")
		event_tower.queue_free()
		if is_instance_valid(hit_enemy):
			hit_enemy.queue_free()
		if is_instance_valid(lost_enemy):
			lost_enemy.queue_free()

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
	# command（刘备·虎贲军）：150px 内友方伤害 +4% × s。
	var commander_promo := load("res://resources/promotions/tiger_guard_army.tres") as PromotionData
	var commander_tower: Tower = tower_manager.build_tower(Vector2(760, 640), liu_bei, null, {"level": 10, "promotion": commander_promo})
	var command_ally_in: Tower = tower_manager.build_tower(Vector2(820, 640), guan_yu, null, {"level": 1})
	var command_ally_out: Tower = tower_manager.build_tower(Vector2(1040, 640), guan_yu, null, {"level": 1})
	_check(commander_tower != null and commander_tower.has_skill(&"command"), "虎贲军应持有军旗技能")
	if commander_tower and command_ally_in and command_ally_out:
		commander_tower.set_process(false)
		command_ally_in.set_process(false)
		command_ally_out.set_process(false)
		var command_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		command_target.set_process(false)
		# 刘备塔同时是仁德源（全图 +8%）与军旗源（150px +4%）：收敛为光环桶加法。
		command_ally_in.refresh_aura_damage_bonus()
		command_ally_out.refresh_aura_damage_bonus()
		_check(is_equal_approx(float(command_ally_in.get("_aura_damage_bonus")), 0.12),
			"军旗+仁德应同区加法收敛（档次 1：0.08 + 0.04 = 0.12，射程内）")
		_check(is_equal_approx(float(command_ally_out.get("_aura_damage_bonus")), 0.08),
			"军旗对射程外友方应无加成（仅剩仁德 0.08）")
		commander_tower.battle_rank = 5
		command_ally_in.refresh_aura_damage_bonus()
		_check(is_equal_approx(float(command_ally_in.get("_aura_damage_bonus")), 0.124),
			"军旗 5 阶应 +4.4%（档位按局内升阶 → 0.08 + 0.044 = 0.124）")
		command_target.queue_free()
	commander_tower.queue_free()
	command_ally_in.queue_free()
	command_ally_out.queue_free()
	# 等一帧释放刘备塔，避免其仁德光环污染后续角色技能伤害断言。
	# ===== 阶段 8 提交 7（v0.32.0 / 0.8.7.0）：职业技能双轨——继承/显示/新技能口径/光环桶 =====
	# 双轨数据：6 条二转新技能线 = 核心技能 + 新技能两个 id、enhanced 留空；
	# 6 条强化线 granted 与 enhanced 均配核心技能 id（显示带 + 由 enhanced 决定）。
	var c7_dual := [
		["res://resources/promotions/cavalry_swift_raider.tres", &"charge", &"assault"],
		["res://resources/promotions/tiger_guard_guard.tres", &"command", &"guard"],
		["res://resources/promotions/archer_crossbow.tres", &"steady", &"chain_arrow"],
		["res://resources/promotions/strategist_heavenly_master.tres", &"wisdom", &"mystic_gate"],
		["res://resources/promotions/dancer_echo.tres", &"inspire", &"echo"],
		["res://resources/promotions/catapult_earthquake.tres", &"siege", &"tremor"],
	]
	for c7_entry in c7_dual:
		var c7_promo := load(c7_entry[0]) as PromotionData
		_check(c7_promo != null and c7_promo.granted_skill_ids == [c7_entry[1], c7_entry[2]]
			and c7_promo.enhanced_skill_ids.is_empty(),
			"%s 应显式继承核心技能+新技能且强化标记留空（提交 7）" % c7_entry[0])
		_check(c7_promo != null and c7_promo.skill_params.has(c7_entry[1]) and c7_promo.skill_params.has(c7_entry[2]),
			"%s 双技能参数应为嵌套字典（核心+新技能各一份）" % c7_entry[0])
	var c7_enhanced := [
		["res://resources/promotions/cavalry_heavy_armor.tres", &"charge"],
		["res://resources/promotions/tiger_guard_vanguard.tres", &"command"],
		["res://resources/promotions/archer_piercing_cloud.tres", &"steady"],
		["res://resources/promotions/strategist_sage.tres", &"wisdom"],
		["res://resources/promotions/dancer_phoenix.tres", &"inspire"],
		["res://resources/promotions/catapult_city_breaker.tres", &"siege"],
	]
	for c7_entry in c7_enhanced:
		var c7_promo := load(c7_entry[0]) as PromotionData
		_check(c7_promo != null and c7_promo.granted_skill_ids == [c7_entry[1]]
			and c7_promo.enhanced_skill_ids == [c7_entry[1]],
			"%s 强化线应配核心技能 id（granted 与 enhanced 同源）" % c7_entry[0])
	# 突袭（骁骑）：击杀 +1 层 / 对精英每 4 次命中 +1 层（上限 3），普攻消耗 1 层该次 +25%×s。
	GameManager.gold = 9999
	var c7_raider_promo := load("res://resources/promotions/cavalry_swift_raider.tres") as PromotionData
	var c7_raider_tower: Tower = tower_manager.build_tower(Vector2(60, 100), guan_yu, null, {"level": 20, "promotion": c7_raider_promo})
	_check(c7_raider_tower != null and c7_raider_tower.has_skill(&"charge") and c7_raider_tower.has_skill(&"assault"),
		"骁骑应同时持有蓄力与突袭（双技能继承）")
	if c7_raider_tower:
		c7_raider_tower.set_process(false)
		_check(c7_raider_tower.get_skill_display_name(&"charge") == "蓄力", "骁骑保留的蓄力不应带 +")
		_check(c7_raider_tower.get_skill_display_name(&"assault") == "突袭", "新技能突袭不应带 +")
		var c7_elite := enemy_manager.spawn_enemy_from_data(sergeant_data) as Enemy
		c7_elite.set_process(false)
		for _i in range(4):
			SkillRegistry.on_attack_hit(c7_raider_tower, c7_elite, 10)
		_check(c7_raider_tower.assault_stacks == 1, "突袭对精英每 4 次命中应叠 1 层")
		for _i in range(4):
			SkillRegistry.on_attack_hit(c7_raider_tower, c7_elite, 10)
		_check(c7_raider_tower.assault_stacks == 2, "突袭精英命中叠层应累计")
		SkillRegistry.on_kill(c7_raider_tower, null)
		_check(c7_raider_tower.assault_stacks == 3, "突袭击杀应 +1 层")
		SkillRegistry.on_kill(c7_raider_tower, null)
		_check(c7_raider_tower.assault_stacks == 3, "突袭叠层应封顶 3 层")
		var c7_assault_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c7_assault_tank.set_process(false)
		SkillRegistry.try_consume_assault(c7_raider_tower)
		_check(c7_raider_tower.assault_stacks == 2 and is_equal_approx(float(c7_raider_tower.get("_next_attack_bonus")), 0.25),
			"普攻应消耗 1 层突袭并挂载 +25%")
		_check(c7_raider_tower.finalize_damage(100, c7_assault_tank) == 125, "突袭层消耗该次伤害应 +25%")
		_check(is_equal_approx(float(c7_raider_tower.get("_next_attack_bonus")), 0.0), "突袭加成应一次性消耗")
		c7_raider_tower.battle_rank = 5
		c7_raider_tower.assault_stacks = 1
		SkillRegistry.try_consume_assault(c7_raider_tower)
		_check(is_equal_approx(float(c7_raider_tower.get("_next_attack_bonus")), 0.275),
			"突袭加成应随档位放大（5 阶 = 0.25×1.1）")
		c7_raider_tower.queue_free()
		if is_instance_valid(c7_elite):
			c7_elite.queue_free()
		if is_instance_valid(c7_assault_tank):
			c7_assault_tank.queue_free()
	# 连矢（连弩）：概率追加——roll 中但目标已死则顺延至下一次存活命中，不吞触发。
	var c7_chain_promo := load("res://resources/promotions/archer_crossbow.tres") as PromotionData
	var c7_chain_tower: Tower = tower_manager.build_tower(Vector2(140, 100), huang_zhong, null, {"level": 20, "promotion": c7_chain_promo})
	_check(c7_chain_tower != null and c7_chain_tower.has_skill(&"steady") and c7_chain_tower.has_skill(&"chain_arrow"),
		"连弩应同时持有稳射与连矢")
	if c7_chain_tower:
		c7_chain_tower.set_process(false)
		_check(c7_chain_tower.get_skill_display_name(&"steady") == "稳射", "连弩保留的稳射不应带 +")
		_check(c7_chain_tower.get_skill_display_name(&"chain_arrow") == "连矢", "新技能连矢不应带 +")
		var c7_chain_dead := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c7_chain_dead.set_process(false)
		c7_chain_dead.die(false)
		c7_chain_tower.chain_arrow_pending = true
		SkillRegistry.on_attack_hit(c7_chain_tower, c7_chain_dead, 10)
		_check(c7_chain_tower.chain_arrow_pending, "连矢命中已死目标应顺延、不吞触发")
		var c7_chain_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c7_chain_tank.set_process(false)
		var c7_chain_before := c7_chain_tank.current_hp
		SkillRegistry.on_attack_hit(c7_chain_tower, c7_chain_tank, 10)
		var c7_chain_extra := int(round(c7_chain_tower.damage * 0.5))
		_check(not c7_chain_tower.chain_arrow_pending, "连矢顺延触发后应复位")
		_check(c7_chain_before - c7_chain_tank.current_hp == c7_chain_extra, "连矢应追加 0.5× 普攻伤害")
		c7_chain_tower.queue_free()
		if is_instance_valid(c7_chain_dead):
			c7_chain_dead.queue_free()
		if is_instance_valid(c7_chain_tank):
			c7_chain_tank.queue_free()
	# 奇门（天师）：大招落点易伤 +10%×s/4s——同类不叠加、时长刷新，所有来源伤害受益。
	var c7_mystic_promo := load("res://resources/promotions/strategist_heavenly_master.tres") as PromotionData
	var c7_mystic_tower: Tower = tower_manager.build_tower(Vector2(220, 100), zhuge_liang, null, {"level": 20, "promotion": c7_mystic_promo})
	_check(c7_mystic_tower != null and c7_mystic_tower.has_skill(&"wisdom") and c7_mystic_tower.has_skill(&"mystic_gate"),
		"天师应同时持有奇谋与奇门")
	if c7_mystic_tower:
		c7_mystic_tower.set_process(false)
		_check(c7_mystic_tower.get_skill_display_name(&"wisdom") == "奇谋", "天师保留的奇谋不应带 +")
		_check(c7_mystic_tower.get_skill_display_name(&"mystic_gate") == "奇门", "新技能奇门不应带 +")
		var c7_vuln_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c7_vuln_tank.set_process(false)
		SkillRegistry.apply_mystic_gate(c7_mystic_tower, c7_vuln_tank)
		_check(is_equal_approx(c7_vuln_tank.get_vulnerability_multiplier(), 1.1), "奇门应施加 +10% 易伤")
		var c7_vuln_before := c7_vuln_tank.current_hp
		c7_vuln_tank.take_damage(100)
		_check(c7_vuln_before - c7_vuln_tank.current_hp == 110, "易伤应使所有来源伤害 +10%")
		SkillRegistry.apply_mystic_gate(c7_mystic_tower, c7_vuln_tank)
		_check(is_equal_approx(c7_vuln_tank.get_vulnerability_multiplier(), 1.1), "同类易伤应不叠加")
		c7_vuln_tank.set("_vulnerability_time_left", 1.0)
		SkillRegistry.apply_mystic_gate(c7_mystic_tower, c7_vuln_tank)
		_check(is_equal_approx(float(c7_vuln_tank.get("_vulnerability_time_left")), 4.0), "同类易伤应刷新时长")
		c7_mystic_tower.battle_rank = 5
		SkillRegistry.apply_mystic_gate(c7_mystic_tower, c7_vuln_tank)
		_check(is_equal_approx(c7_vuln_tank.get_vulnerability_multiplier(), 1.11), "奇门易伤应随档位放大（5 阶 1.11）")
		c7_mystic_tower.queue_free()
		if is_instance_valid(c7_vuln_tank):
			c7_vuln_tank.queue_free()
	# 护卫（虎卫）：近战命中概率沿路径拖回 20px（内置冷却 2.5s 防钉死）。
	var c7_guard_promo := load("res://resources/promotions/tiger_guard_guard.tres") as PromotionData
	var c7_guard_tower: Tower = tower_manager.build_tower(Vector2(340, 100), zhang_fei, null, {"level": 20, "promotion": c7_guard_promo})
	_check(c7_guard_tower != null and c7_guard_tower.has_skill(&"command") and c7_guard_tower.has_skill(&"guard"),
		"虎卫应同时持有军旗与护卫")
	if c7_guard_tower:
		c7_guard_tower.set_process(false)
		c7_guard_tower.battle_rank = 20
		_check(c7_guard_tower.get_skill_display_name(&"command") == "军旗", "虎卫保留的军旗不应带 +")
		_check(c7_guard_tower.get_skill_display_name(&"guard") == "护卫", "新技能护卫不应带 +")
		var c7_guard_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c7_guard_target.set_process(false)
		c7_guard_target.progress = 300.0
		for _i in range(100):
			SkillRegistry.on_attack_hit(c7_guard_tower, c7_guard_target, 10)
			if c7_guard_target.progress < 300.0:
				break
		_check(is_equal_approx(c7_guard_target.progress, 280.0) and c7_guard_tower.guard_cooldown_left > 0.0,
			"护卫应命中拖回 20px 并进入内置冷却")
		for _i in range(20):
			SkillRegistry.on_attack_hit(c7_guard_tower, c7_guard_target, 10)
		_check(is_equal_approx(c7_guard_target.progress, 280.0), "护卫冷却期内不应反复拖回")
		c7_guard_tower.queue_free()
		if is_instance_valid(c7_guard_target):
			c7_guard_target.queue_free()
	# 余音（绕梁）：大招后全队伤害 +8%×s/5s（鼓舞线核心技能保留，走同一次大招钩子）。
	var c7_diao_chan := load("res://resources/characters/diao_chan.tres") as CharacterData
	var c7_echo_promo := load("res://resources/promotions/dancer_echo.tres") as PromotionData
	var c7_echo_tower: Tower = tower_manager.build_tower(Vector2(420, 100), c7_diao_chan, null, {"level": 20, "promotion": c7_echo_promo})
	var c7_echo_ally: Tower = tower_manager.build_tower(Vector2(480, 100), guan_yu, null, {"level": 1})
	_check(c7_echo_tower != null and c7_echo_tower.has_skill(&"inspire") and c7_echo_tower.has_skill(&"echo")
		and c7_echo_ally != null, "绕梁应同时持有鼓舞与余音")
	if c7_echo_tower and c7_echo_ally:
		c7_echo_tower.set_process(false)
		c7_echo_ally.set_process(false)
		_check(c7_echo_tower.get_skill_display_name(&"inspire") == "鼓舞", "绕梁保留的鼓舞不应带 +")
		_check(c7_echo_tower.get_skill_display_name(&"echo") == "余音", "新技能余音不应带 +")
		SkillRegistry.on_ultimate_cast(c7_echo_tower)
		_check(is_equal_approx(c7_echo_ally.damage_buff, 1.08), "余音应使全队伤害 +8%")
	if c7_echo_tower:
		c7_echo_tower.queue_free()
	if c7_echo_ally:
		c7_echo_ally.queue_free()
	# 震地（震山）：大招每发落点眩晕 0.5s×s（同目标内置冷却 2.5s 防 3 连发叠晕）。
	var c7_tremor_promo := load("res://resources/promotions/catapult_earthquake.tres") as PromotionData
	var c7_tremor_tower: Tower = tower_manager.build_tower(Vector2(540, 100), huang_fu_song, null, {"level": 20, "promotion": c7_tremor_promo})
	_check(c7_tremor_tower != null and c7_tremor_tower.has_skill(&"siege") and c7_tremor_tower.has_skill(&"tremor"),
		"震山应同时持有破城与震地")
	if c7_tremor_tower:
		c7_tremor_tower.set_process(false)
		_check(c7_tremor_tower.get_skill_display_name(&"siege") == "破城", "震山保留的破城不应带 +")
		_check(c7_tremor_tower.get_skill_display_name(&"tremor") == "震地", "新技能震地不应带 +")
		var c7_stun_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		c7_stun_enemy.set_process(false)
		c7_stun_enemy.progress = 300.0
		SkillRegistry.try_apply_tremor_stun(c7_tremor_tower, c7_stun_enemy)
		_check(is_equal_approx(float(c7_stun_enemy.get("_stun_time_left")), 0.5), "震地应眩晕 0.5s")
		c7_stun_enemy._process(0.1)
		_check(is_equal_approx(c7_stun_enemy.progress, 300.0), "眩晕期间敌人应停止移动")
		c7_stun_enemy.set("_stun_time_left", 0.05)
		SkillRegistry.try_apply_tremor_stun(c7_tremor_tower, c7_stun_enemy)
		_check(is_equal_approx(float(c7_stun_enemy.get("_stun_time_left")), 0.05), "同目标冷却 2.5s 内不应叠晕")
		c7_tremor_tower.tremor_stun_cooldowns.erase(c7_stun_enemy.get_instance_id())
		c7_tremor_tower.battle_rank = 5
		SkillRegistry.try_apply_tremor_stun(c7_tremor_tower, c7_stun_enemy)
		_check(is_equal_approx(float(c7_stun_enemy.get("_stun_time_left")), 0.55), "震地眩晕应随档位放大（5 阶 0.55s）")
		c7_stun_enemy._process(0.6)
		_check(is_equal_approx(float(c7_stun_enemy.get("_stun_time_left")), 0.0), "眩晕应到时解除")
		var c7_stun_progress_before := c7_stun_enemy.progress
		c7_stun_enemy._process(0.1)
		_check(c7_stun_enemy.progress > c7_stun_progress_before, "眩晕解除后敌人应恢复移动")
		c7_tremor_tower.queue_free()
		if is_instance_valid(c7_stun_enemy):
			c7_stun_enemy.queue_free()
	# 等一帧释放本组测试塔，避免护卫光环/余音增益污染后续光环桶与角色技能断言。
	await get_tree().process_frame
	# 常驻光环伤害桶（提交 7 验收）：军旗+（0.06×s）多源加法求和 + clamp(+50%)，最终只乘一次。
	var c7_aura_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
	c7_aura_tank.set_process(false)
	var c7_aura_probe: Tower = tower_manager.build_tower(Vector2(620, 100), guan_yu, null, {"level": 1})
	_check(c7_aura_probe != null, "应能建造光环桶探针塔")
	if c7_aura_probe:
		c7_aura_probe.set_process(false)
		var c7_aura_sources: Array[Tower] = []
		var c7_aura_offsets := [-160.0, -80.0, 40.0, 120.0, 160.0, -120.0]
		for c7_i in range(5):
			var c7_source: Tower = tower_manager.build_tower(
				Vector2(620.0 + c7_aura_offsets[c7_i], 100.0), zhang_fei, null,
				{"level": 20, "promotion": load("res://resources/promotions/tiger_guard_vanguard.tres")})
			if c7_source != null:
				c7_source.set_process(false)
				c7_source.battle_rank = 20
				c7_aura_sources.append(c7_source)
		c7_aura_probe.refresh_aura_damage_bonus()
		_check(is_equal_approx(float(c7_aura_probe.get("_aura_damage_bonus")), 0.42),
			"军旗+ 5 座应加法求和 +42%（0.06×1.4×5，多源互乘路径应消除）")
		_check(c7_aura_probe.finalize_damage(100, c7_aura_tank) == 142, "光环桶应只乘一次 (1+0.42)")
		var c7_sixth: Tower = tower_manager.build_tower(
			Vector2(620.0 + c7_aura_offsets[5], 100.0), zhang_fei, null,
			{"level": 20, "promotion": load("res://resources/promotions/tiger_guard_vanguard.tres")})
		if c7_sixth != null:
			c7_sixth.set_process(false)
			c7_sixth.battle_rank = 20
			c7_aura_sources.append(c7_sixth)
		c7_aura_probe.refresh_aura_damage_bonus()
		_check(is_equal_approx(float(c7_aura_probe.get("_aura_damage_bonus")), 0.5),
			"光环桶应封顶 +50%（0.504 → clamp 0.5）")
		_check(c7_aura_probe.finalize_damage(100, c7_aura_tank) == 150, "光环桶上限 1.5 应生效")
		for c7_source in c7_aura_sources:
			c7_source.queue_free()
		c7_aura_probe.queue_free()
	if is_instance_valid(c7_aura_tank):
		c7_aura_tank.queue_free()
	await get_tree().process_frame
	# 虎贲职业重构（v0.28.0）：profession_id/大招 ID/克制/升阶步进配置同步。
	var tiger_guard_prof := load("res://resources/professions/tiger_guard.tres") as ProfessionData
	_check(tiger_guard_prof != null and str(tiger_guard_prof.profession_id) == "tiger_guard"
		and tiger_guard_prof.display_name == "虎贲", "虎贲职业资源应更名完成")
	_check(tiger_guard_prof != null and str(tiger_guard_prof.ultimate_id) == "ultimate_tiger_guard_sweep",
		"虎贲大招 ID 应为 ultimate_tiger_guard_sweep")
	_check(tiger_guard_prof != null and is_equal_approx(tiger_guard_prof.battle_rank_damage_step, 0.15)
		and tiger_guard_prof.battle_rank_buff_duration_step > 0.0
		and tiger_guard_prof.battle_rank_buff_power_step > 0.0, "虎贲升阶应降低伤害步进并新增 buff 步进")
	# 破阵（虎贲大招）：1.5× 范围伤害 + 击退 40px + 附近 200px 友方攻速 +15%/5s。
	var sweep_tower: Tower = tower_manager.build_tower(Vector2(300, 100), zhang_fei, null, {"level": 1})
	var sweep_ally: Tower = tower_manager.build_tower(Vector2(420, 100), guan_yu, null, {"level": 1})
	var sweep_far: Tower = tower_manager.build_tower(Vector2(760, 100), huang_zhong, null, {"level": 1})
	_check(sweep_tower != null and sweep_ally != null and sweep_far != null, "破阵用例应能建造三座塔")
	if sweep_tower and sweep_ally and sweep_far:
		sweep_tower.set_process(false)
		sweep_ally.set_process(false)
		sweep_far.set_process(false)
		var sweep_enemy := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		sweep_enemy.set_process(false)
		sweep_enemy.progress = 300.0
		sweep_enemy.global_position = sweep_tower.global_position + Vector2(80, 0)
		sweep_tower.target = sweep_enemy
		_check(BehaviorRegistry.execute_ultimate(&"ultimate_tiger_guard_sweep", sweep_tower), "破阵应能释放")
		_check(is_equal_approx(sweep_enemy.progress, 260.0), "破阵应击退敌人 40px")
		_check(is_equal_approx(sweep_ally.attack_speed_buff, 1.15), "破阵激励段应使 200px 内友方攻速 +15%")
		_check(is_equal_approx(sweep_far.attack_speed_buff, 1.0), "破阵激励段对 200px 外友方应无效")
		sweep_enemy.die(false)
		sweep_tower.queue_free()
		sweep_ally.queue_free()
		sweep_far.queue_free()
	await get_tree().process_frame
	# ===== 阶段 8 提交 8（v0.33.0 / 0.8.8.0）：转职数值提升——18 节点对照 4.1 三张表 + 非链式 + 效果型大招倍率 =====
	# 4.1 表口径：[伤害, 射程, 攻速, 大招]；一转 ult=1.0。
	var c8_table := {
		&"cavalry_iron_rider": [1.2, 1.0, 0.9, 1.0],
		&"tiger_guard_army": [1.2, 1.0, 0.95, 1.0],
		&"archer_strong_bow": [1.15, 1.1, 0.95, 1.0],
		&"strategist_mage": [1.15, 1.1, 0.95, 1.0],
		&"dancer_master": [1.1, 1.0, 0.85, 1.0],
		&"catapult_thunder": [1.2, 1.1, 0.9, 1.0],
		&"cavalry_heavy_armor": [1.35, 1.0, 0.85, 1.3],
		&"tiger_guard_vanguard": [1.35, 1.0, 0.9, 1.25],
		&"archer_piercing_cloud": [1.3, 1.15, 0.9, 1.25],
		&"strategist_sage": [1.3, 1.1, 0.9, 1.25],
		&"dancer_phoenix": [1.25, 1.0, 0.8, 1.2],
		&"catapult_city_breaker": [1.35, 1.1, 0.9, 1.3],
		&"cavalry_swift_raider": [1.3, 1.0, 0.9, 1.15],
		&"tiger_guard_guard": [1.25, 1.0, 0.9, 1.15],
		&"archer_crossbow": [1.25, 1.1, 0.9, 1.15],
		&"strategist_heavenly_master": [1.25, 1.1, 0.9, 1.15],
		&"dancer_echo": [1.2, 1.0, 0.85, 1.15],
		&"catapult_earthquake": [1.3, 1.1, 0.9, 1.15],
	}
	for c8_id in c8_table.keys():
		var c8_promo := load("res://resources/promotions/%s.tres" % c8_id) as PromotionData
		var c8_row: Array = c8_table[c8_id]
		_check(c8_promo != null
			and is_equal_approx(c8_promo.damage_multiplier, c8_row[0])
			and is_equal_approx(c8_promo.range_multiplier, c8_row[1])
			and is_equal_approx(c8_promo.attack_interval_multiplier, c8_row[2])
			and is_equal_approx(c8_promo.ultimate_multiplier, c8_row[3]),
			"%s 三围/大招倍率应与 SKILLS.md 4.1 表一致（提交 8）" % c8_id)
	# 非链式相乘：铁骑→玄甲路径末位直接以未转职为基准（攻速 0.85，而非 0.9×0.85）。
	var c8_guan_yu := load("res://resources/characters/guan_yu.tres") as CharacterData
	if c8_guan_yu != null:
		var c8_xuanjia := load("res://resources/promotions/cavalry_heavy_armor.tres") as PromotionData
		var c8_stats := c8_guan_yu.compute_stats_at(20, c8_xuanjia)
		_check(is_equal_approx(float(c8_stats["attack_interval"]), c8_guan_yu.attack_interval * 0.85),
			"二转攻速应只应用末位倍率（×0.85，不与一转 0.9 链式相乘）")
	# 效果型大招乘转职大招倍率（NUMBERS 10.5）：凤仪鼓舞 = 1+0.3×1.2 = 1.36。
	var c8_diao_chan := load("res://resources/characters/diao_chan.tres") as CharacterData
	var c8_fengyi := load("res://resources/promotions/dancer_phoenix.tres") as PromotionData
	var c8_dancer: Tower = tower_manager.build_tower(Vector2(60, 300), c8_diao_chan, null, {"level": 20, "promotion": c8_fengyi})
	var c8_dance_ally: Tower = tower_manager.build_tower(Vector2(140, 300), guan_yu, null, {"level": 1})
	_check(c8_dancer != null and c8_dance_ally != null, "鼓舞倍率用例应能建造两座塔")
	if c8_dancer and c8_dance_ally:
		c8_dancer.set_process(false)
		c8_dance_ally.set_process(false)
		_check(BehaviorRegistry.execute_ultimate(&"ultimate_dancer_encourage", c8_dancer), "凤仪鼓舞应能释放")
		_check(is_equal_approx(c8_dance_ally.attack_speed_buff, 1.36),
			"凤仪鼓舞攻速应乘转职大招倍率（1+0.3×1.2=1.36）")
		c8_dancer.queue_free()
		c8_dance_ally.queue_free()
	# 陷阵激励段 = 1+0.15×1.25 = 1.1875（提交 8 起 effect 型大招接入 ultimate_multiplier）。
	var c8_xianzhen := load("res://resources/promotions/tiger_guard_vanguard.tres") as PromotionData
	var c8_tiger: Tower = tower_manager.build_tower(Vector2(300, 300), zhang_fei, null, {"level": 20, "promotion": c8_xianzhen})
	var c8_tiger_ally: Tower = tower_manager.build_tower(Vector2(380, 300), guan_yu, null, {"level": 1})
	_check(c8_tiger != null and c8_tiger_ally != null, "陷阵激励段用例应能建造两座塔")
	if c8_tiger and c8_tiger_ally:
		c8_tiger.set_process(false)
		c8_tiger_ally.set_process(false)
		var c8_sweep_enemy := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c8_sweep_enemy.set_process(false)
		c8_sweep_enemy.progress = 300.0
		c8_sweep_enemy.global_position = c8_tiger.global_position + Vector2(80, 0)
		c8_tiger.target = c8_sweep_enemy
		_check(BehaviorRegistry.execute_ultimate(&"ultimate_tiger_guard_sweep", c8_tiger), "陷阵破阵应能释放")
		_check(is_equal_approx(c8_tiger_ally.attack_speed_buff, 1.1875),
			"陷阵激励段应乘转职大招倍率（1+0.15×1.25=1.1875）")
		c8_sweep_enemy.die(false)
		c8_tiger.queue_free()
		c8_tiger_ally.queue_free()
	await get_tree().process_frame
	# 角色技能（v0.28.0）：9 名武将全部配置 character_skill_id。
	var char_skill_ids := {
		"guan_yu": &"char_green_dragon", "zhang_fei": &"char_dangyang_roar",
		"liu_bei": &"char_carry_people", "huang_zhong": &"char_dingjun",
		"diao_chan": &"char_moon_dance", "huang_fu_song": &"char_burn_camp",
		"zhao_yun": &"char_seven_charges", "zhou_wei": &"char_death_fight",
		"zhuge_liang": &"char_borrow_wind",
	}
	for raw_id in char_skill_ids.keys():
		var char_data := GameFlow.load_character_data(raw_id) as CharacterData
		_check(char_data != null and char_data.character_skill_id == char_skill_ids[raw_id],
			"%s 应配置角色技能 %s" % [raw_id, char_skill_ids[raw_id]])
	# 关羽·青龙偃月（A/CD18）：2.5× 单体；击杀冷却 -6s。
	var green_tower: Tower = tower_manager.build_tower(Vector2(320, 640), guan_yu, null, {"level": 10})
	_check(green_tower != null and SkillRegistry.has_character_skill(green_tower), "关羽塔应持有角色技能")
	if green_tower:
		green_tower.set_process(false)
		var green_kill := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		green_kill.set_process(false)
		green_kill.global_position = green_tower.global_position + Vector2(60, 0)
		green_kill.current_hp = green_kill.max_hp
		green_tower.target = green_kill
		_check(green_tower.cast_character_skill(), "青龙偃月应能释放")
		_check(is_equal_approx(green_tower.get_character_skill_cooldown_left(), 12.0),
			"青龙偃月击杀应返 6s 冷却（18-6=12）")
		var green_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		green_tank.set_process(false)
		green_tank.global_position = green_tower.global_position + Vector2(60, 0)
		green_tower.target = green_tank
		green_tower.refund_character_skill_cooldown(999.0)
		var green_before := green_tank.current_hp
		_check(green_tower.cast_character_skill(), "青龙偃月应能再次释放")
		_check(green_before - green_tank.current_hp == int(round(green_tower.damage * 2.5)),
			"青龙偃月应造成 2.5× 普攻伤害")
		green_tank.queue_free()
		green_tower.queue_free()
	# 张飞·当阳桥（A/CD22）：击退 60px + 减速 60% 3s。
	var roar_tower: Tower = tower_manager.build_tower(Vector2(360, 640), zhang_fei, null, {"level": 10})
	if roar_tower:
		roar_tower.set_process(false)
		var roar_enemy := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		roar_enemy.set_process(false)
		roar_enemy.progress = 300.0
		roar_enemy.global_position = roar_tower.global_position + Vector2(60, 0)
		roar_tower.target = roar_enemy
		_check(roar_tower.cast_character_skill(), "当阳桥应能释放")
		_check(is_equal_approx(roar_enemy.progress, 240.0), "当阳桥应击退敌人 60px")
		_check(is_equal_approx(roar_enemy.slow_factor, 0.4), "当阳桥应减速 60%")
		roar_enemy.die(false)
		roar_tower.queue_free()
	# 刘备·携民渡江（B·每波首次漏怪）：全队攻速 +15% 5s。
	var carry_tower: Tower = tower_manager.build_tower(Vector2(400, 640), liu_bei, null, {"level": 10})
	_check(carry_tower != null, "刘备塔应能建造")
	if carry_tower:
		carry_tower.set_process(false)
		GameManager.reset(9999, 20, 5)
		_check(GameManager.start_wave(), "漏怪用例应能开波")
		GameManager.enemy_reached_base(1)
		_check(is_equal_approx(carry_tower.attack_speed_buff, 1.15), "携民渡江应使全队攻速 +15%")
		GameManager.enemy_reached_base(1)
		_check(is_equal_approx(carry_tower.attack_speed_buff, 1.15), "同波第二次漏怪不应重复触发（每波一次）")
		carry_tower.queue_free()
		# 等一帧释放刘备塔，避免其 B 被动在后续漏怪事件中二次触发全队攻速。
		await get_tree().process_frame
	# 黄忠·定军山（A/CD18）：2.5× 单体；未击杀则标记易伤 +15%。
	var dingjun_tower: Tower = tower_manager.build_tower(Vector2(440, 640), huang_zhong, null, {"level": 10})
	if dingjun_tower:
		dingjun_tower.set_process(false)
		var dingjun_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		dingjun_target.set_process(false)
		dingjun_target.global_position = dingjun_tower.global_position + Vector2(120, 0)
		dingjun_tower.target = dingjun_target
		_check(dingjun_tower.cast_character_skill(), "定军山应能释放")
		_check(dingjun_target.has_mark("huang_zhong"), "定军山未击杀应施加定军标记")
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(dingjun_tower, dingjun_target), 1.15),
			"定军标记应使该塔普攻伤害 +15%")
		dingjun_target.die(false)
		dingjun_tower.queue_free()
	# 貂蝉·月下舞（A/CD25）：全队怒气 +10（自身 +15，月幕自增 1.2 → 18）。
	var dance_char_data := load("res://resources/characters/diao_chan.tres") as CharacterData
	var dance_tower: Tower = tower_manager.build_tower(Vector2(480, 640), dance_char_data, null, {"level": 10})
	var dance_ally: Tower = tower_manager.build_tower(Vector2(520, 640), guan_yu, null, {"level": 1})
	if dance_tower and dance_ally:
		dance_tower.set_process(false)
		dance_ally.set_process(false)
		_check(dance_tower.cast_character_skill(), "月下舞应能释放")
		_check(is_equal_approx(dance_tower.rage, 18.0), "月下舞自身应 +15 怒气（月幕 ×1.2）")
		_check(is_equal_approx(dance_ally.rage, 11.0), "月下舞友方应 +10 怒气（月幕 ×1.1）")
		dance_tower.queue_free()
		dance_ally.queue_free()
	# 皇甫嵩·焚营（A/CD20）：目标区域范围伤害 + 灼烧。
	var burn_tower: Tower = tower_manager.build_tower(Vector2(560, 640), huang_fu_song, null, {"level": 10})
	if burn_tower:
		burn_tower.set_process(false)
		var burn_char_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		burn_char_target.set_process(false)
		burn_char_target.global_position = burn_tower.global_position + Vector2(300, 0)
		burn_tower.target = burn_char_target
		_check(burn_tower.cast_character_skill(), "焚营应能释放")
		_check(burn_char_target.burn_dps > 0, "焚营应施加灼烧")
		burn_char_target.die(false)
		burn_tower.queue_free()
	# 赵云·七进七出（B·每波首次漏怪）：射程内范围伤害 + 自身攻速 +30% 3s。
	var seven_tower: Tower = tower_manager.build_tower(Vector2(600, 640), zhao_yun, null, {"level": 10})
	if seven_tower:
		seven_tower.set_process(false)
		var seven_enemy := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		seven_enemy.set_process(false)
		seven_enemy.global_position = seven_tower.global_position + Vector2(60, 0)
		GameManager.reset(9999, 20, 5)
		GameManager.start_wave()
		var seven_before := seven_enemy.current_hp
		GameManager.enemy_reached_base(1)
		_check(seven_enemy.current_hp < seven_before, "七进七出应对射程内敌人造成范围伤害")
		_check(is_equal_approx(seven_tower.attack_speed_buff, 1.3), "七进七出应使自身攻速 +30%")
		seven_enemy.die(false)
		seven_tower.queue_free()
	# 周仓·死战（B·基地 ≤50%）：攻速 +30% 常驻。
	var death_char_data := load("res://resources/characters/zhou_wei.tres") as CharacterData
	var death_tower: Tower = tower_manager.build_tower(Vector2(640, 640), death_char_data, null, {"level": 10})
	if death_tower:
		death_tower.set_process(false)
		GameManager.reset(9999, 20, 5)
		GameManager.start_wave()
		death_tower._process(0.016)
		_check(is_equal_approx(float(death_tower.get("_char_skill_speed_bonus")), 0.0), "基地满血不应触发死战")
		GameManager.enemy_reached_base(10)
		death_tower._process(0.016)
		_check(is_equal_approx(float(death_tower.get("_char_skill_speed_bonus")), 0.3), "基地 ≤50% 应触发死战攻速 +30%")
		death_tower._process(0.016)
		_check(is_equal_approx(float(death_tower.get("_char_skill_speed_bonus")), 0.3), "死战应仅触发一次")
		death_tower.queue_free()
	# 诸葛亮·借东风（A/CD30）：全图友方攻速 +20%、弹道速度 +50% 8s。
	var wind_tower: Tower = tower_manager.build_tower(Vector2(680, 640), zhuge_liang, null, {"level": 10})
	var wind_ally: Tower = tower_manager.build_tower(Vector2(720, 640), guan_yu, null, {"level": 1})
	if wind_tower and wind_ally:
		wind_tower.set_process(false)
		wind_ally.set_process(false)
		_check(wind_tower.cast_character_skill(), "借东风应能释放")
		_check(is_equal_approx(wind_ally.attack_speed_buff, 1.2), "借东风应使友方攻速 +20%")
		_check(is_equal_approx(wind_ally.get_bullet_speed_multiplier(), 1.5), "借东风应使弹道速度 +50%")
		_check(is_equal_approx(wind_tower.get_character_skill_cooldown_left(), 30.0), "借东风冷却应为 30s")
		wind_tower.queue_free()
		wind_ally.queue_free()
	# 职业技能档位口径（v0.27.4）：仅职业技能按局内升阶 battle_rank，角色技能不参与。
	var tier_check_tower: Tower = tower_manager.build_tower(Vector2(760, 640), guan_yu, null, {"level": 1})
	if tier_check_tower:
		tier_check_tower.set_process(false)
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_check_tower), 1.0), "0 阶档位系数应为 1")
		tier_check_tower.battle_rank = 5
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_check_tower), 1.1), "5 阶档位系数应为 1.1")
		tier_check_tower.battle_rank = 20
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_check_tower), 1.4), "20 阶档位系数应封顶 1.4")
		tier_check_tower.queue_free()	# 舞娘光环（v0.11.2）：脉冲增益友方攻速、辅助积怒与贡献经验。
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
			_check(int(pending.get("diao_chan", 0)) == 8, "辅助贡献经验应为 4 + 覆盖 2×2 = 8（10.6）")
		if dancer_tower:
			dancer_tower.queue_free()
		if ally_tower:
			ally_tower.queue_free()

	# 阶段 8 提交 2（P0 3.2/3.4）：攻速 buff 按来源加法叠加、总上限 +100%、间隔下限 0.55。
	var speed_tower: Tower = tower_manager.build_tower(Vector2(320, 100), guan_yu, null, {"level": 1})
	if speed_tower != null:
		speed_tower.apply_attack_speed_buff("test_a", 1.5, 5.0)
		speed_tower.apply_attack_speed_buff("test_b", 1.5, 5.0)
		_check(is_equal_approx(speed_tower.attack_speed_buff, 2.0), "多来源攻速 buff 应加法叠加并封顶 +100%")
		speed_tower.apply_attack_speed_buff("test_c", 3.0, 5.0)
		_check(is_equal_approx(speed_tower.attack_speed_buff, 2.0), "攻速 buff 总上限应为 2.0（+100%）")
		speed_tower.attack_cooldown = 1.0
		speed_tower.kill_stacks = 0
		speed_tower.attack_speed_buff = 2.0
		speed_tower._rebuild_attack_timer()
		_check(is_equal_approx(speed_tower.attack_timer.wait_time, 0.55), "攻速间隔下限应为基础间隔×0.55")
		speed_tower.queue_free()

	# 阶段 8 提交 2（P0 3.3）：结算转盘——奖池 5~7 件、≥150 金抽 1 次、结果入档（隔离存档）。
	_check(SettlementWheel.MIN_REMAINING_GOLD == 150, "转盘门槛应为剩余金币 ≥150（仅一次）")
	_check(SettlementWheel.POOL.size() >= 5 and SettlementWheel.POOL.size() <= 7, "转盘奖池应为 5~7 件道具")
	var wheel_profile := ProfileStore.get_profile()
	var wheel_roll := SettlementWheel.roll(wheel_profile)
	_check(not wheel_roll.is_empty(), "转盘应能抽取奖励")
	var wheel_kind := str(wheel_roll.get("kind", ""))
	_check(["item", "shards", "tech_points"].has(wheel_kind), "转盘奖励类型应合法")
	var wheel_amount_before := 0
	if wheel_kind == "shards":
		var wheel_char := str(wheel_roll.get("character_id", ""))
		_check(not wheel_char.is_empty(), "碎片奖励应指定武将")
		wheel_amount_before = int(wheel_profile.get_character(wheel_char).get("shards", 0))
	elif wheel_kind == "item":
		wheel_amount_before = int(wheel_profile.items.get(str(wheel_roll.get("item_id", "")), 0))
	else:
		wheel_amount_before = wheel_profile.tech_points
	_check(ProfileStore.commit_settlement_reward(wheel_roll), "转盘结果应能入账（隔离存档）")
	if wheel_kind == "shards":
		var wheel_char2 := str(wheel_roll.get("character_id", ""))
		_check(int(wheel_profile.get_character(wheel_char2).get("shards", 0))
			== wheel_amount_before + int(wheel_roll.get("amount", 0)), "碎片入账数量应正确")
	elif wheel_kind == "item":
		_check(int(wheel_profile.items.get(str(wheel_roll.get("item_id", "")), 0))
			== wheel_amount_before + int(wheel_roll.get("amount", 0)), "道具入账数量应正确")
	else:
		_check(wheel_profile.tech_points == wheel_amount_before + int(wheel_roll.get("amount", 0)), "科技点入账数量应正确")

	# 阶段 8 提交 3：地图校验器——第一章 8 关布局全部通过（道路/禁建不重叠、通路完整、覆盖区与职业位达标）。
	var map_issues: Array[String] = []
	for stage_path in _collect_resource_paths("res://resources/stages"):
		var map_stage := load(stage_path) as StageData
		if map_stage != null and not MapValidator.validate_stage(map_stage, map_issues):
			_check(false, "地图校验失败: %s: %s" % [stage_path, "；".join(map_issues)])
			map_issues.clear()
	_check(map_issues.is_empty(), "地图校验器不应有遗留问题")

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
		elif resource is BattleSupplyData:
			_check((resource as BattleSupplyData).is_valid(), "BattleSupplyData 无效: %s" % path)
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
