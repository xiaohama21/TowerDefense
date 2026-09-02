extends VBoxContainer

## 地图选择面板（阶段 8 提交 4 重构，UI_LAYOUT.md 第 4 节）：
## 章节区横向一行胶囊按钮（不滚动，超出自动换行）；关卡区 2×4 网格卡片一屏展示（无滚动条）；
## 底部操作条：关卡摘要 + 难度切换（轻松/标准/困难）+ 出征（金色主按钮）+ 一键通关（测试）。

signal stage_selected(stage_id: StringName, difficulty: int)

## 预留章节（GDD 总纲第 3 节规划；纯 UI 占位，正式数据随新章节 ChapterData 落地）。
const RESERVED_CHAPTERS := [
	"董卓之乱", "群雄逐鹿", "官渡之战", "赤壁之战", "三分天下", "北伐中原",
]

var _selected_chapter: ChapterData = null
var _chapter_buttons: Array[Button] = []
var _stage_cards: Dictionary = {}
var _stage_grid: GridContainer
var _selected_difficulty: int = 1
var _selected_stage: StageData = null
var _status_label: Label
var _summary_label: Label
var _deploy_button: Button
var _clear_button: Button
var _difficulty_buttons: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_build_ui()
	_refresh_stages()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "地图选择"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.GOLD)
	add_child(title)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.visible = false
	add_child(_status_label)

	# 章节区：横向一行胶囊按钮（HFlowContainer 超宽自动换行，仍不出现滚动条）。
	var chapter_flow := HFlowContainer.new()
	chapter_flow.custom_minimum_size = Vector2(0, 48)
	chapter_flow.add_theme_constant_override("h_separation", 10)
	chapter_flow.add_theme_constant_override("v_separation", 6)
	add_child(chapter_flow)

	var chapter := GameFlow.get_chapter()
	_selected_chapter = chapter
	var chapter_button := Button.new()
	chapter_button.text = "第 %d 章 · %s" % [chapter.chapter_number, chapter.display_name]
	chapter_button.custom_minimum_size = Vector2(0, 42)
	chapter_button.add_theme_font_size_override("font_size", 17)
	chapter_button.toggle_mode = true
	chapter_button.set_pressed_no_signal(true)
	chapter_button.pressed.connect(func() -> void: chapter_button.set_pressed_no_signal(true))
	UITheme.apply_selected_style(chapter_button)
	chapter_flow.add_child(chapter_button)
	_chapter_buttons.append(chapter_button)
	for reserved_name in RESERVED_CHAPTERS:
		var reserved := Button.new()
		reserved.text = "敬请期待 · %s" % reserved_name
		reserved.custom_minimum_size = Vector2(0, 42)
		reserved.add_theme_font_size_override("font_size", 14)
		reserved.add_theme_color_override("font_color", UITheme.DISABLED)
		reserved.disabled = true
		chapter_flow.add_child(reserved)
		_chapter_buttons.append(reserved)

	# 关卡区：2×4 网格一屏展示，无滚动条。
	_stage_grid = GridContainer.new()
	_stage_grid.columns = 2
	_stage_grid.add_theme_constant_override("h_separation", 12)
	_stage_grid.add_theme_constant_override("v_separation", 10)
	_stage_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_stage_grid)

	# 底部操作条：关卡摘要 + 难度切换 + 出征 + 一键通关（测试）。
	var action_bar := HBoxContainer.new()
	action_bar.custom_minimum_size = Vector2(0, 64)
	action_bar.add_theme_constant_override("separation", 10)
	add_child(action_bar)

	_summary_label = Label.new()
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 15)
	action_bar.add_child(_summary_label)

	for diff in [0, 1, 2]:
		var diff_button := Button.new()
		diff_button.text = Difficulty.NAMES[diff]
		diff_button.toggle_mode = true
		diff_button.custom_minimum_size = Vector2(62, 40)
		diff_button.add_theme_font_size_override("font_size", 14)
		diff_button.toggled.connect(_on_difficulty_changed.bind(diff))
		action_bar.add_child(diff_button)
		_difficulty_buttons.append(diff_button)

	_deploy_button = Button.new()
	_deploy_button.text = "出 征"
	_deploy_button.custom_minimum_size = Vector2(110, 48)
	_deploy_button.add_theme_font_size_override("font_size", 18)
	_deploy_button.add_theme_color_override("font_color", UITheme.GOLD)
	_deploy_button.pressed.connect(_on_deploy_pressed)
	action_bar.add_child(_deploy_button)

	_clear_button = Button.new()
	_clear_button.text = "一键通关（测试）"
	_clear_button.custom_minimum_size = Vector2(140, 40)
	_clear_button.add_theme_font_size_override("font_size", 13)
	_clear_button.add_theme_color_override("font_color", UITheme.GRAY)
	_clear_button.pressed.connect(_on_instant_clear)
	action_bar.add_child(_clear_button)


func _make_stage_card(profile: PlayerProfile, stage: StageData) -> Button:
	var unlocked := GameFlow.is_stage_unlocked(profile, stage)
	var completed := false
	var entry = profile.stage_progress.get(str(stage.stage_id), {})
	if entry is Dictionary:
		completed = entry.get("completed", false)

	var state_text := "未解锁"
	var state_color := UITheme.GRAY
	if completed:
		state_text = "已通关"
		state_color = UITheme.GREEN
	elif unlocked:
		state_text = "可出战"
		state_color = UITheme.GOLD

	var card := Button.new()
	card.text = "第 %d 关 · %s\n%s\n首通：%s\n%s" % [
		stage.stage_number, stage.display_name,
		stage.description,
		_first_clear_text(stage),
		state_text,
	]
	card.custom_minimum_size = Vector2(0, 108)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_theme_font_size_override("font_size", 15)
	card.toggle_mode = true
	card.disabled = not unlocked
	UITheme.apply_card_style(card, state_color)
	card.set_meta("stage_id", stage.stage_id)
	if unlocked:
		card.pressed.connect(_on_card_pressed.bind(stage))
	return card


## 首通奖励文案：解锁武将 + 首通道具 + Boss 首通信物。
func _first_clear_text(stage: StageData) -> String:
	var parts: Array[String] = []
	var character_names: Array[String] = []
	for character_id in stage.first_clear_unlock_character_ids:
		var character := GameFlow.load_character_data(str(character_id))
		character_names.append(character.display_name if character != null else str(character_id))
	if not character_names.is_empty():
		parts.append("解锁武将：%s" % "、".join(character_names))
	var item_parts: Array[String] = []
	for reward in stage.first_clear_rewards:
		if reward == null or reward.item == null or reward.amount <= 0:
			continue
		item_parts.append("%s×%d" % [reward.item.display_name, reward.amount])
	if not item_parts.is_empty():
		parts.append("、".join(item_parts))
	if stage.first_clear_relic != null:
		parts.append("信物：%s" % stage.first_clear_relic.display_name)
	if parts.is_empty():
		return "无固定奖励"
	return "；".join(parts)


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
		empty.add_theme_color_override("font_color", UITheme.GRAY)
		_stage_grid.add_child(empty)
	for stage in stages:
		var card := _make_stage_card(profile, stage)
		_stage_grid.add_child(card)
		_stage_cards[str(stage.stage_id)] = card
	var default_stage: StageData = null
	for stage in stages:
		if GameFlow.is_stage_unlocked(profile, stage):
			default_stage = stage
			break
	if default_stage == null and not stages.is_empty():
		default_stage = stages[0]
	_select_stage(default_stage)


func _on_card_pressed(stage: StageData) -> void:
	_select_stage(stage)


func _select_stage(stage: StageData) -> void:
	_selected_stage = stage
	var stage_id := str(stage.stage_id) if stage != null else ""
	for key in _stage_cards.keys():
		var card := _stage_cards[key] as Button
		if not is_instance_valid(card):
			continue
		var selected := str(key) == stage_id
		card.set_pressed_no_signal(selected)
		if selected:
			UITheme.apply_selected_style(card)
	_refresh_action_bar()


func _refresh_action_bar() -> void:
	var profile := ProfileStore.get_profile()
	var stage := _selected_stage
	if stage == null:
		_summary_label.text = "请选择关卡"
		_summary_label.add_theme_color_override("font_color", UITheme.GRAY)
		_deploy_button.disabled = true
		_clear_button.disabled = true
		for diff_button in _difficulty_buttons:
			diff_button.disabled = true
		return
	var unlocked := GameFlow.is_stage_unlocked(profile, stage)
	if not unlocked:
		_selected_difficulty = 1
	if not GameFlow.is_difficulty_unlocked(profile, stage.stage_id, _selected_difficulty):
		_selected_difficulty = 1
	_summary_label.text = "第 %d 关 · %s —— %s\n当前难度：%s\n首通：%s" % [
		stage.stage_number, stage.display_name, stage.description,
		Difficulty.NAMES[_selected_difficulty], _first_clear_text(stage),
	]
	_summary_label.add_theme_color_override("font_color", UITheme.TEXT if unlocked else UITheme.DISABLED)
	_deploy_button.disabled = not unlocked
	_clear_button.disabled = not unlocked
	for i in _difficulty_buttons.size():
		var diff_button := _difficulty_buttons[i]
		var diff_unlocked := GameFlow.is_difficulty_unlocked(profile, stage.stage_id, i)
		diff_button.disabled = not diff_unlocked or not unlocked
		diff_button.set_pressed_no_signal(i == _selected_difficulty)


func _on_difficulty_changed(pressed: bool, difficulty: int) -> void:
	if pressed:
		_selected_difficulty = difficulty


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
		_status_label.add_theme_color_override("font_color", UITheme.GREEN)
	else:
		_status_label.text = "一键通关失败：%s" % stage.display_name
		_status_label.add_theme_color_override("font_color", UITheme.RED)
	_refresh_stages()
