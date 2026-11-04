extends VBoxContainer
class_name TalentTreePanel

signal allocate_requested(node_id: String, expected_rank: int)
signal reset_requested

var node_buttons: Dictionary = {}
var scroll: ScrollContainer
var reset_button: Button
var point_label: Label
var _message: Label
var _body: VBoxContainer
var _character_id: String = ""

func configure(character_id: String, level: int, alloc: Dictionary, simulated: bool = false) -> void:
	var previous_scroll := scroll.scroll_vertical if is_instance_valid(scroll) and _character_id == character_id else 0
	_character_id = character_id
	for child in get_children():
		remove_child(child)
		child.queue_free()
	node_buttons.clear()
	var margin := MarginContainer.new()
	margin.name = "TalentContentMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 16)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	margin.add_child(_body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_body.add_child(header)
	header.add_child(ConceptIcon.new("talent_point", 22))
	var total := TalentRegistry.points_for_level(level)
	point_label = _label("%d / %d" % [total - TalentRegistry.spent(alloc), total], 15, UITheme.LIGHT_INK)
	point_label.name = "TalentPoints"
	header.add_child(point_label)
	var rule := _label("模拟分配，不写入存档" if simulated else "每5级获得2点", 12, UITheme.LIGHT_MUTED)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(rule)
	reset_button = Button.new()
	reset_button.name = "ResetTalents"
	reset_button.text = "清空模拟" if simulated else "免费重置"
	reset_button.disabled = alloc.is_empty()
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	UITheme.apply_kenney_rect_button(reset_button, "blue", Color.WHITE, 5.0)
	header.add_child(reset_button)
	_message = _label("模拟分配，不写入存档。" if simulated else "分配可随时免费重置；高层门槛只计本树已投点数。", 12, UITheme.LIGHT_MUTED)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.name = "TalentMessage"
	_message.visible = false
	_body.add_child(_message)
	scroll = ScrollContainer.new()
	scroll.name = "TalentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.name = "TalentTrees"
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	for tree_id in TalentRegistry.tree_ids(character_id):
		var tree := TalentRegistry.get_tree_data(tree_id)
		var panel := PanelContainer.new()
		panel.name = tree_id
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var style := UITheme.light_panel_style()
		for side in ["left", "right", "top", "bottom"]: style.set("content_margin_" + side, 12.0)
		panel.add_theme_stylebox_override("panel", style)
		columns.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		panel.add_child(box)
		var tree_title := HBoxContainer.new()
		tree_title.add_theme_constant_override("separation", 5)
		tree_title.add_child(ConceptIcon.new(tree.icon_key, 20))
		tree_title.add_child(_label(tree.display_name, 19, UITheme.LIGHT_INK))
		box.add_child(tree_title)
		var subtitle := _label("%s · %d/20" % [tree.role, TalentRegistry.spent(alloc, tree_id)], 12, UITheme.LIGHT_MUTED)
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(subtitle)
		for tier in range(1, 5):
			var layer := VBoxContainer.new()
			layer.name = "Tier%d" % tier
			layer.add_theme_constant_override("separation", 8)
			box.add_child(layer)
			var threshold := int(TalentRegistry.THRESHOLDS[tier - 1])
			layer.add_child(_label("终极 · 本树%d点" % threshold if tier == 4 else "第%d层 · 本树%d点" % [tier, threshold], 12, UITheme.LIGHT_MUTED))
			for node in tree.nodes:
				if int(node.tier) != tier: continue
				layer.add_child(_node_card(character_id, level, alloc, node))
	_restore_scroll.call_deferred(scroll, previous_scroll)

func _restore_scroll(target_scroll: ScrollContainer, value: int) -> void:
	await get_tree().process_frame
	if not is_instance_valid(target_scroll): return
	var trees := target_scroll.get_child(0).get_children()
	var headings: Array[Control] = []
	var card_sets: Array = []
	var heading_height := 0.0
	for tree in trees:
		var heading := tree.get_child(0).get_child(1) as Control
		headings.append(heading)
		heading_height = maxf(heading_height, heading.size.y)
		card_sets.append(tree.find_children("*", "PanelContainer", true, false))
	for heading in headings: heading.custom_minimum_size.y = heading_height
	for index in range(10):
		var card_height := 0.0
		for cards in card_sets: card_height = maxf(card_height, cards[index].size.y)
		for cards in card_sets: cards[index].custom_minimum_size.y = card_height
	await get_tree().process_frame
	if is_instance_valid(target_scroll): target_scroll.scroll_vertical = value

func show_error(message: String) -> void:
	_message.visible = true
	_message.text = message
	_message.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)

func _node_card(character_id: String, level: int, alloc: Dictionary, node: Dictionary) -> Control:
	var id := str(node.id)
	var rank := int(alloc.get(id, 0))
	var status := TalentRegistry.allocation_status(character_id, level, alloc, id)
	var panel := PanelContainer.new()
	panel.name = id.replace(".", "_")
	panel.tooltip_text = str(node.get("rule", node.description))
	var style := UITheme.light_panel_style()
	style.bg_color = Color("#fff7e2") if rank > 0 else Color("#f4f6f8")
	style.border_color = Color("#c9a35c") if rank > 0 else Color("#d7dfe5")
	for side in ["left", "right", "top", "bottom"]: style.set("content_margin_" + side, 8.0)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 5)
	box.add_child(title)
	var name_label := _label(str(node.name), 14, UITheme.LIGHT_INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_child(name_label)
	title.add_child(_label("Lv%d/2" % rank, 11, UITheme.LIGHT_MUTED))
	var desc := _label(str(node.description), 12, UITheme.LIGHT_BODY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var status_label := _label("可分配" if status == "分配" else status, 11, UITheme.LIGHT_MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(status_label)
	var button := Button.new()
	button.text = "分配"
	button.custom_minimum_size = Vector2(48, 28)
	button.add_theme_font_size_override("font_size", 12)
	button.disabled = status != "分配"
	button.pressed.connect(func() -> void: allocate_requested.emit(id, rank))
	UITheme.apply_kenney_rect_button(button, "blue", Color.WHITE, 3.0)
	actions.add_child(button)
	node_buttons[id] = button
	return panel

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
