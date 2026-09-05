@tool
extends Node2D

## 地图编辑器编辑态覆盖层（M2）：建造位虚线圈 + 出入口旗标标注 + 路径端点环 +
## 悬停格高亮。底图本身由 GridBackground 实例绘制，保证与运行时一致；
## 导出底图 PNG 时本层剔除。

const GRID_SIZE := 80
const MAP_WIDTH := 1280
const MAP_HEIGHT := 720

var stage: StageData
var entry_cell := Vector2i(-1, -1)
var base_cell := Vector2i(-1, -1)
var hover_cell := Vector2i(-1, -1)
## 路径刷激活时高亮链端点（延伸/退格热点）。
var show_endpoints := false

var _font: Font


func _ready() -> void:
	_font = load("res://assets/fonts/ZCOOL-Kuaile.ttf") as Font
	z_index = 50


func _draw() -> void:
	if stage == null:
		return
	# 战场边界
	draw_rect(Rect2(0, 0, MAP_WIDTH, MAP_HEIGHT), Color(1, 1, 1, 0.25), false, 2.0)
	# 建造位（软引导推荐位）虚线圈
	_draw_slot_positions()
	# 出入口标注
	_draw_landmark_label(entry_cell, "入口", Color(1, 0.85, 0.4))
	_draw_landmark_label(base_cell, "基地", Color(1, 0.55, 0.5))
	# 路径刷端点环（M2）
	if show_endpoints:
		_draw_endpoint_ring(entry_cell, Color(1, 0.85, 0.4, 0.8))
		_draw_endpoint_ring(base_cell, Color(1, 0.5, 0.45, 0.8))
	# 悬停格高亮（M2）
	_draw_hover()


func _draw_slot_positions() -> void:
	var positions := _slot_positions()
	for pos: Vector2 in positions:
		draw_circle(pos, 26.0, Color(1, 1, 1, 0.08))
		_draw_dashed_arc(pos, 26.0, Color(1, 1, 1, 0.6))


func _draw_dashed_arc(center: Vector2, radius: float, color: Color) -> void:
	const SEGMENTS := 24
	const STEP := TAU / SEGMENTS
	for i in range(SEGMENTS):
		if i % 2 == 0:
			var start_angle := i * STEP
			draw_arc(center, radius, start_angle, start_angle + STEP, 3, color, 2.0, true)


func _draw_endpoint_ring(cell: Vector2i, color: Color) -> void:
	if cell.x < 0 or cell.y < 0:
		return
	_draw_dashed_arc(cell_center(cell), 34.0, color)


func _draw_hover() -> void:
	if hover_cell.x < 0 or hover_cell.y < 0:
		return
	var origin := Vector2(hover_cell.x * GRID_SIZE, hover_cell.y * GRID_SIZE)
	var rect := Rect2(origin, Vector2(GRID_SIZE, GRID_SIZE))
	draw_rect(rect, Color(1, 1, 1, 0.1))
	draw_rect(rect, Color(1, 1, 1, 0.45), false, 2.0)


func _draw_landmark_label(cell: Vector2i, text: String, color: Color) -> void:
	if cell.x < 0 or cell.y < 0:
		return
	if _font == null:
		return
	var anchor := Vector2(cell.x * GRID_SIZE + GRID_SIZE * 0.5, cell.y * GRID_SIZE + GRID_SIZE * 0.5)
	var pos := anchor + Vector2(-26.0, -44.0)
	var outline := Color(0.05, 0.07, 0.06, 0.9)
	draw_string_outline(_font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, outline)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)


func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * GRID_SIZE) + Vector2(GRID_SIZE, GRID_SIZE) * 0.5


func _slot_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if stage == null:
		return result
	for pos in stage.build_slot_positions:
		result.append(pos)
	if stage.build_slots.size() > 0:
		for slot in stage.build_slots:
			result.append(slot.position)
	return result
