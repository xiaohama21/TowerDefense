extends Control

## 编队界面（GDD 阶段 1）：从已拥有武将中选出 squad_size 个出战。
## 未解锁角色不会出现在拥有列表中（解锁即拥有，见 CHARACTERS.md 4.3）。
## 纵向分区定稿（v0.33.1，UI_LAYOUT.md §6）：武将选择区 → 羁绊提示 → 遗物选带区 →
## 底部固定操作条（返回选关 / 确认出战 + 二次确认弹窗）；出战编队持久记忆自动预填。

const RELIC_CAP := 2

var _stage_data: StageData
var _owned_characters: Array[CharacterData] = []
var _selected_ids: Array[String] = []
var _buttons: Dictionary = {}

var _counter_label: Label
var _bond_label: Label
var _start_button: Button
var _confirm_dialog: ConfirmationDialog
var _selected_relic_ids: Array[String] = []
var _relic_buttons: Dictionary = {}
var _relic_counter_label: Label


func _ready() -> void:
	_stage_data = GameFlow.load_stage_data(GameFlow.selected_stage_id)
	_load_owned_characters()
	_apply_saved_memory()
	_build_ui()
	_sync_button_states()
	_sync_relic_button_states()
	_refresh()


## 编队记忆自动预填（v0.33.1，UI_LAYOUT.md §6）：优先读取玩家档案记忆
## （「确认出战」写入 squad_character_ids / squad_relic_ids）；档案无记忆时回退
## 运行时状态（旧版流程 / 战斗重试直接带参进入的场景）。
## 校验规则：武将须仍拥有且不超 squad_size 上限；遗物须仍有库存（数量 ≥1）且不超 2 件。
func _apply_saved_memory() -> void:
	var profile := ProfileStore.get_profile()
	var saved_characters := GameFlow.load_saved_squad(profile)
	var character_source := saved_characters if not saved_characters.is_empty() else GameFlow.squad_character_ids
	for character_data in _owned_characters:
		var character_id := str(character_data.character_id)
		if character_source.has(character_id) and _selected_ids.size() < _squad_cap():
			_selected_ids.append(character_id)
	var saved_relics := GameFlow.load_saved_squad_relics(profile)
	var relic_source := saved_relics if not saved_relics.is_empty() else GameFlow.squad_relic_ids
	for relic_id in relic_source:
		if _selected_relic_ids.size() >= RELIC_CAP or _selected_relic_ids.has(relic_id):
			continue
		var amount := int(profile.items.get(relic_id, 0))
		var relic := GameFlow.load_battle_relic_data(relic_id)
		if amount > 0 and relic != null and relic.is_valid():
			_selected_relic_ids.append(relic_id)


func _load_owned_characters() -> void:
	var profile := ProfileStore.get_profile()
	for character_id in profile.get_owned_character_ids():
		var character_data := GameFlow.load_character_data(character_id)
		if character_data != null:
			_owned_characters.append(character_data)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = UITheme.BG
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
	var diff_name: String = Difficulty.name(GameFlow.selected_difficulty)
	var title := Label.new()
	title.text = "编队出征 · %s（最多 %d 名武将 · %s）" % [stage_name, squad_cap, diff_name]
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UITheme.GOLD)
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
		button.custom_minimum_size = Vector2(232, 84)
		button.add_theme_font_size_override("font_size", 16)
		button.text = _character_button_text(character_data)
		button.toggled.connect(_on_character_toggled.bind(character_id))
		_apply_selected_style(button)
		grid.add_child(button)
		_buttons[character_id] = button

	_counter_label = Label.new()
	_counter_label.add_theme_font_size_override("font_size", 22)
	root.add_child(_counter_label)

	_bond_label = Label.new()
	_bond_label.add_theme_font_size_override("font_size", 15)
	_bond_label.add_theme_color_override("font_color", UITheme.GRAY)
	_bond_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_bond_label)

	# 遗物选带（v0.19.0；✅ v0.33.1 改永久使用——选带不消耗库存、可反复携带，BUGS B-019）。
	var relic_hint := Label.new()
	relic_hint.text = "遗物选带（最多 %d 件 · 永久使用，选带不消耗库存）" % RELIC_CAP
	relic_hint.add_theme_font_size_override("font_size", 16)
	relic_hint.add_theme_color_override("font_color", UITheme.GRAY)
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
	_relic_counter_label.add_theme_color_override("font_color", UITheme.GRAY)
	root.add_child(_relic_counter_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	root.add_child(actions)

	var back_button := Button.new()
	back_button.text = "返回选关"
	back_button.custom_minimum_size = Vector2(160, 48)
	back_button.pressed.connect(func() -> void: GameFlow.goto_stage_select())
	actions.add_child(back_button)

	_start_button = Button.new()
	_start_button.text = "确认出战"
	_start_button.custom_minimum_size = Vector2(220, 48)
	_start_button.add_theme_font_size_override("font_size", 22)
	_start_button.pressed.connect(_on_start_pressed)
	actions.add_child(_start_button)

	# 「确认出战」二次确认弹窗（v0.33.1）：展示关卡/难度/武将名单/遗物清单，确认后才进战斗。
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "确认出战"
	var ok_button := _confirm_dialog.get_ok_button()
	if ok_button != null:
		ok_button.text = "确认出战"
	var cancel_button := _confirm_dialog.get_cancel_button()
	if cancel_button != null:
		cancel_button.text = "取消"
	_confirm_dialog.confirmed.connect(_on_confirm_deploy)
	add_child(_confirm_dialog)


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


## 武将卡片文本（v0.33.2，BUGS B-020）：统一构建入口，勾选后随羁绊预览计数刷新。
func _character_button_text(character_data: CharacterData) -> String:
	var bond_tags := _bond_tag_text(str(character_data.character_id))
	return "%s\n%s · %d 金币%s" % [
		character_data.display_name, _profession_name(character_data), character_data.build_cost,
		("\n" + bond_tags) if bond_tags != "" else "",
	]


## 刷新全部武将卡片文本（v0.33.2，BUGS B-020）：羁绊 X/Y 预览随当前勾选实时更新。
func _refresh_character_button_texts() -> void:
	for character_data in _owned_characters:
		var button := _buttons.get(str(character_data.character_id)) as Button
		if is_instance_valid(button):
			button.text = _character_button_text(character_data)


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


## 选中态高亮（v0.19.2）：金色底 + 深色文字（统一走 UITheme 封装）。
func _apply_selected_style(button: Button) -> void:
	UITheme.apply_selected_style(button)


func _on_character_toggled(pressed: bool, character_id: String) -> void:
	if pressed:
		if not _selected_ids.has(character_id) and _selected_ids.size() < _squad_cap():
			_selected_ids.append(character_id)
	else:
		_selected_ids.erase(character_id)
	_sync_button_states()
	_refresh()


## 「确认出战」（v0.33.1）：先弹二次确认，确认后写入编队记忆并进入战斗。
func _on_start_pressed() -> void:
	if _selected_ids.is_empty():
		return
	_refresh_confirm_dialog_text()
	_confirm_dialog.popup_centered()


func _on_confirm_deploy() -> void:
	if _selected_ids.is_empty():
		return
	GameFlow.set_squad(_selected_ids)
	GameFlow.set_squad_relics(_selected_relic_ids)
	var profile := ProfileStore.get_profile()
	GameFlow.save_squad_to_profile(profile)
	GameFlow.save_squad_relics_to_profile(profile)
	ProfileStore.save_profile(profile)
	GameFlow.goto_battle()


func _refresh_confirm_dialog_text() -> void:
	var stage_name := _stage_data.display_name if _stage_data != null else "未选择关卡"
	var diff_name := Difficulty.name(GameFlow.selected_difficulty)
	var names: Array[String] = []
	for character_id in _selected_ids:
		var character := GameFlow.load_character_data(character_id)
		names.append(character.display_name if character != null else character_id)
	var relic_lines: Array[String] = []
	var profile := ProfileStore.get_profile()
	for relic_id in _selected_relic_ids:
		var relic := GameFlow.load_battle_relic_data(relic_id)
		if relic != null:
			relic_lines.append("· %s：%s" % [relic.display_name, relic.description])
	var character_part := "、".join(names) if not names.is_empty() else "（未选择）"
	var relic_part := "\n".join(relic_lines) if not relic_lines.is_empty() else "（未选带）"
	_confirm_dialog.dialog_text = "关卡：%s（%s）\n出战武将：%s\n遗物（永久使用，不消耗库存）：\n%s\n\n确认后进入战斗。" % [
		stage_name, diff_name, character_part, relic_part,
	]


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
	_refresh_character_button_texts()
