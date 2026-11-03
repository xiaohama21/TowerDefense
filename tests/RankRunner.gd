extends Node

var failures: Array[String] = []
var _slot := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_slot = "user://.rank_runner_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("RANK: " + message)

func _run() -> void:
	_test_curve_and_ranks()
	_test_migration()
	await _test_combat()
	await _test_panel_transaction()
	await _test_encyclopedia_icons()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("RANK_RESULT: %s failures=%d" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_curve_and_ranks() -> void:
	_check(LevelCurve.max_level() == 100 and LevelCurve.exp_total_for_level(30) == 13340 and LevelCurve.exp_total_for_level(100) == 79770, "经验里程碑")
	var last_need := 0
	for level in range(2, 101):
		var floor := LevelCurve.exp_total_for_level(level)
		var need := floor - LevelCurve.exp_total_for_level(level - 1)
		_check(need >= last_need and LevelCurve.level_from_total_exp(floor) == level and LevelCurve.level_from_total_exp(floor - 1) == level - 1, "连续经验与边界 Lv%d" % level)
		last_need = need
	var profile := PlayerProfile.new()
	_check(not profile.advance_character_rank("guan_yu"), "未拥有不可进阶")
	profile.unlock_character("guan_yu")
	var sum := [0, 0, 0]
	for rank in range(1, 6):
		profile.characters["guan_yu"]["total_exp"] = LevelCurve.exp_total_for_level(CharacterRank.LEVELS[rank]) - 1
		_check(profile.rank_up_status("guan_yu") == "等级不足", "等级门槛 %d" % rank)
		profile.add_character_exp("guan_yu", 1)
		_check(profile.get_character_rank("guan_yu") == rank - 1, "经验不自动进阶")
		var before := profile.to_dict()
		_check(not profile.advance_character_rank("guan_yu") and profile.to_dict() == before, "材料不足原子拒绝")
		for i in range(3):
			var amount := int(CharacterRank.COSTS[rank][i])
			profile.add_item(CharacterRank.MATERIALS[i], amount)
			sum[i] += amount
		_check(profile.advance_character_rank("guan_yu") and profile.get_character_rank("guan_yu") == rank, "逐阶消耗 %d" % rank)
	_check(sum == [54, 36, 24] and not profile.advance_character_rank("guan_yu"), "总消耗和红阶上限")
	_check(CharacterRank.unlocked_slots(0) == 1 and CharacterRank.unlocked_slots(1) == 2 and CharacterRank.unlocked_slots(2) == 3, "技能解锁框架")
	var growth := {"guan_yu": 306, "zhang_fei": 248, "liu_bei": 196, "huang_zhong": 248, "diao_chan": 93, "huang_fu_song": 474, "zhao_yun": 292, "zhou_wei": 334, "zhuge_liang": 270}
	for id in growth:
		var character := GameFlow.load_character_data(id)
		var stats := character.bare_stats_at(100, 5)
		_check(int(stats.attack) == int(growth[id]), "逐将 L100 红阶攻击：" + id)

func _test_migration() -> void:
	for id in LegacyCharacterGrowth.CHARACTERS:
		var base: Array = LegacyCharacterGrowth.CHARACTERS[id]
		var options: Array[String] = [""]
		for promo in LegacyCharacterGrowth.PROMOTIONS:
			if LegacyCharacterGrowth.PROMOTIONS[promo][3] == base[5]:
				options.append(promo)
		for level in [10, 20, 30]:
			for promo in options:
				var entry := {"total_exp": LevelCurve.exp_total_for_level(level), "promotion_path": [promo] if not promo.is_empty() else [], "stars": 5}
				var raw := {"schema_version": 6, "characters": {id: entry}, "items": {"yellow_turban_cloth": 12, "general_seal": 3, "wolf_tooth": 1}, "exp_pool": 456, "military_merit": 789}
				var result: Dictionary = ProfileStore._migrate_to_current(raw)
				_check(result.ok and result.data.schema_version == PlayerProfile.CURRENT_SCHEMA_VERSION, "v6→v7")
				var profile := PlayerProfile.from_dict(result.data)
				var migrated := profile.get_character(id)
				_check(not migrated.has("promotion_path") and not migrated.has("stars") and profile.items.get("general_seal") == 15 and not profile.items.has("yellow_turban_cloth"), "删除旧字段与 1:1 折算")
				_check(profile.exp_pool == 456 and profile.military_merit == 789 and profile.items.get("wolf_tooth") == 1, "其他进度保留")
				var old := LegacyCharacterGrowth.guard_for(id, entry)
				var character := GameFlow.load_character_data(id)
				var stats := character.compute_stats_at(level, profile.get_character_rank(id), null, 0, migrated.growth_guard)
				_check(int(stats.attack) >= int(old.attack) and float(stats.range) >= float(old.range) - 0.001 and float(stats.attack_interval) <= float(old.attack_interval) + 0.001, "旧裸面板不回退：%s L%d %s" % [id, level, promo])
				var again: Dictionary = ProfileStore._migrate_to_current(result.data).data
				_check(again == result.data, "迁移重复执行幂等")
				var remaining := character.remaining_guard(100, 5, migrated.growth_guard)
				var naked := character.bare_stats_at(100, 5)
				for key in remaining:
					_check(float(naked[key]) > float(remaining[key]) if key == "attack_interval" else float(naked[key]) < float(remaining[key]), "只保留未追平项：" + id)
	var profile := PlayerProfile.new()
	profile.unlock_character("guan_yu")
	_check(profile.get_character("guan_yu").growth_guard.is_empty() and profile.get_character_rank("guan_yu") == 0, "新档没有守护")
	for key in ["yuanbao", "lord_exp", "talent_alloc", "shop_purchases", "skill_levels"]:
		_check(not profile.to_dict().has(key), "不预置未来容器：" + key)
	var profile_saved := PlayerProfile.from_dict(ProfileStore._migrate_v6_to_v7({"schema_version": 6, "characters": {"guan_yu": {"total_exp": 13340, "promotion_path": ["cavalry_heavy_armor"]}}}))
	_check(ProfileStore.save_profile(profile_saved), "迁移档持久化")
	ProfileStore.profile = null
	var reloaded := ProfileStore.load_profile()
	var loaded_entry := reloaded.get_character("guan_yu").duplicate(true)
	var saved_entry := profile_saved.get_character("guan_yu").duplicate(true)
	var loaded_guard: Dictionary = loaded_entry.growth_guard
	var saved_guard: Dictionary = saved_entry.growth_guard
	loaded_entry.erase("growth_guard")
	saved_entry.erase("growth_guard")
	_check(loaded_entry == saved_entry and loaded_guard.keys() == saved_guard.keys(), "守护存盘往返字段")
	for key in saved_guard:
		_check(is_equal_approx(float(loaded_guard.get(key, 0.0)), float(saved_guard[key])), "守护存盘往返数值：" + key)

func _test_combat() -> void:
	GameManager.reset(99999, 20, 1)
	GameFlow.clear_squad_relics()
	GameFlow.squad_character_ids = []
	var tower := (load("res://scenes/Tower.tscn") as PackedScene).instantiate() as Tower
	add_child(tower)
	tower.apply_character(GameFlow.load_character_data("guan_yu"), {"level": 100, "rank": 5})
	tower.set_process(false)
	_check(tower.attack_hit_damage(100, 0.0) == 163 and tower.attack_hit_damage(100, 0.9) == 100, "暴击判定与爆伤")
	tower.crit_rate = 2.0
	tower._base_crit_rate = 2.0
	tower.crit_damage = 1.5
	_check(tower.attack_hit_damage(100, 0.74) == 150 and tower.attack_hit_damage(100, 0.75) == 100, "暴击率 clamp 75%")
	var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.max_hp = 100000
	enemy.armor = 50
	var path := Path2D.new()
	path.curve = Curve2D.new()
	path.curve.add_point(Vector2.ZERO)
	path.curve.add_point(Vector2(1000, 0))
	add_child(path)
	path.add_child(enemy)
	enemy.set_process(false)
	var hp := enemy.current_hp
	tower.deal_damage(enemy, tower.attack_hit_damage(100, 0.0), DamageTypes.PHYSICAL)
	_check(hp - enemy.current_hp == 75, "暴击护甲顺序")
	hp = enemy.current_hp
	tower.deal_damage(enemy, tower.attack_hit_damage(100, 0.0), DamageTypes.TRUE)
	_check(hp - enemy.current_hp == 150, "真伤普攻可暴击")
	tower.skill_amp = 0.4
	_check(int(round(100 * tower.skill_output_multiplier())) == 140 and tower.finalize_damage(100, enemy, DamageTypes.TRUE, false) == 100, "技能增幅不进入普攻")
	tower.rage = 0.0
	tower.notify_attack_damage_dealt(enemy, tower.attack_hit_damage(100, 0.0))
	_check(is_equal_approx(tower.rage, 19.0), "暴击打甲前伤害参与单次积怒")
	var bullet := Bullet.new()
	bullet.source_tower = tower
	bullet.damage = 100
	_check(bullet._hit_damage(enemy) == 100, "技能弹道不暴击")
	bullet.counts_as_attack = true
	bullet.damage_type = DamageTypes.TRUE
	bullet.lob_landing = Vector2(20, 0)
	bullet.explosion_radius = 100
	var enemy2 := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy2.max_hp = 100000
	path.add_child(enemy2)
	enemy2.set_process(false)
	var selected_seed := 0
	for candidate in range(100):
		seed(candidate)
		if (randf() < 0.75) != (randf() < 0.75):
			selected_seed = candidate
			break
	var hp1 := enemy.current_hp
	var hp2 := enemy2.current_hp
	seed(selected_seed)
	tower.rage = 0.0
	add_child(bullet)
	bullet._explode()
	_check([hp1 - enemy.current_hp, hp2 - enemy2.current_hp].has(100) and [hp1 - enemy.current_hp, hp2 - enemy2.current_hp].has(150), "范围普攻逐目标独立判定")
	_check(is_equal_approx(tower.rage, 19.0), "范围普攻按最高命中伤害仅积怒一次")
	bullet.lob_landing = Vector2(5000, 5000)
	bullet._explode()
	_check(is_equal_approx(tower.rage, 19.0), "空爆不积怒")
	bullet.queue_free()
	var in_flight := Bullet.new()
	in_flight.source_tower = tower
	in_flight.counts_as_attack = true
	in_flight.damage = 100
	add_child(in_flight)
	in_flight.set_physics_process(false)
	tower.queue_free()
	path.queue_free()
	await get_tree().process_frame
	seed(selected_seed)
	var shots := [in_flight._hit_damage(), in_flight._hit_damage()]
	_check(shots.has(100) and shots.has(150), "售塔后在途普攻保留暴击且逐次判定")
	in_flight.queue_free()

func _test_panel_transaction() -> void:
	var profile := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(profile)
	profile.add_character_exp("guan_yu", LevelCurve.exp_total_for_level(20))
	for key in CharacterRank.MATERIALS:
		profile.add_item(key, 100)
	var panel: VBoxContainer = (load("res://scripts/ui_screens/panels/DevelopPanel.gd") as GDScript).new()
	add_child(panel)
	await get_tree().process_frame
	panel._select_character("guan_yu")
	panel._refresh()
	_check(panel._tab_container.get_tab_count() == 4 and panel._tab_container.get_tab_title(1) == "品阶" and panel._tab_container.get_tab_title(2) == "装备", "养成页签清理")
	var numeric_row: Control = panel._rank_value("stat_range", "×1.01 → ×1.03", "射程倍率")
	_check((numeric_row.get_child(1) as Label).autowrap_mode == TextServer.AUTOWRAP_OFF, "品阶数值单行防竖排")
	numeric_row.free()
	var before := profile.to_dict()
	panel._on_rank_pressed()
	var dialog: ConfirmationDialog = panel.get_child(panel.get_child_count() - 1)
	dialog.canceled.emit()
	await get_tree().process_frame
	_check(profile.to_dict() == before, "取消不扣料")
	panel._on_rank_pressed()
	dialog = panel.get_child(panel.get_child_count() - 1)
	ProfileStore._writes_blocked = true
	dialog.confirmed.emit()
	_check(profile.to_dict() == before, "写盘失败不扣料")
	ProfileStore._writes_blocked = false
	dialog.confirmed.emit()
	await get_tree().process_frame
	_check(profile.get_character_rank("guan_yu") == 1 and int(profile.items.general_seal) == 97 and int(profile.items.refined_iron) == 96 and int(profile.items.ebony) == 98, "确认后原子写档扣料")
	var badge := panel._character_buttons["guan_yu"].find_child("CardRank", true, false) as ConceptIcon
	_check(badge != null and badge.placeholder_color == CharacterRank.COLORS[1], "进阶后列表徽记立即刷新")
	panel.queue_free()
	await get_tree().process_frame

func _test_encyclopedia_icons() -> void:
	var panel = (load("res://scripts/ui_screens/panels/EncyclopediaPanel.gd") as GDScript).new()
	add_child(panel)
	await get_tree().process_frame
	for id in ["zhuge_liang", "guan_yu"]:
		var before := ProfileStore.get_profile().to_dict()
		panel._select_character(id)
		panel._on_sim_changed()
		await get_tree().process_frame
		var icon_id := "dmg_magic" if id == "zhuge_liang" else "dmg_physical"
		_check(panel._sim_rank_option.get_item_icon(0).get_size() == Vector2(24, 24), "百科下拉图徽固定显示尺寸")
		_check(panel._sim_rank_option.get_combined_minimum_size().y <= 40, "百科下拉最小高度不被源图撑大")
		var stat_rows: Array = panel._base_tab.find_children("*", "GridContainer", true, false)
		_check(not stat_rows.is_empty(), "百科基础属性卡存在")
		if stat_rows.is_empty():
			continue
		var base_icon: ConceptIcon = stat_rows.back().get_child(0).get_child(0).get_child(0).get_child(0)
		_check(base_icon.texture == UITheme.hud_icon_sized(icon_id, 22), "百科基础攻击图徽按类型切换：" + id)
		_check(panel._sim_attack_icon.texture == UITheme.hud_icon_sized(icon_id, 20), "百科模拟攻击图徽按类型切换：" + id)
		_check(ProfileStore.get_profile().to_dict() == before, "百科切换预览不写档")
	panel.queue_free()
	await get_tree().process_frame
