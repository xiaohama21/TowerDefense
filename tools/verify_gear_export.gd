extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("PACKAGE_%s: %s" % ["PASS" if ok else "FAIL", message])
	failed = failed or not ok

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--release-extension=") and not ClassDB.class_exists("SpineSprite"):
			_check(GDExtensionManager.load_extension(arg.trim_prefix("--release-extension=")) == GDExtensionManager.LOAD_STATUS_OK, "load shipped Spine DLL")
	_check(ClassDB.class_exists("SpineSprite"), "Spine runtime")
	_check(ProjectSettings.get_setting("application/config/version") == "0.9.4.2", "project version 0.9.4.2")
	var flow = root.get_node("GameFlow")
	var store = root.get_node("ProfileStore")
	var registry = load("res://scripts/data/WeaponRegistry.gd")
	var skills = load("res://scripts/combat/SkillRegistry.gd")
	var shop = load("res://scripts/data/ShopRegistry.gd")
	store.configure_paths("user://.gear_export_%d.json" % Time.get_ticks_usec())
	_check(flow.start_new_game(), "isolated new profile")
	var profile = store.get_profile()
	_check(profile.to_dict().schema_version == 10, "schema v10")
	_check(profile.ingots == 0 and profile.lord_exp == 0 and profile.shop_state.rotation.size() == 2, "new profile economic defaults")
	_check(shop.all_offers().size() == 31 and shop.exp_for_level(100) == 27225 and shop.data().tier_levels == [1,10,20,40,60,80], "packaged catalog and lord curve")
	var migrated = store._migrate_to_current({"schema_version":9,"military_merit":321,"weapons":{"equipment_long_spear_1":1}})
	_check(migrated.ok and migrated.data.schema_version == 10 and migrated.data.ingots == 0 and migrated.data.lord_exp == 0 and migrated.data.military_merit == 321 and migrated.data.weapons.equipment_long_spear_1 == 1, "packaged v9 migration preserves existing economy and gear")
	_check(flow.get_all_character_ids().size() == 9, "nine three-skill characters retained")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/icons/v2/manifest.json"))
	var count := 0
	for entry in manifest.icons:
		if load("res://assets/ui/icons/v2/" + str(entry.png)) != null: count += 1
	_check(count == 283, "283 packaged icons")
	var theme = load("res://scripts/ui_screens/ui_theme.gd")
	for icon_id in ["ingot", "lord_level", "lord_exp", "equipment_rarity_0", "equipment_rarity_1", "equipment_rarity_2", "equipment_rarity_3", "equipment_rarity_4", "trait_vanguard", "ultimate_death_fight"]:
		_check(theme.hud_icon(icon_id) != null, "packaged economic/quality icon " + icon_id)
	_check(registry.IDS.size() == 12, "12 packaged weapons")
	for id in registry.IDS:
		var weapon = registry.get_weapon(id)
		_check(weapon != null and weapon.is_valid() and weapon.icon != null and weapon.affixes.size() == 2, "weapon resource " + str(id))
		profile.add_weapon(id, 3)
	profile.unlock_character("guan_yu")
	profile.unlock_character("zhuge_liang")
	for id in flow.get_all_character_ids(): profile.unlock_character(id)
	var hub = load("res://scenes/GameHub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub._show_panel(&"develop")
	var panel = hub._panels[&"develop"]
	panel._select_character("guan_yu")
	panel._refresh()
	_check(panel._tab_container.get_tab_count() == 4 and panel._weapon_tab.find_children("WeaponCard_*", "Button", true, false).size() == 2, "packaged equipment UI")
	_check(panel._equip_weapon("guan_yu", "equipment_long_spear_1") and profile.get_character_weapon_id("guan_yu") == "equipment_long_spear_1", "packaged equip and save")
	_check(not profile.set_character_weapon("zhuge_liang", "equipment_long_spear_1"), "packaged profession restriction")
	hub._show_panel(&"encyclopedia")
	var enc = hub._panels[&"encyclopedia"]
	enc._select_character("zhuge_liang")
	var snapshot = profile.to_dict()
	enc._sim_weapon_id = "equipment_bamboo_banner_1"
	enc._on_sim_changed()
	await process_frame
	_check(profile.to_dict() == snapshot and enc._weapon_tab.find_children("WeaponCard_*", "Button", true, false).size() == 2, "packaged read-only weapon preview")
	for id in flow.get_all_character_ids():
		panel._select_character(id)
		panel._refresh()
		_check_skill_cards(panel, flow.load_character_data(id), skills, "develop")
	var skill_snapshot = profile.to_dict()
	for id in flow.get_all_character_ids():
		enc._select_character(id)
		enc._sim_rank_option.select(5)
		enc._on_sim_changed()
		_check_skill_cards(enc, flow.load_character_data(id), skills, "encyclopedia")
	_check(profile.to_dict() == skill_snapshot, "skill encyclopedia leaves profile unchanged")
	profile.ingots = 500
	profile.military_merit = 500
	_check(store.save_profile(profile), "packaged shop fixture saved")
	hub._show_panel(&"shop")
	var shop_panel = hub._panels[&"shop"]
	await process_frame
	_check(hub._buttons.size() == 8 and shop_panel.find_child("LordLevel",true,false).text == "Lv.1" and shop_panel.find_children("ShopOffer_*","PanelContainer",true,false).size() == 21, "packaged shop navigation and initial shelves")
	var economic_snapshot = profile.to_dict()
	store._writes_blocked = true
	_check(not store.buy_shop_offer("iron_1",int(profile.shop_state.revision)) and not store.refresh_shop(int(profile.shop_state.revision)) and profile.to_dict() == economic_snapshot, "packaged failed saves roll back purchase and refresh")
	store._writes_blocked = false
	var iron_before: int = int(profile.items.get("refined_iron",0))
	shop_panel.find_child("ShopOffer_iron_1",true,false).find_child("BuyOffer",true,false).pressed.emit()
	_check(profile.ingots == 492 and int(profile.items.refined_iron) == iron_before + 1 and shop_panel.find_child("IngotBalance",true,false).text == "492", "packaged material purchase button and balance")
	economic_snapshot = profile.to_dict()
	_check(not store.buy_shop_offer("iron_1",0) and profile.to_dict() == economic_snapshot, "packaged stale click rejected")
	shop_panel.find_child("RefreshShop",true,false).pressed.emit()
	_check(profile.ingots == 482 and profile.shop_state.refresh_step == 1 and shop.refresh_price(profile) == 20 and profile.shop_state.rotation.size() == 2, "packaged refresh button and next price")
	economic_snapshot = profile.to_dict()
	shop_panel._switch_page(1)
	_check(profile.to_dict() == economic_snapshot, "packaged page switching keeps rotation")
	shop_panel.find_child("ShopOffer_merit_iron_shield",true,false).find_child("BuyOffer",true,false).pressed.emit()
	_check(profile.military_merit == 260 and profile.ingots == 482 and int(profile.items.iron_shield) == 1, "packaged merit purchase uses separate currency")
	economic_snapshot = profile.to_dict()
	_check(not store.buy_shop_offer("merit_iron_shield",int(profile.shop_state.revision)) and profile.to_dict() == economic_snapshot, "packaged relic permanent limit")
	profile.mark_stage_completed("ch01_s01",{"difficulty":"normal"})
	economic_snapshot = profile.to_dict()
	_check(not store.buy_shop_offer("equipment_ring_blade_1",int(profile.shop_state.revision)) and profile.to_dict() == economic_snapshot, "packaged full equipment rejects deduction")
	profile.weapons.equipment_ring_blade_1 = 2
	_check(store.buy_shop_offer("equipment_ring_blade_1",int(profile.shop_state.revision)) and profile.weapon_count("equipment_ring_blade_1") == 3 and profile.ingots == 362, "packaged equipment purchase")
	hub._show_panel(&"inventory")
	var inventory = hub._panels[&"inventory"]
	inventory._show_detail("iron_shield")
	_check(inventory.find_child("ShopAcquisition",true,false).text.contains("兑换"), "packaged inventory shop source")
	profile.lord_exp = 440
	flow.selected_difficulty = 0
	_check(not ResourceLoader.exists("res://tests/GearRunner.tscn") and not FileAccess.file_exists("res://AGENTS.md"), "development files excluded")
	var session = load("res://scripts/services/BattleSession.gd").new("ch01_s08")
	flow.collect_stage_rewards(session, flow.load_stage_data(&"ch01_s08"), true)
	_check(session.pending_weapons.size() == 3, "packaged first clear three weapons")
	_check(session.get_pending_ingots() == 30 and session.get_pending_lord_exp() == 80, "packaged first-clear economic rewards")
	var seals: int = int(profile.items.get("general_seal", 0))
	var material_seals: int = int(session.pending_loot.get("general_seal", 0))
	session.mark_victory()
	_check(store.commit_victory(session) and int(profile.items.get("general_seal", 0)) == seals + material_seals + 6, "packaged overflow three weapons to six seals")
	_check(profile.ingots == 392 and profile.lord_exp == 520 and shop.lord_progress(profile.lord_exp).level == 10 and profile.shop_state.refresh_step == 0 and profile.shop_state.rotation.size() == 3 and (profile.shop_state.rotation.has("rot_book_2") or profile.shop_state.rotation.has("rot_seal_3")), "packaged victory level-up and new-tier guaranteed rotation")
	economic_snapshot = profile.to_dict()
	_check(store.commit_victory(session) and profile.to_dict() == economic_snapshot, "packaged duplicate victory keeps economy and rotation")
	hub._show_panel(&"map")
	var map = hub._panels[&"map"]
	map._select_stage(flow.load_stage_data(&"ch01_s01"))
	map._on_difficulty_changed(true,1)
	_check(map._detail_rewards.get_child(0).get_child(1).text == "+20" and map._detail_rewards.get_child(1).get_child(1).text == "+38", "packaged map hard repeat economy preview")
	hub.queue_free()
	await process_frame
	flow.selected_stage_id = &"ch01_s01"
	flow.selected_difficulty = 0
	var squad: Array[String] = ["liu_bei", "guan_yu"]
	flow.squad_character_ids = squad
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.ui.skip_dialogue()
	var character = flow.load_character_data("guan_yu")
	var tower = main.tower_manager.build_tower(Vector2(240, 200), character, null, flow.get_battle_loadout(profile, "guan_yu"))
	_check(tower != null and tower.damage == character.base_damage + 6 and absf(tower.crit_rate - 0.09) < 0.001, "packaged battle uses weapon attack and crit")
	main._try_start_wave()
	await create_timer(2.0).timeout
	_check(root.get_node("GameManager").is_wave_active and main.enemy_manager.get_alive_enemies().size() > 0, "first wave starts")
	var ingots_before: int = profile.ingots
	var exp_before: int = profile.lord_exp
	main._on_victory()
	_check(profile.ingots == ingots_before + 10 and profile.lord_exp == exp_before + 25 and main.ui._result_reward_icons.get_child(0).get_child(1).text == "×10" and main.ui._result_reward_icons.get_child(1).get_child(1).text == "×25" and main.ui._result_lines_label.text.contains("升级！"), "packaged battle victory saves economy and displays level-up")
	main.ui.show_result({"victory":true,"saved":false,"economy":{"ingots":30,"lord_exp":80},"lord_before":1,"lord_after":2})
	_check(main.ui._result_reward_icons.get_child_count() == 0 and not main.ui._result_lines_label.text.contains("升级！"), "packaged failed settlement hides economic rewards and level-up")
	paused = false
	main.queue_free()
	await process_frame
	print("PACKAGE_VERIFY_" + ("FAIL" if failed else "OK"))
	quit(1 if failed else 0)

func _check_skill_cards(panel, character, skills, context: String) -> void:
	for id in character.get_skill_ids():
		var card = panel._skill_tab.find_child("SkillCard_" + str(id), true, false)
		var title = card.find_child("SkillName", true, false) if card != null else null
		var description = card.find_child("SkillDescription", true, false) if card != null else null
		var readable: bool = title != null and description != null and title.text == skills.get_skill_name(id) and description.text == skills.description_text(id) and not description.text.is_empty()
		var labels: Array[String] = []
		if card != null:
			var main_icon = card.get_child(0).get_child(0).get_child(0)
			readable = readable and main_icon is TextureRect and main_icon.texture != null and main_icon.tooltip_text == skills.get_skill_name(id)
			for label in card.find_children("*", "Label", true, false): labels.append(label.text)
		for row in skills.effect_rows(character, id, 1, 0.0):
			for entry in row:
				readable = readable and entry.size() == 4 and labels.has(str(entry[3]))
		_check(readable, "%s skill name, description and effect labels: %s" % [context, id])
