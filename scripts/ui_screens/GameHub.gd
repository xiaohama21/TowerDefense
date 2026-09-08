extends Control

## 游戏大厅（GDD v0.10.1 / UI_LAYOUT §4）：按概念图 ui_hub_map.png 的 Kenney 亮蓝
## 换肤落地（v0.18.0 / 程序 0.8.10.11，参照首页 ui_home 同套视觉令牌）：
## 天空三档渐变 + 顶部柔光 → 居中圆角大面板 → 左侧 204px 亮蓝侧栏（Kenney 导航：
## 选中蓝 gloss 白字 / 未选灰 flat 深蓝字、底部红「返回主菜单」）→ 右侧内容区。

const NAV_DEFS := [
	[&"map", "地图选择"], [&"develop", "武将养成"], [&"tech", "科技树"],
	[&"inventory", "背包"], [&"settings", "设置"], [&"encyclopedia", "百科"],
]

const MapPanelScript := preload("res://scripts/ui_screens/panels/MapPanel.gd")
const DevelopPanelScript := preload("res://scripts/ui_screens/panels/DevelopPanel.gd")
const SettingsPanelScript := preload("res://scripts/ui_screens/panels/SettingsPanel.gd")
const TechPanelScript := preload("res://scripts/ui_screens/panels/TechPanel.gd")
const InventoryPanelScript := preload("res://scripts/ui_screens/panels/InventoryPanel.gd")
const EncyclopediaPanelScript := preload("res://scripts/ui_screens/panels/EncyclopediaPanel.gd")

## 概念图色板（src/ui_hub_map.html）
const HUB_PANEL := Color("#f2faff")
const HUB_BORDER := Color("#1c9fd7")
const HUB_BORDER_BOTTOM := Color("#167da8")
const SIDEBAR_TOP := Color("#e9f6fd")
const SIDEBAR_BOTTOM := Color("#dcedf8")
const SIDEBAR_EDGE := Color("#bfe2f4")
const NAV_IDLE_TEXT := Color("#33566f")
const LOGO_TEXT := Color("#14538a")
const SUB_TEXT := Color("#7d9cb4")

var _buttons: Dictionary = {}
var _panels: Dictionary = {}
var _content: MarginContainer


func _ready() -> void:
	_build_background()
	_build_hub()
	_show_panel(GameFlow.hub_active_panel)


# ---------- 背景：天空渐变 + 顶部柔光（概念图 .bg，同首页视觉） ----------

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

	var glow := TextureRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.28), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	glow.texture = texture
	glow.position = Vector2(640 - 380, -160)
	glow.size = Vector2(760, 420)
	add_child(glow)


# ---------- 大面板：左侧导航 + 右侧内容（概念图 .hub / .side / .main） ----------

func _build_hub() -> void:
	# 圆角大面板（概念图 .hub：上 36 / 左右 24 / 下 36 边距直接作锚点偏移）
	var panel := Panel.new()
	panel.name = "HubPanel"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24.0
	panel.offset_right = -24.0
	panel.offset_top = 36.0
	panel.offset_bottom = -36.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = HUB_PANEL
	panel_style.border_color = HUB_BORDER
	panel_style.set_border_width_all(3)
	panel_style.border_width_bottom = 7
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.024, 0.11, 0.196, 0.45)
	panel_style.shadow_size = 26
	panel_style.shadow_offset = Vector2(0, 12)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", 0)
	panel.add_child(columns)

	columns.add_child(_build_sidebar())

	# 右侧内容区（概念图 .main：上 14 / 左右 20 / 下 12）
	_content = MarginContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("margin_left", 20)
	_content.add_theme_constant_override("margin_right", 20)
	_content.add_theme_constant_override("margin_top", 14)
	_content.add_theme_constant_override("margin_bottom", 12)
	columns.add_child(_content)

	_panels[&"map"] = _make_panel("MapPanel", MapPanelScript)
	_panels[&"develop"] = _make_panel("DevelopPanel", DevelopPanelScript)
	_panels[&"tech"] = _make_panel("TechPanel", TechPanelScript)
	_panels[&"inventory"] = _make_panel("InventoryPanel", InventoryPanelScript)
	_panels[&"settings"] = _make_panel("SettingsPanel", SettingsPanelScript)
	_panels[&"encyclopedia"] = _make_panel("EncyclopediaPanel", EncyclopediaPanelScript)


func _build_sidebar() -> Control:
	var sidebar := Panel.new()
	sidebar.name = "Sidebar"
	sidebar.custom_minimum_size = Vector2(204, 0)
	var sidebar_style := StyleBoxFlat.new()
	sidebar_style.bg_color = SIDEBAR_TOP
	sidebar_style.border_color = SIDEBAR_EDGE
	sidebar_style.border_width_right = 3
	sidebar.add_theme_stylebox_override("panel", sidebar_style)
	sidebar.size_flags_vertical = Control.SIZE_FILL

	var margin := MarginContainer.new()
	margin.name = "SidebarMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	sidebar.add_child(margin)

	var sidebar_box := VBoxContainer.new()
	sidebar_box.name = "SidebarBox"
	sidebar_box.add_theme_constant_override("separation", 9)
	margin.add_child(sidebar_box)

	# logo（概念图 .logo：中文名 + 英文副标 + 虚线分隔）
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", 0)
	var title := Label.new()
	title.text = "烽火连营"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UITheme.spaced_font(2))
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", LOGO_TEXT)
	logo.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "TOWER DEFENSE · HUB"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", SUB_TEXT)
	logo.add_child(subtitle)
	sidebar_box.add_child(logo)

	var divider := Panel.new()
	divider.custom_minimum_size = Vector2(0, 2)
	var divider_style := StyleBoxFlat.new()
	divider_style.bg_color = Color("#9fd0ea")
	divider_style.set_corner_radius_all(1)
	divider.add_theme_stylebox_override("panel", divider_style)
	sidebar_box.add_child(divider)

	var nav_spacer := Control.new()
	nav_spacer.custom_minimum_size = Vector2(0, 4)
	sidebar_box.add_child(nav_spacer)

	for nav_def in NAV_DEFS:
		_add_function_button(sidebar_box, nav_def[0], nav_def[1])

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_box.add_child(bottom_spacer)

	var back_button := Button.new()
	back_button.text = "返回主菜单"
	back_button.custom_minimum_size = Vector2(0, 50)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_override("font", UITheme.spaced_font(2))
	back_button.add_theme_font_size_override("font_size", 18)
	UITheme.apply_kenney_rect_button(back_button, "red", Color.WHITE)
	back_button.pressed.connect(func() -> void: GameFlow.goto_menu())
	sidebar_box.add_child(back_button)

	var version: String = ProjectSettings.get_setting("application/config/version", "")
	if not version.is_empty():
		var version_label := Label.new()
		version_label.text = "v" + version
		version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		version_label.add_theme_font_size_override("font_size", 12)
		version_label.add_theme_color_override("font_color", SUB_TEXT)
		sidebar_box.add_child(version_label)
	return sidebar


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
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UITheme.spaced_font(3))
	button.add_theme_font_size_override("font_size", 21)
	button.pressed.connect(_on_function_pressed.bind(panel_id))
	parent.add_child(button)
	_buttons[panel_id] = button


func _on_function_pressed(panel_id: StringName) -> void:
	_show_panel(panel_id)


func _on_stage_selected(stage_id: StringName, difficulty: int) -> void:
	GameFlow.select_stage(stage_id)
	GameFlow.goto_squad_select(difficulty)


func _show_panel(panel_id: StringName) -> void:
	GameFlow.hub_active_panel = panel_id
	for key in _panels.keys():
		_panels[key].visible = key == panel_id
	for key in _buttons.keys():
		var button := _buttons[key] as Button
		if is_instance_valid(button):
			var active: bool = key == panel_id
			button.set_pressed_no_signal(active)
			# Kenney 换肤（v0.18.0）：选中=蓝 gloss 白字，未选=灰 flat 深蓝字。
			UITheme.apply_kenney_rect_button(button, "blue" if active else "grey",
				Color.WHITE if active else NAV_IDLE_TEXT)
	var panel: Control = _panels.get(panel_id)
	if panel != null and panel.has_method("_on_shown"):
		panel._on_shown()
