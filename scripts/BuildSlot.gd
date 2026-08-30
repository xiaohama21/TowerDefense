extends Area2D

class_name BuildSlot

signal build_requested(slot: BuildSlot)
## 预锁位解锁请求（v0.14.1，GDD 5.1）：点击锁定位触发，由 BuildManager 扣金币解锁。
signal unlock_requested(slot: BuildSlot)

@export var slot_id: int = -1
@export var occupied: bool = false
## 待确认建造（防误建）：首次点击高亮待确认，再次点击同一位置确认建造；
## 右键/ESC/切换武将取消（v0.12.4 起为两次点击模式，无底部确认面板）。
var pending: bool = false

## 结构化建造位（v0.14.1）：类型为软引导（不限制放置），locked 为预锁位。
var slot_type: BuildSlotData.SlotType = BuildSlotData.SlotType.ANY
var locked: bool = false
var unlock_cost: int = 60
var _unlocked_in_battle: bool = false

const IDLE_RING_COLOR := Color("8fd694")
const IDLE_FILL_COLOR := Color("294f43d9")
const HOVER_RING_COLOR := Color("fff0a8")
const HOVER_FILL_COLOR := Color("52796fe6")
const OCCUPIED_RING_COLOR := Color("708579")
const OCCUPIED_FILL_COLOR := Color("263832e6")
const PENDING_RING_COLOR := Color("ffc857")
const PENDING_FILL_COLOR := Color("8a6a1fd9")
const LOCKED_RING_COLOR := Color("b8a25c")
const LOCKED_FILL_COLOR := Color("3c3523e6")

@onready var outer_ring: Line2D = $OuterRing
@onready var fill: Polygon2D = $Fill
@onready var plus_horizontal: Polygon2D = $PlusHorizontal
@onready var plus_vertical: Polygon2D = $PlusVertical


func _ready() -> void:
	add_to_group("build_slots")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh_visual(false)
	queue_redraw()


## 应用结构化建造位数据（v0.14.1）：位置由调用方设置，此处只取类型与锁位。
func apply_slot_data(data: BuildSlotData) -> void:
	if data == null:
		return
	slot_type = data.slot_type
	locked = data.locked
	unlock_cost = data.unlock_cost


func is_locked() -> bool:
	return locked and not _unlocked_in_battle


func try_unlock() -> void:
	if not locked:
		return
	_unlocked_in_battle = true
	_refresh_visual(false)
	queue_redraw()


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if occupied:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if is_locked():
				unlock_requested.emit(self)
			else:
				build_requested.emit(self)
			get_viewport().set_input_as_handled()


func mark_built() -> void:
	occupied = true
	pending = false
	input_pickable = false
	_refresh_visual(false)


func set_pending(value: bool) -> void:
	pending = value
	_refresh_visual(false)


func reset_slot() -> void:
	occupied = false
	input_pickable = true
	_refresh_visual(false)


func get_build_position() -> Vector2:
	return global_position


func _on_mouse_entered() -> void:
	if not occupied:
		_refresh_visual(true)


func _on_mouse_exited() -> void:
	_refresh_visual(false)


func _refresh_visual(is_hovered: bool) -> void:
	if occupied:
		outer_ring.default_color = OCCUPIED_RING_COLOR
		# Hide the filled disc so the deployed hero stays fully visible; only
		# the thin ring marks the occupied slot.
		fill.visible = false
		plus_horizontal.visible = false
		plus_vertical.visible = false
		return

	if is_locked():
		outer_ring.default_color = LOCKED_RING_COLOR
		fill.visible = true
		fill.color = LOCKED_FILL_COLOR
		plus_horizontal.visible = false
		plus_vertical.visible = false
		return

	if pending:
		outer_ring.default_color = PENDING_RING_COLOR
		fill.visible = true
		fill.color = PENDING_FILL_COLOR
		plus_horizontal.visible = true
		plus_vertical.visible = true
		plus_horizontal.color = PENDING_RING_COLOR
		plus_vertical.color = PENDING_RING_COLOR
		return

	fill.visible = true
	outer_ring.default_color = HOVER_RING_COLOR if is_hovered else IDLE_RING_COLOR
	fill.color = HOVER_FILL_COLOR if is_hovered else IDLE_FILL_COLOR
	plus_horizontal.visible = true
	plus_vertical.visible = true
	plus_horizontal.color = HOVER_RING_COLOR if is_hovered else IDLE_RING_COLOR
	plus_vertical.color = HOVER_RING_COLOR if is_hovered else IDLE_RING_COLOR


func _draw() -> void:
	if is_locked():
		# 简易锁形：锁环 + 锁体，标注"需金币解锁"。
		draw_arc(Vector2(0, -3), 5.0, 0.0, TAU, 16, LOCKED_RING_COLOR, 2.5)
		draw_circle(Vector2(0, 2), 2.0, LOCKED_RING_COLOR)
		draw_rect(Rect2(-7, 4, 14, 10), LOCKED_RING_COLOR)
	elif slot_type != BuildSlotData.SlotType.ANY and not occupied:
		# 类型软引导标识（GDD 5.1）：近战/远程标签。
		var label := "近" if slot_type == BuildSlotData.SlotType.MELEE else "远"
		draw_string(ThemeDB.fallback_font, Vector2(-5, 32), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.92, 0.88, 0.85))
