extends VBoxContainer

## 军需处（✅ 0.8.16 新入口 / UI_LAYOUT §16 · NUMBERS 10.15）：大厅侧栏第 4 个功能按钮。
## 顶栏（军需标题 + 军功余额胶囊 + 灰口径说明）→ 左 6 件军需卡片（3×2：图标 / 名称 / 等级 chip /
## 效果摘要 / 费用 · 限次 / 解锁 · 强化按钮）+ 右局外选带区（军需带 + 槽位 n / m + 槽位圆卡）→ 底栏说明条。
## 军功来源 = 击杀掉落（困难 ×1.5，失败 / 退出不带出）；解锁与强化即时生效、写档、不可逆。

## 卡片宽 224 = 左侧内容区 988 满宽摊分（3 列 + 槽位列 276 + 间距），不挤压选带区。
const CARD_WIDTH := 224.0
const CARD_HEIGHT := 178.0
const SLOT_WIDTH := 276.0
const SLOT_HEIGHT := 54.0
const GRID_GAP := 12

var _supplies: Array[BattleSupplyData] = []
var _cards: Dictionary = {}
var _slot_box: VBoxContainer
var _slot_nodes: Array[Control] = []
var _merit_label: Label
var _slot_count_label: Label
var _slot_hint: Label
var _status_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_supplies = BattleSupplyData.load_catalog()
	_build_ui()
	_refresh()


func _on_shown() -> void:
	_refresh()


func _build_ui() -> void:
	add_child(_build_topbar())
	add_child(_build_body())
	add_child(_build_footer())


func _build_topbar() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 42)
	row.add_theme_constant_override("separation", 14)
	var title := Label.new()
	title.text = "军需"
	title.add_theme_font_override("font", UITheme.spaced_font(3))
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_merit_label = Label.new()
	_merit_label.add_theme_font_size_override("font_size", 16)
	_merit_label.add_theme_color_override("font_color", UITheme.TAG_OPEN_FG)
	_merit_label.add_theme_stylebox_override("normal", UITheme.tag_style(Color("#ffe9b0"), 12, 4))
	row.add_child(_merit_label)
	var hint := Label.new()
	hint.text = "击杀掉落 · 困难 ×1.5 · 失败 / 退出不带出"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	row.add_child(hint)
	return row


func _build_body() -> Control:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	body.add_child(_build_grid())
	body.add_child(_build_loadout_column())
	return body


func _build_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", GRID_GAP)
	grid.add_theme_constant_override("v_separation", GRID_GAP)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for supply in _supplies:
		grid.add_child(_build_card(supply))
	return grid


func _build_card(supply: BattleSupplyData) -> Control:
	var supply_id := str(supply.supply_id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.focus_mode = Control.FOCUS_NONE
	card.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = UITheme.LIGHT_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(13)
	card.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("#fbfdff")
	card.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color("#f2f9fd")
	card.add_theme_stylebox_override("pressed", pressed_style)
	card.pressed.connect(_on_card_pressed.bind(supply_id))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 9)
	box.add_child(head)
	var icon := DashedPill.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.setup(Color("#f0f6fb"), Color("#9cbed9"), 22.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_text := Label.new()
	icon_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_text.add_theme_font_size_override("font_size", 19)
	icon_text.add_theme_color_override("font_color", Color("#7fa3c2"))
	icon.add_child(icon_text)
	head.add_child(icon)
	var head_info := VBoxContainer.new()
	head_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_info.add_theme_constant_override("separation", 3)
	head.add_child(head_info)
	var name_label := Label.new()
	name_label.text = supply.display_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_info.add_child(name_label)
	var chip_row := HBoxContainer.new()
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_row.add_theme_constant_override("separation", 6)
	head_info.add_child(chip_row)
	var level_chip := Label.new()
	level_chip.add_theme_font_size_override("font_size", 11)
	level_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_row.add_child(level_chip)
	var belt_chip := Label.new()
	belt_chip.add_theme_font_size_override("font_size", 11)
	belt_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_row.add_child(belt_chip)

	var summary := Label.new()
	summary.custom_minimum_size = Vector2(CARD_WIDTH - 26.0, 30)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.max_lines_visible = 2
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.add_theme_font_size_override("font_size", 12)
	summary.add_theme_color_override("font_color", UITheme.LIGHT_DESC)
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(summary)
	var cost := Label.new()
	cost.add_theme_font_size_override("font_size", 12)
	cost.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(cost)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	var action := Button.new()
	action.custom_minimum_size = Vector2(0, 34)
	action.focus_mode = Control.FOCUS_NONE
	action.add_theme_font_size_override("font_size", 14)
	action.pressed.connect(_on_action_pressed.bind(supply_id))
	box.add_child(action)

	_cards[supply_id] = {
		"root": card, "style": style, "hover": hover_style, "pressed": pressed_style,
		"icon_text": icon_text, "name": name_label, "level": level_chip, "belt": belt_chip,
		"summary": summary, "cost": cost, "action": action,
	}
	return card


func _build_loadout_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(276, 0)
	column.size_flags_vertical = Control.SIZE_FILL
	column.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "军需带"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	head.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_slot_count_label = Label.new()
	_slot_count_label.add_theme_font_size_override("font_size", 14)
	_slot_count_label.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	head.add_child(_slot_count_label)
	column.add_child(head)
	_slot_box = VBoxContainer.new()
	_slot_box.add_theme_constant_override("separation", 8)
	column.add_child(_slot_box)
	var hint_spacer := Control.new()
	hint_spacer.custom_minimum_size = Vector2(0, 2)
	column.add_child(hint_spacer)
	_slot_hint = Label.new()
	_slot_hint.custom_minimum_size = Vector2(276, 0)
	_slot_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_hint.add_theme_font_size_override("font_size", 11)
	_slot_hint.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	column.add_child(_slot_hint)
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bottom_spacer)
	return column


func _build_slot(index: int) -> Control:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
	slot.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f7fbfe")
	style.border_color = UITheme.LIGHT_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(13)
	slot.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("#f0f8fd")
	slot.add_theme_stylebox_override("hover", hover_style)
	slot.pressed.connect(_on_slot_pressed.bind(index))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	slot.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	var icon := DashedPill.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.setup(Color("#f0f6fb"), Color("#9cbed9"), 19.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_text := Label.new()
	icon_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_text.add_theme_font_size_override("font_size", 17)
	icon_text.add_theme_color_override("font_color", Color("#7fa3c2"))
	icon.add_child(icon_text)
	row.add_child(icon)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	slot.set_meta("slot_nodes", {
		"root": slot, "style": style, "hover": hover_style,
		"icon_text": icon_text, "label": label,
	})
	return slot


func _build_footer() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", UITheme.DIALOG_WARN)
	column.add_child(_status_label)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.add_theme_constant_override("separation", 10)
	var clauses := [
		"军功来源：击杀掉落（与经验同通道，胜利结算写档）",
		"解锁与强化即时生效、写档",
		"军需带随编队出征、失败 / 退出不带出",
	]
	for index in range(clauses.size()):
		if index > 0:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(spacer)
		var label := Label.new()
		label.text = clauses[index]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
		label.add_theme_stylebox_override("normal", UITheme.tag_style(Color("#eef6fb"), 12, 4))
		row.add_child(label)
	column.add_child(row)
	return column


## ===== 状态刷新 =====

func _refresh() -> void:
	var profile := ProfileStore.get_profile()
	var limit := _slot_limit()
	if _merit_label != null:
		var merit_balance: int = profile.get_military_merit() if profile != null else 0
		_merit_label.text = "◆ 军功 %d" % merit_balance
	_refresh_cards(profile, limit)
	_refresh_slots(profile, limit)


func _refresh_cards(profile: PlayerProfile, limit: int) -> void:
	for supply in _supplies:
		var supply_id := str(supply.supply_id)
		var nodes: Dictionary = _cards.get(supply_id, {})
		if nodes.is_empty():
			continue
		var level: int = profile.get_supply_level(supply_id) if profile != null else 0
		var locked := level <= 0
		var display_level := maxi(level, 1)
		var style := nodes["style"] as StyleBoxFlat
		var hover_style := nodes["hover"] as StyleBoxFlat
		var pressed_style := nodes["pressed"] as StyleBoxFlat
		var icon_text := nodes["icon_text"] as Label
		var name_label := nodes["name"] as Label
		var level_chip := nodes["level"] as Label
		var belt_chip := nodes["belt"] as Label
		var summary := nodes["summary"] as Label
		var cost := nodes["cost"] as Label
		var action := nodes["action"] as Button
		icon_text.text = "锁" if locked else supply.display_name.substr(0, 1)
		name_label.add_theme_color_override("font_color", UITheme.LIGHT_LOCK if locked else UITheme.LIGHT_INK)
		if locked:
			level_chip.text = "未解锁"
			level_chip.add_theme_color_override("font_color", UITheme.TAG_LOCK_FG)
			level_chip.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.TAG_LOCK_BG, 8, 1))
		else:
			level_chip.text = "L%d" % level
			level_chip.add_theme_color_override("font_color", Color("#14538a"))
			level_chip.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.LIGHT_BLUE_SOFT, 8, 1))
		var in_belt := profile != null and profile.get_supply_loadout().has(supply_id)
		if in_belt:
			belt_chip.text = "已选带"
			belt_chip.add_theme_color_override("font_color", UITheme.TAG_OK_FG)
			belt_chip.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.TAG_OK_BG, 8, 1))
		else:
			belt_chip.text = "点击卡片选带" if not locked else "不可选带"
			belt_chip.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
			belt_chip.add_theme_stylebox_override("normal", UITheme.tag_style(Color("#eef3f7"), 8, 1))
		summary.text = supply.summary_at(display_level) if not locked else _locked_summary(supply)
		summary.add_theme_color_override("font_color", UITheme.LIGHT_LOCK if locked else UITheme.LIGHT_DESC)
		cost.text = "%d 金 · 限 %d" % [supply.cost_at(display_level), supply.max_uses_at(display_level)]
		cost.add_theme_color_override("font_color", UITheme.LIGHT_LOCK if locked else UITheme.LIGHT_BODY)
		_update_action_button(action, supply, profile, level)
		var border := UITheme.LIGHT_GOLD_SELECT if in_belt else UITheme.LIGHT_PANEL_BORDER
		var bg := Color("#eef3f7") if locked else Color.WHITE
		for target in [style, hover_style, pressed_style]:
			var target_style := target as StyleBoxFlat
			target_style.border_color = border
			target_style.bg_color = bg if target_style == style else bg.lightened(0.02)


## 未解锁卡片摘要：取描述里「效果句」（首个小括号前），避免 2 行截断成大段省略号。
func _locked_summary(supply: BattleSupplyData) -> String:
	var line := supply.description.split("（")[0].strip_edges()
	return line if not line.is_empty() else supply.description


func _update_action_button(action: Button, supply: BattleSupplyData, profile: PlayerProfile, level: int) -> void:
	var supply_id := str(supply.supply_id)
	var merit: int = profile.get_military_merit() if profile != null else 0
	if level <= 0:
		var unlock_cost := supply.merit_unlock_cost
		action.text = "解锁 · %d 军功" % unlock_cost if unlock_cost > 0 else "解锁"
		var affordable := merit >= unlock_cost
		UITheme.apply_kenney_rect_button(action, "yellow" if affordable else "grey",
			UITheme.INK if affordable else Color("#7d8fa0"), 6.0)
		action.disabled = not affordable
		return
	if level >= PlayerProfile.SUPPLY_MAX_LEVEL:
		action.text = "已满级"
		UITheme.apply_kenney_rect_button(action, "grey", Color("#7d8fa0"), 6.0)
		action.disabled = true
		return
	var upgrade_cost := PlayerProfile.supply_upgrade_cost(level)
	action.text = "强化 · %d 军功" % upgrade_cost
	var next_level := level + 1
	var color_key := "yellow" if next_level == 2 else "blue"
	var affordable_upgrade := merit >= upgrade_cost
	UITheme.apply_kenney_rect_button(action, color_key if affordable_upgrade else "grey",
		(UITheme.INK if color_key == "yellow" else Color.WHITE) if affordable_upgrade else Color("#7d8fa0"), 6.0)
	action.disabled = not affordable_upgrade


func _refresh_slots(profile: PlayerProfile, limit: int) -> void:
	var loadout: Array[String] = []
	if profile != null:
		for value in profile.get_supply_loadout():
			loadout.append(str(value))
	_rebuild_slots(limit)
	if _slot_count_label != null:
		_slot_count_label.text = "%d / %d" % [loadout.size(), limit]
	for index in range(_slot_nodes.size()):
		var slot := _slot_nodes[index]
		var meta: Dictionary = slot.get_meta("slot_nodes", {})
		var supply: BattleSupplyData = _find_supply(loadout[index]) if index < loadout.size() else null
		var icon_text := meta.get("icon_text") as Label
		var label := meta.get("label") as Label
		var style := meta.get("style") as StyleBoxFlat
		var hover_style := meta.get("hover") as StyleBoxFlat
		if supply == null:
			icon_text.text = ""
			label.text = "空"
			label.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)
			style.bg_color = Color("#eef6fb")
			style.border_color = Color("#c3d2dd")
			hover_style.bg_color = Color("#eef6fb")
			slot.disabled = true
		else:
			icon_text.text = supply.display_name.substr(0, 1)
			label.text = "✓ %s" % supply.display_name
			label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
			style.bg_color = Color("#f7fbfe")
			style.border_color = UITheme.LIGHT_PANEL_BORDER
			hover_style.bg_color = Color("#eef3f7")
			slot.disabled = false
	var has_tech := limit > PlayerProfile.BASE_SUPPLY_SLOTS
	if _slot_hint != null:
		var base := "出征时随军需带入局内，未使用作废；点击卡片 = 加入 / 移出军需带。"
		if not has_tech:
			base += "\n科技「军府调度」可 +1 槽。"
		_slot_hint.text = base


## 槽位按当前上限重建（科技「军府调度」解锁后即时反映 2 → 3 槽）。
func _rebuild_slots(limit: int) -> void:
	if _slot_box == null:
		return
	for child in _slot_box.get_children():
		_slot_box.remove_child(child)
		child.queue_free()
	_slot_nodes.clear()
	for index in range(limit):
		var slot := _build_slot(index)
		_slot_nodes.append(slot)
		_slot_box.add_child(slot)


func _find_supply(supply_id: String) -> BattleSupplyData:
	for supply in _supplies:
		if str(supply.supply_id) == supply_id:
			return supply
	return null


## 军需带槽位上限（默认 2 + 科技「军府调度」1 → 3）。
func _slot_limit() -> int:
	var tech_bonuses := TechTree.get_tech_bonuses(ProfileStore.get_profile())
	return PlayerProfile.BASE_SUPPLY_SLOTS + int(tech_bonuses.get("supply_slot_bonus", 0))


## ===== 交互 =====

## 点卡片 = 切换该件选带态（未解锁不可选；超槽位拒绝并提示）。
func _on_card_pressed(supply_id: String) -> void:
	var profile := ProfileStore.get_profile()
	if profile == null:
		return
	var limit := _slot_limit()
	if not profile.toggle_supply_loadout(supply_id, limit):
		var supply := _find_supply(supply_id)
		if supply == null:
			return
		if not profile.is_supply_unlocked(supply_id):
			_show_status("「%s」尚未解锁，先在卡片上解锁" % supply.display_name)
		else:
			_show_status("军需带已满（%d 槽），先移出一件" % limit)
		return
	ProfileStore.save_profile(profile)
	_refresh()


## 点槽位 = 移出军需带。
func _on_slot_pressed(index: int) -> void:
	var profile := ProfileStore.get_profile()
	if profile == null:
		return
	var loadout := profile.get_supply_loadout()
	if index < 0 or index >= loadout.size():
		return
	profile.toggle_supply_loadout(str(loadout[index]), _slot_limit())
	ProfileStore.save_profile(profile)
	_refresh()


## 卡片主按钮：未解锁 = 军功解锁（成本取资源 merit_unlock_cost）；已解锁 = 强化（L1→L2 150 / L2→L3 300）。
func _on_action_pressed(supply_id: String) -> void:
	var profile := ProfileStore.get_profile()
	if profile == null:
		return
	var supply := _find_supply(supply_id)
	if supply == null:
		return
	var level := profile.get_supply_level(supply_id)
	if level <= 0:
		if profile.unlock_supply(supply_id, supply.merit_unlock_cost):
			ProfileStore.save_profile(profile)
			_show_status("已解锁「%s」（L1）" % supply.display_name)
			_refresh()
		else:
			_show_status("军功不足：解锁「%s」需要 %d 军功" % [supply.display_name, supply.merit_unlock_cost])
		return
	var upgrade_cost := PlayerProfile.supply_upgrade_cost(level)
	if profile.upgrade_supply(supply_id):
		ProfileStore.save_profile(profile)
		_show_status("「%s」已强化到 L%d" % [supply.display_name, level + 1])
		_refresh()
	else:
		_show_status("军功不足：强化「%s」需要 %d 军功" % [supply.display_name, upgrade_cost])


## 底栏状态行（军功不足 / 槽位已满 / 解锁强化成功提示，2.4s 后自动清除）。
func _show_status(message: String) -> void:
	if _status_label == null or not is_instance_valid(_status_label):
		return
	_status_label.text = message
	var timer := get_tree().create_timer(2.4)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_status_label) and _status_label.text == message:
			_status_label.text = ""
	)
