extends Control

## 游戏大厅（GDD v0.10.1）：左侧功能面板（地图选择/武将养成/设置 + 返回主菜单），
## 右侧内容区按所选功能切换。选关 → 编队 → 战斗；养成与设置不再各自独立成场景。

const BG_COLOR := Color(0.06, 0.09, 0.08)
const SIDEBAR_COLOR := Color(0.09, 0.13, 0.11)
const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const SUBTITLE_COLOR := Color(0.78, 0.92, 0.8)
const ACTIVE_COLOR := Color(1.0, 0.82, 0.3)

const MapPanelScript := preload("res://scripts/ui_screens/panels/MapPanel.gd")
const DevelopPanelScript := preload("res://scripts/ui_screens/panels/DevelopPanel.gd")
const SettingsPanelScript := preload("res://scripts/ui_screens/panels/SettingsPanel.gd")

var _buttons: Dictionary = {}
var _panels: Dictionary = {}
var _content: MarginContainer


func _ready() -> void:
	_build_ui()
	_show_panel(GameFlow.hub_active_panel)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BG_COLOR
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 0)
	add_child(columns)

	# 左侧功能面板
	var sidebar := PanelContainer.new()
	sidebar.name = "Sidebar"
	sidebar.custom_minimum_size = Vector2(250, 0)
	var sidebar_style := StyleBoxFlat.new()
	sidebar_style.bg_color = SIDEBAR_COLOR
	sidebar_style.border_width_right = 2
	sidebar_style.border_color = Color(0.25, 0.43, 0.38, 0.8)
	sidebar.add_theme_stylebox_override("panel", sidebar_style)
	columns.add_child(sidebar)

	var sidebar_margin := MarginContainer.new()
	sidebar_margin.name = "SidebarMargin"
	sidebar_margin.add_theme_constant_override("margin_left", 18)
	sidebar_margin.add_theme_constant_override("margin_right", 18)
	sidebar_margin.add_theme_constant_override("margin_top", 32)
	sidebar_margin.add_theme_constant_override("margin_bottom", 28)
	sidebar.add_child(sidebar_margin)

	var sidebar_box := VBoxContainer.new()
	sidebar_box.name = "SidebarBox"
	sidebar_box.add_theme_constant_override("separation", 12)
	sidebar_margin.add_child(sidebar_box)

	var title := Label.new()
	title.text = "烽火连营"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	sidebar_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "游戏大厅"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	sidebar_box.add_child(subtitle)

	sidebar_box.add_child(_make_spacer(14))

	_add_function_button(sidebar_box, &"map", "地图选择")
	_add_function_button(sidebar_box, &"develop", "武将养成")
	_add_function_button(sidebar_box, &"settings", "设置")

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_box.add_child(spacer)

	var back_button := Button.new()
	back_button.text = "返回主菜单"
	back_button.custom_minimum_size = Vector2(0, 44)
	back_button.add_theme_font_size_override("font_size", 17)
	back_button.pressed.connect(func() -> void: GameFlow.goto_menu())
	sidebar_box.add_child(back_button)

	var version: String = ProjectSettings.get_setting("application/config/version", "")
	if not version.is_empty():
		var version_label := Label.new()
		version_label.text = "v" + version
		version_label.add_theme_font_size_override("font_size", 13)
		version_label.add_theme_color_override("font_color", Color(0.55, 0.57, 0.53))
		sidebar_box.add_child(version_label)

	# 右侧内容区
	_content = MarginContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("margin_left", 32)
	_content.add_theme_constant_override("margin_right", 32)
	_content.add_theme_constant_override("margin_top", 28)
	_content.add_theme_constant_override("margin_bottom", 24)
	columns.add_child(_content)

	_panels[&"map"] = _make_panel("MapPanel", MapPanelScript)
	_panels[&"develop"] = _make_panel("DevelopPanel", DevelopPanelScript)
	_panels[&"settings"] = _make_panel("SettingsPanel", SettingsPanelScript)


func _make_panel(panel_name: String, script: GDScript) -> Control:
	var panel: Control = script.new()
	panel.name = panel_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if panel.has_signal("stage_selected"):
		panel.stage_selected.connect(_on_stage_selected)
	_content.add_child(panel)
	return panel


func _add_function_button(parent: Node, panel_id: StringName, label: String) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(_on_function_pressed.bind(panel_id))
	parent.add_child(button)
	_buttons[panel_id] = button


func _on_function_pressed(panel_id: StringName) -> void:
	_show_panel(panel_id)


func _on_stage_selected(stage_id: StringName) -> void:
	GameFlow.select_stage(stage_id)
	GameFlow.goto_squad_select()


func _show_panel(panel_id: StringName) -> void:
	GameFlow.hub_active_panel = panel_id
	for key in _panels.keys():
		_panels[key].visible = key == panel_id
	for key in _buttons.keys():
		var button := _buttons[key] as Button
		if is_instance_valid(button):
			button.set_pressed_no_signal(key == panel_id)
			button.add_theme_color_override("font_color",
				ACTIVE_COLOR if key == panel_id else Color(0.88, 0.9, 0.84))
	var panel: Control = _panels.get(panel_id)
	if panel != null and panel.has_method("_on_shown"):
		panel._on_shown()


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
