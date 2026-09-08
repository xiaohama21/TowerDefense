class_name DashedPill
extends MarginContainer
## 概念图虚线胶囊（转职详情 .ptip/.pfoot 等）：浅色圆角底 + 1px 虚线描边。
## Godot 的 StyleBoxFlat 不支持 dashed border，这里在 _draw 里沿轮廓相位自绘。

var _bg_color := Color("#eef6fb")
var _dash_color := Color("#bfdcef")
var _radius := 10.0
var _bg_style: StyleBoxFlat


func setup(bg_color: Color, dash_color: Color, radius: float = 10.0) -> void:
	_bg_color = bg_color
	_dash_color = dash_color
	_radius = radius
	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = _bg_color
	_bg_style.set_corner_radius_all(int(_radius))
	_bg_style.anti_aliasing = true
	queue_redraw()


func _draw() -> void:
	if size.y < 4.0:
		return
	if _bg_style == null:
		_bg_style = StyleBoxFlat.new()
		_bg_style.bg_color = _bg_color
		_bg_style.set_corner_radius_all(int(_radius))
	draw_style_box(_bg_style, Rect2(Vector2.ZERO, size))
	_draw_dashed_border(Rect2(Vector2.ZERO, size).grow(-0.5))


func _draw_dashed_border(rect: Rect2) -> void:
	var pts := _rounded_rect_path(rect)
	if pts.size() < 4:
		return
	var dash_len := 7.0
	var gap_len := 5.0
	var cycle := dash_len + gap_len
	var cumulative := 0.0
	for i in range(1, pts.size()):
		var seg_len := pts[i].distance_to(pts[i - 1])
		if seg_len <= 0.001:
			continue
		if fmod(cumulative, cycle) < dash_len:
			draw_line(pts[i - 1], pts[i], _dash_color, 1.0)
		cumulative += seg_len


func _rounded_rect_path(rect: Rect2) -> PackedVector2Array:
	var r := minf(_radius, minf(rect.size.x, rect.size.y) * 0.5)
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x
	var y1 := rect.end.y
	var pts := PackedVector2Array()
	_append_edge(pts, Vector2(x0 + r, y0), Vector2(x1 - r, y0))
	_append_arc(pts, Vector2(x1 - r, y0 + r), r, -PI / 2.0, 0.0)
	_append_edge(pts, Vector2(x1, y0 + r), Vector2(x1, y1 - r))
	_append_arc(pts, Vector2(x1 - r, y1 - r), r, 0.0, PI / 2.0)
	_append_edge(pts, Vector2(x1 - r, y1), Vector2(x0 + r, y1))
	_append_arc(pts, Vector2(x0 + r, y1 - r), r, PI / 2.0, PI)
	_append_edge(pts, Vector2(x0, y1 - r), Vector2(x0, y0 + r))
	_append_arc(pts, Vector2(x0 + r, y0 + r), r, PI, PI * 1.5)
	return pts


func _append_edge(pts: PackedVector2Array, a: Vector2, b: Vector2) -> void:
	var count := maxi(1, int(ceil(a.distance_to(b))))
	for i in range(count + 1):
		pts.append(a.lerp(b, float(i) / float(count)))


func _append_arc(pts: PackedVector2Array, center: Vector2, radius: float, a0: float, a1: float) -> void:
	var count := maxi(4, int(ceil(radius * PI * 0.5)))
	for i in range(count + 1):
		var ang := lerpf(a0, a1, float(i) / float(count))
		pts.append(center + Vector2(cos(ang), sin(ang)) * radius)
