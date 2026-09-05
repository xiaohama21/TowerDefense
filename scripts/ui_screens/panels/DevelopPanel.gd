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
var _job_identity_label: Label
var _job_ability_label: Label
var _job_progress_label: Label
var _promotion_label: Label
var _promotion_buttons: Array[Button] = []
var _promotion_buttons_box: VBoxContainer
var _promotion_overlay: Control
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
		var pill := VBoxContainer.new()
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pill.add_theme_stylebox_override("normal", _stat_pill_style())
		var key := Label.new()
		key.text = stat_def[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_font_size_override("font_size", 12)
		key.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
		pill.add_child(key)
		var value := Label.new()
		value.text = stat_def[1]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 17)
		value.add_theme_color_override("font_color",
			UITheme.LIGHT_GOLD_TEXT if stat_def[2] else UITheme.LIGHT_INK)
		pill.add_child(value)
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
		button.add_child(_make_roster_content(character_data, "%s · Lv.%d" % [profession_name, level], ""))
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
			locked_button.add_child(_make_roster_content(character_data,
				"%s · 未解锁" % profession_name, GameFlow.get_acquisition_text(character_id)))
			locked_grid.add_child(locked_button)


func _find_roster_count() -> Label:
	return _owned_grid.get_parent().get_parent().get_parent().find_child(
		"RosterCount", true, false) as Label


## 列表卡内容层（头像圆 + 姓名/职业/来源；鼠标穿透，点击落到底层按钮）。
func _make_roster_content(character: CharacterData, sub_text: String, src_text: String) -> Control:
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
		AVATAR_COLORS[abs(hash(avatar_char)) % AVATAR_COLORS.size()], 44.0, 20))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(info)
	var nm := Label.new()
	nm.text = character.display_name
	nm.add_theme_font_size_override("font_size", 15)
	nm.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(nm)
	var sub := Label.new()
	sub.text = sub_text
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", UITheme.LIGHT_DESC)
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(sub)
	if not src_text.is_empty():
		var src := Label.new()
		src.text = src_text
		src.add_theme_font_size_override("font_size", 11)
		src.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)
		src.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.add_child(src)
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
	if _promotion_label != null and is_instance_valid(_promotion_label):
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

	# 怒气大招卡
	var ultimate_id := character.ultimate_override_id
	if ultimate_id.is_empty() and character.profession != null:
		ultimate_id = character.profession.ultimate_id
	var ult_card := _make_skill_card()
	skill_box.add_child(ult_card)
	if not ultimate_id.is_empty():
		_fill_skill_card(ult_card, BehaviorRegistry.ultimate_display_name(ultimate_id).left(1),
			"red", BehaviorRegistry.ultimate_display_name(ultimate_id),
			[["怒气大招", UITheme.TAG_FIRE_FG, UITheme.TAG_FIRE_BG],
			["职业大招", UITheme.LIGHT_INK, UITheme.LIGHT_BLUE_SOFT]],
			ULTIMATE_HINTS.get(ultimate_id, "说明随版本完善"),
			"怒气上限 100，满怒自动释放（设置可选手动）；大招无冷却。")
		ult_card.add_child(_make_rage_bar())
	else:
		_fill_skill_card(ult_card, "—", "grey", "暂无大招", [], "", "")

	# 职业技能卡（核心技能随一转习得）
	var profession_id: StringName = character.profession.profession_id if character.profession != null else &""
	var job_skill: StringName = PROFESSION_JOB_SKILLS.get(profession_id, &"")
	var active := GameFlow.get_active_promotion(_profile, _selected_id)
	var job_card := _make_skill_card()
	skill_box.add_child(job_card)
	if not job_skill.is_empty():
		_fill_skill_card(job_card, SkillRegistry.get_skill_name(job_skill).left(1),
			"gold", SkillRegistry.get_skill_name(job_skill),
			[["职业技能 · 常驻", UITheme.TAG_OK_FG, UITheme.TAG_OK_BG]],
			JOB_SKILL_HINTS.get(job_skill, "说明随版本完善"),
			"一转习得（当前：%s）。" % ("已转职 %s" % active.display_name if active != null else "未转职，一转解锁"))
	else:
		_fill_skill_card(job_card, "—", "grey", "暂无职业技能", [], "", "")

	# 角色专属技能卡
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
			("条件触发（被动），随战斗条件自动生效。" if is_b else "冷却制自动释放（可选手动）；与职业层解耦。"))
	else:
		_fill_skill_card(role_card, "—", "grey", "暂无角色专属技能", [], "", "")


func _make_skill_card() -> VBoxContainer:
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := UITheme.light_card_style()
	card_style.content_margin_left = 10.0
	card_style.content_margin_right = 10.0
	card_style.content_margin_top = 8.0
	card_style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("normal", card_style)
	card.add_theme_constant_override("separation", 5)
	return card


func _fill_skill_card(card: VBoxContainer, avatar_char: String, color_key: String,
		skill_name: String, tags: Array, fx_text: String, note_text: String) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	card.add_child(head)
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
	var fx := Label.new()
	fx.text = fx_text
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.add_theme_font_size_override("font_size", 12)
	fx.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	card.add_child(fx)
	if not note_text.is_empty():
		var note := Label.new()
		note.text = note_text
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
		var note_style := UITheme.tag_style(UITheme.LIGHT_PANEL_SPLIT, 8, 4)
		note_style.set_corner_radius_all(8)
		note.add_theme_stylebox_override("normal", note_style)
		card.add_child(note)


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
	_job_identity_label = Label.new()
	_job_identity_label.add_theme_font_size_override("font_size", 16)
	_job_identity_label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	_job_identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_job_identity_label)
	_job_ability_label = Label.new()
	_job_ability_label.add_theme_font_size_override("font_size", 15)
	_job_ability_label.add_theme_color_override("font_color", UITheme.LIGHT_ACCENT)
	_job_ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_job_ability_label)
	_job_progress_label = Label.new()
	_job_progress_label.add_theme_font_size_override("font_size", 15)
	_job_progress_label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	_job_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_job_progress_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer)
	var open_detail := Button.new()
	open_detail.text = "转职详情 ▸"
	open_detail.custom_minimum_size = Vector2(200, 44)
	open_detail.focus_mode = Control.FOCUS_NONE
	open_detail.add_theme_font_size_override("font_size", 16)
	UITheme.apply_kenney_rect_button(open_detail, "blue", Color.WHITE)
	open_detail.pressed.connect(_open_promotion_overlay)
	page.add_child(open_detail)


## 转职详情整屏叠层（v0.17.4）：树状展示 当前职业 → 一转 → 二转分支，
## 转职操作迁入此处；_promotion_label/_promotion_buttons_box 指向叠层节点，
## _refresh_promotion 逻辑原样复用；确认弹窗规则不变（v0.32.2）。
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
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -580.0
	panel.offset_right = 580.0
	panel.offset_top = -330.0
	panel.offset_bottom = 330.0
	var panel_style := UITheme.light_panel_style()
	panel_style.border_color = UITheme.LIGHT_BORDER_SOFT
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 22.0
	box.offset_right = -22.0
	box.offset_top = 16.0
	box.offset_bottom = -16.0
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var head_label := Label.new()
	head_label.text = "转职详情"
	head_label.add_theme_font_override("font", UITheme.spaced_font(2))
	head_label.add_theme_font_size_override("font_size", 24)
	head_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_label)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 18)
	UITheme.apply_kenney_rect_button(close_button, "red", Color.WHITE)
	close_button.pressed.connect(_close_promotion_overlay)
	head.add_child(close_button)
	_promotion_label = Label.new()
	_promotion_label.add_theme_font_size_override("font_size", 15)
	_promotion_label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	_promotion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_promotion_label)
	_promotion_buttons_box = VBoxContainer.new()
	_promotion_buttons_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_promotion_buttons_box.add_theme_constant_override("separation", 8)
	box.add_child(_promotion_buttons_box)
	add_child(overlay)
	_promotion_overlay = overlay
	var character := _selected_character()
	if character != null:
		_refresh_promotion(character, GameFlow.get_character_level(_profile, _selected_id))


## 关闭叠层：释放节点并把转职节点引用置空（职业页签不直接持有转职列表）。
func _close_promotion_overlay() -> void:
	if _promotion_overlay != null and is_instance_valid(_promotion_overlay):
		_promotion_overlay.queue_free()
	_promotion_overlay = null
	_promotion_label = null
	_promotion_buttons_box = null
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


## 职业页签刷新（身份 / 能力状态 / 转职进度摘要）。
func _refresh_job_tab(character: CharacterData, level: int) -> void:
	var active := GameFlow.get_active_promotion(_profile, _selected_id)
	if character.profession == null:
		_job_identity_label.text = "当前职业：未知"
		_job_ability_label.text = ""
		_job_progress_label.text = ""
		return
	var melee_tag: bool = character.profession.tags.has(&"melee")
	var ranged_tag: bool = character.profession.tags.has(&"ranged")
	var role_text := "近战" if melee_tag else ("远程" if ranged_tag else "战场")
	_job_identity_label.text = "当前职业：%s（%s）—— %s" % [
		character.profession.display_name, role_text, character.profession.description,
	]
	var ultimate_id := character.ultimate_override_id
	if ultimate_id.is_empty():
		ultimate_id = character.profession.ultimate_id
	var ultimate_name := "—"
	if not ultimate_id.is_empty():
		ultimate_name = BehaviorRegistry.ultimate_display_name(ultimate_id)
	var job_skill: StringName = PROFESSION_JOB_SKILLS.get(character.profession.profession_id, &"")
	var job_state := "未习得（一转解锁）"
	if not job_skill.is_empty() and active != null:
		job_state = "已习得（%s）" % SkillRegistry.get_skill_name(job_skill)
	_job_ability_label.text = "能力状态：大招「%s」已习得·职业自带 · 职业技能「%s」%s" % [
		ultimate_name,
		SkillRegistry.get_skill_name(job_skill) if not job_skill.is_empty() else "—",
		job_state,
	]
	var candidates := GameFlow.get_promotion_candidates(_profile, _selected_id)
	if active == null and candidates.is_empty():
		_job_progress_label.text = "转职进度：暂无转职路线"
	elif candidates.is_empty():
		_job_progress_label.text = "转职进度：已至「%s」路线终点" % (active.display_name if active != null else "—")
	else:
		var next_promotion = candidates[0]
		var level_ok: bool = level >= next_promotion.required_level
		_job_progress_label.text = "转职进度：下一转「%s」—— 等级 %d/%d %s" % [
			next_promotion.display_name, level, next_promotion.required_level,
			"✓" if level_ok else "未达标",
		]


## 转职候选（阶段 6 图结构）：未转职展示一转；已转职展示二转分支列表。
## 渲染目标为转职详情叠层（职业页签只展示进度摘要）。
func _refresh_promotion(character: CharacterData, level: int) -> void:
	if _promotion_buttons_box == null or not is_instance_valid(_promotion_buttons_box):
		return
	for child in _promotion_buttons_box.get_children():
		child.queue_free()
	_promotion_buttons.clear()
	_promotion_label.visible = true

	var active := GameFlow.get_active_promotion(_profile, _selected_id)
	var candidates := GameFlow.get_promotion_candidates(_profile, _selected_id)
	if active == null and character.promotion_ids.is_empty():
		_promotion_label.text = "暂无转职路线"
		return
	if candidates.is_empty():
		if active != null:
			_promotion_label.text = "已转职：%s（%s）——已至该路线终点" % [active.display_name, active.description]
		else:
			_promotion_label.text = "转职配置缺失：%s" % str(character.promotion_ids[0])
		return

	_promotion_label.text = "已转职：%s（%s）——选择二转路线：" % [active.display_name, active.description] if active != null else "一转路线："
	for promotion in candidates:
		var level_ok := level >= promotion.required_level
		var lines: Array[String] = [
			"%s：%s —— %s" % ["二转" if active != null else "一转", promotion.display_name, promotion.description],
			"等级需求 %d：%s" % [promotion.required_level, "已达标" if level_ok else "当前 %d" % level],
		]
		var materials_ok := true
		for cost in promotion.item_costs:
			if cost == null or cost.item == null:
				continue
			var owned: int = int(_profile.items.get(str(cost.item.item_id), 0))
			var enough: bool = owned >= cost.amount
			materials_ok = materials_ok and enough
			lines.append("%s：%d/%d %s" % [
				cost.item.display_name, owned, cost.amount, "已备齐" if enough else "不足",
			])
		var label := Label.new()
		label.text = "\n".join(lines)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", UITheme.TAG_OK_FG if (level_ok and materials_ok) else UITheme.TAG_FIRE_FG)
		_promotion_buttons_box.add_child(label)

		var button := Button.new()
		button.text = "转职为「%s」" % promotion.display_name
		button.custom_minimum_size = Vector2(240, 44)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		UITheme.apply_kenney_rect_button(button, "yellow" if (level_ok and materials_ok) else "grey",
			UITheme.INK if (level_ok and materials_ok) else UITheme.LIGHT_BODY)
		button.disabled = not (level_ok and materials_ok)
		button.pressed.connect(_on_promote_pressed.bind(promotion))
		_promotion_buttons_box.add_child(button)
		_promotion_buttons.append(button)


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
