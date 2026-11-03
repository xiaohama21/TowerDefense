extends Node

var _slot := ""
var _capture_dir := "res://build/verify_0.9.3"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): _capture_dir = argument.trim_prefix("--capture-dir=")
	_slot = "user://.gear_preview_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	for id in GameFlow.get_all_character_ids():
		profile.unlock_character(id)
		profile.add_character_exp(id, LevelCurve.exp_total_for_level(40))
		profile.characters[id]["rank"] = 2
	for id in WeaponRegistry.IDS: profile.add_weapon(id, 3)
	for id in CharacterRank.MATERIALS + ["skill_book"]: profile.add_item(id, 100)
	profile.exp_pool = 10000
	profile.set_character_weapon("liu_bei", "equipment_ring_blade_1")
	profile.set_character_weapon("zhou_wei", "equipment_ring_blade_1")
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._show_panel(&"develop")
	var develop = hub._panels[&"develop"]
	develop._select_character("zhang_fei")
	develop._refresh()
	develop._tab_container.current_tab = 2
	await _shot("develop_empty_and_inventory")
	var card = develop._weapon_tab.find_child("WeaponCard_equipment_ring_blade_1", true, false)
	card.find_child("WeaponAction", true, false).pressed.emit()
	await _shot("develop_equipped")
	card = develop._weapon_tab.find_child("WeaponCard_equipment_ring_blade_1", true, false)
	card.find_child("WeaponAction", true, false).pressed.emit()
	await _shot("develop_unequipped")
	for pair in [["diao_chan", "dancer"], ["huang_fu_song", "catapult"], ["zhuge_liang", "strategist"]]:
		develop._select_character(str(pair[0]))
		develop._refresh()
		await _shot("develop_" + str(pair[1]))
	develop._equip_weapon("huang_fu_song", "equipment_wood_mortar_1")
	develop._select_character("huang_fu_song")
	develop._refresh()
	develop._tab_container.current_tab = 0
	await _shot("skills_with_equipment_amp")
	hub._show_panel(&"inventory")
	var inventory = hub._panels[&"inventory"]
	inventory._category_buttons[-1].button_pressed = true
	inventory._on_category_pressed(ItemData.ItemType.EQUIPMENT)
	inventory._on_card_pressed("equipment_ring_blade_1")
	await _shot("inventory_equipment")
	hub._show_panel(&"map")
	hub._panels[&"map"]._select_stage(GameFlow.load_stage_data(&"ch01_s08"))
	await _shot("map_s08_equipment")
	hub._panels[&"map"]._select_stage(GameFlow.load_stage_data(&"ch01_s07"))
	await _shot("map_s07_equipment")
	hub._show_panel(&"encyclopedia")
	var enc = hub._panels[&"encyclopedia"]
	enc._select_character("zhuge_liang")
	enc._tab_container.current_tab = 2
	await _shot("encyclopedia_weapons")
	var preview_card = enc._weapon_tab.find_child("WeaponCard_equipment_bamboo_banner_1", true, false)
	preview_card.find_child("WeaponAction", true, false).pressed.emit()
	enc._sim_level = 40
	enc._sim_rank_option.select(2)
	enc._set_sim_rank(3)
	await get_tree().process_frame
	var selected_card = enc._weapon_tab.find_child("WeaponCard_equipment_bamboo_banner_1", true, false)
	(enc._weapon_tab.get_parent().get_parent() as ScrollContainer).ensure_control_visible(selected_card)
	await _shot("encyclopedia_weapon_simulation")
	hub.queue_free()
	await get_tree().process_frame
	GameFlow.squad_character_ids = ["liu_bei", "guan_yu", "zhang_fei", "huang_zhong"]
	GameFlow.selected_stage_id = &"ch01_s01"
	GameFlow.selected_difficulty = Difficulty.NORMAL
	var battle := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(battle)
	await get_tree().process_frame
	battle.ui.skip_dialogue()
	var rewards := {"weapons":{"equipment_ring_blade_1":1, "equipment_bone_mace_1":1}, "seals":2}
	battle.ui.show_result({"victory":true, "saved":true, "weapon_rewards":rewards, "remaining_gold":0})
	await _shot("victory_equipment_and_overflow")
	battle.ui.show_result({"victory":false, "saved":false})
	await _shot("defeat_no_equipment")
	battle.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("GEAR_PREVIEW_OK")
	get_tree().quit()

func _shot(label: String) -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	var error := get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(label + ".png"))
	print("CAPTURE %s error=%d" % [label, error])
