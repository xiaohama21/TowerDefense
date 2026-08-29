extends VBoxContainer

## 武将养成面板（GDD 阶段 2，v0.10.1 移入游戏大厅）：等级/经验、属性
## （等级+转职实时计算）、一转流程（等级+材料校验、不可逆确认、扣料写档）。

signal back_requested

const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const TEXT_COLOR := Color(0.88, 0.9, 0.84)
const OK_COLOR := Color(0.55, 0.9, 0.6)
const BAD_COLOR := Color(0.9, 0.45, 0.4)
const ACCENT_COLOR := Color(0.65, 0.84, 1.0)

var _profile: PlayerProfile
var _owned: Array[CharacterData] = []
var _selected_id: String = ""

var _character_buttons: Dictionary = {}
var _detail_name_label: Label
var _exp_bar: ProgressBar
var _exp_label: Label
var _stats_label: Label
var _promotion_label: Label
var _promotion_button: Button
var _promotion: PromotionData = null


func _ready() -> void:
	_profile = ProfileStore.get_profile()
	_load_owned_characters()
	add_theme_constant_override("separation", 12)
	_build_ui()
	if not _owned.is_empty() and _selected_id.is_empty():
		_select_character(str(_owned[0].character_id))
	_refresh()


func _on_shown() -> void:
	# 每次切回面板时刷新（战斗结算后等级/材料可能已变化）。
	_refresh()


func _load_owned_characters() -> void:
	for character_id in _profile.get_owned_character_ids():
		var character_data := GameFlow.load_character_data(character_id)
		if character_data != null:
			_owned.append(character_data)


func _build_ui() -> void:
	var title := Label.new()
	title.text = "武将养成"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	add_child(title)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	add_child(columns)

	var list_box := VBoxContainer.new()
	list_box.custom_minimum_size = Vector2(220, 0)
	list_box.add_theme_constant_override("separation", 8)
	columns.add_child(list_box)

	if _owned.is_empty():
		var empty := Label.new()
		empty.text = "暂无武将，请先开始游戏"
		empty.add_theme_font_size_override("font_size", 17)
		list_box.add_child(empty)

	for character_data in _owned:
		var character_id := str(character_data.character_id)
		var level := GameFlow.get_character_level(_profile, character_id)
		var button := Button.new()
		button.text = "%s · Lv.%d" % [character_data.display_name, level]
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 17)
		button.toggle_mode = true
		button.pressed.connect(_on_character_pressed.bind(character_id))
		list_box.add_child(button)
		_character_buttons[character_id] = button

	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 10)
	columns.add_child(detail_box)

	_detail_name_label = Label.new()
	_detail_name_label.add_theme_font_size_override("font_size", 24)
	_detail_name_label.add_theme_color_override("font_color", TEXT_COLOR)
	detail_box.add_child(_detail_name_label)

	_exp_bar = ProgressBar.new()
	_exp_bar.custom_minimum_size = Vector2(0, 22)
	_exp_bar.show_percentage = false
	detail_box.add_child(_exp_bar)

	_exp_label = Label.new()
	_exp_label.add_theme_font_size_override("font_size", 16)
	_exp_label.add_theme_color_override("font_color", ACCENT_COLOR)
	detail_box.add_child(_exp_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.add_theme_color_override("font_color", TEXT_COLOR)
	detail_box.add_child(_stats_label)

	_promotion_label = Label.new()
	_promotion_label.add_theme_font_size_override("font_size", 17)
	_promotion_label.add_theme_color_override("font_color", TEXT_COLOR)
	_promotion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_promotion_label)

	_promotion_button = Button.new()
	_promotion_button.text = "转 职"
	_promotion_button.custom_minimum_size = Vector2(220, 48)
	_promotion_button.add_theme_font_size_override("font_size", 20)
	_promotion_button.pressed.connect(_on_promote_pressed)
	detail_box.add_child(_promotion_button)


func _on_character_pressed(character_id: String) -> void:
	_select_character(character_id)
	_refresh()


func _select_character(character_id: String) -> void:
	_selected_id = character_id
	for key in _character_buttons.keys():
		var button := _character_buttons[key] as Button
		if is_instance_valid(button):
			button.set_pressed_no_signal(str(key) == character_id)


func _selected_character() -> CharacterData:
	for character_data in _owned:
		if str(character_data.character_id) == _selected_id:
			return character_data
	return null


func _refresh() -> void:
	var character := _selected_character()
	if character == null:
		return

	var level := GameFlow.get_character_level(_profile, _selected_id)
	var promotion := GameFlow.get_active_promotion(_profile, _selected_id)
	var progress := LevelCurve.progress_at(_profile.get_character_exp(_selected_id))
	var stats := character.compute_stats_at(level, promotion)

	_detail_name_label.text = "%s · %s · 等级 %d" % [
		character.display_name,
		character.profession.display_name if character.profession != null else "未知职业",
		level,
	]
	_exp_bar.max_value = maxi(int(progress.exp_for_next), 1)
	_exp_bar.value = int(progress.exp_into_level)
	if progress.is_max_level:
		_exp_label.text = "经验 %d（已达第一章等级上限 %d）" % [_profile.get_character_exp(_selected_id), LevelCurve.MAX_LEVEL]
	else:
		_exp_label.text = "经验 %d · 距下一级还需 %d" % [
			int(progress.exp_into_level), int(progress.exp_for_next) - int(progress.exp_into_level),
		]
	_stats_label.text = "伤害 %d　　攻速 %.2f 次/秒　　射程 %d" % [
		stats.damage, 1.0 / maxf(stats.attack_interval, 0.01), int(stats.range),
	]
	_refresh_promotion(character, level)


func _refresh_promotion(character: CharacterData, level: int) -> void:
	_promotion = null
	_promotion_button.visible = false
	if character.promotion_ids.is_empty():
		_promotion_label.text = "暂无转职路线"
		return

	var route_id := str(character.promotion_ids[0])
	var route_path: String = "%s/%s.tres" % [GameFlow.PROMOTION_RESOURCE_DIR, route_id]
	var route := load(route_path) as PromotionData if ResourceLoader.exists(route_path) else null
	if route == null:
		_promotion_label.text = "转职配置缺失：%s" % route_id
		return

	var promoted := GameFlow.get_active_promotion(_profile, _selected_id) != null
	if promoted:
		_promotion_label.text = "已转职：%s（%s）" % [route.display_name, route.description]
		return

	_promotion = route
	var level_ok := level >= route.required_level
	var lines: Array[String] = [
		"一转：%s —— %s" % [route.display_name, route.description],
		"等级需求 %d：%s" % [route.required_level, "已达标" if level_ok else "当前 %d" % level],
	]
	var materials_ok := true
	for cost in route.item_costs:
		if cost == null or cost.item == null:
			continue
		var owned: int = int(_profile.items.get(str(cost.item.item_id), 0))
		var enough: bool = owned >= cost.amount
		materials_ok = materials_ok and enough
		lines.append("%s：%d/%d %s" % [
			cost.item.display_name, owned, cost.amount, "已备齐" if enough else "不足",
		])
	_promotion_label.text = "\n".join(lines)
	_promotion_label.add_theme_color_override("font_color",
		OK_COLOR if (level_ok and materials_ok) else BAD_COLOR)
	_promotion_button.visible = true
	_promotion_button.disabled = not (level_ok and materials_ok)


func _on_promote_pressed() -> void:
	var character := _selected_character()
	if character == null or _promotion == null:
		return
	var promotion := _promotion
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "转职为「%s」？\n转职不可逆，将消耗转职材料。" % promotion.display_name
	dialog.ok_button_text = "确认转职"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(_apply_promotion.bind(character, promotion, dialog))
	dialog.cancelled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _apply_promotion(character: CharacterData, promotion: PromotionData, dialog: ConfirmationDialog) -> void:
	for cost in promotion.item_costs:
		if cost == null or cost.item == null:
			continue
		if not _profile.spend_item(str(cost.item.item_id), cost.amount):
			dialog.queue_free()
			return
	var entry := _profile.get_character(_selected_id)
	var promotion_path: Array = entry.get("promotion_path", [])
	var new_path := []
	for existing in promotion_path:
		new_path.append(str(existing))
	new_path.append(str(promotion.promotion_id))
	_profile.set_promotion_path(_selected_id, new_path)
	ProfileStore.save_profile(_profile)
	dialog.queue_free()
	_refresh()
