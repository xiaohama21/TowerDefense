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
	var slots := get_tree().get_nodes_in_group("build_slots")

	var guan_yu := load("res://resources/characters/guan_yu.tres") as CharacterData
	var liu_bei := load("res://resources/characters/liu_bei.tres") as CharacterData
	if guan_yu != null and slots.size() >= 2:
		build_manager.selected_character = guan_yu
		build_manager._on_build_requested(slots[0])
		GameManager.gold = 9999
		build_manager.selected_character = liu_bei
		build_manager._on_build_requested(slots[1])
	await get_tree().process_frame

	wave_manager.start_wave(0)
	var soldier := load("res://resources/enemies/yellow_turban/yellow_turban_soldier.tres") as EnemyData
	var cavalry := load("res://resources/enemies/yellow_turban/yellow_turban_cavalry.tres") as EnemyData
	if soldier != null:
		enemy_manager.spawn_enemy_from_data(soldier)
	if cavalry != null:
		enemy_manager.spawn_enemy_from_data(cavalry)
