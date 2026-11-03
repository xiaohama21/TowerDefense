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
	_check(ProjectSettings.get_setting("application/config/version") == "0.9.3.0", "project version 0.9.3.0")
	var flow = root.get_node("GameFlow")
	var store = root.get_node("ProfileStore")
	var registry = load("res://scripts/data/WeaponRegistry.gd")
	store.configure_paths("user://.gear_export_%d.json" % Time.get_ticks_usec())
	_check(flow.start_new_game(), "isolated new profile")
	var profile = store.get_profile()
	_check(profile.to_dict().schema_version == 9, "schema v9")
	_check(flow.get_all_character_ids().size() == 9, "nine three-skill characters retained")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/icons/v2/manifest.json"))
	var count := 0
	for entry in manifest.icons:
		if load("res://assets/ui/icons/v2/" + str(entry.png)) != null: count += 1
	_check(count == 273, "273 packaged icons")
	_check(registry.IDS.size() == 12, "12 packaged weapons")
	for id in registry.IDS:
		var weapon = registry.get_weapon(id)
		_check(weapon != null and weapon.is_valid() and weapon.icon != null and weapon.affixes.size() == 2, "weapon resource " + str(id))
		profile.add_weapon(id, 3)
	profile.unlock_character("guan_yu")
	profile.unlock_character("zhuge_liang")
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
	_check(not ResourceLoader.exists("res://tests/GearRunner.tscn") and not FileAccess.file_exists("res://AGENTS.md"), "development files excluded")
	var session = load("res://scripts/services/BattleSession.gd").new("ch01_s08")
	flow.collect_stage_rewards(session, flow.load_stage_data(&"ch01_s08"), true)
	_check(session.pending_weapons.size() == 3, "packaged first clear three weapons")
	var seals: int = int(profile.items.get("general_seal", 0))
	var material_seals: int = int(session.pending_loot.get("general_seal", 0))
	session.mark_victory()
	_check(store.commit_victory(session) and int(profile.items.get("general_seal", 0)) == seals + material_seals + 6, "packaged overflow three weapons to six seals")
	hub.queue_free()
	await process_frame
	flow.selected_stage_id = &"ch01_s01"
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
	main.queue_free()
	await process_frame
	print("PACKAGE_VERIFY_" + ("FAIL" if failed else "OK"))
	quit(1 if failed else 0)
