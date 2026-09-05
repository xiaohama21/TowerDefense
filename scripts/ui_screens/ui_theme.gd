extends RefCounted

## 全局语义色板（UI_LAYOUT.md 第 2 节，阶段 8 提交 4 统一）：
## 金=强调/关键资源，绿=成功/达标，红=警示/不足，蓝=信息/数值，灰=次级文字。
## 所有面板引用本常量；禁止面板私有颜色魔数（删除各面板 TITLE/OK/BAD 等重复定义）。

class_name UITheme

const GOLD := Color(0.92, 0.78, 0.42)
const GREEN := Color(0.55, 0.92, 0.80)
const RED := Color(0.90, 0.45, 0.40)
const BLUE := Color(0.65, 0.84, 1.00)
const GRAY := Color(0.70, 0.72, 0.68)
const BG := Color(0.06, 0.09, 0.08)
const SIDEBAR := Color(0.09, 0.13, 0.11)
const TEXT := Color(0.88, 0.9, 0.84)
const DISABLED := Color(0.55, 0.57, 0.53)
const SELECT_BG := Color(1.0, 0.82, 0.3)
const SELECT_BORDER := Color(1.0, 0.92, 0.62)
const SELECT_TEXT := Color(0.12, 0.09, 0.02)
const SIDEBAR_BORDER := Color(0.25, 0.43, 0.38, 0.8)
const PANEL_BG := Color(0.11, 0.15, 0.13)

## Kenney 亮色视觉令牌（UI_LAYOUT §3，v0.33.6 主菜单换肤首屏落地）：
## 首页背景/文字/弹窗主色统一入口，其余面板换肤时复用。
const SKY_TOP := Color("#46afe6")
const SKY_MID := Color("#3399da")
const SKY_BOTTOM := Color("#277fb9")
const INK := Color("#22384a")      # 黄/灰按钮深蓝墨字
const MIST := Color("#eaf6ff")     # 标题副标/底栏白蓝字
const PALE := Color("#cfe7f7")     # 底栏素材署名
const STROKE := Color("#14538a")   # 亮底白字深蓝投影
const DIALOG_PANEL := Color("#f2faff")
const DIALOG_BORDER := Color("#1c9fd7")
const DIALOG_HEAD := Color("#38a8dd")
const DIALOG_TEXT := Color("#1b4d78")
const DIALOG_WARN := Color("#d71935")
const DIALOG_HINT := Color("#7d9cb4")



## 选中态样式（金色底 + 金色边框 + 深色文字，v0.19.2 惯例统一封装）。
static func apply_selected_style(button: Button) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = SELECT_BG
	style.border_color = SELECT_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover_pressed", style)
	button.add_theme_color_override("font_pressed_color", SELECT_TEXT)
	button.add_theme_color_override("font_hover_pressed_color", SELECT_TEXT)


## 卡片样式：状态色边框 + 圆角；选中时叠加金色底。
static func apply_card_style(button: Button, state_color: Color, selected: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = PANEL_BG
	normal.border_color = state_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0
	var hover := StyleBoxFlat.new()
	hover.bg_color = state_color.darkened(0.35)
	hover.border_color = state_color
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(8)
	hover.content_margin_left = 12.0
	hover.content_margin_right = 12.0
	hover.content_margin_top = 10.0
	hover.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", state_color)
	button.add_theme_color_override("font_hover_color", state_color)
	button.add_theme_color_override("font_disabled_color", DISABLED)
	if selected:
		apply_selected_style(button)

## Kenney 九宫格按钮换肤（UI_LAYOUT §3 / ART_ASSETS v0.2，v0.33.6 首页落地）：
## 素材 assets/ui/buttons/rect/<color_key>/{normal,hover,pressed}.png（原图 384×128，裁边 24）。
static func apply_kenney_rect_button(button: Button, color_key: String, font_color: Color) -> void:
	var pressed_style: StyleBoxTexture = null
	for state_name in ["normal", "hover", "pressed"]:
		var style := StyleBoxTexture.new()
		style.texture = load("res://assets/ui/buttons/rect/%s/%s.png" % [color_key, state_name])
		style.texture_margin_left = 24.0
		style.texture_margin_top = 24.0
		style.texture_margin_right = 24.0
		style.texture_margin_bottom = 24.0
		style.set_content_margin_all(12.0)
		button.add_theme_stylebox_override(state_name, style)
		if state_name == "pressed":
			pressed_style = style
	button.add_theme_stylebox_override("hover_pressed", pressed_style)
	var disabled_style: StyleBoxTexture = pressed_style.duplicate()
	disabled_style.texture = load("res://assets/ui/buttons/rect/grey/normal.png")
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color.darkened(0.15))
	button.add_theme_color_override("font_hover_pressed_color", font_color.darkened(0.15))
	button.add_theme_color_override("font_disabled_color", DISABLED)


## 共享字距字体（v0.19.0，首页私有实现收敛）：在全局主题字体（站酷快乐体 +
## 系统回退）上叠加字距，标题/按钮共用。
static func spaced_font(spacing: int) -> Font:
	var theme := load("res://assets/ui/ui_theme.tres") as Theme
	var variation := FontVariation.new()
	variation.base_font = theme.default_font
	variation.set_spacing(TextServer.SPACING_GLYPH, spacing)
	return variation


## ===== Kenney 亮色大厅主题（v0.19.0，六屏换肤共享；色源 = 概念图共享样式
## docs/ui_concept/src/concept_ui.css + src/ui_hub_map.html）=====

const LIGHT_PAGE_BG := Color("#f2faff")     # 大面板底
const LIGHT_PANEL_BORDER := Color("#d7e9f5")  # 白面板/卡片描边
const LIGHT_PANEL_SPLIT := Color("#e8f2f9")   # 面板内分隔线/滚动槽
const LIGHT_CARD_BG := Color("#f7fbfe")     # 内嵌卡片底
const LIGHT_STAT_BG := Color("#f3f9fd")     # 统计胶囊底
const LIGHT_BLUE_SOFT := Color("#e1f1fb")   # 蓝色 chip 底
const LIGHT_BLUE_SELECT := Color("#e6f4fd")  # 页签选中底
const LIGHT_BORDER_SOFT := Color("#9fd0ea")  # 亮蓝描边（页签/下拉）
const LIGHT_ACCENT := Color("#2eaadc")      # 亮蓝强调（数值/图标）
const LIGHT_GOLD_TEXT := Color("#b8860b")   # 金色数值文字
const LIGHT_GOLD_SELECT := Color("#ffcc00")  # 选中金框
const LIGHT_INK := Color("#1b4d78")         # 标题/主文字
const LIGHT_BODY := Color("#33566f")        # 次级文字/灰按钮字
const LIGHT_MUTED := Color("#7d9cb4")       # 弱文字
const LIGHT_DESC := Color("#6b93ad")        # 简介文字
const LIGHT_LOCK := Color("#9fb3c4")        # 锁定文字
const TAG_OK_FG := Color("#11804a")
const TAG_OK_BG := Color("#d8f2e3")
const TAG_OPEN_FG := Color("#8a6d00")
const TAG_OPEN_BG := Color("#fff3c4")
const TAG_LOCK_FG := Color("#7d8fa0")
const TAG_LOCK_BG := Color("#d9e4ec")
const TAG_FIRE_FG := Color("#c0392b")
const TAG_FIRE_BG := Color("#ffe6e1")

## 白底面板样式（概念图 .panel：白底 + 蓝灰描边 + 圆角 14 + 轻投影）。
static func light_panel_style(bg: Color = Color.WHITE, border: Color = LIGHT_PANEL_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.118, 0.353, 0.51, 0.08)
	style.shadow_size = 6
	return style


## 内嵌浅蓝卡片样式（概念图 .pnode/.rcard/.skcard：浅底 + 细描边 + 圆角 12）。
static func light_card_style(bg: Color = LIGHT_CARD_BG, border: Color = LIGHT_PANEL_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style


## 标签/徽章（概念图 .tag：圆角 8 小色块）。
static func tag_label(text: String, fg: Color, bg: Color, font_size: int = 12) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", fg)
	label.add_theme_stylebox_override("normal", tag_style(bg, 9, 2))
	return label


static func tag_style(bg: Color, margin_h: float = 9.0, margin_v: float = 2.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(8)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style


## 圆形头像占位（概念图 .ava：渐变圆 + 姓氏首字白字）。
static func avatar_label(text: String, color_key: String = "blue", diameter: float = 44.0, font_size: int = 21) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(diameter, diameter)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	var top: Color = LIGHT_ACCENT
	var bottom: Color = Color("#1c8fc0")
	match color_key:
		"grey": top = Color("#c3d3de"); bottom = Color("#9db4c4")
		"gold": top = Color("#ffd75e"); bottom = Color("#f0a92f")
		"green": top = Color("#5fd6a2"); bottom = Color("#26a86f")
		"purple": top = Color("#b393e8"); bottom = Color("#7e5fc4")
		"orange": top = Color("#ffb066"); bottom = Color("#f0802f")
		"red": top = Color("#ff8d7a"); bottom = Color("#e85b43")
		"blue": top = Color("#7ec8ea"); bottom = Color("#2eaadc")
	style.bg_color = top.lerp(bottom, 0.5)
	style.set_corner_radius_all(diameter * 0.5)
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	label.add_theme_stylebox_override("normal", style)
	return label


## 浅色可点选卡片按钮四态（正常浅蓝卡 / 悬停亮蓝描边 / 禁用灰 / 选中金框米黄底）。
static func apply_light_selectable(button: Button, locked: bool = false) -> void:
	var normal := light_card_style()
	var hover := light_card_style(LIGHT_CARD_BG, LIGHT_BORDER_SOFT)
	var disabled := light_card_style(Color("#eef3f7"), Color("#d5e0e8"))
	var selected := light_card_style(Color("#fffdf2"), LIGHT_GOLD_SELECT)
	selected.set_border_width_all(3)
	selected.shadow_color = Color(1.0, 0.8, 0.0, 0.35)
	selected.shadow_size = 5
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", LIGHT_LOCK if locked else LIGHT_INK)
	button.add_theme_color_override("font_hover_color", LIGHT_LOCK if locked else LIGHT_INK)
	button.add_theme_color_override("font_pressed_color", LIGHT_INK)
	button.add_theme_color_override("font_hover_pressed_color", LIGHT_INK)
	button.add_theme_color_override("font_disabled_color", LIGHT_LOCK)


## TabContainer 浅色页签样式（概念图 .tabs：圆角顶页签 + 蓝边内容面板）。
static func apply_light_tab_container(container: TabContainer) -> void:
	var tab_panel := light_panel_style()
	tab_panel.set_border_width_all(2)
	tab_panel.border_color = LIGHT_BORDER_SOFT
	container.add_theme_stylebox_override("panel", tab_panel)
	var tab_selected := StyleBoxFlat.new()
	tab_selected.bg_color = LIGHT_BLUE_SELECT
	tab_selected.border_color = LIGHT_BORDER_SOFT
	tab_selected.border_width_left = 2
	tab_selected.border_width_right = 2
	tab_selected.border_width_top = 2
	tab_selected.corner_radius_top_left = 10
	tab_selected.corner_radius_top_right = 10
	tab_selected.content_margin_left = 18.0
	tab_selected.content_margin_right = 18.0
	tab_selected.content_margin_top = 6.0
	tab_selected.content_margin_bottom = 6.0
	var tab_unselected: StyleBoxFlat = tab_selected.duplicate()
	tab_unselected.bg_color = LIGHT_PANEL_SPLIT
	tab_unselected.border_color = LIGHT_PANEL_BORDER
	container.add_theme_stylebox_override("tab_selected", tab_selected)
	container.add_theme_stylebox_override("tab_unselected", tab_unselected)
	container.add_theme_stylebox_override("tab_hovered", tab_selected)
	container.add_theme_color_override("font_selected_color", LIGHT_INK)
	container.add_theme_color_override("font_unselected_color", LIGHT_LOCK)
	container.add_theme_font_size_override("font_size", 16)


## 经验条浅色样式（概念图 .expbar：浅蓝槽 + 绿色填充）。
static func style_exp_bar(bar: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#e3eef6")
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#2fb47b")
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)

