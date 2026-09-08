extends VBoxContainer

## 科技树面板（阶段 8 提交 3；v0.30.2 树状重构、v0.30.3 布局修正；
## v0.20.15 第三次对齐概念图 ui_tech.png / ui_tech.html）：
## 顶栏一行（标题 + 科技点/已解锁 + 重置 + 测试按钮）+ 分类 Kenney 按钮行（图例右对齐）+ 树状布局：
## 行 = tier 层级（首列竖排层级胶囊 + 同层节点按概念顺序并排），父→子以同列竖线连接；
## 节点卡白底 3px 状态描边（绿=已解锁/金=可解锁/灰=需前置），卡内 左上层级符 + 右上状态字 +
## 名称 + 摘要 + 底部 消耗/✓/前置名；点击节点显示详情与解锁操作；
## 科技重置（v0.23.0 拍板）无条件——免费/不限次数/全额返还（v0.30.2 补确认框）。

const NODE_MIN_WIDTH := 118.0
const NODE_HEIGHT := 92.0
const TIER_LABEL_WIDTH := 52.0
const ROW_GAP := 8
## 树区可用宽（1280×720 大厅内容区实测 1000px；卡宽不足时用最小卡宽兜底）。
const AVAIL_WIDTH := 1000.0
const MAX_CARD_WIDTH := 480.0
const PROFESSION_BONUS_CAP := 10
## 层级行装饰符（概念图：基础强化行 ◆ / 进阶强化行 ○ / 终极强化行 ◆，仅装饰）。
const TIER_GLYPHS := ["◆", "○", "◆"]
## 军略职业线概念顺序（全武将 → 虎贲 → 骑兵 → 弓手 → 术士 → 舞娘 → 投石车）。
const PROFESSION_BASES := [
	"prof_tiger_guard", "prof_cavalry", "prof_archer",
	"prof_strategist", "prof_dancer", "prof_catapult",
]
## 分类子类描述（详情 chip：概念图「军略 · 职业强化」，GDD v0.23.0 拍板定名）。
const CATEGORY_SUB := {"军略": "职业强化", "后勤": "经济节奏", "工事": "防御", "将略": "机制"}
## 节点卡概念色（ui_tech.html .node/.node.done/.node.open/.node.wait）。
const NODE_BG_DONE := Color("#f2fbf5")
const NODE_BG_OPEN := Color("#fffdf0")
const NODE_BG_WAIT := Color("#eef3f7")
const NODE_BORDER_DONE := Color("#52c48a")
const NODE_BORDER_OPEN := Color("#ffcc00")
const NODE_BORDER_WAIT := Color("#cddbe6")
const GLYPH_COLOR := Color("#9fd0ea")
const TIER_PILL_BG := Color("#e8f2f9")
## 测试辅助（v0.30.4）：单次点击增加的科技点，不改变正式数值与结算逻辑。
const DEBUG_POINTS_AMOUNT: int = 50

var _points_label: Label
var _unlocked_count_label: Label
var _tree_area: VBoxContainer
var _tree_scrolls: Dictionary = {}
var _category_buttons: Dictionary = {}
var _detail_cap_pill: Label
var _detail_panel: PanelContainer
var _detail_title: Label
var _detail_state: Label
var _detail_summary: Label
var _detail_desc: Label
var _detail_category_chip: Label
var _detail_prereq_pill: Label
var _detail_invested_pill: Label
var _detail_cost_label: Label
var _detail_balance_label: Label
var _chain_of_item: Dictionary = {}
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


## 顶部结构（对齐概念 .topbar + .tabs）：标题/计数/按钮一行 + 分类按钮行（右侧图例）。
func _build_ui() -> void:
	var topbar := HBoxContainer.new()
	topbar.add_theme_constant_override("separation", 14)
	add_child(topbar)
	var title := Label.new()
	title.text = "科技树"
	title.add_theme_font_override("font", UITheme.spaced_font(3))
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	topbar.add_child(title)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(top_spacer)
	_points_label = Label.new()
	_points_label.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.TAG_OPEN_BG, 11, 4))
	_points_label.add_theme_font_size_override("font_size", 16)
	_points_label.add_theme_color_override("font_color", UITheme.TAG_OPEN_FG)
	topbar.add_child(_points_label)
	_unlocked_count_label = Label.new()
	_unlocked_count_label.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.LIGHT_BLUE_SOFT, 11, 4))
	_unlocked_count_label.add_theme_font_size_override("font_size", 16)
	_unlocked_count_label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	topbar.add_child(_unlocked_count_label)
	var reset_button := Button.new()
	reset_button.text = "重置"
	reset_button.custom_minimum_size = Vector2(118, 40)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.add_theme_font_size_override("font_size", 14)
	UITheme.apply_kenney_rect_button(reset_button, "grey", UITheme.LIGHT_BODY)
	reset_button.pressed.connect(_on_reset_pressed)
	topbar.add_child(reset_button)
	# 测试辅助按钮保留（用户拍板 0.8.10.28 保留）：仅测试用，不进入正式结算逻辑。
	var debug_button := Button.new()
	debug_button.text = "科技点+%d（测试）" % DEBUG_POINTS_AMOUNT
	debug_button.custom_minimum_size = Vector2(150, 40)
	debug_button.focus_mode = Control.FOCUS_NONE
	debug_button.add_theme_font_size_override("font_size", 13)
	UITheme.apply_kenney_rect_button(debug_button, "grey", UITheme.LIGHT_BODY)
	debug_button.pressed.connect(_on_debug_add_points)
	topbar.add_child(debug_button)

	add_child(_build_category_bar())
	_tree_area = VBoxContainer.new()
	_tree_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tree_area)
	var categories := TechTree.get_categories()
	for category in categories:
		var scroll := _build_tree(category)
		scroll.name = category
		scroll.visible = false
		_tree_scrolls[category] = scroll
		_tree_area.add_child(scroll)
	_build_detail_panel()
	_build_confirm_dialog()
	_set_category(categories[0])


## 分类按钮行（概念 .tabs：4 枚 118×44 Kenney 蓝/灰按钮 + 图例右对齐）。
func _build_category_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", ROW_GAP)
	var categories := TechTree.get_categories()
	for i in categories.size():
		var category: String = categories[i]
		var button := Button.new()
		button.text = category
		button.custom_minimum_size = Vector2(118, 44)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", UITheme.spaced_font(2))
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_set_category.bind(category))
		_category_buttons[category] = button
		bar.add_child(button)
	var bar_spacer := Control.new()
	bar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(bar_spacer)
	bar.add_child(_make_legend())
	return bar


## 图例（概念 .legend：色块 + 状态名 + ◆ 根节点说明，位于分类按钮行右侧）。
func _make_legend() -> Control:
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 14)
	legend.add_child(_make_legend_item(NODE_BORDER_OPEN, "可解锁"))
	legend.add_child(_make_legend_item(NODE_BORDER_DONE, "已解锁"))
	legend.add_child(_make_legend_item(NODE_BORDER_WAIT, "需前置"))
	var note := Label.new()
	note.text = "◆ 根节点 → 逐层解锁"
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)
	legend.add_child(note)
	return legend


func _make_legend_item(swatch_color: Color, text: String) -> Control:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 5)
	var swatch := Panel.new()
	swatch.custom_minimum_size = Vector2(12, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = swatch_color
	style.set_corner_radius_all(3)
	swatch.add_theme_stylebox_override("panel", style)
	item.add_child(swatch)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	item.add_child(label)
	return item


## 切换分类：显隐树滚动区 + 按钮选中态（蓝底白字/灰底深字），并复位详情为默认。
func _set_category(category: String) -> void:
	for key in _tree_scrolls.keys():
		(_tree_scrolls[key] as Control).visible = key == category
	for key in _category_buttons.keys():
		var button := _category_buttons[key] as Button
		var active: bool = key == category
		UITheme.apply_kenney_rect_button(button, "blue" if active else "grey",
			Color.WHITE if active else UITheme.LIGHT_BODY)
	_selected_item = null
	_show_default_detail()
	_refresh()


## 层级行标签（概念图：基础强化 / 进阶强化 / 终极强化）。
const TIER_LABELS := {1: "基础强化", 2: "进阶强化", 3: "终极强化"}


## 树状布局（对齐概念 .tree/.tier）：每层一行 = 竖排层级胶囊 + 按概念顺序排节点；
## 层间插入连接行（父→子竖线与节点同列对齐）；军略终极层补 .t3-note 虚线提示条。
func _build_tree(category: String) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = category
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var chains := _get_chains(category)
	var card_w := _card_width(chains.size())
	var rows := VBoxContainer.new()
	rows.name = "TreeRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 2)
	scroll.add_child(rows)
	for chain in chains:
		for item in chain:
			_chain_of_item[item.id] = chain
	var max_tier := max_tier_of_chains(chains)
	for tier in range(1, max_tier + 1):
		if tier > 1:
			rows.add_child(_make_connector_band(chains, tier, card_w))
		rows.add_child(_make_tier_row(category, chains, tier, card_w))
	return scroll


## 节点卡宽度（对齐概念 .row flex:1 等分；受最小/最大卡宽约束）。
func _card_width(chain_count: int) -> float:
	if chain_count <= 0:
		return NODE_MIN_WIDTH
	var total_gap := float(chain_count) * float(ROW_GAP)
	var card_w := floorf((AVAIL_WIDTH - TIER_LABEL_WIDTH - total_gap) / float(chain_count))
	return clampf(card_w, NODE_MIN_WIDTH, MAX_CARD_WIDTH)


## 一行 = 层级胶囊 + 该层出现的链节点（顺序与连接行一致）。
func _make_tier_row(category: String, chains: Array, tier: int, card_w: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	row.add_child(_make_tier_label(tier))
	var glyph := _tier_glyph(tier)
	var present: Array = []
	for chain in chains:
		if _chain_item_at_tier(chain, tier) != null:
			present.append(chain)
	for chain in present:
		var item: TechItemData = _chain_item_at_tier(chain, tier)
		row.add_child(_make_node_button(item, glyph, card_w))
	# 军略终极层虚线提示条（概念 .t3-note，占满本行剩余空间）。
	if category == "军略" and tier == max_tier_of_chains(chains) and present.size() < chains.size():
		row.add_child(_make_t3_note())
	return row


func max_tier_of_chains(chains: Array) -> int:
	var out := 1
	for chain in chains:
		var last: TechItemData = chain[chain.size() - 1]
		out = maxi(out, last.tier)
	return out


## 层间连接行：层级列留空，逐链对齐节点列画 26px 竖线（仅该层有节点的链）。
func _make_connector_band(chains: Array, tier: int, card_w: float) -> Control:
	var band := HBoxContainer.new()
	band.add_theme_constant_override("separation", ROW_GAP)
	var empty_label_col := Control.new()
	empty_label_col.custom_minimum_size = Vector2(TIER_LABEL_WIDTH, 26)
	band.add_child(empty_label_col)
	for chain in chains:
		band.add_child(_make_connector(_chain_item_at_tier(chain, tier) != null, card_w))
	return band


## 竖排层级胶囊（概念 .tlabel：浅底圆角 + 文字竖排）。
func _make_tier_label(tier: int) -> Control:
	var pill := PanelContainer.new()
	pill.custom_minimum_size = Vector2(TIER_LABEL_WIDTH, NODE_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = TIER_PILL_BG
	style.set_corner_radius_all(10)
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	pill.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = _vertical_text(TIER_LABELS.get(tier, "第 %d 层" % tier))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	pill.add_child(label)
	return pill


func _vertical_text(text: String) -> String:
	var lines := PackedStringArray()
	for ch in text:
		lines.append(ch)
	return "\n".join(lines)


## 军略终极层提示条（概念 .t3-note：虚线框 + 弱色说明文字）。
func _make_t3_note() -> Control:
	var pill := DashedPill.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.setup(Color("#f5f9fc"), Color("#cddbe6"), 12.0)
	pill.add_theme_constant_override("margin_left", 16)
	pill.add_theme_constant_override("margin_right", 16)
	pill.add_theme_constant_override("margin_top", 10)
	pill.add_theme_constant_override("margin_bottom", 10)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(center)
	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 3)
	center.add_child(text_box)
	var head := Label.new()
	head.text = "军略 · 终极层"
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	text_box.add_child(head)
	var body := Label.new()
	body.text = "终极强化仅全武将线（精兵操练 → 老兵经验 → 百战精锐）开放；职业线最深 2 层，后续章节按新分类扩页签与节点。"
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(body)
	return pill


## 行装饰符（概念图逐行：基础强化 ◆ / 进阶强化 ○ / 终极强化 ◆）。
func _tier_glyph(tier: int) -> String:
	return TIER_GLYPHS[(tier - 1) % TIER_GLYPHS.size()]


## 按前置链分组：无前置的条目为链根，沿 requires 将后续条目归入同链；链间按概念顺序排。
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
		var ra := _chain_root_rank(str((a[0] as TechItemData).id))
		var rb := _chain_root_rank(str((b[0] as TechItemData).id))
		if ra != rb:
			return ra < rb
		return str((a[0] as TechItemData).id) < str((b[0] as TechItemData).id))
	return chains


## 链根排序权重：全武将线最先，职业线按概念顺序（虎贲→骑兵→弓手→术士→舞娘→投石车）。
func _chain_root_rank(root_id: String) -> int:
	var base := root_id.rsplit("_", true, 1)[0]
	if base == "mil_dmg":
		return 0
	var idx := PROFESSION_BASES.find(base)
	if idx >= 0:
		return idx + 1
	return 100


func _chain_item_at_tier(chain: Array, tier: int) -> TechItemData:
	for item in chain:
		if item.tier == tier:
			return item
	return null


func _is_chain_root(chain: Array, item: TechItemData) -> bool:
	return item.id == (chain[0] as TechItemData).id


func _is_chain_leaf(chain: Array, item: TechItemData) -> bool:
	return item.id == (chain[chain.size() - 1] as TechItemData).id


## 节点卡（概念 .node：3px 状态描边 + 层级符/状态字 + 名称 + 摘要 + 底部消耗/✓/前置）。
func _make_node_button(item: TechItemData, glyph: String, card_w: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(card_w, NODE_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.pressed.connect(_on_node_pressed.bind(item))
	button.set_meta("tech_id", item.id)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 9.0
	content.offset_right = -9.0
	content.offset_top = 6.0
	content.offset_bottom = -6.0
	content.add_theme_constant_override("separation", 2)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var strip := HBoxContainer.new()
	strip.name = "Strip"
	strip.add_theme_constant_override("separation", 6)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(strip)
	var glyph_label := Label.new()
	glyph_label.name = "GlyphLabel"
	glyph_label.text = glyph
	glyph_label.add_theme_font_size_override("font_size", 11)
	glyph_label.add_theme_color_override("font_color", GLYPH_COLOR)
	strip.add_child(glyph_label)
	var strip_spacer := Control.new()
	strip_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(strip_spacer)
	var state_label := Label.new()
	state_label.name = "StateLabel"
	state_label.add_theme_font_size_override("font_size", 10)
	strip.add_child(state_label)
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = item.name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(name_label)
	var summary_label := Label.new()
	summary_label.name = "SummaryLabel"
	summary_label.text = item.summary
	summary_label.add_theme_font_size_override("font_size", 11)
	summary_label.add_theme_color_override("font_color", UITheme.LIGHT_DESC)
	summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(summary_label)
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(bottom_spacer)
	var bottom_label := Label.new()
	bottom_label.name = "BottomLabel"
	bottom_label.add_theme_font_size_override("font_size", 12)
	content.add_child(bottom_label)
	_node_buttons[item.id] = button
	return button


func _make_connector(has_child: bool, card_w: float) -> Control:
	var cell := CenterContainer.new()
	cell.custom_minimum_size = Vector2(card_w, 26)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_child:
		var line := ColorRect.new()
		line.color = UITheme.LIGHT_BORDER_SOFT
		line.custom_minimum_size = Vector2(2, 26)
		cell.add_child(line)
	return cell


func _build_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	var style := UITheme.light_panel_style()
	style.set_border_width_all(3)
	style.border_color = UITheme.LIGHT_GOLD_SELECT
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_detail_panel.add_theme_stylebox_override("panel", style)
	_detail_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(_detail_panel)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	_detail_panel.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 5)
	columns.add_child(left)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	left.add_child(top)
	_detail_title = Label.new()
	_detail_title.add_theme_font_override("font", UITheme.spaced_font(2))
	_detail_title.add_theme_font_size_override("font_size", 21)
	_detail_title.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	top.add_child(_detail_title)
	# 分类 chip（概念 .lv：浅金底「军略 · 职业强化」）。
	_detail_category_chip = Label.new()
	_detail_category_chip.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.TAG_OPEN_BG, 10, 3))
	_detail_category_chip.add_theme_font_size_override("font_size", 13)
	_detail_category_chip.add_theme_color_override("font_color", UITheme.LIGHT_GOLD_TEXT)
	top.add_child(_detail_category_chip)
	_detail_state = UITheme.tag_label("", UITheme.TAG_OPEN_FG, UITheme.TAG_OPEN_BG, 12)
	top.add_child(_detail_state)

	_detail_summary = Label.new()
	_detail_summary.add_theme_font_size_override("font_size", 13)
	_detail_summary.add_theme_color_override("font_color", UITheme.LIGHT_ACCENT)
	left.add_child(_detail_summary)
	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 14)
	_detail_desc.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	left.add_child(_detail_desc)

	# 前置 / 同类已投入 pills（概念图 .d-stat 行）
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 8)
	left.add_child(pills)
	_detail_prereq_pill = _make_detail_pill()
	pills.add_child(_detail_prereq_pill)
	_detail_invested_pill = _make_detail_pill()
	pills.add_child(_detail_invested_pill)
	_detail_cap_pill = _make_detail_pill()
	pills.add_child(_detail_cap_pill)

	# 右列：消耗 / 余额 / 解锁按钮
	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 4)
	columns.add_child(right)
	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 6)
	right.add_child(cost_row)
	var cost_caption := Label.new()
	cost_caption.text = "消耗"
	cost_caption.add_theme_font_size_override("font_size", 12)
	cost_caption.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	cost_row.add_child(cost_caption)
	_detail_cost_label = Label.new()
	_detail_cost_label.add_theme_font_size_override("font_size", 15)
	_detail_cost_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	cost_row.add_child(_detail_cost_label)
	var balance_row := HBoxContainer.new()
	balance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	balance_row.add_theme_constant_override("separation", 6)
	right.add_child(balance_row)
	var balance_caption := Label.new()
	balance_caption.text = "余额"
	balance_caption.add_theme_font_size_override("font_size", 12)
	balance_caption.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	balance_row.add_child(balance_caption)
	_detail_balance_label = Label.new()
	_detail_balance_label.add_theme_font_size_override("font_size", 13)
	_detail_balance_label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	balance_row.add_child(_detail_balance_label)
	_unlock_button = Button.new()
	_unlock_button.custom_minimum_size = Vector2(150, 40)
	_unlock_button.focus_mode = Control.FOCUS_NONE
	_unlock_button.add_theme_font_size_override("font_size", 15)
	right.add_child(_unlock_button)
	_unlock_button.pressed.connect(_on_unlock_pressed)

	_show_default_detail()


func _make_detail_pill() -> Label:
	var pill := Label.new()
	pill.add_theme_stylebox_override("normal", _detail_pill_style())
	pill.add_theme_font_size_override("font_size", 12)
	pill.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	return pill


func _detail_pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.LIGHT_STAT_BG
	style.border_color = UITheme.LIGHT_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


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
	_points_label.text = "科技点 ×%d" % profile.tech_points
	_unlocked_count_label.text = "已解锁 %d 项" % profile.tech_unlocks.size()
	for tech_id in _node_buttons.keys():
		var item := TechTree.get_item(tech_id)
		if item == null:
			continue
		_refresh_node(_node_buttons[tech_id], item)
	if _selected_item != null:
		_show_detail(_selected_item)


## 节点状态（对齐概念 .node 三态）：已解锁=绿、可解锁=金、前置未满足=灰；
## 卡面 = 右上级状态字 + 名称/摘要 + 底部 消耗 / ✓ / 前置名。
func _refresh_node(button: Button, item: TechItemData) -> void:
	var profile := ProfileStore.get_profile()
	var unlocked := TechTree.is_unlocked(profile, item.id)
	var prereq_ok := TechTree.prerequisites_met(profile, item)
	var bg := Color.WHITE
	var border := UITheme.LIGHT_PANEL_BORDER
	var st_text := ""
	var st_color := UITheme.LIGHT_MUTED
	var bottom_text := ""
	var name_color := UITheme.LIGHT_INK
	var summary_color := UITheme.LIGHT_DESC
	if unlocked:
		bg = NODE_BG_DONE
		border = NODE_BORDER_DONE
		st_text = "✔ 已解锁"
		st_color = UITheme.TAG_OK_FG
		bottom_text = "✓"
	elif prereq_ok:
		bg = NODE_BG_OPEN
		border = NODE_BORDER_OPEN
		st_text = "可解锁"
		st_color = UITheme.LIGHT_GOLD_TEXT
		bottom_text = "科技点 ×%d" % item.cost
	else:
		bg = NODE_BG_WAIT
		border = NODE_BORDER_WAIT
		st_text = "🔒 需前置"
		st_color = UITheme.LIGHT_LOCK
		bottom_text = "前置：%s" % _prereq_display_name(item)
		name_color = UITheme.LIGHT_LOCK
		summary_color = UITheme.LIGHT_LOCK
	var content := button.get_child(0) as VBoxContainer
	var state_label := content.get_node("Strip/StateLabel") as Label
	state_label.text = st_text
	state_label.add_theme_color_override("font_color", st_color)
	var name_label := content.get_node("NameLabel") as Label
	name_label.text = item.name
	name_label.add_theme_color_override("font_color", name_color)
	var summary_label := content.get_node("SummaryLabel") as Label
	summary_label.text = item.summary
	summary_label.add_theme_color_override("font_color", summary_color)
	var bottom_label := content.get_node("BottomLabel") as Label
	bottom_label.text = bottom_text
	bottom_label.add_theme_color_override("font_color", st_color)
	_apply_node_style(button, bg, border, false)
	_apply_node_style(button, bg.darkened(0.05), border, true)
	var selected := _selected_item != null and _selected_item.id == item.id
	_apply_node_selected_style(button, selected)


func _prereq_display_name(item: TechItemData) -> String:
	if item.requires.is_empty():
		return "无"
	var req := TechTree.get_item(item.requires)
	return req.name if req != null else item.requires


## 节点卡样式（概念 .node：白底 + 3px 状态色描边 + 圆角 12）。
func _make_node_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	return style


## 应用节点四态样式（含 pressed/hover_pressed，防黑闪见 v0.19.2）。
func _apply_node_style(button: Button, bg: Color, border: Color, hover: bool) -> void:
	var style := _make_node_style(bg, border)
	if hover:
		button.add_theme_stylebox_override("hover", style)
	else:
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("hover_pressed", style)


## 选中节点：状态底/边框不变 + 金色外发光（概念 .node.sel 的 gold box-shadow 环）。
func _apply_node_selected_style(button: Button, selected: bool) -> void:
	if selected:
		var current := button.get_theme_stylebox("normal") as StyleBoxFlat
		var style: StyleBoxFlat = current.duplicate()
		style.shadow_color = Color(1.0, 0.8, 0.0, 0.5)
		style.shadow_size = 6
		style.shadow_offset = Vector2.ZERO
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("hover_pressed", style)
		button.set_pressed_no_signal(true)
	else:
		# 非选中分支保持 pressed/hover_pressed 覆盖为状态底色：
		# 移除覆盖会回落主题默认深色 pressed 样式，点击未选中节点瞬间黑闪（B-034 同款回归）。
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
	var can_unlock := prereq_ok and not unlocked and profile.tech_points >= item.cost
	_detail_title.text = item.name
	_detail_title.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	_detail_category_chip.text = "%s · %s" % [item.category, CATEGORY_SUB.get(item.category, "")]
	if unlocked:
		_detail_state.text = "已解锁"
		_detail_state.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.TAG_OK_BG, 9, 2))
		_detail_state.add_theme_color_override("font_color", UITheme.TAG_OK_FG)
		_unlock_button.text = "已解锁 ✓"
		_unlock_button.disabled = true
		_unlock_button.visible = true
	elif prereq_ok:
		_detail_state.text = "可解锁"
		_detail_state.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.TAG_OPEN_BG, 9, 2))
		_detail_state.add_theme_color_override("font_color", UITheme.LIGHT_GOLD_TEXT)
		_unlock_button.text = "解锁"
		_unlock_button.disabled = profile.tech_points < item.cost
		_unlock_button.visible = true
	else:
		_detail_state.text = "需前置"
		_detail_state.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.TAG_LOCK_BG, 9, 2))
		_detail_state.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)
		var req := TechTree.get_item(item.requires)
		_unlock_button.text = "需前置：%s" % (req.name if req != null else item.requires)
		_unlock_button.disabled = true
		_unlock_button.visible = true
	_apply_unlock_button_style(can_unlock)
	# 前置 / 同类已投入 pills
	var req_item := TechTree.get_item(item.requires)
	if req_item != null:
		var req_done := TechTree.is_unlocked(profile, req_item.id)
		_detail_prereq_pill.text = "前置 %s %s" % [req_item.name, "✓" if req_done else "未解锁"]
	else:
		_detail_prereq_pill.text = "前置 无（链根）"
	var chain: Array = _chain_of_item.get(item.id, [])
	var invested := 0
	for chain_item in chain:
		if TechTree.is_unlocked(profile, chain_item.id):
			invested += 1
	_detail_invested_pill.text = "同类已投入 %d 级" % invested
	# 职业加成合计（概念 .d-stat 第三枚：与该链各层数值合计 + 上限口径一致，仅职业线展示）
	var is_profession_chain := not chain.is_empty() and str((chain[0] as TechItemData).id).begins_with("prof_")
	if is_profession_chain:
		_detail_cap_pill.text = "职业加成合计 +%d%%（上限 +%d%%）" % [_chain_bonus_total(chain), PROFESSION_BONUS_CAP]
	else:
		_detail_cap_pill.text = "职业加成合计 —"
	_detail_cap_pill.visible = true
	# 消耗 / 余额
	_detail_cost_label.text = "科技点 ×%d" % item.cost
	_detail_balance_label.text = "%d · %s" % [profile.tech_points,
		"充足" if profile.tech_points >= item.cost else "不足"]
	_detail_summary.text = item.summary
	_detail_desc.text = item.description


## 职业链效果合计（取链内各条目 effect 数值之和，概念「职业加成合计 +9%」）。
func _chain_bonus_total(chain: Array) -> int:
	var total := 0
	for chain_item in chain:
		for value in (chain_item as TechItemData).effect.values():
			if value is int:
				total += value
			elif value is float:
				total += int(round(value))
	return total


## 解锁按钮样式：可解锁=金色描边+金字（醒目），不可解锁=灰。
func _apply_unlock_button_style(enabled: bool) -> void:
	# 解锁按钮（v0.19.0 换肤）：可解锁=黄 Kenney 主行动，不可=灰。
	UITheme.apply_kenney_rect_button(_unlock_button, "yellow" if enabled else "grey",
		UITheme.INK if enabled else UITheme.LIGHT_BODY)


func _show_default_detail() -> void:
	_detail_title.text = "科技树"
	_detail_title.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	_detail_state.text = ""
	_detail_category_chip.text = ""
	_unlock_button.text = ""
	_unlock_button.disabled = true
	_unlock_button.visible = false
	_detail_cost_label.text = "—"
	_detail_balance_label.text = "—"
	_detail_prereq_pill.text = "前置 —"
	_detail_invested_pill.text = "同类已投入 —"
	_detail_cap_pill.text = "职业加成合计 —"
	_detail_cap_pill.visible = true
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
		_detail_title.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
		_detail_state.text = ""
		_unlock_button.text = ""
		_unlock_button.disabled = true
		_unlock_button.visible = false
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
	_detail_title.add_theme_color_override("font_color", UITheme.TAG_OK_FG)
	_detail_state.text = ""
	_unlock_button.text = ""
	_unlock_button.disabled = true
	_unlock_button.visible = false
	_detail_summary.text = ""
	_detail_desc.text = "已清空全部科技，返还 %d 科技点。" % refund
