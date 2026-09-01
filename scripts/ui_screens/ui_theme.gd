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
