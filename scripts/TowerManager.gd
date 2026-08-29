extends Node2D

signal tower_created(tower: Tower)

@export var tower_cost: int = 50

var tower_scene = preload("res://scenes/Tower.tscn")


## Build a tower for the given character. Character data drives both the cost
## and the tower's combat stats. Returns the created tower (null on failure).
func build_tower(pos: Vector2, character_data: CharacterData = null, slot: Node = null) -> Tower:
	var cost := character_data.build_cost if character_data != null else tower_cost
	if GameManager.gold < cost:
		return null

	GameManager.gold -= cost
	var tower := tower_scene.instantiate() as Tower
	add_child(tower)
	tower.global_position = pos
	if character_data != null:
		tower.apply_character(character_data)
	tower.record_build_investment(cost)
	tower.assigned_slot = slot
	tower_created.emit(tower)
	return tower


## 局内升级（GDD 5.4）：伤害 +25%/级，攻速/射程/特性不变；局内临时状态。
func upgrade_tower(tower: Tower, stage_data: StageData) -> bool:
	if tower == null or stage_data == null:
		return false
	if tower.battle_level >= stage_data.max_inbattle_upgrade_level:
		return false
	var cost := tower.get_upgrade_cost(stage_data.upgrade_cost_factor)
	if GameManager.gold < cost:
		return false
	GameManager.gold -= cost
	tower.apply_upgrade(cost)
	return true


## 回收（GDD 5.4）：返还总投入 × 比例，建造槽立即可复用，局内等级与怒气丢弃。
func sell_tower(tower: Tower, stage_data: StageData) -> bool:
	if tower == null:
		return false
	GameManager.gold += tower.get_sell_refund(stage_data.sell_refund_ratio)
	if is_instance_valid(tower.assigned_slot) and tower.assigned_slot.has_method("reset_slot"):
		tower.assigned_slot.reset_slot()
	tower.assigned_slot = null
	tower.queue_free()
	return true
