extends Node

## 退出导航回归测试（v0.15.2，应用户要求）：验证「战斗退出 → 游戏大厅（不直接退出
## 游戏）」与「游戏大厅 → 返回主菜单」两条链路的关键节点与资源完整性。
## 使用一次性隔离存档槽，不触碰玩家真实存档（模式同 FlowRunner/Stage0Runner）。

var failures: Array[String] = []
var _profile_file := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.exit_flow_runner_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("EXIT_FLOW_TEST: %s" % message)


func _run() -> void:
	_test_scene_resources()
	await _test_battle_exit()
	await _test_hub_back_button()
	await _test_main_menu_quit()
	_cleanup()
	_finish()


## 场景资源完整性：退出/返回链路的目标场景必须可加载。
func _test_scene_resources() -> void:
	for entry in [
		["主菜单场景", GameFlow.MAIN_MENU_SCENE],
		["游戏大厅场景", GameFlow.GAME_HUB_SCENE],
		["编队场景", GameFlow.SQUAD_SELECT_SCENE],
		["战斗场景", GameFlow.BATTLE_SCENE],
	]:
		_check(ResourceLoader.exists(entry[1]), "%s应存在：%s" % [entry[0], entry[1]])


## 战斗退出（v0.9.3）：未结算时弹确认框，确认后回游戏大厅（goto_hub），绝不直接退出。
func _test_battle_exit() -> void:
	var profile := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(profile)
	GameFlow.select_stage(&"ch01_s01")
	GameFlow.set_squad(["liu_bei"] as Array[String])
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var exit_button := main.get_node_or_null("UI/Root/TopBar/Margin/Content/ExitButton") as Button
	_check(exit_button != null, "战斗顶栏应有退出按钮")
	if exit_button == null:
		main.queue_free()
		await get_tree().process_frame
		return
	var ui := main.get_node("UI")
	var exit_forwarding: Array = ui.exit_pressed.get_connections()
	_check(exit_forwarding.any(func(c: Dictionary) -> bool: return c.get("callable", Callable()).get_method() == "_on_exit_pressed"),
		"退出按钮链路应最终绑定 _on_exit_pressed（经 UI 转发）")
	exit_button.pressed.emit()
	await get_tree().process_frame

	var exit_dialog: ConfirmationDialog = null
	for child in get_tree().root.get_children():
		if child is ConfirmationDialog:
			exit_dialog = child
			break
	_check(exit_dialog != null, "战斗退出应弹出确认对话框")
	if exit_dialog != null:
		_check(exit_dialog.ok_button_text == "放弃并退出", "退出确认框应提示放弃本局收益")
		exit_dialog.queue_free()
		await get_tree().process_frame
	main.queue_free()
	await get_tree().process_frame


## 游戏大厅（v0.10.1）：侧栏底部"返回主菜单"→ goto_menu（主菜单），而非退出游戏。
func _test_hub_back_button() -> void:
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame

	var back_button: Button = null
	for button in _collect_buttons(hub):
		if button.text == "返回主菜单":
			back_button = button
			break
	_check(back_button != null, "游戏大厅应有返回主菜单按钮")
	if back_button != null:
		_check(not back_button.disabled, "返回主菜单按钮应可用")
		_check(back_button.pressed.get_connections().size() >= 1, "返回主菜单按钮应绑定跳转处理器")
	hub.queue_free()
	await get_tree().process_frame


## 主菜单（正常退出入口保留）："退出游戏"按钮仍存在并直接退出进程。
func _test_main_menu_quit() -> void:
	var menu := (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame

	var quit_button: Button = null
	for button in _collect_buttons(menu):
		if button.text == "退出游戏":
			quit_button = button
			break
	_check(quit_button != null, "主菜单应保留退出游戏按钮")
	menu.queue_free()
	await get_tree().process_frame


func _collect_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if root is Button:
		buttons.append(root)
	for child in root.get_children():
		buttons.append_array(_collect_buttons(child))
	return buttons


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = _profile_file + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	get_tree().paused = false
	if failures.is_empty():
		print("EXIT_FLOW_OK")
		get_tree().quit(0)
	else:
		print("EXIT_FLOW_FAILED: %d" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)