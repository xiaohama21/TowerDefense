extends VBoxContainer

## 背包面板（GDD v0.15.1 / UI_LAYOUT §9，Kenney 换肤 v0.19.0 按概念图 ui_inventory.png）：
## 顶栏资源胶囊（黄巾布/练兵令）+ 类目筛选 chips + 道具卡片网格（图标块 + 名称 +
## 类型徽标 + 描述 + ×数量，点选金框）+ 底部说明条（选中物品完整描述）；
## 附测试发放"练兵令 ×10"（仅测试辅助，不影响正式数值与结算）。

signal back_requested

const EXP_SCROLL_ID := "exp_scroll"
## 测试发放的局内遗物（v0.19.0，CHARACTERS.md 4.8）：全部 5 件各 1。
const TEST_RELIC_IDS: Array[String] = ["wolf_tooth", "iron_shield", "war_drums", "scout_eye", "provision_bag"]

const ITEM_TYPE_NAMES := ["货币", "抽奖券", "材料", "碎片", "消耗品"]
## 图标块底色按类型轮换（概念图 .ava 彩色方块）。
const TYPE_COLORS := ["gold", "blue", "green", "purple", "orange"]
## 顶部资源胶囊展示的资源道具（求贤令随 v0.30.0 库存隐藏不展示）。
const RESOURCE_CHIP_IDS := ["yellow_cloth", "exp_scroll"]

var _category: int = -1  # -1 = 全部
var _selected_id := ""
var _category_buttons: Array[Button] = []
var _grid: GridContainer
var _detail_panel: Panel
var _detail_box: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_build_ui()
	_refresh()


func _on_shown() -> void:
	# 每次切回面板时刷新（战斗结算/发放后数量可能已变化）。
	_refresh()


func _build_ui() -> void:
	var topbar := HBoxContainer.new()
	topbar.add_theme_constant_override("separation", 10)
	add_child(topbar)
	var title := Label.new()
	title.text = "背包"
	title.add_theme_font_override("font", UITheme.spaced_font(3))
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	topbar.add_child(title)
	for resource_id in RESOURCE_CHIP_IDS:
		var item := GameFlow.load_item_data(resource_id)
		if item == null:
			continue
		var chip := Label.new()
		chip.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.TAG_OPEN_BG, 11, 4))
		chip.add_theme_font_size_override("font_size", 14)
		chip.add_theme_color_override("font_color", UITheme.TAG_OPEN_FG)
		chip.text = "%s ×%d" % [item.display_name, int(ProfileStore.get_profile().items.get(resource_id, 0))]
		topbar.add_child(chip)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(top_spacer)
	var capacity := Label.new()
	capacity.name = "CapacityChip"
	capacity.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.LIGHT_BLUE_SOFT, 11, 4))
	capacity.add_theme_font_size_override("font_size", 14)
	capacity.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	topbar.add_child(capacity)

	# 类目筛选（概念图 .filters：全部 + 类型 chips，Kenney 蓝选中）
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	add_child(filter_row)
	var group := ButtonGroup.new()
	var categories := [-1] + range(ITEM_TYPE_NAMES.size())
	for category_index in categories:
		var button := Button.new()
		button.text = "全部" if category_index < 0 else ITEM_TYPE_NAMES[category_index]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(84, 40)
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_on_category_pressed.bind(category_index))
		filter_row.add_child(button)
		_category_buttons.append(button)
		# 未选中项同样应用灰 Kenney（v0.19.1 修复：缺样式回落默认深色主题）
		UITheme.apply_kenney_rect_button(button, "grey", UITheme.LIGHT_BODY)
		if category_index == -1:
			button.button_pressed = true
			UITheme.apply_kenney_rect_button(button, "blue", Color.WHITE)
	var filter_hint := Label.new()
	filter_hint.text = "点击卡片查看说明 · 遗物与信物为永久持有，不消耗"
	filter_hint.add_theme_font_size_override("font_size", 13)
	filter_hint.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	filter_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	filter_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	filter_row.add_child(filter_hint)

	# 测试发放行（v0.15.1）：仅测试使用。
	var grant_row := HBoxContainer.new()
	grant_row.add_theme_constant_override("separation", 10)
	add_child(grant_row)
	var grant_hint := Label.new()
	grant_hint.text = "测试工具："
	grant_hint.add_theme_font_size_override("font_size", 14)
	grant_hint.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	grant_row.add_child(grant_hint)
	var grant_button := Button.new()
	grant_button.text = "获得练兵令 ×10"
	grant_button.custom_minimum_size = Vector2(160, 40)
	grant_button.focus_mode = Control.FOCUS_NONE
	grant_button.add_theme_font_size_override("font_size", 14)
	UITheme.apply_kenney_rect_button(grant_button, "grey", UITheme.LIGHT_BODY)
	grant_button.pressed.connect(_on_grant_exp_scroll)
	grant_row.add_child(grant_button)
	var relic_grant_button := Button.new()
	relic_grant_button.text = "获得测试遗物 ×1（各）"
	relic_grant_button.custom_minimum_size = Vector2(180, 40)
	relic_grant_button.focus_mode = Control.FOCUS_NONE
	relic_grant_button.add_theme_font_size_override("font_size", 14)
	UITheme.apply_kenney_rect_button(relic_grant_button, "grey", UITheme.LIGHT_BODY)
	relic_grant_button.pressed.connect(_on_grant_test_relics)
	grant_row.add_child(relic_grant_button)

	# 道具卡片网格（概念图 .itemgrid：4 列白卡）
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_grid)

	# 底部说明条（概念图 .detail：白底黄框）
	_detail_panel = Panel.new()
	_detail_panel.custom_minimum_size = Vector2(0, 96)
	var detail_style := UITheme.light_panel_style()
	detail_style.border_color = UITheme.LIGHT_GOLD_SELECT
	detail_style.content_margin_left = 14.0
	detail_style.content_margin_right = 14.0
	detail_style.content_margin_top = 10.0
	detail_style.content_margin_bottom = 10.0
	_detail_panel.add_theme_stylebox_override("panel", detail_style)
	add_child(_detail_panel)
	_detail_box = VBoxContainer.new()
	_detail_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_box.offset_left = 14.0
	_detail_box.offset_right = -14.0
	_detail_box.offset_top = 10.0
	_detail_box.offset_bottom = -10.0
	_detail_box.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(_detail_box)
	_show_detail_hint("点击上方卡片查看道具说明")


func _on_category_pressed(category_index: int) -> void:
	_category = category_index
	for i in _category_buttons.size():
		var button := _category_buttons[i]
		var active := button.button_pressed
		UITheme.apply_kenney_rect_button(button, "blue" if active else "grey",
			Color.WHITE if active else UITheme.LIGHT_BODY)
	_refresh()


func _show_detail_hint(text: String) -> void:
	for child in _detail_box.get_children():
		child.queue_free()
	var hint := Label.new()
	hint.text = text
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	_detail_box.add_child(hint)


func _show_detail(item_id: String) -> void:
	for child in _detail_box.get_children():
		child.queue_free()
	var item := GameFlow.load_item_data(item_id)
	if item == null:
		return
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_detail_box.add_child(head)
	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.add_theme_font_override("font", UITheme.spaced_font(2))
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	head.add_child(name_label)
	var type_name: String = ITEM_TYPE_NAMES[item.item_type] if item.item_type >= 0 and item.item_type < ITEM_TYPE_NAMES.size() else "未知"
	head.add_child(UITheme.tag_label(type_name, UITheme.TAG_OPEN_FG, UITheme.TAG_OPEN_BG, 12))
	var amount := int(ProfileStore.get_profile().items.get(item_id, 0))
	var amount_label := Label.new()
	amount_label.text = "持有 ×%d" % amount
	amount_label.add_theme_font_size_override("font_size", 15)
	amount_label.add_theme_color_override("font_color", UITheme.LIGHT_ACCENT)
	head.add_child(amount_label)
	var desc := Label.new()
	desc.text = item.description if not item.description.is_empty() else "（无描述）"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	_detail_box.add_child(desc)


func _on_grant_exp_scroll() -> void:
	var profile := ProfileStore.get_profile()
	profile.add_item(EXP_SCROLL_ID, 10)
	ProfileStore.save_profile()
	_refresh()


func _on_grant_test_relics() -> void:
	var profile := ProfileStore.get_profile()
	for relic_id in TEST_RELIC_IDS:
		profile.add_item(relic_id, 1)
	ProfileStore.save_profile()
	_refresh()


func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var profile := ProfileStore.get_profile()
	var entries: Array = []
	for key in profile.items.keys():
		var item_id := str(key)
		if item_id == "gacha_token":
			continue  # 求贤令抽将暂时移除（v0.30.0）：库存隐藏，恢复时删除本过滤
		var amount := int(profile.items.get(key, 0))
		if amount > 0:
			entries.append([item_id, amount])
	entries.sort()
	var topbar := get_child(0) as HBoxContainer
	var capacity := topbar.get_node("CapacityChip") as Label
	capacity.text = "共 %d 种" % entries.size()
	var visible_entries: Array = []
	for entry in entries:
		if _category >= 0:
			var item := GameFlow.load_item_data(str(entry[0]))
			if item == null or item.item_type != _category:
				continue
		visible_entries.append(entry)
	if visible_entries.is_empty():
		var empty := Label.new()
		empty.text = "该类目下暂无道具——通关掉落、一键通关或测试发放会获得道具。"
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
		_grid.add_child(empty)
		return
	for entry in visible_entries:
		_grid.add_child(_make_item_card(str(entry[0]), int(entry[1])))
	if _selected_id != "" and not entries.any(func(entry) -> bool: return str(entry[0]) == _selected_id):
		_selected_id = ""
	if _selected_id != "":
		_show_detail(_selected_id)
	else:
		_show_detail_hint("点击上方卡片查看道具说明")


func _make_item_card(item_id: String, amount: int) -> Button:
	var item := GameFlow.load_item_data(item_id)
	var display_name := item.display_name if item != null else item_id
	var type_index: int = item.item_type if item != null and item.item_type >= 0 else 0
	var type_name: String = ITEM_TYPE_NAMES[type_index] if item != null and item.item_type >= 0 and item.item_type < ITEM_TYPE_NAMES.size() else "未知"
	var selected := item_id == _selected_id

	var card := Button.new()
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 108)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := UITheme.light_panel_style()
	card_style.set_border_width_all(2)
	var selected_style := card_style.duplicate()
	selected_style.bg_color = Color("#fffdf2")
	selected_style.border_color = UITheme.LIGHT_GOLD_SELECT
	selected_style.set_border_width_all(3)
	selected_style.shadow_color = Color(1.0, 0.8, 0.0, 0.35)
	selected_style.shadow_size = 6
	card.add_theme_stylebox_override("normal", card_style)
	card.add_theme_stylebox_override("hover", card_style)
	card.add_theme_stylebox_override("pressed", selected_style)
	card.add_theme_stylebox_override("hover_pressed", selected_style)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.set_pressed_no_signal(selected)
	card.set_meta("item_id", item_id)
	card.pressed.connect(_on_card_pressed.bind(item_id))

	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 12.0
	content.offset_right = -12.0
	content.offset_top = 10.0
	content.offset_bottom = -10.0
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	content.add_child(UITheme.avatar_label(display_name.left(1), TYPE_COLORS[type_index % TYPE_COLORS.size()], 44.0, 20))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_row)
	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	name_row.add_child(name_label)
	name_row.add_child(UITheme.tag_label(type_name, UITheme.TAG_OPEN_FG, UITheme.TAG_OPEN_BG, 11))
	var desc := Label.new()
	desc.text = item.description if item != null and not item.description.is_empty() else "（无描述）"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UITheme.LIGHT_DESC)
	desc.max_lines_visible = 2
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(desc)
	var amount_label := Label.new()
	amount_label.text = "×%d" % amount
	amount_label.add_theme_font_size_override("font_size", 15)
	amount_label.add_theme_color_override("font_color", UITheme.LIGHT_ACCENT)
	content.add_child(amount_label)
	return card


func _on_card_pressed(item_id: String) -> void:
	_selected_id = item_id
	for child in _grid.get_children():
		var card := child as Button
		if card != null:
			card.set_pressed_no_signal(str(card.get_meta("item_id", "")) == item_id)
	_show_detail(item_id)
