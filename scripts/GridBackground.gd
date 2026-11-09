extends Node2D

class_name GridBackground

## Modular map background: continuous terrain, an axis-aligned road made of
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
## 显式装饰类型（v0.36.0，StageData.decor_types）：格子 → tree/rock/banner/torch；
## 缺省格回退格子哈希选型，旧关卡行为不变。
var _decor_types: Dictionary = {}
var entry_cell := Vector2i(-1, -1)
var base_cell := Vector2i(-1, -1)
var theme_name: StringName = &"grass"

## 地图主题调色板（GDD modules/STAGES.md 5.7）：调色板 + 氛围 + 光源。
## 纯程序化，视觉常量随主题扩充（水战/雪地等留待后续章节）。
const MAP_TEXTURES := ["grass", "grass_1", "grass_2", "grass_3", "road", "tree", "tree_1", "stump", "rock", "rock_cluster", "banner", "torch", "gate", "base"]
const THEMES := {
	&"grass": {"tile_a": Color("#536e47"), "tile_b": Color("#77915c"), "road": Color("#b6a17a"), "road_edge": Color("#777653"), "road_highlight": Color("#dcc69a"), "trunk": Color("#705537"), "leaf": Color("#789351"), "tint": Color.WHITE, "ambient": Color.TRANSPARENT, "glow": false},
	&"fire": {"tile_a": Color("#665b3d"), "tile_b": Color("#8c774c"), "road": Color("#b29770"), "road_edge": Color("#716047"), "road_highlight": Color("#d6b789"), "trunk": Color("#584737"), "leaf": Color("#91804c"), "tint": Color(.95,.77,.55), "ambient": Color.TRANSPARENT, "glow": true},
	&"night": {"tile_a": Color("#34494b"), "tile_b": Color("#526360"), "road": Color("#7e8b85"), "road_edge": Color("#4b6260"), "road_highlight": Color("#a9b6a5"), "trunk": Color("#465452"), "leaf": Color("#536f61"), "tint": Color(.67,.78,.85), "ambient": Color.TRANSPARENT, "glow": true},
}

var _palette: Dictionary = {}
var _road_set: Dictionary = {}
var route_paths: Dictionary = {}
var _decor_textures: Dictionary = {}
var _camp_textures: Dictionary = {}
var placement_grid_visible := false


func _ready() -> void:
	z_index = -15
	_palette = THEMES.get(theme_name, THEMES[&"grass"])
	_load_decor_textures()
	for id in MAP_TEXTURES:
		var path := "res://assets/battle_visuals/grass_camp/%s.png" % id
		if ResourceLoader.exists(path): _camp_textures[id] = load(path) as Texture2D
	queue_redraw()


func configure(
	stage_road_cells: Array[Vector2i],
	stage_decor_cells: Array[Vector2i],
	stage_entry_cell: Vector2i,
	stage_base_cell: Vector2i,
	stage_theme: StringName = &"grass",
	stage_forbidden_cells: Array[Vector2i] = [],
	stage_decor_types: Dictionary = {},
	stage_routes: Dictionary = {}
) -> void:
	road_cells = stage_road_cells
	decor_cells = stage_decor_cells
	forbidden_cells = stage_forbidden_cells
	_decor_types = stage_decor_types
	route_paths = stage_routes
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
	_draw_road()
	_draw_forbidden()
	_draw_grid_lines()
	_draw_decorations()
	_draw_landmarks()
	_draw_ambient()


func set_placement_grid_visible(active: bool) -> void:
	placement_grid_visible = active
	queue_redraw()


## 禁建地形（阶段 8 提交 3）：深色块 + 山形标记，明确覆盖表示不可建造。
func _draw_forbidden() -> void:
	for cell in forbidden_cells:
		var rect := Rect2(cell_origin(cell),Vector2.ONE * GRID_SIZE)
		if _camp_textures.has("rock_cluster"):
			draw_texture_rect(_camp_textures.rock_cluster,rect.grow(-1),false,_palette.tint)
		else:
			var center := cell_center(cell)
			for offset in [Vector2(-15,5),Vector2(12,-8),Vector2(23,17)]:
				draw_colored_polygon(PackedVector2Array([center+offset+Vector2(-18,12),center+offset+Vector2(-10,-11),center+offset+Vector2(9,-16),center+offset+Vector2(20,9)]),_palette.road_edge)
		if theme_name == &"fire":
			for i in range(3):
				var at := cell_center(cell)+Vector2(-22+i*19,22-float(i%2)*5)
				draw_circle(at,4.5,Color(.95,.41,.13,.14))
				draw_line(at,at+Vector2(2,-1),Color(.86,.49,.21,.7),1.2,true)
		if placement_grid_visible:
			draw_rect(rect.grow(-2),Color(.86,.61,.4,.65),false,2.0)


func _draw_tiles() -> void:
	draw_rect(Rect2(0,0,COLS*GRID_SIZE,ROWS*GRID_SIZE),_palette.tile_a)
	# A private generator keeps map redraws independent of combat critical/drop RNG.
	var rng := RandomNumberGenerator.new()
	rng.seed = 930803
	for i in range(65):
		var at := Vector2(rng.randf_range(0,1280),rng.randf_range(0,720))
		var tint: Color = _palette.tile_b if i % 3 else _palette.road_edge
		tint.a = .035 if i % 3 else .04
		draw_set_transform(at,0,Vector2(rng.randf_range(1.7,2.8),1))
		var radius := rng.randf_range(17,57)
		var patch := PackedVector2Array()
		for point in range(12):
			patch.append(Vector2.from_angle(float(point)*TAU/12)*radius*rng.randf_range(.75,1.15))
		for layer in range(3):
			draw_colored_polygon(patch,tint)
			for point in range(patch.size()): patch[point] *= .88
	draw_set_transform(Vector2.ZERO)
	for col in range(COLS):
		for row in range(ROWS):
			var cell := Vector2i(col,row)
			var variant := _cell_seed(cell) % 4
			var key := "grass" if variant == 0 else "grass_%d" % variant
			if _camp_textures.has(key):
				draw_set_transform(cell_center(cell),float((_cell_seed(cell)/7)%4)*PI*.5)
				draw_texture_rect(_camp_textures[key],Rect2(-40,-40,80,80),false,Color(_palette.tint, .48))
				draw_set_transform(Vector2.ZERO)


func _draw_grid_lines() -> void:
	if not placement_grid_visible: return
	var color := Color(.80,.89,.72,.19)
	for col in range(COLS + 1):
		draw_line(Vector2(col*GRID_SIZE,0),Vector2(col*GRID_SIZE,ROWS*GRID_SIZE),color,1)
	for row in range(ROWS + 1):
		draw_line(Vector2(0,row*GRID_SIZE),Vector2(COLS*GRID_SIZE,row*GRID_SIZE),color,1)


func _draw_road() -> void:
	# Only external sides have a shoulder; neighboring cells share a continuous fill.
	for cell in _road_set:
		var open := _road_open_sides(cell)
		var rect := Rect2(cell_origin(cell),Vector2.ONE * GRID_SIZE)
		_draw_road_shape(rect,open,_palette.road_edge,12.0)
		var inner := rect.grow_individual(-4 if open[0] else 0,-4 if open[1] else 0,-4 if open[2] else 0,-4 if open[3] else 0)
		_draw_road_shape(inner,open,_palette.road,9.0)
		if _camp_textures.has("road"):
			draw_set_transform(cell_center(cell),float((_cell_seed(cell)/11)%4)*PI*.5)
			draw_texture_rect(_camp_textures.road,Rect2(-30,-30,60,60),false,Color(_palette.tint,.8))
			draw_set_transform(Vector2.ZERO)
		for side in range(4):
			if not open[side]: continue
			var normal: Vector2 = [Vector2.LEFT,Vector2.UP,Vector2.RIGHT,Vector2.DOWN][side]
			var along := Vector2(-normal.y,normal.x)
			var center := cell_center(cell) + normal * 33
			var line := PackedVector2Array()
			for i in range(7):
				var offset := float((_cell_seed(cell)+side*7+i*11)%5)*.4
				line.append(center+along*(-24+i*8)+normal*offset)
			draw_polyline(line,Color(_palette.road_highlight,.32),1.2,true)
			for i in range(3):
				var point := center + along * (-20+i*18) + normal*4
				draw_line(point,point+along*2,Color(_palette.road_edge,.6),1.4,true)
	var traversals: Array = [road_cells]
	if not route_paths.is_empty():
		traversals.clear()
		for points in route_paths.values():
			var typed: Array[Vector2] = []
			typed.assign(points)
			traversals.append(trace_road_cells(typed))
	var drawn := {}
	for cells in traversals:
		for index in range(cells.size()-1):
			var cell: Vector2i = cells[index]
			if index%4 != 2 or not _are_adjacent(cell,cells[index+1]): continue
			var heading := Vector2(cells[index+1]-cell)
			var key := Vector4i(cell.x,cell.y,int(heading.x),int(heading.y))
			if drawn.has(key): continue
			drawn[key] = true
			var wing := Vector2(-heading.y,heading.x)
			var center := cell_center(cell)
			draw_polyline(PackedVector2Array([center-heading*5+wing*4,center+heading*3,center-heading*5-wing*4]),Color(_palette.road_highlight,.72),1.5,true)

func _road_open_sides(cell: Vector2i) -> Array[bool]:
	return [not _road_set.has(cell+Vector2i.LEFT),not _road_set.has(cell+Vector2i.UP),not _road_set.has(cell+Vector2i.RIGHT),not _road_set.has(cell+Vector2i.DOWN)]

func _draw_road_shape(rect: Rect2, open: Array[bool], color: Color, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = int(radius) if open[0] and open[1] else 0
	box.corner_radius_top_right = int(radius) if open[2] and open[1] else 0
	box.corner_radius_bottom_left = int(radius) if open[0] and open[3] else 0
	box.corner_radius_bottom_right = int(radius) if open[2] and open[3] else 0
	box.corner_detail = 8
	box.anti_aliasing = true
	draw_style_box(box,rect)


func _are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _draw_landmarks() -> void:
	var landmarks: Array = [[entry_cell,"gate"],[base_cell,"base"]]
	var entries := {entry_cell: true}
	for points in route_paths.values():
		var typed: Array[Vector2] = []
		typed.assign(points)
		var cells := derive_road_cells(typed)
		if not cells.is_empty() and not entries.has(cells[0]):
			entries[cells[0]] = true
			landmarks.append([cells[0],"gate"])
	for entry in landmarks:
		var cell: Vector2i = entry[0]
		if cell.x < 0: continue
		var center := cell_center(cell)
		if _camp_textures.has(entry[1]):
			draw_texture_rect(_camp_textures[entry[1]],Rect2(center-Vector2(40,48),Vector2(80,80)),false,_palette.tint)
		else:
			var color: Color = _palette.road_highlight
			draw_rect(Rect2(center+Vector2(-24,-27),Vector2(7,50)),color)
			draw_rect(Rect2(center+Vector2(17,-27),Vector2(7,50)),color)
			draw_rect(Rect2(center+Vector2(-26,-29),Vector2(52,7)),color)


func _draw_decorations() -> void:
	for cell in decor_cells:
		if not _decor_visible_at(cell): continue
		var kind := str(_decor_type_for_cell(cell))
		var key := "tree_1" if kind == "tree" and _cell_seed(cell)%2 else kind
		if kind == "tree" and theme_name == &"fire": key = "stump"
		var texture: Texture2D = _camp_textures.get(key,_decor_textures.get(kind))
		var center := cell_center(cell)
		if texture != null:
			var side := 66.0 + float(_cell_seed(cell)%9)
			draw_texture_rect(texture,Rect2(center-Vector2(side*.5,side*.5+4),Vector2.ONE*side),false,Color.WHITE if kind == "torch" else _palette.tint)
		else:
			draw_circle(center+Vector2(0,16),8.0,_palette.trunk)
			draw_circle(center+Vector2(0,2),14.0,_palette.leaf)

func _decor_visible_at(cell: Vector2i) -> bool:
	return not _road_set.has(cell) and not forbidden_cells.has(cell) and cell != entry_cell and cell != base_cell

static func _cell_seed(cell: Vector2i) -> int:
	return absi((cell.x*73856093) ^ (cell.y*19349663) ^ 83492791)


func _decor_type_for_cell(cell: Vector2i) -> StringName:
	if _decor_types.has(cell):
		var explicit_type: StringName = _decor_types[cell]
		if DECOR_TYPES.has(explicit_type):
			return explicit_type
	var roll: int = _cell_seed(cell) % 100
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
	# Small light pools belong to visible torches, never to every nth path tile.
	if not _palette.glow: return
	for cell in decor_cells:
		if not _decor_visible_at(cell) or _decor_type_for_cell(cell) != &"torch": continue
		for ring in range(9,0,-1):
			draw_circle(cell_center(cell)+Vector2(0,-11),float(ring)*4,Color(1,.69,.30,.011))


func cell_origin(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * GRID_SIZE, cell.y * GRID_SIZE)


func cell_center(cell: Vector2i) -> Vector2:
	return cell_origin(cell) + Vector2(GRID_SIZE, GRID_SIZE) * 0.5


## Derive in-map road cells by walking a stage path polyline cell-center to
## cell-center (orthogonal, 80px steps). Off-map stubs contribute no cells.
static func derive_road_cells(path_points: Array[Vector2]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in trace_road_cells(path_points):
		if not cells.has(cell): cells.append(cell)
	return cells


static func derive_stage_road_cells(stage: StageData) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for points in stage.get_paths().values():
		var typed: Array[Vector2] = []
		typed.assign(points)
		for cell in derive_road_cells(typed):
			if not cells.has(cell): cells.append(cell)
	return cells


## Ordered traversal keeps a repeated crossing; occupancy uses the unique set above.
static func trace_road_cells(path_points: Array[Vector2]) -> Array[Vector2i]:
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
			if cells.is_empty() or cells.back() != cell:
				cells.append(cell)
	return cells

