extends Node

## 回归 B-100 / B-038（程序 0.8.17.4）：同一 GameHub 内切回养成时，
## 解锁名单、经验详情与具名卡片（姓名 / 职业 / 等级 / 头像）必须一起刷新。
## 通过大厅注册表获取面板；必需节点缺失即失败退出，使用一次性隔离存档。

var failures: Array[String] = []
var _profile_file := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.bug_repro_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	call_deferred("_run")


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		push_error("DEVELOP_REFRESH: %s" % message)
	return condition


func _collect_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if root is Button:
		buttons.append(root)
	for child in root.get_children():
		buttons.append_array(_collect_buttons(child))
	return buttons


func _validate_card(button: Button, character_id: String, locked: bool, profile: PlayerProfile) -> bool:
	if not _check(button != null and is_instance_valid(button), "%s 卡片应存在" % character_id):
		return false
	var character := GameFlow.load_character_data(character_id)
	if not _check(character != null, "%s 角色数据应存在" % character_id):
		return false
	var content := button.get_node_or_null("CardContent")
	if not _check(content != null, "%s 卡片应有 CardContent" % character_id):
		return false
	var name_label := content.find_child("CardName", true, false) as Label
	var sub_label := content.find_child("CardSub", true, false) as Label
	var lv_label := content.find_child("CardLv", true, false) as Label
	var avatar := content.find_child("CardAvatar", true, false) as Label
	if not _check(name_label != null and sub_label != null and lv_label != null and avatar != null,
		"%s 卡片应齐备 CardName / CardSub / CardLv / CardAvatar" % character_id):
		return false
	var level := 0 if locked else GameFlow.get_character_level(profile, character_id)
	var profession_name := character.profession.display_name if character.profession != null else "未知"
	var expected_sub := "%s · 未解锁" % profession_name if locked else profession_name
	_check(name_label.text == character.display_name,
		"卡片姓名应为 %s（实际 %s）" % [character.display_name, name_label.text])
	_check(sub_label.text == expected_sub,
		"%s 卡片职业行应为 %s（实际 %s）" % [character_id, expected_sub, sub_label.text])
	_check(lv_label.text == "Lv%d" % level,
		"%s 卡片等级应为 Lv%d（实际 %s）" % [character_id, level, lv_label.text])
	_check(avatar.text == character.display_name.left(1),
		"%s 头像字不应被覆盖成全名（实际 %s）" % [character_id, avatar.text])
	_check(button.disabled == locked and button.toggle_mode == (not locked),
		"%s 卡片交互状态应与拥有状态一致" % character_id)
	return failures.is_empty()


func _validate_roster(develop_panel: Node, profile: PlayerProfile) -> bool:
	var buttons_value: Variant = develop_panel.get("_character_buttons")
	var locked_value: Variant = develop_panel.get("_locked_ids")
	var locked_box := develop_panel.get("_locked_box") as VBoxContainer
	if not _check(buttons_value is Dictionary and locked_value is Array and locked_box != null,
		"养成应齐备已拥有卡片注册表、未解锁名单与列表容器"):
		return false
	var char_buttons: Dictionary = buttons_value
	var locked_ids: Array = locked_value
	var owned_ids := profile.get_owned_character_ids()
	_check(char_buttons.size() == owned_ids.size(),
		"已拥有卡片数应与档案一致（%d / %d）" % [char_buttons.size(), owned_ids.size()])
	for character_id in owned_ids:
		if not _validate_card(char_buttons.get(character_id) as Button, character_id, false, profile):
			return false
	var expected_locked: Dictionary = {}
	for character_id in GameFlow.get_all_character_ids():
		if owned_ids.has(character_id):
			_check(not locked_ids.has(character_id), "%s 已解锁后应离开未解锁名单" % character_id)
		else:
			var character := GameFlow.load_character_data(character_id)
			if not _check(character != null, "%s 未解锁角色数据应存在" % character_id):
				return false
			expected_locked[character.display_name] = character_id
			_check(locked_ids.has(character_id), "%s 应保留在未解锁名单" % character_id)
	_check(locked_ids.size() == expected_locked.size(), "未解锁名单数量应与角色目录一致")
	var locked_buttons := _collect_buttons(locked_box)
	_check(locked_buttons.size() == expected_locked.size(), "未解锁卡片数量应与名单一致")
	for button in locked_buttons:
		var name_label := button.find_child("CardName", true, false) as Label
		if not _check(name_label != null, "未解锁卡片应有具名 CardName"):
			return false
		if not _check(expected_locked.has(name_label.text), "未解锁卡片应在当前未解锁名单中：%s" % name_label.text):
			return false
		if not _validate_card(button, str(expected_locked[name_label.text]), true, profile):
			return false
		expected_locked.erase(name_label.text)
	_check(expected_locked.is_empty(), "所有未解锁角色均应有唯一卡片")
	return failures.is_empty()


func _validate_detail(develop_panel: Node, profile: PlayerProfile) -> bool:
	var character_id := str(develop_panel.get("_selected_id"))
	var level_label := develop_panel.get("_detail_level_label") as Label
	var exp_label := develop_panel.get("_exp_label") as Label
	var exp_bar := develop_panel.get("_exp_bar") as ProgressBar
	if not _check(profile.has_character(character_id) and level_label != null and exp_label != null and exp_bar != null,
		"选中角色、详情等级与经验控件应存在"):
		return false
	var progress := LevelCurve.progress_at(profile.get_character_exp(character_id))
	var expected_exp := "已达等级上限 %d" % LevelCurve.max_level() if progress.is_max_level else \
		"%d / %d" % [int(progress.exp_into_level), int(progress.exp_for_next)]
	_check(level_label.text == "Lv.%d" % int(progress.level), "详情等级应与档案当前等级一致")
	_check(exp_label.text == expected_exp, "详情经验应随档案刷新（实际 %s，预期 %s）" % [exp_label.text, expected_exp])
	_check(is_equal_approx(exp_bar.value, float(progress.exp_into_level)) and
		is_equal_approx(exp_bar.max_value, float(maxi(int(progress.exp_for_next), 1))),
		"经验条当前进度与上限应随档案刷新")
	return failures.is_empty()


func _run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	if not _check(profile != null, "隔离新档应创建成功"):
		_stop()
		return
	GameFlow.ensure_initial_characters(profile)
	if not _check(profile.has_character("liu_bei") and profile.has_character("guan_yu") and
		profile.get_owned_character_ids().size() == 2, "新档应初始仅拥有刘备、关羽"):
		_stop()
		return
	var hub_scene := load("res://scenes/GameHub.tscn") as PackedScene
	if not _check(hub_scene != null, "GameHub 场景应可加载"):
		_stop()
		return
	var hub := hub_scene.instantiate()
	add_child(hub)
	await get_tree().process_frame
	var panels_value: Variant = hub.get("_panels")
	if not _check(panels_value is Dictionary and hub.has_method("_show_panel"), "大厅面板注册表与切换入口应存在"):
		_stop(hub)
		return
	var panels: Dictionary = panels_value
	var map_panel := panels.get(&"map") as Control
	var develop_panel := panels.get(&"develop") as Control
	if not _check(map_panel != null and develop_panel != null and
		map_panel.has_method("_select_stage") and map_panel.has_method("_on_instant_clear") and
		develop_panel.has_method("_on_character_pressed"), "地图与养成面板及回归入口应已注册"):
		_stop(hub)
		return

	# 刷新前先验证名单、全部具名卡片与零经验详情，避免旧断言失去覆盖仍通过。
	hub._show_panel(&"develop")
	develop_panel._on_character_pressed("liu_bei")
	await get_tree().process_frame
	if not _validate_roster(develop_panel, profile) or not _validate_detail(develop_panel, profile):
		_stop(hub)
		return
	_check(profile.get_character_exp("liu_bei") == 0, "刷新前刘备经验应为 0")
	hub._show_panel(&"map")
	var expected_exp: Dictionary = {"liu_bei": 0, "guan_yu": 0}
	# 面板先构建于 Lv.1；通关期间按当前拥有名单独立累计预期经验与首通解锁。
	for stage_id in [&"ch01_s01", &"ch01_s02", &"ch01_s03", &"ch01_s04", &"ch01_s05"]:
		var stage := GameFlow.load_stage_data(stage_id)
		if not _check(stage != null, "%s 关卡数据应存在" % stage_id):
			_stop(hub)
			return
		for character_id in expected_exp.keys():
			expected_exp[character_id] += 100
		for character_id in stage.first_clear_unlock_character_ids:
			if not expected_exp.has(str(character_id)):
				expected_exp[str(character_id)] = 0
		map_panel._select_stage(stage)
		map_panel._on_instant_clear()
		await get_tree().process_frame
		var stage_progress: Variant = profile.stage_progress.get(str(stage_id))
		if not _check(stage_progress is Dictionary and stage_progress.get("completed", false), "%s 一键通关应成功入档" % stage_id):
			_stop(hub)
			return

	_check(profile.has_character("zhang_fei"), "结算后应拥有张飞（s02 首通解锁）")
	_check(profile.get_owned_character_ids().size() == expected_exp.size(), "结算拥有名单应包含全部首通解锁")
	for character_id in expected_exp.keys():
		_check(profile.has_character(character_id), "%s 应已解锁入档" % character_id)
		_check(profile.get_character_exp(character_id) == int(expected_exp[character_id]),
			"%s 经验应为 %d（实际 %d）" % [character_id, int(expected_exp[character_id]), profile.get_character_exp(character_id)])
	_check(GameFlow.get_character_level(profile, "liu_bei") == 6, "5 次一键通关后刘备应达 6 级")
	_check(profile.get_owned_character_ids().size() == 7, "5 次一键通关后应拥有 7 名武将")

	# 同一大厅、同一养成实例切回，保留选择并刷新名单、详情与卡片。
	hub._show_panel(&"develop")
	await get_tree().process_frame
	_check(panels.get(&"develop") == develop_panel, "切回时应复用同一养成面板实例")
	_check(str(develop_panel.get("_selected_id")) == "liu_bei", "切回养成应保留刘备选择")
	if not _validate_roster(develop_panel, profile) or not _validate_detail(develop_panel, profile):
		_stop(hub)
		return
	var level_six_count := 0
	for character_id in profile.get_owned_character_ids():
		if GameFlow.get_character_level(profile, character_id) == 6:
			level_six_count += 1
	_check(level_six_count == 2, "刷新后应有刘备、关羽两张 Lv.6 卡片")
	_stop(hub)


func _stop(hub: Node = null) -> void:
	if is_instance_valid(hub):
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
		print("DEVELOP_REFRESH_OK")
		get_tree().quit(0)
	else:
		print("DEVELOP_REFRESH_FAILED: %d" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)
