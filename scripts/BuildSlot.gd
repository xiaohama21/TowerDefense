extends Area2D

class_name BuildSlot

signal build_requested(slot: BuildSlot)

@export var slot_id: int = -1
@export var occupied: bool = false

const IDLE_RING_COLOR := Color("8fd694")
const IDLE_FILL_COLOR := Color("294f43d9")
const HOVER_RING_COLOR := Color("fff0a8")
const HOVER_FILL_COLOR := Color("52796fe6")
const OCCUPIED_RING_COLOR := Color("708579")
const OCCUPIED_FILL_COLOR := Color("263832e6")

@onready var outer_ring: Line2D = $OuterRing
@onready var fill: Polygon2D = $Fill
@onready var plus_horizontal: Polygon2D = $PlusHorizontal
@onready var plus_vertical: Polygon2D = $PlusVertical


func _ready() -> void:
	add_to_group("build_slots")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh_visual(false)


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if occupied:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			build_requested.emit(self)
			get_viewport().set_input_as_handled()


func mark_built() -> void:
	occupied = true
	input_pickable = false
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

	fill.visible = true
	outer_ring.default_color = HOVER_RING_COLOR if is_hovered else IDLE_RING_COLOR
	fill.color = HOVER_FILL_COLOR if is_hovered else IDLE_FILL_COLOR
	plus_horizontal.visible = true
	plus_vertical.visible = true
	plus_horizontal.color = HOVER_RING_COLOR if is_hovered else IDLE_RING_COLOR
	plus_vertical.color = HOVER_RING_COLOR if is_hovered else IDLE_RING_COLOR
