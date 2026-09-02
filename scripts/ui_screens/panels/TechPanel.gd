extends VBoxContainer

## 科技树面板（阶段 8 提交 3；v0.30.2 树状重构、v0.30.3 布局修正）：
## 四类分页（军略/后勤/工事/将略）+ 树状布局——行 = tier 层级（同级并排）、列 = 前置链，
## 根节点金边、叶子节点绿边、中间节点灰边，父→子以竖线连接；
## 点击节点显示详情与解锁操作；科技重置（v0.23.0 拍板）无条件——免费/不限次数/全额返还（v0.30.2 补确认框）。

const NODE_MIN_WIDTH := 116
const NODE_HEIGHT := 62
## 测试辅助（v0.30.4）：单次点击增加的科技点，不改变正式数值与结算逻辑。
const DEBUG_POINTS_AMOUNT: int = 50

var _points_label: Label
var _tab_container: TabContainer
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_state: Label
var _detail_summary: Label
var _detail_desc: Label
var _unlock_button: Button
var _confirm_dialog: ConfirmationDialog
var _selected_item: TechItemData = null
var _node_buttons: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_build_ui()
	_refresh()


func _on_shown() -> void:
	_refresh()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "科技树"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.GOLD)
	add_child(title)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	add_child(top_row)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 24)
	_points_label.add_theme_color_override("font_color", UITheme.GOLD)
	top_row.add_child(_points_label)
	var reset_button := Button.new()
	reset_button.text = "重置科技（全额返还）"
	reset_button.custom_minimum_size = Vector2(200, 38)
	reset_button.add_theme_font_size_override("font_size", 15)
	reset_button.pressed.connect(_on_reset_pressed)
	top_row.add_child(reset_button)

	var debug_button := Button.new()
	debug_button.text = "科技点+%d（测试）" % DEBUG_POINTS_AMOUNT
	debug_button.custom_minimum_size = Vector2(140, 38)
	debug_button.add_theme_font_size_override("font_size", 13)
	debug_button.add_theme_color_override("font_color", UITheme.GRAY)
	debug_button.pressed.connect(_on_debug_add_points)
	top_row.add_child(debug_button)

	var legend := Label.new()
	legend.text = "图例：金边=根节点（起点） · 绿边=叶子节点（终点） · 竖线=前置关系"
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", UITheme.GRAY)
	add_child(legend)

	_tab_container = TabContainer.new()
	_tab_container.name = "Tabs"
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tab_container)
	for category in TechTree.get_categories():
		_tab_container.add_child(_build_tree(category))

	_build_detail_panel()
	_build_confirm_dialog()


## 树状布局：GridContainer 按「行 = tier 层级、列 = 前置链」排布，
## 同一 tier 的节点并排展示；链内父→子之间插入竖线连接行；无节点的格子以占位保持列对齐。
func _build_tree(category: String) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = category
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var chains := _get_chains(category)
	var grid := GridContainer.new()
	grid.name = "TreeGrid"
	grid.columns = chains.size()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var max_tier := 1
	for chain in chains:
		var last: TechItemData = chain[chain.size() - 1]
		max_tier = maxi(max_tier, last.tier)
	for tier in range(1, max_tier + 1):
		if tier > 1:
			# 连接行：链在该层有节点才显示竖线，其余格子占位保持列对齐。
			for chain in chains:
				grid.add_child(_make_connector(_chain_item_at_tier(chain, tier) != null))
		for chain in chains:
			var item := _chain_item_at_tier(chain, tier)
			if item != null:
				grid.add_child(_make_node_button(item, _is_chain_root(chain, item), _is_chain_leaf(chain, item)))
			else:
				grid.add_child(Control.new())
	return scroll


## 按前置链分组：无前置的条目为链根，沿 requires 将后续条目归入同链。
func _get_chains(category: String) -> Array:
	var items := TechTree.get_items_by_category(category)
	var by_id := {}
	for item in items:
		by_id[item.id] = item
	var chains_by_root := {}
	for item in items:
		var root_id := item.id
		var cursor := item
		while not cursor.requires.is_empty() and by_id.has(cursor.requires):
			root_id = cursor.requires
			cursor = by_id[cursor.requires]
		if not chains_by_root.has(root_id):
			chains_by_root[root_id] = []
		chains_by_root[root_id].append(item)
	var chains: Array = []
	for root_id in chains_by_root:
		var chain: Array = chains_by_root[root_id]
		chain.sort_custom(func(a: TechItemData, b: TechItemData) -> bool: return a.tier < b.tier)
		chains.append(chain)
	chains.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as TechItemData).id < (b[0] as TechItemData).id)
	return chains


func _chain_item_at_tier(chain: Array, tier: int) -> TechItemData:
	for item in chain:
		if item.tier == tier:
			return item
	return null


func _is_chain_root(chain: Array, item: TechItemData) -> bool:
	return item.id == (chain[0] as TechItemData).id


func _is_chain_leaf(chain: Array, item: TechItemData) -> bool:
	return item.id == (chain[chain.size() - 1] as TechItemData).id


func _make_node_button(item: TechItemData, is_root: bool, is_leaf: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(NODE_MIN_WIDTH, NODE_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 15)
	button.toggle_mode = true
	button.pressed.connect(_on_node_pressed.bind(item))
	button.set_meta("tech_id", item.id)
	button.set_meta("is_root", is_root)
	button.set_meta("is_leaf", is_leaf)
	_node_buttons[item.id] = button
	return button


func _make_connector(has_child: bool) -> Control:
	var cell := CenterContainer.new()
	if has_child:
		var line := ColorRect.new()
		line.color = UITheme.DISABLED
		line.custom_minimum_size = Vector2(2, 16)
		cell.add_child(line)
	return cell


func _build_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.PANEL_BG
	style.border_color = UITheme.SIDEBAR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_detail_panel.add_theme_stylebox_override("panel", style)
	_detail_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(_detail_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_detail_panel.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	box.add_child(top)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 17)
	top.add_child(_detail_title)
	_detail_state = Label.new()
	_detail_state.add_theme_font_size_override("font_size", 13)
	top.add_child(_detail_state)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_unlock_button = Button.new()
	_unlock_button.custom_minimum_size = Vector2(170, 34)
	_unlock_button.add_theme_font_size_override("font_size", 14)
	_unlock_button.pressed.connect(_on_unlock_pressed)
	top.add_child(_unlock_button)

	_detail_summary = Label.new()
	_detail_summary.add_theme_font_size_override("font_size", 13)
	_detail_summary.add_theme_color_override("font_color", UITheme.GRAY)
	box.add_child(_detail_summary)
	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 14)
	box.add_child(_detail_desc)

	_show_default_detail()


func _build_confirm_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "重置科技"
	var ok_button := _confirm_dialog.get_ok_button()
	if ok_button != null:
		ok_button.text = "确认重置"
	var cancel_button := _confirm_dialog.get_cancel_button()
	if cancel_button != null:
		cancel_button.text = "取消"
	_confirm_dialog.confirmed.connect(_do_reset)
	add_child(_confirm_dialog)


func _refresh() -> void:
	var profile := ProfileStore.get_profile()
	_points_label.text = "科技点：%d" % profile.tech_points
	for tech_id in _node_buttons.keys():
		var item := TechTree.get_item(tech_id)
		if item == null:
			continue
		_refresh_node(_node_buttons[tech_id], item)
	if _selected_item != null:
		_show_detail(_selected_item)


## 节点状态：已解锁=绿、可解锁=金（点数不足=正文色）、前置未满足=灰锁；
## 层级描边：根节点=金边、叶子节点=绿边、中间节点=灰边（文字色仍表状态）。
func _refresh_node(button: Button, item: TechItemData) -> void:
	var profile := ProfileStore.get_profile()
	var unlocked := TechTree.is_unlocked(profile, item.id)
	var prereq_ok := TechTree.prerequisites_met(profile, item)
	var state_color := UITheme.TEXT
	if unlocked:
		button.text = "%s\n已解锁 ✓" % item.name
		state_color = UITheme.GREEN
	elif prereq_ok:
		button.text = "%s\n解锁（%d 点）" % [item.name, item.cost]
		state_color = UITheme.GOLD if profile.tech_points >= item.cost else UITheme.TEXT
	else:
		button.text = "%s\n需前置科技" % item.name
		state_color = UITheme.DISABLED
	button.add_theme_color_override("font_color", state_color)
	button.add_theme_stylebox_override("normal", _make_node_style(button, false))
	button.add_theme_stylebox_override("hover", _make_node_style(button, true))
	var selected := _selected_item != null and _selected_item.id == item.id
	_apply_node_selected_style(button, selected)


## 层级样式：根=金边、叶=绿边、中间=灰边；hover 底色加深。
func _make_node_style(button: Button, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.PANEL_BG.darkened(0.12 if hover else 0.0)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	if bool(button.get_meta("is_root", false)):
		style.border_color = UITheme.SELECT_BORDER
	elif bool(button.get_meta("is_leaf", false)):
		style.border_color = UITheme.GREEN.darkened(0.35)
	else:
		style.border_color = UITheme.SIDEBAR_BORDER
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


## 选中节点：金色底 + 深色文字（覆盖按下态，不改变层级描边语义）。
func _apply_node_selected_style(button: Button, selected: bool) -> void:
	if selected:
		var style := StyleBoxFlat.new()
		style.bg_color = UITheme.SELECT_BG
		style.border_color = UITheme.SELECT_BORDER
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_color_override("font_pressed_color", UITheme.SELECT_TEXT)
		button.add_theme_color_override("font_hover_pressed_color", UITheme.SELECT_TEXT)
		button.set_pressed_no_signal(true)
	else:
		button.remove_theme_stylebox_override("pressed")
		button.remove_theme_color_override("font_pressed_color")
		button.remove_theme_color_override("font_hover_pressed_color")
		button.set_pressed_no_signal(false)


func _on_node_pressed(item: TechItemData) -> void:
	if _selected_item != null and _selected_item.id == item.id:
		return
	_selected_item = item
	_refresh()


## 详情区：名称 + 状态 + 解锁操作 + 摘要 + 详细描述（数值已含在描述文案中，
## v0.30.2 起不再单独输出 effect 字典，避免代码键泄漏）。
func _show_detail(item: TechItemData) -> void:
	var profile := ProfileStore.get_profile()
	var unlocked := TechTree.is_unlocked(profile, item.id)
	var prereq_ok := TechTree.prerequisites_met(profile, item)
	_detail_title.text = item.name
	_detail_title.add_theme_color_override("font_color", UITheme.GOLD)
	if unlocked:
		_detail_state.text = "已解锁"
		_detail_state.add_theme_color_override("font_color", UITheme.GREEN)
		_unlock_button.text = "已解锁 ✓"
		_unlock_button.disabled = true
	elif prereq_ok:
		_detail_state.text = "可解锁"
		_detail_state.add_theme_color_override("font_color", UITheme.GOLD)
		_unlock_button.text = "解锁（%d 点）" % item.cost
		_unlock_button.disabled = profile.tech_points < item.cost
	else:
		_detail_state.text = "前置未解锁"
		_detail_state.add_theme_color_override("font_color", UITheme.DISABLED)
		var req := TechTree.get_item(item.requires)
		_unlock_button.text = "需前置：%s" % (req.name if req != null else item.requires)
		_unlock_button.disabled = true
	_detail_summary.text = item.summary
	_detail_desc.text = item.description


func _show_default_detail() -> void:
	_detail_title.text = "科技树"
	_detail_title.add_theme_color_override("font_color", UITheme.GOLD)
	_detail_state.text = ""
	_unlock_button.text = ""
	_unlock_button.disabled = true
	_detail_summary.text = "点击科技节点查看详细说明；同一链（同列）节点需逐级解锁。"
	_detail_desc.text = ""


func _on_unlock_pressed() -> void:
	if _selected_item == null:
		return
	_on_tech_unlock(_selected_item.id, _selected_item.cost)


func _on_tech_unlock(tech_id: String, cost: int) -> void:
	if ProfileStore.get_profile().unlock_tech(tech_id, cost):
		ProfileStore.save_profile(ProfileStore.get_profile())
		_refresh()


## 测试辅助（仅测试用，v0.30.4）：快速增加科技点，便于验证科技树解锁链路。
func _on_debug_add_points() -> void:
	var profile := ProfileStore.get_profile()
	profile.tech_points += DEBUG_POINTS_AMOUNT
	ProfileStore.save_profile(profile)
	_refresh()


## 重置（v0.30.2 补确认框）：弹出确认后再清空，防止误触丢失全部科技。
func _on_reset_pressed() -> void:
	var profile := ProfileStore.get_profile()
	if profile.tech_unlocks.is_empty():
		_detail_title.text = "无需重置"
		_detail_title.add_theme_color_override("font_color", UITheme.GRAY)
		_detail_state.text = ""
		_unlock_button.text = ""
		_unlock_button.disabled = true
		_detail_summary.text = ""
		_detail_desc.text = "当前没有已解锁科技，无需重置。"
		return
	var refund := 0
	for tech_id in profile.tech_unlocks:
		var item := TechTree.get_item(tech_id)
		if item != null:
			refund += item.cost
	_confirm_dialog.dialog_text = "将清空 %d 项已解锁科技，并全额返还 %d 科技点。确定重置？" % [
		profile.tech_unlocks.size(), refund,
	]
	_confirm_dialog.popup_centered()


func _do_reset() -> void:
	var profile := ProfileStore.get_profile()
	var refund := TechTree.reset_tech(profile)
	ProfileStore.save_profile(profile)
	_selected_item = null
	_refresh()
	_detail_title.text = "重置完成"
	_detail_title.add_theme_color_override("font_color", UITheme.GREEN)
	_detail_state.text = ""
	_unlock_button.text = ""
	_unlock_button.disabled = true
	_detail_summary.text = ""
	_detail_desc.text = "已清空全部科技，返还 %d 科技点。" % refund