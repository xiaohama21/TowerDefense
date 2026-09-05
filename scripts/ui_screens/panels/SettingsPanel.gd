extends VBoxContainer

## 设置面板（GDD v0.10.1）：全屏切换、主音量；持久化至 user://settings.cfg。


var _fullscreen_button: Button
var _skip_dialogue_check: CheckButton
var _manual_ultimate_check: CheckButton
var _auto_next_wave_check: CheckButton
var _volume_slider: HSlider
var _volume_value_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_build_ui()
	_load_settings()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_override("font", UITheme.spaced_font(3))
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	add_child(title)

	# 显示分组（概念图 .panel：白底蓝灰描边圆角 14 + 虚线小节标题）
	add_child(_make_group("显示", _make_fullscreen_row()))
	add_child(_make_group("音频", _make_volume_row()))
	add_child(_make_group("玩法", _make_gameplay_rows()))

	var note := Label.new()
	note.text = "更多设置（画质、按键等）将随后续版本加入。"
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	add_child(note)


## 白底分组面板：小节标题（虚线下承）+ 内容行。
func _make_group(group_title: String, content: Control) -> Panel:
	var panel := Panel.new()
	var style := UITheme.light_panel_style()
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16.0
	box.offset_right = -16.0
	box.offset_top = 10.0
	box.offset_bottom = -14.0
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := Label.new()
	head.text = group_title
	head.add_theme_font_override("font", UITheme.spaced_font(2))
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	box.add_child(head)
	var divider := Panel.new()
	divider.custom_minimum_size = Vector2(0, 2)
	var divider_style := StyleBoxFlat.new()
	divider_style.bg_color = UITheme.LIGHT_PANEL_BORDER
	divider.add_theme_stylebox_override("panel", divider_style)
	box.add_child(divider)
	box.add_child(content)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func _make_fullscreen_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var hint := Label.new()
	hint.text = "切换游戏窗口 / 全屏显示模式"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	_fullscreen_button = Button.new()
	_fullscreen_button.custom_minimum_size = Vector2(280, 44)
	_fullscreen_button.focus_mode = Control.FOCUS_NONE
	_fullscreen_button.add_theme_font_size_override("font_size", 15)
	UITheme.apply_kenney_rect_button(_fullscreen_button, "blue", Color.WHITE)
	_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	row.add_child(_fullscreen_button)
	return row


func _make_volume_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var volume_label := Label.new()
	volume_label.text = "主音量"
	volume_label.add_theme_font_size_override("font_size", 16)
	volume_label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	row.add_child(volume_label)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.custom_minimum_size = Vector2(280, 24)
	_volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume_slider.value_changed.connect(_on_volume_changed)
	row.add_child(_volume_slider)
	_volume_value_label = Label.new()
	_volume_value_label.add_theme_font_size_override("font_size", 16)
	_volume_value_label.add_theme_color_override("font_color", UITheme.LIGHT_ACCENT)
	row.add_child(_volume_value_label)
	return row


func _make_gameplay_rows() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_skip_dialogue_check = _make_check("剧情速进（跳过开场对话）", _on_skip_dialogue_toggled)
	box.add_child(_skip_dialogue_check)
	_manual_ultimate_check = _make_check("大招手动释放（满怒后由你决定时机）", _on_manual_ultimate_toggled)
	box.add_child(_manual_ultimate_check)
	_auto_next_wave_check = _make_check("自动开启下一波（波次结束后自动开始）", _on_auto_next_wave_toggled)
	box.add_child(_auto_next_wave_check)
	return box


func _make_check(text: String, handler: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.add_theme_font_size_override("font_size", 16)
	check.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	check.toggled.connect(handler)
	return check


func _load_settings() -> void:
	var config := ConfigFile.new()
	config.load(GameFlow.SETTINGS_PATH)
	var fullscreen: bool = config.get_value("display", "fullscreen", false)
	var volume: float = config.get_value("audio", "master_volume", 100.0)
	var skip_dialogue: bool = config.get_value("gameplay", "skip_dialogue", false)
	var manual_ultimate: bool = config.get_value("gameplay", "manual_ultimate", false)
	var auto_next_wave: bool = config.get_value("gameplay", "auto_next_wave", false)
	_apply_fullscreen(fullscreen)
	_volume_slider.set_value_no_signal(volume)
	_apply_volume(volume)
	_skip_dialogue_check.set_pressed_no_signal(skip_dialogue)
	_manual_ultimate_check.set_pressed_no_signal(manual_ultimate)
	_auto_next_wave_check.set_pressed_no_signal(auto_next_wave)
	_refresh_fullscreen_text()


func _on_fullscreen_pressed() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_apply_fullscreen(not is_fullscreen)
	_refresh_fullscreen_text()
	_save_settings()


func _apply_fullscreen(fullscreen: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _refresh_fullscreen_text() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fullscreen_button.text = "显示模式：全屏（点击切换窗口）" if is_fullscreen else "显示模式：窗口（点击切换全屏）"


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	_save_settings()


func _apply_volume(volume: float) -> void:
	var linear := clampf(volume / 100.0, 0.0001, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(linear))
	AudioServer.set_bus_mute(0, volume <= 0.0)
	_volume_value_label.text = "%d%%" % int(volume)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen",
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.set_value("audio", "master_volume", _volume_slider.value)
	config.set_value("gameplay", "skip_dialogue", _skip_dialogue_check.button_pressed)
	config.set_value("gameplay", "manual_ultimate", _manual_ultimate_check.button_pressed)
	config.set_value("gameplay", "auto_next_wave", _auto_next_wave_check.button_pressed)
	config.save(GameFlow.SETTINGS_PATH)


func _on_skip_dialogue_toggled(pressed: bool) -> void:
	GameFlow.set_gameplay_flag("skip_dialogue", pressed)


func _on_manual_ultimate_toggled(pressed: bool) -> void:
	GameFlow.set_gameplay_flag("manual_ultimate", pressed)


func _on_auto_next_wave_toggled(pressed: bool) -> void:
	GameFlow.set_gameplay_flag("auto_next_wave", pressed)

