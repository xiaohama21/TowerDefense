extends Node

var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("MAP_VISUAL: "+message)

func _ready() -> void:
	ProfileStore.configure_paths("user://.map_visual_tests.json")
	call_deferred("run")

func run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	for id in ["guan_yu","liu_bei"]: profile.unlock_character(id)
	ProfileStore.save_profile(profile)
	GameFlow.squad_character_ids.assign(["guan_yu","liu_bei"])
	GameFlow.clear_squad_relics()
	GameFlow.selected_difficulty = Difficulty.NORMAL
	GameFlow.set_gameplay_flag("skip_dialogue",true)
	GameFlow.set_gameplay_flag("auto_next_wave",false)
	for index in range(1,9):
		var id := StringName("ch01_s%02d" % index)
		GameFlow.selected_stage_id = id
		var stage := GameFlow.load_stage_data(id)
		var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
		add_child(main)
		await get_tree().process_frame
		var grid: GridBackground = main.grid_background
		var primary := GridBackground.derive_road_cells(stage.path_points)
		var expected := {}
		for cell in GridBackground.derive_stage_road_cells(stage): expected[cell] = true
		check(grid._road_set == expected, str(id)+" all original main/fork road cells")
		check(grid.entry_cell == primary.front() and grid.base_cell == primary.back(),str(id)+" main-route landmarks")
		check(main.spawn_marker.position == grid.cell_center(primary.front()) and main.base_marker.position == grid.cell_center(primary.back()),str(id)+" visual and logic landmark positions")
		check(grid.forbidden_cells == stage.forbidden_cells and grid.decor_cells == stage.decor_cells,str(id)+" original layout arrays preserved")
		check(not grid.placement_grid_visible,str(id)+" no idle grid")
		for cell in grid.decor_cells:
			if expected.has(cell) or stage.forbidden_cells.has(cell): check(not grid._decor_visible_at(cell),str(id)+" overlapping decoration hidden")
		check(main.build_manager.begin_drag(GameFlow.load_character_data("liu_bei")),str(id)+" starts real drag")
		check(grid.placement_grid_visible,str(id)+" drag reveals grid")
		for row in range(9):
			for col in range(16):
				var cell := Vector2i(col,row)
				check(main.build_manager.can_build_at(cell) == (not expected.has(cell) and not stage.forbidden_cells.has(cell)),str(id)+" unchanged build rule "+str(cell))
		main.build_manager.cancel_drag()
		check(not grid.placement_grid_visible,str(id)+" cancel hides grid")
		seed(83019); var expected_random := randf(); seed(83019)
		grid.queue_redraw()
		await get_tree().process_frame
		check(is_equal_approx(randf(),expected_random),str(id)+" map redraw preserves combat RNG")
		for key in GridBackground.MAP_TEXTURES:
			check(grid._camp_textures.has(key) and grid._camp_textures[key].get_size() == Vector2(160,160),str(id)+" map texture "+key)
		grid._camp_textures.clear(); grid._decor_textures.clear(); grid.queue_redraw()
		await get_tree().process_frame
		check(grid._road_set == expected and grid.base_cell == primary.back(),str(id)+" missing art retains complete geometry")
		main.queue_free()
		await get_tree().process_frame
	var editor = preload("res://addons/map_editor/map_editor_window.gd").new()
	add_child(editor)
	var last := GameFlow.load_stage_data(&"ch01_s08")
	editor._stage = last
	editor._path_cells.assign(GridBackground.derive_road_cells(last.path_points))
	editor._refresh_from_stage()
	check(editor._grid.base_cell == Vector2i(15,4),"editor uses main-route base")
	check(editor._grid._road_set.has(Vector2i(0,7)),"editor includes visible reinforcement route")
	check(editor._grid.placement_grid_visible,"editor grid stays visible")
	editor.queue_free()
	await get_tree().process_frame
	print("MAP_VISUAL_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
