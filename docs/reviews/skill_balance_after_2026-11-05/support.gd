extends "res://docs/reviews/skill_balance_after_2026-11-05/driver.gd"

func _run() -> void:
	ProfileStore.create_new_profile(false)
	GameFlow.squad_character_ids = []; GameFlow.clear_squad_relics()
	GameManager.reset(999999,20,1); _build_environment()
	for id in ["", "liu_bei", "diao_chan"]:
		for followers in [1, 3, 6]:
			for skill_level in [1, 10]: await _support(id, 0, skill_level, followers)
	var file := FileAccess.open("res://docs/reviews/skill_balance_after_support_2026-11-05.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"program": "0.9.6.3", "seconds": 60, "samples": 3, "measurements": audit_results}, "\t")); file.close()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_profile_file + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_profile_file + suffix))
	print("AUDIT_SUPPORT_COMPLETE rows=%d" % audit_results.size()); get_tree().quit()
