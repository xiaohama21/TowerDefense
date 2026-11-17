extends Control

## CITY v0.2: illustrated camp, shared panels, progress-gated entry points.
const PANEL_SCRIPTS := {
	&"map": preload("res://scripts/ui_screens/panels/MapPanel.gd"),
	&"develop": preload("res://scripts/ui_screens/panels/DevelopPanel.gd"),
	&"settings": preload("res://scripts/ui_screens/panels/SettingsPanel.gd"),
	&"tech": preload("res://scripts/ui_screens/panels/TechPanel.gd"),
	&"inventory": preload("res://scripts/ui_screens/panels/InventoryPanel.gd"),
	&"encyclopedia": preload("res://scripts/ui_screens/panels/EncyclopediaPanel.gd"),
	&"supply": preload("res://scripts/ui_screens/panels/SupplyDepotPanel.gd"),
	&"shop": preload("res://scripts/ui_screens/panels/ShopPanel.gd"),
}
const PANEL_NAMES := {&"map":"MapPanel", &"develop":"DevelopPanel", &"settings":"SettingsPanel", &"tech":"TechPanel", &"inventory":"InventoryPanel", &"encyclopedia":"EncyclopediaPanel", &"supply":"SupplyDepotPanel", &"shop":"ShopPanel"}
const Building := preload("res://scripts/ui_screens/city_building.gd")
var city_palette := "dusk"
var _buttons: Dictionary = {}
var _panels: Dictionary = {}
var _content: MarginContainer
var _city: Control
var _hub_panel: Panel
var _system_menu: PanelContainer
var _intro: Control
var _intro_id: StringName
var _hint: Label
var _balances: HBoxContainer
var _title_icon: TextureRect
var _quit_dialog: ConfirmationDialog
var _command: VBoxContainer
var _supply_button: Button

func _ready() -> void:
	_build_city()
	_build_hub()
	_build_system_menu()
	resized.connect(_fit_city)
	_fit_city()
	refresh_city()
	var initial := GameFlow.hub_active_panel
	_show_panel(initial, false)

func _label(value: String, pixels: int = 18, color := Color("#eddfbd")) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", pixels)
	node.add_theme_color_override("font_color", color)
	return node

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 40)
	button.pressed.connect(callback)
	UITheme.apply_kenney_rect_button(button, "grey", UITheme.INK)
	return button

func _build_city() -> void:
	var fill := ColorRect.new()
	fill.color = Color("#173832")
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	_city = Control.new()
	_city.name = "City"
	_city.size = Vector2(1280,720)
	add_child(_city)
	var bg := TextureRect.new()
	bg.name = "Backdrop"
	bg.texture = load("res://assets/city/%s/background.svg" % city_palette)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.size = Vector2(1280,720)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_city.add_child(bg)
	for data in CityRegistry.all():
		if not data.building: continue
		var button := Building.new()
		button.name = "Building_" + str(data.entry_id)
		button.data = data
		button.palette = city_palette
		button.position = data.position - Vector2(100,80)
		button.pressed.connect(_show_panel.bind(data.entry_id))
		button.mouse_entered.connect(_describe.bind(data.entry_id))
		button.focus_entered.connect(_describe.bind(data.entry_id))
		button.mouse_exited.connect(_reset_hint)
		_city.add_child(button)
		_buttons[data.entry_id] = button
	var bar := Panel.new()
	bar.position = Vector2(28,20)
	bar.size = Vector2(486,54)
	bar.add_theme_stylebox_override("panel", _city_plate(Color("#192e29f2"),Color("#ab8955")))
	_city.add_child(bar)
	_balances = HBoxContainer.new()
	_balances.position = Vector2(18,9)
	_balances.add_theme_constant_override("separation",14)
	bar.add_child(_balances)
	_hint = _label("点击建筑进入；ESC返回。",17)
	var hint_plate := Panel.new()
	hint_plate.position = Vector2(28,638)
	hint_plate.size = Vector2(1130,34)
	hint_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_plate.add_theme_stylebox_override("panel",_city_plate(Color("#172c25d9"),Color("#6e7657")))
	_city.add_child(hint_plate)
	_hint.position = Vector2(42,640)
	_hint.size = Vector2(1100,30)
	_hint.add_theme_color_override("font_shadow_color",Color("#142a29"))
	_hint.add_theme_constant_override("shadow_offset_x",1)
	_hint.add_theme_constant_override("shadow_offset_y",1)
	_city.add_child(_hint)

func _city_plate(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.04,0.1,0.07,0.4)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0,3)
	return style

func _fit_city() -> void:
	if _city == null: return
	var factor := minf(size.x/1280.0,size.y/720.0)
	_city.scale = Vector2.ONE*factor
	_city.position = (size-Vector2(1280,720)*factor)*.5

func _build_hub() -> void:
	_hub_panel = Panel.new()
	_hub_panel.name = "HubPanel"
	_hub_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hub_panel.offset_left=80; _hub_panel.offset_right=-80
	_hub_panel.offset_top=16; _hub_panel.offset_bottom=-16
	_hub_panel.add_theme_stylebox_override("panel", UITheme.light_panel_style())
	add_child(_hub_panel)
	var columns := Control.new()
	columns.name = "Columns"
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hub_panel.add_child(columns)
	_content = MarginContainer.new()
	_content.name = "Content"
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_theme_constant_override("margin_left",20)
	_content.add_theme_constant_override("margin_right",20)
	_content.add_theme_constant_override("margin_top",50)
	_content.add_theme_constant_override("margin_bottom",12)
	columns.add_child(_content)
	for id in PANEL_SCRIPTS:
		var panel: Control = PANEL_SCRIPTS[id].new()
		panel.name = PANEL_NAMES[id]
		if panel.has_signal("stage_selected"): panel.stage_selected.connect(_on_stage_selected)
		_content.add_child(panel)
		_panels[id] = panel
	_command = VBoxContainer.new()
	_command.name = "CommandPanel"
	_command.add_theme_constant_override("separation",18)
	_content.add_child(_command)
	_panels[&"command"] = _command
	_title_icon = TextureRect.new()
	_title_icon.position = Vector2(22,0)
	_title_icon.size = Vector2(58,44)
	_title_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hub_panel.add_child(_title_icon)
	var back := _button("返回",_show_panel.bind(&"city"))
	back.name = "BackToCity"
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left=-250;back.offset_right=-110;back.offset_top=4;back.offset_bottom=44
	_hub_panel.add_child(back)

func _build_system_menu() -> void:
	var menu := _button("☰",func(): _system_menu.visible = not _system_menu.visible)
	menu.name = "SystemMenuButton"
	menu.tooltip_text = "设置与退出"
	menu.custom_minimum_size = Vector2(56,50)
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_left=-112;menu.offset_right=-40;menu.offset_top=20;menu.offset_bottom=68
	for state in ["normal","hover","pressed","hover_pressed","focus"]:
		menu.add_theme_stylebox_override(state,_city_plate(Color("#284137") if state=="hover" else Color("#192e29"),Color("#dfb76b") if state=="focus" else Color("#ab8955")))
	for color_name in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		menu.add_theme_color_override(color_name,Color("#f0d49a"))
	add_child(menu)
	_system_menu = PanelContainer.new()
	_system_menu.name = "SystemMenu"
	_system_menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_system_menu.offset_left=-270;_system_menu.offset_right=-40;_system_menu.offset_top=78
	_system_menu.add_theme_stylebox_override("panel",UITheme.light_panel_style())
	add_child(_system_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	_system_menu.add_child(box)
	box.add_child(_button("设置",_show_panel.bind(&"settings")))
	box.add_child(_button("返回主菜单",func(): GameFlow.goto_menu()))
	box.add_child(_button("退出游戏",func(): _quit_dialog.popup_centered(Vector2i(380,170))))
	_system_menu.hide()
	_quit_dialog = ConfirmationDialog.new()
	_quit_dialog.title = "退出"
	_quit_dialog.dialog_text = "确定退出游戏？"
	_quit_dialog.ok_button_text = "退出"
	_quit_dialog.cancel_button_text = "取消"
	_quit_dialog.confirmed.connect(func(): get_tree().quit())
	add_child(_quit_dialog)

func refresh_city() -> void:
	var profile := ProfileStore.get_profile()
	for button in _buttons.values(): button.refresh(profile)
	for child in _balances.get_children():
		_balances.remove_child(child); child.queue_free()
	var progress := ShopRegistry.lord_progress(profile.lord_exp)
	for pair in [["lord_level","Lv.%d" % progress.level,"主公等级"],["ingot",str(profile.ingots),"元宝"],["merit",str(profile.military_merit),"军功"]]:
		var group := HBoxContainer.new()
		group.custom_minimum_size = Vector2(132,35)
		group.add_theme_constant_override("separation",8)
		group.add_child(ConceptIcon.new(pair[0],28,pair[2]))
		group.add_child(_label(pair[1],22))
		_balances.add_child(group)

func _describe(id: StringName) -> void:
	var data := CityRegistry.entry(id)
	_hint.text = data.display_name + " · " + (data.description if CityRegistry.is_open(ProfileStore.get_profile(),id) else CityRegistry.locked_reason(id))

func _reset_hint() -> void:
	_hint.text = "点击建筑进入；ESC返回。"

func _show_panel(id: StringName, show_intro: bool = true) -> void:
	if is_instance_valid(_intro): return
	_system_menu.hide()
	if id != &"city" and id != &"settings" and CityRegistry.entry(id) == null: id = &"city"
	if id != &"city" and id != &"settings" and not CityRegistry.is_open(ProfileStore.get_profile(),id):
		_show_panel(&"city",false)
		_describe(id)
		return
	if id != &"city" and not _panels.has(id): id = &"city"
	GameFlow.hub_active_panel = id
	_hub_panel.visible = id != &"city"
	for key in _panels: _panels[key].visible = key == id
	if id == &"city":
		refresh_city()
		return
	if id == &"command": _refresh_command()
	if _panels[id].has_method("_on_shown"): _panels[id]._on_shown()
	_title_icon.texture = load("res://assets/city/%s/%s.svg" % [city_palette,"command" if id == &"supply" else id]) if id != &"settings" else null
	if show_intro and id != &"settings" and CityRegistry.is_new(ProfileStore.get_profile(),id): _open_intro(id)

func _refresh_command() -> void:
	for child in _command.get_children():
		_command.remove_child(child);child.queue_free()
	var profile := ProfileStore.get_profile()
	var progress := ShopRegistry.lord_progress(profile.lord_exp)
	var row := HBoxContainer.new()
	row.add_child(ConceptIcon.new("lord_level",46,"主公等级"))
	row.add_child(_label("Lv.%d" % progress.level,32,UITheme.LIGHT_INK))
	_command.add_child(row)
	var exp_row := HBoxContainer.new()
	exp_row.add_child(ConceptIcon.new("lord_exp",28,"主公经验"))
	exp_row.add_child(_label(str(profile.lord_exp),22,UITheme.LIGHT_BODY))
	_command.add_child(exp_row)
	var cleared := 0
	var chapter_stages := GameFlow.get_sorted_stages(GameFlow.get_chapter())
	for data in chapter_stages:
		if profile.stage_progress.get(str(data.stage_id),{}).get("completed",false): cleared+=1
	var stages := HBoxContainer.new()
	stages.add_child(ConceptIcon.new("wave_flag",28,"已通关 / 第一章关卡"))
	stages.add_child(_label("%d / %d" % [cleared,chapter_stages.size()],22,UITheme.LIGHT_BODY))
	_command.add_child(stages)
	_command.add_child(_label("通关获得经验，提升等级后逐步开放选购内容。",20,UITheme.LIGHT_BODY))
	_supply_button = _button("整备",_show_panel.bind(&"supply"))
	_supply_button.name = "SupplyEntry"
	_supply_button.tooltip_text = "军需管理"
	_supply_button.disabled = not CityRegistry.is_open(profile,&"supply")
	_command.add_child(_supply_button)
	if _supply_button.disabled: _command.add_child(_label(CityRegistry.locked_reason(&"supply"),18,UITheme.LIGHT_MUTED))

func _open_intro(id: StringName) -> void:
	_intro_id = id
	_intro = ColorRect.new()
	_intro.name = "FirstVisit"
	_intro.color = Color(0,0,0,.55)
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_intro)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520,210)
	card.add_theme_stylebox_override("panel",UITheme.light_panel_style())
	center.add_child(card)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",22)
	margin.add_child(box)
	var label := _label(CityRegistry.entry(id).introduction,22,UITheme.LIGHT_INK)
	label.name = "Explanation"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_child(_button("跳过",_close_intro))
	var next := _button("继续",_close_intro)
	actions.add_child(next)
	box.add_child(actions)
	next.grab_focus()

func _close_intro() -> void:
	if not is_instance_valid(_intro): return
	if not ProfileStore.mark_city_visited(_intro_id):
		_intro.find_child("Explanation",true,false).text = "未能保存，请重试。"
		return
	_intro.queue_free(); _intro = null
	refresh_city()

func _on_stage_selected(id: StringName, difficulty: int) -> void:
	GameFlow.select_stage(id)
	GameFlow.goto_squad_select(difficulty)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"): return
	if is_instance_valid(_intro): _close_intro()
	elif _system_menu.visible: _system_menu.hide()
	elif _hub_panel.visible: _show_panel(&"city")
	else: _system_menu.show()
	get_viewport().set_input_as_handled()
