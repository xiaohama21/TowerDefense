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
## 装饰素材（v0.16.0，GDD 5.7 第三步）：assets/map/decor/*.png，缺失时回退程序化绘制。
const DECOR_TEXTURE_DIR := "res://assets/map/decor"
const DECOR_TEXTURE_SIZE := 60.0
const DECOR_TYPES: Array[StringName] = [&"tree", &"rock", &"banner", &"torch"]

var road_cells: Array[Vector2i] = []
var decor_cells: Array[Vector2i] = []
var forbidden_cells: Array[Vector2i] = []
var entry_cell := Vector2i(-1, -1)
var base_cell := Vector2i(-1, -1)
var theme_name: StringName = &"grass"

## 地图主题调色板（GDD modules/STAGES.md 5.7）：调色板 + 氛围 + 光源。
## 纯程序化，视觉常量随主题扩充（水战/雪地等留待后续章节）。
const THEMES := {
	&"grass": {
		"tile_a": Color(0.13, 0.26, 0.19), "tile_b": Color(0.11, 0.22, 0.16),
		"road": Color(0.47, 0.34, 0.24), "road_edge": Color(0.15, 0.12, 0.1),
		"road_highlight": Color(0.66, 0.51, 0.34, 0.5),
		"trunk": Color(0.3, 0.22, 0.14), "leaf": Color(0.2, 0.42, 0.28),
		"ambient": Color(0, 0, 0, 0), "glow": false, "glow_color": Color(1, 1, 1, 0),
	},
	&"fire": {
		"tile_a": Color(0.28, 0.19, 0.13), "tile_b": Color(0.24, 0.16, 0.11),
		"road": Color(0.5, 0.33, 0.2), "road_edge": Color(0.2, 0.11, 0.07),
		"road_highlight": Color(0.95, 0.6, 0.3, 0.55),
		"trunk": Color(0.34, 0.2, 0.1), "leaf": Color(0.45, 0.28, 0.12),
		"ambient": Color(1.0, 0.45, 0.15, 0.1), "glow": true,
		"glow_color": Color(1.0, 0.55, 0.2, 0.18), "glow_step": 2, "glow_radius": 26.0,
	},
	&"night": {
		"tile_a": Color(0.06, 0.09, 0.13), "tile_b": Color(0.05, 0.07, 0.11),
		"road": Color(0.3, 0.28, 0.32), "road_edge": Color(0.12, 0.12, 0.15),
		"road_highlight": Color(0.5, 0.5, 0.6, 0.4),
		"trunk": Color(0.15, 0.14, 0.2), "leaf": Color(0.12, 0.16, 0.22),
		"ambient": Color(0.02, 0.04, 0.1, 0.45), "glow": true,
		"glow_color": Color(1.0, 0.75, 0.35, 0.22), "glow_step": 3, "glow_radius": 32.0,
	},
}

var _palette: Dictionary = {}
var _road_set: Dictionary = {}
var _decor_textures: Dictionary = {}


func _ready() -> void:
	z_index = -15
	_load_decor_textures()
	queue_redraw()


## Called by the stage controller after children are ready.
func configure(
	stage_road_cells: Array[Vector2i],
	stage_decor_cells: Array[Vector2i],
	stage_entry_cell: Vector2i,
	stage_base_cell: Vector2i,
	stage_theme: StringName = &"grass",
	stage_forbidden_cells: Array[Vector2i] = []
) -> void:
	road_cells = stage_road_cells
	decor_cells = stage_decor_cells
	forbidden_cells = stage_forbidden_cells
	entry_cell = stage_entry_cell
	base_cell = stage_base_cell
	theme_name = stage_theme
	_palette = THEMES.get(stage_theme, THEMES[&"grass"])
	_road_set.clear()
	for cell in road_cells:
		_road_set[cell] = true
	queue_redraw()


func _draw() -> void:
	_draw_tiles()
	_draw_forbidden()
	_draw_grid_lines()
	_draw_road()
	_draw_landmarks()
	_draw_decorations()
	_draw_ambient()


## 禁建地形（阶段 8 提交 3）：深色块 + 山形标记，明确覆盖表示不可建造。
func _draw_forbidden() -> void:
	if forbidden_cells.is_empty():
		return
	var fill_color := Color(0.33, 0.31, 0.27, 1.0)
	var edge_color := Color(0.52, 0.44, 0.32, 1.0)
	var peak_color := Color(0.24, 0.3, 0.24, 1.0)
	var peak_light := Color(0.34, 0.42, 0.34, 1.0)
	for cell in forbidden_cells:
		var origin := cell_origin(cell)
		draw_rect(Rect2(origin, Vector2(GRID_SIZE, GRID_SIZE)), fill_color)
		draw_rect(Rect2(origin, Vector2(GRID_SIZE, GRID_SIZE)), edge_color, false, 2.0)
		var center := cell_center(cell)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-20, 12),
			center + Vector2(0, -18),
			center + Vector2(20, 12),
		]), peak_color)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-6, 12),
			center + Vector2(8, -8),
			center + Vector2(22, 12),
		]), peak_light)


func _draw_tiles() -> void:
	for col in range(COLS):
		for row in range(ROWS):
			var cell := Vector2i(col, row)
			if _road_set.has(cell):
				continue
			var color: Color = _palette["tile_a"] if (col + row) % 2 == 0 else _palette["tile_b"]
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
		draw_rect(rect, _palette["road"])
		draw_rect(rect, _palette["road_edge"], false, 2.0)
		# Centre line dashes help show the lane direction.
		if index + 1 < road_cells.size() and _are_adjacent(cell, road_cells[index + 1]):
			draw_line(
				cell_center(cell),
				cell_center(road_cells[index + 1]),
				_palette["road_highlight"],
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
		var decor_type := _decor_type_for_cell(cell)
		var texture: Texture2D = _decor_textures.get(decor_type)
		if texture != null:
			draw_texture_rect(texture, Rect2(center - Vector2(DECOR_TEXTURE_SIZE, DECOR_TEXTURE_SIZE) * 0.5, Vector2(DECOR_TEXTURE_SIZE, DECOR_TEXTURE_SIZE)), false)
			continue
		draw_circle(center + Vector2(0, 16), 8.0, _palette["trunk"])
		draw_circle(center + Vector2(0, 2), 14.0, _palette["leaf"])


## 装饰类型（确定性哈希，不依赖布局数据改动）：
## 夜战主题火把比例更高（营造火光氛围），其余主题以树为主。
func _decor_type_for_cell(cell: Vector2i) -> StringName:
	var roll: int = abs(hash(cell)) % 100
	if theme_name == &"night":
		if roll < 40:
			return &"tree"
		if roll < 65:
			return &"rock"
		if roll < 75:
			return &"banner"
		return &"torch"
	if roll < 55:
		return &"tree"
	if roll < 80:
		return &"rock"
	if roll < 90:
		return &"banner"
	return &"torch"


func _load_decor_textures() -> void:
	for decor_type in DECOR_TYPES:
		var path := "%s/%s.png" % [DECOR_TEXTURE_DIR, decor_type]
		if ResourceLoader.exists(path):
			_decor_textures[decor_type] = load(path) as Texture2D


func _draw_ambient() -> void:
	# 氛围层（夜战调暗/火攻暖色）先于光源绘制，火把/火光在其上"点亮"。
	var ambient: Color = _palette["ambient"]
	if ambient.a > 0.0:
		draw_rect(Rect2(0, 0, COLS * GRID_SIZE, ROWS * GRID_SIZE), ambient)
	if _palette["glow"]:
		var step: int = _palette["glow_step"]
		var radius: float = _palette["glow_radius"]
		var glow: Color = _palette["glow_color"]
		for index in range(0, road_cells.size(), step):
			draw_circle(cell_center(road_cells[index]), radius, glow)


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

