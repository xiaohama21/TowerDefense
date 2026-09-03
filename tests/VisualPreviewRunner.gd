extends Node

## Visual preview harness for the playable Stage 0 build.
## Loads Main.tscn, deploys the initial squad, opens wave 1 and spawns a few
## enemies so movie/screenshot captures show the actual game state.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		push_error("Main.tscn 无法加载")
		get_tree().quit(1)
		return
	var main := packed.instantiate()
	add_child(main)
	await get_tree().process_frame

	var build_manager := main.get_node("BuildManager")
	var wave_manager := main.get_node("WaveManager")
	var enemy_manager := main.get_node("EnemyManager")

	var guan_yu := load("res://resources/characters/guan_yu.tres") as CharacterData
	var liu_bei := load("res://resources/characters/liu_bei.tres") as CharacterData
	GameManager.gold = 9999
	var placed := 0
	for row in range(3, GridBackground.ROWS):
		for col in range(GridBackground.COLS):
			var cell := Vector2i(col, row)
			if build_manager._road_cells.has(cell) or build_manager._forbidden_cells.has(cell):
				continue
			if build_manager._is_cell_occupied(cell):
				continue
			var character := guan_yu if placed == 0 else liu_bei
			if character != null and build_manager.begin_drag(character):
				build_manager._update_drag_at(build_manager.cell_center(cell))
				build_manager.release_drag()
				placed += 1
			if placed >= 2:
				break
		if placed >= 2:
			break
	await get_tree().process_frame

	wave_manager.start_wave(0)
	var soldier := load("res://resources/enemies/yellow_turban/yellow_turban_soldier.tres") as EnemyData
	var cavalry := load("res://resources/enemies/yellow_turban/yellow_turban_cavalry.tres") as EnemyData
	if soldier != null:
		enemy_manager.spawn_enemy_from_data(soldier)
	if cavalry != null:
		enemy_manager.spawn_enemy_from_data(cavalry)
