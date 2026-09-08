extends Node

## 回归测试（v0.32.2 / 程序 0.8.7.2）：武将一转确认弹窗可正常弹出/取消/确认
## （v0.32.2 修复前使用 Godot 3 旧信号名 cancelled，点击一转即报 Invalid access
## 'cancelled'，弹窗无法弹出）。使用一次性隔离存档槽，不触碰玩家真实存档。

var failures: Array[String] = []
var _profile_file := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.promote_dialog_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("PROMOTE_DIALOG: %s" % message)


func _find_visible_dialog(panel: Node) -> ConfirmationDialog:
	for child in panel.get_children():
		if child is ConfirmationDialog and child.visible:
			return child
	return null

func _run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(profile)
	_check(profile.has_character("guan_yu"), "新档应初始拥有关羽")

	# 关羽升至 10 级并备齐 10 黄巾布，满足一转（铁骑）条件。
	var target_total := LevelCurve.exp_total_for_level(10)
	var current_total := profile.get_character_exp("guan_yu")
	if current_total < target_total:
		profile.add_character_exp("guan_yu", target_total - current_total)
	profile.add_item("yellow_turban_cloth", 10)
	ProfileStore.save_profile(profile)
	_check(GameFlow.get_character_level(profile, "guan_yu") == 10,
		"关羽应升至 10 级（实际 %d）" % GameFlow.get_character_level(profile, "guan_yu"))

	var candidates := GameFlow.get_promotion_candidates(profile, "guan_yu")
	_check(candidates.size() == 1, "未转职关羽应只有 1 个一转候选（实际 %d）" % candidates.size())
	if candidates.is_empty():
		_cleanup()
		_finish()
		return

	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	var develop_panel := hub.get_node("HubPanel/Columns/Content/DevelopPanel")
	hub._show_panel(&"develop")
	await get_tree().process_frame
	develop_panel._on_character_pressed("guan_yu")
	await get_tree().process_frame

	# 场景 1：点击一转按钮 → 确认弹窗须可见（修复前连到 Godot 3 旧信号 cancelled，
	# 弹窗弹出即抛 Invalid access，永远无法出现）。
	develop_panel._on_promote_pressed(candidates[0])
	await get_tree().process_frame
	var dialog := _find_visible_dialog(develop_panel)
	_check(dialog != null, "点击一转后应弹出确认弹窗（实际无可见弹窗）")
	if dialog == null:
		hub.queue_free()
		_cleanup()
		_finish()
		return

	# 场景 2：取消 → 弹窗关闭且不写入转职。
	var cloth_before := int(profile.items.get("yellow_turban_cloth", 0))
	dialog.canceled.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(GameFlow.get_active_promotion(profile, "guan_yu") == null, "取消后不应写入转职")
	_check(not is_instance_valid(dialog), "取消后弹窗应被释放")
	_check(int(profile.items.get("yellow_turban_cloth", 0)) == cloth_before, "取消后不应扣除黄巾布")

	# 场景 3：右上角关闭（close_requested）→ 弹窗关闭且不写入转职。
	develop_panel._on_promote_pressed(candidates[0])
	await get_tree().process_frame
	var close_dialog := _find_visible_dialog(develop_panel)
	_check(close_dialog != null, "再次点击一转应重新弹出确认弹窗")
	if close_dialog == null:
		hub.queue_free()
		_cleanup()
		_finish()
		return
	close_dialog.close_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(GameFlow.get_active_promotion(profile, "guan_yu") == null, "关闭弹窗后不应写入转职")
	_check(not is_instance_valid(close_dialog), "关闭弹窗后弹窗应被释放")

	# 场景 4：确认 → 写入关羽 promotion_path（铁骑）并按成本扣除材料。
	develop_panel._on_promote_pressed(candidates[0])
	await get_tree().process_frame
	var confirm_dialog := _find_visible_dialog(develop_panel)
	_check(confirm_dialog != null, "第三次点击一转应重新弹出确认弹窗")
	if confirm_dialog == null:
		hub.queue_free()
		_cleanup()
		_finish()
		return
	confirm_dialog.confirmed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var active := GameFlow.get_active_promotion(profile, "guan_yu")
	_check(active != null and str(active.promotion_id) == "cavalry_iron_rider",
		"确认后关羽转职应为铁骑（实际：%s）" % (str(active.promotion_id) if active != null else "null"))
	_check(int(profile.items.get("yellow_turban_cloth", 0)) == cloth_before - 10,
		"确认转职后应恰好扣除 10 黄巾布（实际剩余 %d）" % int(profile.items.get("yellow_turban_cloth", 0)))

	hub.queue_free()
	_cleanup()
	_finish()


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = _profile_file + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	if failures.is_empty():
		print("PROMOTE_DIALOG_OK")
		get_tree().quit(0)
	else:
		print("PROMOTE_DIALOG_FAILED: %d" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)