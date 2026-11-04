extends Node

var checks := 0
var failures: Array[String] = []
var _slot := ""
var _capture_dir := "res://build/verify_0.9.6.0"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): _capture_dir = arg.trim_prefix("--capture-dir=")
	_slot = "user://.faction_preview_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("FACTION_PREVIEW: " + message)

func _click(control: Control) -> void:
	for _frame in range(3): await get_tree().process_frame
	var pos := control.get_global_rect().get_center()
	Input.warp_mouse(pos)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pos
		event.global_position = pos
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame

func _shot(label: String) -> void:
	Input.warp_mouse(Vector2(1275, 5))
	await get_tree().create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	_check(get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(label + ".png")) == OK, label + " 原生截图")
	print("CAPTURE " + label)

func _check_enc(enc: Control, expected: int) -> void:
	_check(enc._character_buttons.size() == expected, "实际鼠标筛选数量 " + str(expected))
	var bounds := enc.get_global_rect()
	var screen := get_viewport().get_visible_rect()
	_check(screen.encloses(bounds), "百科整屏边界")
	_check(screen.encloses(enc.find_child("DetailPanel", true, false).get_global_rect()), "详情卡不撑宽大厅")
	_check(bounds.encloses(enc._faction_row.get_global_rect()), "筛选行边界")
	for button in enc._faction_buttons.values():
		_check(bounds.encloses(button.get_global_rect()) and button.size.y >= 30, "筛选按钮完整 " + str(button.name))
	for faction in FactionRegistry.IDS:
		_check(enc._faction_buttons[faction].text.begins_with(FactionRegistry.display_name(faction) + " "), "阵营筛选中文常显 " + str(faction))
	for id in enc._character_buttons:
		var button: Button = enc._character_buttons[id]
		var badge := button.find_child("FactionBadge", true, false) as Control
		_check(badge != null and button.get_global_rect().encloses(badge.get_global_rect()), "武将卡徽记边界 " + id)
		_check_badge(badge, "归属徽记清晰 " + id)
	if expected == 0:
		_check(enc._detail_box.find_child("FactionEmpty", true, false) != null and not enc._sim_panel.visible, "空态无旧详情与模拟")
	else:
		_check(enc._character_chips.find_child("FactionBadge", true, false) != null and enc._talent_button.visible, "详情归属和天赋入口")
		_check(bounds.encloses(enc._talent_button.get_global_rect()), "天赋入口完整可见")
		for chip in enc._character_chips.get_children():
			_check(enc._character_chips.get_global_rect().encloses(chip.get_global_rect()), "身份标签折行边界")
		_check(bounds.encloses(enc.find_child("AcquisitionValue", true, false).get_global_rect()), "获取方式完整可见")
		_check_badge(enc._character_chips.find_child("FactionBadge", true, false), "详情阵营中文")

func _check_badge(badge: Control, message: String) -> void:
	var flag := badge.find_child("FactionFlag", true, false) as ConceptIcon
	var label := badge.find_child("FactionName", true, false) as Label
	_check(flag != null and flag.texture != null and flag.size.x >= 20, message + " 军旗")
	_check(label != null and label.text == FactionRegistry.display_name(StringName(badge.get_meta("faction_id"))) and label.visible, message + " 名称常显")
	_check(badge.get_global_rect().encloses(flag.get_global_rect()) and badge.get_global_rect().encloses(label.get_global_rect()), message + " 旗与文字边界")

func _check_all_characters(enc: Control) -> void:
	for id in enc._character_buttons:
		enc._select_character(id)
		for _frame in range(4): await get_tree().process_frame
		_check_enc(enc, 9)
	var last: Button = enc._character_buttons["zhuge_liang"]
	enc._left_scroll.ensure_control_visible(last)
	for _frame in range(4): await get_tree().process_frame
	_check(enc._left_scroll.get_global_rect().encloses(last.get_global_rect()), "末卡滚动后完整可见")
	await _click(last)
	_check(enc._selected_character_id == "zhuge_liang", "末卡真实点击可选择")
	await _shot("encyclopedia_factions_last_card")
	enc._left_scroll.scroll_vertical = 0

func _run() -> void:
	var p := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(p)
	ProfileStore.save_profile(p)
	var before := p.to_dict()
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._show_panel(&"encyclopedia")
	var enc = hub._panels[&"encyclopedia"]
	await _shot("encyclopedia_factions_all")
	_check_enc(enc, 9)
	await _check_all_characters(enc)
	enc._select_character("guan_yu")
	enc._sim_level = 35
	enc._on_sim_changed()
	for item in [[&"shu", 7], [&"qun", 2], [&"wei", 0], [&"wu", 0]]:
		await _click(enc._faction_buttons[item[0]])
		await _shot("encyclopedia_factions_" + str(item[0]))
		_check_enc(enc, item[1])
		_check(enc._faction_filter == item[0], "实际点击互斥选中")
		if item[0] == &"shu": _check(enc._selected_character_id == "guan_yu" and enc._sim_level == 35, "筛选保留模拟")
	await _click(enc._faction_buttons[&"qun"])
	await _click(enc._enemy_button)
	await _shot("encyclopedia_factions_enemy")
	_check(not enc._faction_row.visible and enc._enemy_buttons.size() == enc._enemy_ids.size(), "敌人不受武将筛选")
	await _click(enc._character_button)
	await _shot("encyclopedia_factions_return")
	_check_enc(enc, 2)
	await _click(enc._faction_buttons[&""])
	await _shot("encyclopedia_factions_restored")
	_check_enc(enc, 9)
	_check(p.to_dict() == before, "实际筛选和模拟不写档")
	hub._show_panel(&"develop")
	var develop = hub._panels[&"develop"]
	develop._select_character("guan_yu")
	develop._refresh()
	await _shot("develop_faction_badge")
	var badge := develop._detail_chips.find_child("FactionBadge", true, false) as Control
	_check(badge != null and develop.get_global_rect().encloses(badge.get_global_rect()) and develop._talent_button.visible, "属性徽记与天赋入口边界")
	_check_badge(badge, "养成阵营")
	hub.queue_free()
	await get_tree().process_frame
	for id in GameFlow.get_all_character_ids(): p.ensure_character(str(id))
	ProfileStore.save_profile(p)
	GameFlow.select_stage(&"ch01_s01")
	GameFlow.set_squad(["liu_bei", "guan_yu", "diao_chan"])
	GameFlow.save_squad_to_profile(p)
	ProfileStore.save_profile(p)
	var squad := (load("res://scenes/SquadSelect.tscn") as PackedScene).instantiate()
	add_child(squad)
	await _shot("squad_faction_badges")
	for id in squad._card_widgets:
		var card: Button = squad._card_widgets[id].button
		var mark := card.find_child("FactionBadge", true, false) as Control
		_check(mark != null and card.get_global_rect().encloses(mark.get_global_rect()), "编队徽记边界 " + id)
		_check_badge(mark, "编队阵营 " + id)
	squad._open_confirm_popup()
	await _shot("squad_faction_confirm")
	var marks: Array = squad._confirm_popup.find_children("FactionBadge", "", true, false)
	_check(marks.size() == 3, "出战确认三名归属")
	for mark in marks:
		_check(Rect2(0, 0, 1280, 720).encloses(mark.get_global_rect()), "确认徽记不越界")
		_check_badge(mark, "确认阵营")
	squad._close_confirm_popup()
	squad.queue_free()
	await get_tree().process_frame
	var stage := GameFlow.load_stage_data(&"ch01_s01")
	var original := stage.faction_rule.duplicate(true)
	stage.faction_rule = {"allow": ["qun"]}
	squad = (load("res://scenes/SquadSelect.tscn") as PackedScene).instantiate()
	add_child(squad)
	await _shot("squad_faction_rule_preview")
	_check(squad._selected_ids == ["diao_chan"] and squad._card_widgets.guan_yu.button.disabled, "受限关记忆过滤")
	_check_badge(squad.find_child("StageFactionRules", true, false).find_child("FactionBadge", true, false), "限制行阵营")
	await _click(squad._card_widgets.guan_yu.button)
	_check(squad._selected_ids == ["diao_chan"], "真实点击不能选受限阵营")
	stage.faction_rule = original
	squad.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("FACTION_PREVIEW_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
