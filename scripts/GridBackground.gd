extends Node2D

## Grid-based map background: checkerboard tiles, an axis-aligned road made of
## grid cells, plus entrance/base landmarks and a few regular decorations.
## All coordinates derive from GRID_SIZE so the map stays perfectly aligned.

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

## Road cells in grid coordinates (column, row). Row 0 is the top of the map.
const ROAD_CELLS: Array[Vector2i] = [
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
	Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3),
	Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6),
	Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6),
	Vector2i(12, 5), Vector2i(12, 4), Vector2i(13, 4), Vector2i(14, 4),
	Vector2i(15, 4),
]

## Regular decoration cells (trees) placed on empty tiles.
const DECOR_CELLS: Array[Vector2i] = [
	Vector2i(2, 1), Vector2i(5, 1), Vector2i(10, 1), Vector2i(14, 1),
	Vector2i(2, 7), Vector2i(5, 7), Vector2i(10, 7), Vector2i(14, 7),
	Vector2i(1, 6), Vector2i(3, 6), Vector2i(13, 2), Vector2i(13, 6),
]

var _road_set: Dictionary = {}


func _ready() -> void:
	z_index = -15
	for cell in ROAD_CELLS:
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
	for cell in ROAD_CELLS:
		var rect := Rect2(cell_origin(cell), Vector2(GRID_SIZE, GRID_SIZE))
		draw_rect(rect, ROAD_COLOR)
		draw_rect(rect, ROAD_EDGE_COLOR, false, 2.0)
	# Centre line dashes help show the lane direction.
	for index in range(ROAD_CELLS.size() - 1):
		var from := cell_center(ROAD_CELLS[index])
		var to := cell_center(ROAD_CELLS[index + 1])
		draw_line(from, to, ROAD_HIGHLIGHT_COLOR, 3.0)


func _draw_landmarks() -> void:
	var entrance := cell_center(Vector2i(0, 3))
	draw_circle(entrance + Vector2(0, -18), 10.0, ENTRANCE_COLOR)
	draw_rect(Rect2(entrance + Vector2(-24, -14), Vector2(48, 6)), ENTRANCE_COLOR)
	var base := cell_center(Vector2i(15, 4))
	var base_rect := Rect2(base + Vector2(-34, -26), Vector2(68, 52))
	draw_rect(base_rect, BASE_COLOR)
	draw_rect(base_rect, Color(0.9, 0.75, 0.45, 0.9), false, 3.0)
	draw_rect(Rect2(base + Vector2(-12, 8), Vector2(24, 18)), Color(0.12, 0.17, 0.15, 1.0))


func _draw_decorations() -> void:
	for cell in DECOR_CELLS:
		var center := cell_center(cell)
		draw_circle(center + Vector2(0, 16), 8.0, DECOR_TRUNK_COLOR)
		draw_circle(center + Vector2(0, 2), 14.0, DECOR_LEAF_COLOR)


func cell_origin(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * GRID_SIZE, cell.y * GRID_SIZE)


func cell_center(cell: Vector2i) -> Vector2:
	return cell_origin(cell) + Vector2(GRID_SIZE, GRID_SIZE) * 0.5