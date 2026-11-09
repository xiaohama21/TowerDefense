extends Node

var output := "res://build/verify_map_0.9.8.3/after"
var main: Node
var shots: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	ProfileStore.configure_paths("user://.map_visual_preview.json")
	call_deferred("run")

func shot(name: String, drag_at := Vector2(-1,-1)) -> void:
	var paused := get_tree().paused
	get_tree().paused = true
	Input.warp_mouse(Vector2(1270,5) if drag_at.x < 0 else drag_at)
	await get_tree().create_timer(.1,true,false,true).timeout
	if drag_at.x >= 0: main.build_manager._update_drag_at(drag_at)
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(output.path_join(name+".png")) == OK)
	shots.append(name)
	get_tree().paused = paused

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var profile := ProfileStore.create_new_profile(false)
	for id in ["guan_yu","liu_bei"]: profile.unlock_character(id)
	ProfileStore.save_profile(profile)
	GameFlow.squad_character_ids.assign(["guan_yu","liu_bei"])
	GameFlow.clear_squad_relics()
	GameFlow.set_gameplay_flag("skip_dialogue",true)
	GameFlow.set_gameplay_flag("auto_next_wave",false)
	GameFlow.selected_difficulty = Difficulty.NORMAL
	for index in range(1,9):
		GameFlow.selected_stage_id = StringName("ch01_s%02d" % index)
		main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		add_child(main)
		await get_tree().process_frame
		for child in main.ui.get_node("Root").get_children():
			if child.get_script() == load("res://scripts/DebugPanel.gd"): child.visible = false
		# Allow the real entry toast to expire before judging the terrain underneath.
		await get_tree().create_timer(4.15).timeout
		await shot("s%02d_start" % index)
		if index == 1:
			assert(main.build_manager.begin_drag(GameFlow.load_character_data("liu_bei")))
			await shot("s01_drag",Vector2(520,200))
			main.build_manager.cancel_drag()
			for entry in [["guan_yu",Vector2(440,200)],["liu_bei",Vector2(520,200)]]:
				assert(main.build_manager.begin_drag(GameFlow.load_character_data(entry[0])))
				main.build_manager._update_drag_at(entry[1])
				main.build_manager.release_drag()
			main._try_start_wave()
			await get_tree().create_timer(4).timeout
			await shot("s01_battle")
		if index == 4 or index == 7:
			main._try_start_wave()
			await get_tree().create_timer(14.0 if index == 4 else 20.0).timeout
			await shot("s04_split" if index == 4 else "s07_crossing")
		if index == 8:
			main.grid_background._camp_textures.clear()
			main.grid_background._decor_textures.clear()
			main.grid_background.queue_redraw()
			await shot("s08_missing_art")
			for key in GridBackground.MAP_TEXTURES:
				main.grid_background._camp_textures[key] = load("res://assets/battle_visuals/grass_camp/%s.png" % key)
			main.grid_background.queue_redraw()
			# Visual fixture: start the real eleventh wave, without granting prior rewards.
			GameManager.current_wave = 10
			main._try_start_wave()
			await get_tree().create_timer(12).timeout
			await shot("s08_reinforcements")
		main.queue_free()
		await get_tree().process_frame
	var editor = preload("res://addons/map_editor/map_editor_window.gd").new()
	add_child(editor)
	var stage_index: int = editor._stage_paths.find(GameFlow.load_stage_data(&"ch01_s08").resource_path)
	assert(stage_index >= 0)
	editor._stage_option.select(stage_index)
	editor._on_stage_selected(stage_index)
	assert(editor._stage.theme == &"night")
	assert(editor._theme_option.get_item_text(editor._theme_option.selected) == "night")
	editor.show()
	await get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	assert(editor.get_texture().get_image().save_png(output.path_join("editor_s08.png")) == OK)
	shots.append("editor_s08")
	assert(await editor._export_base_map(output.path_join("editor_s08_base.png")) == OK)
	assert(editor._grid.placement_grid_visible)
	shots.append("editor_s08_base")
	editor.queue_free()
	await get_tree().process_frame
	var file := FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"program":ProjectSettings.get_setting("application/config/version"),"screenshots":shots,"fixture":"isolated Lv1 starters, original stage budgets and routes; no balance conclusion"},"\t"))
	file.close()
	print("MAP_PREVIEW_RESULT: PASS screenshots=%d" % shots.size())
	get_tree().quit()
