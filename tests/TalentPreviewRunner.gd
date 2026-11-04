extends Node

var _slot := ""
var _capture_dir := "res://build/verify_0.9.5.1"
var layout_checks := 0
var failures: Array[String] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): _capture_dir = arg.trim_prefix("--capture-dir=")
	_slot = "user://.talent_popup_preview_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	layout_checks += 1
	if not ok: failures.append(message); push_error("TALENT_PREVIEW: " + message)

func _full(id: String, count: int = 2) -> Dictionary:
	var result := {}
	for tree_id in TalentRegistry.tree_ids(id).slice(0, count):
		for node in TalentRegistry.get_tree_data(tree_id).nodes: result[str(node.id)] = 2
	return result

func _click(control: Control) -> void:
	for _frame in range(3): await get_tree().process_frame
	var position := control.get_global_rect().get_center()
	Input.warp_mouse(position)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().process_frame

func _escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	Input.parse_input_event(event)
	await get_tree().process_frame

func _run() -> void:
	var p := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(p)
	ProfileStore.save_profile(p)
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._show_panel(&"develop")
	var develop = hub._panels[&"develop"]
	develop._select_character("guan_yu")
	await _shot("develop_talent_entry", null)
	_check(develop._tab_container.get_tab_count() == 4, "天赋移出页签")
	await _click(develop._talent_button)
	var popup: TalentTreePanel = develop._talent_panel
	_check(is_instance_valid(popup), "真实点击属性卡入口打开天赋")
	await _shot("develop_tree_l1", popup)
	var inspect_snapshot := p.to_dict()
	for id in popup.node_buttons.keys():
		await _click(popup.node_buttons[id])
		_check(is_instance_valid(popup.detail_panel) and popup.selected_node_id == id, "30节点实际点击可查看 " + id)
		_check(p.to_dict() == inspect_snapshot, "查看节点不写档 " + id)
		_check(popup.detail_action.disabled, "L1不可分配 " + id)
		await _escape()
		_check(not is_instance_valid(popup.detail_panel) and is_instance_valid(develop._talent_panel), "ESC只关闭节点详情")
	await _click(popup.node_buttons["physical_burst.fatal"])
	await _shot("develop_node_locked", popup)
	await _escape()
	p.add_character_exp("guan_yu", LevelCurve.exp_total_for_level(5))
	ProfileStore.save_profile(p)
	develop._refresh()
	await _click(popup.node_buttons["physical_burst.slash"])
	await _shot("develop_node_available", popup)
	await _click(popup.detail_action)
	_check(p.get_talent_alloc("guan_yu").get("physical_burst.slash") == 1, "真实点击详情分配扣一点")
	await _shot("develop_node_allocated", popup)
	await _escape()
	await _click(popup.node_buttons["physical_burst.swift"])
	ProfileStore._writes_blocked = true
	await _click(popup.detail_action)
	_check(p.get_talent_alloc("guan_yu").get("physical_burst.swift", 0) == 0 and p.talent_points_remaining("guan_yu") == 1, "保存失败等级与点数保持")
	await _shot("develop_node_save_failed", popup)
	ProfileStore._writes_blocked = false
	await _escape()
	await _click(popup.reset_button)
	await _shot("develop_reset_confirm", popup)
	develop._talent_reset_dialog.get_ok_button().pressed.emit()
	await get_tree().process_frame
	_check(p.get_talent_alloc("guan_yu").is_empty(), "确认免费重置")
	await _shot("develop_tree_reset", popup)
	await _escape()
	_check(develop._talent_panel == null, "ESC关闭树弹窗返回角色属性")
	for id in SkillRegistry.KITS:
		p.ensure_character(id)
		p.characters[id].total_exp = LevelCurve.exp_total_for_level(100)
		p.characters[id].talent_alloc = _full(id)
	ProfileStore.save_profile(p)
	develop._on_shown()
	for id in SkillRegistry.KITS:
		develop._select_character(id)
		develop._refresh()
		await _click(develop._talent_button)
		popup = develop._talent_panel
		await _shot("develop_tree_" + id, popup)
		if id == "guan_yu":
			await _click(popup.node_buttons["armor_break.unbreakable"])
			await _shot("develop_node_ultimate", popup)
			_check(popup.detail_panel.find_child("NodeRule", true, false).text.contains("不暴击"), "终极完整机制可读")
			await _escape()
		await _escape()
	hub._show_panel(&"encyclopedia")
	var enc = hub._panels[&"encyclopedia"]
	enc._select_character("guan_yu")
	enc._sim_level = 100
	enc._sim_talent_alloc = _full("guan_yu", 1)
	enc._on_sim_changed()
	await _shot("encyclopedia_talent_entry", null)
	await _click(enc._talent_button)
	popup = enc._talent_panel
	await _shot("encyclopedia_tree_sim", popup)
	var before := p.to_dict()
	await _click(popup.node_buttons["rage.gather"])
	await _click(popup.detail_action)
	await _shot("encyclopedia_node_sim", popup)
	_check(p.to_dict() == before and enc._sim_talent_alloc.get("rage.gather") == 1, "百科真实点击模拟分配不改档")
	await _escape()
	enc._change_talent_level(-95)
	await _shot("encyclopedia_tree_low_level", popup)
	_check(TalentRegistry.spent(enc._sim_talent_alloc) == 2 and p.to_dict() == before, "降级归一化模拟天赋")
	await _escape()
	enc._select_character("zhuge_liang")
	enc._sim_level = 100
	enc._on_sim_changed()
	await _click(enc._talent_button)
	popup = enc._talent_panel
	await _shot("encyclopedia_tree_magic", popup)
	await _click(popup.node_buttons["magic_area.inferno"])
	await _shot("encyclopedia_node_locked_ultimate", popup)
	await _escape()
	await _escape()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("TALENT_PREVIEW_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", layout_checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _shot(label: String, popup: TalentTreePanel) -> void:
	Input.warp_mouse(Vector2(1275, 5))
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	if not label.ends_with("_entry"): _check(is_instance_valid(popup), label + " 树弹窗已打开")
	if is_instance_valid(popup):
		var window := popup.find_child("TalentWindow", true, false) as Control
		_check(window.get_global_rect().position.x >= 24 and window.get_global_rect().end.x <= 1256 and window.get_global_rect().end.y <= 696, label + " 弹窗留白与屏幕边界")
		_check(popup.node_buttons.size() == 30 and popup.canvas.edges.size() == 36, label + " 三类分叉30节点36连线")
		var bounds := popup.canvas.get_global_rect()
		for id in popup.node_buttons:
			var node := popup.node_buttons[id] as Control
			var name_label := popup.canvas.find_child("Name_" + node.name, false, false) as Label
			_check(bounds.encloses(node.get_global_rect()) and bounds.encloses(name_label.get_global_rect()), label + " 节点及名称同屏 " + id)
			_check(not name_label.text.is_empty() and node.size.x >= 46, label + " 节点可读与可点 " + id)
		if is_instance_valid(popup.detail_panel):
			var rect := popup.detail_panel.get_global_rect()
			_check(Rect2(24, 24, 1232, 672).encloses(rect), label + " 详情不越界")
			_check(rect.encloses(popup.detail_action.get_global_rect()), label + " 详情按钮完整")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	var error := get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(label + ".png"))
	_check(error == OK, label + " 原生截图")
	print("CAPTURE %s error=%d" % [label, error])
