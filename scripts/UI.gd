extends CanvasLayer

signal next_wave_pressed
signal pause_pressed
signal restart_pressed
signal character_selected(character_id: String)

@onready var gold_label: Label = $Root/TopBar/Margin/Content/GoldLabel
@onready var lives_label: Label = $Root/TopBar/Margin/Content/LivesLabel
@onready var wave_label: Label = $Root/TopBar/Margin/Content/WaveLabel
@onready var stage_label: Label = $Root/TopBar/Margin/Content/StageLabel
@onready var next_wave_button: Button = $Root/TopBar/Margin/Content/NextWaveButton
@onready var pause_button: Button = $Root/TopBar/Margin/Content/PauseButton
@onready var restart_button: Button = $Root/TopBar/Margin/Content/RestartButton
@onready var message_panel: PanelContainer = $Root/MessagePanel
@onready var message_label: Label = $Root/MessagePanel/Margin/MessageLabel
@onready var status_label: Label = $Root/StatusLabel
@onready var character_bar: HBoxContainer = $Root/CharacterBar

var _status_request_id: int = 0
var _previous_paused_state: bool = false
var _character_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	next_wave_button.pressed.connect(_on_next_wave_button_pressed)
	pause_button.pressed.connect(_on_pause_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)

	update_gold(GameManager.gold)
	update_lives(GameManager.lives)
	update_wave(GameManager.current_wave, GameManager.total_waves)
	_previous_paused_state = get_tree().paused
	_refresh_action_buttons()


func set_stage_name(stage_name: String) -> void:
	stage_label.text = stage_name


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
