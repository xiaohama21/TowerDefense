extends Control

## 编队界面（SquadSelect）——按概念图 ui_squad.png v3 / UI_LAYOUT.md §7（v0.20.35）
## 落地（docs v0.37.19 / 程序 0.8.11.12；2026-09-09 用户拍板「直接按照概念图开发编队界面与出战弹窗」，
## 0.8.11.12 按反馈简化「遗物不显示持有 / 右侧只列三行数值 / 详情浮层紧凑 / 确认弹窗遗物仅图标+名称」）：
## 天空渐变底 + 亮蓝白页（标题行：出征·编队 + 章节 tag + 关卡·难度 tag + 出战计数；
## 操作提示行：点选说明 +「溢出自动滚动」tag + 已拥有/未解锁计数）→ 左右两栏：
## 左 = 3 列滚动武将网格（≤9 名 3×3 一屏铺满、第 10 位起自动增行纵向滚动；卡 =
## 圆头像 / 姓名+Lv / 职业·定位 / 羁绊 mini（随勾选实时刷新）/ 卡面底部内嵌建造费用通栏
## B-025（与卡面同底同圆角，不贴片）；未解锁灰卡标注解锁来源，无费用）+
## 队伍遗物行（说明列 + 紫晶渐变图标 pill：名称 / 已选·可选徽标，不显示持有数量；悬停浮层看详情、
## 移开即消失、不占布局；超过一行横向滚动）→ 右 = 队伍加成面板（科技 / 羁绊 / 遗物三行，
## 每行直接一个合计数值 + 概算口径注脚）→ 底部固定操作条
## （返回选关 灰 / 确认出战 金）→「确认出战」自绘二次确认弹窗（ui_squad_confirm.png 版式：
## 蓝标题条 + 章节 chip + ✕；出战武将名单行 + 遗物清单（图标占位 + 名称）+ 虚线提示条 + 取消/确认底栏）。
## 行为保留（v0.33.1）：点选/取消、最多 squad_size 名、遗物最多 2 件（超上限禁选）、
## 编队记忆自动预填；确认后写入档案（squad_character_ids / squad_relic_ids）并 goto_battle；
## 返回选关保留关卡与难度。

const RELIC_CAP := 2
const GRID_COLUMNS := 3
const CARD_MIN_SIZE := Vector2(280, 130)
const CN_NUMERALS := ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

## 武将卡副行「职业 · 定位」的定位短词（概念 ui_squad.html v3 卡片 .sub 第二段，用户拍板
## v3 定稿口径）；缺失回退百科打法词（EncyclopediaPanel.CHARACTER_FLAVOR），再缺失留空。
const SQUAD_ROLE_WORDS := {
	"liu_bei": "辅助",
	"guan_yu": "爆发",
	"zhang_fei": "近战",
	"huang_zhong": "点杀",
	"huang_fu_song": "范围",
	"diao_chan": "大招辅助",
	"zhou_wei": "牵制",
	"zhao_yun": "快攻",
	"zhuge_liang": "范围",
}

const EncyclopediaPanelScript := preload("res://scripts/ui_screens/panels/EncyclopediaPanel.gd")

## 细虚线（Godot StyleBoxFlat 不支持 dashed，自绘横线；概念 .cost 上承线 / 分区线）。
class DashLine:
	extends Control

	var dash_color := Color("#e6f0f7")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_dashed_line(Vector2.ZERO, Vector2(size.x, 0.0), dash_color, 1.0, 5.0)


## 遗物 pill 右下角「虚线圆 + ⇪」悬停示意（概念 .rpill 角标；纯装饰不响应鼠标）。
class HoverHintMark:
	extends Control

	var _color := Color("#9fb3c4")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, size.y * 0.5)
		var radius := 4.5
		var segments := 16
		for i in range(segments):
			if i % 2 == 0:
				var a0 := TAU * float(i) / float(segments)
				var a1 := TAU * float(i + 1) / float(segments)
				draw_arc(center, radius, a0, a1, 2, _color, 1.0, true)
		var x := center.x
		draw_line(Vector2(x, center.y + 2.0), Vector2(x, center.y - 3.0), _color, 1.0)
		draw_line(Vector2(x - 2.5, center.y - 0.5), Vector2(x, center.y - 3.0), _color, 1.0)
		draw_line(Vector2(x + 2.5, center.y - 0.5), Vector2(x, center.y - 3.0), _color, 1.0)


var _stage_data: StageData
var _chapter: ChapterData
var _roster: Array[CharacterData] = []
var _owned_ids: Array[String] = []
var _selected_ids: Array[String] = []
var _selected_relic_ids: Array[String] = []

## 武将卡控件表：character_id → {button, level, bonds_box, state_label, state_style,
## cost_tag, cost_value, lock_label, src_label, locked}。
var _card_widgets: Dictionary = {}
## 遗物 pill 控件表：relic_id → {button, state_label, state_style, name_label}。
var _pill_widgets: Dictionary = {}

var _title_progress_label: Label
var _zone_progress_label: Label
var _start_button: Button
var _grid_scroll: ScrollContainer
var _grid: GridContainer
var _relic_scroll: ScrollContainer
var _relic_row: HBoxContainer
var _tech_value_label: Label
var _bond_value_label: Label
var _relic_value_label: Label

var _confirm_popup: Control
var _relic_tooltip: PanelContainer
var _relic_tooltip_box: VBoxContainer


func _ready() -> void:
	_stage_data = GameFlow.load_stage_data(GameFlow.selected_stage_id)
	_chapter = _chapter_for_stage(_stage_data)
	_load_roster()
	_apply_saved_memory()
	_build_ui()
	_sync_all()
	_refresh()


# ---------------------------------------------------------------- 数据准备

func _chapter_for_stage(stage: StageData) -> ChapterData:
	if stage == null:
		return GameFlow.get_chapter()
	for entry in ResourceLoader.list_directory(GameFlow.CHAPTER_SCENE_DIR):
		if not entry.ends_with(".tres"):
			continue
		var chapter := load("%s/%s" % [GameFlow.CHAPTER_SCENE_DIR, entry]) as ChapterData
		if chapter == null:
			continue
		for chapter_stage in chapter.stages:
			if chapter_stage != null and str(chapter_stage.stage_id) == str(stage.stage_id):
				return chapter
	return GameFlow.get_chapter()


## 全量武将卡（含未拥有灰卡）：概念顺序（CHARACTER_ORDER）优先，未知角色按 id 收尾。
func _load_roster() -> void:
	var profile := ProfileStore.get_profile()
	_owned_ids.clear()
	for owned_id in profile.get_owned_character_ids():
		_owned_ids.append(str(owned_id))
	var order := {}
	for i in EncyclopediaPanelScript.CHARACTER_ORDER.size():
		order[EncyclopediaPanelScript.CHARACTER_ORDER[i]] = i
	var ids := GameFlow.get_all_character_ids()
	ids.sort_custom(func(a, b) -> bool:
		var ai: int = order.get(str(a), 999999)
		var bi: int = order.get(str(b), 999999)
		if ai != bi:
			return ai < bi
		return str(a) < str(b)
	)
	for character_id in ids:
		var character_data := GameFlow.load_character_data(str(character_id))
		if character_data != null:
			_roster.append(character_data)


## 编队记忆自动预填（v0.33.1，UI_LAYOUT §7）：优先玩家档案记忆，档案无记忆回退运行时
## 状态；武将须仍拥有且不超 squad_size，遗物须仍有库存且不超 2 件。
func _apply_saved_memory() -> void:
	var profile := ProfileStore.get_profile()
	var saved_characters := GameFlow.load_saved_squad(profile)
	var character_source := saved_characters if not saved_characters.is_empty() else GameFlow.squad_character_ids
	for character_data in _roster:
		var character_id := str(character_data.character_id)
		if _is_owned(character_id) and character_source.has(character_id) \
				and _selected_ids.size() < _squad_cap():
			_selected_ids.append(character_id)
	var saved_relics := GameFlow.load_saved_squad_relics(profile)
	var relic_source := saved_relics if not saved_relics.is_empty() else GameFlow.squad_relic_ids
	for relic_id in relic_source:
		if _selected_relic_ids.size() >= RELIC_CAP or _selected_relic_ids.has(relic_id):
			continue
		var amount := int(profile.items.get(relic_id, 0))
		var relic := GameFlow.load_battle_relic_data(str(relic_id))
		if amount > 0 and relic != null and relic.is_valid():
			_selected_relic_ids.append(str(relic_id))


func _is_owned(character_id: String) -> bool:
	return _owned_ids.has(character_id)


func _squad_cap() -> int:
	return _stage_data.squad_size if _stage_data != null else 4


# ---------------------------------------------------------------- 页面骨架

func _build_ui() -> void:
	_build_background()
	var page := _build_page_panel()
	_build_page_content(page)
	_build_relic_tooltip()


## 天空三档渐变 + 顶部柔光（同 GameHub / MainMenu 视觉令牌）。
func _build_background() -> void:
	var sky := TextureRect.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sky_gradient := Gradient.new()
	sky_gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	sky_gradient.colors = PackedColorArray([UITheme.SKY_TOP, UITheme.SKY_MID, UITheme.SKY_BOTTOM])
	var sky_texture := GradientTexture2D.new()
	sky_texture.gradient = sky_gradient
	sky_texture.fill_from = Vector2(0.5, 0.0)
	sky_texture.fill_to = Vector2(0.5, 1.0)
	sky_texture.width = 8
	sky_texture.height = 256
	sky.texture = sky_texture
	add_child(sky)

	var glow := TextureRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var glow_gradient := Gradient.new()
	glow_gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	glow_gradient.colors = PackedColorArray([Color(1, 1, 1, 0.28), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.0)])
	var glow_texture := GradientTexture2D.new()
	glow_texture.gradient = glow_gradient
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	glow_texture.width = 128
	glow_texture.height = 128
	glow.texture = glow_texture
	glow.position = Vector2(640.0 - 380.0, -160.0)
	glow.size = Vector2(760.0, 420.0)
	add_child(glow)


## 居中圆角页（概念 .page：亮蓝描边 + 7px 深蓝下边 + 圆角 18 + 投影）。
func _build_page_panel() -> Panel:
	var page := Panel.new()
	page.anchor_left = 0.0
	page.anchor_right = 1.0
	page.anchor_top = 0.0
	page.anchor_bottom = 1.0
	page.offset_left = 24.0
	page.offset_right = -24.0
	page.offset_top = 36.0
	page.offset_bottom = -36.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f2faff")
	style.border_color = Color("#1c9fd7")
	style.set_border_width_all(3)
	style.border_width_bottom = 7
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.024, 0.11, 0.196, 0.45)
	style.shadow_size = 26
	style.shadow_offset = Vector2(0, 12)
	page.add_theme_stylebox_override("panel", style)
	add_child(page)
	return page


func _build_page_content(page: Panel) -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 22.0
	root.offset_right = -22.0
	root.offset_top = 14.0
	root.offset_bottom = -12.0
	root.add_theme_constant_override("separation", 9)
	page.add_child(root)

	root.add_child(_build_title_bar())
	root.add_child(_build_zone_bar())

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	root.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	left.add_child(_build_character_area())
	left.add_child(_build_relic_area())
	cols.add_child(_build_power_panel())

	root.add_child(_build_footer())

## 标题行（概念 .title）：出征·编队 + 章节 tag + 关卡·难度 tag + 出战计数。
func _build_title_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "出征 · 编队"
	title.add_theme_font_override("font", UITheme.spaced_font(3))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	bar.add_child(title)
	bar.add_child(UITheme.tag_label(_chapter_label(), Color("#14538a"), Color("#e1f1fb"), 13))
	bar.add_child(UITheme.tag_label(_stage_and_difficulty_label(), UITheme.TAG_OPEN_FG, UITheme.TAG_OPEN_BG, 13))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_title_progress_label = UITheme.tag_label("出战 0 / 0", Color("#33566f"), Color("#e1f1fb"), 14)
	bar.add_child(_title_progress_label)
	return bar


func _chapter_label() -> String:
	if _chapter != null:
		var numeral: String = CN_NUMERALS[_chapter.chapter_number - 1] \
				if _chapter.chapter_number >= 1 and _chapter.chapter_number <= CN_NUMERALS.size() \
				else str(_chapter.chapter_number)
		return "第%s章 · %s" % [numeral, _chapter.display_name]
	return "第一章 · 黄巾之乱"


func _stage_and_difficulty_label() -> String:
	if _stage_data == null:
		return "未选择关卡"
	return "s%02d %s · %s" % [_stage_data.stage_number, _stage_data.display_name,
		Difficulty.name(GameFlow.selected_difficulty)]


## 操作提示行（概念 .zone）：说明 + 溢出自动滚动 tag + 已拥有/未解锁计数。
func _build_zone_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "出战武将"
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("#33566f"))
	label.add_theme_font_override("font", UITheme.spaced_font(2))
	bar.add_child(label)
	var hint := Label.new()
	hint.text = "点选 / 取消 · 金色描边为出战 · 羁绊与右侧队伍加成实时刷新"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("#a8bccb"))
	bar.add_child(hint)
	var scroll_tag := UITheme.tag_label("溢出自动滚动", Color("#14538a"), Color("#e1f1fb"), 11)
	bar.add_child(scroll_tag)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_zone_progress_label = Label.new()
	_zone_progress_label.add_theme_font_size_override("font_size", 13)
	_zone_progress_label.add_theme_color_override("font_color", Color("#33566f"))
	_zone_progress_label.add_theme_font_override("font", UITheme.spaced_font(1))
	bar.add_child(_zone_progress_label)
	return bar


# ---------------------------------------------------------------- 左：武将网格

func _build_character_area() -> Control:
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.add_child(_grid)
	_style_v_scrollbar(_grid_scroll)
	for character_data in _roster:
		_grid.add_child(_make_character_card(character_data))
	return _grid_scroll


func _make_character_card(character_data: CharacterData) -> Button:
	var character_id := str(character_data.character_id)
	var owned := _is_owned(character_id)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.toggle_mode = owned
	card.disabled = not owned
	card.custom_minimum_size = CARD_MIN_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_card_styleboxes(card, owned)
	if owned:
		card.toggled.connect(_on_character_toggled.bind(character_id))

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 11.0
	content.offset_right = -11.0
	content.offset_top = 8.0
	content.offset_bottom = 0.0
	content.add_theme_constant_override("separation", 0)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 11)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(body)

	var avatar := UITheme.avatar_label(character_data.display_name.left(1),
		"grey" if not owned else UITheme.character_avatar_color_key(character_id), 58.0, 27)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(avatar)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 3)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(info)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 7)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_row)
	var name_label := Label.new()
	name_label.text = character_data.display_name
	name_label.add_theme_font_override("font", UITheme.spaced_font(1))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color",
		UITheme.LIGHT_INK if owned else Color("#9fb3c4"))
	name_row.add_child(name_label)
	var level_label := Label.new()
	level_label.text = ""
	level_label.visible = owned
	level_label.add_theme_stylebox_override("normal", UITheme.tag_style(Color("#e1f1fb"), 7, 1))
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color("#14538a"))
	name_row.add_child(level_label)

	var sub_label := Label.new()
	sub_label.text = _character_sub_text(character_data, owned)
	sub_label.add_theme_font_size_override("font_size", 12)
	sub_label.add_theme_color_override("font_color",
		Color("#6b93ad") if owned else Color("#a8bccb"))
	sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(sub_label)

	var src_label := Label.new()
	src_label.text = GameFlow.get_acquisition_text(character_id) if not owned else ""
	src_label.visible = not owned
	src_label.add_theme_font_size_override("font_size", 10)
	src_label.add_theme_color_override("font_color", Color("#9fb3c4"))
	src_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(src_label)

	var bonds_box := HBoxContainer.new()
	bonds_box.visible = owned
	bonds_box.add_theme_constant_override("separation", 5)
	bonds_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(bonds_box)

	# 卡面底部内嵌建造费用通栏（B-025）：细虚线上承 + 与卡面同底同圆角，不贴片。
	var cost_area := VBoxContainer.new()
	cost_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(cost_area)
	var dash := DashLine.new()
	dash.custom_minimum_size = Vector2(0, 1)
	dash.dash_color = Color("#dbe6ee") if not owned else Color("#e6f0f7")
	cost_area.add_child(dash)
	var cost_row := HBoxContainer.new()
	cost_row.custom_minimum_size = Vector2(0, 27)
	cost_row.add_theme_constant_override("separation", 7)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_area.add_child(cost_row)

	var cost_tag := Label.new()
	cost_tag.text = "建造费用"
	cost_tag.visible = owned
	cost_tag.add_theme_stylebox_override("normal", UITheme.tag_style(UITheme.TAG_OPEN_BG, 6, 1))
	cost_tag.add_theme_font_size_override("font_size", 10)
	cost_tag.add_theme_color_override("font_color", Color("#8a6d00"))
	cost_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_row.add_child(cost_tag)

	var cost_value := Label.new()
	cost_value.text = str(character_data.build_cost) if owned else ""
	cost_value.visible = owned
	cost_value.add_theme_font_size_override("font_size", 15)
	cost_value.add_theme_color_override("font_color", Color("#b8860b"))
	cost_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_row.add_child(cost_value)

	var lock_label := Label.new()
	lock_label.text = "🔒"
	lock_label.visible = not owned
	lock_label.add_theme_font_size_override("font_size", 13)
	lock_label.add_theme_color_override("font_color", Color("#9fb3c4"))
	lock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_row.add_child(lock_label)

	var cost_spacer := Control.new()
	cost_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_row.add_child(cost_spacer)

	var state_label := Label.new()
	var state_style := UITheme.tag_style(Color("#e1f1fb"), 7, 1)
	state_label.add_theme_stylebox_override("normal", state_style)
	state_label.add_theme_font_size_override("font_size", 10)
	state_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_row.add_child(state_label)

	var widgets := {
		"button": card,
		"level": level_label,
		"bonds": bonds_box,
		"src": src_label,
		"state": state_label,
		"state_style": state_style,
		"locked": not owned,
	}
	_card_widgets[character_id] = widgets
	return card


## 武将卡副行「职业 · 定位」（概念 .sub）；定位词 = SQUAD_ROLE_WORDS，缺失回退百科打法词。
func _character_sub_text(character_data: CharacterData, owned: bool) -> String:
	var profession_name := character_data.profession.display_name \
			if character_data.profession != null else "未知职业"
	if not owned:
		return profession_name
	var character_id := str(character_data.character_id)
	var role: String = SQUAD_ROLE_WORDS.get(character_id, "")
	if role.is_empty():
		role = EncyclopediaPanelScript.CHARACTER_FLAVOR.get(character_id, "")
	return profession_name if role.is_empty() else "%s · %s" % [profession_name, role]


## 武将卡四态样式（概念 .scard：白底蓝灰描边圆角 14；选中金框 #ffcc00 + 米黄底 + 金晕）。
func _apply_card_styleboxes(card: Button, owned: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#ffffff")
	normal.border_color = Color("#d7e9f5")
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 11.0
	normal.content_margin_right = 11.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 0.0
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#f7fbfe")
	hover.border_color = Color("#9fd0ea")
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("#eef3f7")
	disabled.border_color = Color("#d5e0e8")
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color("#fffdf2")
	selected.border_color = Color("#ffcc00")
	selected.set_border_width_all(3)
	selected.set_corner_radius_all(14)
	selected.shadow_color = Color(1.0, 0.8, 0.0, 0.35)
	selected.shadow_size = 5
	selected.content_margin_left = 11.0
	selected.content_margin_right = 11.0
	selected.content_margin_top = 8.0
	selected.content_margin_bottom = 0.0
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("disabled", disabled)
	card.add_theme_stylebox_override("pressed", selected)
	card.add_theme_stylebox_override("hover_pressed", selected)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## 卡面羁绊 mini 标签（概念 .mini：激活绿 / 预览黄；随勾选实时刷新，B-020 口径）。
func _refresh_card_bonds(bonds_box: HBoxContainer, character_id: String) -> void:
	if not is_instance_valid(bonds_box):
		return
	for child in bonds_box.get_children():
		child.queue_free()
	var squad := _selected_ids.duplicate()
	if not squad.has(character_id):
		squad.append(character_id)
	for progress in GameFlow.get_bond_progress(squad):
		var bond := progress["bond"] as BondData
		if bond == null or not bond.member_ids.has(StringName(character_id)):
			continue
		var count := int(progress["count"])
		var total := int(progress["total"])
		var active := bool(progress["active"])
		var tag := Label.new()
		tag.text = "%s %d/%d" % [bond.display_name.left(2), count, total]
		tag.add_theme_stylebox_override("normal", UITheme.tag_style(
			UITheme.TAG_OK_BG if active else UITheme.TAG_OPEN_BG, 6, 1))
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color",
			UITheme.TAG_OK_FG if active else UITheme.TAG_OPEN_FG)
		bonds_box.add_child(tag)


# ---------------------------------------------------------------- 左：队伍遗物行

func _build_relic_area() -> Control:
	var zone := HBoxContainer.new()
	zone.add_theme_constant_override("separation", 8)
	zone.custom_minimum_size = Vector2(0, 52)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(88, 0)
	side.add_theme_constant_override("separation", 1)
	var side_title := Label.new()
	side_title.text = "队伍遗物"
	side_title.add_theme_font_override("font", UITheme.spaced_font(2))
	side_title.add_theme_font_size_override("font_size", 13)
	side_title.add_theme_color_override("font_color", Color("#33566f"))
	side.add_child(side_title)
	var side_hint := Label.new()
	side_hint.text = "悬停看详情\n移开即消失\n图标待美术"
	side_hint.add_theme_font_size_override("font_size", 9)
	side_hint.add_theme_color_override("font_color", Color("#a8bccb"))
	side_hint.add_theme_constant_override("line_spacing", 1)
	side.add_child(side_hint)
	zone.add_child(side)

	_relic_scroll = ScrollContainer.new()
	_relic_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_relic_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_relic_row = HBoxContainer.new()
	_relic_row.add_theme_constant_override("separation", 8)
	_relic_scroll.add_child(_relic_row)
	_style_h_scrollbar(_relic_scroll)
	zone.add_child(_relic_scroll)

	var profile := ProfileStore.get_profile()
	for relic_id in GameFlow.get_owned_relic_ids(profile):
		_relic_row.add_child(_make_relic_pill(relic_id))
	return zone


## 遗物 pill（概念 .rpill：紫晶渐变方块图标 + 名称 + 已选/可选徽标 +
## 右下角虚线圆悬停示意）；悬停浮层看详情、移开即消失（不占页面布局）。
## v0.37.19：不显示持有数量（多余），名称直排于图标右侧。
func _make_relic_pill(relic_id: String) -> Button:
	var relic := GameFlow.load_battle_relic_data(relic_id)
	if relic == null:
		return Button.new()
	var pill := Button.new()
	pill.focus_mode = Control.FOCUS_NONE
	pill.toggle_mode = true
	pill.custom_minimum_size = Vector2(150, 52)
	pill.add_theme_stylebox_override("normal", _pill_style(false))
	pill.add_theme_stylebox_override("hover", _pill_style(false, true))
	pill.add_theme_stylebox_override("pressed", _pill_style(true))
	pill.add_theme_stylebox_override("hover_pressed", _pill_style(true))
	pill.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	pill.toggled.connect(_on_relic_toggled.bind(relic_id))
	pill.mouse_entered.connect(_show_relic_tooltip.bind(relic_id))
	pill.mouse_exited.connect(_hide_relic_tooltip)

	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8.0
	content.offset_right = -8.0
	content.offset_top = 3.0
	content.offset_bottom = -3.0
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(content)

	content.add_child(UITheme.tile_label(relic.display_name.left(1), "purple", 46.0, 21))

	var name_label := Label.new()
	name_label.text = relic.display_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(name_label)

	var state_label := Label.new()
	var state_style := UITheme.tag_style(UITheme.TAG_OPEN_BG, 6, 1)
	state_label.add_theme_stylebox_override("normal", state_style)
	state_label.add_theme_font_size_override("font_size", 10)
	state_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(state_label)

	var hint_mark := HoverHintMark.new()
	hint_mark.custom_minimum_size = Vector2(16, 16)
	hint_mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_mark.offset_left = -18.0
	hint_mark.offset_top = -18.0
	hint_mark.offset_right = -2.0
	hint_mark.offset_bottom = -2.0
	hint_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(hint_mark)

	_pill_widgets[relic_id] = {
		"button": pill,
		"state": state_label,
		"state_style": state_style,
	}
	return pill


func _pill_style(selected: bool, hover: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = Color("#fffdf2")
		style.border_color = Color("#ffcc00")
		style.shadow_color = Color(1.0, 0.8, 0.0, 0.35)
		style.shadow_size = 4
	else:
		style.bg_color = Color("#ffffff") if not hover else Color("#f7fbfe")
		style.border_color = Color("#9fd0ea") if hover else Color("#d7e9f5")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


# ---------------------------------------------------------------- 右：队伍加成

## 右栏面板（v0.37.19 简化）：不再展示「总战力」折合大数字与来源明细，
## 只列 科技 / 羁绊 / 遗物 三行，每行直接一个合计加成数值（伤害加算，
## 含攻速时按倍率折入显示 ≈+N%）；空态灰字 +0%。口径注脚一行保留。
func _build_power_panel() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(254, 0)
	var style := UITheme.light_panel_style()
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 11.0
	style.content_margin_bottom = 9.0
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12.0
	box.offset_right = -12.0
	box.offset_top = 11.0
	box.offset_bottom = -9.0
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	box.add_child(head)
	var head_title := Label.new()
	head_title.text = "队伍加成"
	head_title.add_theme_font_override("font", UITheme.spaced_font(2))
	head_title.add_theme_font_size_override("font_size", 15)
	head_title.add_theme_color_override("font_color", Color("#14538a"))
	head.add_child(head_title)
	head.add_child(UITheme.tag_label("随编队实时计算", Color("#14538a"), Color("#e1f1fb"), 9))
	var head_dash := DashLine.new()
	head_dash.custom_minimum_size = Vector2(0, 2)
	head_dash.dash_color = Color("#d7e9f5")
	box.add_child(head_dash)

	# 三行加成（无明细、无来源标注）：中间区域垂直居中，行距拉开保持清爽。
	var groups := VBoxContainer.new()
	groups.size_flags_vertical = Control.SIZE_EXPAND_FILL
	groups.alignment = BoxContainer.ALIGNMENT_CENTER
	groups.add_theme_constant_override("separation", 16)
	box.add_child(groups)
	var tech_row := _make_power_row(Color("#2eaadc"), "科技")
	_tech_value_label = tech_row["value"] as Label
	groups.add_child(tech_row["row"] as Control)
	var bond_row := _make_power_row(Color("#26a86f"), "羁绊")
	_bond_value_label = bond_row["value"] as Label
	groups.add_child(bond_row["row"] as Control)
	var relic_row := _make_power_row(Color("#7e5fc4"), "遗物")
	_relic_value_label = relic_row["value"] as Label
	groups.add_child(relic_row["row"] as Control)

	var note := Label.new()
	note.text = "概算展示：伤害类加算 × 攻速倍率；基地生命 / 初始金币不计入。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color("#a8bccb"))
	note.add_theme_constant_override("line_spacing", 2)
	box.add_child(note)
	return panel


## 加成单行（色点 + 名称 + 右侧数值；数值控件由刷新逻辑改文本与颜色）。
func _make_power_row(dot_color: Color, title: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(9, 9)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = dot_color
	dot_style.set_corner_radius_all(4)
	dot.add_theme_stylebox_override("panel", dot_style)
	row.add_child(dot)
	var name := Label.new()
	name.text = title
	name.add_theme_font_override("font", UITheme.spaced_font(1))
	name.add_theme_font_size_override("font_size", 14)
	name.add_theme_color_override("font_color", Color("#33566f"))
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name)
	var value := Label.new()
	value.text = "+0%"
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color("#9fb3c4"))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return {"row": row, "value": value}


## 组值文本与配色：有加成金色（含攻速折入显示 ≈+N%），空态灰 +0%。
func _apply_power_value(value_label: Label, damage: int, speed: float) -> void:
	if damage <= 0 and speed <= 0.0:
		value_label.text = "+0%"
		value_label.add_theme_color_override("font_color", Color("#9fb3c4"))
		return
	var text := "+%d%%" % damage
	if speed > 0.0:
		var combined: float = round((1.0 + float(damage) / 100.0) * (1.0 + speed / 100.0) * 100.0 - 100.0)
		text = "≈+%d%%" % combined
	value_label.text = text
	value_label.add_theme_color_override("font_color", Color("#b8860b"))


# ---------------------------------------------------------------- 底部操作条

func _build_footer() -> HBoxContainer:
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	foot.custom_minimum_size = Vector2(0, 52)

	var back_button := Button.new()
	back_button.text = "返回选关"
	back_button.custom_minimum_size = Vector2(168, 52)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_size_override("font_size", 17)
	UITheme.apply_kenney_rect_button(back_button, "grey", UITheme.LIGHT_BODY)
	back_button.pressed.connect(func() -> void: GameFlow.goto_stage_select())
	foot.add_child(back_button)

	var note := Label.new()
	note.text = "返回保留所选关卡与难度 · 确认出战前弹出名单复核"
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color("#a8bccb"))
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(note)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)

	_start_button = Button.new()
	_start_button.text = "确认出战"
	_start_button.custom_minimum_size = Vector2(200, 52)
	_start_button.focus_mode = Control.FOCUS_NONE
	_start_button.add_theme_font_override("font", UITheme.spaced_font(2))
	_start_button.add_theme_font_size_override("font_size", 20)
	UITheme.apply_kenney_rect_button(_start_button, "yellow", UITheme.INK)
	_start_button.pressed.connect(_open_confirm_popup)
	foot.add_child(_start_button)
	return foot


# ---------------------------------------------------------------- 遗物悬停浮层

func _build_relic_tooltip() -> void:
	_relic_tooltip = PanelContainer.new()
	_relic_tooltip.top_level = true
	_relic_tooltip.visible = false
	_relic_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ffffff")
	style.border_color = Color("#ffcc00")
	style.set_border_width_all(3)
	style.set_corner_radius_all(13)
	style.shadow_color = Color(0.118, 0.235, 0.353, 0.25)
	style.shadow_size = 12
	style.content_margin_left = 11.0
	style.content_margin_right = 11.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 7.0
	_relic_tooltip.add_theme_stylebox_override("panel", style)
	_relic_tooltip_box = VBoxContainer.new()
	_relic_tooltip_box.add_theme_constant_override("separation", 4)
	_relic_tooltip.add_child(_relic_tooltip_box)
	add_child(_relic_tooltip)


func _show_relic_tooltip(relic_id: String) -> void:
	var relic := GameFlow.load_battle_relic_data(relic_id)
	var pill_widget: Dictionary = _pill_widgets.get(relic_id, {})
	var pill := pill_widget.get("button", null) as Button
	if relic == null or not is_instance_valid(pill):
		return
	for child in _relic_tooltip_box.get_children():
		child.queue_free()
	var selected := _selected_relic_ids.has(relic_id)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	_relic_tooltip_box.add_child(title_row)
	var name_label := Label.new()
	name_label.text = relic.display_name
	name_label.add_theme_font_override("font", UITheme.spaced_font(1))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	title_row.add_child(name_label)
	var status_tag := UITheme.tag_label("已选" if selected else "可选",
		UITheme.TAG_OPEN_FG if selected else Color("#14538a"),
		UITheme.TAG_OPEN_BG if selected else Color("#e1f1fb"), 10)
	title_row.add_child(status_tag)

	var desc := Label.new()
	desc.text = relic.description if not relic.description.is_empty() else "（暂无描述）"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(232, 0)
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color("#5f8aa6"))
	desc.add_theme_constant_override("line_spacing", 2)
	_relic_tooltip_box.add_child(desc)

	# 效果 chip 改自动换行文本块（定宽 232 不把浮层撑宽，去空白紧凑化）。
	var effect_label := Label.new()
	effect_label.text = _relic_effect_text(relic)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.custom_minimum_size = Vector2(232, 0)
	effect_label.add_theme_stylebox_override("normal",
		UITheme.tag_style(UITheme.TAG_OPEN_BG, 6, 1))
	effect_label.add_theme_font_size_override("font_size", 10)
	effect_label.add_theme_color_override("font_color", UITheme.TAG_OPEN_FG)
	effect_label.add_theme_constant_override("line_spacing", 1)
	_relic_tooltip_box.add_child(effect_label)

	var meta := Label.new()
	meta.text = "队伍级 · 永久使用 · 不消耗库存"
	meta.add_theme_font_size_override("font_size", 9)
	meta.add_theme_color_override("font_color", Color("#a8bccb"))
	_relic_tooltip_box.add_child(meta)

	_relic_tooltip.reset_size()
	var size := _relic_tooltip.size
	var target := pill.get_global_rect()
	var viewport := get_viewport().get_visible_rect()
	var pos_x := clampf(target.get_center().x - size.x * 0.5, 4.0, viewport.size.x - size.x - 4.0)
	var pos_y := target.position.y - size.y - 10.0
	if pos_y < 4.0:
		pos_y = target.end.y + 10.0
	_relic_tooltip.position = Vector2(pos_x, pos_y)
	_relic_tooltip.visible = true


func _hide_relic_tooltip() -> void:
	if _relic_tooltip != null:
		_relic_tooltip.visible = false


## 遗物效果文案（概念 .cf-relic .rfx / pill 效果 chip；与字段一一对应）。
func _relic_effect_text(relic: BattleRelicData) -> String:
	var parts: Array[String] = []
	if relic.damage_bonus_pct > 0:
		parts.append("全伤害 +%d%%" % relic.damage_bonus_pct)
	if not is_equal_approx(relic.attack_interval_factor, 1.0):
		parts.append("攻速 ×%.2f" % relic.attack_interval_factor)
	if relic.range_bonus_pct > 0:
		parts.append("射程 +%d%%" % relic.range_bonus_pct)
	if relic.start_gold > 0:
		parts.append("初始金币 +%d" % relic.start_gold)
	if relic.base_hp_bonus > 0:
		parts.append("基地生命 +%d" % relic.base_hp_bonus)
	return " · ".join(parts) if not parts.is_empty() else "效果配置缺失"


# ---------------------------------------------------------------- 交互

func _on_character_toggled(pressed: bool, character_id: String) -> void:
	if pressed:
		if not _selected_ids.has(character_id) and _selected_ids.size() < _squad_cap():
			_selected_ids.append(character_id)
	else:
		_selected_ids.erase(character_id)
	_sync_all()
	_refresh()


func _on_relic_toggled(pressed: bool, relic_id: String) -> void:
	if pressed:
		if _selected_relic_ids.has(relic_id):
			return
		if _selected_relic_ids.size() >= RELIC_CAP:
			# 已满 2 件：回弹并保持原状态（超出禁选，v0.33.1 语义）。
			var pill_widget: Dictionary = _pill_widgets.get(relic_id, {})
			var pill := pill_widget.get("button", null) as Button
			if pill != null:
				pill.set_pressed_no_signal(false)
			return
		_selected_relic_ids.append(relic_id)
	else:
		_selected_relic_ids.erase(relic_id)
	_sync_all()
	_refresh()


func _sync_all() -> void:
	for character_id in _card_widgets.keys():
		_sync_character_card(str(character_id))
	for relic_id in _pill_widgets.keys():
		_sync_relic_pill(str(relic_id))


func _sync_character_card(character_id: String) -> void:
	var widgets: Dictionary = _card_widgets.get(character_id, {})
	var card := widgets.get("button", null) as Button
	if not is_instance_valid(card):
		return
	var locked := bool(widgets.get("locked", false))
	var selected := _selected_ids.has(character_id)
	card.set_pressed_no_signal(selected)
	if locked:
		card.disabled = true
		card.modulate = Color.WHITE
		return
	var cap_full := _selected_ids.size() >= _squad_cap() and not selected
	card.disabled = cap_full
	card.modulate = Color(1, 1, 1, 0.55) if cap_full else Color.WHITE


func _sync_relic_pill(relic_id: String) -> void:
	var widgets: Dictionary = _pill_widgets.get(relic_id, {})
	var pill := widgets.get("button", null) as Button
	var state_label := widgets.get("state", null) as Label
	var state_style := widgets.get("state_style", null) as StyleBoxFlat
	if not is_instance_valid(pill) or not is_instance_valid(state_label) or state_style == null:
		return
	var selected := _selected_relic_ids.has(relic_id)
	pill.set_pressed_no_signal(selected)
	var cap_full := _selected_relic_ids.size() >= RELIC_CAP and not selected
	if selected:
		state_label.text = "已选"
		state_style.bg_color = UITheme.TAG_OPEN_BG
		state_label.add_theme_color_override("font_color", UITheme.TAG_OPEN_FG)
	else:
		state_label.text = "可选"
		state_style.bg_color = Color("#e1f1fb")
		state_label.add_theme_color_override("font_color", Color("#14538a"))
	pill.modulate = Color(1, 1, 1, 0.55) if cap_full else Color.WHITE


## 全量刷新（勾选变化后调用）：标题/区计数、卡面文本与状态、遗物 pill、右侧战力面板。
func _refresh() -> void:
	_refresh_header_counts()
	_refresh_card_texts()
	_refresh_power_panel()
	if _start_button != null:
		_start_button.disabled = _selected_ids.is_empty()


func _refresh_header_counts() -> void:
	var cap := _squad_cap()
	if _title_progress_label != null:
		_title_progress_label.text = "出战 %d / %d" % [_selected_ids.size(), cap]
	if _zone_progress_label != null:
		var owned := 0
		for character_data in _roster:
			if _is_owned(str(character_data.character_id)):
				owned += 1
		_zone_progress_label.text = "已拥有 %d · 未解锁 %d" % [owned, _roster.size() - owned]


func _refresh_card_texts() -> void:
	for character_id in _card_widgets.keys():
		var widgets: Dictionary = _card_widgets.get(str(character_id), {})
		var card := widgets.get("button", null) as Button
		if not is_instance_valid(card):
			continue
		var level_label := widgets.get("level", null) as Label
		var src_label := widgets.get("src", null) as Label
		var locked := bool(widgets.get("locked", false))
		var selected := _selected_ids.has(str(character_id))
		if level_label != null:
			level_label.visible = not locked
			if not locked:
				level_label.text = "Lv%d" % GameFlow.get_character_level(
					ProfileStore.get_profile(), str(character_id))
		if src_label != null:
			src_label.visible = locked
		_refresh_card_bonds(widgets.get("bonds", null) as HBoxContainer, str(character_id))
		var state_label := widgets.get("state", null) as Label
		var state_style := widgets.get("state_style", null) as StyleBoxFlat
		if is_instance_valid(state_label) and state_style != null:
			if locked:
				state_label.text = "未解锁"
				state_style.bg_color = Color("#d9e4ec")
				state_label.add_theme_color_override("font_color", Color("#7d8fa0"))
			elif selected:
				state_label.text = "出战"
				state_style.bg_color = UITheme.TAG_OK_BG
				state_label.add_theme_color_override("font_color", UITheme.TAG_OK_FG)
			else:
				state_label.text = "可上阵"
				state_style.bg_color = Color("#e1f1fb")
				state_label.add_theme_color_override("font_color", Color("#14538a"))


# ---------------------------------------------------------------- 队伍加成刷新

## 口径（UI_LAYOUT §7，v0.37.19 简化）：只展示 科技 / 羁绊 / 遗物 三个合计数值
## ——伤害类加算（科技全局+出战职业分支 / 激活羁绊 / 已选遗物），攻速类（科技
## 职业攻速 / 遗物 ×(1/interval)）按倍率折入显示 ≈+N%；基地生命/初始金币不计。
## 数据与战斗同源，仅展示概算，不做编队桶 clamp；不列来源明细。
func _refresh_power_panel() -> void:
	if _tech_value_label == null or _bond_value_label == null or _relic_value_label == null:
		return
	var profile := ProfileStore.get_profile()

	# ① 科技：军略全局伤害 + 出战职业分支（伤害加算；职业攻速折入）。
	var tech_damage := 0
	var tech_speed := 0.0
	var unlocked_sources := _unlocked_tech_sources(profile)
	for item in TechTree.get_items():
		if profile.has_tech(item.id):
			tech_damage += int(item.effect.get("damage_pct", 0))
	for character_data in _selected_character_datas():
		var profession := character_data.profession
		if profession == null:
			continue
		var profession_id := str(profession.profession_id)
		tech_damage += int(unlocked_sources.get("profession_%s_damage_pct" % profession_id, 0))
		tech_speed += float(unlocked_sources.get("profession_%s_attack_speed_pct" % profession_id, 0))
	_apply_power_value(_tech_value_label, tech_damage, tech_speed)

	# ② 羁绊：已激活组合的同队攻击加成合计（未满员不计入）。
	var bond_damage := 0.0
	for progress in GameFlow.get_bond_progress(_selected_ids):
		var bond := progress["bond"] as BondData
		if bond != null and bool(progress["active"]):
			bond_damage += bond.damage_bonus
	_apply_power_value(_bond_value_label, int(round(bond_damage * 100.0)), 0.0)

	# ③ 遗物：仅已选带计入（伤害加算；攻速倍率折入）。
	var relic_damage := 0
	var relic_speed := 0.0
	for relic_id in _selected_relic_ids:
		var relic := GameFlow.load_battle_relic_data(str(relic_id))
		if relic == null:
			continue
		relic_damage += relic.damage_bonus_pct
		if not is_equal_approx(relic.attack_interval_factor, 1.0):
			relic_speed += (1.0 / relic.attack_interval_factor - 1.0) * 100.0
	_apply_power_value(_relic_value_label, relic_damage, relic_speed)


func _selected_character_datas() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for character_id in _selected_ids:
		var character_data := GameFlow.load_character_data(str(character_id))
		if character_data != null:
			result.append(character_data)
	return result


## 已解锁科技效果汇总（TechTree.get_tech_bonuses 同源，仅按条目拆来源名展示）。
func _unlocked_tech_sources(profile: PlayerProfile) -> Dictionary:
	var result := {}
	for item in TechTree.get_items():
		if not profile.has_tech(item.id):
			continue
		var effect: Dictionary = item.effect
		for key in effect.keys():
			result[str(key)] = int(result.get(str(key), 0)) + int(effect[key])
	return result


# ---------------------------------------------------------------- 二次确认弹窗

func _open_confirm_popup() -> void:
	if _selected_ids.is_empty() or _confirm_popup != null:
		return
	var overlay := Control.new()
	overlay.name = "DeployConfirm"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_popup = overlay

	var dim := ColorRect.new()
	dim.color = Color(0.039, 0.149, 0.251, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(640, 560)
	panel.clip_contents = true
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UITheme.DIALOG_PANEL
	panel_style.border_color = UITheme.DIALOG_BORDER
	panel_style.set_border_width_all(3)
	panel_style.border_width_bottom = 7
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.024, 0.11, 0.196, 0.5)
	panel_style.shadow_size = 18
	panel_style.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(panel)
	_panel_center(panel)
	panel.add_child(_build_confirm_header())
	panel.add_child(_build_confirm_body())
	var footer := _build_confirm_footer()
	panel.add_child(footer)

	add_child(overlay)
	var confirm_button := footer.get_node_or_null("ConfirmButton") as Button
	if confirm_button != null:
		confirm_button.call_deferred("grab_focus")


func _panel_center(panel: Control) -> void:
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH


## 弹窗蓝标题条（概念 .cf-title）：白字标题 + 章节 chip + 圆形 ✕。
func _build_confirm_header() -> Panel:
	var header := Panel.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 3.0
	header.offset_right = -3.0
	header.offset_top = 3.0
	header.offset_bottom = 57.0
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = UITheme.DIALOG_HEAD
	header_style.corner_radius_top_left = 15
	header_style.corner_radius_top_right = 15
	header.add_theme_stylebox_override("panel", header_style)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24.0
	row.offset_right = -10.0
	row.add_theme_constant_override("separation", 12)
	header.add_child(row)

	var title := Label.new()
	title.text = "确认出战"
	title.add_theme_font_override("font", UITheme.spaced_font(6))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color("#0e5f92"))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	var chapter_chip := Label.new()
	chapter_chip.text = _chapter_label()
	chapter_chip.add_theme_stylebox_override("normal", UITheme.tag_style(Color(1, 1, 1, 0.22), 12, 3))
	chapter_chip.add_theme_font_size_override("font_size", 12)
	chapter_chip.add_theme_color_override("font_color", Color("#eaf6ff"))
	chapter_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chapter_chip)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.tooltip_text = "关闭"
	close_button.icon = load("res://assets/ui/icons/cross_blue.png")
	close_button.add_theme_constant_override("icon_max_width", 18)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(1, 1, 1, 0.28)
	close_style.set_corner_radius_all(16)
	var close_pressed := StyleBoxFlat.new()
	close_pressed.bg_color = Color(1, 1, 1, 0.45)
	close_pressed.set_corner_radius_all(16)
	close_button.add_theme_stylebox_override("normal", close_style)
	close_button.add_theme_stylebox_override("hover", close_style)
	close_button.add_theme_stylebox_override("pressed", close_pressed)
	close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_button.pressed.connect(_close_confirm_popup)
	row.add_child(close_button)
	return header


func _build_confirm_body() -> Control:
	var body := MarginContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 24.0
	body.offset_right = -24.0
	body.offset_top = 66.0
	body.offset_bottom = -88.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	body.add_child(box)

	# 元数据行（概念 .cf-meta）：关名蓝 tag / 难度 tag / 出战计数。
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	box.add_child(meta)
	meta.add_child(UITheme.tag_label(_stage_tag_text(), Color("#14538a"), Color("#e1f1fb"), 12))
	meta.add_child(UITheme.tag_label("难度 · %s" % Difficulty.name(GameFlow.selected_difficulty),
		UITheme.TAG_OPEN_FG, UITheme.TAG_OPEN_BG, 12))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(spacer)
	meta.add_child(UITheme.tag_label("出战 %d / %d" % [_selected_ids.size(), _squad_cap()],
		Color("#33566f"), Color("#e1f1fb"), 12))

	box.add_child(_confirm_section_title("出战武将"))
	box.add_child(_confirm_character_list())
	box.add_child(_confirm_section_title("队伍遗物 · 永久使用不消耗库存"))
	box.add_child(_confirm_relic_row())

	var tip := DashedPill.new()
	tip.setup(Color("#eef6fb"), Color("#bfdcef"), 10.0)
	var tip_margin := MarginContainer.new()
	tip_margin.add_theme_constant_override("margin_left", 12)
	tip_margin.add_theme_constant_override("margin_right", 12)
	tip_margin.add_theme_constant_override("margin_top", 6)
	tip_margin.add_theme_constant_override("margin_bottom", 6)
	tip.add_child(tip_margin)
	var tip_label := Label.new()
	tip_label.text = "确认后立即进入战斗；出战武将与本局遗物即刻生效，遗物永久使用、不消耗库存；取消 / 关闭可返回编队继续调整。"
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.add_theme_font_size_override("font_size", 12)
	tip_label.add_theme_color_override("font_color", Color("#33566f"))
	tip_label.add_theme_constant_override("line_spacing", 3)
	tip_margin.add_child(tip_label)
	box.add_child(tip)
	return body


func _stage_tag_text() -> String:
	if _stage_data == null:
		return "未选择关卡"
	return "s%02d %s" % [_stage_data.stage_number, _stage_data.display_name]


func _confirm_section_title(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#7d9cb4"))
	label.add_theme_font_override("font", UITheme.spaced_font(2))
	row.add_child(label)
	var line := DashLine.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.dash_color = Color("#dcecf6")
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


## 出战武将名单（概念 .cf-list）：最多约 4 行可见，更多行纵向滚动；行间细虚线分隔。
func _confirm_character_list() -> Control:
	var list_holder := Control.new()
	var row_height := 46.0
	list_holder.custom_minimum_size = Vector2(0,
		minf(_selected_ids.size() * row_height - 1.0, row_height * 4.0 - 1.0))
	var list_scroll := ScrollContainer.new()
	list_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_v_scrollbar(list_scroll)
	list_holder.add_child(list_scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 0)
	list_scroll.add_child(rows)

	var profile := ProfileStore.get_profile()
	var deploy_index := 1
	for character_id in _selected_ids:
		var character_data := GameFlow.load_character_data(str(character_id))
		if character_data != null:
			rows.add_child(_confirm_character_row(character_data, profile, deploy_index))
			deploy_index += 1
		if deploy_index <= _selected_ids.size():
			var divider := DashLine.new()
			divider.custom_minimum_size = Vector2(0, 1)
			divider.dash_color = Color("#dbeaf4")
			rows.add_child(divider)
	return list_holder


func _confirm_character_row(character_data: CharacterData, profile: PlayerProfile,
		deploy_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 45)
	row.add_theme_constant_override("separation", 10)
	var avatar := UITheme.avatar_label(character_data.display_name.left(1),
		UITheme.character_avatar_color_key(str(character_data.character_id)), 38.0, 17)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar)
	var name_label := Label.new()
	name_label.text = character_data.display_name
	name_label.add_theme_font_override("font", UITheme.spaced_font(1))
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var sub_label := Label.new()
	sub_label.text = _character_sub_text(character_data, true)
	sub_label.add_theme_font_size_override("font_size", 12)
	sub_label.add_theme_color_override("font_color", Color("#6b93ad"))
	sub_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sub_label)
	var level_label := Label.new()
	level_label.text = "Lv%d" % GameFlow.get_character_level(profile, str(character_data.character_id))
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color("#2eaadc"))
	level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(level_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var pos_tag := UITheme.tag_label("出战 %d" % deploy_index, UITheme.TAG_OK_FG, UITheme.TAG_OK_BG, 11)
	pos_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pos_tag)
	return row


## 队伍遗物清单（概念 .cf-relic；v0.37.19 简化）：图标占位 + 名称，
## 不显示效果与持有数；未选带显示灰字占位。
func _confirm_relic_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if _selected_relic_ids.is_empty():
		var empty := Label.new()
		empty.text = "未选带遗物（本局无遗物加成）"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color("#a8bccb"))
		row.add_child(empty)
		return row
	for relic_id in _selected_relic_ids:
		var relic := GameFlow.load_battle_relic_data(str(relic_id))
		if relic == null:
			continue
		var card := Panel.new()
		card.custom_minimum_size = Vector2(150, 52)
		var style := UITheme.light_card_style()
		style.set_border_width_all(2)
		card.add_theme_stylebox_override("panel", style)
		var content := HBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 10.0
		content.offset_right = -10.0
		content.offset_top = 5.0
		content.offset_bottom = -5.0
		content.add_theme_constant_override("separation", 8)
		card.add_child(content)
		content.add_child(UITheme.tile_label(relic.display_name.left(1), "purple", 42.0, 19))
		var name_label := Label.new()
		name_label.text = relic.display_name
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(name_label)
		row.add_child(card)
	return row


func _build_confirm_footer() -> HBoxContainer:
	var foot := HBoxContainer.new()
	foot.anchor_left = 0.0
	foot.anchor_right = 1.0
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 24.0
	foot.offset_right = -24.0
	foot.offset_top = -74.0
	foot.offset_bottom = -18.0
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 12)

	var hint := Label.new()
	hint.text = "本局配置在确认后写入存档记忆，下次出征自动预填"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("#a8bccb"))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	foot.add_child(hint)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.custom_minimum_size = Vector2(150, 44)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.add_theme_font_size_override("font_size", 17)
	UITheme.apply_kenney_rect_button(cancel_button, "grey", UITheme.LIGHT_BODY)
	cancel_button.pressed.connect(_close_confirm_popup)
	foot.add_child(cancel_button)

	var confirm_button := Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = "确认出战"
	confirm_button.custom_minimum_size = Vector2(176, 44)
	confirm_button.add_theme_font_override("font", UITheme.spaced_font(2))
	confirm_button.add_theme_font_size_override("font_size", 17)
	UITheme.apply_kenney_rect_button(confirm_button, "yellow", UITheme.INK)
	confirm_button.pressed.connect(_on_confirm_deploy)
	foot.add_child(confirm_button)
	return foot


func _close_confirm_popup() -> void:
	if _confirm_popup != null and is_instance_valid(_confirm_popup):
		_confirm_popup.queue_free()
	_confirm_popup = null


func _on_confirm_deploy() -> void:
	if _selected_ids.is_empty():
		return
	GameFlow.set_squad(_selected_ids)
	GameFlow.set_squad_relics(_selected_relic_ids)
	var profile := ProfileStore.get_profile()
	GameFlow.save_squad_to_profile(profile)
	GameFlow.save_squad_relics_to_profile(profile)
	ProfileStore.save_profile(profile)
	GameFlow.goto_battle()


## ESC 关闭确认弹窗（原生 ConfirmationDialog 取消语义保留）。
func _unhandled_input(event: InputEvent) -> void:
	if _confirm_popup != null and is_instance_valid(_confirm_popup) \
			and event.is_action_pressed("ui_cancel"):
		_close_confirm_popup()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- 滚动条样式（同 MapPanel）

func _style_v_scrollbar(scroll: ScrollContainer) -> void:
	var vbar := scroll.get_v_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = UITheme.LIGHT_PANEL_SPLIT
	track.set_corner_radius_all(5)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("#7ec8ea")
	grabber.set_corner_radius_all(5)
	var grabber_hot := StyleBoxFlat.new()
	grabber_hot.bg_color = UITheme.LIGHT_ACCENT
	grabber_hot.set_corner_radius_all(5)
	vbar.add_theme_stylebox_override("scroll", track)
	vbar.add_theme_stylebox_override("grabber", grabber)
	vbar.add_theme_stylebox_override("grabber_highlight", grabber_hot)
	vbar.add_theme_stylebox_override("grabber_pressed", grabber_hot)
	vbar.custom_minimum_size = Vector2(10, 0)


func _style_h_scrollbar(scroll: ScrollContainer) -> void:
	var hbar := scroll.get_h_scroll_bar()
	var track := StyleBoxFlat.new()
	track.bg_color = UITheme.LIGHT_PANEL_SPLIT
	track.set_corner_radius_all(5)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("#7ec8ea")
	grabber.set_corner_radius_all(5)
	var grabber_hot := StyleBoxFlat.new()
	grabber_hot.bg_color = UITheme.LIGHT_ACCENT
	grabber_hot.set_corner_radius_all(5)
	hbar.add_theme_stylebox_override("scroll", track)
	hbar.add_theme_stylebox_override("grabber", grabber)
	hbar.add_theme_stylebox_override("grabber_highlight", grabber_hot)
	hbar.add_theme_stylebox_override("grabber_pressed", grabber_hot)
	hbar.custom_minimum_size = Vector2(0, 10)
