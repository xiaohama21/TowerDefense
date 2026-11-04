extends Node

var _failed := 0
var _checks := 0
var _slot := ""

func _ready() -> void:
	_slot = "user://.item_ui_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
		push_error("ITEM_UI: " + message)

func _settle() -> void:
	for frame in range(6): await get_tree().process_frame

func _run() -> void:
	var p := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(p)
	for id in GameFlow.get_all_character_ids():
		p.unlock_character(id)
		p.characters[id]["rank"] = 2
	for id in WeaponRegistry.IDS: p.add_weapon(id, 3)
	for id in ["refined_iron", "ebony", "general_seal", "skill_book", "wolf_tooth", "iron_shield", "war_drums", "scout_eye", "provision_bag"]: p.add_item(id, 3)
	_check(ProfileStore.save_profile(p), "isolated fixture saved")
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await _settle()
	hub._show_panel(&"develop")
	var develop = hub._panels[&"develop"]
	develop._select_character("guan_yu")
	develop._tab_container.current_tab = 0
	await _settle()
	await _check_skill_spacing(develop._skill_tab.get_child(0), "养成")
	hub._show_panel(&"encyclopedia")
	var enc = hub._panels[&"encyclopedia"]
	enc._select_character("guan_yu")
	enc._tab_container.current_tab = 1
	await _settle()
	await _check_skill_spacing(enc._skill_tab.get_parent().get_parent(), "百科")
	for panel_id in [&"develop", &"encyclopedia"]:
		hub._show_panel(panel_id)
		var panel = hub._panels[panel_id]
		panel._tab_container.current_tab = 2
		for id in GameFlow.get_all_character_ids():
			panel._select_character(id)
			await _settle()
			for card in panel._weapon_tab.find_children("WeaponCard_*", "Button", true, false):
				_check(_readable_item(card) and _labels_fit(card), "%s %s装备名称/简介和卡内边界" % [panel_id, id])
	hub._show_panel(&"inventory")
	var inventory = hub._panels[&"inventory"]
	inventory._on_category_pressed(-1)
	await _settle()
	for card in inventory._grid.get_children():
		_check(_readable_item(card) and _labels_fit(card), "背包物品可读且文本在卡内：" + str(card.get_meta("item_id", "")))
	inventory._show_detail("equipment_long_spear_1")
	await _settle()
	_check(_readable_item(inventory._detail_box), "背包装备详情可读")
	hub._show_panel(&"map")
	var map = hub._panels[&"map"]
	for number in range(1, 9):
		map._select_stage(GameFlow.load_stage_data("ch01_s%02d" % number))
		await _settle()
		_check(map.get_viewport_rect().encloses(map._detail_panel.get_global_rect()), "地图详情在视口内")
		_check(not map._detail_rewards.find_children("ItemDescription", "Label", true, false).is_empty(), "地图奖励详情有物品用途")
	for card in map._stage_cards.values():
		var summary := card.find_child("RewardItemNames", true, false) as Label
		_check(summary != null and card.get_global_rect().grow(1).encloses(summary.get_global_rect()), "关卡物品摘要在边框内")
	hub.queue_free()
	await _settle()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("ITEM_UI_RESULT: %s checks=%d failures=%d" % ["PASS" if _failed == 0 else "FAIL", _checks, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _readable_item(control: Control) -> bool:
	var title := control.find_child("ItemName", true, false) as Label
	var description := control.find_child("ItemDescription", true, false) as Label
	return title != null and not title.text.is_empty() and description != null and not description.text.is_empty()

func _labels_fit(card: Control) -> bool:
	for label in card.find_children("*", "Label", true, false):
		if not card.get_global_rect().grow(1).encloses(label.get_global_rect()): return false
	return true

func _check_skill_spacing(scroll: ScrollContainer, context: String) -> void:
	scroll.scroll_vertical = 0
	await _settle()
	var cards := scroll.find_children("SkillCard_*", "PanelContainer", true, false)
	_check(cards.size() == 3, context + "保留三张技能卡")
	if cards.size() != 3: return
	var viewport := scroll.get_global_rect()
	var first: Rect2 = cards[0].get_global_rect()
	var second: Rect2 = cards[1].get_global_rect()
	_check(first.position.x - viewport.position.x >= 12 and first.position.y - viewport.position.y >= 12, context + "首卡与页签边框有留白")
	_check(second.position.y - first.end.y >= 10, context + "技能卡之间有间距")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _settle()
	var last: Rect2 = cards[2].get_global_rect()
	_check(viewport.end.y - last.end.y >= 12, context + "滚动至末卡保留底部留白")
