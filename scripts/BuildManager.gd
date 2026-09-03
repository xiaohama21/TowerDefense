extends Node2D

## 建造成功（拖拽松手直建，与旧点击路径同一 build_tower 链路）。
signal tower_built(character_id: String)
## 拖拽结束（放置= true / 取消= false），UI 据此复位卡片按下高亮。
signal drag_finished(placed: bool)

## 拖拽建造（v0.33.3 定稿，UI_LAYOUT.md §9）：唯一建造方式——按住顶部武将卡片
## 拖出，角色虚影 + 攻击范围圈 + 落点格绿/红提示跟随鼠标，松手在可建格直接建造；
## 右键 / ESC / 原地松手 / 拖入 UI 区松手均取消。点击建造、两次点击确认、绿色 +
## 推荐位、预锁位解锁与 hover 可建预览（B-021）已随 v0.33.3 全部移除。

@export var tower_manager_path: NodePath = NodePath("../TowerManager")
@export var ui_path: NodePath = NodePath("../UI")

const TOWER_SCENE: PackedScene = preload("res://scenes/Tower.tscn")
## 拖拽覆盖层高度：位于战斗 UI（layer 1）之上、军需（50）/设置（60）之下。
const DRAG_OVERLAY_LAYER: int = 40

## 落点格提示色：可建=绿、不可建=红。
const VALID_TINT := Color(0.35, 0.95, 0.5, 0.30)
const INVALID_TINT := Color(0.95, 0.32, 0.28, 0.30)
const GHOST_MODULATE_VALID := Color(1.0, 1.0, 1.0, 0.55)
const GHOST_MODULATE_INVALID := Color(1.0, 0.42, 0.36, 0.6)

var _road_cells: Dictionary = {}
var _forbidden_cells: Dictionary = {}

## 拖拽状态机（UI 卡片 button_down → Main → begin_drag 激活）。
var _drag_active: bool = false
var _drag_character: CharacterData = null
var _drag_loadout: Dictionary = {}
var _drag_cell: Vector2i = Vector2i(-1, -1)
var _drag_valid: bool = false
var _drag_over_ui: bool = false

var _drag_layer: CanvasLayer = null
var _catcher: Control = null
var _ghost_root: Node2D = null
var _cell_tint: Polygon2D = null
var _ghost: Tower = null

@onready var tower_manager: Node = get_node(tower_manager_path)
@onready var ui: Node = get_node_or_null(ui_path)


func _ready() -> void:
	_drag_layer = CanvasLayer.new()
	_drag_layer.layer = DRAG_OVERLAY_LAYER
	add_child(_drag_layer)

	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.visible = false
	_catcher.gui_input.connect(_on_catcher_gui_input)
	_drag_layer.add_child(_catcher)

	_ghost_root = Node2D.new()
	_drag_layer.add_child(_ghost_root)

	_cell_tint = Polygon2D.new()
	_cell_tint.polygon = PackedVector2Array([
		Vector2(-38, -38), Vector2(38, -38), Vector2(38, 38), Vector2(-38, 38),
	])
	_cell_tint.visible = false
	_cell_tint.z_index = -1
	_ghost_root.add_child(_cell_tint)


## 可建判定数据注入（Main._ready 调用）：道路格与禁建格集合。
func setup_free_build(road_cells: Array[Vector2i], forbidden_cells: Array[Vector2i]) -> void:
	_road_cells.clear()
	for cell in road_cells:
		_road_cells[cell] = true
	_forbidden_cells.clear()
	for cell in forbidden_cells:
		_forbidden_cells[cell] = true


## 拖拽开始（UI 卡片 button_down → Main → 本方法）：校验战局/金币后激活覆盖层。
func begin_drag(character_data: CharacterData) -> bool:
	if _drag_active:
		return false
	if character_data == null:
		return false
	if GameManager.lives <= 0 or GameManager.current_wave >= GameManager.total_waves:
		_show_feedback("本局已经结束")
		return false
	if GameManager.gold < character_data.build_cost:
		_show_feedback("金币不足")
		return false
	if get_tree().paused:
		return false
	_drag_character = character_data
	_drag_loadout = GameFlow.get_battle_loadout(ProfileStore.get_profile(), str(character_data.character_id))
	_drag_active = true
	_drag_cell = Vector2i(-1, -1)
	_drag_valid = false
	_drag_over_ui = false
	_ensure_ghost()
	_catcher.visible = true
	_update_drag_at(get_viewport().get_mouse_position())
	return true


## 拖拽中每帧跟随鼠标（暂停/战局结束路径由 Main 先取消拖拽）。
func _process(_delta: float) -> void:
	if _drag_active:
		_update_drag_at(get_viewport().get_mouse_position())


func is_dragging() -> bool:
	return _drag_active


## 落点可建判定（测试/松手建造共用）：界内、非道路/禁建/已占用且金币足够。
func can_build_at(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= GridBackground.COLS or cell.y < 0 or cell.y >= GridBackground.ROWS:
		return false
	if _road_cells.has(cell) or _forbidden_cells.has(cell) or _is_cell_occupied(cell):
		return false
	if _drag_character == null or GameManager.gold < _drag_character.build_cost:
		return false
	return true


## 按鼠标屏幕位置刷新虚影/落点格（战场无相机平移缩放，屏幕=世界网格）。
func _update_drag_at(screen_pos: Vector2) -> void:
	if not _drag_active or _ghost == null:
		return
	_drag_over_ui = _is_point_over_battle_ui(screen_pos)
	if _drag_over_ui:
		_drag_valid = false
		_cell_tint.visible = false
		_ghost.visible = false
		return
	var cell := Vector2i(
		floori(screen_pos.x / GridBackground.GRID_SIZE),
		floori(screen_pos.y / GridBackground.GRID_SIZE)
	)
	_drag_cell = cell
	_drag_valid = can_build_at(cell)
	var in_bounds := cell.x >= 0 and cell.x < GridBackground.COLS \
		and cell.y >= 0 and cell.y < GridBackground.ROWS
	_ghost.visible = in_bounds
	if not in_bounds:
		_cell_tint.visible = false
		return
	var center := cell_center(cell)
	_cell_tint.global_position = center
	_cell_tint.color = VALID_TINT if _drag_valid else INVALID_TINT
	_cell_tint.visible = true
	_ghost.global_position = center
	_ghost.modulate = GHOST_MODULATE_VALID if _drag_valid else GHOST_MODULATE_INVALID


## 拖拽经过 UI 面板（顶栏/卡条/塔面板等）时隐藏虚影，松手不建造。
func _is_point_over_battle_ui(screen_pos: Vector2) -> bool:
	if is_instance_valid(ui) and ui.has_method("is_point_over_battle_ui"):
		return ui.is_point_over_battle_ui(screen_pos)
	return false


## 覆盖层吞掉拖拽期间全部鼠标事件：左键松手=放置，右键按下=取消。
func _on_catcher_gui_input(event: InputEvent) -> void:
	if not _drag_active:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		# 释放若未被发起拖拽的卡片接收（焦点落在覆盖层），同样按当前位置放置。
		release_drag()
	elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_drag()


## 左键松手统一入口（卡片 button_up / 覆盖层左键释放）：落点可建且不在 UI 区
## 则直接建造（扣费 / 上塔 / 音效与旧点击路径一致），其余取消、不扣费。
func release_drag() -> void:
	if not _drag_active:
		return
	var placed := false
	if _drag_valid and not _drag_over_ui and _drag_character != null:
		var built: Tower = tower_manager.build_tower(
			cell_center(_drag_cell), _drag_character, null, _drag_loadout
		)
		if built != null:
			tower_built.emit(str(_drag_character.character_id))
			placed = true
			_show_feedback("建造完成")
	_end_drag(placed)
	if _drag_valid and not placed:
		_show_feedback("金币不足")


## 右键 / ESC / 战局结束与暂停：取消拖拽，不建造不扣费。
func cancel_drag() -> void:
	if not _drag_active:
		return
	_end_drag(false)


func _end_drag(placed: bool) -> void:
	_drag_active = false
	_drag_character = null
	_drag_loadout.clear()
	_drag_cell = Vector2i(-1, -1)
	_drag_valid = false
	_drag_over_ui = false
	if _catcher != null:
		_catcher.visible = false
	if _cell_tint != null:
		_cell_tint.visible = false
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	drag_finished.emit(placed)


## ESC 取消（键盘事件不经覆盖层，走 unhandled）。
func _unhandled_input(event: InputEvent) -> void:
	if _drag_active and event.is_action_pressed("ui_cancel"):
		cancel_drag()
		get_viewport().set_input_as_handled()


## 虚影 = 实塔同款表现（半透明 + 选中态范围圈），不参与任何战斗逻辑。
func _ensure_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		return
	var ghost := TOWER_SCENE.instantiate() as Tower
	_ghost_root.add_child(ghost)
	ghost.remove_from_group(Tower.TOWER_GROUP)
	ghost.process_mode = Node.PROCESS_MODE_DISABLED
	ghost.apply_character(_drag_character, _drag_loadout)
	ghost.is_selected = true
	ghost.queue_redraw()
	_ghost = ghost


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


func _show_feedback(message: String) -> void:
	if is_instance_valid(ui) and ui.has_method("show_status"):
		ui.show_status(message)
