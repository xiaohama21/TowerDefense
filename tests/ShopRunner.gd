extends Node

var checks := 0
var failures: Array[String] = []
var _slot := ""

func _ready() -> void:
	_slot = "user://.shop_test_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("SHOP: " + message)

func _rich(level: int = 1) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.ingots = 100000
	p.military_merit = 10000
	p.lord_exp = ShopRegistry.exp_for_level(level)
	p.shop_state = ShopRegistry.normalize_state({}, p.lord_exp)
	return p

func _run() -> void:
	_test_catalog_and_progress()
	_test_migration()
	_test_purchases()
	_test_rotation()
	await _test_transactions_and_ui()
	await _test_map_ui()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("SHOP_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_catalog_and_progress() -> void:
	_check(ShopRegistry.all_offers().size() == 31, "7常驻+7轮换+5军功+12装备")
	var unique := {}
	for entry in ShopRegistry.all_offers():
		_check(not unique.has(entry.id) and entry.price > 0, "商品ID与价格有效 " + str(entry.id))
		unique[entry.id] = true
		for id in entry.items:
			_check(GameFlow.load_item_data(str(id)) != null and int(entry.items[id]) > 0, "商品资源 " + str(id))
	_check(ShopRegistry.exp_for_level(2) == 30 and ShopRegistry.exp_for_level(10) == 450 and ShopRegistry.exp_for_level(12) == 605 and ShopRegistry.exp_for_level(100) == 27225, "固定等级预算锚点")
	_check(ShopRegistry.lord_progress(29).level == 1 and ShopRegistry.lord_progress(30).level == 2 and ShopRegistry.lord_progress(640).level == 12 and ShopRegistry.lord_progress(999999).level == 100, "升档边界与上限")
	for pair in [[1,1],[9,1],[10,2],[19,2],[20,3],[39,3],[40,4],[59,4],[60,5],[79,5],[80,6],[100,6]]:
		_check(ShopRegistry.tier(pair[0]) == pair[1], "货档边界 %d" % pair[0])
	_check(ShopRegistry.victory_rewards(true, 0) == {"ingots":30,"lord_exp":80}, "标准首通")
	_check(ShopRegistry.victory_rewards(false, 0) == {"ingots":10,"lord_exp":25}, "标准重复")
	_check(ShopRegistry.victory_rewards(true, 1) == {"ingots":60,"lord_exp":120}, "困难首通")
	_check(ShopRegistry.victory_rewards(false, 1) == {"ingots":20,"lord_exp":38}, "困难重复独立倍率")
	var character := GameFlow.load_character_data("guan_yu")
	var stats := character.compute_stats_at(20, 1)
	var p := _rich(100)
	_check(character.compute_stats_at(20, 1) == stats and p.lord_exp == 27225, "主公不进入角色属性")

func _test_migration() -> void:
	var raw := {"schema_version":9,"characters":{"guan_yu":{"rank":2,"skill_levels":{"char_green_dragon":6},"weapon_id":"equipment_long_spear_1"}},"weapons":{"equipment_long_spear_1":1},"items":{"iron_shield":1},"stage_progress":{"ch01_s01":{"completed":true}},"military_merit":123}
	var result := ProfileStore._migrate_to_current(raw)
	var p := PlayerProfile.from_dict(result.data)
	_check(result.ok and p.to_dict().schema_version == 10 and p.ingots == 0 and p.lord_exp == 0, "旧档补零无首通补偿")
	_check(p.get_character_rank("guan_yu") == 2 and p.get_skill_level("guan_yu", &"char_green_dragon") == 6 and p.weapon_count("equipment_long_spear_1") == 1 and p.military_merit == 123, "旧养成/装备/军功保留")
	_check(p.shop_state.rotation == ["rot_iron_5","rot_ebony_3"], "初始两件不重复")
	_check(ProfileStore._migrate_v9_to_v10(result.data) == result.data and p.duplicate_profile().to_dict() == p.to_dict(), "幂等与读档货架保留")
	p.ingots = 654
	p.lord_exp = 999
	p.shop_state.refresh_step = 2
	p.shop_state.permanent_counts = {"iron_1":4}
	var kept := PlayerProfile.from_dict(ProfileStore._migrate_v9_to_v10(p.to_dict()))
	_check(kept.ingots == 654 and kept.lord_exp == 999 and kept.shop_state.refresh_step == 2 and kept.shop_state.permanent_counts.iron_1 == 4, "有效字段不覆盖")
	var corrupt := PlayerProfile.from_dict({"ingots":NAN,"lord_exp":INF,"shop_state":{"permanent_counts":{"unknown":5,"iron_1":999,"book_1":-2},"rotation":["rot_iron_5","bad","rot_iron_5"],"refresh_step":99,"revision":-1}})
	_check(corrupt.ingots == 0 and corrupt.lord_exp == 0 and corrupt.shop_state.permanent_counts == {"iron_1":60} and corrupt.shop_state.rotation.size() == 2 and corrupt.shop_state.refresh_step == 2 and corrupt.shop_state.revision == 0, "非法经济数据归一")
	_check(not ProfileStore._migrate_to_current({"schema_version":11}).ok and not ProfileStore._migrate_to_current({"schema_version":10,"shop_state":[]}).ok, "未来档和错误容器拒绝")

func _test_purchases() -> void:
	var p := _rich()
	var old := p.to_dict()
	_check(not ShopRegistry.buy(p, "unknown", 0) and not ShopRegistry.buy(p, "book_1", 0) and not ShopRegistry.buy(p, "equipment_ring_blade_1", 0) and p.to_dict() == old, "未知/等级/关卡门槛拒绝无扣费")
	_check(ShopRegistry.buy(p,"iron_1",0) and p.ingots == 99992 and p.items.refined_iron == 1 and p.military_merit == 10000, "元宝单买不动军功")
	old = p.to_dict()
	_check(not ShopRegistry.buy(p,"iron_1",0) and p.to_dict() == old, "旧点击拒绝")
	for i in range(59): _check(ShopRegistry.buy(p,"iron_1",int(p.shop_state.revision)), "精铁限购内购买")
	old = p.to_dict()
	_check(not ShopRegistry.buy(p,"iron_1",int(p.shop_state.revision)) and p.to_dict() == old and p.items.refined_iron == 60, "永久60封顶不扣费")
	p.lord_exp = 450
	_check(ShopRegistry.buy(p,"book_1",int(p.shop_state.revision)) and p.items.skill_book == 1, "L10解锁技能书")
	for item in [["iron_shield",240],["provision_bag",240],["scout_eye",300],["wolf_tooth",360],["war_drums",360]]:
		var before_merit := p.military_merit
		var before_ingots := p.ingots
		_check(ShopRegistry.buy(p,"merit_"+item[0],int(p.shop_state.revision)) and p.military_merit == before_merit-item[1] and p.ingots == before_ingots and p.items[item[0]] == 1, "军功独立兑换 " + item[0])
		old = p.to_dict()
		_check(not ShopRegistry.buy(p,"merit_"+item[0],int(p.shop_state.revision)) and p.to_dict() == old, "遗物永久仅一次 " + item[0])
	var legacy := _rich()
	legacy.add_item("iron_shield", 1)
	_check(ShopRegistry.purchase_status(legacy, ShopRegistry.offer("merit_iron_shield")) == "已购", "旧遗物视为已购")
	for id in WeaponRegistry.IDS:
		var buyer := _rich()
		buyer.stage_progress[str(WeaponRegistry.get_weapon(id).unlock_stage_id)] = {"completed":true}
		for i in range(3): _check(ShopRegistry.buy(buyer,id,int(buyer.shop_state.revision)), "装备复件 " + id)
		_check(buyer.ingots == 99640 and buyer.weapon_count(id) == 3 and not ShopRegistry.buy(buyer,id,int(buyer.shop_state.revision)), "每款3件上限 " + id)
	var poor := PlayerProfile.new()
	_check(not ShopRegistry.buy(poor,"iron_1",0) and not ShopRegistry.manual_refresh(poor,0) and poor.ingots == 0, "余额不足拒绝")

func _test_rotation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9426
	for level in [1,10,20,40,60,80,100]:
		var p := _rich(level)
		for i in range(8):
			ShopRegistry.reroll(p, 0, rng)
			var seen := {}
			for id in p.shop_state.rotation:
				seen[id] = true
				_check(ShopRegistry.rotation_pool(level).has(id), "轮换符合货档")
			_check(seen.size() == p.shop_state.rotation.size() and p.shop_state.rotation.size() == (2 if level == 1 else 3), "同屏不重复/池不足")
	var p := _rich()
	for cost in [10,20,30,10,20,30,10]:
		var balance := p.ingots
		_check(ShopRegistry.refresh_price(p) == cost and ShopRegistry.manual_refresh(p,int(p.shop_state.revision),rng) and p.ingots == balance-cost, "刷新价回绕")
	p.lord_exp = 450
	for i in range(12):
		ShopRegistry.reroll(p, 9, rng)
		_check(p.shop_state.rotation.has("rot_seal_3") or p.shop_state.rotation.has("rot_book_2"), "升档至少一件新货")
	var old := p.to_dict()
	var absent := "rot_material_large"
	_check(not ShopRegistry.buy(p,absent,int(p.shop_state.revision)) and p.to_dict() == old, "非当前轮换拒绝")

func _test_transactions_and_ui() -> void:
	var p := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(p)
	p.ingots = 500
	p.military_merit = 500
	ProfileStore.save_profile(p)
	var old := p.to_dict()
	ProfileStore._writes_blocked = true
	_check(not ProfileStore.buy_shop_offer("iron_1",0) and p.to_dict() == old, "购买写档失败全部回滚")
	_check(not ProfileStore.refresh_shop(0) and p.to_dict() == old, "刷新写档失败全部回滚")
	var session := BattleSession.new("ch01_s01",[],"shop_first")
	GameFlow.selected_difficulty = Difficulty.NORMAL
	GameFlow.collect_stage_rewards(session,GameFlow.load_stage_data(&"ch01_s01"),true)
	session.mark_victory()
	_check(not ProfileStore.commit_victory(session) and p.to_dict() == old, "胜利写档失败余额/等级/货架回滚")
	ProfileStore._writes_blocked = false
	_check(ProfileStore.commit_victory(session) and p.ingots == 530 and p.lord_exp == 80 and p.shop_state.refresh_step == 0 and p.shop_state.revision == 1, "胜利原子入账与自动刷新")
	old = p.to_dict()
	_check(ProfileStore.commit_victory(session) and p.to_dict() == old, "重复胜利不再次刷新")
	var repeated := BattleSession.new("ch01_s01",[],"shop_repeat")
	GameFlow.selected_difficulty = Difficulty.HARD
	GameFlow.collect_stage_rewards(repeated,GameFlow.load_stage_data(&"ch01_s01"),true)
	_check(repeated.get_pending_ingots() == 20 and repeated.get_pending_lord_exp() == 38, "跨难度不补首通")
	var restored := BattleSession.from_dict(repeated.to_dict())
	_check(restored.get_pending_ingots() == 20 and restored.get_pending_lord_exp() == 38, "战局经济往返")
	repeated.mark_defeat()
	ProfileStore.discard_session(repeated)
	_check(repeated.get_pending_ingots() == 0 and repeated.get_pending_lord_exp() == 0 and p.to_dict() == old, "失败/丢弃清空经济")
	var panel = load("res://scripts/ui_screens/panels/ShopPanel.gd").new()
	add_child(panel)
	await get_tree().process_frame
	var card: Control = panel.find_child("ShopOffer_iron_1",true,false)
	var button := card.find_child("BuyOffer",true,false) as Button
	var iron_before := int(p.items.get("refined_iron",0))
	button.pressed.emit()
	_check(p.ingots == 522 and p.items.refined_iron == iron_before + 1 and panel.find_child("IngotBalance",true,false).text == "522", "实际购买按钮刷新余额")
	var saved := p.to_dict()
	ProfileStore.load_profile()
	var loaded := ProfileStore.get_profile().to_dict()
	_check(loaded.shop_state == saved.shop_state and loaded.ingots == saved.ingots and loaded.lord_exp == saved.lord_exp and int(loaded.items.refined_iron) == int(saved.items.refined_iron), "重启读档保留经济/物品/货架/限购")
	panel.queue_free()
	await get_tree().process_frame

func _test_map_ui() -> void:
	var p := ProfileStore.get_profile()
	for number in range(1, 9): p.mark_stage_completed("ch01_s%02d" % number, {"difficulty":"normal"})
	ProfileStore.save_profile(p)
	GameFlow.selected_difficulty = Difficulty.NORMAL
	GameFlow.hub_active_panel = &"map"
	var hub = load("res://scenes/GameHub.tscn").instantiate()
	add_child(hub)
	for frame in range(4): await get_tree().process_frame
	var map = hub._panels[&"map"]
	map._select_stage(GameFlow.load_stage_data(&"ch01_s08"))
	_check(map._progress_labels[0].text == "已通关 8/8" and _map_economy_matches(map, "+10", "+25"), "地图最新档案与标准重复经济预告")
	map._on_difficulty_changed(true, Difficulty.HARD)
	for frame in range(4): await get_tree().process_frame
	_check(_map_economy_matches(map, "+20", "+38"), "困难切换同步全部卡片和预告条")
	for id in map._stage_cards:
		var card: Control = map._stage_cards[id]
		var rewards: Control = card.find_child("StageRewardGlyphs", true, false)
		var boundary := card.get_global_rect()
		var reward_rect := rewards.get_global_rect()
		_check(reward_rect.end.y <= boundary.end.y - 3 and reward_rect.position.x >= boundary.position.x and reward_rect.end.x <= boundary.end.x, "八关奖励图徽留在卡片内 " + str(id))
	var ingots_before := p.ingots
	var exp_before := p.lord_exp
	GameFlow.selected_difficulty = Difficulty.NORMAL # 模拟公共状态尚未同步。
	map._on_instant_clear()
	_check(p.ingots == ingots_before + 20 and p.lord_exp == exp_before + 38, "一键通关使用地图所选困难奖励")
	_check(ShopRegistry.acquisition_text("refined_iron").contains("补给") and ShopRegistry.acquisition_text("iron_shield").contains("兑换"), "背包物资与遗物来源对应双店")
	hub.queue_free()
	await get_tree().process_frame

func _map_economy_matches(map, ingots: String, lord_exp: String) -> bool:
	for card in map._stage_cards.values():
		var rewards: Control = card.find_child("StageRewardGlyphs", true, false)
		if rewards.get_child(0).get_child(1).text != ingots or rewards.get_child(1).get_child(1).text != lord_exp: return false
	var detail_economy: Control = map._detail_rewards.get_child(0)
	return detail_economy.get_child(0).get_child(1).text == ingots and detail_economy.get_child(1).get_child(1).text == lord_exp
