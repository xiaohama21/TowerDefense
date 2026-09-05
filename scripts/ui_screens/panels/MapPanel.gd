extends VBoxContainer

## 地图选择面板（UI_LAYOUT §5，Kenney 换肤 v0.18.0，按概念图 ui_hub_map.png）：
## 顶栏（标题 + 章节下拉 + 通关/总星进度胶囊 + 难度 Kenney 分段）→ 关卡 4×2 白卡
## （状态徽标 + 星级三槽[阶段10预留] + sNN 关名 + 两行简介 + 敌人/波次·经验 + 首通奖励行）
## → 底部关卡预告条（简介 + 四统计胶囊 + 首通奖励徽章 + 一键通关(测试) + 出征·编队）。
## 交互不变：卡片点选联动预告条；返回选关保留关卡/难度；出征直达编队（v0.33.1）。

signal stage_selected(stage_id: StringName, difficulty: int)

## 预留章节（GDD 总纲第 3 节规划；纯 UI 占位，正式数据随新章节 ChapterData 落地）。
const RESERVED_CHAPTERS := [
	"董卓之乱", "群雄逐鹿", "官渡之战", "赤壁之战", "三分天下", "北伐中原",
]

## 概念图色板（src/ui_hub_map.html）
const INK := Color("#1b4d78")
const BODY := Color("#5f8aa6")
const MUTED := Color("#7d9cb4")
const DESC := Color("#6b93ad")
const LOCK_TEXT := Color("#9fb3c4")
const NAV_BODY := Color("#33566f")
const LOGO_TEXT := Color("#14538a")
const CHIP_BLUE_BG := Color("#e1f1fb")
const CARD_BORDER_DONE := Color("#9ad8b4")
const CARD_BORDER_READY := Color("#ffcc00")
const CARD_BORDER_LOCKED := Color("#cddbe6")
const CARD_BG_LOCKED := Color("#e6eef5")
const TAG_DONE_FG := Color("#11804a")
const TAG_DONE_BG := Color("#d8f2e3")
const TAG_OPEN_FG := Color("#8a6d00")
const TAG_OPEN_BG := Color("#fff3c4")
const TAG_LOCK_FG := Color("#7d8fa0")
const TAG_LOCK_BG := Color("#d9e4ec")
const CHIP_GREEN := Color("#16bb77")
const CHIP_BLUE := Color("#2eaadc")
const REWARD_LINE := Color("#d7e9f5")

var _selected_chapter: ChapterData = null
var _chapter_button: Button
var _chapter_popup: Control
var _chapter_rows: Array[Button] = []

## 章节号中文数字（概念图文案「第一章」）。
const CN_NUMERALS := ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
var _stage_cards: Dictionary = {}
var _stage_grid: GridContainer
var _selected_difficulty: int = Difficulty.NORMAL
var _selected_stage: StageData = null
var _progress_labels: Array[Label] = []
var _status_label: Label
var _difficulty_buttons: Array[Button] = []
## 关卡预告条控件
var _detail_panel: Panel
var _detail_name: Label
var _detail_difficulty_chip: Label
var _detail_desc: Label
var _detail_stats: Array[Label] = []
var _stat_key_labels: Array[Label] = []
var _detail_rewards: HBoxContainer
var _deploy_button: Button
var _clear_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	# 返回选关保留关卡/难度（v0.33.1，UI_LAYOUT.md §6）：重进地图页签时沿用
	# GameFlow 当前所选难度（编队页「返回选关」回来不丢难度选择）。
	_selected_difficulty = GameFlow.selected_difficulty
	_build_ui()
	_refresh_stages()


# ============ 顶栏：标题 + 章节下拉 + 进度 + 难度分段 ============

func _build_ui() -> void:
	var topbar := HBoxContainer.new()
	topbar.add_theme_constant_override("separation", 10)
	add_child(topbar)

	var title := Label.new()
	title.text = "地图选择"
	title.add_theme_font_override("font", UITheme.spaced_font(3))
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", INK)
	topbar.add_child(title)

	# 章节下拉（自绘，v0.20.3 对齐概念图 .dropdown：行左名称 + 右侧 ✅/敬请期待）
	var chapter := GameFlow.get_chapter()
	_selected_chapter = chapter
	_chapter_button = Button.new()
	_chapter_button.custom_minimum_size = Vector2(250, 42)
	_chapter_button.focus_mode = Control.FOCUS_NONE
	_chapter_button.text = "第%s章 · %s" % [_chapter_cn_numeral(chapter.chapter_number), chapter.display_name]
	_chapter_button.add_theme_font_override("font", UITheme.spaced_font(2))
	_chapter_button.add_theme_font_size_override("font_size", 18)
	_chapter_button.add_theme_icon_override("arrow", _small_arrow_icon())
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color.WHITE
	box_style.border_color = Color("#9fd0ea")
	box_style.border_width_bottom = 4
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(10)
	box_style.content_margin_left = 12.0
	box_style.content_margin_right = 10.0
	box_style.content_margin_top = 6.0
	box_style.content_margin_bottom = 4.0
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		_chapter_button.add_theme_stylebox_override(state, box_style)
	# 按下/悬停态文字同样墨蓝（v0.20.3 修复：默认按压白字落在白底上「文字消失」）
	for color_state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		_chapter_button.add_theme_color_override(color_state, LOGO_TEXT)
	_chapter_button.pressed.connect(_toggle_chapter_popup)
	topbar.add_child(_chapter_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(spacer)

	# 通关进度胶囊（星级为阶段 10 预留：总星恒 0，挑战目标落地后接入实值）
	for i in range(2):
		var prog := Label.new()
		prog.add_theme_stylebox_override("normal", _chip_style(CHIP_BLUE_BG, 11, 4))
		prog.add_theme_font_size_override("font_size", 14)
		prog.add_theme_color_override("font_color", NAV_BODY)
		topbar.add_child(prog)
		_progress_labels.append(prog)

	var diff_label := Label.new()
	diff_label.text = "难度"
	diff_label.add_theme_font_size_override("font_size", 15)
	diff_label.add_theme_color_override("font_color", MUTED)
	topbar.add_child(diff_label)

	# 难度档位随 Difficulty.count()（difficulty_presets）自动扩展（v0.31.2）。
	var difficulty_group := ButtonGroup.new()
	for diff in range(Difficulty.count()):
		var diff_button := Button.new()
		diff_button.text = Difficulty.name(diff)
		diff_button.toggle_mode = true
		diff_button.button_group = difficulty_group
		diff_button.focus_mode = Control.FOCUS_NONE
		diff_button.custom_minimum_size = Vector2(92, 42)
		diff_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		diff_button.add_theme_font_override("font", UITheme.spaced_font(3))
		diff_button.add_theme_font_size_override("font_size", 17)
		diff_button.toggled.connect(_on_difficulty_changed.bind(diff))
		topbar.add_child(diff_button)
		_difficulty_buttons.append(diff_button)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.visible = false
	add_child(_status_label)

	# 关卡卡片：4 列 × 2 行一屏展示，无滚动条。
	_stage_grid = GridContainer.new()
	_stage_grid.columns = 4
	_stage_grid.add_theme_constant_override("h_separation", 12)
	_stage_grid.add_theme_constant_override("v_separation", 12)
	_stage_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_stage_grid)

	_build_detail_bar()


## 章节下拉弹层（概念图 .dropdown .list）：整屏点击遮罩 + 白色圆角列表，
## 行 = 名称（左） + 状态（右：当前章 ✅ 绿勾 / 预留章 敬请期待 灰字）。
func _toggle_chapter_popup() -> void:
	if _chapter_popup != null and is_instance_valid(_chapter_popup):
		_close_chapter_popup()
		return
	var overlay := Control.new()
	overlay.top_level = true
	overlay.name = "ChapterPopup"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var catcher := Button.new()
	catcher.flat = true
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var catcher_style := StyleBoxEmpty.new()
	catcher.add_theme_stylebox_override("normal", catcher_style)
	catcher.add_theme_stylebox_override("hover", catcher_style)
	catcher.add_theme_stylebox_override("pressed", catcher_style)
	catcher.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	catcher.pressed.connect(_close_chapter_popup)
	overlay.add_child(catcher)
	var list_panel := Panel.new()
	list_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var list_style := UITheme.light_panel_style()
	list_style.set_border_width_all(2)
	list_style.border_color = UITheme.LIGHT_BORDER_SOFT
	list_style.set_corner_radius_all(10)
	list_style.shadow_color = Color(0.078, 0.325, 0.541, 0.22)
	list_style.shadow_size = 10
	list_panel.add_theme_stylebox_override("panel", list_style)
	overlay.add_child(list_panel)
	var list_box := VBoxContainer.new()
	list_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list_box.offset_left = 6.0
	list_box.offset_right = -6.0
	list_box.offset_top = 6.0
	list_box.offset_bottom = -6.0
	list_panel.add_child(list_box)

	var chapter := GameFlow.get_chapter()
	_chapter_rows.clear()
	_append_chapter_row(list_box, "第%s章 · %s" % [_chapter_cn_numeral(chapter.chapter_number), chapter.display_name],
		true, true)
	for reserved_name in RESERVED_CHAPTERS:
		_append_chapter_row(list_box, reserved_name, false, false)

	add_child(overlay)
	_chapter_popup = overlay
	# 弹层定位：框按钮正下方（top_level 坐标 = 画布坐标，与 get_global_rect 同空间）
	var box_rect := _chapter_button.get_global_rect()
	list_panel.position = box_rect.position + Vector2(0, box_rect.size.y + 4)
	# 显式尺寸（行高 42 × 行数 + 内边距）：Panel 锚定子盒不传导最小尺寸，不能 reset_size
	var row_count := 1 + RESERVED_CHAPTERS.size()
	list_panel.size = Vector2(maxf(box_rect.size.x, 260.0), row_count * 42.0 + 14.0)


func _append_chapter_row(list_box: VBoxContainer, name_text: String, is_current: bool, enabled: bool) -> void:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 42)
	row.focus_mode = Control.FOCUS_NONE
	row.disabled = not enabled
	var normal := StyleBoxFlat.new()
	normal.bg_color = UITheme.LIGHT_BLUE_SELECT if (is_current and enabled) else Color.TRANSPARENT
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var hover := StyleBoxFlat.new()
	hover.bg_color = UITheme.LIGHT_PANEL_SPLIT if not (is_current and enabled) else UITheme.LIGHT_BLUE_SELECT
	hover.set_corner_radius_all(8)
	hover.content_margin_left = 12.0
	hover.content_margin_right = 12.0
	hover.content_margin_top = 8.0
	hover.content_margin_bottom = 8.0
	row.add_theme_stylebox_override("normal", normal)
	row.add_theme_stylebox_override("hover", hover)
	row.add_theme_stylebox_override("disabled", normal)
	row.add_theme_stylebox_override("pressed", normal)
	row.add_theme_stylebox_override("hover_pressed", normal)
	row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	row.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	row.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	row.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	row.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0))
	if enabled:
		row.pressed.connect(_close_chapter_popup)
	list_box.add_child(row)
	var row_content := HBoxContainer.new()
	row_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row_content.offset_left = 12.0
	row_content.offset_right = -12.0
	row_content.offset_top = 8.0
	row_content.offset_bottom = -8.0
	row_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(row_content)
	var name_label := Label.new()
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color",
		LOGO_TEXT if enabled else UITheme.LIGHT_LOCK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_content.add_child(name_label)
	if is_current and enabled:
		var check := Label.new()
		check.text = "✔"
		check.add_theme_font_size_override("font_size", 15)
		check.add_theme_color_override("font_color", UITheme.TAG_OK_FG)
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_content.add_child(check)
	elif not enabled:
		var later := Label.new()
		later.text = "敬请期待"
		later.add_theme_font_size_override("font_size", 14)
		later.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)
		later.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_content.add_child(later)


func _close_chapter_popup() -> void:
	if _chapter_popup != null and is_instance_valid(_chapter_popup):
		_chapter_popup.queue_free()
	_chapter_popup = null


## 章节号中文数字（1 → 一）。
func _chapter_cn_numeral(number: int) -> String:
	if number >= 1 and number <= CN_NUMERALS.size():
		return CN_NUMERALS[number - 1]
	return str(number)


# ============ 关卡卡片（4×2 白卡） ============

func _refresh_stages() -> void:
	_status_label.visible = false
	for child in _stage_grid.get_children():
		child.queue_free()
	_stage_cards.clear()
	var profile := ProfileStore.get_profile()
	var stages := GameFlow.get_sorted_stages(_selected_chapter)
	if stages.is_empty():
		var empty := Label.new()
		empty.text = "该章节暂无关卡"
		empty.add_theme_font_size_override("font_size", 17)
		empty.add_theme_color_override("font_color", MUTED)
		_stage_grid.add_child(empty)
	for stage in stages:
		var card := _make_stage_card(profile, stage)
		_stage_grid.add_child(card)
		_stage_cards[str(stage.stage_id)] = card
	var completed := 0
	for stage in stages:
		var entry = profile.stage_progress.get(str(stage.stage_id), {})
		if entry is Dictionary and entry.get("completed", false):
			completed += 1
	_progress_labels[0].text = "已通关 %d/%d" % [completed, stages.size()]
	_progress_labels[1].text = "总星 %d/%d" % [0, stages.size() * 3]
	# 关卡默认选中：优先 GameFlow.selected_stage_id（v0.33.1「返回选关」保留所选关卡），
	# 不可玩/未解锁则回退首个已解锁关卡。
	var default_stage: StageData = null
	var last_stage_id := str(GameFlow.selected_stage_id)
	for stage in stages:
		if str(stage.stage_id) == last_stage_id and GameFlow.is_stage_unlocked(profile, stage):
			default_stage = stage
			break
	if default_stage == null:
		for stage in stages:
			if GameFlow.is_stage_unlocked(profile, stage):
				default_stage = stage
				break
	if default_stage == null and not stages.is_empty():
		default_stage = stages[0]
	_select_stage(default_stage)


func _make_stage_card(profile: PlayerProfile, stage: StageData) -> Button:
	var unlocked := GameFlow.is_stage_unlocked(profile, stage)
	var entry = profile.stage_progress.get(str(stage.stage_id), {})
	var completed: bool = entry is Dictionary and entry.get("completed", false)

	var card := Button.new()
	card.toggle_mode = true
	card.disabled = not unlocked
	card.focus_mode = Control.FOCUS_NONE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_text = false
	var border_color := CARD_BORDER_READY if unlocked and not completed else (CARD_BORDER_DONE if completed else CARD_BORDER_LOCKED)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color.WHITE if unlocked else CARD_BG_LOCKED
	card_style.border_color = border_color
	card_style.set_border_width_all(3)
	card_style.set_corner_radius_all(14)
	card_style.content_margin_left = 12.0
	card_style.content_margin_right = 12.0
	card_style.content_margin_top = 9.0
	card_style.content_margin_bottom = 8.0
	if unlocked and not completed:
		card_style.shadow_color = Color(1.0, 0.8, 0.0, 0.35)
		card_style.shadow_size = 6
	var selected_style := card_style.duplicate()
	selected_style.bg_color = Color("#fffbe6")
	selected_style.border_color = CARD_BORDER_READY
	selected_style.set_border_width_all(3)
	card.add_theme_stylebox_override("normal", card_style)
	card.add_theme_stylebox_override("hover", card_style)
	card.add_theme_stylebox_override("disabled", card_style)
	card.add_theme_stylebox_override("pressed", selected_style)
	card.add_theme_stylebox_override("hover_pressed", selected_style)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.set_meta("stage_id", stage.stage_id)
	if unlocked:
		card.pressed.connect(_on_card_pressed.bind(stage))

	# 卡面内容（忽略鼠标，点击落到底层按钮）
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10.0
	content.offset_right = -10.0
	content.offset_top = 8.0
	content.offset_bottom = -6.0
	content.add_theme_constant_override("separation", 3)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)

	var text_color := INK if unlocked else LOCK_TEXT
	var sub_color := DESC if unlocked else LOCK_TEXT

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(head)
	var tag := Label.new()
	if completed:
		tag.text = "已通关"
		tag.add_theme_stylebox_override("normal", _chip_style(TAG_DONE_BG, 9, 2))
		tag.add_theme_color_override("font_color", TAG_DONE_FG)
	elif unlocked:
		tag.text = "可挑战"
		tag.add_theme_stylebox_override("normal", _chip_style(TAG_OPEN_BG, 9, 2))
		tag.add_theme_color_override("font_color", TAG_OPEN_FG)
	else:
		tag.text = "未解锁"
		tag.add_theme_stylebox_override("normal", _chip_style(TAG_LOCK_BG, 9, 2))
		tag.add_theme_color_override("font_color", TAG_LOCK_FG)
	tag.add_theme_font_size_override("font_size", 12)
	head.add_child(tag)
	var star_spacer := Control.new()
	star_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	star_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(star_spacer)
	for star_index in range(3):
		var star := TextureRect.new()
		star.texture = load("res://assets/ui/icons/star_outline_grey.png")
		star.custom_minimum_size = Vector2(16, 15)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(star)

	var name_label := Label.new()
	name_label.text = "s%02d %s" % [stage.stage_number, stage.display_name]
	name_label.add_theme_font_override("font", UITheme.spaced_font(1))
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.add_theme_color_override("font_color", text_color)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(name_label)

	var desc := Label.new()
	desc.text = stage.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", sub_color)
	desc.max_lines_visible = 2
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(desc)

	content.add_child(_make_kv("敌人", _enemy_names(stage), sub_color, text_color if unlocked else LOCK_TEXT))
	content.add_child(_make_kv("波次", "%d 波 · 经验 %d" % [stage.waves.size(), stage.participant_xp], sub_color, text_color if unlocked else LOCK_TEXT))

	var row_spacer := Control.new()
	row_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row_spacer)
	var reward_border := Panel.new()
	reward_border.custom_minimum_size = Vector2(0, 1)
	reward_border.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	reward_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reward_border_style := StyleBoxFlat.new()
	reward_border_style.bg_color = REWARD_LINE
	reward_border.add_theme_stylebox_override("panel", reward_border_style)
	content.add_child(reward_border)
	content.add_child(_make_kv_text("首通", _reward_compact_text(stage), MUTED if unlocked else LOCK_TEXT, NAV_BODY if unlocked else LOCK_TEXT))
	return card


## 「敌人」行：跨全部波次去重后的敌人名（最多展示 4 种，超出计总数）。
func _enemy_names(stage: StageData) -> String:
	var names: Array[String] = []
	for wave in stage.waves:
		if wave == null:
			continue
		for spawn in wave.spawn_groups:
			if spawn == null or spawn.enemy == null:
				continue
			if not names.has(spawn.enemy.display_name):
				names.append(spawn.enemy.display_name)
	if names.size() > 4:
		return "%s 等 %d 种" % ["·".join(names.slice(0, 4)), names.size()]
	return "·".join(names)


## 「k v」行（概念图 .kv）：单层 HBox，值 Label 弹性占宽（超宽省略号截断）。
func _make_kv(k: String, v: String, k_color: Color, v_color: Color) -> HBoxContainer:
	return _make_kv_text(k, v, k_color, v_color)


## 下拉框箭头图标：原图过大（会撑高顶栏），预缩放为 18×12。
func _small_arrow_icon() -> ImageTexture:
	var texture := load("res://assets/ui/icons/arrow_basic_s_blue.png") as Texture2D
	var image := texture.get_image()
	image.resize(18, 12, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _make_kv_text(k: String, v: String, k_color: Color, v_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key := Label.new()
	key.text = k
	key.add_theme_font_size_override("font_size", 13)
	key.add_theme_color_override("font_color", k_color)
	row.add_child(key)
	var value := Label.new()
	value.text = v
	value.add_theme_font_size_override("font_size", 13)
	value.add_theme_color_override("font_color", v_color)
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	return row


func _chip_style(bg: Color, margin_h: float, margin_v: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(8)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style


## 首通奖励紧凑文案（卡片奖励行用）：解锁 X · 道具×N · 信物 X。
func _reward_compact_text(stage: StageData) -> String:
	var parts: Array[String] = []
	for character_id in stage.first_clear_unlock_character_ids:
		var character := GameFlow.load_character_data(str(character_id))
		parts.append("解锁 %s" % (character.display_name if character != null else str(character_id)))
	for reward in stage.first_clear_rewards:
		if reward == null or reward.item == null or reward.amount <= 0:
			continue
		parts.append("%s×%d" % [reward.item.display_name, reward.amount])
	if stage.first_clear_relic != null:
		parts.append("信物 %s" % stage.first_clear_relic.display_name)
	if parts.is_empty():
		return "—"
	return " · ".join(parts)


# ============ 底部关卡预告条（概念图 .detail） ============

func _build_detail_bar() -> void:
	_detail_panel = Panel.new()
	_detail_panel.custom_minimum_size = Vector2(0, 148)
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color.WHITE
	detail_style.border_color = CARD_BORDER_READY
	detail_style.set_border_width_all(3)
	detail_style.set_corner_radius_all(14)
	detail_style.shadow_color = Color(0.078, 0.325, 0.541, 0.14)
	detail_style.shadow_size = 8
	detail_style.content_margin_left = 16.0
	detail_style.content_margin_right = 14.0
	detail_style.content_margin_top = 10.0
	detail_style.content_margin_bottom = 10.0
	_detail_panel.add_theme_stylebox_override("panel", detail_style)
	add_child(_detail_panel)

	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.offset_left = 14.0
	columns.offset_right = -12.0
	columns.offset_top = 10.0
	columns.offset_bottom = -10.0
	columns.add_theme_constant_override("separation", 14)
	_detail_panel.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	columns.add_child(left)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	left.add_child(head)
	var badge := Label.new()
	badge.text = "关卡预告"
	badge.add_theme_stylebox_override("normal", _chip_style(TAG_OPEN_BG, 10, 2))
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", TAG_OPEN_FG)
	head.add_child(badge)
	_detail_name = Label.new()
	_detail_name.add_theme_font_override("font", UITheme.spaced_font(2))
	_detail_name.add_theme_font_size_override("font_size", 24)
	_detail_name.add_theme_color_override("font_color", INK)
	head.add_child(_detail_name)
	var head_spacer := Control.new()
	head_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_spacer)
	_detail_difficulty_chip = Label.new()
	_detail_difficulty_chip.add_theme_stylebox_override("normal", _chip_style(TAG_DONE_BG, 10, 2))
	_detail_difficulty_chip.add_theme_font_size_override("font_size", 13)
	_detail_difficulty_chip.add_theme_color_override("font_color", TAG_DONE_FG)
	head.add_child(_detail_difficulty_chip)

	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", 14)
	_detail_desc.add_theme_color_override("font_color", BODY)
	_detail_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	left.add_child(_detail_desc)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	left.add_child(stats)
	for stat_def in ["敌人", "波次", "经验", "推荐"]:
		var pill := PanelContainer.new()
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pill_style := StyleBoxFlat.new()
		pill_style.bg_color = Color("#f3f9fd")
		pill_style.border_color = REWARD_LINE
		pill_style.set_border_width_all(1)
		pill_style.set_corner_radius_all(9)
		pill_style.content_margin_left = 9.0
		pill_style.content_margin_right = 9.0
		pill_style.content_margin_top = 4.0
		pill_style.content_margin_bottom = 4.0
		pill.add_theme_stylebox_override("panel", pill_style)
		var pill_row := HBoxContainer.new()
		pill_row.alignment = BoxContainer.ALIGNMENT_CENTER
		pill_row.add_theme_constant_override("separation", 5)
		pill.add_child(pill_row)
		# 键（弱色）+ 值（墨蓝）——v0.20.3 修复：原胶囊只有值没有键名，含义不明
		var key_label := Label.new()
		key_label.text = stat_def
		key_label.add_theme_font_size_override("font_size", 13)
		key_label.add_theme_color_override("font_color", MUTED)
		pill_row.add_child(key_label)
		_stat_key_labels.append(key_label)
		var value_label := Label.new()
		value_label.add_theme_font_size_override("font_size", 13)
		value_label.add_theme_color_override("font_color", INK)
		pill_row.add_child(value_label)
		_detail_stats.append(value_label)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 9)
	columns.add_child(right)

	var reward_head := HBoxContainer.new()
	reward_head.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_head.add_theme_constant_override("separation", 8)
	right.add_child(reward_head)
	var reward_label := Label.new()
	reward_label.text = "首通奖励"
	reward_label.add_theme_font_size_override("font_size", 13)
	reward_label.add_theme_color_override("font_color", MUTED)
	reward_head.add_child(reward_label)
	_detail_rewards = HBoxContainer.new()
	_detail_rewards.add_theme_constant_override("separation", 8)
	reward_head.add_child(_detail_rewards)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	right.add_child(actions)

	_clear_button = Button.new()
	_clear_button.text = "一键通关(测试)"
	_clear_button.custom_minimum_size = Vector2(136, 52)
	_clear_button.focus_mode = Control.FOCUS_NONE
	_clear_button.add_theme_font_size_override("font_size", 15)
	UITheme.apply_kenney_rect_button(_clear_button, "grey", NAV_BODY)
	_clear_button.pressed.connect(_on_instant_clear)
	actions.add_child(_clear_button)

	_deploy_button = Button.new()
	_deploy_button.text = "出征 · 编队"
	_deploy_button.custom_minimum_size = Vector2(176, 52)
	_deploy_button.focus_mode = Control.FOCUS_NONE
	_deploy_button.add_theme_font_override("font", UITheme.spaced_font(3))
	_deploy_button.add_theme_font_size_override("font_size", 20)
	UITheme.apply_kenney_rect_button(_deploy_button, "yellow", UITheme.INK)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	actions.add_child(_deploy_button)


## 首通奖励徽章（右列）：解锁武将=绿、道具/信物=蓝。
func _refresh_reward_chips(stage: StageData) -> void:
	for child in _detail_rewards.get_children():
		_detail_rewards.remove_child(child)
		child.queue_free()
	for character_id in stage.first_clear_unlock_character_ids:
		var character := GameFlow.load_character_data(str(character_id))
		_detail_rewards.add_child(_make_reward_chip(
			"武将 · %s" % (character.display_name if character != null else str(character_id)), CHIP_GREEN))
	for reward in stage.first_clear_rewards:
		if reward == null or reward.item == null or reward.amount <= 0:
			continue
		_detail_rewards.add_child(_make_reward_chip("%s ×%d" % [reward.item.display_name, reward.amount], CHIP_BLUE))
	if stage.first_clear_relic != null:
		_detail_rewards.add_child(_make_reward_chip("信物 · %s" % stage.first_clear_relic.display_name, CHIP_BLUE))


func _make_reward_chip(text: String, bg: Color) -> Label:
	var chip := Label.new()
	chip.text = text
	chip.add_theme_font_size_override("font_size", 14)
	chip.add_theme_color_override("font_color", Color.WHITE)
	var style := _chip_style(bg, 12, 4)
	style.set_corner_radius_all(9)
	style.border_width_bottom = 3
	style.border_color = bg.darkened(0.2)
	chip.add_theme_stylebox_override("normal", style)
	return chip


# ============ 选择与刷新（交互逻辑不变） ============

func _on_card_pressed(stage: StageData) -> void:
	_select_stage(stage)


func _select_stage(stage: StageData) -> void:
	_selected_stage = stage
	var stage_id := str(stage.stage_id) if stage != null else ""
	for key in _stage_cards.keys():
		var card := _stage_cards[key] as Button
		if not is_instance_valid(card):
			continue
		card.set_pressed_no_signal(str(key) == stage_id)
	_refresh_action_bar()


func _refresh_action_bar() -> void:
	var profile := ProfileStore.get_profile()
	var stage := _selected_stage
	if stage == null:
		_detail_name.text = "请选择关卡"
		_detail_desc.text = ""
		_detail_difficulty_chip.text = ""
		for key_label in _stat_key_labels:
			key_label.visible = false
		for pill in _detail_stats:
			pill.text = "—"
		for reward_child in _detail_rewards.get_children():
			reward_child.queue_free()
		_deploy_button.disabled = true
		_clear_button.disabled = true
		for diff_button in _difficulty_buttons:
			diff_button.disabled = true
		return
	var unlocked := GameFlow.is_stage_unlocked(profile, stage)
	if not unlocked:
		_selected_difficulty = Difficulty.NORMAL
	if not GameFlow.is_difficulty_unlocked(profile, stage.stage_id, _selected_difficulty):
		_selected_difficulty = Difficulty.NORMAL
	_detail_name.text = "s%02d %s" % [stage.stage_number, stage.display_name]
	_detail_difficulty_chip.text = "难度 · %s" % Difficulty.name(_selected_difficulty)
	_detail_desc.text = stage.description
	var stat_values := [
		_enemy_names(stage),
		"%d 波" % stage.waves.size(),
		str(stage.participant_xp),
		"塔×%d · 升阶×%d" % [stage.recommended_tower_count, stage.recommended_rank_count],
	]
	for i in _detail_stats.size():
		_stat_key_labels[i].visible = true
		_detail_stats[i].text = stat_values[i]
	_refresh_reward_chips(stage)
	_deploy_button.disabled = not unlocked
	_clear_button.disabled = not unlocked
	for i in _difficulty_buttons.size():
		var diff_button := _difficulty_buttons[i]
		var diff_unlocked := GameFlow.is_difficulty_unlocked(profile, stage.stage_id, i)
		diff_button.disabled = not diff_unlocked or not unlocked
		diff_button.set_pressed_no_signal(i == _selected_difficulty)
		# Kenney 分段（v0.18.0）：选中=蓝，未选=灰。
		UITheme.apply_kenney_rect_button(diff_button, "blue" if i == _selected_difficulty else "grey",
			Color.WHITE if i == _selected_difficulty else NAV_BODY)


func _on_difficulty_changed(pressed: bool, difficulty: int) -> void:
	if pressed:
		_selected_difficulty = difficulty
		if _selected_stage != null:
			_detail_difficulty_chip.text = "难度 · %s" % Difficulty.name(_selected_difficulty)
		for i in _difficulty_buttons.size():
			UITheme.apply_kenney_rect_button(_difficulty_buttons[i], "blue" if i == difficulty else "grey",
				Color.WHITE if i == difficulty else NAV_BODY)


## 出征（✅ v0.33.1 无确认直达编队）：发 stage_selected，由 GameHub 跳转。
func _on_deploy_pressed() -> void:
	if _selected_stage != null:
		stage_selected.emit(_selected_stage.stage_id, _selected_difficulty)


## 一键通关（测试，v0.15.1）：构造一场标准胜利战局并走正常结算写档
## （参与经验 +100/已拥有武将、首通/重复掉落、解锁、首通信物、科技点）。
func _on_instant_clear() -> void:
	var stage := _selected_stage
	if stage == null:
		return
	var profile := ProfileStore.get_profile()
	var first_clear := not profile.stage_progress.has(str(stage.stage_id))
	var session := BattleSession.new(str(stage.stage_id))
	for character_id in profile.get_owned_character_ids():
		session.add_xp(character_id, 100)
	GameFlow.collect_stage_rewards(session, stage, first_clear)
	GameFlow.award_tech_points(session, first_clear)
	session.mark_victory({
		"remaining_lives": 20,
		"completed_waves": stage.waves.size(),
		"difficulty": Difficulty.key_name(_selected_difficulty),
		"instant_clear": true,
	})
	_status_label.visible = true
	if ProfileStore.commit_victory(session, profile):
		_status_label.text = "测试通关：%s 已结算（首通=%s），奖励已写档。" % [stage.display_name, str(first_clear)]
		_status_label.add_theme_color_override("font_color", TAG_DONE_FG)
	else:
		_status_label.text = "一键通关失败：%s" % stage.display_name
		_status_label.add_theme_color_override("font_color", Color("#d71935"))
	_refresh_stages()
