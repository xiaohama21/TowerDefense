extends CanvasLayer

signal next_wave_pressed
signal pause_pressed
signal restart_pressed
signal character_selected(character_id: String)
signal debug_wave_jump_requested(wave_index: int)
signal debug_clear_enemies_requested
signal tower_upgrade_requested
signal tower_sell_requested
signal result_next_pressed
signal result_retry_pressed
signal result_menu_pressed
signal exit_pressed
signal dialogue_finished

const PANEL_STYLE_BG := Color(0.055, 0.075, 0.12, 0.94)
const PANEL_STYLE_BORDER := Color(0.25, 0.43, 0.68, 0.85)

@onready var gold_label: Label = $Root/TopBar/Margin/Content/GoldLabel
@onready var lives_label: Label = $Root/TopBar/Margin/Content/LivesLabel
@onready var wave_label: Label = $Root/TopBar/Margin/Content/WaveLabel
@onready var stage_label: Label = $Root/TopBar/Margin/Content/StageLabel
@onready var next_wave_button: Button = $Root/TopBar/Margin/Content/NextWaveButton
@onready var pause_button: Button = $Root/TopBar/Margin/Content/PauseButton
@onready var restart_button: Button = $Root/TopBar/Margin/Content/RestartButton
@onready var exit_button: Button = $Root/TopBar/Margin/Content/ExitButton
@onready var message_panel: PanelContainer = $Root/MessagePanel
@onready var message_label: Label = $Root/MessagePanel/Margin/MessageLabel
@onready var status_label: Label = $Root/StatusLabel
@onready var character_bar: HBoxContainer = $Root/CharacterBar

const DEBUG_PANEL_SCRIPT := preload("res://scripts/DebugPanel.gd")

var _status_request_id: int = 0
var _previous_paused_state: bool = false
var _character_buttons: Dictionary = {}

# 武将属性面板（升级/回收）当前展示的塔与关卡规则；塔被回收后引用失效。
var _panel_tower: Tower = null
var _panel_stage_data: StageData = null
var _tower_panel: PanelContainer
var _tower_title_label: Label
var _tower_attr_label: Label
var _tower_upgrade_button: Button
var _tower_sell_button: Button
var _result_panel: PanelContainer
var _result_center: CenterContainer
var _result_title_label: Label
var _result_lines_label: Label
var _result_next_button: Button
var _dialogue_layer: Control
var _dialogue_speaker_label: Label
var _dialogue_text_label: Label
var _dialogue_lines: Array = []
var _dialogue_index: int = 0
var _dialogue_advance_after_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	next_wave_button.pressed.connect(_on_next_wave_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	exit_button.pressed.connect(func() -> void: exit_pressed.emit())

	_create_tower_panel()
	_create_result_panel()
	_create_dialogue_layer()

	if OS.is_debug_build():
		_create_debug_panel()

	update_gold(GameManager.gold)
	update_lives(GameManager.lives)
	update_wave(GameManager.current_wave, GameManager.total_waves)
	_previous_paused_state = get_tree().paused
	_refresh_action_buttons()


func set_stage_name(stage_name: String) -> void:
	stage_label.text = stage_name


## 调试辅助面板（仅调试构建创建）：加金币、跳波次、清场，方便测试。
func _create_debug_panel() -> void:
	var panel := DEBUG_PANEL_SCRIPT.new()
	panel.position = Vector2(16, 164)
	panel.wave_jump_requested.connect(debug_wave_jump_requested.emit)
	panel.clear_enemies_requested.connect(debug_clear_enemies_requested.emit)
	$Root.add_child(panel)


func setup_character_bar(characters: Array) -> void:
	for button in _character_buttons.values():
		if is_instance_valid(button):
			button.queue_free()
	_character_buttons.clear()

	for character_data in characters:
		if character_data == null:
			continue
		var button := Button.new()
		button.text = "%s\n%d 金币" % [character_data.display_name, character_data.build_cost]
		button.custom_minimum_size = Vector2(120, 54)
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 15)
		var character_id := str(character_data.character_id)
		button.pressed.connect(_on_character_button_pressed.bind(character_id))
		character_bar.add_child(button)
		_character_buttons[character_id] = button


func set_selected_character(character_id: String) -> void:
	for key in _character_buttons.keys():
		var button := _character_buttons[key] as Button
		if is_instance_valid(button):
			button.set_pressed_no_signal(str(key) == character_id)


func _on_character_button_pressed(character_id: String) -> void:
	character_selected.emit(character_id)
	# Keep at least one hero selected: clicking the active hero again must not
	# leave the build bar without a selection.
	for key in _character_buttons.keys():
		var button := _character_buttons[key] as Button
		if is_instance_valid(button):
			button.set_pressed_no_signal(str(key) == character_id)


func _process(_delta: float) -> void:
	# UI 始终处理，暂停后仍可继续或重开游戏。
	_refresh_wave_label()
	if get_tree().paused != _previous_paused_state:
		_previous_paused_state = get_tree().paused
		_refresh_action_buttons()


func update_gold(new_amount: int) -> void:
	gold_label.text = "金币：%d" % max(new_amount, 0)
	_refresh_tower_panel()


func update_lives(new_amount: int) -> void:
	lives_label.text = "生命：%d" % max(new_amount, 0)
	_refresh_action_buttons()


func update_wave(current: int, total: int) -> void:
	_refresh_wave_label(current, total)
	_refresh_action_buttons()


func _refresh_wave_label(current: int = -1, total: int = -1) -> void:
	if current < 0:
		current = GameManager.current_wave
	if total < 0:
		total = GameManager.total_waves
	var displayed_wave := current + 1 if GameManager.is_wave_active else current
	wave_label.text = "波次：%d / %d" % [clampi(displayed_wave, 0, total), total]


func show_message(message: String) -> void:
	message_label.text = message
	message_panel.visible = true


func hide_message() -> void:
	message_panel.visible = false


func show_status(message: String, duration: float = 1.5) -> void:
	_status_request_id += 1
	var request_id := _status_request_id
	status_label.text = message
	status_label.visible = true

	await get_tree().create_timer(duration, true).timeout
	if request_id == _status_request_id:
		status_label.visible = false


func _refresh_action_buttons() -> void:
	if not is_instance_valid(next_wave_button):
		return

	var all_waves_completed := GameManager.current_wave >= GameManager.total_waves
	var game_finished := all_waves_completed or GameManager.lives <= 0
	next_wave_button.disabled = (
		GameManager.is_wave_active
		or game_finished
	)
	pause_button.disabled = game_finished

	if all_waves_completed:
		next_wave_button.text = "全部波次完成"
	elif GameManager.is_wave_active:
		next_wave_button.text = "第 %d 波进行中…" % (GameManager.current_wave + 1)
	else:
		next_wave_button.text = "开始第 %d 波" % (GameManager.current_wave + 1)

	pause_button.text = "继续" if get_tree().paused else "暂停"


func _on_next_wave_button_pressed() -> void:
	if not next_wave_button.disabled:
		next_wave_pressed.emit()


func _on_pause_button_pressed() -> void:
	pause_pressed.emit()


func _on_restart_button_pressed() -> void:
	restart_pressed.emit()


## 武将属性面板（GDD v0.9.2）：点击已建塔，在地图正下方展示职业、局内
## 等级与伤害/攻速/射程；升级与回收入口并入面板。
func _create_tower_panel() -> void:
	_tower_panel = PanelContainer.new()
	_tower_panel.name = "TowerPanel"
	_tower_panel.visible = false
	_tower_panel.add_theme_stylebox_override("panel", _make_panel_style())
	$Root.add_child(_tower_panel)
	_tower_panel.anchor_left = 0.5
	_tower_panel.anchor_right = 0.5
	_tower_panel.anchor_top = 1.0
	_tower_panel.anchor_bottom = 1.0
	_tower_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tower_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tower_panel.offset_left = -230.0
	_tower_panel.offset_right = 230.0
	_tower_panel.offset_top = -14.0
	_tower_panel.offset_bottom = -14.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	_tower_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_tower_title_label = Label.new()
	_tower_title_label.add_theme_font_size_override("font_size", 18)
	_tower_title_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.8))
	_tower_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_tower_title_label)

	_tower_attr_label = Label.new()
	_tower_attr_label.add_theme_font_size_override("font_size", 15)
	_tower_attr_label.add_theme_color_override("font_color", Color(0.65, 0.84, 1.0))
	_tower_attr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_tower_attr_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)

	_tower_upgrade_button = Button.new()
	_tower_upgrade_button.custom_minimum_size = Vector2(0, 40)
	_tower_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tower_upgrade_button.add_theme_font_size_override("font_size", 16)
	_tower_upgrade_button.pressed.connect(func() -> void: tower_upgrade_requested.emit())
	buttons.add_child(_tower_upgrade_button)

	_tower_sell_button = Button.new()
	_tower_sell_button.custom_minimum_size = Vector2(0, 40)
	_tower_sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tower_sell_button.add_theme_font_size_override("font_size", 16)
	_tower_sell_button.pressed.connect(func() -> void: tower_sell_requested.emit())
	buttons.add_child(_tower_sell_button)


func show_tower_panel(tower: Tower, stage_data: StageData) -> void:
	_panel_tower = tower
	_panel_stage_data = stage_data
	_tower_panel.visible = true
	_refresh_tower_panel()


func hide_tower_panel() -> void:
	_panel_tower = null
	_panel_stage_data = null
	_tower_panel.visible = false


func _refresh_tower_panel() -> void:
	if _tower_panel == null or not _tower_panel.visible:
		return
	var tower := _panel_tower as Tower
	if tower == null or not is_instance_valid(tower):
		hide_tower_panel()
		return

	var max_level: int = _panel_stage_data.max_inbattle_upgrade_level if _panel_stage_data != null else 0
	_tower_title_label.text = "%s · %s · 局内等级 %d/%d" % [
		tower.display_name, tower.get_profession_name(), tower.battle_level, max_level
	]
	var attacks_per_second := 1.0 / maxf(tower.attack_cooldown, 0.01)
	_tower_attr_label.text = "伤害 %d　　攻速 %.2f 次/秒　　射程 %d" % [
		tower.damage, attacks_per_second, int(tower.range_radius)
	]

	if _panel_stage_data != null and tower.battle_level < max_level:
		var cost := tower.get_upgrade_cost(_panel_stage_data.upgrade_cost_factor)
		_tower_upgrade_button.text = "升级（%d 金币）" % cost
		_tower_upgrade_button.disabled = GameManager.gold < cost
	else:
		_tower_upgrade_button.text = "已满级"
		_tower_upgrade_button.disabled = true

	var refund := tower.get_sell_refund(_panel_stage_data.sell_refund_ratio if _panel_stage_data != null else 0.6)
	_tower_sell_button.text = "回收（返还 %d）" % refund
	_tower_sell_button.disabled = false


## 开场剧情对话层（GDD modules/STAGES.md 5.1）：底部叙事面板，
## 点击任意处推进，"跳过"直接结束；展示期间为模态（阻挡地图点击）。
func _create_dialogue_layer() -> void:
	_dialogue_layer = Control.new()
	_dialogue_layer.name = "DialogueLayer"
	_dialogue_layer.visible = false
	_dialogue_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	$Root.add_child(_dialogue_layer)
	_dialogue_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_layer.gui_input.connect(_on_dialogue_input)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.4)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_layer.add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 190)
	# 面板可穿透：点击台词区域同样推进（否则"点击任意处"在最自然的
	# 位置失效）；下方的跳过按钮保持 STOP，点击不会误触推进。
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	_dialogue_layer.add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 120.0
	panel.offset_right = -120.0
	panel.offset_top = -230.0
	panel.offset_bottom = -24.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_dialogue_speaker_label = Label.new()
	_dialogue_speaker_label.add_theme_font_size_override("font_size", 21)
	_dialogue_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	vbox.add_child(_dialogue_speaker_label)

	_dialogue_text_label = Label.new()
	_dialogue_text_label.add_theme_font_size_override("font_size", 19)
	_dialogue_text_label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.9))
	_dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_dialogue_text_label)

	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 12)
	vbox.add_child(hint_row)

	var hint := Label.new()
	hint.text = "点击任意处继续 ▼"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.65, 0.84, 1.0))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_row.add_child(hint)

	var skip_button := Button.new()
	skip_button.text = "跳过对话"
	skip_button.custom_minimum_size = Vector2(120, 34)
	skip_button.add_theme_font_size_override("font_size", 15)
	skip_button.pressed.connect(_finish_dialogue)
	hint_row.add_child(skip_button)


func show_dialogue(lines: Array) -> void:
	_dialogue_lines = lines
	_dialogue_index = 0
	_dialogue_layer.visible = true
	# 打开瞬间与每次推进后的短防抖：快速连点不会一次跳过多行。
	_dialogue_advance_after_msec = Time.get_ticks_msec() + 200
	_show_current_line()


func _show_current_line() -> void:
	if _dialogue_index >= _dialogue_lines.size():
		_finish_dialogue()
		return
	var line: DialogueLineData = _dialogue_lines[_dialogue_index]
	_dialogue_speaker_label.text = line.speaker
	_dialogue_text_label.text = line.text


func _on_dialogue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed 			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_try_advance_dialogue()


func _try_advance_dialogue() -> void:
	var now := Time.get_ticks_msec()
	if now < _dialogue_advance_after_msec:
		return
	_dialogue_advance_after_msec = now + 180
	_advance_dialogue()


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_lines.size():
		_finish_dialogue()
	else:
		_show_current_line()


func _finish_dialogue() -> void:
	_dialogue_layer.visible = false
	dialogue_finished.emit()


func skip_dialogue() -> void:
	_finish_dialogue()


func is_dialogue_active() -> bool:
	return _dialogue_layer != null and _dialogue_layer.visible


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_STYLE_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = PANEL_STYLE_BORDER
	style.set_corner_radius_all(10)
	return style


## 结算面板（GDD 阶段 1）：胜利/失败、经验明细、掉落与新武将。
## 由全屏 CenterContainer 承载以保证严格居中；展示期间整体可见，
## 并以其默认 STOP 鼠标过滤充当模态（遮住后方顶栏与地图点击）。
func _create_result_panel() -> void:
	_result_center = CenterContainer.new()
	_result_center.name = "ResultCenter"
	_result_center.visible = false
	$Root.add_child(_result_center)
	_result_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_result_panel = PanelContainer.new()
	_result_panel.name = "ResultPanel"
	_result_panel.custom_minimum_size = Vector2(460, 0)
	_result_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_result_center.add_child(_result_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_result_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.name = "ResultTitle"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_result_title_label = title

	var lines := Label.new()
	lines.name = "ResultLines"
	lines.add_theme_font_size_override("font_size", 19)
	lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lines)
	_result_lines_label = lines

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	vbox.add_child(buttons)

	_result_next_button = Button.new()
	_result_next_button.custom_minimum_size = Vector2(170, 46)
	_result_next_button.add_theme_font_size_override("font_size", 18)
	_result_next_button.pressed.connect(func() -> void: result_next_pressed.emit())
	buttons.add_child(_result_next_button)

	var retry_button := Button.new()
	retry_button.custom_minimum_size = Vector2(150, 46)
	retry_button.add_theme_font_size_override("font_size", 18)
	retry_button.text = "重试本关"
	retry_button.pressed.connect(func() -> void: result_retry_pressed.emit())
	buttons.add_child(retry_button)

	var menu_button := Button.new()
	menu_button.custom_minimum_size = Vector2(150, 46)
	menu_button.add_theme_font_size_override("font_size", 18)
	menu_button.text = "返回选关"
	menu_button.pressed.connect(func() -> void: result_menu_pressed.emit())
	buttons.add_child(menu_button)


func show_result(data: Dictionary) -> void:
	var victory: bool = data.get("victory", false)
	var title := _result_title_label
	var lines := _result_lines_label
	title.text = "胜 利" if victory else "战 败"
	title.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.4) if victory else Color(0.9, 0.4, 0.35))

	var line_parts: Array[String] = []
	if victory:
		var xp_by_character: Dictionary = data.get("xp_by_character", {})
		for character_id in xp_by_character.keys():
			line_parts.append("%s +%d 经验" % [
				GameFlow.load_character_data(str(character_id)).display_name
					if GameFlow.load_character_data(str(character_id)) != null else str(character_id),
				int(xp_by_character[character_id]),
			])
		var loot: Dictionary = data.get("loot", {})
		for item_id in loot.keys():
			line_parts.append("%s ×%d" % [GameFlow.get_item_display_name(str(item_id)), int(loot[item_id])])
		for unlock_name in data.get("unlock_names", []):
			line_parts.append("新武将加入：%s" % unlock_name)
		if line_parts.is_empty():
			line_parts.append("守住了全部波次")
		if not data.get("saved", false):
			line_parts.append("警告：存档写入失败，本次收益未保存")
	else:
		line_parts.append("基地陷落，本局收益未保存（失败不产生任何成长）")
	lines.text = "\n".join(line_parts)

	var next_stage_name := str(data.get("next_stage_name", ""))
	_result_next_button.visible = victory and not next_stage_name.is_empty()
	_result_next_button.text = "下一关：%s" % next_stage_name

	_tower_panel.visible = false
	_result_center.visible = true
	_result_panel.visible = true


func hide_result() -> void:
	_result_center.visible = false
	_result_panel.visible = false
