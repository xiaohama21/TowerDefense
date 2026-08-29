extends VBoxContainer

## 地图选择面板（GDD v0.10.1）：章节 → 关卡两级。
## 第一章来自 ChapterData 资源；后续章节以锁定占位预留（纯展示，待 ChapterData）。

signal stage_selected(stage_id: StringName)

const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const UNLOCKED_COLOR := Color(0.78, 0.92, 0.8)
const LOCKED_COLOR := Color(0.55, 0.55, 0.55)
const DONE_COLOR := Color(1.0, 0.82, 0.3)

## 预留章节（GDD 总纲第 3 节规划；纯 UI 占位，正式数据随新章节 ChapterData 落地）。
const RESERVED_CHAPTERS := [
	"董卓之乱", "群雄逐鹿", "官渡之战", "赤壁之战", "三分天下", "北伐中原",
]

var _selected_chapter: ChapterData = null
var _chapter_buttons: Array[Button] = []
var _stage_box: VBoxContainer
var _selected_difficulty: int = 1


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_build_ui()
	_refresh_stages()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "地图选择"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	add_child(title)

	var chapter_hint := Label.new()
	chapter_hint.text = "选择章节"
	chapter_hint.add_theme_font_size_override("font_size", 16)
	chapter_hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.68))
	add_child(chapter_hint)

	var chapter_box := VBoxContainer.new()
	chapter_box.add_theme_constant_override("separation", 6)
	add_child(chapter_box)

	var chapter := GameFlow.get_chapter()
	_selected_chapter = chapter
	_chapter_buttons.append(_make_chapter_button(chapter_box, chapter, true))
	for reserved_name in RESERVED_CHAPTERS:
		var reserved := Button.new()
		reserved.text = "敬请期待 · %s" % reserved_name
		reserved.custom_minimum_size = Vector2(0, 40)
		reserved.add_theme_font_size_override("font_size", 16)
		reserved.add_theme_color_override("font_color", LOCKED_COLOR)
		reserved.disabled = true
		chapter_box.add_child(reserved)
		_chapter_buttons.append(reserved)

	var stage_hint := Label.new()
	stage_hint.text = "关卡（前置关卡通关后解锁）"
	stage_hint.add_theme_font_size_override("font_size", 16)
	stage_hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.68))
	add_child(stage_hint)

	_stage_box = VBoxContainer.new()
	_stage_box.add_theme_constant_override("separation", 6)
	_stage_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_stage_box)


func _make_chapter_button(parent: Node, chapter: ChapterData, selected: bool) -> Button:
	var button := Button.new()
	button.text = "第 %d 章 · %s" % [chapter.chapter_number, chapter.display_name]
	button.custom_minimum_size = Vector2(0, 44)
	button.toggle_mode = true
	button.set_pressed_no_signal(selected)
	button.add_theme_font_size_override("font_size", 18)
	button.disabled = true  # 当前仅一章，章节按钮仅作展示与选中态
	parent.add_child(button)
	return button


func _refresh_stages() -> void:
	for child in _stage_box.get_children():
		child.queue_free()
	var profile := ProfileStore.get_profile()
	var stages := GameFlow.get_sorted_stages(_selected_chapter)
	if stages.is_empty():
		var empty := Label.new()
		empty.text = "该章节暂无关卡"
		empty.add_theme_font_size_override("font_size", 17)
		_stage_box.add_child(empty)
	for stage in stages:
		_stage_box.add_child(_make_stage_row(profile, stage))


func _make_stage_row(profile: PlayerProfile, stage: StageData) -> HBoxContainer:
	var unlocked := GameFlow.is_stage_unlocked(profile, stage)
	var completed := false
	var entry = profile.stage_progress.get(str(stage.stage_id), {})
	if entry is Dictionary:
		completed = entry.get("completed", false)

	var state_text := "未解锁"
	var state_color := LOCKED_COLOR
	if completed:
		state_text = "已通关"
		state_color = DONE_COLOR
	elif unlocked:
		state_text = "可出战"
		state_color = UNLOCKED_COLOR

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var stage_button := Button.new()
	stage_button.text = "第 %d 关 · %s　%s" % [stage.stage_number, stage.display_name, state_text]
	stage_button.custom_minimum_size = Vector2(280, 44)
	stage_button.add_theme_font_size_override("font_size", 18)
	stage_button.add_theme_color_override("font_color", state_color)
	stage_button.disabled = not unlocked
	row.add_child(stage_button)
	if unlocked:
		stage_button.pressed.connect(func() -> void: stage_selected.emit(stage.stage_id))
	# 难度选择（轻松/标准/困难；困难需标准通关）
	for diff in [0, 1, 2]:
		var diff_name: String = Difficulty.NAMES[diff]
		var diff_unlocked: bool = GameFlow.is_difficulty_unlocked(profile, stage.stage_id, diff)
		var diff_button := Button.new()
		diff_button.text = diff_name
		diff_button.toggle_mode = true
		diff_button.custom_minimum_size = Vector2(52, 30)
		diff_button.add_theme_font_size_override("font_size", 13)
		diff_button.disabled = not diff_unlocked or not unlocked
		if diff == 1:
			diff_button.set_pressed_no_signal(true)
		diff_button.toggled.connect(_on_difficulty_changed.bind(diff, stage.stage_id))
		row.add_child(diff_button)
	return row


func _on_difficulty_changed(pressed: bool, difficulty: int, _stage_id: StringName) -> void:
	if pressed:
		_selected_difficulty = difficulty
