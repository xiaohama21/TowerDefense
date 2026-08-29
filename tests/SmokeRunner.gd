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
		build_manager.confirm_pending_build()
		await get_tree().process_frame
		_check(GameManager.gold == 0, "建造关羽后金币应扣除其造价")
		build_manager.selected_character = liu_bei
		build_manager._on_build_requested(slots[1])
		build_manager._on_build_requested(slots[2])
		build_manager.confirm_pending_build()
		await get_tree().process_frame
		_check(tower_manager.get_child_count() == 1, "金币不足时不应生成第二座塔")
		_check(slots[0].occupied and not slots[1].occupied and not slots[2].occupied, "建造位占用状态错误")
		GameManager.gold = 9999
		build_manager._on_build_requested(slots[1])
		build_manager.confirm_pending_build()
		await get_tree().process_frame
		_check(tower_manager.get_child_count() == 2 and slots[1].occupied, "金币充足时应能建造第二座塔")
		# 待确认建造（v0.12.2 防误建）：点选后需确认；取消则不建造。
		build_manager._on_build_requested(slots[3])
		_check(slots[3].get("pending") == true, "点选建造位后应进入待确认状态")
		build_manager.cancel_pending()
		_check(slots[3].get("pending") == false and not slots[3].occupied, "取消后建造位应恢复可用且不建塔")
		build_manager._on_build_requested(slots[3])
		build_manager.confirm_pending_build()
		await get_tree().process_frame
		_check(slots[3].occupied, "确认后应完成建造")
		var extra_tower := tower_manager.get_child(tower_manager.get_child_count() - 1) as Tower
		if extra_tower:
			extra_tower.queue_free()
			slots[3].reset_slot()
			await get_tree().process_frame

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
	var boss := enemy_manager.spawn_enemy_from_data(boss_data) as Enemy
	await get_tree().process_frame
	_check(boss != null and boss.current_hp == 800, "Boss 应以 800 HP 初始化")
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
		build_manager.confirm_pending_build()
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
	_check(LevelCurve.level_from_total_exp(999999) == LevelCurve.MAX_LEVEL, "等级不应超过上限")

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
		rage_tower.queue_free()

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
