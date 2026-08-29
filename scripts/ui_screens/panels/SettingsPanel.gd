extends VBoxContainer

## 设置面板（GDD v0.10.1）：全屏切换、主音量；持久化至 user://settings.cfg。

const SETTINGS_PATH := "user://settings.cfg"
const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const TEXT_COLOR := Color(0.88, 0.9, 0.84)
const ACCENT_COLOR := Color(0.65, 0.84, 1.0)

var _fullscreen_button: Button
var _volume_slider: HSlider
var _volume_value_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_build_ui()
	_load_settings()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	add_child(title)

	_fullscreen_button = Button.new()
	_fullscreen_button.custom_minimum_size = Vector2(240, 46)
	_fullscreen_button.add_theme_font_size_override("font_size", 18)
	_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	add_child(_fullscreen_button)

	var volume_label := Label.new()
	volume_label.text = "主音量"
	volume_label.add_theme_font_size_override("font_size", 18)
	volume_label.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.custom_minimum_size = Vector2(280, 24)
	_volume_slider.value_changed.connect(_on_volume_changed)
	add_child(_volume_slider)

	_volume_value_label = Label.new()
	_volume_value_label.add_theme_font_size_override("font_size", 16)
	_volume_value_label.add_theme_color_override("font_color", ACCENT_COLOR)
	add_child(_volume_value_label)

	var note := Label.new()
	note.text = "更多设置（画质、按键等）将随后续版本加入。"
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.65, 0.67, 0.63))
	add_child(note)


func _load_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	var fullscreen: bool = config.get_value("display", "fullscreen", false)
	var volume: float = config.get_value("audio", "master_volume", 100.0)
	_apply_fullscreen(fullscreen)
	_volume_slider.set_value_no_signal(volume)
	_apply_volume(volume)
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
	config.save(SETTINGS_PATH)
