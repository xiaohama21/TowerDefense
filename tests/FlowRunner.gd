extends Node

## 阶段 1 流程测试：关卡解锁逻辑、布局规范抽查、选关/编队界面、战斗入场参数。
## 使用一次性隔离存档槽，不触碰玩家真实存档（模式同 Stage0Runner）。

var failures: Array[String] = []
var _profile_file := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.flow_runner_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FLOW_TEST: %s" % message)


func _run() -> void:
	var profile := _test_unlock_logic()
	_test_stage_select_screen(profile)
	_test_squad_select_screen()
	_test_battle_entry()
	_cleanup()
	_finish()


func _test_unlock_logic() -> PlayerProfile:
	var profile := ProfileStore.create_new_profile(false)
	_check(profile != null, "应能创建新档")
	if profile == null:
		return null
	GameFlow.ensure_initial_characters(profile)
	_check(profile.has_character("liu_bei") and profile.has_character("guan_yu"), "新档应获得初始武将")

	var s01 := GameFlow.load_stage_data(&"ch01_s01")
	var s02 := GameFlow.load_stage_data(&"ch01_s02")
	var s03 := GameFlow.load_stage_data(&"ch01_s03")
	_check(s01 != null and s02 != null and s03 != null, "第一章前三关数据应可加载")
	if s01 == null or s02 == null or s03 == null:
		return profile

	_check(GameFlow.is_stage_unlocked(profile, s01), "首关应默认解锁")
	_check(not GameFlow.is_stage_unlocked(profile, s02), "未通关首关时第二关应锁定")
	profile.mark_stage_completed("ch01_s01")
	_check(GameFlow.is_stage_unlocked(profile, s02), "通关首关后第二关应解锁")
	_check(not GameFlow.is_stage_unlocked(profile, s03), "第二关未通关时第三关应锁定")

	_check(GameFlow.get_next_stage_id(&"ch01_s01") == StringName("ch01_s02"), "首关的下一关应为第二关")
	_check(GameFlow.get_next_stage_id(&"ch01_s03") == StringName(&""), "末关应无下一关")

	_check_layout(s01, false)
	_check_layout(s02, true)
	_check_layout(s03, true)
	return profile


## 布局规范抽查（GDD modules/STAGES.md 5.6，ch01_s02 起强制）。
func _check_layout(stage: StageData, enforce_spec: bool) -> void:
	var stage_tag := str(stage.stage_id)
	_check(stage.path_points.size() >= 2, "%s 应配置路径" % stage_tag)
	_check(stage.build_slot_positions.size() == stage.build_slot_count,
		"%s 建造位数量应与 build_slot_count 一致" % stage_tag)

	var curve := Curve2D.new()
	for point in stage.path_points:
		curve.add_point(point)
	var close_count := 0
	var far_count := 0
	for position in stage.build_slot_positions:
		var distance: float = position.distance_to(curve.get_closest_point(position))
		_check(distance >= 70.0 and distance <= 250.0, "%s 建造位应贴邻道路网格" % stage_tag)
		if distance <= 90.0:
			close_count += 1
		if distance >= 150.0:
			far_count += 1

	var road_cells := GridBackground.derive_road_cells(stage.path_points)
	var corners := 0
	for index in range(1, road_cells.size() - 1):
		if road_cells[index] - road_cells[index - 1] != road_cells[index + 1] - road_cells[index]:
			corners += 1

	if enforce_spec:
		_check(road_cells.size() >= 24, "%s 路径总格数应 ≥ 24" % stage_tag)
		_check(corners >= 2, "%s 至少 2 个转角" % stage_tag)
		_check(close_count >= 3, "%s 贴路位应 ≥ 3" % stage_tag)
		_check(far_count >= 3, "%s 中远程位应 ≥ 3" % stage_tag)


func _collect_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if root is Button:
		buttons.append(root)
	for child in root.get_children():
		buttons.append_array(_collect_buttons(child))
	return buttons


func _test_stage_select_screen(profile: PlayerProfile) -> void:
	var scene := (load("res://scenes/StageSelect.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame

	var buttons := _collect_buttons(scene)
	_check(buttons.size() == 4, "选关界面应有 3 个关卡行 + 1 个返回按钮")
	if buttons.size() == 4:
		_check(not buttons[0].disabled, "第一关应可点击")
		_check(not buttons[1].disabled, "通关首关后第二关应可点击")
		_check(buttons[2].disabled, "第三关应保持锁定")
	_check(scene.get_child_count() > 0, "选关界面应完成构建")
	scene.queue_free()


func _test_squad_select_screen() -> void:
	GameFlow.select_stage(&"ch01_s01")
	GameFlow.set_squad([] as Array[String])
	var scene := (load("res://scenes/SquadSelect.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame

	var toggles: Array[Button] = []
	for button in _collect_buttons(scene):
		if button.toggle_mode:
			toggles.append(button)
	_check(toggles.size() == 2, "新档编队界面应展示 2 名初始武将")
	for toggle in toggles:
		toggle.set_pressed(true)
	await get_tree().process_frame
	_check(toggles.all(func(button: Button) -> bool: return not button.disabled),
		"未达编队上限时所有武将可勾选")
	scene.queue_free()
	await get_tree().process_frame


func _test_battle_entry() -> void:
	GameFlow.select_stage(&"ch01_s02")
	GameFlow.set_squad(["liu_bei"] as Array[String])
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var stage_label := main.get_node("UI/Root/TopBar/Margin/Content/StageLabel") as Label
	_check(stage_label.text == "长社火攻", "战斗界面应展示 GameFlow 选中的关卡")
	_check(main.get_node_or_null("UI/Root/TopBar/Margin/Content/ExitButton") != null,
		"战斗顶栏应有退出按钮")
	var character_bar := main.get_node("UI/Root/CharacterBar") as HBoxContainer
	_check(character_bar.get_child_count() == 1, "编队过滤后建造栏应只含出战武将")
	_check(get_tree().get_nodes_in_group("build_slots").size() == 10, "s02 应由布局数据生成 10 个建造位")
	_check(GameManager.total_waves == 6, "s02 应有 6 波敌人")

	main.queue_free()
	await get_tree().process_frame
	GameFlow.select_stage(&"ch01_s01")
	GameFlow.set_squad([] as Array[String])


func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = _profile_file + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	get_tree().paused = false
	if failures.is_empty():
		print("FLOW_TEST_OK")
		get_tree().quit(0)
	else:
		print("FLOW_TEST_FAILED: %d" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)
