extends Node2D

signal tower_built(slot: Node)
signal build_failed(slot: Node, reason: String)

@export var tower_manager_path: NodePath = NodePath("../TowerManager")
@export var ui_path: NodePath = NodePath("../UI")

var selected_character: CharacterData = null

## 待确认建造位（防误建）：首次点击高亮待确认，再次点击同一位置确认建造；
## 右键/ESC/切换武将取消。
var pending_slot: Node = null
var pending_loadout: Dictionary = {}

@onready var tower_manager: Node = get_node(tower_manager_path)
@onready var ui: Node = get_node_or_null(ui_path)


func _ready() -> void:
	call_deferred("_connect_build_slots")
	get_tree().node_added.connect(_on_node_added)


func _unhandled_input(event: InputEvent) -> void:
	if pending_slot == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_pending()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel_pending()
		get_viewport().set_input_as_handled()


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
	if selected_character == null:
		_show_feedback("请先选择出战武将")
		build_failed.emit(slot, "no_character")
		return

	# 两次点击确认：第一次高亮待确认，第二次同一位置确认建造。
	if pending_slot == slot:
		_confirm_build(slot)
		return

	var profile := ProfileStore.get_profile()
	pending_loadout = GameFlow.get_battle_loadout(profile, str(selected_character.character_id))
	_clear_pending_visual()
	pending_slot = slot
	if slot.has_method("set_pending"):
		slot.set_pending(true)
	_show_feedback("再次点击确认建造（右键取消）")


func _confirm_build(slot: Node) -> void:
	var profile := ProfileStore.get_profile()
	pending_loadout = GameFlow.get_battle_loadout(profile, str(selected_character.character_id))
	if tower_manager.build_tower(slot.global_position, selected_character, slot, pending_loadout):
		if slot.has_method("mark_built"):
			slot.mark_built()
		_clear_pending_visual()
		pending_slot = null
		tower_built.emit(slot)
		_show_feedback("建造完成")
	else:
		_clear_pending_visual()
		pending_slot = null
		build_failed.emit(slot, "not_enough_gold")
		_show_feedback("金币不足")


func cancel_pending() -> void:
	_clear_pending_visual()
	pending_slot = null


func _clear_pending_visual() -> void:
	if pending_slot != null and is_instance_valid(pending_slot) and pending_slot.has_method("set_pending"):
		pending_slot.set_pending(false)


func _show_feedback(message: String) -> void:
	if is_instance_valid(ui) and ui.has_method("show_status"):
		ui.show_status(message)
