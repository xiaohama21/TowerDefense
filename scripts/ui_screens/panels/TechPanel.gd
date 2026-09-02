extends VBoxContainer

## 科技树面板（阶段 8 提交 3；v0.30.2 树状重构）：
## 四类分页（军略/后勤/工事/将略）+ 树状布局（前置链分列、tier 分层、竖线连接）+
## 点击节点显示详情与解锁操作；科技重置（v0.23.0 拍板）无条件——免费/不限次数/全额返还（v0.30.2 补确认框）。

const NODE_SIZE := Vector2(140, 62)

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
	add_theme_constant_override("separation", 10)
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

	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tab_container)
	for category in TechTree.get_categories():
		_tab_container.add_child(_build_tree(category))

	_build_detail_panel()
	_build_confirm_dialog()


## 树状布局：每个分类内按前置链分列（GridContainer 列 = 链），
## 列内节点按 tier 从上到下排列，节点间以竖线连接，形成清晰的树形结构。
func _build_tree(category: String) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = category
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.name = "TreeGrid"
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for chain in _get_chains(category):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 4)
		for i in chain.size():
			var item: TechItemData = chain[i]
			column.add_child(_make_node_button(item))
			if i < chain.size() - 1:
				column.add_child(_make_connector())
		grid.add_child(column)
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


func _make_node_button(item: TechItemData) -> Button:
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 15)
	button.toggle_mode = true
	button.pressed.connect(_on_node_pressed.bind(item))
	button.set_meta("tech_id", item.id)
	_node_buttons[item.id] = button
	return button


func _make_connector() -> Control:
	var connector := CenterContainer.new()
	var line := ColorRect.new()
	line.color = UITheme.DISABLED
	line.custom_minimum_size = Vector2(2, 14)
	connector.add_child(line)
	return connector


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


## 节点状态：已解锁=绿、可解锁=金（点数不足=正文色）、前置未满足=灰锁。
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
	var selected := _selected_item != null and _selected_item.id == item.id
	_apply_node_selected_style(button, selected)


## 选中节点：金色描边 + 按下态保持（不改变状态色语义）。
func _apply_node_selected_style(button: Button, selected: bool) -> void:
	if selected:
		var style := StyleBoxFlat.new()
		style.bg_color = UITheme.PANEL_BG
		style.border_color = UITheme.SELECT_BORDER
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override("pressed", style)
		button.set_pressed_no_signal(true)
	else:
		button.remove_theme_stylebox_override("pressed")
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
	_detail_summary.text = "点击科技节点查看详细说明；同一列节点需逐级解锁。"
	_detail_desc.text = ""


func _on_unlock_pressed() -> void:
	if _selected_item == null:
		return
	_on_tech_unlock(_selected_item.id, _selected_item.cost)


func _on_tech_unlock(tech_id: String, cost: int) -> void:
	if ProfileStore.get_profile().unlock_tech(tech_id, cost):
		ProfileStore.save_profile(ProfileStore.get_profile())
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