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
	_check(profile.has_character("liu_bei") and profile.has_character("guan_yu"), "新档应初始拥有刘备、关羽")

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

	# 难度写档（v0.14.1）：标准通关记录写入后困难难度解锁。
	_check(not GameFlow.is_difficulty_unlocked(profile, &"ch01_s01", Difficulty.HARD), "未通关标准前困难应锁定")
	profile.mark_stage_completed("ch01_s01", {"difficulty": "normal"})
	_check(GameFlow.is_difficulty_unlocked(profile, &"ch01_s01", Difficulty.HARD), "标准通关后困难难度应解锁")

	_check_layout(stages[0], false)
	for index in range(1, stages.size()):
		_check_layout(stages[index], true)
	return profile


## 布局规范抽查（GDD modules/STAGES.md 5.6，ch01_s02 起强制）。
func _check_layout(stage: StageData, enforce_spec: bool) -> void:
	var stage_tag := str(stage.stage_id)
	_check(stage.path_points.size() >= 2, "%s 应配置路径" % stage_tag)
	# 结构化建造位（v0.14.1）：优先 build_slots，旧配置回退 build_slot_positions。
	var slot_data := stage.get_build_slot_data()
	_check(slot_data.size() == stage.build_slot_count,
		"%s 建造位数量应与 build_slot_count 一致" % stage_tag)

	var curve := Curve2D.new()
	for point in stage.path_points:
		curve.add_point(point)
	var close_count := 0
	var far_count := 0
	for slot_entry in slot_data:
		var position := slot_entry.position
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

	# 建造位结构化试点（v0.14.1，GDD 5.1）：s08 配置预锁位 + 类型软引导。
	if stage.stage_id == &"ch01_s08":
		var locked_slot_count := 0
		var typed_slot_count := 0
		for slot_entry in slot_data:
			if slot_entry.locked:
				locked_slot_count += 1
			if slot_entry.slot_type != BuildSlotData.SlotType.ANY:
				typed_slot_count += 1
		_check(locked_slot_count >= 1, "s08 应配置预锁位试点")
		_check(typed_slot_count >= 3, "s08 应配置类型化建造位试点")


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
	_check(sidebar_buttons.size() == 6, "大厅侧栏应有 5 个功能入口 + 返回主菜单")
	var back_button_exists := sidebar_buttons.any(func(button: Button) -> bool: return button.text == "返回主菜单")
	_check(back_button_exists, "大厅侧栏应含返回主菜单按钮")

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
	# 界面排版重构（阶段 8 提交 4）：章节一行 + 关卡 2×4 网格 + 底部操作条，无滚动条。
	# v0.31.2：难度两档（标准/困难），按文本精确断言，避免按钮数随档位变化失效。
	var has_deploy := false
	var has_instant_clear := false
	var diff_name_count := 0
	for button in map_buttons:
		if button.text == "出 征":
			has_deploy = true
		elif button.text == "一键通关（测试）":
			has_instant_clear = true
		elif button.text == "标准" or button.text == "困难":
			diff_name_count += 1
	_check(map_buttons.size() >= 19 and has_deploy and has_instant_clear and diff_name_count == 2,
		"地图面板应包含章节行 + 8 关卡卡片 + 底部操作条（难度 2 档 + 出征 + 一键通关）")
	_check(disabled_count >= 12, "预留章节、未解锁关卡与未解锁难度应禁用")
	var map_scrolls := map_panel.find_children("*", "ScrollContainer", true, false)
	_check(map_scrolls.is_empty(), "地图面板应一屏展示无滚动条")
	var stage_card_count := 0
	for card in map_panel.find_children("*", "Button", true, false):
		if card.has_meta("stage_id"):
			stage_card_count += 1
	_check(stage_card_count == 8, "地图面板应展示第一章 8 关卡片（2×4 网格）")

	# 切换到武将养成面板
	_show_hub_panel(hub, &"develop")
	_check(develop_panel.visible and not map_panel.visible, "点击武将养成应切换内容区")
	var toggles := 0
	for button in _collect_buttons(develop_panel):
		if button.toggle_mode:
			toggles += 1
	_check(toggles == 2, "养成面板应列出 2 名初始武将（刘备/关羽）")
	# 武将图鉴（v0.11.3）：9 名角色全部可见，未解锁 7 名置灰标注获取方式
	var develop_buttons := _collect_buttons(develop_panel)
	var locked_count := 0
	for button in develop_buttons:
		if button.disabled and not button.toggle_mode:
			locked_count += 1
	print("PROBE develop_buttons=", develop_buttons.size(), " locked_disabled=", locked_count)
	_check(locked_count >= 7, "图鉴应显示 7 名未拥有武将（置灰）")
	# 转职分支候选（v0.17.0）：未转职时展示一转候选按钮，等级/材料不足应禁用。
	var promotion_buttons: Array = develop_panel.get("_promotion_buttons")
	var promote_button = promotion_buttons[0] if promotion_buttons.size() > 0 else null
	_check(promote_button != null and promote_button is Button and promote_button.disabled,
		"等级/材料不足时转职按钮应禁用")

	# 切换到设置面板
	_show_hub_panel(hub, &"settings")
	_check(settings_panel.visible and not develop_panel.visible, "点击设置应切换内容区")
	# 设置面板（v0.15.0）：大招手动释放开关存在且持久化。
	var manual_ultimate_check = settings_panel.get("_manual_ultimate_check")
	_check(manual_ultimate_check != null and manual_ultimate_check is CheckButton,
		"设置面板应含大招手动释放开关")
	if manual_ultimate_check is CheckButton:
		manual_ultimate_check.set_pressed(true)
		_check(GameFlow.is_gameplay_flag_enabled("manual_ultimate"),
			"勾选大招手动应写入 gameplay.manual_ultimate")
		manual_ultimate_check.set_pressed(false)
		_check(not GameFlow.is_gameplay_flag_enabled("manual_ultimate"),
			"取消勾选应清除手动大招标志")

	# 设置面板（v0.15.3）：自动开启下一波开关存在且持久化。
	var auto_next_wave_check = settings_panel.get("_auto_next_wave_check")
	_check(auto_next_wave_check != null and auto_next_wave_check is CheckButton,
		"设置面板应含自动开启下一波开关")
	if auto_next_wave_check is CheckButton:
		auto_next_wave_check.set_pressed(true)
		_check(GameFlow.is_gameplay_flag_enabled("auto_next_wave"),
			"勾选自动下一波应写入 gameplay.auto_next_wave")
		auto_next_wave_check.set_pressed(false)
		_check(not GameFlow.is_gameplay_flag_enabled("auto_next_wave"),
			"取消勾选应清除自动下一波标志")
	# 背包页签（v0.15.1）：查看道具 + 测试发放练兵令。
	var inventory_panel := hub.get_node("Columns/Content/InventoryPanel")
	_show_hub_panel(hub, &"inventory")
	_check(inventory_panel.visible and not settings_panel.visible, "点击背包应切换内容区")
	var grant_button: Button = null
	for button in _collect_buttons(inventory_panel):
		if button.text == "获得练兵令 ×10":
			grant_button = button
			break
	_check(grant_button != null, "背包面板应含测试发放按钮")
	if grant_button != null:
		grant_button.pressed.emit()
		await get_tree().process_frame
		_check(int(profile.items.get("exp_scroll", 0)) == 10, "测试发放应写入 10 枚练兵令")

	# 难度选择（v0.16.0 修复）：面板难度更新 _selected_difficulty，并随一键通关按所选难度写档。
	_show_hub_panel(hub, &"map")
	# 界面排版重构（v0.27.0）：默认选中首个已解锁关卡（s01），一键通关在底部操作条。
	var clear_button: Button = null
	for button in _collect_buttons(map_panel):
		if button.text == "一键通关（测试）":
			clear_button = button
			break
	_check(clear_button != null, "地图面板底部操作条应有一键通关按钮")
	map_panel._on_difficulty_changed(true, Difficulty.HARD)
	_check(int(map_panel.get("_selected_difficulty")) == Difficulty.HARD,
		"选择困难应更新地图面板所选难度")
	if clear_button != null:
		clear_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		var s01_entry = profile.stage_progress.get("ch01_s01", {})
		_check(s01_entry is Dictionary and s01_entry.get("completed", false),
			"一键通关应标记 s01 已通关并写档")
		_check(GameFlow.is_stage_unlocked(profile, GameFlow.load_stage_data(&"ch01_s02")),
			"一键通关 s01 后应解锁 s02")
		var s01_diffs: Dictionary = s01_entry.get("difficulties", {})
		_check(s01_diffs.has(Difficulty.key_name(Difficulty.HARD)),
			"一键通关应按所选困难难度写档")

	# 难度两档化（v0.31.2）+ 出征直达编队（v0.33.1）：难度切换仅标准/困难；
	# 出征点击直接发 stage_selected——v0.31.2 确认弹窗已删除，防误触确认收敛到编队页。
	var diff_buttons: Array[Button] = []
	for button in _collect_buttons(map_panel):
		if button.text == "标准" or button.text == "困难":
			diff_buttons.append(button)
	_check(diff_buttons.size() == Difficulty.count() and diff_buttons.size() == 2,
		"难度切换应只有标准/困难两档（随 difficulty_presets 扩展）")
	var deploy_button: Button = null
	for button in _collect_buttons(map_panel):
		if button.text == "出 征":
			deploy_button = button
			break
	_check(map_panel.get("_deploy_confirm") == null, "地图面板不应再挂载出征确认框（v0.33.1 直达编队）")
	if deploy_button != null:
		var emitted: Array = []
		var capture := func(stage_id: StringName, difficulty: int) -> void:
			emitted.append([stage_id, difficulty])
		for conn in map_panel.stage_selected.get_connections():
			map_panel.stage_selected.disconnect(conn["callable"])
		map_panel.stage_selected.connect(capture)
		deploy_button.pressed.emit()
		await get_tree().process_frame
		_check(emitted.size() == 1 and emitted[0][0] == &"ch01_s01"
			and int(emitted[0][1]) == Difficulty.HARD,
			"点击出征应直接发出 stage_selected（当前所选关卡与难度，不弹确认框）")

	hub.queue_free()
	await get_tree().process_frame


func _show_hub_panel(hub: Node, panel_id: StringName) -> void:
	hub._show_panel(panel_id)


func _test_squad_select_screen() -> void:
	# 编队以"新档"为前置（v0.15.1：前置背包/一键通关测试会改动共享档，此处重建新档，
	# 保证"初始武将"断言不受污染）。
	var fresh_profile := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(fresh_profile)
	GameFlow.select_stage(&"ch01_s01")
	GameFlow.set_squad([] as Array[String])
	GameFlow.set_squad_relics([] as Array[String])
	var scene := (load("res://scenes/SquadSelect.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame

	var toggles: Array[Button] = []
	for button in _collect_buttons(scene):
		if button.toggle_mode:
			toggles.append(button)
	_check(toggles.size() == 2, "新档编队界面应展示 2 名初始武将（刘备/关羽）")
	_check((scene.get_child(0) as Control).size == get_viewport().get_visible_rect().size, "编队界面背景应铺满视口")
	var start_button := scene.get("_start_button") as Button
	_check(start_button != null and start_button.disabled, "未选择武将时「确认出战」应禁用")
	var has_back := false
	for button in _collect_buttons(scene):
		if button.text == "返回选关":
			has_back = true
	_check(has_back, "编队页应提供「返回选关」按钮")
	for toggle in toggles:
		toggle.set_pressed(true)
	await get_tree().process_frame
	_check(toggles.all(func(button: Button) -> bool: return not button.disabled),
		"未达编队上限时所有武将可勾选")
	_check(start_button != null and not start_button.disabled, "已选武将后「确认出战」应可用")
	_check(toggles.all(func(button: Button) -> bool: return button.custom_minimum_size.x >= 232.0),
		"武将卡片宽 232px（B-020 防选中态标签裁剪）")
	_check(toggles.any(func(button: Button) -> bool: return button.text.contains("2/3")),
		"选中刘/关后卡片羁绊标签应实时刷新为 2/3（B-020）")

	# 编队记忆（v0.33.1）：发放遗物并把上次出战配置写入档案，重建界面应自动预填。
	fresh_profile.add_item("wolf_tooth", 1)
	fresh_profile.add_item("iron_shield", 1)
	GameFlow.set_squad(["liu_bei", "guan_yu"] as Array[String])
	GameFlow.set_squad_relics(["wolf_tooth"] as Array[String])
	GameFlow.save_squad_to_profile(fresh_profile)
	GameFlow.save_squad_relics_to_profile(fresh_profile)
	ProfileStore.save_profile(fresh_profile)
	scene.queue_free()
	await get_tree().process_frame

	var scene2 := (load("res://scenes/SquadSelect.tscn") as PackedScene).instantiate()
	add_child(scene2)
	await get_tree().process_frame
	var remembered_ids: Array = scene2.get("_selected_ids")
	_check(remembered_ids.size() == 2 and remembered_ids.has("liu_bei") and remembered_ids.has("guan_yu"),
		"再次进入编队应自动预填上次出战的武将（刘备/关羽）")
	var remembered_relics: Array = scene2.get("_selected_relic_ids")
	_check(remembered_relics.size() == 1 and remembered_relics.has("wolf_tooth"),
		"再次进入编队应自动预填上次选带的遗物（狼牙符）")
	var start_button2 := scene2.get("_start_button") as Button
	_check(start_button2 != null and not start_button2.disabled, "预填编队后「确认出战」应可用")
	start_button2.pressed.emit()
	await get_tree().process_frame
	var confirm_dialog: ConfirmationDialog = scene2.get("_confirm_dialog")
	_check(confirm_dialog != null and confirm_dialog.visible, "点击「确认出战」应弹出二次确认弹窗")
	_check(confirm_dialog.dialog_text.contains("刘备") and confirm_dialog.dialog_text.contains("关羽"),
		"确认弹窗应展示出战武将名单")
	_check(confirm_dialog.dialog_text.contains("狼牙符") and confirm_dialog.dialog_text.contains("永久使用"),
		"确认弹窗应展示遗物清单与永久使用说明")
	confirm_dialog.hide()
	scene2.queue_free()
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
	# 剧情展示期间地图应保持可交互（拖拽建造照常可用，v0.33.3）。
	var build_manager_flow := main.get_node("BuildManager")
	var battle_character_id_flow: String = str(GameFlow.squad_character_ids[0])
	var battle_character_flow := GameFlow.load_character_data(battle_character_id_flow)
	_check(battle_character_flow != null, "出战武将数据应可加载")
	if battle_character_flow != null:
		GameManager.gold = 9999
		_check(build_manager_flow.begin_drag(battle_character_flow), "剧情展示期间应能开始拖拽建造")
		build_manager_flow.cancel_drag()
		_check(not build_manager_flow.is_dragging(), "剧情展示期间取消拖拽应生效")
	dialogue_ui.skip_dialogue()
	_check(not dialogue_layer.visible, "跳过后对话层应关闭")
	var grid_bg := main.get_node("GridBackground") as GridBackground
	_check(grid_bg.theme_name == &"fire", "s02 应应用火攻主题")
	_check(main.get_node_or_null("BuildSlots") == null, "v0.33.3 起战场不应生成 BuildSlots 节点")
	_check(get_tree().get_nodes_in_group("build_slots").is_empty(), "v0.33.3 起战场不应生成建造位")
	_check(GameManager.total_waves == 6, "s02 应有 6 波敌人")

	# 退出导航（v0.15.2）：顶栏退出弹确认框（确认后回游戏大厅，不直接退出）。
	var exit_button_flow := main.get_node("UI/Root/TopBar/Margin/Content/ExitButton") as Button
	exit_button_flow.pressed.emit()
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

	# 自动开启下一波（v0.15.3）：开启后波次结束自动开下一波，关闭时保持手动等待。
	GameFlow.set_gameplay_flag("auto_next_wave", true)
	GameManager.start_wave()
	main._on_wave_completed()
	_check(GameManager.is_wave_active and GameManager.current_wave == 1,
		"开启自动下一波后，波次结束应立即开始下一波")
	GameFlow.set_gameplay_flag("auto_next_wave", false)
	main._on_wave_completed()
	_check(not GameManager.is_wave_active and GameManager.current_wave == 2,
		"关闭自动下一波后，波次结束应停在等待手动开启")

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

