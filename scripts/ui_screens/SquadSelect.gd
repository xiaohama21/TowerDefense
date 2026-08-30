extends Control

## 编队界面（GDD 阶段 1）：从已拥有武将中选出 squad_size 个出战。
## 未解锁角色不会出现在拥有列表中（解锁即拥有，见 CHARACTERS.md 4.3）。

const BG_COLOR := Color(0.06, 0.09, 0.08)
const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const SELECTED_COLOR := Color(1.0, 0.82, 0.3)
const RELIC_CAP := 2

var _stage_data: StageData
var _owned_characters: Array[CharacterData] = []
var _selected_ids: Array[String] = []
var _buttons: Dictionary = {}

var _counter_label: Label
var _bond_label: Label
var _start_button: Button
var _selected_relic_ids: Array[String] = []
var _relic_buttons: Dictionary = {}
var _relic_counter_label: Label


func _ready() -> void:
	_stage_data = GameFlow.load_stage_data(GameFlow.selected_stage_id)
	_load_owned_characters()
	_preselect_previous_squad()
	_preselect_previous_relics()
	_build_ui()
	_sync_button_states()
	_sync_relic_button_states()
	_refresh()


## 预选上次编队携带的遗物（返回编队调整时保留，数量不超过上限）。 
func _preselect_previous_relics() -> void:
	for relic_id in GameFlow.squad_relic_ids:
		if _selected_relic_ids.size() < RELIC_CAP:
			_selected_relic_ids.append(relic_id)


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
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var diff_name: String = Difficulty.NAMES[GameFlow.selected_difficulty] if GameFlow.selected_difficulty < 3 else "标准"
	var title := Label.new()
	title.text = "编队出征 · %s（最多 %d 名武将 · %s）" % [stage_name, squad_cap, diff_name]
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
		var bond_tags := _bond_tag_text(character_id)
		button.text = "%s\n%s · %d 金币%s" % [
			character_data.display_name, _profession_name(character_data), character_data.build_cost,
			("\n" + bond_tags) if bond_tags != "" else "",
		]
		button.toggled.connect(_on_character_toggled.bind(character_id))
		_apply_selected_style(button)
		grid.add_child(button)
		_buttons[character_id] = button

	_counter_label = Label.new()
	_counter_label.add_theme_font_size_override("font_size", 22)
	root.add_child(_counter_label)

	_bond_label = Label.new()
	_bond_label.add_theme_font_size_override("font_size", 15)
	_bond_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.68))
	_bond_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_bond_label)

	# 遗物选带（v0.19.0，GDD modules/CHARACTERS.md 4.8）：出征即消耗、仅本局生效。
	var relic_hint := Label.new()
	relic_hint.text = "遗物选带（最多 %d 件，进入战斗即消耗，仅本局生效）" % RELIC_CAP
	relic_hint.add_theme_font_size_override("font_size", 16)
	relic_hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.68))
	root.add_child(relic_hint)

	# HFlowContainer 自动换行，避免遗物按钮过多时溢出屏幕（v0.19.1 修复）。 
	var relic_box := HFlowContainer.new()
	relic_box.add_theme_constant_override("separation", 10)
	root.add_child(relic_box)

	var profile := ProfileStore.get_profile()
	for relic_id in GameFlow.get_owned_relic_ids(profile):
		var relic := GameFlow.load_battle_relic_data(relic_id)
		if relic == null:
			continue
		var relic_button := Button.new()
		relic_button.toggle_mode = true
		relic_button.custom_minimum_size = Vector2(190, 54)
		relic_button.add_theme_font_size_override("font_size", 14)
		var relic_amount := int(profile.items.get(relic_id, 0))
		relic_button.text = "%s ×%d\n%s" % [relic.display_name, relic_amount, relic.description]
		relic_button.toggled.connect(_on_relic_toggled.bind(relic_id))
		_apply_selected_style(relic_button)
		relic_box.add_child(relic_button)
		_relic_buttons[relic_id] = relic_button

	_relic_counter_label = Label.new()
	_relic_counter_label.add_theme_font_size_override("font_size", 15)
	_relic_counter_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.68))
	root.add_child(_relic_counter_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	root.add_child(actions)

	var back_button := Button.new()
	back_button.text = "返回大厅"
	back_button.custom_minimum_size = Vector2(160, 48)
	back_button.pressed.connect(func() -> void: GameFlow.goto_hub())
	actions.add_child(back_button)

	_start_button = Button.new()
	_start_button.text = "出征"
	_start_button.custom_minimum_size = Vector2(220, 48)
	_start_button.add_theme_font_size_override("font_size", 22)
	_start_button.pressed.connect(_on_start_pressed)
	actions.add_child(_start_button)


func _bond_tag_text(character_id: String) -> String:
	var tags: Array[String] = []
	var squad := _selected_ids.duplicate()
	if not squad.has(character_id):
		squad.append(character_id)
	for progress in GameFlow.get_bond_progress(squad):
		var bond := progress["bond"] as BondData
		if bond == null or not bond.member_ids.has(StringName(character_id)):
			continue
		tags.append("%s %d/%d" % [bond.display_name, int(progress["count"]), int(progress["total"])])
	return "　".join(tags)


## 编队羁绊状态说明（v0.17.0，GDD modules/CHARACTERS.md 4.8）：激活/预览与效果描述。
func _bond_summary_text() -> String:
	var parts: Array[String] = []
	for progress in GameFlow.get_bond_progress(_selected_ids):
		var bond := progress["bond"] as BondData
		if bond == null:
			continue
		var state := "✅ 已激活" if bool(progress["active"]) else "预览"
		parts.append("%s %d/%d %s：%s" % [
			bond.display_name, int(progress["count"]), int(progress["total"]), state, bond.description,
		])
	return "\n".join(parts)


func _profession_name(character_data: CharacterData) -> String:
	return character_data.profession.display_name if character_data.profession != null else "未知职业"


## 选中态高亮（v0.19.2）：金色底 + 深色文字，避免默认主题按压态不明显。
func _apply_selected_style(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = SELECTED_COLOR
	style.border_color = Color(1.0, 0.92, 0.62)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover_pressed", style)
	button.add_theme_color_override("font_pressed_color", Color(0.12, 0.09, 0.02))
	button.add_theme_color_override("font_hover_pressed_color", Color(0.12, 0.09, 0.02))


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
	GameFlow.set_squad_relics(_selected_relic_ids)
	GameFlow.consume_squad_relics(ProfileStore.get_profile())
	ProfileStore.save_profile()
	GameFlow.goto_battle()


func _squad_cap() -> int:
	return _stage_data.squad_size if _stage_data != null else 4


func _on_relic_toggled(pressed: bool, relic_id: String) -> void:
	if pressed:
		if not _selected_relic_ids.has(relic_id) and _selected_relic_ids.size() < RELIC_CAP:
			_selected_relic_ids.append(relic_id)
	else:
		_selected_relic_ids.erase(relic_id)
	_sync_relic_button_states()
	_refresh()


func _sync_relic_button_states() -> void:
	for relic_id in _relic_buttons.keys():
		var button := _relic_buttons[relic_id] as Button
		if not is_instance_valid(button):
			continue
		button.set_pressed_no_signal(_selected_relic_ids.has(str(relic_id)))
		if not _selected_relic_ids.has(str(relic_id)):
			button.disabled = _selected_relic_ids.size() >= RELIC_CAP
		else:
			button.disabled = false


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
	_relic_counter_label.text = "已选 %d / %d 件遗物" % [_selected_relic_ids.size(), RELIC_CAP]
	_start_button.disabled = _selected_ids.is_empty()
	var summary := _bond_summary_text()
	_bond_label.text = summary
	_bond_label.visible = not summary.is_empty()
