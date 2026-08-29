extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	ProfileStore.configure_paths("user://.build_probe.json")
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var build_manager := main.get_node("BuildManager")
	var ui := main.get_node("UI")
	var slots := get_tree().get_nodes_in_group("build_slots")
	var slot = slots[0]
	print("PROBE slot_pos=", slot.global_position, " pickable=", slot.input_pickable)

	# 跳过开场对话（模拟玩家点击推进完毕）
	ui.skip_dialogue()
	await get_tree().process_frame
	var dialogue_layer: Control = main.get_node("UI/Root/DialogueLayer")
	print("PROBE dialogue_hidden=", not dialogue_layer.visible)

	# 对照实验：注入点击暂停按钮（GUI Control），验证注入方式本身是否有效
	var pause_button: Button = main.get_node("UI/Root/TopBar/Margin/Content/PauseButton")
	var pause_rect := pause_button.get_global_rect()
	print("PROBE pause_rect=", pause_rect, " paused_before=", get_tree().paused)
	var pause_click := InputEventMouseButton.new()
	pause_click.button_index = MOUSE_BUTTON_LEFT
	pause_click.pressed = true
	pause_click.position = pause_rect.position + pause_rect.size / 2.0
	Input.parse_input_event(pause_click)
	await get_tree().process_frame
	await get_tree().process_frame
	print("PROBE paused_after_injection=", get_tree().paused)
	get_tree().paused = false

	# 注入真实鼠标点击事件（走完整输入管线：位置命中 → Area2D → 信号）
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = slot.global_position
	Input.parse_input_event(click)
	await get_tree().process_frame
	await get_tree().process_frame

	print("PROBE pending=", build_manager.pending_slot, " slot_pending=", slot.get("pending"))
	var panel: Control = main.get_node("UI/Root/BuildConfirmPanel")
	print("PROBE confirm_visible=", panel.visible)
	var towers := main.get_node("TowerManager").get_child_count()
	print("PROBE towers_before_confirm=", towers)

	# 真实点击"确认建造"按钮（按钮全局位置）
	var confirm_button: Button = null
	for node in panel.find_children("*", "Button", true, false):
		var b := node as Button
		if b != null and b.text.begins_with("确认建造"):
			confirm_button = b
	print("PROBE confirm_btn_pos=", confirm_button.get_global_rect().position + confirm_button.get_global_rect().size / 2.0 if confirm_button != null else Vector2.ZERO, " disabled=", confirm_button.disabled if confirm_button != null else true)
	var btn_click := InputEventMouseButton.new()
	btn_click.button_index = MOUSE_BUTTON_LEFT
	btn_click.pressed = true
	btn_click.position = confirm_button.get_global_rect().position + confirm_button.get_global_rect().size / 2.0
	Input.parse_input_event(btn_click)
	await get_tree().process_frame
	await get_tree().process_frame
	print("PROBE towers_after_confirm=", main.get_node("TowerManager").get_child_count(), " gold=", GameManager.gold, " occupied=", slot.get("occupied"))
	get_tree().quit(0)
