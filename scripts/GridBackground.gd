extends Node2D

class_name GridBackground

## Grid-based map background: checkerboard tiles, an axis-aligned road made of
## grid cells, plus entrance/base landmarks and decorations. Road/decor cells
## are injected per stage (GDD 5.6 / StageData layout) instead of hardcoded.

const GRID_SIZE: int = 80
const COLS: int = 16
const ROWS: int = 9

const TILE_A_COLOR := Color(0.13, 0.26, 0.19, 1.0)
const TILE_B_COLOR := Color(0.11, 0.22, 0.16, 1.0)
const GRID_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.045)
const ROAD_COLOR := Color(0.47, 0.34, 0.24, 1.0)
const ROAD_EDGE_COLOR := Color(0.15, 0.12, 0.1, 1.0)
const ROAD_HIGHLIGHT_COLOR := Color(0.66, 0.51, 0.34, 0.5)
const ENTRANCE_COLOR := Color(0.78, 0.62, 0.36, 1.0)
const BASE_COLOR := Color(0.68, 0.29, 0.24, 1.0)
const DECOR_TRUNK_COLOR := Color(0.3, 0.22, 0.14, 1.0)
const DECOR_LEAF_COLOR := Color(0.2, 0.42, 0.28, 1.0)

var road_cells: Array[Vector2i] = []
var decor_cells: Array[Vector2i] = []
var entry_cell := Vector2i(-1, -1)
var base_cell := Vector2i(-1, -1)

var _road_set: Dictionary = {}


func _ready() -> void:
	z_index = -15
	queue_redraw()


## Called by the stage controller after children are ready.
func configure(
	stage_road_cells: Array[Vector2i],
	stage_decor_cells: Array[Vector2i],
	stage_entry_cell: Vector2i,
	stage_base_cell: Vector2i
) -> void:
	road_cells = stage_road_cells
	decor_cells = stage_decor_cells
	entry_cell = stage_entry_cell
	base_cell = stage_base_cell
	_road_set.clear()
	for cell in road_cells:
		_road_set[cell] = true
	queue_redraw()


func _draw() -> void:
	_draw_tiles()
	_draw_grid_lines()
	_draw_road()
	_draw_landmarks()
	_draw_decorations()


func _draw_tiles() -> void:
	for col in range(COLS):
		for row in range(ROWS):
			var cell := Vector2i(col, row)
			if _road_set.has(cell):
				continue
			var color := TILE_A_COLOR if (col + row) % 2 == 0 else TILE_B_COLOR
			draw_rect(Rect2(cell_origin(cell), Vector2(GRID_SIZE, GRID_SIZE)), color)


func _draw_grid_lines() -> void:
	for col in range(COLS + 1):
		var x := col * GRID_SIZE
		draw_line(Vector2(x, 0), Vector2(x, ROWS * GRID_SIZE), GRID_LINE_COLOR, 1.0)
	for row in range(ROWS + 1):
		var y := row * GRID_SIZE
		draw_line(Vector2(0, y), Vector2(COLS * GRID_SIZE, y), GRID_LINE_COLOR, 1.0)


func _draw_road() -> void:
	for index in range(road_cells.size()):
		var cell := road_cells[index]
		var rect := Rect2(cell_origin(cell), Vector2(GRID_SIZE, GRID_SIZE))
		draw_rect(rect, ROAD_COLOR)
		draw_rect(rect, ROAD_EDGE_COLOR, false, 2.0)
		# Centre line dashes help show the lane direction.
		if index + 1 < road_cells.size() and _are_adjacent(cell, road_cells[index + 1]):
			draw_line(
				cell_center(cell),
				cell_center(road_cells[index + 1]),
				ROAD_HIGHLIGHT_COLOR,
				3.0
			)


func _are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _draw_landmarks() -> void:
	if entry_cell.x >= 0:
		var entrance := cell_center(entry_cell)
		draw_circle(entrance + Vector2(0, -18), 10.0, ENTRANCE_COLOR)
		draw_rect(Rect2(entrance + Vector2(-24, -14), Vector2(48, 6)), ENTRANCE_COLOR)
	if base_cell.x >= 0:
		var base := cell_center(base_cell)
		var base_rect := Rect2(base + Vector2(-34, -26), Vector2(68, 52))
		draw_rect(base_rect, BASE_COLOR)
		draw_rect(base_rect, Color(0.9, 0.75, 0.45, 0.9), false, 3.0)
		draw_rect(Rect2(base + Vector2(-12, 8), Vector2(24, 18)), Color(0.12, 0.17, 0.15, 1.0))


func _draw_decorations() -> void:
	for cell in decor_cells:
		var center := cell_center(cell)
		draw_circle(center + Vector2(0, 16), 8.0, DECOR_TRUNK_COLOR)
		draw_circle(center + Vector2(0, 2), 14.0, DECOR_LEAF_COLOR)


func cell_origin(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * GRID_SIZE, cell.y * GRID_SIZE)


func cell_center(cell: Vector2i) -> Vector2:
	return cell_origin(cell) + Vector2(GRID_SIZE, GRID_SIZE) * 0.5


## Derive in-map road cells by walking a stage path polyline cell-center to
## cell-center (orthogonal, 80px steps). Off-map stubs contribute no cells.
static func derive_road_cells(path_points: Array[Vector2]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for index in range(path_points.size() - 1):
		var from := path_points[index]
		var to := path_points[index + 1]
		var step := (to - from).normalized()
		var distance := from.distance_to(to)
		var steps := int(round(distance / GRID_SIZE))
		for i in range(steps + 1):
			var point := from + step * (GRID_SIZE * i)
			var cell := Vector2i(
				int(round((point.x - GRID_SIZE * 0.5) / GRID_SIZE)),
				int(round((point.y - GRID_SIZE * 0.5) / GRID_SIZE))
			)
			if cell.x < 0 or cell.x >= COLS or cell.y < 0 or cell.y >= ROWS:
				continue
			if not cells.has(cell):
				cells.append(cell)
	return cells
