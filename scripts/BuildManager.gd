extends Node2D

signal tower_built(slot: Node)
signal build_failed(slot: Node, reason: String)

@export var tower_manager_path: NodePath = NodePath("../TowerManager")
@export var ui_path: NodePath = NodePath("../UI")

var selected_character: CharacterData = null

## 自由建造（v0.23.0 拍板，阶段 8 提交 3）：非建造位（空地）均可建造，80px 网格吸附；
## 推荐位降级为软引导（保留原有点击流程）。道路格与禁建格由 Main 注入。
var _road_cells: Dictionary = {}
var _forbidden_cells: Dictionary = {}
var _pending_cell: Vector2i = Vector2i(-1, -1)
var _preview: Polygon2D = null

## 待确认建造位（防误建）：首次点击高亮待确认，再次点击同一位置确认建造；
## 右键/ESC/切换武将取消。
var pending_slot: Node = null
var pending_loadout: Dictionary = {}

@onready var tower_manager: Node = get_node(tower_manager_path)
@onready var ui: Node = get_node_or_null(ui_path)


func _ready() -> void:
	call_deferred("_connect_build_slots")
	get_tree().node_added.connect(_on_node_added)
	_preview = Polygon2D.new()
	_preview.polygon = PackedVector2Array([
		Vector2(-38, -38), Vector2(38, -38), Vector2(38, 38), Vector2(-38, 38),
	])
	_preview.color = Color(0.55, 0.9, 0.6, 0.35)
	_preview.z_index = 5
	_preview.visible = false
	add_child(_preview)


## 自由建造数据注入（Main._ready 调用）：道路格与禁建格集合。
func setup_free_build(road_cells: Array[Vector2i], forbidden_cells: Array[Vector2i]) -> void:
	_road_cells.clear()
	for cell in road_cells:
		_road_cells[cell] = true
	_forbidden_cells.clear()
	for cell in forbidden_cells:
		_forbidden_cells[cell] = true


## 可建格悬停预览（v0.33.2 UX，BUGS B-021）：选中武将后，鼠标扫过可建空地即显示
## 半透明绿色方块，明确"这里能建"；道路/禁建/已占用格不显示（不可建）。
## 与"两次点击确认"的待确认高亮互斥：存在待确认位时不随鼠标移动。
func _update_hover_preview(viewport_pos: Vector2) -> void:
	if _preview == null:
		return
	if selected_character == null or GameManager.lives <= 0 \
			or GameManager.current_wave >= GameManager.total_waves:
		_preview.visible = false
		return
	if pending_slot != null or _pending_cell != Vector2i(-1, -1):
		return
	var cell := Vector2i(
		floori(viewport_pos.x / GridBackground.GRID_SIZE),
		floori(viewport_pos.y / GridBackground.GRID_SIZE)
	)
	if cell.x < 0 or cell.x >= GridBackground.COLS or cell.y < 0 or cell.y >= GridBackground.ROWS:
		_preview.visible = false
		return
	if _road_cells.has(cell) or _forbidden_cells.has(cell) or _is_cell_occupied(cell):
		_preview.visible = false
		return
	_preview.global_position = cell_center(cell)
	_preview.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover_preview((event as InputEventMouseMotion).position)
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_on_map_clicked(mouse_event.position)
			get_viewport().set_input_as_handled()
			return
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


## 空地自由建造（阶段 8 提交 3）：点击非道路/非禁建/未占用的网格，两次点击确认。
func _on_map_clicked(viewport_pos: Vector2) -> void:
	if GameManager.lives <= 0 or GameManager.current_wave >= GameManager.total_waves:
		_show_feedback("本局已经结束")
		return
	if selected_character == null:
		if pending_slot == null and _pending_cell == Vector2i(-1, -1):
			_show_feedback("请先选择出战武将")
		return
	var cell := Vector2i(floori(viewport_pos.x / GridBackground.GRID_SIZE), floori(viewport_pos.y / GridBackground.GRID_SIZE))
	if cell.x < 0 or cell.x >= GridBackground.COLS or cell.y < 0 or cell.y >= GridBackground.ROWS:
		return
	if _road_cells.has(cell):
		_show_feedback("道路格不可建造")
		cancel_pending()
		return
	if _forbidden_cells.has(cell):
		_show_feedback("该地形不可建造")
		cancel_pending()
		return
	if _is_cell_occupied(cell):
		_show_feedback("该位置已有防御塔")
		cancel_pending()
		return
	if _pending_cell == cell:
		_confirm_free_build(cell)
		return
	var profile := ProfileStore.get_profile()
	pending_loadout = GameFlow.get_battle_loadout(profile, str(selected_character.character_id))
	_clear_pending_visual()
	pending_slot = null
	_pending_cell = cell
	_preview.global_position = cell_center(cell)
	_preview.visible = true
	_show_feedback("再次点击确认建造（右键取消）")


func _confirm_free_build(cell: Vector2i) -> void:
	var profile := ProfileStore.get_profile()
	pending_loadout = GameFlow.get_battle_loadout(profile, str(selected_character.character_id))
	var tower: Tower = tower_manager.build_tower(cell_center(cell), selected_character, null, pending_loadout)
	if tower != null:
		tower_built.emit(null)
		_clear_pending_visual()
		_pending_cell = Vector2i(-1, -1)
		_show_feedback("建造完成")
	else:
		_clear_pending_visual()
		_pending_cell = Vector2i(-1, -1)
		_show_feedback("金币不足")


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * GridBackground.GRID_SIZE, cell.y * GridBackground.GRID_SIZE) \
		+ Vector2(GridBackground.GRID_SIZE, GridBackground.GRID_SIZE) * 0.5


func _is_cell_occupied(cell: Vector2i) -> bool:
	for child in tower_manager.get_children():
		var tower := child as Tower
		if tower == null or not is_instance_valid(tower):
			continue
		var tower_cell := Vector2i(
			floori(tower.global_position.x / GridBackground.GRID_SIZE),
			floori(tower.global_position.y / GridBackground.GRID_SIZE)
		)
		if tower_cell == cell:
			return true
	return false


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
	var unlock_callback := Callable(self, "_on_unlock_requested")
	if slot.has_signal("unlock_requested") and not slot.is_connected("unlock_requested", unlock_callback):
		slot.connect("unlock_requested", unlock_callback)


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


## 预锁位解锁（v0.14.1，GDD 5.1）：消耗金币解锁后即可正常建造；本局有效。
func _on_unlock_requested(slot: Node) -> void:
	if not is_instance_valid(slot):
		return
	if GameManager.lives <= 0 or GameManager.current_wave >= GameManager.total_waves:
		_show_feedback("本局已经结束")
		return
	var raw_cost = slot.get("unlock_cost")
	var cost := int(raw_cost) if raw_cost != null else 60
	if GameManager.gold < cost:
		_show_feedback("金币不足，无法解锁建造位（%d）" % cost)
		build_failed.emit(slot, "unlock_not_enough_gold")
		return
	cancel_pending()
	GameManager.gold -= cost
	if slot.has_method("try_unlock"):
		slot.try_unlock()
	_show_feedback("建造位已解锁（- %d 金币）" % cost)


func cancel_pending() -> void:
	_clear_pending_visual()
	pending_slot = null
	_pending_cell = Vector2i(-1, -1)
	if _preview != null:
		_preview.visible = false


func _clear_pending_visual() -> void:
	if pending_slot != null and is_instance_valid(pending_slot) and pending_slot.has_method("set_pending"):
		pending_slot.set_pending(false)
	if _preview != null:
		_preview.visible = false


func _show_feedback(message: String) -> void:
	if is_instance_valid(ui) and ui.has_method("show_status"):
		ui.show_status(message)
