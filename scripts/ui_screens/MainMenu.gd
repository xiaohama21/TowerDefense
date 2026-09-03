extends Control

## 主菜单（GDD 阶段 1 / UI_LAYOUT §3）：按概念图 ui_home.png 的 Kenney 亮蓝换肤
## 首屏落地（v0.33.6 / 程序 0.8.8.6）。布局全代码构建：
## 天空三档渐变 + 柔光 + 星饰 → 标题区 → 三枚 Kenney 九宫格大按钮 → 底栏版本署名；
## 「新的征程」自绘白面确认弹窗（ui_dialog.png）。

const TITLE_TEXT := "烽火连营"
const SUBTITLE_TEXT := "三国塔防"
const CHAPTER_TEXT := "第一章 · 黄巾之乱"
const CREDIT_TEXT := "素材 Kenney UI Pack · 字体 站酷快乐体"
const VIEW_SIZE := Vector2(1280.0, 720.0)  # 分辨率固定（UI_LAYOUT 不做窗口自适应）

var _new_game_dialog: Control = null


func _ready() -> void:
	_build_background()
	_build_stage()
	_build_footer()


func _unhandled_key_input(event: InputEvent) -> void:
	if _new_game_dialog != null and event.is_action_pressed("ui_cancel"):
		_close_new_game_dialog()


# ---------- 背景：天空渐变 / 柔光 / 星饰（概念图 .bg + .bg-stars） ----------

func _build_background() -> void:
	var sky := TextureRect.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sky_gradient := Gradient.new()
	sky_gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	sky_gradient.colors = PackedColorArray([UITheme.SKY_TOP, UITheme.SKY_MID, UITheme.SKY_BOTTOM])
	var sky_texture := GradientTexture2D.new()
	sky_texture.gradient = sky_gradient
	sky_texture.fill_from = Vector2(0.5, 0.0)
	sky_texture.fill_to = Vector2(0.5, 1.0)
	sky_texture.width = 8
	sky_texture.height = 256
	sky.texture = sky_texture
	add_child(sky)

	_add_glow(Vector2(0.5, -0.08), Vector2(760, 420), 0.28)
	_add_glow(Vector2(0.90, 1.08), Vector2(560, 330), 0.13)
	_add_glow(Vector2(0.08, 1.10), Vector2(470, 290), 0.11)

	_add_star(Vector2(0.07, 0.14), 90.0)
	_add_star(Vector2(0.90, 0.12), 60.0)
	_add_star(Vector2(0.93, 0.70), 70.0)
	_add_star(Vector2(0.10, 0.78), 110.0)
	_add_star(Vector2(0.88, 0.90), 50.0)


func _add_glow(center_frac: Vector2, size: Vector2, alpha: float) -> void:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, alpha), Color(1, 1, 1, alpha * 0.5), Color(1, 1, 1, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	rect.texture = texture
	rect.position = Vector2(center_frac.x * VIEW_SIZE.x - size.x * 0.5, center_frac.y * VIEW_SIZE.y - size.y * 0.5)
	rect.size = size
	add_child(rect)


func _add_star(center_frac: Vector2, width: float) -> void:
	var star := TextureRect.new()
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.texture = load("res://assets/ui/icons/star_outline.png")
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.modulate = Color(1.6, 1.9, 2.1, 0.16)  # 概念图低透明度星形点缀（白色调淡）
	var height := width * 120.0 / 128.0
	star.size = Vector2(width, height)
	star.position = Vector2(center_frac.x * VIEW_SIZE.x - width * 0.5, center_frac.y * VIEW_SIZE.y - height * 0.5)
	add_child(star)


# ---------- 标题区 + 主按钮（概念图 .head + .menu） ----------

func _build_stage() -> void:
	var stage := VBoxContainer.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.offset_top = 24.0
	stage.add_theme_constant_override("separation", 0)
	add_child(stage)

	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(title, 78, Color.WHITE, 14, UITheme.STROKE, Vector2(0, 3), 4)
	stage.add_child(title)

	stage.add_child(_make_spacer(2))
	var subtitle := Label.new()
	subtitle.text = SUBTITLE_TEXT
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(subtitle, 25, UITheme.MIST, 24, UITheme.STROKE, Vector2(0, 2), 2)
	stage.add_child(subtitle)

	stage.add_child(_make_spacer(14))
	stage.add_child(_make_ornament())

	stage.add_child(_make_spacer(10))
	var chapter := Label.new()
	chapter.text = CHAPTER_TEXT
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(chapter, 19, UITheme.MIST, 6, UITheme.STROKE, Vector2(0, 1), 1)
	stage.add_child(chapter)

	var has_save := GameFlow.has_existing_save()
	stage.add_child(_make_spacer(24))

	var primary := _make_main_button("继续出征" if has_save else "开始游戏", "yellow", UITheme.INK)
	primary.pressed.connect(_on_primary_pressed)
	stage.add_child(primary)

	if has_save:
		stage.add_child(_make_spacer(16))
		var new_game_button := _make_main_button("新的征程", "red", Color.WHITE)
		new_game_button.pressed.connect(_on_new_game_pressed)
		stage.add_child(new_game_button)

	stage.add_child(_make_spacer(16))
	var quit_button := _make_main_button("退出游戏", "grey", UITheme.INK)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	stage.add_child(quit_button)


func _make_ornament() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hbox.add_theme_constant_override("separation", 12)
	hbox.add_child(_make_bar(120.0))
	var star := TextureRect.new()
	star.texture = load("res://assets/ui/icons/star.png")
	star.custom_minimum_size = Vector2(28, 26)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(star)
	hbox.add_child(_make_bar(120.0))
	return hbox


func _make_bar(width: float) -> Panel:
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(width, 5)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.5)
	style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("panel", style)
	return bar


# ---------- 按钮 / 文本 / 间距辅助 ----------

func _make_main_button(text: String, color_key: String, font_color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(296, 84)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", _spaced_font(8))
	button.add_theme_font_size_override("font_size", 38)
	UITheme.apply_kenney_rect_button(button, color_key, font_color)
	return button


func _spaced_font(spacing: int) -> Font:
	# 在全局主题字体（站酷快乐体 + 系统回退）上叠加字距，按钮/标题共用。
	var theme := load("res://assets/ui/ui_theme.tres") as Theme
	var variation := FontVariation.new()
	variation.base_font = theme.default_font
	variation.set_spacing(TextServer.SPACING_GLYPH, spacing)
	return variation


func _style_label(label: Label, font_size: int, color: Color, spacing: int, shadow_color: Color, shadow_offset: Vector2, shadow_blur: int) -> void:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	if shadow_blur > 0:
		settings.shadow_color = shadow_color
		settings.shadow_offset = shadow_offset
		settings.shadow_size = shadow_blur
	label.label_settings = settings
	# 字距通过字体变体叠加（LabelSettings 无 spacing 属性）
	label.add_theme_font_override("font", _spaced_font(spacing))


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


# ---------- 底栏：版本 + 素材署名 ----------

func _build_footer() -> void:
	var footer := HBoxContainer.new()
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 28.0
	footer.offset_right = -28.0
	footer.offset_top = -48.0
	footer.offset_bottom = -14.0
	footer.add_theme_constant_override("separation", 12)
	add_child(footer)

	var version: String = ProjectSettings.get_setting("application/config/version", "")
	var version_label := Label.new()
	version_label.text = "FengHuoLianYing · ALPHA %s" % version if not version.is_empty() else "FengHuoLianYing · ALPHA"
	_style_label(version_label, 17, UITheme.MIST, 2, UITheme.STROKE, Vector2(0, 1), 1)
	version_label.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_child(version_label)

	var credit := Label.new()
	credit.text = CREDIT_TEXT
	_style_label(credit, 15, UITheme.PALE, 2, Color(0, 0, 0, 0), Vector2.ZERO, 0)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credit.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_child(credit)


# ---------- 「新的征程」：主按钮跳转 / 自绘确认弹窗（ui_dialog.png） ----------

func _on_primary_pressed() -> void:
	GameFlow.goto_hub()


func _on_new_game_pressed() -> void:
	if not GameFlow.has_existing_save():
		_start_new_game()
		return
	_show_new_game_dialog()


func _show_new_game_dialog() -> void:
	if _new_game_dialog != null:
		return
	var overlay := Control.new()
	overlay.name = "NewGameDialog"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_new_game_dialog = overlay

	var dim := ColorRect.new()
	dim.color = Color(0.039, 0.149, 0.251, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(560, 296)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UITheme.DIALOG_PANEL
	panel_style.border_color = UITheme.DIALOG_BORDER
	panel_style.set_border_width_all(3)
	panel_style.border_width_bottom = 7
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.024, 0.11, 0.196, 0.5)
	panel_style.shadow_size = 18
	panel_style.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)

	panel.add_child(_make_dialog_header())
	panel.add_child(_make_dialog_body())
	var actions := _make_dialog_actions()
	panel.add_child(actions)

	add_child(overlay)
	var confirm_button := actions.get_node_or_null("ConfirmButton") as Button
	if confirm_button != null:
		confirm_button.call_deferred("grab_focus")


func _make_dialog_header() -> Panel:
	var header := Panel.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 3.0
	header.offset_right = -3.0
	header.offset_top = 3.0
	header.offset_bottom = 59.0
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = UITheme.DIALOG_HEAD
	header_style.set_corner_radius_all(0)
	header_style.corner_radius_top_left = 15
	header_style.corner_radius_top_right = 15
	header.add_theme_stylebox_override("panel", header_style)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 21.0
	row.offset_right = -10.0
	row.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "新的征程"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(title, 26, Color.WHITE, 6, Color("#0e5f92"), Vector2(0, 1), 1)
	row.add_child(title)

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.tooltip_text = "关闭"
	close_button.icon = load("res://assets/ui/icons/cross_blue.png")
	close_button.add_theme_constant_override("icon_max_width", 18)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(1, 1, 1, 0.28)
	close_style.set_corner_radius_all(16)
	var close_pressed := StyleBoxFlat.new()
	close_pressed.bg_color = Color(1, 1, 1, 0.45)
	close_pressed.set_corner_radius_all(16)
	close_button.add_theme_stylebox_override("normal", close_style)
	close_button.add_theme_stylebox_override("hover", close_style)
	close_button.add_theme_stylebox_override("pressed", close_pressed)
	close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_button.pressed.connect(_close_new_game_dialog)
	row.add_child(close_button)
	header.add_child(row)
	return header


func _make_dialog_body() -> MarginContainer:
	var body := MarginContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 26.0
	body.offset_right = -26.0
	body.offset_top = 59.0
	body.offset_bottom = -92.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	body.add_child(box)

	var main := Label.new()
	main.text = "新的征程将开启一份全新存档。"
	main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(main, 24, UITheme.DIALOG_TEXT, 1, Color(0, 0, 0, 0), Vector2.ZERO, 0)
	box.add_child(main)

	box.add_child(_make_spacer(8))
	var warn := Label.new()
	warn.text = "当前进度将被覆盖，且无法恢复。"
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(warn, 20, UITheme.DIALOG_WARN, 1, Color(0, 0, 0, 0), Vector2.ZERO, 0)
	box.add_child(warn)

	box.add_child(_make_spacer(10))
	var hint := Label.new()
	hint.text = "确定要放弃现有进度，从头开始吗？"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(hint, 15, UITheme.DIALOG_HINT, 1, Color(0, 0, 0, 0), Vector2.ZERO, 0)
	box.add_child(hint)
	return body


func _make_dialog_actions() -> HBoxContainer:
	var actions := HBoxContainer.new()
	actions.anchor_left = 1.0
	actions.anchor_right = 1.0
	actions.anchor_top = 1.0
	actions.anchor_bottom = 1.0
	actions.offset_left = -356.0
	actions.offset_right = -22.0
	actions.offset_top = -86.0
	actions.offset_bottom = -18.0
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 14)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.custom_minimum_size = Vector2(160, 68)
	cancel_button.add_theme_font_override("font", _spaced_font(4))
	cancel_button.add_theme_font_size_override("font_size", 28)
	UITheme.apply_kenney_rect_button(cancel_button, "grey", UITheme.INK)
	cancel_button.pressed.connect(_close_new_game_dialog)
	actions.add_child(cancel_button)

	var confirm_button := Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = "继续"
	confirm_button.custom_minimum_size = Vector2(160, 68)
	confirm_button.add_theme_font_override("font", _spaced_font(4))
	confirm_button.add_theme_font_size_override("font_size", 28)
	UITheme.apply_kenney_rect_button(confirm_button, "red", Color.WHITE)
	confirm_button.pressed.connect(_on_dialog_confirm)
	actions.add_child(confirm_button)
	return actions


func _on_dialog_confirm() -> void:
	_close_new_game_dialog()
	_start_new_game()


func _close_new_game_dialog() -> void:
	if _new_game_dialog == null:
		return
	_new_game_dialog.queue_free()
	_new_game_dialog = null


func _start_new_game() -> void:
	if not GameFlow.start_new_game():
		push_error("新档创建失败")
		return
	GameFlow.goto_hub()

