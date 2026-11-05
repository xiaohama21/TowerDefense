extends "res://tests/ProgressionPreviewRunner.gd"

## Reuse the real Lv1 build/wave/reward flow in its own versioned archive.
func _ready() -> void:
	capture_dir = "res://docs/ui_concept/runtime_0.9.8"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
	super._ready()

func _shot(name: String) -> void:
	if name == "new_save_start":
		for child in main.ui.get_node("Root").get_children():
			if child.get_script() == load("res://scripts/DebugPanel.gd"): child.visible = false
		_check(not main.grid_background.placement_grid_visible, "常态草地隐藏网格")
		await super._shot(name)
		var prior_pause := get_tree().paused
		var hero := GameFlow.load_character_data("liu_bei")
		_check(main.build_manager.begin_drag(hero), "刘备拖放样板")
		get_tree().paused = true
		main.build_manager._update_drag_at(slots[0])
		_check(main.grid_background.placement_grid_visible, "拖放显示网格")
		await super._shot("drag_liu_bei")
		main.build_manager.cancel_drag()
		_check(not main.grid_background.placement_grid_visible, "取消恢复地面")
		get_tree().paused = prior_pause
		return
	await super._shot(name)
