extends Control

## 游戏百科（ENCYCLOPEDIA.md，阶段 8·提交 9）：只读信息中心——
## 武将图鉴（9 将全量 + 基础/技能/转职/信物/特性页签 + 数值模拟器）与
## 敌人图鉴（7 敌 + 各档难度面板 + 出现关卡反查）。不写档、不改存档。
## 布局规范 UI_LAYOUT.md §12；文案字典集中维护，禁止面板间散落私有文案漂移。

const DevelopPanelScript := preload("res://scripts/ui_screens/panels/DevelopPanel.gd")
const TowerScript := preload("res://scripts/Tower.gd")

## 第一章敌人展示顺序（ENEMIES.md 5.5.2 表序）。
const ENEMY_ORDER: Array[String] = [
	"yellow_turban_soldier",
	"yellow_turban_cavalry",
	"yellow_turban_sergeant",
	"yellow_turban_archer",
	"yellow_turban_berserker",
	"yellow_turban_sorcerer",
	"yellow_turban_general",
]

## 敌人定位标签（ENEMIES.md 5.5.2）。
const ENEMY_LOCATIONS := {
	"yellow_turban_soldier": "炮灰",
	"yellow_turban_cavalry": "快速",
	"yellow_turban_sergeant": "精英",
	"yellow_turban_archer": "远程",
	"yellow_turban_berserker": "高血坦克",
	"yellow_turban_sorcerer": "光环支援",
	"yellow_turban_general": "Boss",
}

## 敌人特殊行为玩家向文案（BEHAVIORS.md B.3.2，勿直出 special_behavior_id）。
const ENEMY_BEHAVIOR_HINTS := {
	&"healer_aura": "每 2s 治疗周围 120px 友军 15 点",
	&"summon_guard": "每 8s 自岔路召唤 2 名步卒（广宗决战分叉试点）",
}

## 职业大招玩家向文案（CHARACTERS.md 4.6 表）。
const ULTIMATE_HINTS := {
	&"ultimate_cavalry_breaker": "对当前目标造成高额单体伤害；若击杀则返还 50% 怒气",
	&"ultimate_tiger_guard_sweep": "破阵：范围内敌人受到 1.5× 普攻伤害并击退，附近友方攻速提升",
	&"ultimate_archer_volley": "快速连射 3~5 箭，优先锁定低血量敌人",
	&"ultimate_strategist_blaze": "大范围法术伤害并施加减速",
	&"ultimate_dancer_encourage": "范围内友方攻速与伤害提升，持续数秒",
	&"ultimate_catapult_barrage": "快速连发抛射轰击目标区域",
}

## 角色专属技能玩家向文案（CHARACTER_SKILLS.md §2 效果草案）。
const CHARACTER_SKILL_HINTS := {
	&"char_green_dragon": "对当前目标造成 2.5× 普攻伤害；击杀则冷却 -6s",
	&"char_dangyang_roar": "范围内敌人击退 60px + 减速 60% 持续 3s",
	&"char_carry_people": "全队攻速 +15% 持续 5s（每波一次）",
	&"char_dingjun": "2.5× 单体伤害；未击杀则目标被「定军」标记 5s：受该塔普攻伤害 +15%",
	&"char_moon_dance": "全队怒气 +10（自身 +15）",
	&"char_burn_camp": "目标区域 1.5× 范围伤害 + 灼烧 3s（每秒 0.25×）",
	&"char_seven_charges": "对射程内所有敌人造成 1× 范围伤害 + 自身攻速 +30% 持续 3s",
	&"char_death_fight": "自身攻速 +30%（常驻，仅触发一次）",
	&"char_borrow_wind": "全图友方塔攻速 +20%、弹道速度 +50% 持续 8s",
}

var _mode: StringName = &"character"
var _character_ids: Array[String] = []
var _enemy_ids: Array[String] = []
var _selected_character_id: String = ""
var _selected_enemy_id: String = ""

## 模拟器状态（只读假设视图，不写档）。
var _sim_level: int = 1
var _sim_promotion: PromotionData = null
var _sim_battle_rank: int = 0

var _character_button: Button
var _enemy_button: Button
var _left_box: VBoxContainer
var _left_scroll: ScrollContainer
var _detail_box: VBoxContainer
var _header_name_label: Label
var _header_meta_label: Label
var _tab_container: TabContainer
var _base_tab: VBoxContainer
var _skill_tab: VBoxContainer
var _promotion_tab: VBoxContainer
var _relic_tab: VBoxContainer
var _trait_tab: VBoxContainer
var _sim_level_slider: HSlider
var _sim_level_label: Label
var _sim_promotion_option: OptionButton
var _sim_rank_slider: HSlider
var _sim_rank_label: Label
var _sim_stats_label: Label


func _ready() -> void:
	_character_ids = GameFlow.get_all_character_ids()
	_enemy_ids = _ordered_enemy_ids()
	_build_ui()
	_switch_mode(&"character")
	if not _character_ids.is_empty():
		_select_character(_character_ids[0])


## 敌人按 ENEMY_ORDER 排序（目录扫描结果与文档表序对齐；缺失项跳过）。
func _ordered_enemy_ids() -> Array[String]:
	var result: Array[String] = []
	for enemy_id in ENEMY_ORDER:
		if GameFlow.load_enemy_data(enemy_id) != null:
			result.append(enemy_id)
	return result


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# 顶栏：标题 + 状态标签
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var title := Label.new()
	title.text = "游戏百科"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.GOLD)
	header.add_child(title)
	var tag := Label.new()
	tag.text = "全量图鉴 · 只读不写档"
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_color", UITheme.DISABLED)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(tag)

	# 武将 / 敌人互斥切换
	var switch_row := HBoxContainer.new()
	switch_row.name = "ModeRow"
	switch_row.add_theme_constant_override("separation", 10)
	root.add_child(switch_row)
	_character_button = _make_segment_button("武将图鉴", &"character")
	switch_row.add_child(_character_button)
	_enemy_button = _make_segment_button("敌人图鉴", &"enemy")
	switch_row.add_child(_enemy_button)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	# 左侧列表区（滚动容器兜底，不撑爆页面）
	_left_scroll = ScrollContainer.new()
	_left_scroll.name = "LeftScroll"
	_left_scroll.custom_minimum_size = Vector2(250, 0)
	_left_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_left_scroll)
	_left_box = VBoxContainer.new()
	_left_box.name = "LeftBox"
	_left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_box.add_theme_constant_override("separation", 8)
	_left_scroll.add_child(_left_box)

	# 右侧详情（武将：页签 + 底部模拟器条；敌人：详情）
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 8)
	body.add_child(_detail_box)


func _make_segment_button(label_text: String, mode: StringName) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(140, 42)
	button.add_theme_font_size_override("font_size", 18)
	button.toggle_mode = true
	button.pressed.connect(_switch_mode.bind(mode))
	return button


func _switch_mode(mode: StringName) -> void:
	_mode = mode
	_character_button.set_pressed_no_signal(mode == &"character")
	_enemy_button.set_pressed_no_signal(mode == &"enemy")
	for button in [_character_button, _enemy_button]:
		var selected: bool = button == (_character_button if mode == &"character" else _enemy_button)
		if selected:
			UITheme.apply_selected_style(button)
	_rebuild_left_list()
	_rebuild_detail()
	if mode == &"character":
		if _selected_character_id.is_empty() and not _character_ids.is_empty():
			_selected_character_id = _character_ids[0]
		if not _selected_character_id.is_empty():
			_select_character(_selected_character_id)
	elif mode == &"enemy":
		if _selected_enemy_id.is_empty() and not _enemy_ids.is_empty():
			_selected_enemy_id = _enemy_ids[0]
		if not _selected_enemy_id.is_empty():
			_select_enemy(_selected_enemy_id)


## 左侧列表：武将 = 2 列网格；敌人 = 竖排卡片。
func _rebuild_left_list() -> void:
	for child in _left_box.get_children():
		child.queue_free()
	if _mode == &"character":
		var grid := GridContainer.new()
		grid.name = "CharacterGrid"
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		_left_box.add_child(grid)
		for character_id in _character_ids:
			var character := GameFlow.load_character_data(character_id)
			if character == null:
				continue
			var button := Button.new()
			button.text = _character_card_text(character)
			button.custom_minimum_size = Vector2(0, 88)
			button.add_theme_font_size_override("font_size", 16)
			button.add_theme_constant_override("h_separation", 4)
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var accent := _profession_color(character)
			button.add_theme_color_override("font_color", accent.lightened(0.35))
			button.pressed.connect(_select_character.bind(str(character_id)))
			grid.add_child(button)
	else:
		for enemy_id in _enemy_ids:
			var enemy := GameFlow.load_enemy_data(enemy_id)
			if enemy == null:
				continue
			var button := Button.new()
			button.text = "%s\n%s" % [enemy.display_name, ENEMY_LOCATIONS.get(enemy_id, "")]
			button.custom_minimum_size = Vector2(0, 58)
			button.add_theme_font_size_override("font_size", 16)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_color_override("font_color", enemy.body_color.lightened(0.4))
			button.pressed.connect(_select_enemy.bind(str(enemy_id)))
			_left_box.add_child(button)


func _character_card_text(character: CharacterData) -> String:
	var profession := character.profession
	var prof_name := profession.display_name if profession != null else "未知职业"
	var line2 := "%s · %s" % [prof_name, _profession_role_text(profession)]
	return "%s\n%s" % [character.display_name, line2]


func _rebuild_detail() -> void:
	for child in _detail_box.get_children():
		child.queue_free()
	if _mode == &"enemy":
		_build_enemy_detail()
	else:
		_build_character_detail()


## ============ 武将图鉴 ============

func _build_character_detail() -> void:
	_header_name_label = Label.new()
	_header_name_label.add_theme_font_size_override("font_size", 24)
	_header_name_label.add_theme_color_override("font_color", UITheme.GOLD)
	_detail_box.add_child(_header_name_label)
	_header_meta_label = Label.new()
	_header_meta_label.add_theme_font_size_override("font_size", 15)
	_header_meta_label.add_theme_color_override("font_color", UITheme.GRAY)
	_detail_box.add_child(_header_meta_label)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_theme_font_size_override("font_size", 16)
	_detail_box.add_child(_tab_container)

	_base_tab = _make_tab("基础")
	_skill_tab = _make_tab("技能")
	_promotion_tab = _make_tab("转职")
	_relic_tab = _make_tab("信物")
	_trait_tab = _make_tab("特性")

	# 底部模拟器条（只读假设视图）
	var sim_panel := PanelContainer.new()
	sim_panel.custom_minimum_size = Vector2(0, 168)
	var sim_style := StyleBoxFlat.new()
	sim_style.bg_color = UITheme.PANEL_BG
	sim_style.border_color = UITheme.GOLD.darkened(0.4)
	sim_style.set_border_width_all(1)
	sim_style.set_corner_radius_all(8)
	sim_style.content_margin_left = 12.0
	sim_style.content_margin_top = 8.0
	sim_style.content_margin_right = 12.0
	sim_style.content_margin_bottom = 8.0
	sim_panel.add_theme_stylebox_override("panel", sim_style)
	_detail_box.add_child(sim_panel)
	_build_simulator(sim_panel)


func _make_tab(tab_name: String) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = tab_name
	tab.add_theme_constant_override("separation", 8)
	_tab_container.add_child(tab)
	return tab


func _build_simulator(parent: PanelContainer) -> void:
	var sim_box := VBoxContainer.new()
	sim_box.add_theme_constant_override("separation", 6)
	parent.add_child(sim_box)

	var hint_row := HBoxContainer.new()
	sim_box.add_child(hint_row)
	var hint := Label.new()
	hint.text = "数值模拟器"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", UITheme.GOLD)
	hint_row.add_child(hint)
	var note := Label.new()
	note.text = "预览不影响存档 · 转职任选不校验条件"
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", UITheme.DISABLED)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_row.add_child(note)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 10)
	sim_box.add_child(level_row)
	var level_caption := Label.new()
	level_caption.text = "等级"
	level_caption.custom_minimum_size = Vector2(48, 0)
	level_caption.add_theme_font_size_override("font_size", 14)
	level_row.add_child(level_caption)
	_sim_level_slider = HSlider.new()
	_sim_level_slider.min_value = 1
	_sim_level_slider.max_value = LevelCurve.max_level()
	_sim_level_slider.step = 1
	_sim_level_slider.value = 1
	_sim_level_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sim_level_slider.value_changed.connect(func(_value: float) -> void: _on_sim_changed())
	level_row.add_child(_sim_level_slider)
	_sim_level_label = Label.new()
	_sim_level_label.custom_minimum_size = Vector2(64, 0)
	_sim_level_label.add_theme_font_size_override("font_size", 14)
	_sim_level_label.add_theme_color_override("font_color", UITheme.BLUE)
	level_row.add_child(_sim_level_label)

	var promo_row := HBoxContainer.new()
	promo_row.add_theme_constant_override("separation", 10)
	sim_box.add_child(promo_row)
	var promo_caption := Label.new()
	promo_caption.text = "转职"
	promo_caption.custom_minimum_size = Vector2(48, 0)
	promo_caption.add_theme_font_size_override("font_size", 14)
	promo_row.add_child(promo_caption)
	_sim_promotion_option = OptionButton.new()
	_sim_promotion_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sim_promotion_option.add_theme_font_size_override("font_size", 14)
	_sim_promotion_option.item_selected.connect(func(_index: int) -> void: _on_sim_changed())
	promo_row.add_child(_sim_promotion_option)
	var rank_caption := Label.new()
	rank_caption.text = "局内升阶"
	rank_caption.custom_minimum_size = Vector2(64, 0)
	rank_caption.add_theme_font_size_override("font_size", 14)
	promo_row.add_child(rank_caption)
	_sim_rank_slider = HSlider.new()
	_sim_rank_slider.min_value = 0
	_sim_rank_slider.max_value = 3
	_sim_rank_slider.step = 1
	_sim_rank_slider.value = 0
	_sim_rank_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sim_rank_slider.value_changed.connect(func(_value: float) -> void: _on_sim_changed())
	promo_row.add_child(_sim_rank_slider)
	_sim_rank_label = Label.new()
	_sim_rank_label.custom_minimum_size = Vector2(32, 0)
	_sim_rank_label.add_theme_font_size_override("font_size", 14)
	_sim_rank_label.add_theme_color_override("font_color", UITheme.BLUE)
	promo_row.add_child(_sim_rank_label)

	_sim_stats_label = Label.new()
	_sim_stats_label.add_theme_font_size_override("font_size", 16)
	_sim_stats_label.add_theme_color_override("font_color", UITheme.BLUE)
	sim_box.add_child(_sim_stats_label)


func _fill_promotion_options(character: CharacterData) -> void:
	_sim_promotion_ids.clear()
	_sim_promotion_option.clear()
	_sim_promotion_option.add_item("初始（未转职）", 0)
	var index := 1
	var seen: Dictionary = {}
	var queue: Array[String] = []
	for root_id in character.promotion_ids:
		queue.append(str(root_id))
	while not queue.is_empty():
		var promotion_id: String = queue.pop_front()
		if seen.has(promotion_id):
			continue
		seen[promotion_id] = true
		var promotion := GameFlow.load_promotion_data(promotion_id)
		if promotion == null:
			continue
		_sim_promotion_option.add_item(promotion.display_name, index)
		_sim_promotion_ids[index] = promotion
		index += 1
		for next_id in promotion.next_promotion_ids:
			queue.append(str(next_id))
	_sim_promotion = null
	_sim_promotion_option.select(0)


var _sim_promotion_ids: Dictionary = {}


func _select_character(character_id: String) -> void:
	_selected_character_id = character_id
	_sim_level = 1
	_sim_battle_rank = 0
	if _mode != &"character":
		_switch_mode(&"character")
	_sync_selected_buttons()
	_fill_promotion_options(GameFlow.load_character_data(character_id))
	_refresh_character_detail()


func _refresh_character_detail() -> void:
	var character := GameFlow.load_character_data(_selected_character_id)
	if character == null:
		return
	_header_name_label.text = character.display_name
	_header_meta_label.text = "%s · 称号 %s" % [
		character.profession.display_name if character.profession != null else "未知职业",
		" / ".join(character.titles) if not character.titles.is_empty() else "无",
	]
	_refresh_base_tab(character)
	_refresh_skill_tab(character)
	_refresh_promotion_tab(character)
	_refresh_relic_tab(character)
	_refresh_trait_tab(character)
	_refresh_simulator(character)


func _clear_tab(tab: VBoxContainer) -> void:
	for child in tab.get_children():
		child.queue_free()


func _make_body_label(text_value: String, color: Color = UITheme.TEXT, font_size: int = 15) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _refresh_base_tab(character: CharacterData) -> void:
	_clear_tab(_base_tab)
	var baseline := character.compute_stats_at(1, null, 0, null)
	_base_tab.add_child(_make_body_label("等级上限：%d（经验条见武将养成）" % LevelCurve.max_level(), UITheme.GOLD))
	var role_text := _profession_role_text(character.profession)
	_base_tab.add_child(_make_body_label("职业：%s · %s" % [
		character.profession.display_name if character.profession != null else "未知职业",
		role_text,
	]))
	var counter := _profession_counter_text(character.profession)
	if not counter.is_empty():
		_base_tab.add_child(_make_body_label("克制：%s" % counter, UITheme.GRAY))
	_base_tab.add_child(_make_body_label("属性摘要（1 级）：伤害 %d　　攻速 %.2f 次/秒　　射程 %d" % [
		baseline.damage, 1.0 / maxf(baseline.attack_interval, 0.01), int(baseline.range),
	], UITheme.BLUE))
	_base_tab.add_child(_make_body_label("角色简介：%s" % character.description))
	_base_tab.add_child(_make_body_label("获取方式：%s" % GameFlow.get_acquisition_text(str(character.character_id)), UITheme.GREEN))


func _refresh_skill_tab(character: CharacterData) -> void:
	_clear_tab(_skill_tab)
	var skill_id := character.character_skill_id
	if not skill_id.is_empty():
		var is_b := SkillRegistry.CHARACTER_SKILL_B_TYPE.has(skill_id)
		var type_text := "条件触发（被动）" if is_b else "主动（冷却制）"
		_skill_tab.add_child(_make_body_label("角色专属技能：%s（%s）" % [
			SkillRegistry.get_character_skill_name(skill_id), type_text,
		], UITheme.GOLD))
		_skill_tab.add_child(_make_body_label("效果：%s" % CHARACTER_SKILL_HINTS.get(skill_id, "说明随版本完善"), UITheme.TEXT))
	else:
		_skill_tab.add_child(_make_body_label("角色专属技能：无", UITheme.DISABLED))
	_skill_tab.add_child(_make_body_label("——", UITheme.DISABLED))
	var ultimate_id := character.ultimate_override_id
	if ultimate_id.is_empty() and character.profession != null:
		ultimate_id = character.profession.ultimate_id
	if not ultimate_id.is_empty():
		_skill_tab.add_child(_make_body_label("职业大招：%s（怒气满 100 释放）" % BehaviorRegistry.ultimate_display_name(ultimate_id), UITheme.GOLD))
		_skill_tab.add_child(_make_body_label("效果：%s" % ULTIMATE_HINTS.get(ultimate_id, "说明随版本完善"), UITheme.TEXT))
	else:
		_skill_tab.add_child(_make_body_label("职业大招：无", UITheme.DISABLED))


func _refresh_promotion_tab(character: CharacterData) -> void:
	_clear_tab(_promotion_tab)
	var nodes: Array[PromotionData] = []
	var seen: Dictionary = {}
	var queue: Array[String] = []
	for root_id in character.promotion_ids:
		queue.append(str(root_id))
	while not queue.is_empty():
		var promotion_id: String = queue.pop_front()
		if seen.has(promotion_id):
			continue
		seen[promotion_id] = true
		var promotion := GameFlow.load_promotion_data(promotion_id)
		if promotion == null:
			continue
		nodes.append(promotion)
		for next_id in promotion.next_promotion_ids:
			queue.append(str(next_id))
	if nodes.is_empty():
		_promotion_tab.add_child(_make_body_label("该武将暂无转职路线", UITheme.DISABLED))
		return
	_promotion_tab.add_child(_make_body_label("职业级转职树（同职业角色共享；预览任选不校验材料/等级）", UITheme.GOLD))
	for node in nodes:
		var requirement := "等级 ≥ %d" % node.required_level
		var skills_text := _promotion_skill_text(node)
		var block := _make_body_label("· %s（%s）\n　%s\n　授予：%s\n　预览条件：%s" % [
			node.display_name, requirement, node.description, skills_text, requirement,
		])
		_promotion_tab.add_child(block)
	_promotion_tab.add_child(_make_body_label("档位口径：职业技能档位系数 s = 1 + 0.1 × min(局内升阶/5, 4)（仅职业技能适用，上限 +40%）", UITheme.GRAY, 13))


func _promotion_skill_text(promotion: PromotionData) -> String:
	var parts: Array[String] = []
	for skill_id in promotion.granted_skill_ids:
		parts.append(SkillRegistry.get_skill_name(skill_id))
	return "、".join(parts) if not parts.is_empty() else "无"


func _refresh_relic_tab(character: CharacterData) -> void:
	_clear_tab(_relic_tab)
	var relic := GameFlow.get_relic_for_character(str(character.character_id))
	if relic == null:
		_relic_tab.add_child(_make_body_label("该武将暂无专属信物", UITheme.DISABLED))
		return
	_relic_tab.add_child(_make_body_label("%s（%d 碎片兑换）" % [relic.display_name, relic.shard_cost], UITheme.GOLD))
	_relic_tab.add_child(_make_body_label("效果：%s" % relic.description))
	var effects: Array[String] = []
	if relic.damage_bonus > 0.0:
		effects.append("伤害 +%d%%" % int(round(relic.damage_bonus * 100)))
	if relic.range_bonus > 0.0:
		effects.append("射程 +%d%%" % int(round(relic.range_bonus * 100)))
	if relic.attack_interval_factor != 1.0:
		effects.append("攻速 %s%d%%" % ["+" if relic.attack_interval_factor < 1.0 else "-", int(abs((1.0 - relic.attack_interval_factor) * 100))])
	_relic_tab.add_child(_make_body_label("数值：%s" % ("；".join(effects) if not effects.is_empty() else "无"), UITheme.BLUE))


func _refresh_trait_tab(character: CharacterData) -> void:
	_clear_tab(_trait_tab)
	var hints := DevelopPanelScript.TRAIT_HINTS
	var trait_id := character.trait_id
	if trait_id.is_empty():
		_trait_tab.add_child(_make_body_label("该武将暂无特性", UITheme.DISABLED))
		return
	var hint_text: String = str(hints.get(trait_id, "说明随版本完善"))
	_trait_tab.add_child(_make_body_label("特性（常驻被动）：%s" % hint_text, UITheme.GOLD))
	_trait_tab.add_child(_make_body_label("数据同源：与武将养成页签/局内表现共用字典，不在此另存文案。", UITheme.GRAY, 13))


## ============ 模拟器 ============

func _on_sim_changed() -> void:
	var character := GameFlow.load_character_data(_selected_character_id)
	if character == null:
		return
	_sim_level = int(_sim_level_slider.value)
	_sim_battle_rank = int(_sim_rank_slider.value)
	var selected: int = _sim_promotion_option.selected
	if selected > 0:
		_sim_promotion = _sim_promotion_ids.get(selected, null) as PromotionData
	else:
		_sim_promotion = null
	_sim_level_label.text = "%d 级" % _sim_level
	_sim_rank_label.text = "%d 阶" % _sim_battle_rank
	_refresh_simulator(character)


func _refresh_simulator(character: CharacterData) -> void:
	if _sim_level_label == null:
		return
	_sim_level_label.text = "%d 级" % _sim_level
	_sim_rank_label.text = "%d 阶" % _sim_battle_rank
	var stats := character.compute_stats_at(_sim_level, _sim_promotion, 0, null, _sim_battle_rank)
	var preview_range := float(stats.range) * character.get_static_range_multiplier()
	var attacks_per_second := 1.0 / maxf(float(stats.attack_interval), 0.01)
	var attr_text := "伤害 %d　　攻速 %.2f 次/秒　　射程 %d" % [
		stats.damage, attacks_per_second, int(preview_range),
	]
	var steps := character.get_battle_rank_steps()
	if float(steps.aoe) > 0.0 and _sim_battle_rank > 0:
		attr_text += "　　爆散 %d" % ceili(BehaviorRegistry.LOB_EXPLOSION_RADIUS * CharacterData.rank_scale(steps.aoe, _sim_battle_rank))
	_sim_stats_label.text = attr_text
	if _sim_promotion == null:
		_sim_stats_label.text += "\n转职预览：未转职（如已满足条件可任选路线）"


## ============ 敌人图鉴 ============

func _build_enemy_detail() -> void:
	_header_name_label = Label.new()
	_header_name_label.add_theme_font_size_override("font_size", 24)
	_header_name_label.add_theme_color_override("font_color", UITheme.GOLD)
	_detail_box.add_child(_header_name_label)
	_header_meta_label = Label.new()
	_header_meta_label.add_theme_font_size_override("font_size", 15)
	_header_meta_label.add_theme_color_override("font_color", UITheme.GRAY)
	_detail_box.add_child(_header_meta_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "EnemyDetailContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	_detail_scroll_content = content


var _detail_scroll_content: VBoxContainer


func _select_enemy(enemy_id: String) -> void:
	_selected_enemy_id = enemy_id
	if _mode != &"enemy":
		_switch_mode(&"enemy")
	_sync_selected_buttons()
	_refresh_enemy_detail()


func _refresh_enemy_detail() -> void:
	var enemy := GameFlow.load_enemy_data(_selected_enemy_id)
	if enemy == null or _header_name_label == null:
		return
	_header_name_label.text = enemy.display_name
	_header_meta_label.text = "%s · 阵营 黄巾" % ENEMY_LOCATIONS.get(_selected_enemy_id, "未知")
	_clear_tab(_detail_scroll_content)
	var body := _detail_scroll_content

	body.add_child(_make_body_label("简介：%s" % enemy.description))
	var behavior_text := "无"
	if not enemy.special_behavior_id.is_empty():
		behavior_text = str(ENEMY_BEHAVIOR_HINTS.get(enemy.special_behavior_id, "说明随版本完善"))
	body.add_child(_make_body_label("基础面板", UITheme.GOLD, 18))
	body.add_child(_make_body_label("生命 %d　　速度 %.0f　　护甲 %d　　漏怪伤害 %d" % [
		enemy.max_hp, enemy.move_speed, enemy.armor, enemy.damage_to_base,
	], UITheme.BLUE))
	body.add_child(_make_body_label("特殊行为：%s" % behavior_text))

	body.add_child(_make_body_label("各档难度面板", UITheme.GOLD, 18))
	for difficulty in range(Difficulty.count()):
		var hp := int(round(enemy.max_hp * Difficulty.enemy_hp_mult(difficulty)))
		body.add_child(_make_body_label("「%s」生命 %d（×%.1f）" % [
			Difficulty.name(difficulty), hp, Difficulty.enemy_hp_mult(difficulty),
		], UITheme.TEXT))
	body.add_child(_make_body_label("口径：生命随难度缩放（读 BalanceData.enemy_hp_mult）；漏怪伤害 / 速度 / 护甲不随难度变化。", UITheme.GRAY, 13))

	body.add_child(_make_body_label("出现关卡", UITheme.GOLD, 18))
	var entries := GameFlow.get_enemy_stage_entries(_selected_enemy_id)
	if entries.is_empty():
		body.add_child(_make_body_label("未配置出现关卡", UITheme.DISABLED))
	for entry in entries:
		var stage_id: String = str(entry.get("stage_id", ""))
		var stage := GameFlow.load_stage_data(StringName(stage_id))
		var name_text := stage.display_name if stage != null else stage_id
		var suffix := "（Boss 召唤登场，非波次直出）" if entry.get("summoned", false) else ""
		body.add_child(_make_body_label("· 第 %d 关 %s%s" % [
			stage.stage_number if stage != null else 0, name_text, suffix,
		]))


## ============ 通用 ============

func _sync_selected_buttons() -> void:
	pass


func _profession_role_text(profession: ProfessionData) -> String:
	if profession == null:
		return "未知定位"
	var role_parts: Array[String] = []
	match profession.combat_role:
		ProfessionData.CombatRole.DAMAGE:
			role_parts.append("输出")
		ProfessionData.CombatRole.CONTROL:
			role_parts.append("控制")
		ProfessionData.CombatRole.SUPPORT:
			role_parts.append("辅助")
		ProfessionData.CombatRole.HYBRID:
			role_parts.append("混合")
	match profession.attack_pattern:
		ProfessionData.AttackPattern.SINGLE_TARGET:
			role_parts.append("单体")
		ProfessionData.AttackPattern.AREA:
			role_parts.append("范围")
		ProfessionData.AttackPattern.PIERCING:
			role_parts.append("穿透")
		ProfessionData.AttackPattern.AURA:
			role_parts.append("光环")
	return " · ".join(role_parts)


func _profession_counter_text(profession: ProfessionData) -> String:
	if profession != null and profession.profession_id == &"tiger_guard":
		return "骑兵（破阵：对骑兵目标伤害加成）"
	return ""


func _profession_color(character: CharacterData) -> Color:
	if character.profession != null:
		var colors: Dictionary = TowerScript.PROFESSION_COLORS
		return colors.get(character.profession.profession_id, Color(0.45, 0.55, 0.65))
	return Color(0.45, 0.55, 0.65)