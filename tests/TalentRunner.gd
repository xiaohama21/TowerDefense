extends Node

var failures: Array[String] = []
var checks := 0
var _slot := ""
var _path: Path2D
const TOWER_SCENE := preload("res://scenes/Tower.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

func _ready() -> void:
	_slot = "user://.talents_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("TALENT: " + label)

func _all(character_id: String, count: int = 3) -> Dictionary:
	var alloc := {}
	for tree_id in TalentRegistry.tree_ids(character_id).slice(0, count):
		for node in TalentRegistry.get_tree_data(tree_id).nodes: alloc[str(node.id)] = 2
	return alloc

func _profile(level: int = 100) -> PlayerProfile:
	return PlayerProfile.from_dict({"characters": {"guan_yu": {"total_exp": LevelCurve.exp_total_for_level(level)}, "zhao_yun": {"total_exp": LevelCurve.exp_total_for_level(level)}}})

func _tower(id: String = "guan_yu", alloc: Dictionary = {}, rank: int = 2) -> Tower:
	var tower := TOWER_SCENE.instantiate() as Tower
	add_child(tower)
	tower.set_process(false)
	tower.apply_character(GameFlow.load_character_data(id), {"level": 100, "rank": rank, "talent_alloc": alloc})
	tower.global_position = Vector2(300, 300)
	tower.crit_rate = 0.0
	return tower

func _enemy(hp: int = 100000, armor: int = 0, tags: Array[StringName] = []) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.max_hp = hp
	enemy.speed = 0.0
	enemy.armor = armor
	enemy.reward = 0
	enemy.kill_xp = 0
	enemy.tags = tags
	_path.add_child(enemy)
	enemy.set_process(false)
	enemy.global_position = Vector2(380, 300)
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
	ProfileStore.create_new_profile(false)
	GameFlow.squad_character_ids = []
	GameFlow.clear_squad_relics()
	GameFlow.selected_difficulty = Difficulty.NORMAL
	GameManager.reset(1000, 20, 4)
	_path = Path2D.new()
	_path.curve = Curve2D.new()
	_path.curve.add_point(Vector2.ZERO)
	_path.curve.add_point(Vector2(2000, 0))
	add_child(_path)
	_resources()
	_allocations()
	_migration()
	_stats()
	_combat()
	_clear()
	_ultimates()
	_clear()
	await _pause_and_rage()
	_clear()
	_economy_and_support()
	_clear()
	await _ui_transactions()
	_clear()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	await get_tree().process_frame
	print("TALENT_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _resources() -> void:
	var count := 0
	for id in TalentRegistry.IDS:
		var tree := TalentRegistry.get_tree_data(id)
		_check(tree != null and tree.nodes.size() == 10, "树10节点 " + id)
		var tiers := [0, 0, 0, 0]
		for node in tree.nodes:
			count += 1
			_check(str(node.get("icon_key", "")) == "talent_" + str(node.id).replace(".", "_") and UITheme.hud_icon(str(node.get("icon_key", ""))) != null, "节点专属图徽 " + str(node.id))
			tiers[int(node.tier) - 1] += 1
			_check(str(node.id).begins_with(id + ".") and not str(node.name).is_empty() and not str(node.description).is_empty(), "节点ID/中文 " + str(node.id))
		_check(tiers == [3, 3, 3, 1], "层级容量 " + id)
		_check(UITheme.hud_icon(tree.icon_key) != null, "树图徽 " + id)
	_check(count == 110, "全库110节点")
	for id in SkillRegistry.KITS:
		_check(TalentRegistry.tree_ids(id).size() == 3, "九将三树 " + id)
		var all := TalentRegistry.bonuses(id, _all(id))
		_check(float(all.get("crit_rate", 0)) <= 0.040001 and float(all.get("crit_damage", 0)) <= 0.120001 and float(all.get("skill_amp", 0)) + float(all.get("ultimate_amp", 0)) <= 0.080001, "三树节点预算 " + id)

func _allocations() -> void:
	for pair in [[1, 0], [4, 0], [5, 2], [99, 38], [100, 40]]:
		_check(TalentRegistry.points_for_level(pair[0]) == pair[1], "等级点数 " + str(pair[0]))
	var p := _profile()
	_check(not p.allocate_talent("guan_yu", "physical_burst.fatal", 0), "空树不能点二层")
	for id in ["physical_burst.slash", "physical_burst.swift"]:
		_check(p.allocate_talent("guan_yu", id, 0) and p.allocate_talent("guan_yu", id, 1), "一层分配 " + id)
	_check(p.talent_allocation_status("guan_yu", "physical_burst.fatal") == "分配", "4点解锁二层")
	_check(p.talent_allocation_status("guan_yu", "armor_break.pierce") == "本树门槛未达", "跨树不认门槛")
	_check(not p.allocate_talent("guan_yu", "physical_burst.slash", 1), "重复点击/满级拒绝")
	for id in ["physical_burst.critical", "physical_burst.fatal"]:
		p.allocate_talent("guan_yu", id, 0)
		p.allocate_talent("guan_yu", id, 1)
	_check(p.talent_allocation_status("guan_yu", "physical_burst.chain") == "分配", "8点解锁三层")
	for id in ["physical_burst.pierce", "physical_burst.rupture"]:
		p.allocate_talent("guan_yu", id, 0)
		p.allocate_talent("guan_yu", id, 1)
	_check(p.talent_allocation_status("guan_yu", "physical_burst.dragon") == "分配", "12点解锁终极")
	_check(p.get_talent_alloc("zhao_yun").is_empty(), "共享树两将独立")
	var bounded := TalentRegistry.normalize("guan_yu", 100, _all("guan_yu"))
	_check(TalentRegistry.spent(bounded) == 40 and TalentRegistry.spent(bounded, "physical_burst") == 20 and TalentRegistry.spent(bounded, "armor_break") == 20, "40点可满两树")
	p.characters.guan_yu.talent_alloc = bounded
	_check(p.talent_points_remaining("guan_yu") == 0 and not p.allocate_talent("guan_yu", "rage.gather", 0), "总预算不可超40")
	var copy := p.get_talent_alloc("guan_yu")
	copy.clear()
	_check(p.talent_points_remaining("guan_yu") == 0, "对外字典不污染存档")
	_check(p.reset_talents("guan_yu", bounded) and p.talent_points_remaining("guan_yu") == 40, "免费重置返40点")
	_check(not p.reset_talents("guan_yu", bounded), "陈旧重置拒绝")
	_check(not p.allocate_talent("unknown", "physical_burst.slash", 0), "未拥有不可分配")
	p = _profile(4)
	_check(not p.allocate_talent("guan_yu", "physical_burst.slash", 0), "L4不可分配")
	p.add_character_exp("guan_yu", LevelCurve.exp_total_for_level(5) - p.get_character_exp("guan_yu"))
	_check(p.talent_points_remaining("guan_yu") == 2, "升级自动获得2点")

func _migration() -> void:
	var raw := {"physical_burst.slash": 99, "physical_burst.swift": true, "physical_burst.critical": NAN, "physical_burst.fatal": -1, "physical_burst.power": 2, "magic_area.focus": 2, "rage.resolve": 1.5, "rage.gather": INF, "unknown": 2}
	var normalized := TalentRegistry.normalize("guan_yu", 100, raw)
	_check(normalized == {"physical_burst.slash": 2}, "未知外树/布尔/非整数/NaN/Inf/负值/孤高层清除")
	_check(TalentRegistry.normalize("guan_yu", 5, _all("guan_yu")) == {"physical_burst.slash": 2}, "低等级存档预算截断")
	var old := {"schema_version": 10, "characters": {"guan_yu": {"total_exp": LevelCurve.exp_total_for_level(100), "rank": 4, "skill_levels": {"char_green_dragon": 8}, "talent_alloc": _all("guan_yu", 2)}}, "ingots": 123, "military_merit": 456}
	var result := ProfileStore._migrate_to_current(old)
	_check(result.ok and result.data.schema_version == 11, "v10迁移v11")
	_check(ProfileStore._migrate_v10_to_v11(result.data) == result.data, "迁移幂等")
	var p := PlayerProfile.from_dict(result.data)
	_check(p.ingots == 123 and p.military_merit == 456 and p.get_character_rank("guan_yu") == 4 and p.get_skill_level("guan_yu", &"char_green_dragon") == 8 and p.talent_points_remaining("guan_yu") == 0, "有效成长/货币/技能/天赋保留")
	_check(not p.get_character("guan_yu").has("faction"), "不预置阵营")
	_check(not ProfileStore._migrate_to_current({"schema_version":12}).ok, "未来档保护")
	var missing := ProfileStore._migrate_to_current({"schema_version":10,"characters":{"guan_yu":{}}})
	_check(missing.ok and missing.data.characters.guan_yu.talent_alloc == {}, "缺失补空")

func _stats() -> void:
	for id in SkillRegistry.KITS:
		var character := GameFlow.load_character_data(id)
		for level in [1, 20, 100]:
			_check(character.compute_stats_at(level, 2) == character.compute_stats_at(level, 2, null, 0, {}, {}, null, {}), "空天赋基准 " + id + str(level))
	var character := GameFlow.load_character_data("guan_yu")
	var empty := character.compute_stats_at(100, 2)
	var full := character.compute_stats_at(100, 2, null, 0, {}, {}, null, _all("guan_yu", 1))
	_check(full.attack == int(round(empty.attack * 1.012)), "基础攻击+1.2%")
	_check(is_equal_approx(full.attack_interval, empty.attack_interval / 1.012), "基础攻速+1.2%")
	_check(is_equal_approx(full.crit_rate, empty.crit_rate + .01) and is_equal_approx(full.crit_damage, empty.crit_damage + .03), "暴击/爆伤同轴")
	_check(is_equal_approx(full.skill_amp, empty.skill_amp + .02), "全技能增幅只加2%")
	var values := TalentRegistry.bonuses("guan_yu", _all("guan_yu", 1))
	values.skill_amp = 99
	_check(is_equal_approx(TalentRegistry.skill_amp("guan_yu", _all("guan_yu", 1)), .02), "缓存隔离")
	var guard := {"attack": empty.attack * 2.0}
	_check(character.compute_stats_at(100, 2, null, 0, guard, {}, null, {"physical_burst.slash":2}).attack == int(round(empty.attack * 2.0 * 1.012)), "守护后应用天赋")

func _combat() -> void:
	var tower := _tower("guan_yu", _all("guan_yu", 2))
	var enemy := _enemy(100000, 50)
	var pen := tower.get_armor_penetration(enemy, &"attack")
	_check(is_equal_approx(float(pen.ratios.talent), .06) and pen.flat == 4, "天赋穿甲合源/固定后置")
	tower.notify_attack_damage_dealt(enemy, 10)
	_check(is_equal_approx(float(tower.get_armor_penetration(enemy, &"attack").ratios.talent), .078), "连破同目标第2击")
	var other := _enemy()
	_check(is_equal_approx(float(tower.get_armor_penetration(other, &"attack").ratios.talent), .06), "换目标不吃连破")
	_check(is_equal_approx(float(tower.get_armor_penetration(other, &"ultimate").ratios.talent), .08), "大招专属穿甲")
	var before := other.current_hp
	for _i in range(4): tower.notify_attack_damage_dealt(other, 10)
	_check(int(tower.talent_state.hits) == 5 and other.current_hp < before, "5次命中追加真实伤害不递归")
	var fake := _tower()
	fake.talent_bonuses = {"physical_damage_pct":.1,"elite_damage_pct":.2,"elite_boss_damage_pct":.2}
	var elite := _enemy(1000, 0, [&"elite"])
	var normal := _enemy(1000)
	fake.deal_damage(elite, 100, DamageTypes.PHYSICAL)
	fake.deal_damage(normal, 100, DamageTypes.PHYSICAL)
	_check(elite.current_hp == 870 and normal.current_hp == 890, "条件桶上限30%与目标独立")
	normal.take_damage(20, fake.character_id, DamageTypes.MAGIC, {}, 0, true, fake)
	_check(normal.current_hp == 870, "固定状态不吃天赋")
	_clear()
	tower = _tower("huang_fu_song")
	tower.talent_bonuses = {"hit_rage_flat":1.0,"armor_ignore_every":5.,"armor_ignore_mult":.1,"slow_on_hit":.02}
	TalentCombat.reset(tower)
	var first := _enemy()
	var second := _enemy()
	var bullet := tower.instantiate_bullet(first)
	bullet.counts_as_attack = true
	bullet.damage = 10
	bullet.lob_landing = first.global_position
	bullet.explosion_radius = 150
	bullet._explode()
	_check(tower.talent_state.hits == 1 and first.is_controlled() and second.is_controlled(), "范围一发一次计数、逐目标控制")
	_check(is_equal_approx(tower.rage, 6.0), "范围命中怒气只加一次")
	bullet.queue_free()
	var hits: int = tower.talent_state.hits
	tower.notify_aoe_damage_dealt(0)
	_check(tower.talent_state.hits == hits, "空爆不触发")
	_clear()
	tower = _tower("guan_yu")
	var twin := _tower("guan_yu")
	tower.talent_bonuses = {"kill_rage_flat":1.,"ultimate_kill_rage":4.,"kill_speed_pct":.02,"kill_pen_flat":6.}
	twin.talent_bonuses = tower.talent_bonuses.duplicate()
	var victim := _enemy(10)
	tower.deal_damage(victim, 20, DamageTypes.TRUE, &"ultimate")
	_check(is_equal_approx(tower.rage, 5.0) and twin.rage == 0, "真实击杀塔独立、大招返怒")
	_check(tower.get_armor_penetration().flat == 6 and is_equal_approx(TalentCombat.speed_multiplier(tower),1.02), "击杀穿甲/攻速2s")
	TalentCombat.tick(tower, 2.01)
	_check(tower.get_armor_penetration().flat == 0 and TalentCombat.speed_multiplier(tower) == 1.0, "击杀窗口过期")
	victim = _enemy(10)
	victim.take_damage(20, tower.character_id, DamageTypes.MAGIC, {}, 0, true, tower)
	_check(is_equal_approx(tower.rage, 6.0), "状态击杀仅普通返怒")
	tower.talent_bonuses.leak_rage_flat = 5.
	TalentCombat.on_leak(tower)
	TalentCombat.on_leak(tower)
	_check(is_equal_approx(tower.rage,11.), "每波首次漏怪一次")
	GameManager.current_wave += 1
	TalentCombat.on_leak(tower)
	_check(is_equal_approx(tower.rage,16.), "新波漏怪重开")
	var main_stub := Node2D.new()
	add_child(main_stub)
	main_stub.set_script(preload("res://scripts/Main.gd"))
	GameManager.last_leak_was_stealth = false
	GameManager.enemy_leaked.connect(main_stub._on_enemy_leaked)
	tower.rage = 0.0
	TalentCombat.reset(tower)
	GameManager.enemy_reached_base(1)
	var late := _tower()
	late.talent_bonuses = {"leak_rage_flat":5.0}
	GameManager.enemy_reached_base(1)
	_check(tower.rage == 5.0 and late.rage == 0.0, "Main全场首次漏怪、后来建塔不补领")
	GameManager.current_wave += 1
	GameManager.enemy_reached_base(1)
	_check(late.rage == 5.0, "后来建塔下波正常领取")
	GameManager.enemy_leaked.disconnect(main_stub._on_enemy_leaked)
	main_stub.queue_free()

func _ultimates() -> void:
	var tower := _tower("guan_yu", _all("guan_yu",1))
	var enemy := _enemy()
	tower.target = enemy
	tower.talent_bonuses.post_ultimate_hit_rage = 3.
	tower.talent_bonuses.post_ultimate_rage_pct = .02
	_check(is_equal_approx(SkillRegistry.strength(tower, &"char_green_dragon"),tower.skill_output_multiplier()+.03), "大招增幅同轴加一次")
	tower.rage = 100.
	_check(tower._try_cast_ultimate() and float(tower.talent_state.fury_left) == 0.0, "异步起手不触发结束")
	tower._process_pending_steps(.21)
	_check(float(tower.talent_state.fury_left) == 0.0, "未到最后一拍不触发")
	tower._process_pending_steps(1.0)
	_check(float(tower.talent_state.fury_left) == 3.0 and float(tower.talent_state.post_left) == 2.0, "最后一拍完成开始2s/3s窗口")
	_check(is_equal_approx(TalentCombat.hit_rage(tower),3.) and is_equal_approx(TalentCombat.rage_bonus(tower),.02), "大招后怒气节点实效")
	TalentCombat.tick(tower,2.1)
	_check(TalentCombat.rage_bonus(tower)==0 and TalentCombat.hit_rage(tower)==3., "2s结束而3s保持")
	TalentCombat.tick(tower,1.)
	_check(TalentCombat.hit_rage(tower)==0, "3s窗口结束")
	_clear()
	tower = _tower("liu_bei")
	var ally := _tower()
	tower.talent_bonuses = {"post_ultimate_hit_rage":2.,"buff_duration_pct":.2}
	tower.rage = 100.
	_check(tower._try_cast_ultimate() and float(tower.talent_state.fury_left)==0, "增益大招起手不触发结束")
	var time_left := SkillRegistry.duration(tower,&"char_carry_people") * tower.get_battle_rank_buff_duration_multiplier()
	tower._process_pending_steps(time_left-.01)
	_check(float(tower.talent_state.fury_left)==0, "增益有效期内不算结束")
	tower._process_pending_steps(.02)
	_check(float(tower.talent_state.fury_left)==3. and ally.attack_speed_buff>1., "增益大招原始时长结束回调")
	_clear()
	tower = _tower()
	tower.talent_bonuses = {"post_ultimate_hit_rage":3.}
	tower.rage=100.
	_check(not tower._try_cast_ultimate() and tower.rage==100. and float(tower.talent_state.fury_left)==0, "施放失败不扣怒/触发")

func _economy_and_support() -> void:
	var tower := _tower("liu_bei")
	tower.talent_bonuses = {"kill_gold_pct":.1,"elite_gold_pct":.1,"upgrade_discount_pct":.1,"buff_power_pct":.1,"buff_duration_pct":.1,"support_hit_rage":1.}
	var before := GameManager.gold
	for _i in range(10):
		var enemy := _enemy(1)
		enemy.reward=1
		tower.deal_damage(enemy,2,DamageTypes.TRUE)
	_check(GameManager.gold-before==11, "金币小数累计与真实金币一次反馈")
	_check(tower.get_upgrade_cost(1.5)==ceili(tower.build_cost*1.5*.9), "自身升阶折扣向上取整")
	var ally := _tower()
	var base_damage := ally.damage
	ally.refresh_aura_damage_bonus()
	_check(ally.damage>=base_damage, "仁德增强真实覆盖")
	_check(is_equal_approx(tower.get_battle_rank_buff_power_multiplier(),1.1) and is_equal_approx(tower.get_battle_rank_buff_duration_multiplier(),1.1), "增益强度与时长施加方")
	_clear()
	tower=_tower("diao_chan")
	tower.talent_bonuses={"support_hit_rage":1.}
	ally=_tower()
	tower.gain_support_pulse([ally])
	_check(is_equal_approx(tower.rage,8.442), "辅助脉冲额外怒气一次")
	var mage:=_tower("zhuge_liang")
	mage.talent_bonuses={"slow_strength_pct":.1,"control_duration_pct":.1,"reveal_duration_pct":.1}
	var target:=_enemy()
	SkillRegistry.tick(mage,.25)
	_check(target.is_controlled() and target.slow_factor<.92, "减速天赋实际施加")

func _pause_and_rage() -> void:
	var tower := _tower()
	tower.talent_bonuses = {"post_ultimate_hit_rage":3., "high_rage_speed_pct":.02}
	TalentCombat.on_ultimate_end(tower)
	tower.process_mode = Node.PROCESS_MODE_PAUSABLE
	tower.set_process(true)
	get_tree().paused = true
	await get_tree().create_timer(.04, true).timeout
	_check(float(tower.talent_state.fury_left) == 3.0, "真实暂停冻结天赋窗口")
	get_tree().paused = false
	tower.set_process(false)
	tower.grant_rage_flat(49.)
	_check(TalentCombat.speed_multiplier(tower) == 1.0, "49%怒气不加速")
	tower.grant_rage_flat(1.)
	_check(is_equal_approx(tower.attack_timer.wait_time, tower.attack_cooldown / 1.02), "50%阈值即时更新攻击计时器")

func _ui_transactions() -> void:
	ProfileStore.profile=_profile()
	ProfileStore.save_profile(ProfileStore.profile)
	var panel:=preload("res://scripts/ui_screens/panels/DevelopPanel.gd").new()
	panel.custom_minimum_size=Vector2(1000,620)
	add_child(panel)
	await get_tree().process_frame
	panel._select_character("guan_yu")
	panel._talent_button.pressed.emit()
	var popup: TalentTreePanel = panel._talent_panel
	_check(panel._tab_container.get_tab_count()==4 and popup.node_buttons.size()==30, "养成四页签与独立30节点弹窗")
	panel._talent_button.pressed.emit()
	_check(panel._talent_panel == popup, "重复入口不叠加弹窗")
	var inspect_snapshot := ProfileStore.profile.to_dict()
	popup.node_buttons["physical_burst.slash"].pressed.emit()
	_check(is_instance_valid(popup.detail_panel) and popup.selected_node_id == "physical_burst.slash" and ProfileStore.profile.to_dict() == inspect_snapshot, "节点点击只查看详情不扣点")
	_check(popup.detail_panel.find_child("NodeDescription", true, false).text.contains("0.6%"), "详情常显中文效果")
	var focus_event := InputEventAction.new()
	focus_event.action = "ui_focus_next"
	focus_event.pressed = true
	Input.parse_input_event(focus_event)
	await get_tree().process_frame
	_check(popup.detail_panel.is_ancestor_of(get_viewport().gui_get_focus_owner()), "Tab焦点限制在节点详情内")
	focus_event.pressed = false
	Input.parse_input_event(focus_event)
	popup.close_detail()
	popup.node_buttons["physical_burst.fatal"].pressed.emit()
	_check(popup.detail_action.disabled, "门槛未达仍可查看详情但不可分配")
	popup.close_detail()
	popup.open_detail("physical_burst.slash")
	var saved_before:=ProfileStore.profile.to_dict()
	ProfileStore.configure_paths("user://talent_blocked.json", "", "user://")
	_check(not panel._allocate_talent("physical_burst.slash",0) and ProfileStore.profile.to_dict()==saved_before, "分配保存失败不扣点")
	ProfileStore.configure_paths(_slot)
	popup.detail_action.pressed.emit()
	_check(ProfileStore.profile.get_talent_alloc("guan_yu").get("physical_burst.slash")==1 and popup.selected_node_id == "physical_burst.slash" and is_instance_valid(popup.detail_panel), "详情分配原子保存并保留节点")
	var alloc:=ProfileStore.profile.get_talent_alloc("guan_yu")
	panel._confirm_reset_talents()
	panel._talent_reset_dialog.canceled.emit()
	_check(ProfileStore.profile.get_talent_alloc("guan_yu")==alloc, "取消重置保持")
	ProfileStore.configure_paths("user://talent_blocked.json", "", "user://")
	_check(not panel._reset_talents("guan_yu",alloc) and ProfileStore.profile.get_talent_alloc("guan_yu")==alloc, "重置保存失败保持")
	ProfileStore.configure_paths(_slot)
	_check(panel._reset_talents("guan_yu",alloc) and ProfileStore.profile.talent_points_remaining("guan_yu")==40, "重置原子保存")
	popup.close_detail()
	popup.dismiss()
	_check(panel._talent_panel == null and get_viewport().gui_get_focus_owner() == panel._talent_button, "关闭返回属性面板并恢复入口焦点")
	var encyclopedia:=preload("res://scripts/ui_screens/panels/EncyclopediaPanel.gd").new()
	encyclopedia.custom_minimum_size=Vector2(1000,620)
	add_child(encyclopedia)
	await get_tree().process_frame
	encyclopedia._select_character("guan_yu")
	encyclopedia._sim_level=100
	encyclopedia._on_sim_changed()
	encyclopedia._talent_button.pressed.emit()
	var before_sim:=ProfileStore.profile.to_dict()
	encyclopedia._allocate_sim_talent("physical_burst.slash",0)
	_check(encyclopedia._tab_container.get_tab_count()==4 and encyclopedia._sim_talent_alloc.get("physical_burst.slash")==1 and ProfileStore.profile.to_dict()==before_sim, "百科模拟不写档")
	encyclopedia._sim_level=1
	encyclopedia._on_sim_changed()
	_check(encyclopedia._sim_talent_alloc.is_empty(), "模拟降级归一化")
	encyclopedia._change_talent_level(1)
	_check(encyclopedia._sim_level == 2 and ProfileStore.profile.to_dict() == before_sim, "弹窗内调模拟等级不写档")
	encyclopedia.hide()
	_check(encyclopedia._talent_panel == null, "父面板隐藏关闭天赋弹窗")
	panel.queue_free()
	encyclopedia.queue_free()
