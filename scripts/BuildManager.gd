extends Node2D

signal tower_built(slot: Node)
signal build_failed(slot: Node, reason: String)
signal build_preview_requested(slot: Node, character: CharacterData)
signal build_cancelled

@export var tower_manager_path: NodePath = NodePath("../TowerManager")
@export var ui_path: NodePath = NodePath("../UI")

## The character to place when a build slot is clicked. Set by the stage
## controller (Main) when the player picks a hero from the build bar.
var selected_character: CharacterData = null

## 待确认建造位（v0.12.2 防误建）：首次点击进入待确认，底部面板确认后才
## 真正建造；右键/取消按钮/切换武将/选中已建塔均可取消。
var pending_slot: Node = null

@onready var tower_manager: Node = get_node(tower_manager_path)
@onready var ui: Node = get_node_or_null(ui_path)


func _ready() -> void:
	# BuildSlot 在各自 _ready() 中加入分组，因此延后一帧统一接线。
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
	if selected_character == null:
		_show_feedback("请先选择出战武将")
		build_failed.emit(slot, "no_character")
		return
	if pending_slot == slot:
		return

	_set_pending_slot(slot)


## 进入待确认：建造位高亮 + 底部确认面板，等待玩家确认或取消。
func _set_pending_slot(slot: Node) -> void:
	_clear_pending_visual()
	pending_slot = slot
	if slot.has_method("set_pending"):
		slot.set_pending(true)
	build_preview_requested.emit(slot, selected_character)


func cancel_pending() -> void:
	var had_pending := pending_slot != null
	_clear_pending_visual()
	pending_slot = null
	if had_pending:
		build_cancelled.emit()


## 确认建造（底部面板触发）。返回是否成功；金币不足时保持待确认并给出反馈。
func confirm_pending_build() -> bool:
	var slot := pending_slot
	if slot == null or not is_instance_valid(slot):
		return false
	var occupied_value = slot.get("occupied")
	if occupied_value is bool and occupied_value:
		cancel_pending()
		return false
	if tower_manager.build_tower(slot.global_position, selected_character, slot):
		if slot.has_method("mark_built"):
			slot.mark_built()
		_clear_pending_visual()
		pending_slot = null
		tower_built.emit(slot)
		_show_feedback("建造完成")
		return true
	build_failed.emit(slot, "not_enough_gold")
	_show_feedback("金币不足")
	return false


func _clear_pending_visual() -> void:
	if pending_slot != null and is_instance_valid(pending_slot) and pending_slot.has_method("set_pending"):
		pending_slot.set_pending(false)


func _show_feedback(message: String) -> void:
	if is_instance_valid(ui) and ui.has_method("show_status"):
		ui.show_status(message)
