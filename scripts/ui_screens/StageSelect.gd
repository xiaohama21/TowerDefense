extends Control

## 章节选关界面（GDD 阶段 1）：按进度解锁，可重刷已通关关卡。

const BG_COLOR := Color(0.06, 0.09, 0.08)
const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const UNLOCKED_COLOR := Color(0.78, 0.92, 0.8)
const LOCKED_COLOR := Color(0.55, 0.55, 0.55)
const DONE_COLOR := Color(1.0, 0.82, 0.3)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BG_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var chapter := GameFlow.get_chapter()
	var chapter_name: String = chapter.display_name if chapter != null else "章节"
	var title := Label.new()
	title.text = "章节选择 · %s" % chapter_name
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	root.add_child(title)

	root.add_child(_make_spacer(10))

	var profile := ProfileStore.get_profile()
	var stages := GameFlow.get_sorted_stages(chapter)
	if stages.is_empty():
		var empty := Label.new()
		empty.text = "暂无可用关卡"
		empty.add_theme_font_size_override("font_size", 20)
		root.add_child(empty)

	for stage in stages:
		root.add_child(_make_stage_row(profile, stage))

	root.add_child(_make_spacer(16))

	var back_button := Button.new()
	back_button.text = "返回主菜单"
	back_button.custom_minimum_size = Vector2(180, 44)
	back_button.pressed.connect(func() -> void: GameFlow.goto_menu())
	root.add_child(back_button)


func _make_stage_row(profile: PlayerProfile, stage: StageData) -> Button:
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

	var row := Button.new()
	row.text = "第 %d 关 · %s　　%s　敌波 %d" % [
		stage.stage_number, stage.display_name, state_text, stage.waves.size()
	]
	row.custom_minimum_size = Vector2(0, 56)
	row.add_theme_font_size_override("font_size", 20)
	row.add_theme_color_override("font_color", state_color)
	row.disabled = not unlocked
	if unlocked:
		row.pressed.connect(_on_stage_pressed.bind(stage.stage_id))
	return row


func _on_stage_pressed(stage_id: StringName) -> void:
	GameFlow.select_stage(stage_id)
	GameFlow.goto_squad_select()


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
