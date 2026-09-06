extends Node

## 回归测试（v0.32.1 / 程序 0.8.7.1）：武将养成面板在 GameHub 实例内"切回"时
## 必须整体重载左侧列表——① 一键通关首通解锁的武将应从图鉴置灰区移入已拥有区；
## ② 左侧卡片等级须随档案更新（曾停留在面板构建时 Lv.1，右侧详情却已 6 级）。
## 使用一次性隔离存档槽，不触碰玩家真实存档。

var failures: Array[String] = []
var _profile_file := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.bug_repro_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("DEVELOP_REFRESH: %s" % message)


func _collect_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if root is Button:
		buttons.append(root)
	for child in root.get_children():
		buttons.append_array(_collect_buttons(child))
	return buttons


func _has_text(root: Node, needle: String) -> bool:
	if root is Label and (root as Label).text.contains(needle):
		return true
	for child in root.get_children():
		if _has_text(child, needle):
			return true
	return false


func _run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(profile)
	_check(profile.has_character("liu_bei") and profile.has_character("guan_yu"), "新档应初始拥有刘备、关羽")

	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	var map_panel := hub.get_node("Columns/Content/MapPanel")
	var develop_panel := hub.get_node("Columns/Content/DevelopPanel")

	# 一键通关 s01~s05（面板先构建于全员 Lv.1、仅刘备/关羽时，随后连续通关升级+解锁）。
	for stage_id in [&"ch01_s01", &"ch01_s02", &"ch01_s03", &"ch01_s04", &"ch01_s05"]:
		map_panel._select_stage(GameFlow.load_stage_data(stage_id))
		map_panel._on_instant_clear()
		await get_tree().process_frame

	_check(profile.has_character("zhang_fei"), "结算后档案应拥有张飞（s02 首通解锁）")
	_check(LevelCurve.level_from_total_exp(profile.get_character_exp("liu_bei")) == 6,
		"5 次一键通关后刘备经验应达 6 级（实际 %d）" % LevelCurve.level_from_total_exp(profile.get_character_exp("liu_bei")))
	_check(profile.get_owned_character_ids().size() == 7, "结算后应拥有 7 名武将（实际 %d）" % profile.get_owned_character_ids().size())

	# 切回武将养成面板（同一 GameHub 实例，触发 _on_shown）。
	hub._show_panel(&"develop")
	await get_tree().process_frame

	var detail_level_text: String = develop_panel.get("_detail_level_label").text
	_check(detail_level_text == "Lv.6", "右侧详情应显示当前等级 6（实际：%s）" % detail_level_text)

	var locked_count := 0
	for button in _collect_buttons(develop_panel):
		if button.disabled and not button.toggle_mode and _has_text(button, "首通解锁"):
			locked_count += 1
	var char_buttons: Dictionary = develop_panel.get("_character_buttons")
	_check(char_buttons.size() == 7, "左侧应列出 7 名已拥有武将（实际 %d）" % char_buttons.size())
	_check(locked_count == 2, "未解锁区应只剩 2 名（实际 %d）" % locked_count)
	# B-038：左卡按命名节点同步——旧实现按 find_children 顺序覆盖，把头像写成全名、
	# 职业行写错、等级不更新；此处逐卡校验 姓名/职业/等级 标签与头像字是否被污染。
	var level_six_count := 0
	for character_id in char_buttons.keys():
		var button := char_buttons[character_id] as Button
		if button == null or button.get_child_count() == 0:
			continue
		var content := button.get_child(0)
		var name_label := content.find_child("CardName", true, false) as Label
		var sub_label := content.find_child("CardSub", true, false) as Label
		var lv_label := content.find_child("CardLv", true, false) as Label
		var avatar := content.get_child(0) as Label
		if name_label == null or sub_label == null or lv_label == null:
			continue
		var character_data := GameFlow.load_character_data(str(character_id))
		var level := GameFlow.get_character_level(profile, str(character_id))
		if level == 6:
			level_six_count += 1
		_check(name_label.text == character_data.display_name,
			"卡片姓名应为 %s（实际 %s）" % [character_data.display_name, name_label.text])
		_check(sub_label.text == (character_data.profession.display_name
			if character_data.profession != null else "未知职业"),
			"卡片职业行应显示职业名（实际 %s）" % sub_label.text)
		_check(lv_label.text == "Lv%d" % level,
			"卡片等级应随档案刷新为 Lv%d（实际 %s）" % [level, lv_label.text])
		_check(avatar != null and avatar.text == character_data.display_name.left(1),
			"头像字不应被同步覆盖成全名（实际 %s）" % (avatar.text if avatar != null else "null"))
	_check(level_six_count == 2, "左侧已拥有武将应含 2 张 Lv.6 卡片（实际 %d）" % level_six_count)

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
