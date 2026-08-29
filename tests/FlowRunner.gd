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
	# 各测试函数含 await，必须逐个等待，否则 _finish 会在断言执行前提前退出。
	await _test_hub(profile)
	await _test_squad_select_screen()
	await _test_battle_entry()
	_cleanup()
	_finish()


func _test_unlock_logic() -> PlayerProfile:
	var profile := ProfileStore.create_new_profile(false)
	_check(profile != null, "应能创建新档")
	if profile == null:
		return null
	GameFlow.ensure_initial_characters(profile)
	_check(profile.has_character("liu_bei") and profile.has_character("guan_yu"), "新档应获得初始武将")

	var stage_ids := [&"ch01_s01", &"ch01_s02", &"ch01_s03", &"ch01_s04", &"ch01_s05", &"ch01_s06", &"ch01_s07", &"ch01_s08"]
	var stages: Array[StageData] = []
	for stage_id in stage_ids:
		stages.append(GameFlow.load_stage_data(stage_id))
	_check(stages.all(func(stage: StageData) -> bool: return stage != null), "第一章八关数据应可加载")
	if stages.any(func(stage: StageData) -> bool: return stage == null):
		return profile
	var s01 := stages[0]
	var s02 := stages[1]
	var s03 := stages[2]

	_check(GameFlow.is_stage_unlocked(profile, s01), "首关应默认解锁")
	_check(not GameFlow.is_stage_unlocked(profile, s02), "未通关首关时第二关应锁定")
	profile.mark_stage_completed("ch01_s01")
	_check(GameFlow.is_stage_unlocked(profile, s02), "通关首关后第二关应解锁")
	_check(not GameFlow.is_stage_unlocked(profile, s03), "第二关未通关时第三关应锁定")

	_check(GameFlow.get_next_stage_id(&"ch01_s01") == StringName("ch01_s02"), "首关的下一关应为第二关")
	_check(GameFlow.get_next_stage_id(&"ch01_s08") == StringName(&""), "末关（s08）应无下一关")

	_check_layout(stages[0], false)
	for index in range(1, stages.size()):
		_check_layout(stages[index], true)
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


## 游戏大厅（GDD v0.10.1）：左侧功能面板 + 内容区页签切换；
## 地图面板含章节预留占位与关卡解锁；养成面板等级/材料不足时转职禁用。
func _test_hub(profile: PlayerProfile) -> void:
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame

	var sidebar_buttons := _collect_buttons(hub.get_node("Columns/Sidebar/SidebarMargin/SidebarBox"))
	_check(sidebar_buttons.size() == 4, "大厅侧栏应有 3 个功能入口 + 返回主菜单")

	var map_panel := hub.get_node("Columns/Content/MapPanel")
	var develop_panel := hub.get_node("Columns/Content/DevelopPanel")
	var settings_panel := hub.get_node("Columns/Content/SettingsPanel")
	_check(map_panel.visible and not develop_panel.visible and not settings_panel.visible,
		"大厅默认应显示地图选择面板")
	# 布局回归（v0.10.2）：set_anchors_preset 曾导致容器 0×0 钉在原点。
	var viewport_size := get_viewport().get_visible_rect().size
	_check(hub.get_node("Columns").size == viewport_size, "大厅布局应铺满视口")

	var map_buttons := _collect_buttons(map_panel)
	var disabled_count := 0
	for button in map_buttons:
		if button.disabled:
			disabled_count += 1
	# 8 个关卡行（解锁用例已标记首关通关，故第二关解锁，第三~八关锁定）
	# + 6 个预留章节占位（第二~七章）+ 1 个当前章节展示钮 → 禁用数 = 13
	_check(map_buttons.size() == 15, "地图面板应有 7 个章节行（1 可用 + 6 预留）+ 8 个关卡行")
	_check(disabled_count == 13, "预留章节、章节展示钮与未解锁关卡应禁用，其余可点")

	# 切换到武将养成面板
	_show_hub_panel(hub, &"develop")
	_check(develop_panel.visible and not map_panel.visible, "点击武将养成应切换内容区")
	var toggles := 0
	for button in _collect_buttons(develop_panel):
		if button.toggle_mode:
			toggles += 1
	_check(toggles == 2, "养成面板应列出 2 名初始武将")
	# 武将图鉴（v0.11.3）：9 名角色全部可见，未解锁 7 名置灰标注获取方式
	var develop_buttons := _collect_buttons(develop_panel)
	var locked_count := 0
	for button in develop_buttons:
		if button.disabled and not button.toggle_mode:
			locked_count += 1
	print("PROBE develop_buttons=", develop_buttons.size(), " locked_disabled=", locked_count)
	_check(locked_count >= 7, "图鉴应显示 7 名未解锁武将（置灰）")
	var promote_button = develop_panel.get("_promotion_button")
	_check(promote_button != null and promote_button.disabled,
		"等级/材料不足时转职按钮应禁用")

	# 切换到设置面板
	_show_hub_panel(hub, &"settings")
	_check(settings_panel.visible and not develop_panel.visible, "点击设置应切换内容区")

	hub.queue_free()
	await get_tree().process_frame


func _show_hub_panel(hub: Node, panel_id: StringName) -> void:
	hub._show_panel(panel_id)


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
	_check((scene.get_child(0) as Control).size == get_viewport().get_visible_rect().size, "编队界面背景应铺满视口")
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
	# 布局回归（v0.10.2）：结算弹窗承载容器必须铺满屏幕，居中才成立。
	var result_center := main.get_node("UI/Root/ResultCenter") as CenterContainer
	_check(result_center != null and result_center.size == get_viewport().get_visible_rect().size,
		"结算弹窗承载容器应铺满视口（保证居中）")
	# 剧情对话（v0.12）：战斗开场播放；v0.12.3 修复——对话层不拦截地图点击，
	# 防抖内连点不跳行、冷却后单击推进、跳过关闭。
	var dialogue_layer := main.get_node("UI/Root/DialogueLayer")
	var dialogue_ui := main.get_node("UI")
	_check(dialogue_layer != null and dialogue_layer.visible, "战斗开场应播放剧情对话层")
	_check(dialogue_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"对话层不应拦截地图点击（v0.12.3）")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	dialogue_ui._on_dialogue_input(click)
	_check(int(dialogue_ui.get("_dialogue_index")) == 0, "防抖窗口内连点不应跳行")
	await get_tree().create_timer(0.25).timeout
	dialogue_ui._on_dialogue_input(click)
	_check(int(dialogue_ui.get("_dialogue_index")) == 1, "防抖后单击应推进一行")
	dialogue_ui._on_dialogue_input(click)
	_check(int(dialogue_ui.get("_dialogue_index")) == 1, "180ms 防抖内的紧连点击应被拦截")
	await get_tree().create_timer(0.25).timeout
	dialogue_ui._on_dialogue_input(click)
	_check(int(dialogue_ui.get("_dialogue_index")) == 2, "防抖窗口过后单击应继续推进")
	# 剧情展示期间地图应保持可交互（建造待确认照常工作）
	var build_manager_flow := main.get_node("BuildManager")
	build_manager_flow._on_build_requested(main.get_node("BuildSlots").get_child(0))
	_check(build_manager_flow.pending_slot != null, "剧情展示期间应能点选建造位")
	build_manager_flow.cancel_pending()
	dialogue_ui.skip_dialogue()
	_check(not dialogue_layer.visible, "跳过后对话层应关闭")
	var grid_bg := main.get_node("GridBackground") as GridBackground
	_check(grid_bg.theme_name == &"fire", "s02 应应用火攻主题")
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
