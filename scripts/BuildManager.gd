extends Node2D

signal tower_built(slot: Node)
signal build_failed(slot: Node, reason: String)

@export var tower_manager_path: NodePath = NodePath("../TowerManager")
@export var ui_path: NodePath = NodePath("../UI")

## The character to place when a build slot is clicked. Set by the stage
## controller (Main) when the player picks a hero from the build bar.
var selected_character: CharacterData = null

@onready var tower_manager: Node = get_node(tower_manager_path)
@onready var ui: Node = get_node_or_null(ui_path)


func _ready() -> void:
	# BuildSlot 在各自 _ready() 中加入分组，因此延后一帧统一接线。
	call_deferred("_connect_build_slots")
	get_tree().node_added.connect(_on_node_added)


func _connect_build_slots() -> void:
	for slot in get_tree().get_nodes_in_group("build_slots"):
		_connect_slot(slot)


func _connect_slot(slot: Node) -> void:
	if not is_instance_valid(slot):
		return
	if not slot.has_signal("build_requested"):
		return

	var callback := Callable(self, "_on_build_requested")
	if not slot.is_connected("build_requested", callback):
		slot.connect("build_requested", callback)


func _on_node_added(node: Node) -> void:
	# 兼容运行时生成或切换关卡后出现的新建造位。
	if node.has_signal("build_requested"):
		call_deferred("_connect_slot", node)


func _on_build_requested(slot: Node) -> void:
	if not is_instance_valid(slot):
		return
	if GameManager.lives <= 0 or GameManager.current_wave >= GameManager.total_waves:
		_show_feedback("本局已经结束")
		build_failed.emit(slot, "game_finished")
		return

	var occupied_value = slot.get("occupied")
	if occupied_value is bool and occupied_value:
		_show_feedback("该建造位已经有防御塔")
		build_failed.emit(slot, "occupied")
		return

	if tower_manager.build_tower(slot.global_position, selected_character):
		if slot.has_method("mark_built"):
			slot.mark_built()
		tower_built.emit(slot)
		_show_feedback("建造完成")
	else:
		build_failed.emit(slot, "not_enough_gold")
		_show_feedback("金币不足")


func _show_feedback(message: String) -> void:
	if is_instance_valid(ui) and ui.has_method("show_status"):
		ui.show_status(message)
