extends VBoxContainer

## 武将养成面板（UI_LAYOUT §6，Kenney 换肤 v0.20.0 按概念图 ui_develop.png）：
## 左侧武将列表（头像圆 + 姓名 + 职业 + Lv 白卡，未解锁灰卡显示获取方式）；
## 右侧基础信息卡（头像/称呼 chips/大号等级/经验条/伤害·攻速·射程·建造费用四统计格）；
## 页签区（技能 / 职业 / 信物 / 特性）——技能=怒气大招卡+职业技能卡+角色专属技能卡
## （概念图 .skcard）；职业=当前职业身份+能力状态+转职进度+「转职详情 ▸」整屏叠层
## （v0.17.4：树状展示转职路线，转职操作迁入叠层，确认弹窗规则不变）。

signal back_requested

const EXP_SCROLL_ID := "exp_scroll"

## 职业核心技能映射（基础授予与 resources/promotions 一致，SKILLS.md 4.1）。
const PROFESSION_JOB_SKILLS := {
	&"cavalry": &"charge",
	&"tiger_guard": &"command",
	&"archer": &"steady",
	&"dancer": &"inspire",
	&"catapult": &"siege",
	&"strategist": &"wisdom",
}

## 职业技能玩家向简述（数值口径以 SKILLS.md 4.1 为准）。
const JOB_SKILL_HINTS := {
	&"charge": "蓄力普攻：下一击伤害上浮（骑兵·爆发）",
	&"command": "150px 内友军伤害 +4%（常驻光环，自身不生效）",
	&"steady": "保底触发：每 5 次普攻追加一次额外伤害",
	&"inspire": "范围内友方攻速提升（鼓舞）",
	&"siege": "破城：对高血量目标增伤（投石车·范围）",
	&"wisdom": "攻击附带奇谋效果（术士·范围）",
}

## 大招玩家向简述（同源 ENCYCLOPEDIA ULTIMATE_HINTS）。
const ULTIMATE_HINTS := {
	&"ultimate_iron_bull": "重击地面，范围伤害并减速",
	&"ultimate_green_dragon": "横扫大范围目标，伤害随怒气提升",
	&"ultimate_dangyang_roar": "当阳桥喝断当阳，范围恐惧",
	&"ultimate_archer_focus": "连续箭雨覆盖目标区域",
	&"ultimate_strategist_blaze": "大范围法术伤害并施加减速",
	&"ultimate_dancer_encourage": "范围内友方攻速与伤害提升，持续数秒",
	&"ultimate_catapult_barrage": "快速连发抛射轰击目标区域",
}

## 角色专属技能玩家向文案（同源 ENCYCLOPEDIA CHARACTER_SKILL_HINTS）。
const CHARACTER_SKILL_HINTS := {
	&"char_green_dragon": "对当前目标造成 2.5× 普攻伤害；击杀则冷却 -6s",
	&"char_dangyang_roar": "范围内敌人恐惧 1s（反向行军）→ 减速 60% 持续 2s",
	&"char_carry_people": "全队攻速 +15% 持续 5s（每波一次）",
	&"char_dingjun": "2.5× 单体伤害；未击杀则目标被「定军」标记 5s：受该塔普攻伤害 +15%",
	&"char_moon_dance": "全队怒气 +10（自身 +15）",
	&"char_burn_camp": "目标区域 1.5× 范围伤害 + 灼烧 3s（每秒 0.25×）",
	&"char_seven_charges": "对射程内所有敌人造成 1× 范围伤害 + 自身攻速 +30% 持续 3s",
	&"char_death_fight": "自身攻速 +30%（常驻，仅触发一次）",
	&"char_borrow_wind": "全图友方塔攻速 +20%、弹道速度 +50% 持续 8s",
}

## 特性展示文案（CHARACTERS.md 4.7；阶段 9 升阶特性接入后改由数据源驱动）。
const TRAIT_HINTS := {
	&"trait_wusheng": "武圣：对精英/Boss 伤害 +25%",
	&"trait_royal_fire": "皇家烈焰：范围伤害 +15%",
	&"trait_yanyan_roar": "燕颜咆哮：攻击命中概率使目标短暂减速",
	&"trait_hundred_step": "百步穿杨：连续攻击同一目标伤害逐步提升（至多 +30%）",
	&"trait_benevolence": "仁德：光环——场上所有友方塔伤害 +8%（不可叠加）",
	&"trait_moon_veil": "月纱：自身大招怒气获取 +20%，友方大招怒气获取 +10%",
}

const AVATAR_COLORS := ["blue", "red", "gold", "green", "purple", "orange"]

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
var _skill_tab: VBoxContainer
var _job_content_box: VBoxContainer
var _promotion_buttons: Array[Button] = []
var _promotion_overlay: Control
var _promotion_tree_box: VBoxContainer
var _relic_label: Label
var _relic_button: Button
var _trait_label: Label
var _exp_scroll_label: Label
var _exp_scroll_button: Button
var _exp_scroll_hint: Label
var _resource_labels: Dictionary = {}


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


# ============ 顶栏（概念图 .topbar：标题 + 资源胶囊） ============

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
	for resource_def in [["yellow_turban_cloth", true], ["exp_scroll", false]]:
		var chip := Label.new()
		chip.name = "Res_" + resource_def[0]
		chip.add_theme_stylebox_override("normal", UITheme.tag_style(
			UITheme.TAG_OPEN_BG if resource_def[1] else UITheme.LIGHT_BLUE_SOFT, 11, 4))
		chip.add_theme_font_size_override("font_size", 14)
		chip.add_theme_color_override("font_color",
			UITheme.TAG_OPEN_FG if resource_def[1] else UITheme.LIGHT_BODY)
		topbar.add_child(chip)
		_resource_labels[resource_def[0]] = chip

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
	info_panel.custom_minimum_size = Vector2(0, 200)
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
	var stat_row := HBoxContainer.new()
	stat_row.name = "StatRow"
	stat_row.add_theme_constant_override("separation", 8)
	info_box.add_child(stat_row)

	# 练兵令行（测试：直接升 1 级）
	var exp_scroll_row := HBoxContainer.new()
	exp_scroll_row.name = "ExpScrollRow"
	exp_scroll_row.add_theme_constant_override("separation", 10)
	info_box.add_child(exp_scroll_row)
	_exp_scroll_label = Label.new()
	_exp_scroll_label.add_theme_font_size_override("font_size", 13)
	_exp_scroll_label.add_theme_color_override("font_color", UITheme.LIGHT_ACCENT)
	exp_scroll_row.add_child(_exp_scroll_label)
	_exp_scroll_button = Button.new()
	_exp_scroll_button.text = "使用练兵令（测试：直接升 1 级）"
	_exp_scroll_button.custom_minimum_size = Vector2(240, 38)
	_exp_scroll_button.focus_mode = Control.FOCUS_NONE
	_exp_scroll_button.add_theme_font_size_override("font_size", 13)
	UITheme.apply_kenney_rect_button(_exp_scroll_button, "grey", UITheme.LIGHT_BODY)
	_exp_scroll_button.pressed.connect(_on_exp_scroll_pressed)
	exp_scroll_row.add_child(_exp_scroll_button)
	_exp_scroll_hint = Label.new()
	_exp_scroll_hint.add_theme_font_size_override("font_size", 13)
	_exp_scroll_hint.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	exp_scroll_row.add_child(_exp_scroll_hint)

	# 页签区（概念图 .tabs）：技能 / 职业 / 信物 / 特性
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.tab_alignment = TabBar.ALIGNMENT_LEFT
	UITheme.apply_light_tab_container(_tab_container)
	right_column.add_child(_tab_container)
	_skill_tab = _make_tab_page("技能")
	_build_job_tab()
	_build_relic_tab()
	_build_trait_tab()
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
		child.queue_free()
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

	# 四统计格（伤害/攻速/射程/建造费用）
	var stat_row := _info_node("StatRow") as HBoxContainer
	for child in stat_row.get_children():
		child.queue_free()
	var attack_speed := 1.0 / maxf(stats.attack_interval, 0.01)
	var stat_values := [
		["伤害", str(int(stats.damage)), false],
		["攻速", "%.2f 次/秒" % attack_speed, false],
		["射程", str(int(stats.range)), false],
		["建造费用", str(character.build_cost), true],
	]
	for stat_def in stat_values:
		var pill := PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pill.add_theme_stylebox_override("panel", _stat_pill_style())
		var pill_box := VBoxContainer.new()
		pill_box.add_theme_constant_override("separation", 0)
		pill.add_child(pill_box)
		var key := Label.new()
		key.text = stat_def[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_font_size_override("font_size", 12)
		key.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
		pill_box.add_child(key)
		var value := Label.new()
		value.text = stat_def[1]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 9.0
	content.offset_right = -9.0
	content.offset_top = 8.0
	content.offset_bottom = -8.0
	content.add_theme_constant_override("separation", 9)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar_char := character.display_name.left(1)
	content.add_child(UITheme.avatar_label(avatar_char,
		"grey" if locked else AVATAR_COLORS[abs(hash(avatar_char)) % AVATAR_COLORS.size()], 44.0, 20))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(info)
	var nm := Label.new()
	nm.text = character.display_name
	nm.add_theme_font_size_override("font_size", 15)
	nm.add_theme_color_override("font_color", UITheme.LIGHT_LOCK if locked else UITheme.LIGHT_INK)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(nm)
	var profession_name := character.profession.display_name if character.profession != null else "未知"
	var sub := Label.new()
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
	var lvl := Label.new()
	lvl.text = "Lv%d" % level
	lvl.add_theme_font_size_override("font_size", 14)
	lvl.add_theme_color_override("font_color", UITheme.LIGHT_LOCK if locked else UITheme.LIGHT_ACCENT)
	lvl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(lvl)
	return content


## 左侧已拥有卡片内容刷新（等级可在本面板内变化，如使用练兵令直接升级）。
func _sync_owned_button_labels() -> void:
	for character_id in _character_buttons.keys():
		var button := _character_buttons[character_id] as Button
		var character_data := _character_data_by_id(character_id)
		if button == null or not is_instance_valid(button) or character_data == null:
			continue
		if button.get_child_count() == 0:
			continue
		var labels := button.get_child(0).find_children("", "Label", true, false)
		if labels.size() >= 2:
			var level := GameFlow.get_character_level(_profile, character_id)
			var profession_name := character_data.profession.display_name if character_data.profession != null else "未知职业"
			(labels[0] as Label).text = character_data.display_name
			(labels[1] as Label).text = "%s · Lv.%d" % [profession_name, level]


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
	var promotion := GameFlow.get_active_promotion(_profile, _selected_id)
	var progress := LevelCurve.progress_at(_profile.get_character_exp(_selected_id))
	var stats := character.compute_stats_at(level, promotion)
	_populate_info_card(character, level, stats, progress)
	_refresh_skill_tab(character)
	_refresh_job_tab(character, level)
	if _promotion_overlay != null and is_instance_valid(_promotion_overlay):
		_refresh_promotion(character, level)
	_refresh_relic(character)
	_refresh_trait(character)
	_refresh_exp_scroll(level)
	_sync_owned_button_labels()
	for resource_id in _resource_labels.keys():
		var chip: Label = _resource_labels[resource_id]
		var item := GameFlow.load_item_data(resource_id)
		chip.text = "%s ×%d" % [item.display_name if item != null else resource_id,
			int(_profile.items.get(resource_id, 0))]


# ============ 技能页签（概念图 .skrow/.skcard） ============

func _refresh_skill_tab(character: CharacterData) -> void:
	for child in _skill_tab.get_children():
		child.queue_free()
	if character == null:
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_tab.add_child(scroll)
	var skill_box := VBoxContainer.new()
	skill_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_box.add_theme_constant_override("separation", 8)
	scroll.add_child(skill_box)

	# 第一行：怒气大招卡 + 职业技能卡（概念图 .skrow 并排）
	var skrow := HBoxContainer.new()
	skrow.add_theme_constant_override("separation", 10)
	skrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_box.add_child(skrow)

	# 怒气大招卡
	var ultimate_id := character.ultimate_override_id
	if ultimate_id.is_empty() and character.profession != null:
		ultimate_id = character.profession.ultimate_id
	var ult_card := _make_skill_card()
	ult_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skrow.add_child(ult_card)
	# 职业技能卡（核心技能随一转习得）
	var profession_id: StringName = character.profession.profession_id if character.profession != null else &""
	var job_skill: StringName = PROFESSION_JOB_SKILLS.get(profession_id, &"")
	var active := GameFlow.get_active_promotion(_profile, _selected_id)
	var job_card := _make_skill_card()
	job_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skrow.add_child(job_card)
	if not ultimate_id.is_empty():
		_fill_skill_card(ult_card, BehaviorRegistry.ultimate_display_name(ultimate_id).left(1),
			"red", BehaviorRegistry.ultimate_display_name(ultimate_id),
			[["怒气大招", UITheme.TAG_FIRE_FG, UITheme.TAG_FIRE_BG],
			["职业大招", UITheme.LIGHT_INK, UITheme.LIGHT_BLUE_SOFT]],
			ULTIMATE_HINTS.get(ultimate_id, "说明随版本完善"),
			"怒气上限 100，满怒自动释放（设置可选手动）；大招无冷却。", true)
	else:
		_fill_skill_card(ult_card, "—", "grey", "暂无大招", [], "", "", false)
	if not job_skill.is_empty():
		_fill_skill_card(job_card, SkillRegistry.get_skill_name(job_skill).left(1),
			"gold", SkillRegistry.get_skill_name(job_skill),
			[["职业技能 · 常驻", UITheme.TAG_OK_FG, UITheme.TAG_OK_BG]],
			JOB_SKILL_HINTS.get(job_skill, "说明随版本完善"),
			"一转习得（当前：%s）。" % ("已转职 %s" % active.display_name if active != null else "未转职，一转解锁"), false)
	else:
		_fill_skill_card(job_card, "—", "grey", "暂无职业技能", [], "", "", false)

	# 角色专属技能卡（整行）
	var role_card := _make_skill_card()
	skill_box.add_child(role_card)
	var skill_id := character.character_skill_id
	if not skill_id.is_empty():
		var is_b := SkillRegistry.CHARACTER_SKILL_B_TYPE.has(skill_id)
		_fill_skill_card(role_card, SkillRegistry.get_character_skill_name(skill_id).left(1),
			"blue", SkillRegistry.get_character_skill_name(skill_id),
			[["角色专属技能", UITheme.LIGHT_INK, UITheme.LIGHT_BLUE_SOFT],
			["不耗怒气", UITheme.TAG_LOCK_FG, UITheme.TAG_LOCK_BG]],
			CHARACTER_SKILL_HINTS.get(skill_id, "说明随版本完善"),
			("条件触发（被动），随战斗条件自动生效。" if is_b else "冷却制自动释放（可选手动）；与职业层解耦。"), false)
	else:
		_fill_skill_card(role_card, "—", "grey", "暂无角色专属技能", [], "", "", false)


func _make_skill_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := UITheme.light_card_style()
	card_style.content_margin_left = 10.0
	card_style.content_margin_right = 10.0
	card_style.content_margin_top = 8.0
	card_style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", card_style)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 5)
	card.add_child(content)
	return card


func _fill_skill_card(card: PanelContainer, avatar_char: String, color_key: String,
		skill_name: String, tags: Array, fx_text: String, note_text: String,
		with_rage: bool = false) -> void:
	var content := card.get_node("Content") as VBoxContainer
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 10)
	content.add_child(head)
	head.add_child(UITheme.avatar_label(avatar_char, color_key, 36.0, 16))
	var meta := VBoxContainer.new()
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_theme_constant_override("separation", 2)
	head.add_child(meta)
	var nm := Label.new()
	nm.text = skill_name
	nm.add_theme_font_size_override("font_size", 16)
	nm.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	meta.add_child(nm)
	var tag_row := HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 5)
	meta.add_child(tag_row)
	for tag_def in tags:
		tag_row.add_child(UITheme.tag_label(tag_def[0], tag_def[1], tag_def[2], 11))
	if with_rage:
		head.add_child(_make_rage_bar())
	var fx := Label.new()
	fx.text = fx_text
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.add_theme_font_size_override("font_size", 12)
	fx.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	content.add_child(fx)
	if not note_text.is_empty():
		var note := Label.new()
		note.text = note_text
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
		var note_style := UITheme.tag_style(UITheme.LIGHT_PANEL_SPLIT, 8, 4)
		note_style.set_corner_radius_all(8)
		note.add_theme_stylebox_override("normal", note_style)
		content.add_child(note)


## 怒气条（概念图 .rage：金框横条 + 满怒标注）。
func _make_rage_bar() -> Control:
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(84, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ffd75e")
	style.border_color = UITheme.LIGHT_GOLD_SELECT
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	bar.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "满怒 100"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", UITheme.TAG_OPEN_FG)
	bar.add_child(label)
	return bar


# ============ 职业页签（身份 + 能力状态 + 转职进度 + 叠层入口） ============

func _build_job_tab() -> void:
	var page := _make_tab_page("职业")
	_job_content_box = VBoxContainer.new()
	_job_content_box.add_theme_constant_override("separation", 10)
	page.add_child(_job_content_box)


## 转职详情整屏叠层（概念图 ui_develop_promo.png，v0.17.4）：蓝头 + 转职树
## （基础职业 → 已转链（绿 done）→ 下一转候选（金 可转职 + 转职为按钮）→
## 二转分支预览（灰）），底部二次确认说明；确认弹窗规则不变（v0.32.2）。
func _open_promotion_overlay() -> void:
	if _promotion_overlay != null and is_instance_valid(_promotion_overlay):
		return
	var overlay := Control.new()
	overlay.top_level = true
	overlay.name = "PromotionOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.039, 0.149, 0.251, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var panel := Panel.new()
	panel.name = "OverlayPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -580.0
	panel.offset_right = 580.0
	panel.offset_top = -330.0
	panel.offset_bottom = 330.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UITheme.LIGHT_PAGE_BG
	panel_style.set_corner_radius_all(16)
	panel_style.shadow_color = Color(0.024, 0.11, 0.196, 0.5)
	panel_style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 3.0
	box.offset_right = -3.0
	box.offset_top = 3.0
	box.offset_bottom = -3.0
	panel.add_child(box)
	# 蓝色标题条（概念图头部：亮蓝底白字；Panel+MarginContainer 确保绘制与最小尺寸传导）
	var header := Panel.new()
	header.custom_minimum_size = Vector2(0, 56)
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color("#38a8dd")
	header_style.corner_radius_top_left = 13
	header_style.corner_radius_top_right = 13
	header.add_theme_stylebox_override("panel", header_style)
	var header_margin := MarginContainer.new()
	header_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_margin.add_theme_constant_override("margin_left", 20)
	header_margin.add_theme_constant_override("margin_right", 12)
	header_margin.add_theme_constant_override("margin_top", 10)
	header_margin.add_theme_constant_override("margin_bottom", 10)
	header.add_child(header_margin)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	header_margin.add_child(head_row)
	var head_label := Label.new()
	head_label.text = "转职详情"
	head_label.add_theme_font_override("font", UITheme.spaced_font(2))
	head_label.add_theme_font_size_override("font_size", 24)
	head_label.add_theme_color_override("font_color", Color.WHITE)
	head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head_row.add_child(head_label)
	var character := _selected_character()
	var level := 0
	if character != null:
		level = GameFlow.get_character_level(_profile, _selected_id)
		var who_chip := Label.new()
		who_chip.text = "%s · %s · Lv.%d" % [character.display_name,
			character.profession.display_name if character.profession != null else "未知", level]
		who_chip.add_theme_font_size_override("font_size", 16)
		who_chip.add_theme_color_override("font_color", Color.WHITE)
		who_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head_row.add_child(who_chip)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.add_theme_color_override("font_color", Color.WHITE)
	close_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(1, 1, 1, 0.25)
	close_style.set_corner_radius_all(20)
	close_button.add_theme_stylebox_override("normal", close_style)
	close_button.add_theme_stylebox_override("hover", close_style)
	close_button.add_theme_stylebox_override("pressed", close_style)
	close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_button.pressed.connect(_close_promotion_overlay)
	head_row.add_child(close_button)

	# 树主体（滚动）
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(body_scroll)
	_promotion_tree_box = VBoxContainer.new()
	_promotion_tree_box.name = "TreeBox"
	_promotion_tree_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_promotion_tree_box.add_theme_constant_override("separation", 6)
	body_scroll.add_child(_promotion_tree_box)
	var bottom_note := Panel.new()
	var bottom_style := UITheme.tag_style(UITheme.LIGHT_PANEL_SPLIT, 12, 6)
	bottom_style.set_corner_radius_all(8)
	bottom_note.add_theme_stylebox_override("panel", bottom_style)
	bottom_note.custom_minimum_size = Vector2(0, 40)
	box.add_child(bottom_note)
	var bottom_label := Label.new()
	bottom_label.text = "转职需 二次确认（提示不可逆与目标职业）；未满足条件时按钮不可点击；二转需先完成一转，Lv 20 后回到本页选择分支。"
	bottom_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_label.add_theme_font_size_override("font_size", 12)
	bottom_label.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	bottom_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom_label.offset_left = 12.0
	bottom_label.offset_right = -12.0
	bottom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_note.add_child(bottom_label)

	add_child(overlay)
	_promotion_overlay = overlay
	if character != null:
		_refresh_promotion(character, level)


## 关闭叠层：释放节点并把转职节点引用置空（职业页签不直接持有转职列表）。
func _close_promotion_overlay() -> void:
	if _promotion_overlay != null and is_instance_valid(_promotion_overlay):
		_promotion_overlay.queue_free()
	_promotion_overlay = null
	_promotion_tree_box = null
	_promotion_buttons.clear()


# ============ 信物 / 特性 页签 ============

func _build_relic_tab() -> void:
	var page := _make_tab_page("信物")
	_relic_label = Label.new()
	_relic_label.add_theme_font_size_override("font_size", 16)
	_relic_label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	_relic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_relic_label)
	_relic_button = Button.new()
	_relic_button.custom_minimum_size = Vector2(220, 44)
	_relic_button.focus_mode = Control.FOCUS_NONE
	_relic_button.add_theme_font_size_override("font_size", 16)
	UITheme.apply_kenney_rect_button(_relic_button, "blue", Color.WHITE)
	_relic_button.pressed.connect(_on_relic_pressed)
	page.add_child(_relic_button)


## 特性页（预留）：展示现有常驻特性，阶段 9 升阶特性接入后挂载分支选择。
func _build_trait_tab() -> void:
	var page := _make_tab_page("特性")
	_trait_label = Label.new()
	_trait_label.add_theme_font_size_override("font_size", 15)
	_trait_label.add_theme_color_override("font_color", UITheme.LIGHT_ACCENT)
	_trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_trait_label)


## 职业页签刷新（概念图 ui_develop_job.png）：职业身份卡（绿）+ 大招/职业技能
## 两卡 + 转职进度面板（下一转 chip、等级/材料 pills、完整路线、转职详情按钮）。
func _refresh_job_tab(character: CharacterData, level: int) -> void:
	for child in _job_content_box.get_children():
		child.queue_free()
	if character.profession == null:
		return
	var active := GameFlow.get_active_promotion(_profile, _selected_id)
	var candidates := GameFlow.get_promotion_candidates(_profile, _selected_id)
	var job_skill: StringName = PROFESSION_JOB_SKILLS.get(character.profession.profession_id, &"")
	var ultimate_id := character.ultimate_override_id
	if ultimate_id.is_empty():
		ultimate_id = character.profession.ultimate_id

	# ① 职业身份卡（绿边 node）
	var identity := PanelContainer.new()
	var identity_style := UITheme.light_card_style(Color("#f3fbf6"), UITheme.TAG_OK_FG)
	identity_style.content_margin_left = 12.0
	identity_style.content_margin_right = 12.0
	identity_style.content_margin_top = 10.0
	identity_style.content_margin_bottom = 10.0
	identity.add_theme_stylebox_override("panel", identity_style)
	_job_content_box.add_child(identity)
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 12)
	identity.add_child(identity_row)
	identity_row.add_child(UITheme.avatar_label(
		character.profession.display_name.left(1), "blue", 40.0, 18))
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_theme_constant_override("separation", 3)
	identity_row.add_child(who)
	var job_head := HBoxContainer.new()
	job_head.add_theme_constant_override("separation", 8)
	who.add_child(job_head)
	var job_name := Label.new()
	job_name.text = character.profession.display_name
	job_name.add_theme_font_override("font", UITheme.spaced_font(2))
	job_name.add_theme_font_size_override("font_size", 17)
	job_name.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	job_head.add_child(job_name)
	var melee_tag: bool = character.profession.tags.has(&"melee")
	var ranged_tag: bool = character.profession.tags.has(&"ranged")
	job_head.add_child(UITheme.tag_label("近战" if melee_tag else ("远程" if ranged_tag else "战场"),
		UITheme.LIGHT_INK, UITheme.LIGHT_BLUE_SOFT, 11))
	var job_lv_ok := not candidates.is_empty() and level >= candidates[0].required_level
	if not candidates.is_empty():
		identity_row.add_child(UITheme.tag_label("已可一转" if job_lv_ok else "未可一转",
			UITheme.TAG_OPEN_FG, UITheme.TAG_OPEN_BG, 11))
	who.add_child(_make_kv_label("近战抗线、持旗鼓舞的近战 buff 职业（当前未转职）；技能效果详见「技能」页签。",
		UITheme.LIGHT_BODY, 12))
	_job_content_box.add_child(_make_skill_cards_row(character, active, job_skill))

	# ③ 转职进度面板（白卡：下一转 chip + pills + 完整路线 + 转职详情按钮）
	var progress_panel := PanelContainer.new()
	var progress_style := UITheme.light_card_style(Color.WHITE, UITheme.LIGHT_PANEL_BORDER)
	progress_style.content_margin_left = 12.0
	progress_style.content_margin_right = 12.0
	progress_style.content_margin_top = 10.0
	progress_style.content_margin_bottom = 10.0
	progress_panel.add_theme_stylebox_override("panel", progress_style)
	_job_content_box.add_child(progress_panel)
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 12)
	progress_panel.add_child(progress_row)
	var progress_left := VBoxContainer.new()
	progress_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_left.add_theme_constant_override("separation", 4)
	progress_row.add_child(progress_left)
	if candidates.is_empty():
		progress_left.add_child(_make_kv_label("转职进度：已至路线终点", UITheme.LIGHT_BODY, 14))
	else:
		var next_promotion: PromotionData = candidates[0]
		var head_chip := HBoxContainer.new()
		head_chip.add_theme_constant_override("separation", 8)
		progress_left.add_child(head_chip)
		head_chip.add_child(UITheme.tag_label(
			"下一转 · %s（%s）" % [next_promotion.display_name,
			"二转" if active != null else "一转"], UITheme.LIGHT_INK, UITheme.LIGHT_BLUE_SOFT, 12))
		var lv_ok: bool = level >= next_promotion.required_level
		progress_left.add_child(_make_kv_label("等级需求：%d/%d %s" % [level,
			next_promotion.required_level, "已达标" if lv_ok else "未达标"],
			UITheme.TAG_OK_FG if lv_ok else UITheme.TAG_FIRE_FG, 13))
		for cost in next_promotion.item_costs:
			if cost == null or cost.item == null:
				continue
			var owned: int = int(_profile.items.get(str(cost.item.item_id), 0))
			progress_left.add_child(_make_kv_label("%s：%d / %d %s" % [
				cost.item.display_name, owned, cost.amount,
				"充足" if owned >= cost.amount else "不足"],
				UITheme.TAG_OK_FG if owned >= cost.amount else UITheme.TAG_FIRE_FG, 13))
	var detail_button := Button.new()
	detail_button.text = "转职详情 ▸"
	detail_button.custom_minimum_size = Vector2(200, 52)
	detail_button.focus_mode = Control.FOCUS_NONE
	detail_button.add_theme_font_size_override("font_size", 16)
	UITheme.apply_kenney_rect_button(detail_button, "yellow", UITheme.INK)
	detail_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_button.pressed.connect(_open_promotion_overlay)
	progress_row.add_child(detail_button)


## 职业大招 / 职业技能两卡行（概念图 .skrow）。
func _make_skill_cards_row(character: CharacterData, active: PromotionData, job_skill: StringName) -> Control:
	var ultimate_id := character.ultimate_override_id
	if ultimate_id.is_empty() and character.profession != null:
		ultimate_id = character.profession.ultimate_id
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ult_card := _make_skill_card()
	ult_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ult_card)
	var job_card := _make_skill_card()
	job_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(job_card)
	if not ultimate_id.is_empty():
		_fill_skill_card(ult_card, BehaviorRegistry.ultimate_display_name(ultimate_id).left(1),
			"red", "职业大招 · %s" % BehaviorRegistry.ultimate_display_name(ultimate_id),
			[["已习得", UITheme.TAG_OK_FG, UITheme.TAG_OK_BG]],
			ULTIMATE_HINTS.get(ultimate_id, "说明随版本完善"),
			"职业自带，满怒自动释放（可选手动）。", false)
	else:
		_fill_skill_card(ult_card, "—", "grey", "暂无大招", [], "", "", false)
	if not job_skill.is_empty():
		var job_unlocked := active != null
		_fill_skill_card(job_card, SkillRegistry.get_skill_name(job_skill).left(1),
			"gold", "职业技能 · %s" % SkillRegistry.get_skill_name(job_skill),
			[["未习得", UITheme.TAG_OPEN_FG, UITheme.TAG_OPEN_BG] if not job_unlocked
				else ["已习得", UITheme.TAG_OK_FG, UITheme.TAG_OK_BG]],
			JOB_SKILL_HINTS.get(job_skill, "说明随版本完善"),
			"一转「%s」习得 · 将位替代见转职详情。" % (active.display_name if active != null else "一转"), false)
	else:
		_fill_skill_card(job_card, "—", "grey", "暂无职业技能", [], "", "", false)
	return row


func _make_kv_label(text_value: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## 转职树渲染（概念图 ui_develop_promo.png）：节点 PanelContainer 随内容长高，
## 左侧状态点标级（绿=当前/已转，金=可转职，灰=未解锁），行内右列放按钮/注记。
func _refresh_promotion(character: CharacterData, level: int) -> void:
	if _promotion_tree_box == null or not is_instance_valid(_promotion_tree_box):
		return
	for child in _promotion_tree_box.get_children():
		child.queue_free()
	_promotion_buttons.clear()
	var active := GameFlow.get_active_promotion(_profile, _selected_id)
	var candidates := GameFlow.get_promotion_candidates(_profile, _selected_id)
	var intro := Label.new()
	intro.text = "职业级转职树：同职业武将共享同一路线，绿点＝当前职业，金点＝可转职目标，灰点＝未解锁；转职不可逆，需二次确认。"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	var intro_panel := Panel.new()
	intro_panel.add_theme_stylebox_override("panel", UITheme.tag_style(UITheme.LIGHT_PANEL_SPLIT, 12, 6))
	intro_panel.add_child(intro)
	_promotion_tree_box.add_child(intro_panel)

	# 已完成链：基础职业（或当前职业）节点
	var base_tag := "当前职业" if active == null else "基础职业 · 未转职"
	var base_note := ""
	if active == null:
		var job_skill: StringName = PROFESSION_JOB_SKILLS.get(
			character.profession.profession_id if character.profession != null else &"", &"")
		base_note = "近战抗线职业；职业技能「%s」需一转后习得。" % (
			SkillRegistry.get_skill_name(job_skill) if not job_skill.is_empty() else "—")
	_promotion_tree_box.add_child(_make_promo_node(
		character.profession.display_name.left(1), "green",
		character.profession.display_name,
		[[base_tag, UITheme.TAG_OK_FG, UITheme.TAG_OK_BG]],
		character.profession.description,
		[[_make_note_label("职业包括大招「%s」" % (BehaviorRegistry.ultimate_display_name(
			character.ultimate_override_id if not character.ultimate_override_id.is_empty()
			else (character.profession.ultimate_id if character.profession != null else &""))
			if character.profession != null else "—"), UITheme.LIGHT_LOCK)]],
		null))
	_promotion_tree_box.add_child(_make_tree_arrow())

	# 已转职链节点
	var path_ids: Array = _profile.get_character(_selected_id).get("promotion_path", [])
	for pid in path_ids:
		var taken := GameFlow.load_promotion_data(str(pid))
		if taken == null:
			continue
		var is_current := active != null and str(taken.promotion_id) == str(active.promotion_id)
		_promotion_tree_box.add_child(_make_promo_node(
			taken.display_name.left(1), "gold",
			taken.display_name,
			[["当前职业" if is_current else "已转职", UITheme.TAG_OK_FG, UITheme.TAG_OK_BG]],
			taken.description, [], null))
		_promotion_tree_box.add_child(_make_tree_arrow())

	# 下一转候选（金 · 可转职 + 转职为按钮 + 数值/条件）
	for promotion in candidates:
		var level_ok := level >= promotion.required_level
		var materials_ok := true
		var material_pills: Array[Control] = []
		for cost in promotion.item_costs:
			if cost == null or cost.item == null:
				continue
			var owned: int = int(_profile.items.get(str(cost.item.item_id), 0))
			var enough: bool = owned >= cost.amount
			materials_ok = materials_ok and enough
			material_pills.append(_promo_pill("%s %d / %d %s" % [cost.item.display_name, owned, cost.amount,
				"充足" if enough else "不足"], UITheme.TAG_OK_FG if enough else UITheme.TAG_FIRE_FG))
		var skill_line := ""
		for sid in promotion.granted_skill_ids:
			skill_line = "习得职业技能「%s」：%s" % [SkillRegistry.get_skill_name(sid),
				JOB_SKILL_HINTS.get(sid, "效果见 SKILLS.md 4.1")]
			break
		var depth_text := "二转 · 可转职" if active != null else "一转 · 可转职（唯一）"
		var numeric_parts: Array[String] = []
		if absf(promotion.damage_multiplier - 1.0) > 0.001:
			numeric_parts.append("伤害 ×%.2f" % promotion.damage_multiplier)
		if absf(promotion.attack_interval_multiplier - 1.0) > 0.001:
			numeric_parts.append("攻速 ×%.2f" % promotion.attack_interval_multiplier)
		if absf(promotion.range_multiplier - 1.0) > 0.001:
			numeric_parts.append("射程 ×%.2f" % promotion.range_multiplier)
		var numeric_text := "数值：" + " · ".join(numeric_parts) if not numeric_parts.is_empty() else ""
		var promote_button := Button.new()
		promote_button.text = "转职为「%s」" % promotion.display_name
		promote_button.custom_minimum_size = Vector2(200, 48)
		promote_button.focus_mode = Control.FOCUS_NONE
		promote_button.add_theme_font_size_override("font_size", 15)
		UITheme.apply_kenney_rect_button(promote_button, "yellow" if (level_ok and materials_ok) else "grey",
			UITheme.INK if (level_ok and materials_ok) else UITheme.LIGHT_BODY)
		promote_button.disabled = not (level_ok and materials_ok)
		promote_button.pressed.connect(_on_promote_pressed.bind(promotion))
		_promotion_buttons.append(promote_button)
		_promotion_tree_box.add_child(_make_promo_node(
			promotion.display_name.left(1), "gold", promotion.display_name,
			[[depth_text, UITheme.LIGHT_GOLD_TEXT, UITheme.TAG_OPEN_BG]],
			promotion.description,
			[[_make_kv_label(skill_line, UITheme.LIGHT_BODY, 12)] if not skill_line.is_empty() else [],
			[_make_note_label(numeric_text, UITheme.LIGHT_BODY)] if not numeric_text.is_empty() else [],
			material_pills],
			promote_button))
		_promotion_tree_box.add_child(_make_tree_arrow())

	# 二转分支预览（未完成一转时灰显）
	if active == null and not candidates.is_empty():
		var first_promotion := candidates[0]
		var branch_note_text := "— 二转分支 · 完成一转后 %d 选 1" % first_promotion.next_promotion_ids.size()
		var first_cost: ItemAmountData = null
		for cost in first_promotion.item_costs:
			if cost != null and cost.item != null:
				first_cost = cost
				break
		if first_cost != null:
			branch_note_text += "（需 Lv %d · %s ×%d）" % [first_promotion.required_level,
				first_cost.item.display_name, first_cost.amount]
		branch_note_text += "   选定后写入「转职路径」，不可回退"
		var branch_note := Label.new()
		branch_note.text = branch_note_text
		branch_note.add_theme_font_size_override("font_size", 13)
		branch_note.add_theme_color_override("font_color", UITheme.LIGHT_GOLD_TEXT)
		_promotion_tree_box.add_child(branch_note)
		var branch_row := HBoxContainer.new()
		branch_row.add_theme_constant_override("separation", 10)
		_promotion_tree_box.add_child(branch_row)
		for next_id in first_promotion.next_promotion_ids:
			var branch := GameFlow.load_promotion_data(str(next_id))
			if branch == null:
				continue
			var locked_button := Button.new()
			locked_button.text = "未解锁"
			locked_button.custom_minimum_size = Vector2(120, 44)
			locked_button.focus_mode = Control.FOCUS_NONE
			locked_button.disabled = true
			UITheme.apply_kenney_rect_button(locked_button, "grey", UITheme.LIGHT_BODY)
			_promotion_tree_box.add_child(_make_promo_node(
				branch.display_name.left(1), "grey", branch.display_name,
				[["二转 · 需先完成一转", UITheme.TAG_LOCK_FG, UITheme.TAG_LOCK_BG]],
				branch.description,
				[[_make_kv_label("Lv %d / %d 未达标" % [level, branch.required_level],
					UITheme.TAG_FIRE_FG, 12)]],
				locked_button))


## 节点卡（概念图 .pnode/.bopt）：PanelContainer 随内容长高；右列放按钮或注记。
func _make_promo_node(avatar_char: String, color_key: String, title: String,
		tags: Array, desc: String, extra_rows: Array, right: Control = null) -> PanelContainer:
	var border_color := UITheme.LIGHT_GOLD_SELECT
	var bg_color := Color("#fffdf2")
	for tag_def in tags:
		if tag_def[1] == UITheme.TAG_OK_FG:
			border_color = UITheme.TAG_OK_FG
			bg_color = Color("#f3fbf6")
		if tag_def[1] == UITheme.LIGHT_LOCK:
			border_color = UITheme.LIGHT_PANEL_BORDER
			bg_color = UITheme.LIGHT_CARD_BG
	var node := PanelContainer.new()
	var style := UITheme.light_card_style(bg_color, border_color)
	style.set_border_width_all(3)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	node.add_theme_stylebox_override("panel", style)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	node.add_child(row)
	row.add_child(UITheme.avatar_label(avatar_char, color_key, 40.0, 18))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	info.add_child(head)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", UITheme.spaced_font(2))
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	head.add_child(title_label)
	for tag_def in tags:
		head.add_child(UITheme.tag_label(tag_def[0], tag_def[1], tag_def[2], 11))
	if not desc.is_empty():
		var desc_label := Label.new()
		desc_label.text = desc
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
		info.add_child(desc_label)
	for extra_row in extra_rows:
		for control in extra_row:
			info.add_child(control)
	if right != null:
		var right_slot := VBoxContainer.new()
		right_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		right_slot.add_child(right)
		row.add_child(right_slot)
	return node


func _make_note_label(text_value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label


func _promo_pill(text_value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.LIGHT_STAT_BG, 10, 3))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label


func _make_kv_pill(text_value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	var style := UITheme.tag_style(UITheme.LIGHT_STAT_BG, 10, 3)
	style.set_corner_radius_all(8)
	label.add_theme_stylebox_override("normal", style)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label


func _make_tree_arrow() -> Control:
	var cell := CenterContainer.new()
	var arrow := Label.new()
	arrow.text = "↓"
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_color_override("font_color", UITheme.LIGHT_BORDER_SOFT)
	cell.add_child(arrow)
	return cell


## 练兵令（测试，v0.15.1）：数量展示、满级/不足禁用。
func _refresh_exp_scroll(level: int) -> void:
	var count: int = int(_profile.items.get(EXP_SCROLL_ID, 0))
	_exp_scroll_label.text = "练兵令 ×%d" % count
	_exp_scroll_button.disabled = _selected_id.is_empty() or count <= 0 or level >= LevelCurve.max_level()
	_exp_scroll_hint.text = "（仅测试发放，使用后直接升 1 级）"


func _on_exp_scroll_pressed() -> void:
	if _selected_id.is_empty():
		return
	var level := GameFlow.get_character_level(_profile, _selected_id)
	if level >= LevelCurve.max_level():
		_exp_scroll_hint.text = "已达等级上限，无法使用"
		return
	if not _profile.spend_item(EXP_SCROLL_ID, 1):
		_exp_scroll_hint.text = "练兵令不足"
		return
	var current_total := _profile.get_character_exp(_selected_id)
	var next_total := LevelCurve.exp_total_for_level(level + 1)
	_profile.add_character_exp(_selected_id, next_total - current_total)
	ProfileStore.save_profile(_profile)
	_exp_scroll_hint.text = "已使用：等级提升至 %d" % (level + 1)
	_refresh()


func _on_promote_pressed(promotion: PromotionData) -> void:
	if promotion == null:
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "转职为「%s」？\n转职不可逆，将消耗转职材料。" % promotion.display_name
	dialog.ok_button_text = "确认转职"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(_apply_promotion.bind(promotion, dialog))
	# Godot 4 取消信号名为 canceled（v0.32.2 修复）。
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _apply_promotion(promotion: PromotionData, dialog: ConfirmationDialog) -> void:
	var character := _selected_character()
	if character == null or promotion == null:
		dialog.queue_free()
		return
	# 防御：候选必须是当前图结构的合法下一步（防跳级/回退/重复转职）。
	var valid := false
	for candidate in GameFlow.get_promotion_candidates(_profile, _selected_id):
		if str(candidate.promotion_id) == str(promotion.promotion_id):
			valid = true
			break
	if not valid:
		dialog.queue_free()
		return
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


## 信物（GDD 4.8）：碎片兑换 + 装备/卸下；建造时经 loadout 生效。
func _refresh_relic(character: CharacterData) -> void:
	var relic := GameFlow.get_relic_for_character(_selected_id)
	if relic == null:
		_relic_label.text = "信物：暂未开放"
		_relic_button.visible = false
		return
	var owned := _profile.has_relic(str(relic.relic_id))
	var equipped: String = str(_profile.get_character(_selected_id).get("relic", ""))
	if owned:
		var is_equipped := equipped == str(relic.relic_id)
		_relic_label.text = "信物：%s —— %s%s" % [
			relic.display_name, relic.description, "（已装备）" if is_equipped else "（未装备）",
		]
		_relic_button.text = "卸下信物" if is_equipped else "装备信物"
		_relic_button.visible = true
		_relic_button.disabled = false
	else:
		var shards: int = int(_profile.get_character(_selected_id).get("shards", 0))
		_relic_label.text = "信物：%s（%s）· 碎片 %d 兑换" % [relic.display_name, relic.description, relic.shard_cost]
		_relic_button.text = "碎片兑换"
		_relic_button.visible = true
		_relic_button.disabled = shards < relic.shard_cost


func _on_relic_pressed() -> void:
	var relic := GameFlow.get_relic_for_character(_selected_id)
	if relic == null:
		return
	if _profile.has_relic(str(relic.relic_id)):
		var equipped: String = str(_profile.get_character(_selected_id).get("relic", ""))
		var next_relic := "" if equipped == str(relic.relic_id) else str(relic.relic_id)
		_profile.set_character_relic(_selected_id, next_relic)
	else:
		if not _profile.spend_shards(_selected_id, relic.shard_cost):
			return
		_profile.add_relic(str(relic.relic_id))
		_profile.set_character_relic(_selected_id, str(relic.relic_id))
	ProfileStore.save_profile(_profile)
	_refresh()


## 特性页：展示现有常驻特性（CHARACTERS.md 4.7），阶段 9 升阶特性接入后挂载分支选择。
func _refresh_trait(character: CharacterData) -> void:
	var hint: String = TRAIT_HINTS.get(character.trait_id, "")
	if hint.is_empty():
		_trait_label.text = "特性：%s（详细说明随阶段 9 完善）" % str(character.trait_id)
		return
	_trait_label.text = "%s\n（常驻被动；阶段 9 升阶特性接入后新增特性分支选择）" % hint
