extends Node2D

@export var tower_cost: int = 50

var tower_scene = preload("res://scenes/Tower.tscn")


## Build a tower for the given character. Character data drives both the cost
## and the tower's combat stats.
func build_tower(pos: Vector2, character_data: CharacterData = null) -> bool:
	var cost := character_data.build_cost if character_data != null else tower_cost
	if GameManager.gold < cost:
		return false
	
	GameManager.gold -= cost
	var tower := tower_scene.instantiate() as Tower
	add_child(tower)
	tower.global_position = pos
	if character_data != null:
		tower.apply_character(character_data)
	return true
