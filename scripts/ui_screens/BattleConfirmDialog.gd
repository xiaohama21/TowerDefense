class_name BattleConfirmDialog
extends Control

## 局内二次确认弹窗（v0.37.32）：顶栏「重开 / 退出」等不可逆操作防误触。
## 视觉走 Kenney DIALOG 语言（同 MainMenu「新的征程」确认弹窗 / 局内设置弹窗）：
## DIALOG_PANEL #f2faff 底 + DIALOG_BORDER 3px 描边（下边 7px 加粗）+ 圆角 18 + 底部投影，
## 蓝渐变标题条（DIALOG_HEAD）白字 + 圆形 ✕，正文深蓝墨字，底栏 灰「取消」+ 主按钮。
## 交互：ESC / ✕ / 取消 / 点击遮罩关闭；打开期间暂停战斗，关闭复原进入前暂停态。
## 挂在独立 CanvasLayer（layer 60，同设置弹窗）——位于局内 HUD 之上。

const LAYER_NAME := "BattleConfirmLayer"
const DIALOG_NAME := "BattleConfirmDialog"
const DIALOG_WIDTH := 560.0
const DIM_COLOR := Color(0.02, 0.05, 0.09, 0.62)

var _layer: CanvasLayer = null
var _confirm_action: Callable = Callable()
var _was_paused: bool = false
var _closed: bool = false


## 打开确认弹窗（host = 当前战斗节点）。on_confirm 在关闭后执行（不传参）。
static func open(host: Node, title: String, message: String, ok_text: String,
		on_confirm: Callable, cancel_text: String = "继续战斗",
		ok_color: String = "yellow") -> BattleConfirmDialog:
	if host == null or not host.is_inside_tree():
		return null
	var tree := host.get_tree()
	if tree == null:
		return null
	# 已有弹窗时不再叠加（顶栏可连点）。
	var existing := tree.root.get_node_or_null("%s/%s" % [LAYER_NAME, DIALOG_NAME])
	if existing != null:
		return existing as BattleConfirmDialog
	var layer := CanvasLayer.new()
	layer.name = LAYER_NAME
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(layer)
	var dialog := BattleConfirmDialog.new()
	dialog.name = DIALOG_NAME
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog._layer = layer
	dialog._confirm_action = on_confirm
	dialog._was_paused = tree.paused
	tree.paused = true
	layer.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog._build(title, message, ok_text, cancel_text, ok_color)
	return dialog


func _unhandled_input(event: InputEvent) -> void:
	if _closed:
		return
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		dismiss()


func _build(title: String, message: String, ok_text: String, cancel_text: String,
		ok_color: String) -> void:
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(DIALOG_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.DIALOG_PANEL
	style.border_color = UITheme.DIALOG_BORDER
	style.set_border_width_all(3)
	style.border_width_bottom = 7
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.02, 0.1, 0.18, 0.45)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	column.add_child(_make_header(title))
	column.add_child(_make_body(message))
	column.add_child(_make_actions(ok_text, cancel_text, ok_color))


## 蓝渐变标题条：白字标题 + 圆 ✕。
func _make_header(title: String) -> Panel:
	var header := Panel.new()
	header.custom_minimum_size = Vector2(0, 54)
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.DIALOG_HEAD
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	header.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20.0
	row.offset_right = -12.0
	row.add_theme_constant_override("separation", 10)
	header.add_child(row)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", UITheme.spaced_font(3))
	title_label.add_theme_font_size_override("font_size", 23)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(34, 34)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 17)
	UITheme.apply_kenney_rect_button(close_button, "red", Color.WHITE)
	close_button.pressed.connect(dismiss)
	row.add_child(close_button)
	return header


## 正文：提示 + 一句结果风险说明。
func _make_body(message: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 6)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	var text := Label.new()
	text.text = message
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", UITheme.DIALOG_TEXT)
	text.add_theme_constant_override("line_spacing", 4)
	box.add_child(text)
	return margin


## 底栏：左灰「取消」右主按钮（默认黄，「退出」传 red）。
func _make_actions(ok_text: String, cancel_text: String, ok_color: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 22)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	margin.add_child(actions)

	var cancel_button := Button.new()
	cancel_button.text = cancel_text
	cancel_button.custom_minimum_size = Vector2(160, 50)
	cancel_button.add_theme_font_size_override("font_size", 18)
	UITheme.apply_kenney_rect_button(cancel_button, "grey", UITheme.INK)
	cancel_button.pressed.connect(dismiss)
	actions.add_child(cancel_button)

	var confirm_button := Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = ok_text
	confirm_button.custom_minimum_size = Vector2(180, 50)
	confirm_button.add_theme_font_size_override("font_size", 18)
	UITheme.apply_kenney_rect_button(confirm_button, ok_color,
		Color.WHITE if ok_color == "red" else UITheme.INK)
	confirm_button.pressed.connect(_on_confirm_pressed)
	actions.add_child(confirm_button)
	return margin


func _on_confirm_pressed() -> void:
	var action := _confirm_action
	_confirm_action = Callable()
	close()
	if action.is_valid():
		action.call()


## 取消 / ✕ / ESC：仅关闭（恢复进入前暂停态）。
func dismiss() -> void:
	close()


func close() -> void:
	if _closed:
		return
	_closed = true
	var layer := _layer
	_layer = null
	if layer != null and is_instance_valid(layer):
		var tree := layer.get_tree()
		layer.queue_free()
		if tree != null:
			tree.paused = _was_paused
	else:
		queue_free()
