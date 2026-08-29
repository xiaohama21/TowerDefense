extends Control

## 编队界面（GDD 阶段 1）：从已拥有武将中选出 squad_size 个出战。
## 未解锁角色不会出现在拥有列表中（解锁即拥有，见 CHARACTERS.md 4.3）。

const BG_COLOR := Color(0.06, 0.09, 0.08)
const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const SELECTED_COLOR := Color(1.0, 0.82, 0.3)

var _stage_data: StageData
var _owned_characters: Array[CharacterData] = []
var _selected_ids: Array[String] = []
var _buttons: Dictionary = {}

var _counter_label: Label
var _start_button: Button


func _ready() -> void:
	_stage_data = GameFlow.load_stage_data(GameFlow.selected_stage_id)
	_load_owned_characters()
	_preselect_previous_squad()
	_build_ui()
	_sync_button_states()
	_refresh()


## 预选上次编队中仍拥有的武将（进入战斗后返回调整编队的场景）。
func _preselect_previous_squad() -> void:
	for character_data in _owned_characters:
		var character_id := str(character_data.character_id)
		if GameFlow.squad_character_ids.has(character_id) and _selected_ids.size() < _squad_cap():
			_selected_ids.append(character_id)


func _load_owned_characters() -> void:
	var profile := ProfileStore.get_profile()
	for character_id in profile.get_owned_character_ids():
		var character_data := GameFlow.load_character_data(character_id)
		if character_data != null:
			_owned_characters.append(character_data)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BG_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 100)
	margin.add_theme_constant_override("margin_right", 100)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var squad_cap: int = _stage_data.squad_size if _stage_data != null else 4
	var stage_name: String = _stage_data.display_name if _stage_data != null else "未选择关卡"
	var title := Label.new()
	title.text = "编队出征 · %s（最多 %d 名武将）" % [stage_name, squad_cap]
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	root.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	root.add_child(grid)

	for character_data in _owned_characters:
		var character_id := str(character_data.character_id)
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(200, 84)
		button.add_theme_font_size_override("font_size", 16)
		button.text = "%s\n%s · %d 金币" % [
			character_data.display_name, _profession_name(character_data), character_data.build_cost
		]
		button.toggled.connect(_on_character_toggled.bind(character_id))
		grid.add_child(button)
		_buttons[character_id] = button

	_counter_label = Label.new()
	_counter_label.add_theme_font_size_override("font_size", 22)
	root.add_child(_counter_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	root.add_child(actions)

	var back_button := Button.new()
	back_button.text = "返回选关"
	back_button.custom_minimum_size = Vector2(160, 48)
	back_button.pressed.connect(func() -> void: GameFlow.goto_stage_select())
	actions.add_child(back_button)

	_start_button = Button.new()
	_start_button.text = "出 征"
	_start_button.custom_minimum_size = Vector2(220, 48)
	_start_button.add_theme_font_size_override("font_size", 22)
	_start_button.pressed.connect(_on_start_pressed)
	actions.add_child(_start_button)


func _profession_name(character_data: CharacterData) -> String:
	return character_data.profession.display_name if character_data.profession != null else "未知职业"


func _on_character_toggled(pressed: bool, character_id: String) -> void:
	if pressed:
		if not _selected_ids.has(character_id) and _selected_ids.size() < _squad_cap():
			_selected_ids.append(character_id)
	else:
		_selected_ids.erase(character_id)
	_sync_button_states()
	_refresh()


func _on_start_pressed() -> void:
	if _selected_ids.is_empty():
		return
	GameFlow.set_squad(_selected_ids)
	GameFlow.goto_battle()


func _squad_cap() -> int:
	return _stage_data.squad_size if _stage_data != null else 4


func _sync_button_states() -> void:
	for character_id in _buttons.keys():
		var button := _buttons[character_id] as Button
		if not is_instance_valid(button):
			continue
		button.set_pressed_no_signal(_selected_ids.has(str(character_id)))
		# 达到编队上限后禁止再勾选新武将。
		if not _selected_ids.has(str(character_id)):
			button.disabled = _selected_ids.size() >= _squad_cap()
		else:
			button.disabled = false


func _refresh() -> void:
	_counter_label.text = "已选 %d / %d 名武将" % [_selected_ids.size(), _squad_cap()]
	_start_button.disabled = _selected_ids.is_empty()
