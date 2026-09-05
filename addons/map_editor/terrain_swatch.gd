@tool
extends Button

## 地形样块按钮（地图编辑器笔刷地形栏，v0.8）：在按钮内容区自绘地形预览——
## 装饰四类直接加载 assets/map/decor/*.png 素材图（缺失回退程序化绘制），
## 路径/禁建/建造位/擦除按运行时同源视觉程序化预览；选中态金框高亮。

const SWATCH := 52.0
const PAD_TOP := 6.0

## road / tree / rock / banner / torch / mountain / slot / erase
var terrain_id := &""
var display_name := ""

var _font: Font


func _ready() -> void:
	toggle_mode = true
	custom_minimum_size = Vector2(76, 84)
	focus_mode = Control.FOCUS_NONE
	_font = load("res://assets/fonts/ZCOOL-Kuaile.ttf")
	pressed.connect(queue_redraw)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


func _draw() -> void:
	var rect := Rect2(Vector2((size.x - SWATCH) * 0.5, PAD_TOP), Vector2(SWATCH, SWATCH))
	match terrain_id:
		&"road":
			_draw_road(rect)
		&"tree", &"rock", &"banner", &"torch":
			_draw_decor(rect)
		&"mountain":
			_draw_mountain(rect)
		&"slot":
			_draw_slot(rect)
		&"erase":
			_draw_erase(rect)
		_:
			draw_rect(rect, Color(0.3, 0.3, 0.3, 0.6))
	if button_pressed:
		draw_rect(rect.grow(3.0), Color(1.0, 0.85, 0.4, 0.95), false, 3.0)
	if _font != null and not display_name.is_empty():
		var text_pos := Vector2(size.x * 0.5 - display_name.length() * 8.0, size.y - 6.0)
		draw_string(_font, text_pos, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.94, 0.96))


## 道路格预览（同 GridBackground 道路配色：棕底 + 深边 + 中央高亮线）。
func _draw_road(rect: Rect2) -> void:
	draw_rect(rect, Color(0.47, 0.34, 0.24))
	draw_rect(rect, Color(0.15, 0.12, 0.1), false, 2.0)
	draw_line(
		Vector2(rect.position.x + 6, rect.get_center().y),
		Vector2(rect.end.x - 6, rect.get_center().y),
		Color(0.66, 0.51, 0.34, 0.6), 3.0
	)


## 装饰预览：素材图优先（assets/map/decor/<id>.png），缺失回退程序化绘制。
func _draw_decor(rect: Rect2) -> void:
	var path := "res://assets/map/decor/%s.png" % terrain_id
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			draw_texture_rect(tex, rect.grow(-4.0), false)
			return
	var center := rect.get_center()
	match terrain_id:
		&"tree":
			draw_circle(center + Vector2(0, 10), 9.0, Color(0.3, 0.22, 0.14))
			draw_circle(center + Vector2(0, -2), 16.0, Color(0.2, 0.42, 0.28))
		&"rock":
			draw_circle(center, 14.0, Color(0.45, 0.45, 0.42))
		&"banner":
			draw_rect(Rect2(center + Vector2(-2, -14), Vector2(4, 30)), Color(0.3, 0.22, 0.14))
			draw_rect(Rect2(center + Vector2(2, -14), Vector2(16, 12)), Color(0.78, 0.62, 0.36))
		&"torch":
			draw_rect(Rect2(center + Vector2(-2, -2), Vector2(4, 18)), Color(0.3, 0.22, 0.14))
			draw_circle(center + Vector2(0, -8), 7.0, Color(0.95, 0.6, 0.3))


## 禁建山地预览（同 GridBackground._draw_forbidden：深色格 + 双峰）。
func _draw_mountain(rect: Rect2) -> void:
	draw_rect(rect, Color(0.33, 0.31, 0.27))
	draw_rect(rect, Color(0.52, 0.44, 0.32), false, 2.0)
	var center := rect.get_center()
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-20, 12), center + Vector2(0, -18), center + Vector2(20, 12),
	]), Color(0.24, 0.3, 0.24))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-6, 12), center + Vector2(8, -8), center + Vector2(22, 12),
	]), Color(0.34, 0.42, 0.34))


## 建造位预览（同覆盖层：淡填充 + 白色虚线圈）。
func _draw_slot(rect: Rect2) -> void:
	draw_rect(rect, Color(0.1, 0.2, 0.14))
	var center := rect.get_center()
	draw_circle(center, 20.0, Color(1, 1, 1, 0.08))
	_draw_dashed_arc(center, 20.0, Color(1, 1, 1, 0.7))


func _draw_dashed_arc(center: Vector2, radius: float, color: Color) -> void:
	const SEGMENTS := 24
	const STEP := TAU / SEGMENTS
	for i in range(SEGMENTS):
		if i % 2 == 0:
			var start_angle := i * STEP
			draw_arc(center, radius, start_angle, start_angle + STEP, 3, color, 2.0, true)


## 擦除预览：暗格 + 红叉。
func _draw_erase(rect: Rect2) -> void:
	draw_rect(rect, Color(0.16, 0.12, 0.12))
	draw_rect(rect, Color(0.5, 0.3, 0.28), false, 2.0)
	var a := rect.position + Vector2(12, 12)
	var b := rect.end - Vector2(12, 12)
	draw_line(a, b, Color(1, 0.45, 0.4, 0.9), 4.0)
	draw_line(Vector2(b.x, a.y), Vector2(a.x, b.y), Color(1, 0.45, 0.4, 0.9), 4.0)
