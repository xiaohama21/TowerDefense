extends Control
class_name TalentTreePanel

signal allocate_requested(node_id: String, expected_rank: int)
signal reset_requested
signal level_change_requested(delta: int)
signal dismissed

const COLORS := [Color("#d87e55"), Color("#429dcc"), Color("#54a78c")]
const EFFECT_NAMES := {
	"attack_pct": "基础攻击", "speed_pct": "攻击速度", "range_pct": "射程",
	"crit_rate": "暴击率", "crit_damage": "暴击伤害", "skill_amp": "所有技能增幅",
	"ultimate_amp": "大招增幅", "physical_damage_pct": "物理伤害", "magic_damage_pct": "魔法伤害",
	"attack_damage_pct": "普攻伤害", "elite_damage_pct": "对精英伤害", "boss_damage_pct": "对Boss伤害",
	"elite_boss_damage_pct": "对精英与Boss伤害", "aura_armor_damage_pct": "对护甲光环目标伤害",
	"low_hp_damage_pct": "对半血目标伤害", "controlled_damage_pct": "对受控目标伤害",
	"controlled_elite_damage_pct": "对受控精英与Boss伤害", "armor_pen_pct": "百分比穿甲",
	"armor_pen_flat": "固定穿甲", "ultimate_pen_pct": "大招穿甲", "same_target_pen_pct": "连续同目标穿甲",
	"kill_pen_flat": "击杀后固定穿甲", "kill_speed_pct": "击杀后攻速", "splash_pct": "普攻溅射半径",
	"rage_pct": "常规怒气获取", "hit_rage_flat": "普攻命中怒气", "kill_rage_flat": "击杀返怒",
	"ultimate_kill_rage": "大招击杀返怒", "leak_rage_flat": "每波首次漏怪怒气",
	"post_ultimate_rage_pct": "大招结束后怒气获取", "high_rage_speed_pct": "半怒攻速",
	"post_ultimate_hit_rage": "大招结束后命中怒气", "support_hit_rage": "辅助脉冲怒气",
	"control_duration_pct": "控制时长", "slow_strength_pct": "减速强度", "slow_on_hit": "普攻附加减速",
	"reveal_duration_pct": "现形时长", "buff_power_pct": "友方攻击与攻速增益强度",
	"buff_duration_pct": "限时友方增益时长", "ally_rage_pct": "月华友方积怒比例",
	"upgrade_discount_pct": "自身局内升阶费用降低", "kill_gold_pct": "自身击杀金币",
	"elite_gold_pct": "精英击杀金币", "boss_gold_pct": "Boss击杀金币",
}

var node_buttons: Dictionary = {}
var canvas: BranchCanvas
var reset_button: Button
var point_label: Label
var detail_action: Button
var detail_panel: PanelContainer
var selected_node_id := ""
var confirmation_open := false
var _layer: CanvasLayer
var _entry: Button
var _shell: PanelContainer
var _title: Label
var _message: Label
var _detail_overlay: Control
var _detail_error: Label
var _sim_controls: HBoxContainer
var _level_label: Label
var _minus: Button
var _plus: Button
var _character_id := ""
var _level := 1
var _alloc: Dictionary = {}
var _simulated := false
var _closed := false

static func open(host: Control, entry: Button) -> TalentTreePanel:
	var existing := host.get_node_or_null("TalentPopupLayer/TalentPopup") as TalentTreePanel
	if is_instance_valid(existing) and not existing._closed: return existing
	var layer := CanvasLayer.new()
	layer.name = "TalentPopupLayer"
	layer.layer = 55
	host.add_child(layer)
	var dialog := TalentTreePanel.new()
	dialog.name = "TalentPopup"
	dialog._layer = layer
	dialog._entry = entry
	layer.add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog._build_shell()
	host.visibility_changed.connect(dialog._host_visibility_changed.bind(host))
	return dialog

func _host_visibility_changed(host: Control) -> void:
	if not host.is_visible_in_tree(): dismiss()

func configure(character_id: String, level: int, alloc: Dictionary, simulated: bool = false) -> void:
	if _shell == null: _build_shell()
	if _character_id != character_id: close_detail(); selected_node_id = ""
	_character_id = character_id
	_level = level
	_alloc = alloc.duplicate(true)
	_simulated = simulated
	var character := GameFlow.load_character_data(character_id)
	_title.text = "%s · 天赋%s" % [character.display_name, "模拟" if simulated else " · Lv.%d" % level]
	_level_label.text = "Lv.%d" % level
	_sim_controls.visible = simulated
	_minus.disabled = level <= 1
	_plus.disabled = level >= 100
	point_label.text = "%d / %d" % [TalentRegistry.points_for_level(level) - TalentRegistry.spent(alloc), TalentRegistry.points_for_level(level)]
	reset_button.text = "清空模拟" if simulated else "免费重置"
	reset_button.disabled = alloc.is_empty()
	_message.visible = false
	canvas.configure(character_id, level, alloc, selected_node_id)
	node_buttons = canvas.node_buttons
	if is_instance_valid(_detail_overlay): _populate_detail()

func _build_shell() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := _shade(self, Color(0.02, 0.07, 0.13, 0.64))
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: dismiss())
	_shell = PanelContainer.new()
	_shell.name = "TalentWindow"
	_shell.add_theme_stylebox_override("panel", _style(UITheme.DIALOG_PANEL, UITheme.DIALOG_BORDER, 18, 3))
	add_child(_shell)
	resized.connect(_resize_shell)
	_resize_shell()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	_shell.add_child(body)
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _style(UITheme.DIALOG_HEAD, UITheme.DIALOG_HEAD, 14, 0, 14))
	header.custom_minimum_size.y = 54
	body.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	header.add_child(row)
	row.add_child(ConceptIcon.new("talent_point", 30))
	_title = _label("天赋", 23, Color.WHITE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	_sim_controls = HBoxContainer.new()
	_sim_controls.add_theme_constant_override("separation", 8)
	_minus = _button("−", func() -> void: level_change_requested.emit(-1), "grey")
	_plus = _button("+", func() -> void: level_change_requested.emit(1), "grey")
	_sim_controls.add_child(_minus)
	_level_label = _label("Lv.1", 17, Color.WHITE)
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sim_controls.add_child(_level_label)
	_sim_controls.add_child(_plus)
	row.add_child(_sim_controls)
	var close := _button("关闭", dismiss, "red")
	close.name = "CloseTalents"
	row.add_child(close)
	close.grab_focus()
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	column.add_child(toolbar)
	toolbar.add_child(ConceptIcon.new("talent_point", 24))
	point_label = _label("", 19, UITheme.LIGHT_INK)
	point_label.name = "TalentPoints"
	toolbar.add_child(point_label)
	var hint := _label("每5级获得2点 · 点击节点查看详情", 14, UITheme.LIGHT_MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(hint)
	reset_button = _button("免费重置", func() -> void: reset_requested.emit(), "blue")
	toolbar.add_child(reset_button)
	_message = _label("", 13, Color("#bd514b"))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	column.add_child(_message)
	canvas = BranchCanvas.new()
	canvas.name = "TalentBranches"
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.node_selected.connect(open_detail)
	column.add_child(canvas)
	var footer := _label("连线显示成长分支 · 解锁按本树已投入点数" , 13, UITheme.LIGHT_MUTED)
	footer.name = "TalentRule"
	column.add_child(footer)

func _resize_shell() -> void:
	if not is_instance_valid(_shell): return
	var available := get_viewport_rect().size
	_shell.size = Vector2(minf(1160, available.x - 48), minf(640, available.y - 48))
	_shell.position = (available - _shell.size) * 0.5

func _input(event: InputEvent) -> void:
	if _closed or confirmation_open: return
	if event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var scope: Node = detail_panel if is_instance_valid(detail_panel) else _shell
		var buttons: Array[Button] = []
		for control in scope.find_children("*", "Button", true, false):
			if control.is_visible_in_tree() and not control.disabled: buttons.append(control)
		if not buttons.is_empty():
			var index := buttons.find(get_viewport().gui_get_focus_owner())
			var step := -1 if event.is_action_pressed("ui_focus_prev") else 1
			var target := posmod(index + step, buttons.size()) if index >= 0 else (0 if step > 0 else buttons.size() - 1)
			buttons[target].grab_focus()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_instance_valid(_detail_overlay): close_detail()
		else: dismiss()

func dismiss() -> void:
	if _closed: return
	_closed = true
	visible = false
	close_detail()
	dismissed.emit()
	if is_instance_valid(_entry) and _entry.is_visible_in_tree(): _entry.grab_focus()
	if is_instance_valid(_layer): _layer.queue_free()
	else: queue_free()

func open_detail(id: String) -> void:
	if not node_buttons.has(id): return
	selected_node_id = id
	canvas.select_node(id)
	if not is_instance_valid(_detail_overlay):
		_detail_overlay = Control.new()
		_detail_overlay.name = "TalentNodeOverlay"
		_detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_detail_overlay)
		var dim := _shade(_detail_overlay, Color(0.02, 0.05, 0.10, 0.56))
		dim.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: close_detail())
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_detail_overlay.add_child(center)
		detail_panel = PanelContainer.new()
		detail_panel.name = "TalentNodeDetail"
		detail_panel.custom_minimum_size = Vector2(520, 0)
		detail_panel.add_theme_stylebox_override("panel", _style(UITheme.DIALOG_PANEL, UITheme.DIALOG_BORDER, 16, 3, 22))
		center.add_child(detail_panel)
	_populate_detail()

func _populate_detail() -> void:
	for child in detail_panel.get_children(): detail_panel.remove_child(child); child.queue_free()
	var node := TalentRegistry.node_data(selected_node_id)
	var tree := TalentRegistry.get_tree_data(selected_node_id.get_slice(".", 0))
	var rank := int(_alloc.get(selected_node_id, 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	detail_panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	head.add_child(ConceptIcon.new(effect_icon(node, tree.icon_key), 38))
	var title := _label(str(node.name), 23, UITheme.LIGHT_INK)
	title.name = "NodeName"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_label("Lv%d / 2" % rank, 17, UITheme.LIGHT_ACCENT))
	head.add_child(_button("关闭", close_detail, "grey"))
	box.add_child(_label("%s · %s" % [tree.display_name, "终极天赋" if int(node.tier) == 4 else "第%d层" % int(node.tier)], 14, UITheme.LIGHT_MUTED))
	var desc := _label(str(node.description), 16, UITheme.LIGHT_BODY)
	desc.name = "NodeDescription"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	var effects := HBoxContainer.new()
	effects.add_theme_constant_override("separation", 12)
	box.add_child(effects)
	for item in [["当前效果", effect_text(node, rank)], ["下级效果", effect_text(node, rank + 1) if rank < 2 else "已满级"]]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _style(Color("#eaf5fb"), Color("#c6e2ef"), 10, 1, 12))
		effects.add_child(card)
		var info := VBoxContainer.new()
		card.add_child(info)
		info.add_child(_label(item[0], 13, UITheme.LIGHT_MUTED))
		var value := _label(item[1], 15, UITheme.LIGHT_INK)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(value)
	var rule := _label(str(node.get("rule", node.description)), 14, UITheme.LIGHT_BODY)
	rule.name = "NodeRule"
	rule.visible = str(node.get("rule", node.description)) != str(node.description)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(rule)
	var threshold := int(TalentRegistry.THRESHOLDS[int(node.tier) - 1])
	var spent := TalentRegistry.spent(_alloc, tree.tree_id)
	box.add_child(_label("本树需投入%d点 · 当前%d点" % [threshold, spent], 14, UITheme.LIGHT_MUTED))
	var remaining := TalentRegistry.points_for_level(_level) - TalentRegistry.spent(_alloc)
	box.add_child(_label("剩余%d点 · %s" % [remaining, "模拟分配，不写入存档" if _simulated else "分配消耗1点，可免费重置"], 14, UITheme.LIGHT_MUTED))
	_detail_error = _label("", 14, Color("#bd514b"))
	_detail_error.name = "NodeError"
	_detail_error.visible = false
	_detail_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_error)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var status := TalentRegistry.allocation_status(_character_id, _level, _alloc, selected_node_id)
	var status_label := _label("可分配" if status == "分配" else status, 14, UITheme.LIGHT_MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(status_label)
	var id := selected_node_id
	detail_action = _button("模拟分配1点" if _simulated else "分配1点", func() -> void: allocate_requested.emit(id, rank), "blue")
	detail_action.name = "AllocateTalent"
	detail_action.disabled = status != "分配"
	actions.add_child(detail_action)
	detail_action.grab_focus()

func close_detail() -> void:
	if is_instance_valid(_detail_overlay):
		_detail_overlay.visible = false
		_detail_overlay.queue_free()
	_detail_overlay = null
	detail_panel = null
	detail_action = null
	if node_buttons.has(selected_node_id) and is_instance_valid(node_buttons[selected_node_id]): node_buttons[selected_node_id].grab_focus()

func show_error(message: String) -> void:
	_message.visible = true
	_message.text = message
	if is_instance_valid(_detail_error):
		_detail_error.visible = true
		_detail_error.text = message

static func effect_text(node: Dictionary, rank: int) -> String:
	if rank == 0: return "尚未分配"
	var effects := TalentRegistry.node_effects(node, rank)
	var lines := PackedStringArray()
	for key in effects:
		var value := float(effects[key])
		if key == "armor_ignore_every": lines.append("每%d次普攻命中触发" % int(value)); continue
		if key == "armor_ignore_mult": lines.append("追加%.0f%%攻击的真实伤害" % (value * 100)); continue
		var percent: bool = str(key).ends_with("_pct") or key in ["crit_rate", "crit_damage", "skill_amp", "ultimate_amp", "slow_on_hit"]
		var amount := String.num(value * 100 if percent else value, 2)
		lines.append("%s +%s%s" % [EFFECT_NAMES.get(key, "效果"), amount, "%" if percent else ""])
	return "\n".join(lines)

static func effect_icon(node: Dictionary, _fallback: String) -> String:
	return str(node.get("icon_key", "talent_" + str(node.id).replace(".", "_")))

static func _style(bg: Color, border: Color, radius: int, width: int, padding: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	for side in ["left", "right", "top", "bottom"]: style.set("content_margin_" + side, float(padding))
	return style

static func _label(text: String, pixels: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func _button(text: String, action: Callable, color: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	UITheme.apply_kenney_rect_button(button, color, Color.WHITE if color in ["blue", "red"] else UITheme.LIGHT_INK, 4.0)
	return button

static func _shade(parent: Control, color: Color) -> ColorRect:
	var dim := ColorRect.new()
	dim.color = color
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	return dim

class BranchCanvas extends Control:
	signal node_selected(id: String)
	var node_buttons: Dictionary = {}
	var node_positions: Dictionary = {}
	var edges: Array[Dictionary] = []
	var _trees: Array = []
	var _alloc: Dictionary = {}
	var _items: Array[Dictionary] = []
	var _labels: Array[Dictionary] = []
	var _selected := ""

	func _ready() -> void: resized.connect(_layout)

	func configure(id: String, level: int, alloc: Dictionary, selected: String) -> void:
		for child in get_children(): remove_child(child); child.queue_free()
		node_buttons.clear(); _items.clear(); _labels.clear(); _trees.clear()
		_alloc = alloc.duplicate(true)
		_selected = selected
		for tree_id in TalentRegistry.tree_ids(id):
			var tree := TalentRegistry.get_tree_data(tree_id)
			var index := _trees.size()
			_trees.append(tree)
			var title := TalentTreePanel._label(tree.display_name, 22, TalentTreePanel.COLORS[index])
			add_child(title)
			_labels.append({"control": title, "tree": index, "y": 4.0})
			var subtitle := TalentTreePanel._label("%s · %d/20点" % [tree.role, TalentRegistry.spent(alloc, tree_id)], 13, UITheme.LIGHT_MUTED)
			add_child(subtitle)
			_labels.append({"control": subtitle, "tree": index, "y": 32.0})
			var icon := ConceptIcon.new(tree.icon_key, 22)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(icon)
			_items.append({"control": icon, "tree": index, "root": true})
			for node in tree.nodes:
				var node_id := str(node.id)
				var rank := int(alloc.get(node_id, 0))
				var status := TalentRegistry.allocation_status(id, level, alloc, node_id)
				var button := Button.new()
				button.name = node_id.replace(".", "_")
				button.tooltip_text = "%s · Lv%d/2\n%s\n点击查看详情" % [node.name, rank, node.description]
				button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				var border: Color = TalentTreePanel.COLORS[index] if rank > 0 or status == "分配" else Color("#b8cbd6")
				var bg: Color = TalentTreePanel.COLORS[index].lightened(0.87) if rank > 0 else Color("#f8fbfd")
				button.add_theme_stylebox_override("normal", TalentTreePanel._style(bg, border, 28, 3))
				button.add_theme_stylebox_override("hover", TalentTreePanel._style(Color("#fff5ce"), Color("#d5ad45"), 28, 3))
				button.add_theme_stylebox_override("pressed", TalentTreePanel._style(Color("#ffe8a5"), Color("#c69a30"), 28, 3))
				button.add_theme_stylebox_override("hover_pressed", TalentTreePanel._style(Color("#ffe8a5"), Color("#c69a30"), 28, 3))
				button.add_theme_stylebox_override("focus", TalentTreePanel._style(Color.TRANSPARENT, Color("#e8b736"), 28, 3))
				button.pressed.connect(func() -> void: node_selected.emit(node_id))
				add_child(button)
				var pictogram := ConceptIcon.new(TalentTreePanel.effect_icon(node, tree.icon_key), 28)
				pictogram.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pictogram.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				for side in ["left", "top"]: pictogram.set("offset_" + side, 6.0)
				for side in ["right", "bottom"]: pictogram.set("offset_" + side, -6.0)
				pictogram.modulate.a = 1.0 if rank > 0 or status == "分配" else 0.48
				button.add_child(pictogram)
				var name_label := TalentTreePanel._label(str(node.name), 14, UITheme.LIGHT_INK if rank > 0 or status == "分配" else UITheme.LIGHT_BODY)
				name_label.name = "Name_" + button.name
				add_child(name_label)
				var level_label := TalentTreePanel._label("%d/2" % rank, 12, TalentTreePanel.COLORS[index] if rank > 0 else UITheme.LIGHT_MUTED)
				level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				level_label.add_theme_stylebox_override("normal", TalentTreePanel._style(Color("#f8fbfd"), border, 6, 1, 2))
				add_child(level_label)
				node_buttons[node_id] = button
				_items.append({"control": button, "label": name_label, "level": level_label, "tree": index, "node": node, "status": status, "rank": rank})
		_layout()

	func select_node(id: String) -> void:
		_selected = id
		queue_redraw()

	func _layout() -> void:
		if _trees.is_empty(): return
		var width := size.x / 3.0
		var rows := [size.y * 0.28, size.y * 0.47, size.y * 0.66, size.y * 0.87]
		node_positions.clear(); edges.clear()
		for item in _labels:
			var label := item.control as Label
			label.position = Vector2(item.tree * width + 8, item.y)
			label.size = Vector2(width - 16, 26)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for item in _items:
			var root := Vector2((item.tree + 0.5) * width, 68)
			if item.get("root", false):
				item.control.position = root - Vector2(11, 11)
				item.control.size = Vector2(22, 22)
				continue
			var node: Dictionary = item.node
			var tier := int(node.tier)
			var index: int = _trees[item.tree].nodes.find(node) % 3
			var x: float = ([0.19, 0.5, 0.81] if tier != 2 else [0.24, 0.5, 0.76])[index] if tier < 4 else 0.5
			var position := Vector2((item.tree + x) * width, rows[tier - 1])
			var diameter := 60.0 if tier == 4 else 52.0
			item.control.position = position - Vector2.ONE * diameter * 0.5
			item.control.size = Vector2.ONE * diameter
			item.label.position = position + Vector2(-width * 0.15, diameter * 0.5 + 3)
			item.label.size = Vector2(width * 0.3, 23)
			item.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			item.level.position = position + Vector2(15, 7)
			item.level.size = Vector2(32, 20)
			node_positions[str(node.id)] = position
		for item in _items:
			if item.get("root", false): continue
			var node: Dictionary = item.node
			var tier := int(node.tier)
			var tree: TalentTreeData = _trees[item.tree]
			var color: Color = TalentTreePanel.COLORS[item.tree] if item.rank > 0 else TalentTreePanel.COLORS[item.tree].lightened(0.55)
			if item.rank == 0 and item.status != "分配": color = Color("#cedce4")
			var end: Vector2 = node_positions[str(node.id)]
			var starts: Array[Vector2] = []
			if tier == 1: starts.append(Vector2((item.tree + 0.5) * width, 68))
			elif tier == 4:
				for previous in tree.nodes:
					if int(previous.tier) == 3: starts.append(node_positions[str(previous.id)])
			else:
				var index := tree.nodes.find(node)
				starts.append(node_positions[str(tree.nodes[index - 3].id)])
			for start in starts:
				edges.append({"start": start + Vector2(0, 12 if tier == 1 else 52), "end": end - Vector2(0, 30 if tier == 4 else 26), "color": color})
		queue_redraw()

	func _draw() -> void:
		var width := size.x / 3.0
		for index in range(3):
			var region := Rect2(index * width + 5, 0, width - 10, size.y)
			var style := TalentTreePanel._style(TalentTreePanel.COLORS[index].lightened(0.95), Color.TRANSPARENT, 14, 0)
			draw_style_box(style, region)
		for edge in edges:
			var start: Vector2 = edge.start
			var end: Vector2 = edge.end
			var midpoint := Vector2(start.x, start.y + (end.y - start.y) * 0.38)
			draw_polyline(PackedVector2Array([start, midpoint, end]), edge.color, 3.0, true)
			draw_circle(midpoint, 3.2, edge.color)
		if node_positions.has(_selected): draw_arc(node_positions[_selected], 31, 0, TAU, 40, Color("#e5b63f"), 2.0, true)
