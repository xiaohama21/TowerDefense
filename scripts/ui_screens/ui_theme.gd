extends RefCounted

## 全局语义色板（UI_LAYOUT.md 第 2 节，阶段 8 提交 4 统一）：
## 木金=关键动作/资源，青绿=主动作/成功/信息，陶红=警示，灰橄榄=次级状态。
## 所有面板引用本常量；禁止面板私有颜色魔数（删除各面板 TITLE/OK/BAD 等重复定义）。

class_name UITheme

static func button_focus_style(radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = LIGHT_GOLD_SELECT
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

## 兼容既有调用签名；所有动作使用同源营地材质。
static func _action_fill(color_key: String) -> Color:
	match color_key:
		"blue", "green", "teal": return LIGHT_ACCENT
		"yellow", "gold": return Color("#e9c574")
		"red": return TAG_FIRE_FG
	return LIGHT_CARD_BG

static func _action_text(color_key: String) -> Color:
	return LIGHT_PAGE_BG if color_key in ["blue", "green", "teal", "red"] else LIGHT_INK

static func _camp_action_style(color_key: String, state: String, radius: int, margin: float) -> StyleBoxFlat:
	var fill := _action_fill(color_key)
	var edge := LIGHT_BORDER_SOFT
	var style := StyleBoxFlat.new()
	if state == "hover":
		fill = fill.lightened(0.13)
		edge = LIGHT_GOLD_SELECT
	elif state in ["pressed", "hover_pressed"]:
		fill = fill.darkened(0.08)
		edge = LIGHT_GOLD_SELECT
	elif state == "disabled":
		fill = Color("#ece7d9")
		edge = LIGHT_PANEL_BORDER
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.border_width_bottom = 1 if state in ["pressed", "hover_pressed"] else 3
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.shadow_color = Color(0.18,0.23,0.15,0.16 if state != "disabled" else 0.06)
	style.shadow_size = 1 if state in ["pressed", "hover_pressed"] else 3
	style.shadow_offset = Vector2(0,1 if state in ["pressed", "hover_pressed"] else 2)
	return style

static func _apply_camp_action(button: Button, color_key: String, radius: int, margin: float) -> void:
	button.set_meta("ui_material", "camp")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _camp_action_style(color_key,state,radius,margin))
	button.add_theme_stylebox_override("focus", button_focus_style(radius))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, _action_text(color_key))
	button.add_theme_color_override("font_disabled_color", LIGHT_LOCK)
	CursorIcons.apply_hover(button)

static func apply_kenney_round_button(button: Button, color_key: String, _font_color: Color) -> void:
	button.set_meta("ui_button_role", "round_action")
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_camp_action(button,color_key,24,2)

## 默认控件也有皮肤，避免确认框/下拉/勾选回落Godot默认灰色。
static func install_button_theme(theme: Theme) -> void:
	var sample := Button.new()
	for type_name in ["Button", "MenuButton", "OptionButton", "CheckButton", "CheckBox"]:
		apply_kenney_rect_button(sample, "grey" if type_name != "Button" else "blue", LIGHT_INK if type_name != "Button" else Color.WHITE, 4)
		if type_name in ["CheckButton", "CheckBox"]: apply_light_selectable(sample)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var style := sample.get_theme_stylebox(state)
			for target in [theme, ThemeDB.get_default_theme()]: target.set_stylebox(state, type_name, style)
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
			var color := sample.get_theme_color(color_name)
			if type_name in ["CheckButton", "CheckBox"]: color = LIGHT_LOCK if color_name == "font_disabled_color" else LIGHT_INK
			for target in [theme, ThemeDB.get_default_theme()]: target.set_color(color_name, type_name, color)
	for target in [theme, ThemeDB.get_default_theme()]:
		target.set_stylebox("panel", "PopupMenu", light_panel_style())
		target.set_stylebox("hover", "PopupMenu", light_card_style(LIGHT_BLUE_SELECT, LIGHT_BORDER_SOFT))
		target.set_color("font_color", "PopupMenu", LIGHT_INK)
		target.set_color("font_hover_color", "PopupMenu", LIGHT_INK)
		target.set_color("font_disabled_color", "PopupMenu", LIGHT_LOCK)
		target.set_stylebox("panel", "AcceptDialog", light_panel_style())
		target.set_constant("buttons_min_width", "AcceptDialog", 88)
		target.set_constant("buttons_min_height", "AcceptDialog", 34)
		for margin in ["margin_left", "margin_right", "margin_top", "margin_bottom"]: target.set_constant(margin, "AcceptDialog", 16)
		var border := light_panel_style()
		border.expand_margin_top = 32
		target.set_stylebox("embedded_border", "Window", border)
		target.set_stylebox("embedded_unfocused_border", "Window", border)
		target.set_constant("title_height", "Window", 32)
		target.set_color("title_color", "Window", LIGHT_INK)
		target.set_color("title_outline_modulate", "Window", Color.TRANSPARENT)
		for type_name in ["Label", "RichTextLabel", "LineEdit", "TextEdit"]:
			target.set_color("font_color", type_name, LIGHT_INK)
			target.set_color("default_color", type_name, LIGHT_INK)
			target.set_color("font_disabled_color", type_name, LIGHT_LOCK)
			target.set_color("font_readonly_color", type_name, LIGHT_BODY)
		for type_name in ["HScrollBar", "VScrollBar"]:
			var track := light_card_style(LIGHT_PANEL_SPLIT,LIGHT_PANEL_BORDER)
			track.set_content_margin_all(0)
			target.set_stylebox("scroll",type_name,track)
			target.set_stylebox("scroll_focus",type_name,track)
			for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
				var grip := light_card_style(LIGHT_ACCENT.lightened(0.18) if state == "grabber_highlight" else LIGHT_ACCENT,LIGHT_BORDER_SOFT)
				grip.set_content_margin_all(4)
				grip.set_corner_radius_all(5)
				target.set_stylebox(state,type_name,grip)
		for type_name in ["HSlider", "VSlider"]:
			var track := light_card_style(LIGHT_PANEL_SPLIT,LIGHT_PANEL_BORDER)
			track.set_content_margin_all(2)
			target.set_stylebox("slider",type_name,track)
			for state in ["grabber_area", "grabber_area_highlight"]:
				var fill := light_card_style(LIGHT_ACCENT,LIGHT_ACCENT)
				fill.set_content_margin_all(2)
				target.set_stylebox(state,type_name,fill)
			target.set_icon("grabber",type_name,_camp_slider_knob(LIGHT_ACCENT))
			target.set_icon("grabber_highlight",type_name,_camp_slider_knob(LIGHT_ACCENT.lightened(0.15)))
			target.set_icon("grabber_disabled",type_name,_camp_slider_knob(LIGHT_LOCK))
		for type_name in ["LineEdit", "TextEdit"]:
			target.set_stylebox("normal",type_name,light_card_style())
			target.set_stylebox("read_only",type_name,light_card_style(Color("#ece7d9"),LIGHT_PANEL_BORDER))
			target.set_stylebox("focus",type_name,button_focus_style())
			target.set_color("selection_color",type_name,LIGHT_BLUE_SELECT)
			target.set_color("caret_color",type_name,LIGHT_ACCENT)
		target.set_stylebox("background","ProgressBar",light_card_style(LIGHT_PANEL_SPLIT,LIGHT_PANEL_BORDER))
		target.set_stylebox("fill","ProgressBar",light_card_style(LIGHT_ACCENT,LIGHT_ACCENT))
		target.set_stylebox("panel","TooltipPanel",light_panel_style())
		target.set_color("font_color","TooltipLabel",LIGHT_INK)
		target.set_stylebox("selected","Tree",light_card_style(LIGHT_BLUE_SELECT,LIGHT_ACCENT))
		target.set_stylebox("selected_focus","Tree",light_card_style(LIGHT_BLUE_SELECT,LIGHT_ACCENT))
		target.set_color("font_color","Tree",LIGHT_INK)
		target.set_color("font_selected_color","Tree",LIGHT_INK)
		target.set_stylebox("panel","Tree",light_panel_style())
	sample.free()

static func _camp_slider_knob(fill: Color) -> Texture2D:
	var image := Image.create(16,16,false,Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var distance := Vector2(x+0.5,y+0.5).distance_to(Vector2(8,8))
			if distance < 7: image.set_pixel(x,y,LIGHT_BORDER_SOFT if distance > 5.5 else fill)
	return ImageTexture.create_from_image(image)

## 动态弹窗和自绘卡片在构建后补齐交互状态，不改变动作或选中逻辑。
static func complete_button_states(button: Button) -> void:
	if not is_instance_valid(button): return
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is AcceptDialog:
			ancestor.get_label().add_theme_color_override("font_color", LIGHT_INK)
			if ancestor.ok_button_text in ["", "OK"]: ancestor.ok_button_text = "确认"
			if ancestor is ConfirmationDialog and ancestor.cancel_button_text == "Cancel": ancestor.cancel_button_text = "取消"
			button.custom_minimum_size = Vector2(88, 34)
			apply_kenney_rect_button(button, "yellow" if button == ancestor.get_ok_button() else "grey", LIGHT_INK, 5)
			break
		ancestor = ancestor.get_parent()
	if not button.has_meta("ui_button_role"):
		if not button.has_theme_stylebox_override("normal"):
			button.set_meta("ui_button_role", "default_control")
			button.set_meta("ui_material", "camp")
		elif button.get_theme_stylebox("normal") is StyleBoxFlat and not button.text.is_empty() and button.get_child_count() == 0:
			var close := button.text in ["×", "关闭", "返回", "取消"]
			apply_kenney_rect_button(button, "red" if close else "grey", Color.WHITE if close else LIGHT_INK, 3)
		else: button.set_meta("ui_button_role", "node_card")
	if button.has_theme_stylebox_override("normal"):
		if not button.has_theme_stylebox_override("hover_pressed"): button.add_theme_stylebox_override("hover_pressed", button.get_theme_stylebox("pressed"))
		if not button.has_theme_stylebox_override("disabled"):
			var disabled := button.get_theme_stylebox("normal").duplicate() as StyleBox
			if disabled is StyleBoxFlat:
				disabled.bg_color = Color("#ece7d9")
				disabled.border_color = LIGHT_PANEL_BORDER
			button.add_theme_stylebox_override("disabled", disabled)
		var focus := button.get_theme_stylebox("focus")
		if focus is StyleBoxEmpty or not button.has_theme_stylebox_override("focus"):
			var normal := button.get_theme_stylebox("normal")
			var radius := maxi(normal.corner_radius_top_left, normal.corner_radius_top_right) if normal is StyleBoxFlat else 8
			button.add_theme_stylebox_override("focus", button_focus_style(radius))

const GOLD := Color("#946e28")
const GREEN := Color("#467465")
const RED := Color("#b95443")
const BLUE := Color("#467465")
const GRAY := Color("#79816d")
const BG := Color("#e2e9d8")
const SIDEBAR := Color("#f7edd8")
const TEXT := Color("#293e32")
const DISABLED := Color("#8a8a76")
const SELECT_BG := Color("#dce8d6")
const SELECT_BORDER := Color("#467465")
const SELECT_TEXT := Color("#293e32")
const SIDEBAR_BORDER := Color("#d6c4a0")
const PANEL_BG := Color("#fff7e6")

## 营地视觉令牌（UI_LAYOUT §20，0.10.1.2；旧名称保留调用兼容）：
## 首页背景/文字/弹窗主色统一入口，其余面板换肤时复用。
const SKY_TOP := Color("#c9dccc")
const SKY_MID := Color("#dde7d2")
const SKY_BOTTOM := Color("#b5c5a2")
const INK := Color("#293e32")      # 黄/灰按钮深蓝墨字
const MIST := Color("#fff7e6")     # 标题副标/底栏白蓝字
const PALE := Color("#d6c4a0")     # 底栏素材署名
const STROKE := Color("#293e32")   # 亮底白字深蓝投影
const DIALOG_PANEL := Color("#fff7e6")
const DIALOG_BORDER := Color("#b79a65")
const DIALOG_HEAD := Color("#467465")
const DIALOG_TEXT := Color("#293e32")
const DIALOG_WARN := Color("#b95443")
const DIALOG_HINT := Color("#78816c")



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
	CursorIcons.apply_hover(button)
	if selected:
		apply_selected_style(button)

## 既有矩形按钮入口保留，材质由营地主题统一。
static func apply_kenney_rect_button(button: Button, color_key: String, _font_color: Color,
		content_margin: float = 12.0) -> void:
	button.set_meta("ui_button_role", "action")
	_apply_camp_action(button,color_key,8,content_margin)


## 共享字距字体（v0.19.0，首页私有实现收敛）：在全局主题字体（站酷快乐体 +
## 系统回退）上叠加字距，标题/按钮共用。
static func spaced_font(spacing: int) -> Font:
	var theme := load("res://assets/ui/ui_theme.tres") as Theme
	var variation := FontVariation.new()
	variation.base_font = theme.default_font
	variation.set_spacing(TextServer.SPACING_GLYPH, spacing)
	return variation


## ===== 全界面暖纸与青绿营地主题（0.10.1.2；共享语义令牌
## docs/ui_concept/src/concept_ui.css + src/ui_hub_map.html）=====

const LIGHT_PAGE_BG := Color("#fff7e6")     # 大面板底
const LIGHT_PANEL_BORDER := Color("#d6c4a0")  # 白面板/卡片描边
const LIGHT_PANEL_SPLIT := Color("#e9dfc8")   # 面板内分隔线/滚动槽
const LIGHT_CARD_BG := Color("#f7edd8")     # 内嵌卡片底
const LIGHT_STAT_BG := Color("#f1e7d1")     # 统计胶囊底
const LIGHT_BLUE_SOFT := Color("#dce8d6")   # 蓝色 chip 底
const LIGHT_BLUE_SELECT := Color("#dce8d6")  # 页签选中底
const LIGHT_BORDER_SOFT := Color("#b79a65")  # 亮蓝描边（页签/下拉）
const LIGHT_ACCENT := Color("#467465")      # 亮蓝强调（数值/图标）
const LIGHT_GOLD_TEXT := Color("#946e28")   # 金色数值文字
const LIGHT_GOLD_SELECT := Color("#b79a65")  # 选中金框
const LIGHT_INK := Color("#293e32")         # 标题/主文字
const LIGHT_BODY := Color("#4c5f4d")        # 次级文字/灰按钮字
const LIGHT_MUTED := Color("#78816c")       # 弱文字
const LIGHT_DESC := Color("#6e7d66")        # 简介文字
const LIGHT_LOCK := Color("#8a8a76")        # 锁定文字
const TAG_OK_FG := Color("#467465")
const TAG_OK_BG := Color("#dce8d6")
const TAG_OPEN_FG := Color("#946e28")
const TAG_OPEN_BG := Color("#f6e5b8")
const TAG_LOCK_FG := Color("#7b806c")
const TAG_LOCK_BG := Color("#e8e2d2")
const TAG_FIRE_FG := Color("#b95443")
const TAG_FIRE_BG := Color("#f7ded0")

## 暖纸面板：木金描边 + 圆角14 + 轻营地阴影。
static func light_panel_style(bg: Color = LIGHT_PAGE_BG, border: Color = LIGHT_PANEL_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.25,0.28,0.18,0.10)
	style.shadow_size = 6
	return style


## 内嵌浅纸卡片：低对比填充 + 木金细描边 + 圆角12。
static func light_card_style(bg: Color = LIGHT_CARD_BG, border: Color = LIGHT_PANEL_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = LIGHT_CARD_BG if bg == Color.WHITE else bg
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
static func avatar_label(text: String, color_key: String = "blue", diameter: float = 44.0, font_size: int = 21, base: Color = Color(0, 0, 0, 0)) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(diameter, diameter)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	var colors: Array = avatar_gradient_colors(color_key, base)
	style.bg_color = colors[0].lerp(colors[1], 0.5)
	style.set_corner_radius_all(diameter * 0.5)
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	label.add_theme_stylebox_override("normal", style)
	return label


static func hero_avatar(id: String, name_text: String, color_key: String = "blue", diameter: float = 44.0, font_size: int = 21) -> Control:
	var path: String = BattleVisualRegistry.PORTRAITS.get(id, "")
	if not path.is_empty() and ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			var portrait := TextureRect.new()
			portrait.custom_minimum_size = Vector2(diameter, diameter)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.texture = texture
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return portrait
	return avatar_label(name_text.left(1), color_key, diameter, font_size)


## 道具方块图标占位（概念图 .tile：类型色渐变圆角方块 + 首字白字；背包卡片/说明条用）。
static func tile_label(text: String, color_key: String = "blue", size: float = 52.0, font_size: int = 24) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(size, size)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	var colors: Array = avatar_gradient_colors(color_key)
	style.bg_color = colors[0].lerp(colors[1], 0.5)
	style.set_corner_radius_all(size * 0.23)
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	label.add_theme_stylebox_override("normal", style)
	return label


## 头像渐变取色（avatar_label / character_avatar_texture 共用）：base 缺省用 key 色。
static func avatar_gradient_colors(color_key: String = "blue", base: Color = Color(0, 0, 0, 0)) -> Array:
	var top: Color = LIGHT_ACCENT.lightened(.25)
	var bottom: Color = LIGHT_ACCENT
	if base != Color(0, 0, 0, 0):
		top = base.lightened(0.15)
		bottom = base.darkened(0.15)
	match color_key:
		"grey": top = Color("#c8c7ae"); bottom = Color("#969a7d")
		"gold": top = Color("#ffd75e"); bottom = Color("#f0a92f")
		"green": top = Color("#5fd6a2"); bottom = Color("#26a86f")
		"purple": top = Color("#b393e8"); bottom = Color("#7e5fc4")
		"orange": top = Color("#ffb066"); bottom = Color("#f0802f")
		"red": top = Color("#ff8d7a"); bottom = Color("#e85b43")
		"blue": top = Color("#78a08a"); bottom = LIGHT_ACCENT
		"brown": top = Color("#c8a06a"); bottom = Color("#9c6f3e")
		"pink": top = Color("#ff9ec2"); bottom = Color("#e0558c")
		"teal": top = Color("#63d8c8"); bottom = Color("#1f9d92")
	return [top, bottom]


## 武将头像概念九色键（与 EncyclopediaPanel.CHARACTER_AVATAR_COLORS 同步维护；缺失回退蓝）。
const CHARACTER_AVATAR_KEYS := {
	"liu_bei": "gold",
	"guan_yu": "red",
	"zhang_fei": "blue",
	"huang_zhong": "orange",
	"huang_fu_song": "purple",
	"diao_chan": "orange",
	"zhou_wei": "blue",
	"zhao_yun": "pink",
	"zhuge_liang": "teal",
}

static func character_avatar_color_key(character_id: String) -> String:
	return str(CHARACTER_AVATAR_KEYS.get(character_id, "blue"))


## 可点选卡片六态：浅纸常态、浅青选中与青绿边、低饱和禁用、木金焦点。
static func apply_light_selectable(button: Button, locked: bool = false) -> void:
	button.set_meta("ui_button_role", "card")
	button.set_meta("ui_material", "camp")
	var normal := light_card_style()
	var hover := light_card_style(LIGHT_CARD_BG, LIGHT_BORDER_SOFT)
	var disabled := light_card_style(Color("#ece7d9"), LIGHT_PANEL_BORDER)
	var selected := light_card_style(LIGHT_BLUE_SELECT, LIGHT_ACCENT)
	selected.set_border_width_all(3)
	selected.shadow_color = Color(0.27,0.45,0.39,0.16)
	selected.shadow_size = 5
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("pressed", selected)
	button.add_theme_stylebox_override("hover_pressed", selected)
	button.add_theme_stylebox_override("focus", button_focus_style(12))
	button.add_theme_color_override("font_color", LIGHT_LOCK if locked else LIGHT_INK)
	button.add_theme_color_override("font_hover_color", LIGHT_LOCK if locked else LIGHT_INK)
	button.add_theme_color_override("font_pressed_color", LIGHT_INK)
	button.add_theme_color_override("font_hover_pressed_color", LIGHT_INK)
	button.add_theme_color_override("font_disabled_color", LIGHT_LOCK)
	CursorIcons.apply_hover(button)


## TabContainer营地页签：浅青选中、浅纸未选、木金分隔。
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


## 经验条：浅纸槽与青绿填充。
static func style_exp_bar(bar: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = LIGHT_PANEL_SPLIT
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = LIGHT_ACCENT
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)

## 局内 HUD v2 皮肤令牌（0.8.17.0 / UI_LAYOUT §10 v0.20.41 定稿）：
## 青绿木金框体与暖纸浮窗；地图与道路本身不改色。
const HUD_BG := Color("#365749")
const HUD_BG_DEEP := Color("#2e4b3e")
const HUD_LINE := Color("#b79a65")
const HUD_TEXT := Color("#fff7e6")
const HUD_VALUE := Color("#e9c574")
const HUD_GREEN := Color("#a3d09b")
const HUD_RED := Color("#ef8872")
const HUD_ACTION := Color("#e9c574")
const HUD_CARD_BG := Color("#40604ee8")
const HUD_COST_BG := Color("#e9c574")
const HUD_COST_TEXT := Color("#293e32")
## 塔详情动作盘（升阶=金盘 / 回收=红盘）：上亮下深做立体，悬停提亮。
const HUD_DISC_GOLD := Color("#e9c574")
const HUD_DISC_GOLD_DEEP := Color("#b79a65")
const HUD_DISC_RED := Color("#df9376")
const HUD_DISC_RED_DEEP := Color("#b95443")

## 新版图徽唯一目录（ICONS v1.0）。旧图保留归档，不作缺图兜底。
const HUD_ICON_DIR := "res://assets/ui/icons/v2/"
const ICON_MANIFEST := HUD_ICON_DIR + "manifest.json"

static var _hud_icon_cache: Dictionary = {}
static var _hud_icon_sized_cache: Dictionary = {}


## 图徽加载（透明符号，裸符号落位）：只取新版；缺图返回 null，
## 调用方按 AGENTS §6 用虚线圆占位并登记 ART_PROMPTS。
static func hud_icon(icon_name: String) -> Texture2D:
	if _hud_icon_cache.has(icon_name):
		return _hud_icon_cache[icon_name]
	var texture: Texture2D = null
	var path := "%s%s.png" % [HUD_ICON_DIR, icon_name]
	if not icon_name.is_empty() and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_hud_icon_cache[icon_name] = texture
	return texture


static func icon_bbcode(icon_name: String, pixels: int = 18) -> String:
	return "[img=%dx%d]%s%s.png[/img]" % [pixels, pixels, HUD_ICON_DIR, icon_name]

static func item_brief(item: Resource) -> String:
	if item == null: return ""
	if item is WeaponData: return WeaponRegistry.brief_description(item)
	if item is RelicData: return item.effect_summary()
	return str(item.description).split("（")[0].strip_edges().trim_suffix("。") + "。"

static func supply_effect_bbcode(supply: BattleSupplyData, level: int) -> String:
	var duration := "  " + icon_bbcode("cooldown") + "%.0fs" % supply.duration_at(level)
	if supply.instant_physical_at(level) > 0:
		return icon_bbcode("dmg_physical") + str(supply.instant_physical_at(level))
	if supply.heal_at(level) > 0:
		return icon_bbcode("base_hp") + "+%d" % supply.heal_at(level)
	if supply.rage_gain_at(level) > 0:
		return icon_bbcode("rage") + "+%d" % supply.rage_gain_at(level)
	if supply.burn_dps_at(level) > 0:
		return icon_bbcode("dmg_magic") + str(supply.instant_magic_at(level)) + "  " + icon_bbcode("status_burn") + "%d/秒" % supply.burn_dps_at(level) + duration
	if supply.attack_speed_bonus_at(level) > 0.0:
		return icon_bbcode("stat_attack_speed") + "+%d%%" % roundi(supply.attack_speed_bonus_at(level) * 100.0) + duration
	if supply.slow_factor_at(level) < 1.0:
		return icon_bbcode("status_slow") + "%d%%" % roundi((1.0 - supply.slow_factor_at(level)) * 100.0) + duration
	return supply.description


## Install icons on the project's theme; all other font/skin settings are preserved.
static func install_icon_theme() -> void:
	var theme := load("res://assets/ui/ui_theme.tres") as Theme
	install_button_theme(theme)
	var groups := {
		"OptionButton": {"arrow": "ui_arrow_down"},
		"CheckBox": {"checked": "ui_checkbox_on", "unchecked": "ui_checkbox_off", "checked_disabled": "ui_checkbox_on", "unchecked_disabled": "ui_checkbox_off", "radio_checked": "ui_radio_on", "radio_unchecked": "ui_radio_off"},
		"CheckButton": {"checked": "ui_checkbox_on", "unchecked": "ui_checkbox_off", "checked_disabled": "ui_checkbox_on", "unchecked_disabled": "ui_checkbox_off"},
		"PopupMenu": {"checked": "ui_checkbox_on", "unchecked": "ui_checkbox_off", "radio_checked": "ui_radio_on", "radio_unchecked": "ui_radio_off", "submenu": "ui_arrow_right"},
		"Tree": {"checked": "ui_checkbox_on", "unchecked": "ui_checkbox_off", "arrow": "ui_arrow_down", "arrow_collapsed": "ui_arrow_right"},
		"SpinBox": {"up": "ui_arrow_up", "down": "ui_arrow_down"},
		"TabBar": {"close": "ui_close", "increment": "ui_arrow_right", "decrement": "ui_arrow_left"},
		"Window": {"close": "ui_close", "close_pressed": "ui_close"},
	}
	for type_name in groups:
		for icon_name in groups[type_name]:
			var icon := hud_icon_sized(groups[type_name][icon_name], 18)
			if icon != null:
				theme.set_icon(icon_name, type_name, icon)
				ThemeDB.get_default_theme().set_icon(icon_name, type_name, icon)


## 图徽落位（0.8.17.2）：< 24px 小档位（160px 源直缩 ≈10.7×，无 mipmap 线性 = 锯齿糊斑、
## mipmap 三线性 = 过软）按显示尺寸 Lanczos 重采样后线性 1:1 落位；其余档位 LINEAR_WITH_MIPMAPS（纹理侧 mipmaps 已开）。
## 仍是「裸符号落位」不加底槽。
static func apply_hud_icon(rect: TextureRect, icon_name: String, display_px: int = 0) -> Texture2D:
	if rect == null:
		return null
	# 小图徽（< 24px）：mipmap 三线性在此档位过软偏糊——先按显示尺寸 Lanczos 重采样、
	# 再 1:1 线性落位，观感对齐概念稿 `.costpill img {15px}`（0.8.17.2）。
	if display_px > 0 and display_px < 24:
		var small := hud_icon_sized(icon_name, display_px)
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		rect.texture = small
		return small
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var texture := hud_icon(icon_name)
	rect.texture = texture
	return texture


## 按显示尺寸一次性高质量重采样（缓存复用；只服务小图徽档位）。
static func hud_icon_sized(icon_name: String, display_px: int) -> Texture2D:
	var source := hud_icon(icon_name)
	if source == null or display_px <= 0:
		return source
	var key := "%s@%d" % [icon_name, display_px]
	if _hud_icon_sized_cache.has(key):
		return _hud_icon_sized_cache[key]
	var image: Image = source.get_image()
	if image == null:
		_hud_icon_sized_cache[key] = source
		return source
	var resized := image.duplicate() as Image
	resized.resize(display_px, display_px, Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(resized)
	_hud_icon_sized_cache[key] = texture
	return texture


## 自定义 _draw / Sprite2D 等 CanvasItem 图徽过滤（同一口径）。
static func tune_hud_icon_item(item: CanvasItem) -> void:
	if item != null:
		item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
