extends SceneTree

## 装饰素材生成工具（v0.16.0，GDD 5.7 第三步）：把程序化装饰"素材化"——
## 生成 assets/decor/ 下的 PNG 纹理（树/石头/旗帜/火把），GridBackground 直接
## 加载纹理绘制（布局数据不变），后续可被手绘素材直接替换。
## 运行：godot --headless --path . --script res://tools/generate_decor.gd

const SIZE := 64
const OUT_DIR := "res://assets/decor"


func _initialize() -> void:
	_generate_tree()
	_generate_rock()
	_generate_banner()
	_generate_torch()
	quit(0)


func _save(name: String, image: Image) -> void:
	var err := image.save_png("%s/%s.png" % [OUT_DIR, name])
	if err != OK:
		push_error("保存 %s 失败：%d" % [name, err])


func _new_image() -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


## 树：棕树干 + 三层绿色树冠（矢量风格）。
func _generate_tree() -> void:
	var image := _new_image()
	_fill_rect(image, Rect2i(28, 40, 8, 14), Color(0.35, 0.22, 0.12))
	_fill_circle(image, Vector2i(32, 26), 14, Color(0.18, 0.42, 0.24))
	_fill_circle(image, Vector2i(22, 30), 11, Color(0.24, 0.5, 0.28))
	_fill_circle(image, Vector2i(42, 30), 11, Color(0.22, 0.47, 0.26))
	_fill_circle(image, Vector2i(32, 18), 10, Color(0.3, 0.58, 0.32))
	_save("tree", image)


## 石头：灰岩多边形 + 高光。
func _generate_rock() -> void:
	var image := _new_image()
	_fill_circle(image, Vector2i(32, 34), 16, Color(0.42, 0.44, 0.42))
	_fill_circle(image, Vector2i(24, 38), 10, Color(0.38, 0.4, 0.38))
	_fill_circle(image, Vector2i(40, 37), 9, Color(0.45, 0.47, 0.45))
	_fill_circle(image, Vector2i(30, 28), 7, Color(0.55, 0.56, 0.53))
	_save("rock", image)


## 旗帜：金边三角旗（三国风格）。
func _generate_banner() -> void:
	var image := _new_image()
	_fill_rect(image, Rect2i(14, 14, 3, 36), Color(0.3, 0.18, 0.1))
	_fill_triangle(image, Vector2i(17, 14), Vector2i(17, 34), Vector2i(44, 30), Color(0.62, 0.14, 0.12))
	_fill_triangle(image, Vector2i(17, 34), Vector2i(17, 44), Vector2i(34, 40), Color(0.5, 0.1, 0.1))
	_save("banner", image)


## 火把：木柄 + 橙黄火焰（夜战氛围）。
func _generate_torch() -> void:
	var image := _new_image()
	_fill_rect(image, Rect2i(30, 30, 4, 24), Color(0.35, 0.22, 0.12))
	_fill_circle(image, Vector2i(32, 34), 5, Color(0.3, 0.18, 0.1))
	_fill_circle(image, Vector2i(32, 24), 9, Color(0.95, 0.55, 0.15))
	_fill_circle(image, Vector2i(32, 21), 6, Color(1.0, 0.82, 0.3))
	_save("torch", image)


func _fill_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	var radius_sq := radius * radius
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
				continue
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy <= radius_sq:
				image.set_pixel(x, y, color)


func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
				image.set_pixel(x, y, color)


## 三角形填充（半平面法），用于三角旗。
func _fill_triangle(image: Image, a: Vector2i, b: Vector2i, c: Vector2i, color: Color) -> void:
	var min_x := mini(a.x, mini(b.x, c.x))
	var max_x := maxi(a.x, maxi(b.x, c.x))
	var min_y := mini(a.y, mini(b.y, c.y))
	var max_y := maxi(a.y, maxi(b.y, c.y))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var point := Vector2(x + 0.5, y + 0.5)
			if _inside_triangle(point, a, b, c):
				image.set_pixel(x, y, color)


func _inside_triangle(p: Vector2, a: Vector2i, b: Vector2i, c: Vector2i) -> bool:
	var av := Vector2(a)
	var bv := Vector2(b)
	var cv := Vector2(c)
	var d1 := _cross(p - av, bv - av)
	var d2 := _cross(p - bv, cv - bv)
	var d3 := _cross(p - cv, av - cv)
	var has_neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_neg and has_pos)


func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x