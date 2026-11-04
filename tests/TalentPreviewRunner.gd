extends Node

var _slot := ""
var _capture_dir := "res://build/verify_0.9.5.0"
var layout_checks := 0
var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): _capture_dir = arg.trim_prefix("--capture-dir=")
	_slot = "user://.talent_preview_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	layout_checks += 1
	if not ok:
		failures.append(message)
		push_error("TALENT_PREVIEW: " + message)

func _full(id: String, count: int = 2) -> Dictionary:
	var result := {}
	for tree_id in TalentRegistry.tree_ids(id).slice(0, count):
		for node in TalentRegistry.get_tree_data(tree_id).nodes: result[str(node.id)] = 2
	return result

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
	develop._tab_container.current_tab = 4
	await _shot("develop_talent_l1", develop._talent_panel)
	p.add_character_exp("guan_yu", LevelCurve.exp_total_for_level(5))
	ProfileStore.save_profile(p)
	develop._refresh()
	await _shot("develop_talent_l5", develop._talent_panel)
	develop._allocate_talent("physical_burst.slash", 0)
	await _shot("develop_talent_allocated", develop._talent_panel)
	ProfileStore._writes_blocked = true
	develop._allocate_talent("physical_burst.swift", 0)
	await _shot("develop_talent_save_failed", develop._talent_panel)
	ProfileStore._writes_blocked = false
	develop._confirm_reset_talents()
	await _shot("develop_talent_reset_confirm", develop._talent_panel)
	develop._talent_reset_dialog.canceled.emit()
	await get_tree().process_frame
	develop._reset_talents("guan_yu", p.get_talent_alloc("guan_yu"))
	await _shot("develop_talent_reset_done", develop._talent_panel)
	for id in SkillRegistry.KITS:
		p.ensure_character(id)
		p.characters[id].total_exp = LevelCurve.exp_total_for_level(100)
		p.characters[id].talent_alloc = _full(id)
	ProfileStore.save_profile(p)
	develop._on_shown()
	for id in SkillRegistry.KITS:
		develop._select_character(id)
		develop._refresh()
		develop._tab_container.current_tab = 4
		await _shot("develop_talent_" + id, develop._talent_panel)
	develop._select_character("guan_yu")
	develop._refresh()
	await _bottom(develop._talent_panel)
	await _shot("develop_talent_ultimate", develop._talent_panel)
	hub._show_panel(&"encyclopedia")
	var enc = hub._panels[&"encyclopedia"]
	enc._select_character("guan_yu")
	enc._tab_container.current_tab = 4
	enc._sim_level = 100
	enc._sim_talent_alloc = _full("guan_yu", 1)
	enc._on_sim_changed()
	await _shot("encyclopedia_talent_sim", enc._talent_panel)
	await _bottom(enc._talent_panel)
	await _shot("encyclopedia_talent_ultimate", enc._talent_panel)
	var before := p.to_dict()
	enc._allocate_sim_talent("rage.gather", 0)
	await _shot("encyclopedia_talent_scroll_kept", enc._talent_panel)
	_check(enc._talent_panel.scroll.scroll_vertical > 100, "分配后保持滚动位置")
	_check(p.to_dict() == before, "百科模拟不改玩家档")
	enc._select_character("zhuge_liang")
	enc._sim_level = 100
	enc._on_sim_changed()
	await _shot("encyclopedia_talent_magic", enc._talent_panel)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("TALENT_PREVIEW_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", layout_checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _shot(label: String, panel: TalentTreePanel) -> void:
	Input.warp_mouse(Vector2(1275, 5))
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var rect := panel.get_global_rect()
	_check(rect.position.x >= 0 and rect.end.x <= 1281 and rect.end.y <= 721, label + " 页签不越屏")
	var trees := panel.find_child("TalentTrees", true, false) as HBoxContainer
	_check(trees != null and trees.get_child_count() == 3, label + " 三列树")
	var widths: Array[float] = []
	for tree in trees.get_children():
		widths.append(tree.size.x)
		_check(tree.size.x > 140, label + " 节点可读宽度")
		for card in tree.find_children("*", "PanelContainer", true, false):
			_check(card.get_global_rect().position.x >= tree.get_global_rect().position.x - 1 and card.get_global_rect().end.x <= tree.get_global_rect().end.x + 1, label + " 卡片横向不溢出")
	_check(absf(widths.max() - widths.min()) <= 1.0, label + " 三列等宽")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	var error := get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(label + ".png"))
	_check(error == OK, label + " 原生截图")
	print("CAPTURE %s error=%d" % [label,error])

func _bottom(panel: TalentTreePanel) -> void:
	for _frame in range(5): await get_tree().process_frame
	panel.scroll.scroll_vertical = 99999
	await get_tree().process_frame
	_check(panel.scroll.scroll_vertical > 100, "末层滚动有效")
	var trees := panel.find_child("TalentTrees", true, false)
	for tree in trees.get_children():
		var cards := tree.find_children("*", "PanelContainer", true, false)
		_check(panel.scroll.get_global_rect().intersects(cards[-1].get_global_rect()), "三树终极可见")
