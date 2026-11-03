extends Node

var _slot := ""
var _capture_dir := "res://build/verify_0.9.4.1"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): _capture_dir = arg.trim_prefix("--capture-dir=")
	_slot = "user://.shop_preview_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _run() -> void:
	var p := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(p)
	p.ingots = 2000
	p.military_merit = 3000
	ProfileStore.save_profile(p)
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._show_panel(&"shop")
	var panel = hub._panels[&"shop"]
	await _shot("shop_l1")
	(panel.find_child("ShopOffer_iron_1",true,false).find_child("BuyOffer",true,false) as Button).pressed.emit()
	await _shot("shop_bought_material")
	(panel.find_child("RefreshShop",true,false) as Button).pressed.emit()
	await _shot("shop_refresh_price")
	p.lord_exp = 450
	ShopRegistry.reroll(p, 1)
	ProfileStore.save_profile(p)
	panel._refresh()
	await _shot("shop_l10")
	await _scroll_to(panel, "ShopOffer_equipment_ring_blade_1")
	await _shot("shop_equipment_locked")
	p.lord_exp = ShopRegistry.exp_for_level(60)
	ShopRegistry.reroll(p, 10)
	for number in range(1,9): p.mark_stage_completed("ch01_s%02d" % number, {"difficulty":"normal"})
	p.add_weapon("equipment_ring_blade_1",2)
	ProfileStore.save_profile(p)
	panel._refresh()
	await _scroll_to(panel, "ShopOffer_equipment_ring_blade_1")
	await _shot("shop_l60_equipment")
	(panel.find_child("ShopOffer_equipment_ring_blade_1",true,false).find_child("BuyOffer",true,false) as Button).pressed.emit()
	await _shot("shop_equipment_full")
	await _scroll_to(panel, "ShopOffer_equipment_ritual_staff_1")
	await _shot("shop_equipment_middle")
	await _scroll_to(panel, "ShopOffer_equipment_wood_mortar_1")
	await _shot("shop_equipment_bottom")
	panel._switch_page(1)
	await _shot("shop_merit")
	(panel.find_child("ShopOffer_merit_iron_shield",true,false).find_child("BuyOffer",true,false) as Button).pressed.emit()
	await _shot("shop_merit_owned")
	await _scroll_to(panel, "ShopOffer_merit_war_drums")
	await _shot("shop_merit_bottom")
	panel._switch_page(0)
	ProfileStore._writes_blocked = true
	panel._buy("iron_1",int(p.shop_state.revision))
	await _shot("shop_save_failed")
	ProfileStore._writes_blocked = false
	p.ingots = 0
	ProfileStore.save_profile(p)
	panel._refresh()
	await _shot("shop_insufficient")
	hub._show_panel(&"map")
	hub._panels[&"map"]._select_stage(GameFlow.load_stage_data(&"ch01_s08"))
	await _shot("map_economy")
	hub._panels[&"map"]._on_difficulty_changed(true, Difficulty.HARD)
	await _shot("map_economy_hard")
	hub._show_panel(&"inventory")
	hub._panels[&"inventory"]._show_detail("refined_iron")
	await _shot("inventory_shop_material")
	hub._panels[&"inventory"]._show_detail("iron_shield")
	await _shot("inventory_shop_relic")
	hub.queue_free()
	await get_tree().process_frame
	GameFlow.selected_stage_id = &"ch01_s01"
	GameFlow.selected_difficulty = Difficulty.NORMAL
	p.lord_exp = 440
	p.stage_progress.clear()
	ProfileStore.save_profile(p)
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.ui.skip_dialogue()
	main._on_victory()
	await _shot("victory_economy_levelup")
	main.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("SHOP_PREVIEW_OK")
	get_tree().quit()

func _scroll_to(panel, card_name: String) -> void:
	for frame in range(4): await get_tree().process_frame
	panel._scroll.ensure_control_visible(panel.find_child(card_name, true, false))
	await get_tree().process_frame

func _shot(label: String) -> void:
	Input.warp_mouse(Vector2(get_viewport().get_visible_rect().size.x - 5, 5))
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	var error := get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(label + ".png"))
	print("CAPTURE %s error=%d" % [label,error])
