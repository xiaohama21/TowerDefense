extends Control

## 游戏百科（ENCYCLOPEDIA.md v0.1.9 概念终版对齐）：只读信息中心——
## 武将图鉴（9 将全量 + 基础/技能/转职/信物/特性页签 + 数值模拟器）与
## 敌人图鉴（章节选择 + 12 敌双列网格 + 各档难度面板 + 出现关卡反查）。不写档、不改存档。
## 布局规范 UI_LAYOUT.md §12（v0.20.19）；卡片副行口径 = 职业名/定位 · 打法词（概念字典）。禁止面板间散落私有文案漂移。

const DevelopPanelScript := preload("res://scripts/ui_screens/panels/DevelopPanel.gd")
const MapPanelScript := preload("res://scripts/ui_screens/panels/MapPanel.gd")
const TowerScript := preload("res://scripts/Tower.gd")

## 第一章敌人展示顺序（ENEMIES.md 5.5.2 表序）。
const ENEMY_ORDER: Array[String] = [
	"yellow_turban_soldier",
	"yellow_turban_cavalry",
	"yellow_turban_sergeant",
	"yellow_turban_elite_sergeant",
	"yellow_turban_archer",
	"yellow_turban_berserker",
	"yellow_turban_heavy_berserker",
	"yellow_turban_sorcerer",
	"yellow_turban_armor_aura_caster",
	"yellow_turban_stealth_assassin",
	"yellow_turban_stealth_healer",
	"yellow_turban_general",
]

## 敌人定位标签（UI 短词口径，概念 ui_encyclopedia_enemy.html 卡片副行第一段 / 头部 chip1；
## 完整定位设计表见 ENEMIES.md 5.5.2：坦克=高血坦克、支援=光环支援 的 UI 短词）。
const ENEMY_LOCATIONS := {
	"yellow_turban_soldier": "炮灰",
	"yellow_turban_cavalry": "快速",
	"yellow_turban_sergeant": "精英",
	"yellow_turban_elite_sergeant": "精英",
	"yellow_turban_archer": "远程",
	"yellow_turban_berserker": "坦克",
	"yellow_turban_heavy_berserker": "坦克",
	"yellow_turban_sorcerer": "支援",
	"yellow_turban_armor_aura_caster": "支援",
	"yellow_turban_stealth_assassin": "隐匿",
	"yellow_turban_stealth_healer": "隐匿",
	"yellow_turban_general": "Boss",
}

## 敌人打法词（卡片副行第二段；概念图文案，对应特殊行为/数值基调）。
const ENEMY_TACTIC_SUB := {
	"yellow_turban_soldier": "近战",
	"yellow_turban_cavalry": "机动",
	"yellow_turban_sergeant": "头目",
	"yellow_turban_elite_sergeant": "军阵",
	"yellow_turban_archer": "高漏伤",
	"yellow_turban_berserker": "高血量",
	"yellow_turban_heavy_berserker": "中甲",
	"yellow_turban_sorcerer": "治疗光环",
	"yellow_turban_armor_aura_caster": "甲光环",
	"yellow_turban_stealth_assassin": "隐匿突袭",
	"yellow_turban_stealth_healer": "隐匿治疗",
	"yellow_turban_general": "召唤",
}

## 武将图鉴概念顺序（概念 ui_encyclopedia.html 列表卡顺序，不再按资源 id 字典序排位）。
const CHARACTER_ORDER: Array[String] = [
	"liu_bei",
	"guan_yu",
	"zhang_fei",
	"huang_zhong",
	"huang_fu_song",
	"diao_chan",
	"zhou_wei",
	"zhao_yun",
	"zhuge_liang",
]

## 武将头像概念配色键（概念 ui_encyclopedia.html .lcard .ava 九色：金/红/蓝/绿/紫/橙/棕/粉/青；
## 键映射 UITheme.avatar_label 渐变键，缺失回退蓝）。周仓=棕、赵云=粉、诸葛亮=青为概念色，
## 不再按职业色着色。
const CHARACTER_AVATAR_COLORS := {
	"liu_bei": "gold",
	"guan_yu": "red",
	"zhang_fei": "blue",
	"huang_zhong": "green",
	"huang_fu_song": "purple",
	"diao_chan": "orange",
	"zhou_wei": "brown",
	"zhao_yun": "pink",
	"zhuge_liang": "teal",
}

## 概念稿默认选中（武将=张飞、敌人=黄巾渠帅·张梁；缺失回退列表首位）。
const DEFAULT_CHARACTER_ID := "zhang_fei"
const DEFAULT_ENEMY_ID := "yellow_turban_general"

## 武将副行打法词（概念图列表卡 .sub「职业名 · 打法词」第二段；与 CHARACTERS.md 4.5.1
## 角色使用决策表对齐的百科展示字典，缺失回退职业定位短词）。
const CHARACTER_FLAVOR := {
	"liu_bei": "辅助",
	"guan_yu": "斩将",
	"zhang_fei": "士气",
	"huang_fu_song": "压制",
	"huang_zhong": "稳定",
	"diao_chan": "鼓舞",
	"zhou_wei": "抗线",
	"zhao_yun": "越战越勇",
	"zhuge_liang": "控场",
}

## 敌人方形头像对角渐变（概念 .eava 七色：白描边圆角方 + 135° 渐变）。
const ENEMY_AVATAR_GRADIENTS := {
	"yellow_turban_soldier": [Color("#e7c34f"), Color("#c08a16")],
	"yellow_turban_cavalry": [Color("#e08d4f"), Color("#b45a17")],
	"yellow_turban_sergeant": [Color("#d75f4f"), Color("#a62e20")],
	"yellow_turban_elite_sergeant": [Color("#c94a3a"), Color("#8c1f18")],
	"yellow_turban_archer": [Color("#7fbf6a"), Color("#3f8f34")],
	"yellow_turban_berserker": [Color("#8f7fbf"), Color("#5c46a6")],
	"yellow_turban_heavy_berserker": [Color("#8f9fd0"), Color("#4f5fa6")],
	"yellow_turban_sorcerer": [Color("#5fb8d9"), Color("#2b80a8")],
	"yellow_turban_armor_aura_caster": [Color("#d9b45f"), Color("#a8791f")],
	"yellow_turban_stealth_assassin": [Color("#5f6fd9"), Color("#2b3a8f")],
	"yellow_turban_stealth_healer": [Color("#5fd0a8"), Color("#25806a")],
	"yellow_turban_general": [Color("#7a6a9e"), Color("#44366b")],
}

## 当前章节阵营展示名（第一章=黄巾军；后续章节落地时随章节数据切换）。
const CHAPTER_FACTION := "黄巾军"

## 敌人特殊行为玩家向文案（BEHAVIORS.md B.3.2，勿直出 special_behavior_id）。
const ENEMY_BEHAVIOR_HINTS := {
	&"fast_charger": "高速推进，漏怪时造成更高基地伤害（轻骑 / 夜行刺）",
	&"healer_aura": "每 2s 治疗周围 120px 友军 15 点（隐方士 = 2.5s / 140px / 20 点）",
	&"armor_aura": "为周围友军（含自身）加甲 +6，持续刷新（精锐伍长 140px / 符祭 160px）",
	&"summon_guard": "每 8s 自岔路召唤 2 名步卒（广宗决战分叉试点）",
}

## 职业大招玩家向文案（CHARACTERS.md 4.6 表）。
const ULTIMATE_HINTS := {
	&"ultimate_cavalry_breaker": "对当前目标造成 3× 真实伤害（无视护甲）；若击杀则返还 50% 怒气",
	&"ultimate_tiger_guard_sweep": "破阵：范围内敌人受到 1.5× 物理伤害并击退，附近友方攻速提升",
	&"ultimate_archer_volley": "快速连射 4 支物理箭（0.8×），优先锁定低血量敌人",
	&"ultimate_strategist_blaze": "大范围魔法伤害并施加减速",
	&"ultimate_dancer_encourage": "范围内友方攻速与伤害提升，持续数秒",
	&"ultimate_catapult_barrage": "3 连发物理抛射轰击目标区域",
}

## 角色专属技能玩家向文案（CHARACTER_SKILLS.md §2 效果草案）。
const CHARACTER_SKILL_HINTS := {
	&"char_green_dragon": "3 段 × 2.0× 真实伤害（不分摊、无视护甲）；段内溢血转下一目标，每击杀冷却 -5s",
	&"char_dangyang_roar": "范围内敌人恐惧 1s（反向行军）→ 减速 60% 持续 2s",
	&"char_carry_people": "全队攻速 +15% 持续 5s（每波一次）",
	&"char_dingjun": "命中射程内最多 3 个目标，各 2.0× 物理伤害；未击杀者被「定军」标记 4s：受该塔普攻伤害 +15%",
	&"char_moon_dance": "全队怒气 +10（自身 +15）",
	&"char_burn_camp": "目标区域 1.5× 魔法伤害 + 灼烧 3s（每秒 0.25× 魔法）",
	&"char_seven_charges": "对射程内所有敌人造成 1× 物理伤害 + 自身攻速 +30% 持续 3s",
	&"char_death_fight": "自身攻速 +30%（常驻，仅触发一次）",
	&"char_borrow_wind": "全图友方塔攻速 +20%、弹道速度 +50% 持续 8s；期间**全图破隐**（可锁定隐匿单位）",
}

## 概念图 .dhead 底部 2px 虚线分隔（StyleBoxFlat 不支持 dashed，_draw 手绘横虚线）。
class DashedLine:
	extends Control

	var _dash_color := Color("#d7e9f5")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if size.x <= 4.0:
			return
		var y := size.y * 0.5
		var dash_len := 8.0
		var gap_len := 6.0
		var cycle := dash_len + gap_len
		var x := 0.0
		while x < size.x:
			draw_line(Vector2(x, y), Vector2(minf(x + dash_len, size.x), y), _dash_color, 2.0)
			x += cycle


## 敌人方形渐变头像（概念 .eava：白色描边圆角方 + 对角渐变 + 首字白字）。
## _draw 手绘：白圆角底 → 对角渐变纹理（四角月牙按底色裁切出圆角）→ 子 Label 白字。
class EnemyAvatar:
	extends Control

	var _text := ""
	var _font_size := 15
	var _top := Color("#7ec8ea")
	var _bottom := Color("#2eaadc")
	var _cut_color := Color("#f7fbfe")
	var _radius := 10.0
	var _texture: ImageTexture = null

	func setup(text: String, top_c: Color, bottom_c: Color, font_size: int,
			bg: Color, radius: float = 10.0) -> void:
		_text = text
		_top = top_c
		_bottom = bottom_c
		_font_size = font_size
		_cut_color = bg
		_radius = radius
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gradient := Gradient.new()
		gradient.set_color(0, _top)
		gradient.set_color(1, _bottom)
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.width = 64
		tex.height = 64
		tex.fill_from = Vector2(0.0, 0.0)
		tex.fill_to = Vector2(1.0, 1.0)
		# 预生成 ImageTexture 存实例：_draw 内现建纹理当帧画不上（B-048），
		# setup（入树前）建好、布局后重绘即可正常显示。
		_texture = ImageTexture.create_from_image(tex.get_image())
		var label := Label.new()
		label.text = text
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		queue_redraw()

	func _draw() -> void:
		if size.x <= 4.0:
			return
		var outer := StyleBoxFlat.new()
		outer.bg_color = Color.WHITE
		outer.set_corner_radius_all(int(_radius))
		outer.anti_aliasing = true
		draw_style_box(outer, Rect2(Vector2.ZERO, size))
		var border := 2.0
		var inner := Rect2(border, border, size.x - border * 2.0, size.y - border * 2.0)
		if inner.size.x <= 4.0:
			return
		if _texture != null:
			draw_texture_rect(_texture, inner, false)
		_cut_corners(inner, maxf(_radius - border, 1.0))

	func _cut_corners(rect: Rect2, r: float) -> void:
		var corners: Array = [
			[rect.position, rect.position + Vector2(r, 0), -PI * 0.5, -PI, rect.position + Vector2(0, r)],
			[rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(rect.size.x - r, 0), -PI * 0.5, 0.0, rect.position + Vector2(rect.size.x, r)],
			[rect.position + Vector2(rect.size.x, rect.size.y), rect.position + Vector2(rect.size.x - r, rect.size.y), PI * 0.5, 0.0, rect.position + Vector2(rect.size.x, rect.size.y - r)],
			[rect.position + Vector2(0, rect.size.y), rect.position + Vector2(r, rect.size.y), PI * 0.5, PI, rect.position + Vector2(0, rect.size.y - r)],
		]
		for def in corners:
			var corner_pt: Vector2 = def[0]
			var edge_a: Vector2 = def[1]
			var a0: float = def[2]
			var a1: float = def[3]
			var edge_b: Vector2 = def[4]
			var center := edge_a + edge_b - corner_pt
			var pts := PackedVector2Array()
			pts.append(corner_pt)
			pts.append(edge_a)
			var steps := 10
			for step in range(steps + 1):
				var t := float(step) / float(steps)
				var ang := lerpf(a0, a1, t)
				pts.append(center + Vector2(cos(ang), sin(ang)) * r)
			pts.append(edge_b)
			draw_colored_polygon(pts, _cut_color)


## 敌人方形渐变头像构建（概念 .eava；id 未收录回退蓝渐变）。
func _enemy_avatar(enemy_id: String, avatar_char: String, size: float,
		font_size: int, bg: Color) -> Control:
	var colors: Array = ENEMY_AVATAR_GRADIENTS.get(enemy_id, [Color("#7ec8ea"), Color("#2eaadc")])
	var avatar := EnemyAvatar.new()
	avatar.custom_minimum_size = Vector2(size, size)
	avatar.setup(avatar_char, colors[0], colors[1], font_size, bg, clampf(size * 0.19, 8.0, 11.0))
	return avatar



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
var _chapter_flow: HBoxContainer
var _character_buttons: Dictionary = {}
var _enemy_buttons: Dictionary = {}
var _left_box: VBoxContainer
var _left_scroll: ScrollContainer
var _kind_note: Label
var _list_header: Label
var _list_count: Label
var _sim_panel: PanelContainer
var _character_chips: HBoxContainer
var _enemy_chips: HBoxContainer
var _enemy_appear_label: Label
var _detail_box: VBoxContainer
var _header_name_label: Label
var _count_chip: Label
var _tab_container: TabContainer
var _base_tab: VBoxContainer
var _skill_tab: VBoxContainer
var _promotion_tab: VBoxContainer
var _relic_tab: VBoxContainer
var _trait_tab: VBoxContainer
var _sim_level_num: Label
var _sim_minus_button: Button
var _sim_plus_button: Button
var _sim_promotion_option: OptionButton
var _sim_rank_buttons: Dictionary = {}
var _sim_result_values: Dictionary = {}
var _detail_scroll_content: VBoxContainer


func _ready() -> void:
	_character_ids = _ordered_character_ids()
	_enemy_ids = _ordered_enemy_ids()
	_build_ui()
	# _switch_mode 首次进入即按概念默认选中张飞（DEFAULT_CHARACTER_ID），无需二次选中
	_switch_mode(&"character")


## 武将按 CHARACTER_ORDER 概念顺序（图鉴浏览序 = 概念图列表序；目录新增回退补齐）。
func _ordered_character_ids() -> Array[String]:
	var result: Array[String] = []
	for character_id in CHARACTER_ORDER:
		if GameFlow.load_character_data(character_id) != null:
			result.append(character_id)
	for character_id in GameFlow.get_all_character_ids():
		if not result.has(character_id):
			result.append(character_id)
	return result


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

	# 顶栏（概念 .topbar）：标题 + 全量图鉴 tag → spacer → 计数 chip + 只读 tag
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)
	var title := Label.new()
	title.text = "游戏百科"
	title.add_theme_font_override("font", UITheme.spaced_font(3))
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var full_tag := UITheme.tag_label("全量图鉴", UITheme.TAG_OK_FG, UITheme.TAG_OK_BG, 13)
	full_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(full_tag)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	_count_chip = Label.new()
	_count_chip.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.LIGHT_BLUE_SOFT, 11, 4))
	_count_chip.add_theme_font_size_override("font_size", 14)
	_count_chip.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	_count_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_count_chip)
	var readonly_tag := UITheme.tag_label("只读信息 · 不写存档", Color("#14538a"), UITheme.LIGHT_BLUE_SOFT, 13)
	readonly_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(readonly_tag)

	# 分段按钮行（概念 .kindbar）：武将图鉴 / 敌人图鉴 + 右侧解锁规则灰字
	var kind_row := HBoxContainer.new()
	kind_row.name = "KindRow"
	kind_row.add_theme_constant_override("separation", 10)
	root.add_child(kind_row)
	_character_button = _make_segment_button("武将图鉴", &"character")
	kind_row.add_child(_character_button)
	_enemy_button = _make_segment_button("敌人图鉴", &"enemy")
	kind_row.add_child(_enemy_button)
	var kind_spacer := Control.new()
	kind_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kind_row.add_child(kind_spacer)
	_kind_note = Label.new()
	_kind_note.add_theme_font_override("font", UITheme.spaced_font(1))
	_kind_note.add_theme_font_size_override("font_size", 13)
	_kind_note.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	_kind_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kind_row.add_child(_kind_note)

	# 章节选择行（敌人图鉴视图顶部，v0.20.1 用户拍板：对齐地图选关下拉框）
	_chapter_flow = HBoxContainer.new()
	_chapter_flow.name = "ChapterRow"
	_chapter_flow.add_theme_constant_override("separation", 10)
	root.add_child(_chapter_flow)
	var chapter_caption := Label.new()
	chapter_caption.text = "章节"
	chapter_caption.add_theme_font_size_override("font_size", 15)
	chapter_caption.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	chapter_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chapter_flow.add_child(chapter_caption)
	var chapter_option := OptionButton.new()
	chapter_option.name = "ChapterOption"
	chapter_option.custom_minimum_size = Vector2(250, 42)
	chapter_option.focus_mode = Control.FOCUS_NONE
	chapter_option.add_theme_font_override("font", UITheme.spaced_font(2))
	chapter_option.add_theme_font_size_override("font_size", 18)
	chapter_option.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	chapter_option.add_theme_icon_override("arrow", _chapter_arrow_icon())
	var box_style := UITheme.light_card_style(Color.WHITE, UITheme.LIGHT_BORDER_SOFT)
	box_style.border_width_bottom = 4
	box_style.set_corner_radius_all(10)
	box_style.content_margin_left = 12.0
	box_style.content_margin_right = 10.0
	box_style.content_margin_top = 6.0
	box_style.content_margin_bottom = 4.0
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		chapter_option.add_theme_stylebox_override(state, box_style)
	var chapter := GameFlow.get_chapter()
	chapter_option.add_item("第 %d 章 · %s" % [chapter.chapter_number, chapter.display_name])
	for reserved_name in MapPanelScript.RESERVED_CHAPTERS:
		var item_index := chapter_option.item_count
		chapter_option.add_item("敬请期待 · %s" % reserved_name)
		chapter_option.set_item_disabled(item_index, true)
	var popup := chapter_option.get_popup()
	if popup != null:
		var popup_style := UITheme.light_panel_style()
		popup_style.set_border_width_all(2)
		popup_style.border_color = UITheme.LIGHT_BORDER_SOFT
		popup_style.set_corner_radius_all(10)
		popup.add_theme_stylebox_override("panel", popup_style)
		popup.add_theme_color_override("font_color", UITheme.LIGHT_INK)
		popup.add_theme_color_override("font_hover_color", UITheme.LIGHT_INK)
		popup.add_theme_color_override("font_disabled_color", UITheme.LIGHT_LOCK)
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = UITheme.LIGHT_BLUE_SELECT
		popup.add_theme_stylebox_override("hover", hover_style)
	_chapter_flow.add_child(chapter_option)
	_chapter_flow.visible = false  # 武将图鉴视图不展示章节行

	# 中部两栏（概念 .work）：左 396px 列表卡 + 右详情卡
	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var list_panel := PanelContainer.new()
	list_panel.name = "ListPanel"
	list_panel.custom_minimum_size = Vector2(396, 0)
	list_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", UITheme.light_panel_style())
	body.add_child(list_panel)
	var list_margin := MarginContainer.new()
	list_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list_margin.add_theme_constant_override("margin_left", 12)
	list_margin.add_theme_constant_override("margin_right", 12)
	list_margin.add_theme_constant_override("margin_top", 10)
	list_margin.add_theme_constant_override("margin_bottom", 10)
	list_panel.add_child(list_margin)
	var list_column := VBoxContainer.new()
	list_column.add_theme_constant_override("separation", 8)
	list_margin.add_child(list_column)
	var list_head := HBoxContainer.new()
	list_head.add_theme_constant_override("separation", 10)
	list_column.add_child(list_head)
	_list_header = Label.new()
	_list_header.add_theme_font_override("font", UITheme.spaced_font(2))
	_list_header.add_theme_font_size_override("font_size", 16)
	_list_header.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	_list_header.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	list_head.add_child(_list_header)
	_list_count = Label.new()
	_list_count.add_theme_font_size_override("font_size", 12)
	_list_count.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	_list_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	list_head.add_child(_list_count)
	var head_spacer := Control.new()
	head_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_head.add_child(head_spacer)
	_left_scroll = ScrollContainer.new()
	_left_scroll.name = "LeftScroll"
	_left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_column.add_child(_left_scroll)
	_left_box = VBoxContainer.new()
	_left_box.name = "LeftBox"
	_left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_box.add_theme_constant_override("separation", 0)
	_left_scroll.add_child(_left_box)

	# 右侧详情卡（概念 .dp：白卡 3px #d7e9f5 外框）
	var detail_panel := PanelContainer.new()
	detail_panel.name = "DetailPanel"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", UITheme.light_panel_style())
	body.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	detail_margin.name = "DetailMargin"
	detail_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_margin.add_theme_constant_override("margin_left", 14)
	detail_margin.add_theme_constant_override("margin_right", 14)
	detail_margin.add_theme_constant_override("margin_top", 10)
	detail_margin.add_theme_constant_override("margin_bottom", 10)
	detail_panel.add_child(detail_margin)
	_detail_box = VBoxContainer.new()
	_detail_box.name = "DetailBox"
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 6)
	detail_margin.add_child(_detail_box)

	# 底部数值模拟器条（概念 .sim：白卡整行，仅武将图鉴展示；不挤占详情页签高度）
	_sim_panel = PanelContainer.new()
	_sim_panel.name = "SimPanel"
	_sim_panel.visible = false
	_sim_panel.add_theme_stylebox_override("panel", UITheme.light_panel_style())
	root.add_child(_sim_panel)
	_build_simulator(_sim_panel)


## 下拉/选择框概念 .pick 样式（白底蓝边圆角；转职选择与章节下拉同构）。
func _apply_pick_style(option: OptionButton) -> void:
	var pick_style := UITheme.light_card_style(Color("#f3f9fd"), UITheme.LIGHT_BORDER_SOFT)
	pick_style.set_border_width_all(2)
	pick_style.set_corner_radius_all(9)
	pick_style.content_margin_left = 12.0
	pick_style.content_margin_right = 10.0
	pick_style.content_margin_top = 4.0
	pick_style.content_margin_bottom = 4.0
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		option.add_theme_stylebox_override(state, pick_style)
	option.add_theme_color_override("font_color", Color("#14538a"))
	option.add_theme_color_override("font_hover_color", Color("#14538a"))
	option.add_theme_color_override("font_pressed_color", Color("#14538a"))
	option.add_theme_font_size_override("font_size", 14)
	option.add_theme_font_override("font", UITheme.spaced_font(1))
	option.add_theme_icon_override("arrow", _chapter_arrow_icon())


func _chapter_arrow_icon() -> ImageTexture:
	var texture := load("res://assets/ui/icons/arrow_basic_s_blue.png") as Texture2D
	var image := texture.get_image()
	image.resize(18, 12, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


## 左列卡片内容层（概念 .lcard：头像 + 姓名 + 副行；鼠标穿透，点击落到底层按钮）。
## 武将=概念九色圆形头像（avatar_key=UITheme.avatar_label 色键）；敌人=方形对角渐变头像（enemy_id 非空）。
func _make_left_card_content(avatar_char: String, avatar_key: String, card_text: String,
		enemy_id: String = "") -> Control:
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10.0
	content.offset_right = -10.0
	content.offset_top = 9.0
	content.offset_bottom = -9.0
	content.add_theme_constant_override("separation", 9)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar: Control
	if enemy_id.is_empty():
		avatar = UITheme.avatar_label(avatar_char, avatar_key, 40.0, 18)
	else:
		avatar = _enemy_avatar(enemy_id, avatar_char, 40.0, 15, UITheme.LIGHT_CARD_BG)
	content.add_child(avatar)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(info)
	var lines := card_text.split("\n")
	for i in range(lines.size()):
		var line_label := Label.new()
		line_label.text = lines[i]
		line_label.add_theme_font_size_override("font_size", 15 if i == 0 else 12)
		line_label.add_theme_color_override("font_color", UITheme.LIGHT_INK if i == 0 else UITheme.LIGHT_DESC)
		line_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info.add_child(line_label)
	return content


func _make_segment_button(label_text: String, mode: StringName) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(186, 46)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UITheme.spaced_font(4))
	button.add_theme_font_size_override("font_size", 20)
	button.toggle_mode = true
	# 概念 .segbtn：Kenney 蓝底白字=选中 / 灰底深字=未选（同科技树 .tabs 分段按钮口径）
	UITheme.apply_kenney_rect_button(button, "grey", UITheme.LIGHT_BODY)
	button.pressed.connect(_switch_mode.bind(mode))
	return button


func _switch_mode(mode: StringName) -> void:
	_mode = mode
	_character_button.set_pressed_no_signal(mode == &"character")
	_enemy_button.set_pressed_no_signal(mode == &"enemy")
	for button in [_character_button, _enemy_button]:
		# 概念 .segbtn 选中=Kenney 蓝底白字 / 未选=灰底深字（v0.19.1：两枚按钮每帧都全量刷样式）
		var active: bool = (button == _character_button) if mode == &"character" 			else (button == _enemy_button)
		UITheme.apply_kenney_rect_button(button, "blue" if active else "grey",
			Color.WHITE if active else UITheme.LIGHT_BODY)
	if _chapter_flow != null:
		_chapter_flow.visible = mode == &"enemy"
	if _count_chip != null:
		_count_chip.text = "武将 %d 名 · 全量可见" % _character_ids.size() if mode == &"character" \
			else "敌人 %d 种 · 第一章 · 黄巾军" % _enemy_ids.size()
	if _kind_note != null:
		_kind_note.text = "解锁规则：当前版本全量可见 · 「发现解锁」随阶段 10 接入" if mode == &"character" \
			else "解锁规则：当前版本全量可见 · 「难度面板 / 关卡信息解锁」随阶段 10 接入"
	if _sim_panel != null:
		_sim_panel.visible = mode == &"character"
	if _list_header != null:
		_list_header.text = "武将列表" if mode == &"character" else "敌人列表"
	if _list_count != null:
		_list_count.text = "%d 名 · 含未拥有" % _character_ids.size() if mode == &"character" \
			else "%d 种 · 第一章全部敌人" % _enemy_ids.size()
	_rebuild_left_list()
	_rebuild_detail()
	if mode == &"character":
		if _selected_character_id.is_empty() and not _character_ids.is_empty():
			_selected_character_id = _default_character_id()
		if not _selected_character_id.is_empty():
			_select_character(_selected_character_id)
	elif mode == &"enemy":
		if _selected_enemy_id.is_empty() and not _enemy_ids.is_empty():
			_selected_enemy_id = _default_enemy_id()
		if not _selected_enemy_id.is_empty():
			_select_enemy(_selected_enemy_id)


## 左侧列表：概念 .list 2 列网格卡（武将 9 卡 5 行 / 敌人 7 卡 4 行，卡片随网格拉伸铺满）。
func _rebuild_left_list() -> void:
	# 先摘除再释放：避免当帧新旧网格并存（DevelopPanel 同款处理）。
	for child in _left_box.get_children():
		_left_box.remove_child(child)
		child.queue_free()
	_character_buttons.clear()
	_enemy_buttons.clear()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_left_box.add_child(grid)
	if _mode == &"character":
		grid.name = "CharacterGrid"
		for character_id in _character_ids:
			var character := GameFlow.load_character_data(character_id)
			if character == null:
				continue
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.size_flags_vertical = Control.SIZE_EXPAND_FILL
			button.toggle_mode = true
			UITheme.apply_light_selectable(button)
			button.pressed.connect(_select_character.bind(str(character_id)))
			button.add_child(_make_left_card_content(
				character.display_name.left(1), _avatar_color_key(character),
				_character_card_text(character)))
			grid.add_child(button)
			_character_buttons[str(character_id)] = button
	else:
		grid.name = "EnemyGrid"
		for enemy_id in _enemy_ids:
			var enemy := GameFlow.load_enemy_data(enemy_id)
			if enemy == null:
				continue
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.size_flags_vertical = Control.SIZE_EXPAND_FILL
			button.toggle_mode = true
			UITheme.apply_light_selectable(button)
			button.pressed.connect(_select_enemy.bind(str(enemy_id)))
			var loc: String = ENEMY_LOCATIONS.get(enemy_id, "未知")
			var tactic: String = ENEMY_TACTIC_SUB.get(enemy_id, "")
			var sub := "%s · %s" % [loc, tactic] if not tactic.is_empty() else loc
			button.add_child(_make_left_card_content(enemy.display_name.left(1), "",
				"%s\n%s" % [enemy.display_name, sub], str(enemy_id)))
			grid.add_child(button)
			_enemy_buttons[str(enemy_id)] = button


## 卡片副行（概念 ui_encyclopedia.html .sub）：第一段 = 职业名，第二段 = 角色打法词
## （CHARACTER_FLAVOR 字典；口径与概念图一致并同步文档 v0.1.8）。
func _character_card_text(character: CharacterData) -> String:
	var profession := character.profession
	var prof_name := profession.display_name if profession != null else "未知职业"
	var flavor: String = CHARACTER_FLAVOR.get(str(character.character_id), "")
	if flavor.is_empty():
		flavor = _profession_role_short(profession)
	return "%s\n%s · %s" % [character.display_name, prof_name, flavor]


func _rebuild_detail() -> void:
	for child in _detail_box.get_children():
		child.queue_free()
	if _mode == &"enemy":
		_build_enemy_detail()
	else:
		_build_character_detail()


## ============ 武将图鉴 ============

func _build_character_detail() -> void:
	# 头行（概念 .dhead）：头像 52 + 名称 + chips（职业定位 / 称号）+ 右侧获取方式
	var header_row := HBoxContainer.new()
	header_row.name = "CharacterHeaderRow"
	header_row.add_theme_constant_override("separation", 12)
	_detail_box.add_child(header_row)
	var avatar_slot := CenterContainer.new()
	avatar_slot.name = "DetailAvatarSlot"
	avatar_slot.custom_minimum_size = Vector2(52, 52)
	header_row.add_child(avatar_slot)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_theme_constant_override("separation", 4)
	header_row.add_child(who)
	_header_name_label = Label.new()
	_header_name_label.add_theme_font_override("font", UITheme.spaced_font(2))
	_header_name_label.add_theme_font_size_override("font_size", 21)
	_header_name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	who.add_child(_header_name_label)
	_character_chips = HBoxContainer.new()
	_character_chips.name = "CharacterChips"
	_character_chips.add_theme_constant_override("separation", 6)
	who.add_child(_character_chips)
	var acquisition_box := VBoxContainer.new()
	acquisition_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	acquisition_box.add_theme_constant_override("separation", 2)
	header_row.add_child(acquisition_box)
	var acquisition_caption := Label.new()
	acquisition_caption.text = "获取方式"
	acquisition_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	acquisition_caption.add_theme_font_size_override("font_size", 12)
	acquisition_caption.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	acquisition_box.add_child(acquisition_caption)
	var acquisition_value := Label.new()
	acquisition_value.name = "AcquisitionValue"
	acquisition_value.text = GameFlow.get_acquisition_text(_selected_character_id)
	acquisition_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	acquisition_value.add_theme_font_size_override("font_size", 13)
	acquisition_value.add_theme_color_override("font_color", UITheme.TAG_OK_FG)
	acquisition_box.add_child(acquisition_value)
	# 虚线分隔（概念 .dhead border-bottom: 2px dashed）
	var head_dash := DashedLine.new()
	head_dash.name = "HeaderDash"
	head_dash.custom_minimum_size = Vector2(0, 2)
	_detail_box.add_child(head_dash)

	# 页签（概念 .tabs）
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.tab_alignment = TabBar.ALIGNMENT_LEFT
	UITheme.apply_light_tab_container(_tab_container)
	_detail_box.add_child(_tab_container)

	_base_tab = _make_tab("基础")
	_skill_tab = _make_tab("技能")
	_promotion_tab = _make_tab("转职")
	_relic_tab = _make_tab("信物")
	_trait_tab = _make_tab("特性")


func _make_tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "%sScroll" % tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)
	# 页签标题 = 概念页签文字（TabContainer 默认取子节点名，原为「基础Scroll…」，
	# v0.20.19 起显式 set_tab_title，去除内部滚动节点名后缀）。
	_tab_container.set_tab_title(_tab_container.get_tab_count() - 1, tab_name)
	# 页签体内容内边距（概念 .tabbody padding: 10px 14px）：文字/卡片与浅蓝描边留白，
	# 不再紧贴边框（v0.20.19）。
	var body_margin := MarginContainer.new()
	body_margin.name = "%sMargin" % tab_name
	body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", 14)
	body_margin.add_theme_constant_override("margin_right", 14)
	body_margin.add_theme_constant_override("margin_top", 10)
	body_margin.add_theme_constant_override("margin_bottom", 10)
	scroll.add_child(body_margin)
	var tab := VBoxContainer.new()
	tab.name = tab_name
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_constant_override("separation", 8)
	body_margin.add_child(tab)
	return tab


func _build_simulator(parent: PanelContainer) -> void:
	var sim_margin := MarginContainer.new()
	sim_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sim_margin.add_theme_constant_override("margin_left", 16)
	sim_margin.add_theme_constant_override("margin_right", 16)
	sim_margin.add_theme_constant_override("margin_top", 9)
	sim_margin.add_theme_constant_override("margin_bottom", 9)
	parent.add_child(sim_margin)
	var sim_box := VBoxContainer.new()
	sim_box.name = "SimBox"
	sim_box.add_theme_constant_override("separation", 8)
	sim_margin.add_child(sim_box)

	# 行 1（概念 .simr1）：标题 + 等级 −/＋ + 转职选择 + 局内升阶 0~3
	var row1 := HBoxContainer.new()
	row1.name = "SimRow1"
	row1.add_theme_constant_override("separation", 16)
	sim_box.add_child(row1)
	var sim_title := Label.new()
	sim_title.text = "数值模拟器"
	sim_title.add_theme_font_override("font", UITheme.spaced_font(2))
	sim_title.add_theme_font_size_override("font_size", 16)
	sim_title.add_theme_color_override("font_color", Color("#14538a"))
	sim_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row1.add_child(sim_title)

	var lv_group := HBoxContainer.new()
	lv_group.add_theme_constant_override("separation", 7)
	row1.add_child(lv_group)
	var lv_caption := Label.new()
	lv_caption.text = "等级"
	lv_caption.add_theme_font_size_override("font_size", 13)
	lv_caption.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	lv_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_group.add_child(lv_caption)
	_sim_minus_button = _make_step_button("−")
	_sim_minus_button.pressed.connect(_step_sim_level.bind(-1))
	lv_group.add_child(_sim_minus_button)
	_sim_level_num = Label.new()
	_sim_level_num.custom_minimum_size = Vector2(44, 0)
	_sim_level_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sim_level_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sim_level_num.add_theme_font_size_override("font_size", 18)
	_sim_level_num.add_theme_color_override("font_color", Color("#1b4d78"))
	lv_group.add_child(_sim_level_num)
	_sim_plus_button = _make_step_button("＋")
	_sim_plus_button.pressed.connect(_step_sim_level.bind(1))
	lv_group.add_child(_sim_plus_button)

	var promo_group := HBoxContainer.new()
	promo_group.add_theme_constant_override("separation", 7)
	row1.add_child(promo_group)
	var promo_caption := Label.new()
	promo_caption.text = "转职"
	promo_caption.add_theme_font_size_override("font_size", 13)
	promo_caption.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	promo_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	promo_group.add_child(promo_caption)
	_sim_promotion_option = OptionButton.new()
	_sim_promotion_option.custom_minimum_size = Vector2(200, 34)
	_sim_promotion_option.focus_mode = Control.FOCUS_NONE
	_apply_pick_style(_sim_promotion_option)
	_sim_promotion_option.item_selected.connect(func(_index: int) -> void: _on_sim_changed())
	promo_group.add_child(_sim_promotion_option)

	var rank_group := HBoxContainer.new()
	rank_group.name = "RankRow"
	rank_group.add_theme_constant_override("separation", 7)
	row1.add_child(rank_group)
	var rank_caption := Label.new()
	rank_caption.text = "局内升阶"
	rank_caption.add_theme_font_size_override("font_size", 13)
	rank_caption.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	rank_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_group.add_child(rank_caption)
	for rank in range(4):
		var rank_button := Button.new()
		rank_button.name = "Rank%d" % rank
		rank_button.text = str(rank)
		rank_button.custom_minimum_size = Vector2(40, 32)
		rank_button.focus_mode = Control.FOCUS_NONE
		rank_button.toggle_mode = true
		rank_button.pressed.connect(_set_sim_rank.bind(rank))
		rank_group.add_child(rank_button)
		_sim_rank_buttons[rank] = rank_button

	# 行 2（概念 .simr2）：= + 三枚金色结果卡 + 右侧只读提示
	var row2 := HBoxContainer.new()
	row2.name = "SimRow2"
	row2.add_theme_constant_override("separation", 10)
	sim_box.add_child(row2)
	var equal_label := Label.new()
	equal_label.text = "="
	equal_label.add_theme_font_size_override("font_size", 22)
	equal_label.add_theme_color_override("font_color", Color("#9fd0ea"))
	equal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row2.add_child(equal_label)
	for result_key in ["伤害", "攻速", "射程"]:
		var res_card := PanelContainer.new()
		res_card.custom_minimum_size = Vector2(86, 0)
		res_card.add_theme_stylebox_override("panel", _sim_result_style())
		var res_box := VBoxContainer.new()
		res_box.add_theme_constant_override("separation", 1)
		res_card.add_child(res_box)
		var res_caption := Label.new()
		res_caption.text = result_key
		res_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		res_caption.add_theme_font_size_override("font_size", 11)
		res_caption.add_theme_color_override("font_color", Color("#8a6d00"))
		res_box.add_child(res_caption)
		var res_value := Label.new()
		res_value.name = "SimValue%s" % result_key
		res_value.text = "-"
		res_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		res_value.add_theme_font_size_override("font_size", 17)
		res_value.add_theme_color_override("font_color", UITheme.LIGHT_GOLD_TEXT)
		res_box.add_child(res_value)
		row2.add_child(res_card)
		_sim_result_values[result_key] = res_value
	var row2_spacer := Control.new()
	row2_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(row2_spacer)
	var note_box := VBoxContainer.new()
	note_box.add_theme_constant_override("separation", 3)
	row2.add_child(note_box)
	var note_tag := UITheme.tag_label("预览不影响存档", UITheme.TAG_OK_FG, UITheme.TAG_OK_BG, 12)
	note_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note_box.add_child(note_tag)
	var note_sub := Label.new()
	note_sub.text = "数值与战斗实算一致（含特性与升阶乘区）"
	note_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note_sub.add_theme_font_size_override("font_size", 11)
	note_sub.add_theme_color_override("font_color", Color("#a4b8c8"))
	note_box.add_child(note_sub)


func _make_step_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(32, 32)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	var normal := UITheme.light_card_style(UITheme.LIGHT_BLUE_SOFT, Color(1, 1, 1, 0))
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(9)
	button.add_theme_stylebox_override("normal", normal)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = UITheme.LIGHT_BORDER_SOFT
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color("#14538a"))
	button.add_theme_color_override("font_pressed_color", Color("#14538a"))
	return button


func _sim_result_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff6d8")
	style.border_color = Color("#f0d98a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


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


func acquisition_box_lookup() -> Label:
	return _detail_box.find_child("AcquisitionValue", true, false) as Label


func _refresh_character_detail() -> void:
	var character := GameFlow.load_character_data(_selected_character_id)
	if character == null:
		return
	_header_name_label.text = character.display_name
	_refresh_character_chips(character)
	var avatar_slot := _detail_box.get_node("CharacterHeaderRow/DetailAvatarSlot") as CenterContainer
	for child in avatar_slot.get_children():
		avatar_slot.remove_child(child)
		child.queue_free()
	avatar_slot.add_child(UITheme.avatar_label(character.display_name.left(1),
		_avatar_color_key(character), 52.0, 22))
	var acquisition_label := acquisition_box_lookup()
	if acquisition_label != null:
		acquisition_label.text = GameFlow.get_acquisition_text(_selected_character_id)
	_refresh_base_tab(character)
	_refresh_skill_tab(character)
	_refresh_promotion_tab(character)
	_refresh_relic_tab(character)
	_refresh_trait_tab(character)
	_on_sim_changed()


## 头部 chips（概念 .dhead .chips）：①职业名 · 定位短词（蓝）②称号（概念 open tag）。
func _refresh_character_chips(character: CharacterData) -> void:
	if _character_chips == null:
		return
	for child in _character_chips.get_children():
		child.queue_free()
	var profession := character.profession
	var prof_name := profession.display_name if profession != null else "未知职业"
	var role_short := _profession_role_short(profession)
	_character_chips.add_child(UITheme.tag_label(
		"%s · %s" % [prof_name, role_short], Color("#14538a"), UITheme.LIGHT_BLUE_SOFT, 12))
	var title_text := character.titles[0] if not character.titles.is_empty() else "无"
	_character_chips.add_child(UITheme.tag_label(
		"称号 · %s" % title_text, UITheme.TAG_OPEN_FG, UITheme.TAG_OPEN_BG, 12))


func _clear_tab(tab: VBoxContainer) -> void:
	for child in tab.get_children():
		child.queue_free()


func _make_body_label(text_value: String, color: Color = UITheme.LIGHT_BODY, font_size: int = 15) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _stat_pill() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.LIGHT_STAT_BG
	style.border_color = UITheme.LIGHT_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style


func _refresh_base_tab(character: CharacterData) -> void:
	_clear_tab(_base_tab)
	var profession := character.profession
	var role_desc := "角色数据缺失"
	if profession != null:
		role_desc = "%s——%s" % [profession.display_name, profession.description]
	_base_tab.add_child(_make_irow("职业定位 · ", role_desc))
	_base_tab.add_child(_make_irow("等级上限 · ",
		"1 ~ %d（随章节推进逐步开放；经验由通关与击杀获得）" % LevelCurve.max_level()))
	var baseline := character.compute_stats_at(1, null, 0, null)
	var stat_row := HBoxContainer.new()
	stat_row.name = "BaseStatRow"
	stat_row.add_theme_constant_override("separation", 8)
	_base_tab.add_child(stat_row)
	stat_row.add_child(_stat_pill_box("伤害（Lv1）", str(int(baseline.damage))))
	stat_row.add_child(_stat_pill_box("攻速", "%.2fs" % float(baseline.attack_interval)))
	stat_row.add_child(_stat_pill_box("射程", str(int(baseline.range))))
	stat_row.add_child(_stat_pill_box("建造费用", str(character.build_cost), true))
	_base_tab.add_child(_make_irow("角色简介 · ", character.description))
	_base_tab.add_child(_make_irow("获取方式 · ",
		GameFlow.get_acquisition_text(str(character.character_id)), UITheme.TAG_OK_FG))


## 键值行（概念 .rows .irow：灰键 + 正文值，正文可自动换行）。
func _make_irow(key_text: String, value_text: String, value_color: Color = UITheme.LIGHT_BODY) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var key := Label.new()
	key.text = key_text
	key.add_theme_font_size_override("font_size", 13)
	key.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	key.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(key)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", value_color)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	return row


## 统计格（概念 .stat：浅蓝胶囊，k 11px + v 16px；gold=金色数值如建造费用）。
func _stat_pill_box(key_text: String, value_text: String, gold: bool = false) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.add_theme_stylebox_override("panel", _stat_pill())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	pill.add_child(box)
	var key := Label.new()
	key.text = key_text
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 11)
	key.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	box.add_child(key)
	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", UITheme.LIGHT_GOLD_TEXT if gold else UITheme.LIGHT_INK)
	box.add_child(value)
	return pill


func _refresh_skill_tab(character: CharacterData) -> void:
	_clear_tab(_skill_tab)
	var skill_id := character.character_skill_id
	if not skill_id.is_empty():
		var is_b := SkillRegistry.CHARACTER_SKILL_B_TYPE.has(skill_id)
		var type_text := "条件触发（被动）" if is_b else "主动（冷却制）"
		_skill_tab.add_child(_make_body_label("角色专属技能：%s（%s）" % [
			SkillRegistry.get_character_skill_name(skill_id), type_text,
		], UITheme.LIGHT_GOLD_TEXT))
		_skill_tab.add_child(_make_body_label("效果：%s" % CHARACTER_SKILL_HINTS.get(skill_id, "说明随版本完善"), UITheme.LIGHT_BODY))
	else:
		_skill_tab.add_child(_make_body_label("角色专属技能：无", UITheme.LIGHT_LOCK))
	_skill_tab.add_child(_make_body_label("——", UITheme.LIGHT_LOCK))
	var ultimate_id := character.ultimate_override_id
	if ultimate_id.is_empty() and character.profession != null:
		ultimate_id = character.profession.ultimate_id
	if not ultimate_id.is_empty():
		_skill_tab.add_child(_make_body_label("职业大招：%s（怒气满 100 释放）" % BehaviorRegistry.ultimate_display_name(ultimate_id), UITheme.LIGHT_GOLD_TEXT))
		_skill_tab.add_child(_make_body_label("效果：%s" % ULTIMATE_HINTS.get(ultimate_id, "说明随版本完善"), UITheme.LIGHT_BODY))
	else:
		_skill_tab.add_child(_make_body_label("职业大招：无", UITheme.LIGHT_LOCK))


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
		_promotion_tab.add_child(_make_body_label("该武将暂无转职路线", UITheme.LIGHT_LOCK))
		return
	_promotion_tab.add_child(_make_body_label("职业级转职树（同职业角色共享；预览任选不校验材料/等级）", UITheme.LIGHT_GOLD_TEXT))
	for node in nodes:
		var requirement := "等级 ≥ %d" % node.required_level
		var skills_text := _promotion_skill_text(node)
		var block := _make_body_label("· %s（%s）\n　%s\n　授予：%s\n　预览条件：%s" % [
			node.display_name, requirement, node.description, skills_text, requirement,
		])
		_promotion_tab.add_child(block)
	_promotion_tab.add_child(_make_body_label("档位口径：职业技能档位系数 s = 1 + 0.1 × min(局内升阶/5, 4)（仅职业技能适用，上限 +40%）", UITheme.LIGHT_MUTED, 13))


func _promotion_skill_text(promotion: PromotionData) -> String:
	var parts: Array[String] = []
	for skill_id in promotion.granted_skill_ids:
		parts.append(SkillRegistry.get_skill_name(skill_id))
	return "、".join(parts) if not parts.is_empty() else "无"


func _refresh_relic_tab(character: CharacterData) -> void:
	_clear_tab(_relic_tab)
	var relic := GameFlow.get_relic_for_character(str(character.character_id))
	if relic == null:
		_relic_tab.add_child(_make_body_label("该武将暂无专属信物", UITheme.LIGHT_LOCK))
		return
	_relic_tab.add_child(_make_body_label("%s（%d 碎片兑换）" % [relic.display_name, relic.shard_cost], UITheme.LIGHT_GOLD_TEXT))
	_relic_tab.add_child(_make_body_label("效果：%s" % relic.description))
	var effects: Array[String] = []
	if relic.damage_bonus > 0.0:
		effects.append("伤害 +%d%%" % int(round(relic.damage_bonus * 100)))
	if relic.range_bonus > 0.0:
		effects.append("射程 +%d%%" % int(round(relic.range_bonus * 100)))
	if relic.attack_interval_factor != 1.0:
		effects.append("攻速 %s%d%%" % ["+" if relic.attack_interval_factor < 1.0 else "-", int(abs((1.0 - relic.attack_interval_factor) * 100))])
	_relic_tab.add_child(_make_body_label("数值：%s" % ("；".join(effects) if not effects.is_empty() else "无"), UITheme.LIGHT_ACCENT))


func _refresh_trait_tab(character: CharacterData) -> void:
	_clear_tab(_trait_tab)
	var hints := DevelopPanelScript.TRAIT_HINTS
	var trait_id := character.trait_id
	if trait_id.is_empty():
		_trait_tab.add_child(_make_body_label("该武将暂无特性", UITheme.LIGHT_LOCK))
		return
	var hint_text: String = str(hints.get(trait_id, "说明随版本完善"))
	_trait_tab.add_child(_make_body_label("特性（常驻被动）：%s" % hint_text, UITheme.LIGHT_GOLD_TEXT))
	_trait_tab.add_child(_make_body_label("数据同源：与武将养成页签/局内表现共用字典，不在此另存文案。", UITheme.LIGHT_MUTED, 13))


## ============ 模拟器 ============

func _step_sim_level(delta: int) -> void:
	_sim_level = clampi(_sim_level + delta, 1, LevelCurve.max_level())
	_sim_level_num.text = str(_sim_level)
	_sim_minus_button.disabled = _sim_level <= 1
	_sim_plus_button.disabled = _sim_level >= LevelCurve.max_level()
	_on_sim_changed()


func _set_sim_rank(rank: int) -> void:
	_sim_battle_rank = clampi(rank, 0, 3)
	_sync_rank_buttons()
	_on_sim_changed()


## 升阶按钮态（概念 .rk：选中蓝底白字 / 未选浅蓝底深字）。
func _sync_rank_buttons() -> void:
	if _sim_rank_buttons.is_empty():
		return
	for rank in _sim_rank_buttons.keys():
		var button := _sim_rank_buttons[rank] as Button
		if button == null:
			continue
		button.set_pressed_no_signal(int(rank) == _sim_battle_rank)
		var on := int(rank) == _sim_battle_rank
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#1c9fd7") if on else Color("#e1f1fb")
		style.set_corner_radius_all(9)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("hover_pressed", style)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", Color.WHITE if on else Color("#33566f"))
		button.add_theme_color_override("font_pressed_color", Color.WHITE if on else Color("#33566f"))


func _on_sim_changed() -> void:
	var character := GameFlow.load_character_data(_selected_character_id)
	if character == null:
		return
	if _sim_level_num != null:
		_sim_level_num.text = str(_sim_level)
	if _sim_minus_button != null:
		_sim_minus_button.disabled = _sim_level <= 1
		_sim_plus_button.disabled = _sim_level >= LevelCurve.max_level()
	_sync_rank_buttons()
	var selected: int = _sim_promotion_option.selected if _sim_promotion_option != null else 0
	if selected > 0:
		_sim_promotion = _sim_promotion_ids.get(selected, null) as PromotionData
	else:
		_sim_promotion = null
	var stats := character.compute_stats_at(_sim_level, _sim_promotion, 0, null, _sim_battle_rank)
	var preview_range := float(stats.range) * character.get_static_range_multiplier()
	_set_sim_result("伤害", str(int(stats.damage)))
	_set_sim_result("攻速", "%.2fs" % float(stats.attack_interval))
	_set_sim_result("射程", str(int(preview_range)))


func _set_sim_result(result_key: String, value_text: String) -> void:
	var label := _sim_result_values.get(result_key, null) as Label
	if label != null:
		label.text = value_text


## ============ 敌人图鉴 ============

func _build_enemy_detail() -> void:
	# 头行（概念 .dhead）：方形渐变头像 52 + 名称 + chips + 右侧出现关卡
	var header_row := HBoxContainer.new()
	header_row.name = "EnemyHeaderRow"
	header_row.add_theme_constant_override("separation", 12)
	_detail_box.add_child(header_row)
	var avatar_slot := CenterContainer.new()
	avatar_slot.name = "EnemyAvatarSlot"
	avatar_slot.custom_minimum_size = Vector2(52, 52)
	header_row.add_child(avatar_slot)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_theme_constant_override("separation", 4)
	header_row.add_child(who)
	_header_name_label = Label.new()
	_header_name_label.add_theme_font_override("font", UITheme.spaced_font(2))
	_header_name_label.add_theme_font_size_override("font_size", 21)
	_header_name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	who.add_child(_header_name_label)
	_enemy_chips = HBoxContainer.new()
	_enemy_chips.name = "EnemyChips"
	_enemy_chips.add_theme_constant_override("separation", 6)
	who.add_child(_enemy_chips)
	var appear_box := VBoxContainer.new()
	appear_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	appear_box.add_theme_constant_override("separation", 2)
	header_row.add_child(appear_box)
	var appear_caption := Label.new()
	appear_caption.text = "出现关卡"
	appear_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	appear_caption.add_theme_font_size_override("font_size", 12)
	appear_caption.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	appear_box.add_child(appear_caption)
	_enemy_appear_label = Label.new()
	_enemy_appear_label.name = "EnemyAppearValue"
	_enemy_appear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_enemy_appear_label.add_theme_font_size_override("font_size", 13)
	_enemy_appear_label.add_theme_color_override("font_color", Color("#14538a"))
	_enemy_appear_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	appear_box.add_child(_enemy_appear_label)
	var head_dash := DashedLine.new()
	head_dash.name = "HeaderDash"
	head_dash.custom_minimum_size = Vector2(0, 2)
	_detail_box.add_child(head_dash)

	# 滚动详情体（概念 .body2：statrow → bcard → diffrow → foot）
	var scroll := ScrollContainer.new()
	scroll.name = "EnemyScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_box.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "EnemyDetailContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	scroll.add_child(content)
	_detail_scroll_content = content


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
	var enemy_avatar_slot := _detail_box.get_node("EnemyHeaderRow/EnemyAvatarSlot") as CenterContainer
	for child in enemy_avatar_slot.get_children():
		enemy_avatar_slot.remove_child(child)
		child.queue_free()
	enemy_avatar_slot.add_child(_enemy_avatar(_selected_enemy_id, enemy.display_name.left(1),
		52.0, 20, Color.WHITE))
	_refresh_enemy_chips(enemy)
	var entries := GameFlow.get_enemy_stage_entries(_selected_enemy_id)
	var sorted_entries := _sorted_stage_entries(entries)
	if _enemy_appear_label != null:
		_enemy_appear_label.text = _enemy_appear_summary(sorted_entries)
	_clear_tab(_detail_scroll_content)
	var body := _detail_scroll_content

	# ① 五统计格（概念 .statrow）
	var stat_row := HBoxContainer.new()
	stat_row.name = "EnemyStatRow"
	stat_row.add_theme_constant_override("separation", 8)
	body.add_child(stat_row)
	stat_row.add_child(_stat_pill_box("生命（基准）", str(enemy.max_hp)))
	stat_row.add_child(_stat_pill_box("速度", str(int(enemy.move_speed))))
	stat_row.add_child(_stat_pill_box("护甲", str(enemy.armor)))
	stat_row.add_child(_stat_pill_box("漏怪伤害", str(enemy.damage_to_base), true))
	stat_row.add_child(_stat_pill_box("击杀奖励", "金 %d · %d 经" % [enemy.currency_reward, enemy.kill_xp], true))

	# ② 特殊行为卡（概念 .bcard）
	var behavior_text := "无"
	if not enemy.special_behavior_id.is_empty():
		behavior_text = str(ENEMY_BEHAVIOR_HINTS.get(enemy.special_behavior_id, "说明随版本完善"))
	body.add_child(_make_labeled_card("特殊行为", behavior_text))
	# ②′ 隐匿机制卡（NUMBERS 10.16，✅ 0.8.13.1）：隐匿单位补破隐反制说明。
	if enemy.stealth:
		body.add_child(_make_labeled_card("隐匿机制",
			"无目标框、不显示血条，不可被「以单位为目标」的攻击选中；范围 / 无差别区域效果仍可命中。"
			+ "破隐来源：黄忠（固有）/ 诸葛亮·借东风（全图 8s）/ 貂蝉 3 阶光环（半径 = 射程）"))

	# ③ 各档难度面板（概念 .diffrow，随 difficulty_presets 自动扩档）
	var diff_row := HBoxContainer.new()
	diff_row.name = "DifficultyRow"
	diff_row.add_theme_constant_override("separation", 10)
	body.add_child(diff_row)
	for difficulty in range(Difficulty.count()):
		var diff_name := Difficulty.name(difficulty)
		var hp_mult := Difficulty.enemy_hp_mult(difficulty)
		var hp := int(round(enemy.max_hp * hp_mult))
		var is_hard := diff_name.contains("困难") or diff_name.contains("噩梦")
		var diff_card := PanelContainer.new()
		diff_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var diff_style := UITheme.light_card_style(Color.WHITE, UITheme.LIGHT_PANEL_BORDER)
		diff_style.set_border_width_all(2)
		diff_style.set_corner_radius_all(12)
		diff_card.add_theme_stylebox_override("panel", diff_style)
		var diff_box := VBoxContainer.new()
		diff_box.add_theme_constant_override("separation", 2)
		diff_card.add_child(diff_box)
		var hd_row := HBoxContainer.new()
		diff_box.add_child(hd_row)
		var hd_title := Label.new()
		hd_title.text = "%s难度" % diff_name
		hd_title.add_theme_font_size_override("font_size", 12)
		hd_title.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
		hd_row.add_child(hd_title)
		var hd_spacer := Control.new()
		hd_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hd_row.add_child(hd_spacer)
		var hd_mult := Label.new()
		hd_mult.text = "生命 ×%.1f" % hp_mult
		hd_mult.add_theme_font_size_override("font_size", 12)
		hd_mult.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
		hd_row.add_child(hd_mult)
		var hd_value := Label.new()
		hd_value.text = str(hp)
		hd_value.add_theme_font_size_override("font_size", 19)
		hd_value.add_theme_color_override("font_color",
			Color("#d71935") if is_hard else Color("#11804a"))
		diff_box.add_child(hd_value)
		var hd_sub := Label.new()
		hd_sub.text = "速度 %d · 护甲 %d · 漏怪伤害 %d（同基准，不变）" % [
			int(enemy.move_speed), enemy.armor, enemy.damage_to_base]
		hd_sub.add_theme_font_size_override("font_size", 11)
		hd_sub.add_theme_color_override("font_color", Color("#a4b8c8"))
		diff_box.add_child(hd_sub)
		diff_row.add_child(diff_card)

	# ④ 口径注脚（概念 .foot）
	body.add_child(_make_body_label(
		"难度口径：仅生命随难度倍率缩放（当前 %d 档 = 标准 / 困难，随难度档位自动扩展）；速度 / 护甲 / 漏怪伤害不随难度变化。" % Difficulty.count(),
		UITheme.LIGHT_MUTED, 12))

	# ⑤ 出现关卡明细（头部右侧已给摘要；多关登场补全量列表，单关已在头部展示不重复）
	if sorted_entries.size() > 1:
		var lines: Array[String] = []
		for entry in sorted_entries:
			var stage: StageData = entry.get("stage", null) as StageData
			var stage_id: String = str(entry.get("stage_id", ""))
			var name_text := stage.display_name if stage != null else stage_id
			var line := "第 %d 关 · %s" % [stage.stage_number if stage != null else 0, name_text]
			if entry.get("summoned", false):
				line += "（Boss 召唤登场）"
			lines.append(line)
		body.add_child(_make_labeled_card("出现关卡", "、".join(lines)))


## 敌人头部 chips（概念 .dhead .chips）：①定位词（Boss=红，其余蓝）②阵营 · 首现关卡。
func _refresh_enemy_chips(enemy: EnemyData) -> void:
	if _enemy_chips == null:
		return
	for child in _enemy_chips.get_children():
		child.queue_free()
	var loc: String = ENEMY_LOCATIONS.get(_selected_enemy_id, "未知")
	var is_boss := loc == "Boss"
	_enemy_chips.add_child(UITheme.tag_label(loc,
		UITheme.TAG_FIRE_FG if is_boss else Color("#14538a"),
		UITheme.TAG_FIRE_BG if is_boss else UITheme.LIGHT_BLUE_SOFT, 12))
	var entries := GameFlow.get_enemy_stage_entries(_selected_enemy_id)
	var sorted_entries := _sorted_stage_entries(entries)
	var first_name := "未配置"
	if not sorted_entries.is_empty():
		var first: Dictionary = sorted_entries[0]
		var stage := first.get("stage", null) as StageData
		first_name = stage.display_name if stage != null else str(first.get("stage_id", ""))
	_enemy_chips.add_child(UITheme.tag_label(
		"%s · %s" % [CHAPTER_FACTION, first_name], Color("#14538a"), UITheme.LIGHT_BLUE_SOFT, 12))


## 敌人出现关卡条目按关号升序（Boss 召唤补记去重，只保留直出或首个来源）。
func _sorted_stage_entries(entries: Array) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for entry in entries:
		var stage_id: String = str(entry.get("stage_id", ""))
		if stage_id.is_empty() or seen.has(stage_id):
			continue
		seen[stage_id] = true
		var stage := GameFlow.load_stage_data(StringName(stage_id))
		result.append({
			"stage_id": stage_id,
			"stage": stage,
			"summoned": bool(entry.get("summoned", false)),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: StageData = a.get("stage", null) as StageData
		var sb: StageData = b.get("stage", null) as StageData
		return (sa.stage_number if sa != null else 999) < (sb.stage_number if sb != null else 999))
	return result


## 头部出现关卡摘要（概念 .dhead .appear：单关 = sNN · 关名；多关 = sNN~sMM · 共 N 关）。
func _enemy_appear_summary(sorted_entries: Array) -> String:
	if sorted_entries.is_empty():
		return "未配置出现关卡"
	if sorted_entries.size() == 1:
		var entry: Dictionary = sorted_entries[0]
		var stage := entry.get("stage", null) as StageData
		if stage == null:
			return str(entry.get("stage_id", ""))
		var text_value := "s%02d · %s" % [stage.stage_number, stage.display_name]
		if ENEMY_LOCATIONS.get(_selected_enemy_id, "") == "Boss":
			text_value += "（Boss 战）"
		return text_value
	var first: Dictionary = sorted_entries[0]
	var last: Dictionary = sorted_entries[sorted_entries.size() - 1]
	var first_stage := first.get("stage", null) as StageData
	var last_stage := last.get("stage", null) as StageData
	if first_stage == null or last_stage == null:
		return "多关登场（共 %d 关）" % sorted_entries.size()
	return "s%02d~s%02d · 共 %d 关" % [first_stage.stage_number, last_stage.stage_number, sorted_entries.size()]


## 标题 + 正文卡（概念 .bcard：浅蓝底圆角卡）。
func _make_labeled_card(card_title: String, detail_text: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := UITheme.light_card_style()
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left = 10.0
	card_style.content_margin_right = 10.0
	card_style.content_margin_top = 7.0
	card_style.content_margin_bottom = 7.0
	card.add_theme_stylebox_override("panel", card_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var card_key := Label.new()
	card_key.text = card_title
	card_key.add_theme_font_size_override("font_size", 13)
	card_key.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	row.add_child(card_key)
	var card_value := Label.new()
	card_value.text = detail_text
	card_value.add_theme_font_size_override("font_size", 14)
	card_value.add_theme_color_override("font_color", Color("#33566f"))
	card_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(card_value)
	return card


## ============ 通用 ============

func _sync_selected_buttons() -> void:
	for character_id in _character_buttons.keys():
		var button := _character_buttons[character_id] as Button
		if is_instance_valid(button):
			button.set_pressed_no_signal(str(character_id) == _selected_character_id)
	for enemy_id in _enemy_buttons.keys():
		var button := _enemy_buttons[enemy_id] as Button
		if is_instance_valid(button):
			button.set_pressed_no_signal(str(enemy_id) == _selected_enemy_id)



## 职业定位短词（概念 .dhead chips① / 卡片副行兜底）：职业 tags → 中文词，
## 与武将养成职业页签同源（DevelopPanel.PROFESSION_TAG_LABELS），不另存第二份。
func _profession_role_short(profession: ProfessionData) -> String:
	if profession == null:
		return "未知"
	var parts: Array[String] = []
	for tag in profession.tags:
		var label: String = DevelopPanelScript.PROFESSION_TAG_LABELS.get(tag, "")
		if not label.is_empty() and not parts.has(label):
			parts.append(label)
	if parts.is_empty():
		return "近战" if profession.tags.has(&"melee") else (
			"远程" if profession.tags.has(&"ranged") else "战场")
	return " · ".join(parts)


## 战斗定位词（输出/控制/辅助/混合）：卡片短标签专用，单字词保证宽度内放下。
func _profession_card_role_text(profession: ProfessionData) -> String:
	if profession == null:
		return "未知"
	match profession.combat_role:
		ProfessionData.CombatRole.DAMAGE:
			return "输出"
		ProfessionData.CombatRole.CONTROL:
			return "控制"
		ProfessionData.CombatRole.SUPPORT:
			return "辅助"
		ProfessionData.CombatRole.HYBRID:
			return "混合"
	return "未知"


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


## 概念默认选中武将（DEFAULT_CHARACTER_ID 未收录回退列表首位）。
func _default_character_id() -> String:
	if _character_ids.has(DEFAULT_CHARACTER_ID):
		return DEFAULT_CHARACTER_ID
	return _character_ids[0]


## 概念默认选中敌人（DEFAULT_ENEMY_ID 未收录回退列表首位）。
func _default_enemy_id() -> String:
	if _enemy_ids.has(DEFAULT_ENEMY_ID):
		return DEFAULT_ENEMY_ID
	return _enemy_ids[0]


## 武将头像概念九色键（CHARACTER_AVATAR_COLORS；缺失回退蓝，不再按职业色着色）。
func _avatar_color_key(character: CharacterData) -> String:
	return str(CHARACTER_AVATAR_COLORS.get(str(character.character_id), "blue"))
