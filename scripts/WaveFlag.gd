extends Node2D
## 局内 HUD v2（0.8.17.0 / UI_LAYOUT §10 v0.20.41）：敌人出口道路上的波次旗帜——点击开波。
## v0.20.69（0.8.17.3 / B-093）：仅「可点击开波」时展示——点击开波即隐藏、波次完成重现；
## 自动接波开启后（首波之后）不再展示（Main 抑制）。Space 同效（Main 输入）。
## 表现 = 深墨绿圆底 + 暖金描边 + 透明波次旗帜图徽（裸符号落位，AGENTS §6）+ 指向出口的小箭头。

signal start_requested

const CORE_RADIUS := 26.0
const HALO_RADIUS := 36.0
const ARROW_DIST := 40.0
const COLOR_LINE := Color("#c9a35c")
const COLOR_BG_READY := Color("#22392b")
const COLOR_HALO := Color("#ffcc00")

var _can_start := false
var _finished := false
## 自动接波接管（B-093）：开启后后续波次由系统自动开启，旗帜不再展示。
var _suppressed := false
var _pulse := 0.0
var _texture: Texture2D = null
var _arrow_dir := Vector2.LEFT


func _ready() -> void:
	z_index = 8
	_texture = UITheme.hud_icon("wave_flag")
	UITheme.tune_hud_icon_item(self)
	var area := Area2D.new()
	area.name = "WaveFlagArea"
	area.input_event.connect(_on_area_input_event)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = CORE_RADIUS + 5.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	set_process(true)


## 由 Main 按 StageData 路径配置：位置 = 出怪点沿路径方向的偏移，箭头指向出口（反向）。
func configure(spawn_pos: Vector2, path_dir: Vector2) -> void:
	var dir := path_dir.normalized() if path_dir.length() > 0.001 else Vector2.RIGHT
	position = spawn_pos + dir * 52.0
	_arrow_dir = -dir
	queue_redraw()


## 波次状态（Main 在开波 / 波次完成 / 结算时刷新）。
## 可见规则（B-093）：仅「可点击开波」时可见（开波中 / 全波完成 / 基地陷落 / 自动接波接管一律隐藏）。
func set_wave_state(can_start: bool, finished: bool, suppressed: bool = false) -> void:
	_can_start = can_start
	_finished = finished
	_suppressed = suppressed
	visible = can_start and not suppressed
	queue_redraw()


func _process(delta: float) -> void:
	if _can_start and not _finished and not _suppressed:
		_pulse = fmod(_pulse + delta * 2.4, TAU)
		queue_redraw()


func _draw() -> void:
	if not _can_start or _finished or _suppressed:
		return
	var glow := 0.16 + 0.10 * (0.5 + 0.5 * sin(_pulse))
	draw_circle(Vector2.ZERO, HALO_RADIUS + 2.0 * sin(_pulse), Color(COLOR_HALO.r, COLOR_HALO.g, COLOR_HALO.b, glow))
	_draw_arrow()
	draw_circle(Vector2.ZERO, CORE_RADIUS, COLOR_BG_READY)
	draw_arc(Vector2.ZERO, CORE_RADIUS, 0.0, TAU, 44, COLOR_LINE, 3.0, true)
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2(-18, -18), Vector2(36, 36)), false, Color.WHITE)


## 小箭头：位于旗帜外侧、指向敌人出口（= 出怪点方向）。
func _draw_arrow() -> void:
	var tip := _arrow_dir * ARROW_DIST
	var side := _arrow_dir.orthogonal() * 9.0
	var base := tip - _arrow_dir * 13.0
	var color := Color(COLOR_HALO.r, COLOR_HALO.g, COLOR_HALO.b, 0.9)
	draw_polygon(
		PackedVector2Array([tip, base + side, base - side]),
		PackedColorArray([color, color, color])
	)


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _can_start or _finished or _suppressed:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			start_requested.emit()
			get_viewport().set_input_as_handled()
