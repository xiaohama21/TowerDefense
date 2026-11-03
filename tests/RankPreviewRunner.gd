extends Node

## Windowed 0.9.1 visual acceptance; isolated profile and viewport captures.
## Godot --path . res://tests/RankPreviewRunner.tscn
var _slot := ""
var _capture_dir := "res://build/verify_0.9.1"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	_slot = "user://.rank_preview_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	for id in GameFlow.get_all_character_ids():
		profile.unlock_character(id)
		profile.add_character_exp(id, LevelCurve.exp_total_for_level(40))
	for id in CharacterRank.MATERIALS + ["skill_book"]:
		profile.add_item(id, 100)
	profile.exp_pool = 10000
	profile.characters["zhang_fei"]["rank"] = 1
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._show_panel(&"develop")
	var develop = hub._panels[&"develop"]
	develop._select_character("zhang_fei")
	develop._refresh()
	develop._tab_container.current_tab = 1
	await _shot("develop_rank")
	develop._tab_container.current_tab = 0
	await _shot("develop_skills")
	develop._tab_container.current_tab = 2
	await _shot("develop_relic")
	hub._show_panel(&"inventory")
	await _shot("inventory_materials")
	hub._show_panel(&"map")
	hub._panels[&"map"]._select_stage(GameFlow.load_stage_data(&"ch01_s08"))
	await _shot("map_s08")
	hub._show_panel(&"encyclopedia")
	var enc = hub._panels[&"encyclopedia"]
	enc._select_character("zhang_fei")
	enc._sim_level = 100
	enc._sim_rank_option.select(5)
	enc._on_sim_changed()
	await _shot("encyclopedia_rank")
	enc._select_character("zhuge_liang")
	enc._on_sim_changed()
	await _shot("encyclopedia_magic")
	hub.queue_free()
	await get_tree().process_frame
	GameFlow.squad_character_ids = ["liu_bei", "guan_yu", "zhang_fei", "huang_zhong"]
	var squad := (load("res://scenes/SquadSelect.tscn") as PackedScene).instantiate()
	add_child(squad)
	await _shot("squad_rank")
	squad.queue_free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("RANK_PREVIEW_OK")
	get_tree().quit()

func _shot(label: String) -> void:
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	var error := get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(label + ".png"))
	print("CAPTURE %s error=%d" % [label, error])
