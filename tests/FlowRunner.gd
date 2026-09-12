extends Node

## 阶段 1 流程测试：关卡解锁逻辑、布局规范抽查、选关/编队界面、战斗入场参数。
## 使用一次性隔离存档槽，不触碰玩家真实存档（模式同 Stage0Runner）。

var failures: Array[String] = []
var _profile_file := ""
## 设置隔离（B-054 顺带修复）：开场对话用例依赖 skip_dialogue 关闭，但 user://settings.cfg
## 是全局用户设置（剧情速进可能被玩家开启）——跑前强制关闭、_cleanup 还原，避免用例被用户设置污染。
var _saved_skip_dialogue: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.flow_runner_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	_saved_skip_dialogue = GameFlow.is_gameplay_flag_enabled("skip_dialogue")
	GameFlow.set_gameplay_flag("skip_dialogue", false)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FLOW_TEST: %s" % message)


func _run() -> void:
	var profile := _test_unlock_logic()
	# 各测试函数含 await，必须逐个等待，否则 _finish 会在断言执行前提前退出。
	await _test_hub(profile)
	await _test_encyclopedia(profile)
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

	var sidebar_buttons := _collect_buttons(hub.get_node("HubPanel/Columns/Sidebar/SidebarMargin/SidebarBox"))
	_check(sidebar_buttons.size() == 7, "大厅侧栏应有 6 个功能入口 + 返回主菜单（v0.34 百科入列）")
	var back_button_exists := sidebar_buttons.any(func(button: Button) -> bool: return button.text == "返回主菜单")
	_check(back_button_exists, "大厅侧栏应含返回主菜单按钮")

	var map_panel := hub.get_node("HubPanel/Columns/Content/MapPanel")
	var develop_panel := hub.get_node("HubPanel/Columns/Content/DevelopPanel")
	var settings_panel := hub.get_node("HubPanel/Columns/Content/SettingsPanel")
	_check(map_panel.visible and not develop_panel.visible and not settings_panel.visible,
		"大厅默认应显示地图选择面板")
	# 布局回归（v0.10.2）：set_anchors_preset 曾导致容器 0×0 钉在原点。

	_check(hub.get_node("HubPanel/Columns").size == hub.get_node("HubPanel").size, "大厅 Columns 应铺满 HubPanel（v0.10.2 回归，GameHub 换肤后加 HubPanel 包裹）")

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
		if button.text == "出征 · 编队":
			has_deploy = true
		elif button.text == "一键通关(测试)":
			has_instant_clear = true
		elif button.text == "标准" or button.text == "困难":
			diff_name_count += 1
	_check(map_buttons.size() >= 13 and has_deploy and has_instant_clear and diff_name_count == 2,
		"地图面板应包含章节行 + 8 关卡卡片 + 底部操作条（难度 2 档 + 出征·编队 + 一键通关）")
	_check(disabled_count == 6, "未解锁的 s03~s08 六关卡片应禁用")
	var map_scrolls := map_panel.find_children("*", "ScrollContainer", true, false)
	_check(map_scrolls.is_empty(), "地图面板应一屏展示无滚动条")
	var stage_card_count := 0
	for card in map_panel.find_children("*", "Button", true, false):
		if card.has_meta("stage_id"):
			stage_card_count += 1
	_check(stage_card_count == 8, "地图面板应展示第一章 8 关卡片（2×4 网格）")

	# 底部关卡预告条自适应回归（B-054 / 0.8.11.3）：逐关切换，详情条所有内容控件
	# 不得越出面板（首通奖励/敌人列表长度不同曾把右列撑出面板甚至视口，s03/s06~s08）。
	var detail_panel: Control = map_panel.get("_detail_panel")
	var vp_rect := map_panel.get_viewport().get_visible_rect()
	# 扫描会逐关切换选中态，结束后还原（后续步骤依赖 s01 默认选中 / 难度状态）。
	var saved_scan_stage: StageData = map_panel.get("_selected_stage")
	var saved_scan_diff: int = map_panel.get("_selected_difficulty")
	for hub_stage_id in [&"ch01_s01", &"ch01_s02", &"ch01_s03", &"ch01_s04",
			&"ch01_s05", &"ch01_s06", &"ch01_s07", &"ch01_s08"]:
		var hub_stage: StageData = GameFlow.load_stage_data(hub_stage_id)
		if hub_stage == null:
			continue
		map_panel._select_stage(hub_stage)
		await get_tree().process_frame
		await get_tree().process_frame
		var det_rect: Rect2 = detail_panel.get_global_rect()
		var inside := vp_rect.encloses(det_rect)
		var worst := ""
		for probe_child in detail_panel.find_children("*", "", true, false):
			var probe_ctl := probe_child as Control
			if probe_ctl == null or not probe_ctl.is_visible_in_tree():
				continue
			var probe_rect: Rect2 = probe_ctl.get_global_rect()
			if probe_rect.size.x <= 0.0 or probe_rect.size.y <= 0.0:
				continue
			if not det_rect.encloses(probe_rect):
				inside = false
				worst = "%s rect=%s" % [probe_ctl.get_class(), str(probe_rect)]
				break
		_check(inside, "%s 关卡预告条内容不得越出详情面板/视口（B-054）%s" % [str(hub_stage_id), worst])
	if saved_scan_stage != null:
		map_panel._select_stage(saved_scan_stage)
		map_panel.set("_selected_difficulty", saved_scan_diff)
		await get_tree().process_frame

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
	# 转职候选（v0.35.3+ 收纳）：收敛至职业页签「转职详情 ▸」叠层——切职业页 →
	# 打开叠层后应展示一转候选按钮，新档 Lv1 未达门槛应禁用。
	var develop_tabs = develop_panel.get("_tab_container")
	_check(develop_tabs != null, "养成面板应含页签容器")
	if develop_tabs != null:
		develop_tabs.current_tab = 1  # 页签序：技能 / 职业 / 信物 / 特性
		await get_tree().process_frame
	var detail_button: Button = null
	for button in _collect_buttons(develop_panel):
		if button.text.begins_with("转职详情"):
			detail_button = button
			break
	_check(detail_button != null, "职业页签应含「转职详情 ▸」入口")
	if detail_button != null:
		detail_button.pressed.emit()
		await get_tree().process_frame
		var promotion_buttons: Array = develop_panel.get("_promotion_buttons")
		var promote_button = promotion_buttons[0] if promotion_buttons.size() > 0 else null
		_check(promote_button != null and promote_button is Button and promote_button.disabled,
			"等级/材料不足时转职按钮应禁用")
		develop_panel._close_promotion_overlay()
		await get_tree().process_frame

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
	var inventory_panel := hub.get_node("HubPanel/Columns/Content/InventoryPanel")
	_show_hub_panel(hub, &"inventory")
	_check(inventory_panel.visible and not settings_panel.visible, "点击背包应切换内容区")
	# 背包版式 v0.37.11（对照概念图 ui_inventory）：顶栏无资源胶囊、类目收敛、
	# 网格入滚动容器（超高滚动兜底）；空类目出空态提示不崩溃。
	var inventory_topbar := inventory_panel.get_child(0) as HBoxContainer
	_check(inventory_topbar != null, "背包顶栏应存在")
	if inventory_topbar != null:
		var top_texts: Array[String] = []
		for child in inventory_topbar.get_children():
			if child is Label:
				top_texts.append((child as Label).text)
		_check(not top_texts.any(func(t: String) -> bool:
			return t.begins_with("黄巾布") or t.begins_with("练兵令")),
			"背包顶栏应无资源胶囊（黄巾布/练兵令）")
	var inventory_filter_row := inventory_panel.get_child(1) as HBoxContainer
	var filter_texts: Array[String] = []
	if inventory_filter_row != null:
		for child in inventory_filter_row.get_children():
			if child is Button:
				filter_texts.append((child as Button).text)
	_check(filter_texts == ["全部", "材料", "消耗品", "遗物"],
		"背包类目 chips 应收敛为 全部/材料/消耗品/遗物，实际 %s" % [filter_texts])
	var inventory_scroll := inventory_panel.get_node_or_null("GridScroll") as ScrollContainer
	_check(inventory_scroll != null, "背包网格应包在 GridScroll 滚动容器内")
	if inventory_scroll != null and inventory_scroll.get_child_count() > 0:
		_check(inventory_scroll.get_child(0) is GridContainer, "GridScroll 内应含道具网格")
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
	# 空类目（遗物未发放前为空）：网格空态 + 底部说明条提示；切回全部恢复卡片。
	inventory_panel._on_category_pressed(int(inventory_panel.FILTER_TYPES[2]))
	await get_tree().process_frame
	var empty_cards := 0
	var empty_grid := inventory_panel.get_node_or_null("GridScroll") as ScrollContainer
	if empty_grid != null and empty_grid.get_child_count() > 0:
		var grid_node := empty_grid.get_child(0) as GridContainer
		if grid_node != null:
			for card in grid_node.get_children():
				if card is Button:
					empty_cards += 1
	_check(empty_cards == 0, "空类目网格不应渲染道具卡")
	var inventory_detail_box := inventory_panel.get("_detail_box") as VBoxContainer
	if inventory_detail_box != null:
		var empty_hint := false
		for child in inventory_detail_box.get_children():
			if child is Label and "暂无道具" in (child as Label).text:
				empty_hint = true
		_check(empty_hint, "空类目应在底部说明条提示暂无道具")
	inventory_panel._on_category_pressed(-1)
	await get_tree().process_frame
	var restored_cards := 0
	var restored_grid := inventory_panel.get_node_or_null("GridScroll") as ScrollContainer
	if restored_grid != null and restored_grid.get_child_count() > 0:
		var grid_node2 := restored_grid.get_child(0) as GridContainer
		if grid_node2 != null:
			for card in grid_node2.get_children():
				if card is Button:
					restored_cards += 1
	_check(restored_cards >= 1, "切回全部后应恢复道具卡渲染")

	# 难度选择（v0.16.0 修复）：面板难度更新 _selected_difficulty，并随一键通关按所选难度写档。
	_show_hub_panel(hub, &"map")
	# 界面排版重构（v0.27.0）：默认选中首个已解锁关卡（s01），一键通关在底部操作条。
	var clear_button: Button = null
	for button in _collect_buttons(map_panel):
		if button.text == "一键通关(测试)":
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
		if button.text == "出征 · 编队":
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


## 游戏百科（ENCYCLOPEDIA.md，阶段 8·提交 9，布局修订 B-023 于 0.8.9.1）：入口入列、武将/敌人两页签、
## 模拟器只读不改档、敌人难度面板与出现关卡反查。
func _test_encyclopedia(profile: PlayerProfile) -> void:
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame

	var encyclopedia := hub.get_node("HubPanel/Columns/Content/EncyclopediaPanel")
	_check(encyclopedia != null and not encyclopedia.visible, "大厅默认不应显示百科面板")
	var sidebar_box := hub.get_node("HubPanel/Columns/Sidebar/SidebarMargin/SidebarBox")
	var encyclopedia_button: Button = null
	for child in _collect_buttons(sidebar_box):
		var button := child as Button
		if button != null and button.text == "百科":
			encyclopedia_button = button
			break
	_check(encyclopedia_button != null, "大厅侧栏应含百科入口")
	if encyclopedia_button == null:
		hub.queue_free()
		await get_tree().process_frame
		return
	encyclopedia_button.pressed.emit()
	await get_tree().process_frame
	_check(encyclopedia.visible, "点击百科后应显示百科面板")

	# 存档不变式：百科为只读，全程不触碰存档文件。
	var before_save := ""
	var save_path := _profile_file
	if FileAccess.file_exists(save_path):
		before_save = FileAccess.get_file_as_string(save_path)
	else:
		before_save = "<none>"

	# 武将图鉴：左侧 9 将网格（全部角色可见），概念默认选中张飞。
	var left_box := encyclopedia.get("_left_box") as Control
	var grid_node := left_box.get_node_or_null("CharacterGrid") as Node
	_check(grid_node != null, "百科应构建武将 2 列网格")
	var character_cards := 0
	if grid_node != null:
		for child in grid_node.get_children():
			if child is Button:
				character_cards += 1
	_check(character_cards == 9, "武将图鉴应展示全部 9 名武将（当前版全量可见）")
	await get_tree().process_frame
	# B-023 回归：左列 2 列网格应横向铺满（原列宽塌陷至 8px，卡片不可见/不可点，
	# 表现=“只有默认首位数据”）。
	var character_min_width := 100000.0
	if grid_node != null:
		for child in grid_node.get_children():
			if child is Button:
				character_min_width = minf(character_min_width, (child as Button).size.x)
	_check(character_min_width >= 100.0, "武将卡应横向铺满左列 2 列网格（B-023 列宽塌陷回归）")
	var card_texts_clean := true
	if grid_node != null:
		for child in grid_node.get_children():
			if child is Button and (child as Button).text.contains("…"):
				card_texts_clean = false
	_check(card_texts_clean, "武将卡文本应精简放得下、不出现省略号（B-024）")
	_check((encyclopedia.get("_header_name_label") as Label).text == "张飞", "武将图鉴默认应选中概念稿张飞")
	var chapter_row := encyclopedia.get_node_or_null("Root/ChapterRow") as Node
	_check(chapter_row != null and not chapter_row.visible, "武将图鉴视图顶部不应展示章节行")

	# 数值模拟器：切换诸葛亮并调局内升阶 3 阶，属性实时刷新且无存档变化。
	encyclopedia._select_character("zhuge_liang")
	encyclopedia._sim_level = 20
	encyclopedia._set_sim_rank(3)
	var dmg_label := encyclopedia.get("_sim_result_values").get("伤害") as Label
	_check(dmg_label != null and dmg_label.text != "-", "模拟器结果卡应实时展示伤害（概念 .res）")
	var sim_results: Array[Label] = []
	for key in ["伤害", "攻速", "射程"]:
		var result_label := encyclopedia.get("_sim_result_values").get(key) as Label
		if result_label != null:
			sim_results.append(result_label)
	_check(sim_results.size() == 3, "模拟器结果卡应为伤害/攻速/射程三枚（概念 .res）")
	var zhuge := GameFlow.load_character_data("zhuge_liang")
	var base := zhuge.compute_stats_at(20, null, 0, null)
	var steps := zhuge.get_battle_rank_steps()
	var expected_damage := int(round(base.damage * CharacterData.rank_scale(steps.damage, 3)))
	var ranked := zhuge.compute_stats_at(20, null, 0, null, 3)
	_check(ranked.damage == expected_damage, "模拟器升阶数值应与共享倍率公式一致（观星角色）")
	_check(dmg_label != null and str(int(ranked.damage)) == dmg_label.text,
		"结果卡伤害应与升阶公式一致（%s / %s）" % [dmg_label.text if dmg_label else "?", str(int(ranked.damage))])
	_check(is_equal_approx(zhuge.get_static_range_multiplier(), 1.12), "诸葛亮观星应提供 +12% 静态射程加成")
	_check(is_equal_approx(GameFlow.load_character_data("liu_bei").get_static_range_multiplier(), 1.0),
		"非观星角色静态射程倍率应为 1.0")

	# 敌人图鉴：切换到敌人页，7 敌列表 + 困难难度 HP 倍率 + 出现关卡反查。
	var enemy_segment: Button = null
	for child in _collect_buttons(encyclopedia):
		var button := child as Button
		if button != null and button.text == "敌人图鉴":
			enemy_segment = button
			break
	_check(enemy_segment != null, "百科应含敌人图鉴切换按钮")
	if enemy_segment != null:
		enemy_segment.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(chapter_row != null and chapter_row.visible, "敌人图鉴视图顶部应展示章节选择行（B-023）")
	_check(str(encyclopedia.get("_selected_enemy_id")) == "yellow_turban_general",
		"敌人图鉴默认应选中概念稿黄巾渠帅·张梁")
	var enemy_grid := left_box.get_node_or_null("EnemyGrid") as GridContainer
	_check(enemy_grid != null and enemy_grid.columns == 2, "敌人图鉴左列应为 2 列网格（横排两个卡片，B-023）")
	var enemy_cards := 0
	var enemy_min_width := 100000.0
	if enemy_grid != null:
		for child in enemy_grid.get_children():
			if child is Button:
				enemy_cards += 1
				enemy_min_width = minf(enemy_min_width, (child as Button).size.x)
	_check(enemy_cards == 12, "敌人图鉴应展示第一章全部 12 种敌人（0.8.13.1 夜行刺 + 0.8.13.2 四类新精英）")
	_check(enemy_min_width >= 100.0, "敌人卡应横向铺满左列 2 列网格（B-023）")
	var all_text := ""
	var labels: Array[Label] = []
	_collect_labels(encyclopedia, labels)
	for label in labels:
		all_text += label.text + "\n"
	_check(all_text.contains("标准难度") and all_text.contains("困难难度"), "敌人难度面板应按难度档拆卡展示")
	_check(all_text.contains("出现关卡"), "敌人详情头/明细应含出现关卡反查")
	var soldier_entries := GameFlow.get_enemy_stage_entries("yellow_turban_soldier")
	_check(not soldier_entries.is_empty(), "黄巾步卒应反查到出现关卡")
	var general_stage_ids: Array[String] = []
	for entry in GameFlow.get_enemy_stage_entries("yellow_turban_general"):
		general_stage_ids.append(str(entry.get("stage_id", "")))
	_check(general_stage_ids.has("ch01_s08"), "黄巾渠帅·张梁应出现在 s08")
	# 0.8.13.3：张梁落位 s03 Boss → 出现关卡升为多关（首现 s03，明细按关号升序）。
	_check(general_stage_ids.has("ch01_s03") and general_stage_ids[0] == "ch01_s03",
		"黄巾渠帅·张梁应出现在 s03 且为首现关卡（多关登场）")

	# 只读不变式：模拟器调参 + 全量浏览后存档文件不变。
	var after_save := ""
	if FileAccess.file_exists(save_path):
		after_save = FileAccess.get_file_as_string(save_path)
	else:
		after_save = "<none>"
	_check(before_save == after_save, "百科浏览与模拟器操作不应产生任何存档变化")

	hub.queue_free()
	await get_tree().process_frame


func _collect_labels(node: Node, result: Array[Label]) -> void:
	if node is Label:
		result.append(node)
	for child in node.get_children():
		_collect_labels(child, result)


func _find_node_named(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_node_named(child, node_name)
		if found != null:
			return found
	return null



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
	var squad_labels: Array[Label] = []
	_collect_labels(scene, squad_labels)
	_check(squad_labels.any(func(label: Label) -> bool: return label.text.contains("2/3")),
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
	var confirm_popup := scene2.get("_confirm_popup") as Control
	_check(confirm_popup != null and confirm_popup.visible, "点击「确认出战」应弹出二次确认弹窗")
	var popup_labels: Array[Label] = []
	if confirm_popup != null:
		_collect_labels(confirm_popup, popup_labels)
	_check(popup_labels.any(func(label: Label) -> bool: return label.text.contains("刘备"))
		and popup_labels.any(func(label: Label) -> bool: return label.text.contains("关羽")),
		"确认弹窗应展示出战武将名单")
	_check(popup_labels.any(func(label: Label) -> bool: return label.text.contains("狼牙符"))
		and popup_labels.any(func(label: Label) -> bool: return label.text.contains("永久使用")),
		"确认弹窗应展示遗物清单与永久使用说明")
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
	var character_bar := main.get_node("UI/Root/BottomBar/CharacterBar") as HBoxContainer
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
	_check(GameManager.total_waves == 7, "s02 应有 7 波敌人（0.8.13.2 +1）")

	# 退出导航（v0.15.2）：顶栏退出弹确认框（确认后回游戏大厅，不直接退出）。
	var exit_button_flow := main.get_node("UI/Root/TopBar/Margin/Content/ExitButton") as Button
	exit_button_flow.pressed.emit()
	await get_tree().process_frame
	var exit_dialog := get_tree().root.get_node_or_null("%s/%s" % [
		BattleConfirmDialog.LAYER_NAME, BattleConfirmDialog.DIALOG_NAME]) as Control
	_check(exit_dialog != null, "战斗退出应弹出二次确认弹窗")
	if exit_dialog != null:
		var exit_confirm := _find_node_named(exit_dialog, "ConfirmButton") as Button
		_check(exit_confirm != null and exit_confirm.text == "放弃并退出",
			"退出确认框应提示放弃本局收益")
		exit_dialog.close()
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
	GameFlow.set_gameplay_flag("skip_dialogue", _saved_skip_dialogue)
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
