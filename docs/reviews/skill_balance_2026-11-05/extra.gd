extends "res://docs/reviews/skill_balance_2026-11-05/driver.gd"

func _run() -> void:
	ProfileStore.create_new_profile(false)
	GameFlow.squad_character_ids = []
	GameFlow.clear_squad_relics()
	GameManager.reset(999999,20,1)
	_build_environment()
	for level in [40,100]:
		var rank := 2 if level==40 else 5
		await _measure("zhou_wei",{"level":level,"rank":rank,"skill_level":10,"target_hp_ratio":0.49},1,20)
	# Actual cast snapshots for three kills, and combined amplification threshold.
	for amp in [0.0,0.14]:
		audit_config={"level":40,"skill_level":10}
		var group := _make_group("guan_yu",2,3,1,0,[] as Array[StringName])
		var tower: Tower=group.tower
		tower.skill_amp=amp
		tower._base_skill_amp=amp
		tower.rage=100
		tower._try_cast_ultimate()
		for i in range(60): tower._process_pending_steps(0.02)
		probe_results["green_dragon_refund_"+str(amp)]={"rage":tower.rage,"expected_unclamped":45*1.27*(1+amp)}
		await _teardown_window()
	var file := FileAccess.open("res://docs/reviews/skill_balance_extra_2026-11-05.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"measurements":audit_results,"probes":probe_results},"\t"))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_profile_file+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_profile_file+suffix))
	print("AUDIT_EXTRA_COMPLETE")
	get_tree().quit()
