extends Control

## 主菜单（GDD 阶段 1）：继续 / 新的征程 / 退出。UI 以代码构建。

const TITLE_TEXT := "烽火连营"
const SUBTITLE_TEXT := "三国塔防 · 第一章 黄巾之乱"
const BG_COLOR := Color(0.06, 0.09, 0.08)
const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const ACCENT_COLOR := Color(0.78, 0.92, 0.8)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BG_COLOR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	add_child(center)

	var title := Label.new()
	title.text = TITLE_TEXT
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)

	var subtitle := Label.new()
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	subtitle.text = SUBTITLE_TEXT if version.is_empty() else "%s  ·  v%s" % [SUBTITLE_TEXT, version]
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", ACCENT_COLOR)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(subtitle)

	center.add_child(_make_spacer(16))

	var has_save := GameFlow.has_existing_save()

	var continue_button := _make_menu_button("继续出征" if has_save else "开始游戏")
	continue_button.pressed.connect(func() -> void: GameFlow.goto_hub())
	center.add_child(continue_button)

	var new_game_button := _make_menu_button("新的征程")
	new_game_button.visible = has_save
	new_game_button.pressed.connect(_on_new_game_pressed)
	center.add_child(new_game_button)

	center.add_child(_make_spacer(12))

	var quit_button := _make_menu_button("退出游戏")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	center.add_child(quit_button)


func _on_new_game_pressed() -> void:
	if GameFlow.has_existing_save():
		var dialog := ConfirmationDialog.new()
		dialog.dialog_text = "开始新的征程将覆盖现有存档，确定继续？"
		dialog.ok_button_text = "覆盖并开始"
		dialog.cancel_button_text = "取消"
		dialog.confirmed.connect(_start_new_game)
		add_child(dialog)
		dialog.popup_centered()
	else:
		_start_new_game()


func _start_new_game() -> void:
	if not GameFlow.start_new_game():
		push_error("新档创建失败")
		return
	GameFlow.goto_hub()


func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 56)
	button.add_theme_font_size_override("font_size", 22)
	return button


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
