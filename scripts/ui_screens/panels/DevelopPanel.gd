extends VBoxContainer

## 武将养成面板（UI_LAYOUT §6，Kenney 换肤 v0.20.0 按概念图 ui_develop.png）：
## 左侧武将列表（头像圆 + 姓名 + 职业 + Lv 白卡，未解锁灰卡显示获取方式）；
## 右侧基础信息卡（头像/称呼 chips/大号等级/经验条/伤害·攻速·射程·建造费用四统计格）；
## 页签区：技能 / 品阶 / 信物；品阶手动进阶，三材料与等级双门槛。

signal back_requested

## 大招玩家向简述（同源 ENCYCLOPEDIA ULTIMATE_HINTS）。

## 角色专属技能玩家向文案（同源 ENCYCLOPEDIA CHARACTER_SKILL_HINTS）。

## 特性展示文案（CHARACTERS.md 4.7；阶段 9 升阶特性接入后改由数据源驱动）。

const AVATAR_COLORS := ["blue", "red", "gold", "green", "purple", "orange"]

## 职业 tags → 中文定位词（概念图 .rcard/.jcard 职业 tag 文案；tags 为英文机器标签，
## 不直接对玩家展示，B-040 引入展示映射后身份卡 tag 与概念「近战 · 持旗鼓舞」同构）。
const PROFESSION_TAG_LABELS := {
	&"melee": "近战",
	&"ranged": "远程",
	&"banner": "持旗鼓舞",
	&"burst": "爆发",
	&"precision": "精准",
	&"siege": "攻城",
	&"support": "辅助",
	&"aura": "鼓舞",
	&"magic": "法术",
	&"control": "控场",
}

var _profile: PlayerProfile
var _owned: Array[CharacterData] = []
var _locked_ids: Array[String] = []
var _selected_id: String = ""

var _character_buttons: Dictionary = {}
var _owned_grid: GridContainer
var _locked_box: VBoxContainer
var _detail_name_label: Label
var _detail_chips: HBoxContainer
var _detail_level_label: Label
var _exp_bar: ProgressBar
var _exp_label: Label
var _tab_container: TabContainer
var _weapon_tab: VBoxContainer
var _talent_button: Button
var _talent_panel: TalentTreePanel
var _talent_reset_dialog: ConfirmationDialog
var _skill_tab: VBoxContainer
## 信物页签：专属槽锁定占位标签 + 可选槽（Boss 签名信物）列表容器（✅ 0.8.14 双槽）。
var _relic_label: Label
var _exclusive_relic_preview: VBoxContainer
var _relic_optional_box: VBoxContainer
## 经验池行（✅ 0.8.15 / NUMBERS 10.14）：余额 + 分配入口 + 直接升级。
var _exp_pool_label: Label
var _exp_pool_allocate_button: Button
var _exp_pool_level_button: Button
var _exp_pool_hint: Label
## 经验池分配弹窗（自绘 560px 叠层，二次确认后写档）。
var _exp_pool_dialog: Control


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_profile = ProfileStore.get_profile()
	_reload_characters()
	_build_ui()
	_rebuild_left_list()
	if not _owned.is_empty():
		_selected_id = str(_owned[0].character_id)
		_select_character(_selected_id)
	_refresh()


func _on_shown() -> void:
	# 每次切回面板整体重载（战斗/一键通关会新增武将、提升等级；v0.32.1）。
	_profile = ProfileStore.get_profile()
	_reload_characters()
	_rebuild_left_list()
	if not _owned.is_empty():
		if _selected_id.is_empty() or _character_data_by_id(_selected_id) == null:
			_select_character(str(_owned[0].character_id))
		else:
			_select_character(_selected_id)
	_refresh()


func _reload_characters() -> void:
	_owned.clear()
	_locked_ids.clear()
	for character_id in _profile.get_owned_character_ids():
		var character_data := GameFlow.load_character_data(character_id)
		if character_data != null:
			_owned.append(character_data)
	# 武将图鉴（v0.11.3）：全角色目录 - 已拥有 = 未解锁
	var owned_set := {}
	for character_data in _owned:
		owned_set[str(character_data.character_id)] = true
	for character_id in GameFlow.get_all_character_ids():
		if not owned_set.has(character_id):
			_locked_ids.append(character_id)


# ============ 顶栏（标题；右上角资源胶囊已按用户要求移除 v0.20.11） ============

func _build_ui() -> void:
	var topbar := HBoxContainer.new()
	topbar.add_theme_constant_override("separation", 10)
	add_child(topbar)
	var title := Label.new()
	title.text = "武将养成"
	title.add_theme_font_override("font", UITheme.spaced_font(3))
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(title)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	add_child(columns)

	columns.add_child(_build_roster())
	columns.add_child(_build_right_column())


## 左侧武将列表白面板（概念图 .roster：标题行 + 2 列卡片网格，超出滚动兜底）。
func _build_roster() -> Control:
	var roster := Panel.new()
	roster.name = "RosterPanel"
	roster.custom_minimum_size = Vector2(368, 0)
	roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var roster_style := UITheme.light_panel_style()
	roster_style.content_margin_left = 10.0
	roster_style.content_margin_right = 10.0
	roster_style.content_margin_top = 10.0
	roster_style.content_margin_bottom = 10.0
	roster.add_theme_stylebox_override("panel", roster_style)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	roster.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "RosterBox"
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var head_label := Label.new()
	head_label.text = "武将列表"
	head_label.add_theme_font_size_override("font_size", 15)
	head_label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	head.add_child(head_label)
	var cnt := Label.new()
	cnt.name = "RosterCount"
	cnt.add_theme_font_size_override("font_size", 12)
	cnt.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	head.add_child(cnt)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 6)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)

	_owned_grid = GridContainer.new()
	_owned_grid.columns = 2
	_owned_grid.add_theme_constant_override("h_separation", 8)
	_owned_grid.add_theme_constant_override("v_separation", 8)
	_owned_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_child(_owned_grid)

	_locked_box = VBoxContainer.new()
	_locked_box.add_theme_constant_override("separation", 6)
	_locked_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_child(_locked_box)
	return roster


## 右列：基础信息卡 + 页签区（概念图 .rcol/.base/.tabs）。
func _build_right_column() -> Control:
	var right_column := VBoxContainer.new()
	right_column.name = "RightColumn"
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 10)

	# 基础信息卡（概念图 .base）
	var info_panel := Panel.new()
	info_panel.name = "InfoPanel"
	info_panel.custom_minimum_size = Vector2(0, 246)
	var info_style := UITheme.light_panel_style()
	info_style.content_margin_left = 16.0
	info_style.content_margin_right = 16.0
	info_style.content_margin_top = 14.0
	info_style.content_margin_bottom = 12.0
	info_panel.add_theme_stylebox_override("panel", info_style)
	right_column.add_child(info_panel)
	var info_box := VBoxContainer.new()
	info_box.name = "InfoBox"
	info_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_box.offset_left = 16.0
	info_box.offset_right = -16.0
	info_box.offset_top = 14.0
	info_box.offset_bottom = -12.0
	info_box.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_box)

	var row1 := HBoxContainer.new()
	row1.name = "AvatarRow"
	row1.add_theme_constant_override("separation", 12)
	info_box.add_child(row1)
	var avatar_slot := CenterContainer.new()
	avatar_slot.name = "AvatarSlot"
	avatar_slot.custom_minimum_size = Vector2(64, 64)
	row1.add_child(avatar_slot)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_theme_constant_override("separation", 4)
	row1.add_child(who)
	_detail_name_label = Label.new()
	_detail_name_label.add_theme_font_override("font", UITheme.spaced_font(2))
	_detail_name_label.add_theme_font_size_override("font_size", 24)
	_detail_name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	who.add_child(_detail_name_label)
	_detail_chips = HBoxContainer.new()
	_detail_chips.name = "Chips"
	_detail_chips.add_theme_constant_override("separation", 6)
	who.add_child(_detail_chips)
	_talent_button = TalentTreePanel._button("天赋", _open_talents, "blue")
	_talent_button.name = "TalentEntry"
	_talent_button.icon = UITheme.hud_icon_sized("talent_point", 18)
	_talent_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(_talent_button)
	var lvl_big := VBoxContainer.new()
	lvl_big.name = "LevelBig"
	lvl_big.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row1.add_child(lvl_big)
	_detail_level_label = Label.new()
	_detail_level_label.text = "Lv.1"
	_detail_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail_level_label.add_theme_font_size_override("font_size", 26)
	_detail_level_label.add_theme_color_override("font_color", UITheme.LIGHT_ACCENT)
	lvl_big.add_child(_detail_level_label)
	var lvl_caption := Label.new()
	lvl_caption.text = "等级"
	lvl_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvl_caption.add_theme_font_size_override("font_size", 12)
	lvl_caption.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	lvl_big.add_child(lvl_caption)

	var exp_slot := VBoxContainer.new()
	exp_slot.name = "ExpSlot"
	exp_slot.add_theme_constant_override("separation", 2)
	info_box.add_child(exp_slot)

	# 四统计格（概念图 .statrow/.stat）
	var stat_row := GridContainer.new()
	stat_row.columns = 4
	stat_row.name = "StatRow"
	stat_row.add_theme_constant_override("separation", 8)
	info_box.add_child(stat_row)

	# 经验池行（✅ 0.8.15 / NUMBERS 10.14）：余额 + 「分配 ▸」+「直接升级」+ 不可逆注脚
	var exp_pool_row := HBoxContainer.new()
	exp_pool_row.name = "ExpPoolRow"
	exp_pool_row.add_theme_constant_override("separation", 8)
	info_box.add_child(exp_pool_row)
	exp_pool_row.add_child(ConceptIcon.new("stat_exp", 24, "经验池"))
	_exp_pool_label = Label.new()
	_exp_pool_label.add_theme_font_size_override("font_size", 14)
	_exp_pool_label.add_theme_color_override("font_color", UITheme.LIGHT_GOLD_TEXT)
	exp_pool_row.add_child(_exp_pool_label)
	_exp_pool_allocate_button = Button.new()
	_exp_pool_allocate_button.text = "分配 ▸"
	_exp_pool_allocate_button.custom_minimum_size = Vector2(96, 34)
	_exp_pool_allocate_button.focus_mode = Control.FOCUS_NONE
	_exp_pool_allocate_button.add_theme_font_size_override("font_size", 13)
	UITheme.apply_kenney_rect_button(_exp_pool_allocate_button, "grey", UITheme.LIGHT_BODY)
	_exp_pool_allocate_button.pressed.connect(_on_exp_pool_allocate_pressed)
	exp_pool_row.add_child(_exp_pool_allocate_button)
	_exp_pool_level_button = Button.new()
	_exp_pool_level_button.text = "直接升级"
	_exp_pool_level_button.custom_minimum_size = Vector2(112, 34)
	_exp_pool_level_button.focus_mode = Control.FOCUS_NONE
	_exp_pool_level_button.add_theme_font_size_override("font_size", 13)
	UITheme.apply_kenney_rect_button(_exp_pool_level_button, "yellow", UITheme.INK)
	_exp_pool_level_button.pressed.connect(_on_exp_pool_level_up_pressed)
	exp_pool_row.add_child(_exp_pool_level_button)
	_exp_pool_hint = Label.new()
	_exp_pool_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exp_pool_hint.add_theme_font_size_override("font_size", 12)
	_exp_pool_hint.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	exp_pool_row.add_child(_exp_pool_hint)

	# 页签区（概念图 .tabs）：技能 / 职业 / 信物 / 特性
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.tab_alignment = TabBar.ALIGNMENT_LEFT
	UITheme.apply_light_tab_container(_tab_container)
	right_column.add_child(_tab_container)
	_skill_tab = _make_tab_page("技能")
	_build_rank_tab()
	_weapon_tab = _make_tab_page("装备")
	_build_relic_tab()
	return right_column


func _make_tab_page(tab_title: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = tab_title
	page.add_theme_constant_override("separation", 10)
	_tab_container.add_child(page)
	return page


func _info_node(node_name: String) -> Node:
	return _tab_container.get_parent().get_node("InfoPanel/InfoBox/" + node_name)


# ============ 基础信息卡填充 ============

func _populate_info_card(character: CharacterData, level: int, stats, progress) -> void:
	var avatar_slot := _info_node("AvatarRow/AvatarSlot") as CenterContainer
	for child in avatar_slot.get_children():
		avatar_slot.remove_child(child)
		child.queue_free()
	var color_key: String = AVATAR_COLORS[abs(hash(str(character.character_id))) % AVATAR_COLORS.size()]
	avatar_slot.add_child(UITheme.avatar_label(character.display_name.left(1), color_key, 64.0, 28))

	_detail_name_label.text = character.display_name
	for child in _detail_chips.get_children():
		_detail_chips.remove_child(child)
		child.queue_free()
	_detail_chips.add_child(FactionUI.badge(character.faction, 20))
	if character.profession != null:
		var melee_tag: bool = character.profession.tags.has(&"melee")
		var ranged_tag: bool = character.profession.tags.has(&"ranged")
		var role_text := "近战" if melee_tag else ("远程" if ranged_tag else "战场")
		_detail_chips.add_child(UITheme.tag_label(
			"%s · %s" % [character.profession.display_name, role_text],
			UITheme.LIGHT_INK, UITheme.LIGHT_BLUE_SOFT, 12))
	_detail_chips.add_child(UITheme.tag_label(
		"称号 · %s" % (" / ".join(character.titles) if not character.titles.is_empty() else "无"),
		UITheme.TAG_OPEN_FG, UITheme.TAG_OPEN_BG, 12))
	_detail_level_label.text = "Lv.%d" % level

	# 经验条 + 数值（概念图 .expbar）
	var exp_slot := _info_node("ExpSlot") as VBoxContainer
	for child in exp_slot.get_children():
		child.queue_free()
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	exp_slot.add_child(bar_row)
	_exp_bar = ProgressBar.new()
	_exp_bar.custom_minimum_size = Vector2(0, 16)
	_exp_bar.show_percentage = false
	_exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_exp_bar.max_value = maxi(int(progress.exp_for_next), 1)
	_exp_bar.value = int(progress.exp_into_level)
	UITheme.style_exp_bar(_exp_bar)
	bar_row.add_child(_exp_bar)
	_exp_label = Label.new()
	if progress.is_max_level:
		_exp_label.text = "已达等级上限 %d" % LevelCurve.max_level()
	else:
		_exp_label.text = "%d / %d" % [int(progress.exp_into_level), int(progress.exp_for_next)]
	_exp_label.add_theme_font_size_override("font_size", 13)
	_exp_label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	bar_row.add_child(_exp_label)

	# 基础属性用现有图徽 + 数值；名称与量纲说明收在 tooltip（B-102）。
	var stat_row := _info_node("StatRow") as GridContainer
	for child in stat_row.get_children():
		stat_row.remove_child(child)
		child.queue_free()
	var damage_type := character.profession.attack_damage_type if character.profession != null else DamageTypes.PHYSICAL
	if not DamageTypes.is_valid(damage_type):
		damage_type = DamageTypes.PHYSICAL
	var stat_values := [
		["dmg_%s" % damage_type, str(int(stats.attack)), false, "%s攻击力" % DamageTypes.display_name(damage_type)],
		["stat_attack_speed", "%.2fs" % stats.attack_interval, false, "攻击间隔（s）"],
		["stat_range", str(int(stats.range)), false, "射程（px）"],
		["coin", str(character.build_cost), true, "建造费用"],
		["stat_crit_rate", "%.1f%%" % (float(stats.crit_rate) * 100.0), false, "暴击率（仅普攻）"],
		["stat_crit_damage", "%.1f%%" % (float(stats.crit_damage) * 100.0), false, "暴击伤害（仅普攻）"],
		["stat_skill_amp", "%.1f%%" % (float(stats.skill_amp) * 100.0), false, "技能增幅"],
	]
	for stat_def in stat_values:
		var pill := PanelContainer.new()
		pill.name = "Stat_%s" % stat_def[0]
		pill.tooltip_text = stat_def[3]
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pill.add_theme_stylebox_override("panel", _stat_pill_style())
		var pill_box := HBoxContainer.new()
		pill_box.add_theme_constant_override("separation", 8)
		pill.add_child(pill_box)
		var icon := ConceptIcon.new(stat_def[0], 24, stat_def[3])
		icon.name = "StatIcon"
		pill_box.add_child(icon)
		var value := Label.new()
		value.name = "StatValue"
		value.text = stat_def[1]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.add_theme_font_size_override("font_size", 17)
		value.add_theme_color_override("font_color",
			UITheme.LIGHT_GOLD_TEXT if stat_def[2] else UITheme.LIGHT_INK)
		pill_box.add_child(value)
		stat_row.add_child(pill)


func _stat_pill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.LIGHT_STAT_BG
	style.border_color = UITheme.LIGHT_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


# ============ 左列表卡片（概念图 .rcard：头像 + 姓名/职业 + 右对齐 Lv） ============

func _rebuild_left_list() -> void:
	for child in _owned_grid.get_children():
		_owned_grid.remove_child(child)
		child.queue_free()
	for child in _locked_box.get_children():
		_locked_box.remove_child(child)
		child.queue_free()
	_character_buttons.clear()

	var roster_count := _owned_grid.get_parent().get_parent().get_parent().find_child(
		"RosterCount", true, false) as Label
	if roster_count != null:
		roster_count.text = "%d 名 · 已拥有 %d 名" % [_owned.size() + _locked_ids.size(), _owned.size()]

	if _owned.is_empty():
		var empty := Label.new()
		empty.text = "暂无武将，请先开始游戏"
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
		_owned_grid.add_child(empty)

	for character_data in _owned:
		var character_id := str(character_data.character_id)
		var level := GameFlow.get_character_level(_profile, character_id)
		var profession_name := character_data.profession.display_name if character_data.profession != null else "未知职业"
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 64)
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(_on_character_pressed.bind(character_id))
		UITheme.apply_light_selectable(button)
		button.add_child(_make_roster_content(character_data, level, false))
		_owned_grid.add_child(button)
		_character_buttons[character_id] = button

	if not _locked_ids.is_empty():
		var hint := Label.new()
		hint.text = "未解锁武将（首通对应关卡解锁）"
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
		_locked_box.add_child(hint)
		var locked_grid := GridContainer.new()
		locked_grid.columns = 2
		locked_grid.add_theme_constant_override("h_separation", 8)
		locked_grid.add_theme_constant_override("v_separation", 8)
		locked_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_locked_box.add_child(locked_grid)
		for character_id in _locked_ids:
			var character_data := GameFlow.load_character_data(character_id)
			if character_data == null:
				continue
			var locked_button := Button.new()
			locked_button.custom_minimum_size = Vector2(150, 64)
			locked_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			locked_button.disabled = true
			UITheme.apply_light_selectable(locked_button, true)
			var profession_name := character_data.profession.display_name if character_data.profession != null else "未知"
			locked_button.add_child(_make_roster_content(character_data, 0, true))
			locked_grid.add_child(locked_button)


func _find_roster_count() -> Label:
	return _owned_grid.get_parent().get_parent().get_parent().find_child(
		"RosterCount", true, false) as Label


## 列表卡内容层（概念图 .rcard：头像圆 + 姓名/职业两行 + 右对齐 Lv；锁定卡含来源）。
func _make_roster_content(character: CharacterData, level: int, locked: bool) -> Control:
	var content := HBoxContainer.new()
	content.name = "CardContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 9.0
	content.offset_right = -9.0
	content.offset_top = 8.0
	content.offset_bottom = -8.0
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar_char := character.display_name.left(1)
	var avatar := UITheme.avatar_label(avatar_char,
		"grey" if locked else UITheme.character_avatar_color_key(str(character.character_id)), 36.0, 18)
	avatar.name = "CardAvatar"
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(avatar)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(info)
	var nm := Label.new()
	nm.name = "CardName"
	nm.text = character.display_name
	nm.add_theme_font_size_override("font_size", 15)
	nm.add_theme_color_override("font_color", UITheme.LIGHT_LOCK if locked else UITheme.LIGHT_INK)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(nm)
	var profession_name := character.profession.display_name if character.profession != null else "未知"
	var sub := Label.new()
	sub.name = "CardSub"
	sub.text = profession_name if not locked else "%s · 未解锁" % profession_name
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", UITheme.LIGHT_DESC if not locked else UITheme.LIGHT_LOCK)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(sub)
	if locked:
		var src := Label.new()
		src.text = GameFlow.get_acquisition_text(str(character.character_id))
		src.add_theme_font_size_override("font_size", 11)
		src.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)
		src.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.add_child(src)
	var progress := VBoxContainer.new()
	progress.name = "CardProgress"
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_theme_constant_override("separation", 2)
	content.add_child(progress)
	var lvl := Label.new()
	lvl.name = "CardLv"
	lvl.text = "Lv%d" % level
	lvl.add_theme_font_size_override("font_size", 14)
	lvl.add_theme_color_override("font_color", UITheme.LIGHT_LOCK if locked else UITheme.LIGHT_ACCENT)
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress.add_child(lvl)
	var badge := ConceptIcon.new("", 22)
	badge.name = "CardRank"
	badge.visible = not locked
	badge.set_rank(_profile.get_character_rank(str(character.character_id)))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	progress.add_child(badge)
	return content


## 左侧已拥有卡片内容刷新（等级可在本面板内变化，如经验池分配 / 直接升级 或进阶；
## 卡片含头像/姓名/职业/等级多个 Label，旧实现按 find_children 顺序覆盖，
## 会把头像写成全名、职业行写错、等级不更新——B-038 改为按命名节点更新）。
func _sync_owned_button_labels() -> void:
	for character_id in _character_buttons.keys():
		var button := _character_buttons[character_id] as Button
		var character_data := _character_data_by_id(character_id)
		if button == null or not is_instance_valid(button) or character_data == null:
			continue
		if button.get_child_count() == 0:
			continue
		var content := button.get_child(0)
		var name_label := content.find_child("CardName", true, false) as Label
		var sub_label := content.find_child("CardSub", true, false) as Label
		var lv_label := content.find_child("CardLv", true, false) as Label
		if name_label == null or sub_label == null or lv_label == null:
			continue
		var level := GameFlow.get_character_level(_profile, character_id)
		var profession_name := character_data.profession.display_name if character_data.profession != null else "未知职业"
		name_label.text = character_data.display_name
		sub_label.text = profession_name
		lv_label.text = "Lv%d" % level
		var badge := content.find_child("CardRank", true, false) as ConceptIcon
		if badge != null:
			badge.set_rank(_profile.get_character_rank(character_id))


func _character_data_by_id(character_id: String) -> CharacterData:
	for character_data in _owned:
		if str(character_data.character_id) == character_id:
			return character_data
	return null


func _selected_character() -> CharacterData:
	return _character_data_by_id(_selected_id)


func _on_character_pressed(character_id: String) -> void:
	_select_character(character_id)
	_refresh()


func _select_character(character_id: String) -> void:
	_selected_id = character_id
	for key in _character_buttons.keys():
		var button := _character_buttons[key] as Button
		if is_instance_valid(button):
			button.set_pressed_no_signal(str(key) == character_id)


# ============ 主刷新 ============

func _refresh() -> void:
	var character := _selected_character()
	if character == null:
		return
	var level := GameFlow.get_character_level(_profile, _selected_id)
	var progress := LevelCurve.progress_at(_profile.get_character_exp(_selected_id))
	var stats := character.compute_stats_at(level, _profile.get_character_rank(_selected_id), GameFlow.get_equipped_relic(_profile, _selected_id), 0, _profile.get_character(_selected_id).get("growth_guard", {}), _profile.get_character(_selected_id).get("skill_levels", {}), WeaponRegistry.get_weapon(_profile.get_character_weapon_id(_selected_id)), _profile.get_talent_alloc(_selected_id))
	_populate_info_card(character, level, stats, progress)
	_refresh_skill_tab(character, stats)
	_refresh_talents()
	_refresh_rank_tab(character, level)
	_refresh_relic(character)
	_refresh_weapon_tab(character)
	_refresh_exp_pool(level)
	_sync_owned_button_labels()


# ============ 技能页签（概念图 .skrow/.skcard） ============

func _refresh_skill_tab(character: CharacterData, stats: Dictionary = {}) -> void:
	for child in _skill_tab.get_children():
		_skill_tab.remove_child(child)
		child.queue_free()
	if character == null: return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_tab.add_child(scroll)
	var margin := MarginContainer.new()
	margin.name = "SkillContentMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var rank := _profile.get_character_rank(_selected_id)
	for id in character.get_skill_ids():
		var card := SkillCard.new()
		content.add_child(card)
		var amp := float(stats.get("skill_amp", 0.0)) + (float(stats.get("talents", {}).get("ultimate_amp", 0.0)) if id == character.ultimate_id else 0.0)
		card.configure(character, id, rank, _profile.get_skill_level(_selected_id, id), amp, _profile.skill_upgrade_status(_selected_id, id), true, stats)
		card.upgrade_requested.connect(_upgrade_skill)

func _upgrade_skill(character_id: String, skill_id: StringName, expected_level: int) -> void:
	var candidate := ProfileStore.get_profile().duplicate_profile()
	if candidate.get_skill_level(character_id, skill_id) != expected_level or not candidate.upgrade_skill(character_id, skill_id):
		_refresh()
		return
	if not ProfileStore.save_profile(candidate):
		var error := _make_note_label("保存失败，未扣除。请重试。", UITheme.LIGHT_LOCK)
		error.name = "SkillSaveError"
		_skill_tab.add_child(error)
		return
	_refresh()

func _build_relic_tab() -> void:
	var page := _make_tab_page("信物")
	var exclusive_slot := HBoxContainer.new()
	exclusive_slot.add_theme_constant_override("separation", 8)
	exclusive_slot.add_child(ConceptIcon.new("lock", 34, "专属信物槽暂未开放。"))
	page.add_child(exclusive_slot)
	_relic_label = Label.new()
	_relic_label.add_theme_font_size_override("font_size", 15)
	_relic_label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	_relic_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	exclusive_slot.add_child(_relic_label)
	_exclusive_relic_preview = VBoxContainer.new()
	_exclusive_relic_preview.name = "ExclusiveRelicPreview"
	page.add_child(_exclusive_relic_preview)
	var optional_title := Label.new()
	optional_title.text = "可选信物槽（Boss 签名信物 · 通用件，可自由装卸）"
	optional_title.add_theme_font_size_override("font_size", 15)
	optional_title.add_theme_color_override("font_color", UITheme.LIGHT_GOLD_TEXT)
	page.add_child(optional_title)
	_relic_optional_box = VBoxContainer.new()
	_relic_optional_box.add_theme_constant_override("separation", 10)
	page.add_child(_relic_optional_box)


## 特性页（预留）：展示现有常驻特性，阶段 9 升阶特性接入后挂载分支选择。
func _make_kv_label(text_value: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## 职业 tags → 定位词组合（概念图 .jtags：如虎贲 melee+banner →「近战 · 持旗鼓舞」）。
func _make_fx_label(text_value: String, color: Color = Color("#33566f")) -> Label:
	return _make_note_label(text_value, color, 13)


## 转职条件胶囊流（概念 .reqs/.reqchip）：自动折行，窄卡不横向外溢（B-042 口径）。
func _make_note_label(text_value: String, color: Color, font_size: int = 12) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _refresh_exp_pool(level: int) -> void:
	var balance: int = _profile.get_exp_pool()
	_exp_pool_label.text = str(balance)
	var assignable := not _selected_id.is_empty() and _profile.can_allocate_exp_pool(_selected_id)
	_exp_pool_allocate_button.disabled = balance <= 0 or not assignable
	var cost: int = 0
	if not _selected_id.is_empty():
		cost = _profile.exp_pool_level_up_cost(_selected_id)
	_exp_pool_level_button.disabled = cost <= 0 or balance < cost
	if _selected_id.is_empty():
		_exp_pool_hint.text = "（选择武将后可分配）"
	elif cost <= 0:
		_exp_pool_hint.text = "（已满级，无法分配池内经验）"
	else:
		_exp_pool_hint.text = "（分配不可逆 · 直接升级需 %d）" % cost


## 分配入口（✅ 0.8.15）：自绘弹窗选武将 + 数量 → 二次确认 → 写档（不可逆）。
func _on_exp_pool_allocate_pressed() -> void:
	if _selected_id.is_empty() or _profile.get_exp_pool() <= 0:
		return
	_open_exp_pool_dialog()


## 「直接升级」（✅ 0.8.15）：消耗池内经验 +1 级（消耗 = 升级到下一级差额），二次确认。
func _on_exp_pool_level_up_pressed() -> void:
	if _selected_id.is_empty():
		return
	var level := GameFlow.get_character_level(_profile, _selected_id)
	var cost: int = _profile.exp_pool_level_up_cost(_selected_id)
	if cost <= 0:
		_refresh_exp_pool(level)
		return
	if _profile.get_exp_pool() < cost:
		_refresh_exp_pool(level)
		return
	var character := _selected_character()
	var display_name := character.display_name if character != null else _selected_id
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "消耗 %d 点经验池经验，将「%s」提升至 Lv.%d？\n升级不可撤销（池内经验不可回收）。" % [cost, display_name, level + 1]
	dialog.ok_button_text = "确认升级"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(_apply_exp_pool_level_up.bind(dialog))
	# Godot 4 取消信号名为 canceled（v0.32.2 修复）。
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _apply_exp_pool_level_up(dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	if _selected_id.is_empty():
		return
	if not _profile.level_up_with_exp_pool(_selected_id):
		_refresh_exp_pool(GameFlow.get_character_level(_profile, _selected_id))
		return
	ProfileStore.save_profile(_profile)
	_refresh()


# ============ 经验池分配弹窗（自绘 560px；UI_LAYOUT v0.20.47 §6） ============

func _open_exp_pool_dialog() -> void:
	if _exp_pool_dialog != null and is_instance_valid(_exp_pool_dialog):
		return
	var overlay := Control.new()
	overlay.top_level = true
	overlay.name = "ExpPoolDialog"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.039, 0.149, 0.251, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", _pool_dialog_panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	column.add_child(_build_pool_dialog_header(overlay))
	column.add_child(_build_pool_dialog_body(overlay))
	column.add_child(_build_pool_dialog_actions(overlay))
	add_child(overlay)
	_exp_pool_dialog = overlay


func _pool_dialog_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.DIALOG_PANEL
	style.border_color = UITheme.DIALOG_BORDER
	style.set_border_width_all(3)
	style.border_width_bottom = 7
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.02, 0.1, 0.18, 0.45)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	return style


## 蓝标题条：白字「经验池分配」+ 圆 ✕（沿用 §3 弹窗视觉语言）。
func _build_pool_dialog_header(overlay: Control) -> Panel:
	var header := Panel.new()
	header.custom_minimum_size = Vector2(0, 54)
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.DIALOG_HEAD
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	header.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20.0
	row.offset_right = -12.0
	row.add_theme_constant_override("separation", 10)
	header.add_child(row)
	var title := Label.new()
	title.text = "经验池分配"
	title.add_theme_font_override("font", UITheme.spaced_font(3))
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var close_button := Button.new()
	close_button.icon = UITheme.hud_icon_sized("ui_close", 18)
	close_button.tooltip_text = "关闭"
	close_button.custom_minimum_size = Vector2(34, 34)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 17)
	UITheme.apply_kenney_rect_button(close_button, "red", Color.WHITE)
	close_button.pressed.connect(_close_exp_pool_dialog.bind(overlay))
	row.add_child(close_button)
	return header


## 正文：余额 / 不可逆说明 + 武将下拉（满级禁用）+ 数量 SpinBox（默认全部余额）。
func _build_pool_dialog_body(overlay: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 6)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var balance: int = _profile.get_exp_pool()
	var note := Label.new()
	note.text = "当前余额 %d 点。分配给已拥有武将后立即计入其经验（不可撤销）。" % balance
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", UITheme.DIALOG_TEXT)
	box.add_child(note)

	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 10)
	box.add_child(target_row)
	var target_label := Label.new()
	target_label.text = "分配对象"
	target_label.custom_minimum_size = Vector2(84, 0)
	target_label.add_theme_font_size_override("font_size", 15)
	target_label.add_theme_color_override("font_color", UITheme.DIALOG_TEXT)
	target_row.add_child(target_label)
	var picker := OptionButton.new()
	picker.name = "PoolCharacterPicker"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_theme_font_size_override("font_size", 14)
	var first_assignable := -1
	for character_data in _owned:
		var character_id := str(character_data.character_id)
		var level := GameFlow.get_character_level(_profile, character_id)
		var assignable := _profile.can_allocate_exp_pool(character_id)
		picker.add_item("%s · Lv%d%s" % [character_data.display_name, level, "" if assignable else "（已满级）"])
		# 武将 id 由 item metadata 承载（下拉文本含姓名，B-064：曾以文本解析取 id 致「分配」静默失效）。
		var index := picker.item_count - 1
		picker.set_item_metadata(index, character_id)
		if not assignable:
			picker.set_item_disabled(index, true)
		elif first_assignable < 0:
			first_assignable = index
		if character_id == _selected_id:
			picker.select(index)
	if picker.selected < 0 or picker.is_item_disabled(picker.selected):
		if first_assignable >= 0:
			picker.select(first_assignable)
	target_row.add_child(picker)

	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 10)
	box.add_child(amount_row)
	var amount_label := Label.new()
	amount_label.text = "分配数量"
	amount_label.custom_minimum_size = Vector2(84, 0)
	amount_label.add_theme_font_size_override("font_size", 15)
	amount_label.add_theme_color_override("font_color", UITheme.DIALOG_TEXT)
	amount_row.add_child(amount_label)
	var spin := SpinBox.new()
	spin.name = "PoolAmountSpin"
	spin.min_value = 1
	spin.max_value = maxi(balance, 1)
	spin.step = 1
	spin.value = balance
	spin.custom_minimum_size = Vector2(160, 36)
	amount_row.add_child(spin)
	var amount_hint := Label.new()
	amount_hint.text = "（1 ~ %d，默认全部余额）" % balance
	amount_hint.add_theme_font_size_override("font_size", 13)
	amount_hint.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	amount_row.add_child(amount_hint)
	return margin


## 底栏：灰「取消」+ 黄「分配」（点分配 → 二次确认）。
func _build_pool_dialog_actions(overlay: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 22)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	margin.add_child(actions)
	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.custom_minimum_size = Vector2(140, 46)
	cancel_button.add_theme_font_size_override("font_size", 17)
	UITheme.apply_kenney_rect_button(cancel_button, "grey", UITheme.LIGHT_BODY)
	cancel_button.pressed.connect(_close_exp_pool_dialog.bind(overlay))
	actions.add_child(cancel_button)
	var confirm_button := Button.new()
	confirm_button.text = "分配"
	confirm_button.custom_minimum_size = Vector2(160, 46)
	confirm_button.add_theme_font_size_override("font_size", 17)
	UITheme.apply_kenney_rect_button(confirm_button, "yellow", UITheme.INK)
	confirm_button.pressed.connect(_on_pool_dialog_confirm.bind(overlay))
	actions.add_child(confirm_button)
	return margin


## 分配二次确认（不可逆）：确认后写 characters[id].total_exp 并刷新面板。
func _on_pool_dialog_confirm(overlay: Control) -> void:
	var picker := overlay.find_child("PoolCharacterPicker", true, false) as OptionButton
	var spin := overlay.find_child("PoolAmountSpin", true, false) as SpinBox
	if picker == null or spin == null or picker.selected < 0:
		_close_exp_pool_dialog(overlay)
		return
	var character_id := ""
	var metadata = picker.get_item_metadata(picker.selected)
	if metadata is String:
		character_id = str(metadata)
	var amount := int(spin.value)
	_close_exp_pool_dialog(overlay)
	if character_id.is_empty() or amount <= 0 or not _profile.can_allocate_exp_pool(character_id):
		return
	var display_name := character_id
	for character_data in _owned:
		if str(character_data.character_id) == character_id:
			display_name = character_data.display_name
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "将 %d 点经验分配给「%s」？\n分配后不可撤销（立即计入该武将经验）。" % [amount, display_name]
	dialog.ok_button_text = "确认分配"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(_apply_exp_pool_allocation.bind(character_id, amount, dialog))
	# Godot 4 取消信号名为 canceled（v0.32.2 修复）。
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _apply_exp_pool_allocation(character_id: String, amount: int, dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	if not _profile.allocate_exp_pool(character_id, amount):
		_refresh_exp_pool(GameFlow.get_character_level(_profile, _selected_id))
		return
	ProfileStore.save_profile(_profile)
	_refresh()


func _close_exp_pool_dialog(overlay: Control) -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	if _exp_pool_dialog == overlay:
		_exp_pool_dialog = null

func _refresh_relic(_character: CharacterData) -> void:
	_relic_label.text = "未开放"
	_relic_label.tooltip_text = "专属信物槽暂未开放。"
	for child in _exclusive_relic_preview.get_children():
		_exclusive_relic_preview.remove_child(child)
		child.queue_free()
	var exclusive := GameFlow.get_relic_for_character(_selected_id)
	if exclusive != null: _exclusive_relic_preview.add_child(preload("res://scripts/ui_screens/locked_relic_card.gd").new(exclusive))
	for child in _relic_optional_box.get_children():
		_relic_optional_box.remove_child(child)
		child.queue_free()
	var optional_relics := GameFlow.get_optional_relics()
	if optional_relics.is_empty():
		_relic_optional_box.add_child(_make_relic_line("暂无通用信物", UITheme.LIGHT_LOCK))
		return
	var equipped_id := _profile.get_character_relic_id(_selected_id, "optional")
	for relic in optional_relics:
		_relic_optional_box.add_child(_build_optional_relic_row(relic, equipped_id))


## 可选槽信物行（UI_LAYOUT v0.20.46 §6：卡片 = 名称 + 效果摘要 + 获取/持有态 + 右侧装配按钮）。
func _build_optional_relic_row(relic: RelicData, equipped_id: String) -> PanelContainer:
	var card := PanelContainer.new()
	var style := UITheme.light_card_style()
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(ConceptIcon.new(str(relic.relic_id), 44, relic.display_name))
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 2)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var owned := _profile.has_relic(str(relic.relic_id))
	var is_equipped := owned and equipped_id == str(relic.relic_id)
	text_box.add_child(_make_relic_line(
		"%s%s" % [relic.display_name, "（已装备）" if is_equipped else ("（未持有）" if not owned else "")],
		UITheme.LIGHT_GOLD_TEXT if owned else UITheme.LIGHT_LOCK))
	text_box.add_child(_make_relic_line("效果：%s" % relic.effect_summary(), UITheme.LIGHT_ACCENT, 13))
	if not relic.faction_limit.is_empty(): text_box.add_child(FactionUI.limit_row(relic.faction_limit))
	if not relic.acquisition_hint.is_empty():
		text_box.add_child(_make_relic_line("获取：%s" % relic.acquisition_hint, UITheme.LIGHT_MUTED, 13))
	var action := Button.new()
	action.custom_minimum_size = Vector2(132, 40)
	action.focus_mode = Control.FOCUS_NONE
	action.add_theme_font_size_override("font_size", 15)
	action.text = "卸下" if is_equipped else "装备"
	action.disabled = not owned or (not is_equipped and not relic.fits(GameFlow.load_character_data(_selected_id)))
	UITheme.apply_kenney_rect_button(action, "blue", Color.WHITE)
	action.pressed.connect(_on_optional_relic_pressed.bind(str(relic.relic_id), is_equipped))
	row.add_child(action)
	return card


## 可选槽装配 / 卸下：写入 characters[id].relic_optional 并即时存盘。
func _on_optional_relic_pressed(relic_id: String, is_equipped: bool) -> void:
	if relic_id.is_empty():
		return
	_profile.set_character_relic(_selected_id, "" if is_equipped else relic_id)
	ProfileStore.save_profile(_profile)
	_refresh()


func _make_relic_line(text_value: String, color: Color, font_size: int = 15) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## 品阶页：手动进阶与材料事务。

var _rank_tab: VBoxContainer
var _rank_button: Button

func _build_rank_tab() -> void:
	_rank_tab = _make_tab_page("品阶")

func _rank_value(icon_key: String, value: String, hint: String, color: Color = UITheme.LIGHT_MUTED) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(ConceptIcon.new(icon_key, 24, hint, color))
	var label := _make_note_label(value, UITheme.LIGHT_INK, 14)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	return row

func _refresh_rank_tab(character: CharacterData, level: int) -> void:
	for child in _rank_tab.get_children():
		_rank_tab.remove_child(child)
		child.queue_free()
	var current := _profile.get_character_rank(_selected_id)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rank_tab.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var rail := HBoxContainer.new()
	rail.add_theme_constant_override("separation", 8)
	content.add_child(rail)
	for r in range(6):
		var node := VBoxContainer.new()
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rail.add_child(node)
		var center := CenterContainer.new()
		node.add_child(center)
		var icon := ConceptIcon.new("rank_" + CharacterRank.KEYS[r], 34, CharacterRank.NAMES[r] + "阶", CharacterRank.COLORS[r])
		icon.modulate.a = 1.0 if r <= current else 0.4
		center.add_child(icon)
		var caption := _make_note_label("Lv%d" % CharacterRank.LEVELS[r], CharacterRank.COLORS[r], 13)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.add_child(caption)
		var state := _make_note_label("已达成" if r < current else ("当前" if r == current else ""), UITheme.LIGHT_MUTED, 12)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.add_child(state)
	var next := mini(current + 1, 5)
	var effects := HFlowContainer.new()
	effects.add_theme_constant_override("h_separation", 14)
	content.add_child(effects)
	effects.add_child(_rank_value("dmg_" + str(character.profession.attack_damage_type), "×%.2f → ×%.2f" % [CharacterRank.ATTACK[current], CharacterRank.ATTACK[next]], "品阶攻击倍率"))
	effects.add_child(_rank_value("stat_range", "×%.2f → ×%.2f" % [CharacterRank.RANGE[current], CharacterRank.RANGE[next]], "品阶射程倍率"))
	effects.add_child(_rank_value("stat_attack_speed", "×%.2f → ×%.2f" % [CharacterRank.SPEED[current], CharacterRank.SPEED[next]], "品阶攻速倍率"))
	var axis := "stat_skill_amp"
	var delta := character.per_rank_skill_amp
	if character.per_rank_crit_rate > 0.0:
		axis = "stat_crit_rate"
		delta = character.per_rank_crit_rate
	elif character.per_rank_crit_damage > 0.0:
		axis = "stat_crit_damage"
		delta = character.per_rank_crit_damage
	effects.add_child(_rank_value(axis, "+%.1f%% → +%.1f%%" % [delta * current * 100, delta * next * 100], "品阶专属加成"))
	var materials := HFlowContainer.new()
	materials.add_theme_constant_override("h_separation", 18)
	content.add_child(materials)
	for item_id in CharacterRank.MATERIALS:
		var need := int(CharacterRank.costs(next).get(item_id, 0)) if current < 5 else 0
		materials.add_child(_rank_value(item_id, "%d / %d" % [int(_profile.items.get(item_id, 0)), need], GameFlow.get_item_display_name(item_id)))
	_rank_button = Button.new()
	_rank_button.name = "AdvanceRank"
	_rank_button.text = _profile.rank_up_status(_selected_id)
	_rank_button.disabled = _rank_button.text != "进阶"
	_rank_button.custom_minimum_size = Vector2(160, 40)
	_rank_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UITheme.apply_kenney_rect_button(_rank_button, "yellow", UITheme.INK)
	_rank_button.pressed.connect(_on_rank_pressed)
	content.add_child(_rank_button)
	content.add_child(_make_note_label("进阶不可逆，达到等级后需手动进阶。", UITheme.LIGHT_MUTED, 13))

func _on_rank_pressed() -> void:
	if _profile.rank_up_status(_selected_id) != "进阶":
		return
	var selected := _selected_id
	var expected := _profile.get_character_rank(selected)
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "确认进阶？将消耗所示材料，进阶不可逆。"
	dialog.ok_button_text = "进阶"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(_apply_rank.bind(selected, expected, dialog))
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(440, 160))

func _apply_rank(character_id: String, expected_rank: int, dialog: ConfirmationDialog) -> void:
	var candidate := _profile.duplicate_profile()
	if candidate.get_character_rank(character_id) == expected_rank and candidate.advance_character_rank(character_id):
		if not ProfileStore.save_profile(candidate):
			dialog.dialog_text = "保存失败，材料未扣除。请稍后重试。"
			return
	dialog.queue_free()
	_refresh()

func _refresh_weapon_tab(character: CharacterData) -> void:
	for child in _weapon_tab.get_children():
		_weapon_tab.remove_child(child)
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_weapon_tab.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	var current := _profile.get_character_weapon_id(_selected_id)
	if current.is_empty():
		var empty := HBoxContainer.new()
		empty.add_child(ConceptIcon.new("ui_empty", 28, "当前槽为空，可在下方选择已拥有的装备。"))
		var hint := _make_note_label("选择后生效，可自由装卸。", UITheme.LIGHT_MUTED)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.add_child(hint)
		content.add_child(empty)
	for weapon in WeaponRegistry.for_character(character):
		var id := str(weapon.weapon_id)
		var count := _profile.weapon_count(id)
		var available := _profile.weapon_available(id)
		var equipped := current == id
		var action := "卸下" if equipped else ("未获得" if count == 0 else ("已占用" if available == 0 else "装备"))
		var card := WeaponCard.new()
		content.add_child(card)
		card.configure(weapon, count, available, action, equipped or available > 0, equipped)
		var character_id := _selected_id
		card.action_requested.connect(func(_id: String) -> void: _equip_weapon(character_id, "" if equipped else id))

func _equip_weapon(character_id: String, weapon_id: String) -> bool:
	var candidate := ProfileStore.get_profile().duplicate_profile()
	if not candidate.set_character_weapon(character_id, weapon_id): return false
	if not ProfileStore.save_profile(candidate):
		_weapon_tab.add_child(_make_note_label("保存失败，请重试。", UITheme.LIGHT_LOCK))
		return false
	_profile = ProfileStore.get_profile()
	_refresh()
	return true


func _open_talents() -> void:
	if is_instance_valid(_talent_panel): return
	if _selected_id.is_empty() or not _profile.characters.has(_selected_id): return
	_talent_panel = TalentTreePanel.open(self, _talent_button)
	_talent_panel.allocate_requested.connect(_allocate_talent)
	_talent_panel.reset_requested.connect(_confirm_reset_talents)
	_talent_panel.dismissed.connect(func() -> void: _talent_panel = null)
	_refresh_talents()

func _refresh_talents() -> void:
	_talent_button.tooltip_text = "查看天赋 · 剩余%d点" % _profile.talent_points_remaining(_selected_id)
	if is_instance_valid(_talent_panel):
		_talent_panel.configure(_selected_id, GameFlow.get_character_level(_profile, _selected_id), _profile.get_talent_alloc(_selected_id))

func _allocate_talent(node_id: String, expected_rank: int) -> bool:
	var candidate := ProfileStore.get_profile().duplicate_profile()
	if not candidate.allocate_talent(_selected_id, node_id, expected_rank):
		_refresh()
		if is_instance_valid(_talent_panel): _talent_panel.show_error("分配条件已变化，请查看当前等级、门槛和剩余点数。")
		return false
	if not ProfileStore.save_profile(candidate):
		if is_instance_valid(_talent_panel): _talent_panel.show_error("保存失败，未消耗点数。请重试。")
		return false
	_profile = ProfileStore.get_profile()
	_refresh()
	return true

func _confirm_reset_talents() -> void:
	var character_id := _selected_id
	var alloc := ProfileStore.get_profile().get_talent_alloc(character_id)
	if alloc.is_empty(): return
	if is_instance_valid(_talent_reset_dialog): _talent_reset_dialog.queue_free()
	var dialog := ConfirmationDialog.new()
	_talent_reset_dialog = dialog
	dialog.title = "免费重置天赋"
	var character := GameFlow.load_character_data(character_id)
	dialog.dialog_text = "重置%s的全部天赋，返还%d点？可随时重新分配。" % [character.display_name, TalentRegistry.spent(alloc)]
	dialog.get_ok_button().text = "重置"
	dialog.get_cancel_button().text = "取消"
	if is_instance_valid(_talent_panel): _talent_panel.confirmation_open = true
	dialog.confirmed.connect(func() -> void:
		if is_instance_valid(_talent_panel): _talent_panel.confirmation_open = false
		_reset_talents(character_id, alloc, dialog))
	dialog.canceled.connect(func() -> void:
		if is_instance_valid(_talent_panel): _talent_panel.confirmation_open = false
		dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(450, 180))

func _reset_talents(character_id: String, expected_alloc: Dictionary, dialog: ConfirmationDialog = null) -> bool:
	var candidate := ProfileStore.get_profile().duplicate_profile()
	if character_id != _selected_id or not candidate.reset_talents(character_id, expected_alloc):
		if is_instance_valid(dialog): dialog.queue_free()
		_refresh()
		return false
	if not ProfileStore.save_profile(candidate):
		if is_instance_valid(_talent_panel): _talent_panel.show_error("保存失败，天赋保持原样。请重试。")
		if is_instance_valid(dialog): dialog.queue_free()
		return false
	if is_instance_valid(dialog): dialog.queue_free()
	_profile = ProfileStore.get_profile()
	_refresh()
	return true
