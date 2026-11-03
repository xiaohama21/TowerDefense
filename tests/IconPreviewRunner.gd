extends Node

var slot := ""
const CAPTURE := "res://docs/ui_concept/runtime_0.9.1.1/"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	slot = "user://.icons_preview_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(slot)
	call_deferred("_run")

func _run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	for id in GameFlow.get_all_character_ids():
		profile.unlock_character(id)
		profile.add_character_exp(id, LevelCurve.exp_total_for_level(40))
	for id in ["general_seal", "refined_iron", "ebony", "skill_book", "iron_shield", "scout_eye", "war_drums", "wolf_tooth", "provision_bag"]:
		profile.add_item(id, 100)
	profile.add_military_merit(5000)
	for id in ["stone_volley", "reward_army"]:
		var supply := load("res://resources/battle_supplies/%s.tres" % id) as BattleSupplyData
		profile.unlock_supply(id, supply.merit_unlock_cost)
	profile.set_supply_loadout(["fire_attack", "war_drum"], 2)
	profile.add_relic("relic_tiangong_leizhao")
	profile.add_relic("relic_taiping_yaoshu")
	profile.exp_pool = 10000
	profile.characters["zhang_fei"]["rank"] = 1
	var menu := (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _shot("main_menu")
	menu.queue_free()
	await get_tree().process_frame
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	for panel_id in [&"map", &"supply", &"inventory", &"tech", &"develop", &"encyclopedia", &"settings"]:
		hub._show_panel(panel_id)
		if panel_id == &"develop":
			var panel = hub._panels[panel_id]
			panel._select_character("zhang_fei")
			panel._refresh()
			panel._tab_container.current_tab = 0
		if panel_id == &"encyclopedia":
			hub._panels[panel_id]._select_character("zhuge_liang")
		await _shot(str(panel_id))
		if panel_id == &"develop":
			for tab in [1, 2]:
				hub._panels[panel_id]._tab_container.current_tab = tab
				await _shot("develop_" + ("rank" if tab == 1 else "relic"))
		if panel_id == &"encyclopedia":
			for tab in [1, 2]:
				hub._panels[panel_id]._tab_container.current_tab = tab
				await _shot("encyclopedia_" + ("skills" if tab == 1 else "relics"))
	hub.queue_free()
	await get_tree().process_frame
	GameFlow.squad_character_ids = ["liu_bei", "guan_yu", "zhang_fei", "huang_zhong"]
	GameFlow.squad_relic_ids = ["iron_shield", "war_drums"]
	var squad := (load("res://scenes/SquadSelect.tscn") as PackedScene).instantiate()
	add_child(squad)
	await _shot("squad")
	squad.queue_free()
	await get_tree().process_frame
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.ui.skip_dialogue()
	await _shot("battle")
	main._on_battle_supply_pressed()
	await _shot("battle_supply")
	main.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(slot + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(slot + suffix))
	print("ICONS_PREVIEW_OK")
	get_tree().quit()

func _shot(label: String) -> void:
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE))
	var code := get_viewport().get_texture().get_image().save_png(CAPTURE + label + ".png")
	print("ICONS_CAPTURE %s error=%d" % [label, code])
