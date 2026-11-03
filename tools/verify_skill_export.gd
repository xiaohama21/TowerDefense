extends SceneTree

## Editor executable: --main-pack <release EXE> --script <absolute file>
## User args: --release-extension=<absolute .gdextension selecting shipped DLL>.
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
	_check(ProjectSettings.get_setting("application/config/version") == "0.9.2.0", "project version 0.9.2.0")
	var flow = root.get_node("GameFlow")
	var store = root.get_node("ProfileStore")
	store.configure_paths("user://.skill_export_%d.json" % Time.get_ticks_usec())
	_check(flow.start_new_game(), "isolated new profile")
	var profile = store.get_profile()
	_check(profile.to_dict().schema_version == 8, "schema v8")
	_check(flow.get_all_character_ids().size() == 9, "nine characters")
	for id in flow.get_all_character_ids():
		var character = flow.load_character_data(id)
		_check(character != null and character.get_skill_ids().size() == 3, "three skills " + str(id))
	profile.unlock_character("guan_yu")
	profile.add_item("skill_book", 10)
	var hub = load("res://scenes/GameHub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub._show_panel(&"develop")
	var panel = hub._panels[&"develop"]
	panel._select_character("guan_yu")
	_check(panel._skill_tab.find_children("SkillCard_*", "PanelContainer", true, false).size() == 3, "three skill cards")
	panel._upgrade_skill("guan_yu", &"char_green_dragon", 1)
	_check(profile.get_skill_level("guan_yu", &"char_green_dragon") == 2 and int(profile.items.skill_book) == 9, "packaged skill upgrade")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/icons/v2/manifest.json"))
	var count := 0
	for entry in manifest.icons:
		if load("res://assets/ui/icons/v2/" + str(entry.png)) != null: count += 1
	_check(count == 273, "273 packaged icons")
	_check(not ResourceLoader.exists("res://assets/ui/icons/star.png"), "legacy icons excluded")
	_check(not ResourceLoader.exists("res://tests/SkillKitRunner.tscn") and not FileAccess.file_exists("res://AGENTS.md"), "development files excluded")
	hub.queue_free()
	await process_frame
	flow.selected_stage_id = &"ch01_s01"
	var squad: Array[String] = ["liu_bei", "guan_yu"]
	flow.squad_character_ids = squad
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.ui.skip_dialogue()
	var tower = main.tower_manager.build_tower(Vector2(240, 200), flow.load_character_data("guan_yu"), null, flow.get_battle_loadout(profile, "guan_yu"))
	_check(tower != null and tower.get_skill_level(&"char_green_dragon") == 2, "battle uses upgraded skill")
	main._try_start_wave()
	await create_timer(2.0).timeout
	_check(root.get_node("GameManager").is_wave_active and main.enemy_manager.get_alive_enemies().size() > 0, "first wave starts")
	main.queue_free()
	await process_frame
	print("PACKAGE_VERIFY_" + ("FAIL" if failed else "OK"))
	quit(1 if failed else 0)
