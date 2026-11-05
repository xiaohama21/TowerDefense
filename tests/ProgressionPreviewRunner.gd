extends Node

## 0.9.7原生实战：真实新档/拖放建造/开波/结算/养成/购物，不注入战斗收益。
var main: Node
var build_index := 0
var next_budget := 0.0
var elapsed := 0.0
var failures: Array[String] = []
var checks := 0
var slots: Array[Vector2] = []
var flags := {}
var capture_dir := "res://docs/ui_concept/runtime_0.9.7"
var slot := ""
var driving := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().gui_embed_subwindows = true
	slot = "user://.progression_preview_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(slot)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("NATIVE_PROGRESSION: " + message)

func _run() -> void:
	for flag in ["manual_ultimate", "skip_dialogue", "auto_next_wave"]:
		flags[flag] = GameFlow.is_gameplay_flag_enabled(flag)
		GameFlow.set_gameplay_flag(flag, flag == "skip_dialogue")
	_check(GameFlow.start_new_game(), "真实新档")
	GameFlow.selected_stage_id = &"ch01_s01"
	GameFlow.selected_difficulty = Difficulty.NORMAL
	GameFlow.squad_character_ids.assign(["guan_yu", "liu_bei"])
	GameFlow.clear_squad_relics()
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	for position in main.stage_data.build_slot_positions:
		var cell := Vector2i(floori(position.x / 80), floori(position.y / 80))
		if not main.build_manager._road_cells.has(cell) and not main.build_manager._forbidden_cells.has(cell): slots.append(position)
	await _shot("new_save_start")
	driving = true
	var previous_scale := Engine.time_scale
	Engine.time_scale = 5.0
	var deadline := Time.get_ticks_msec() + 110000
	var captured := false
	while main.battle_session.is_in_progress() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not captured and GameManager.current_wave >= 2 and get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP).size() >= 4:
			captured = true
			await _shot("new_save_battle")
	Engine.time_scale = previous_scale
	_check(main.battle_session.get_status() == BattleSession.STATUS_COMMITTED, "正常战斗胜利并结算")
	_check(GameManager.gold >= 0 and GameManager.lives > 0 and main.battle_session.get_deployed_character_ids().size() == 2, "合法金币与真实部署")
	var profile := ProfileStore.get_profile()
	_check(profile.stage_progress.has("ch01_s01") and profile.ingots == 30 and profile.lord_exp == 80 and profile.exp_pool > 0, "首通收益完整")
	var result := {"program": ProjectSettings.get_setting("application/config/version"), "stage": "ch01_s01", "lives": GameManager.lives, "waves": GameManager.current_wave, "gold": GameManager.gold, "pool": profile.exp_pool, "items": profile.items.duplicate(), "weapons": profile.weapons.duplicate(), "ingots": profile.ingots, "lord_exp": profile.lord_exp}
	await _shot("new_save_victory")
	main.queue_free(); main = null
	await get_tree().process_frame
	get_tree().paused = false
	while profile.exp_pool_level_up_cost("guan_yu") <= profile.exp_pool:
		if not profile.level_up_with_exp_pool("guan_yu"): break
	_check(profile.upgrade_skill("guan_yu", &"char_green_dragon"), "真实技能书升级")
	var ingots_before := profile.ingots
	_check(ProfileStore.buy_shop_offer("iron_1", int(profile.shop_state.revision)), "真实原子购买")
	profile = ProfileStore.get_profile()
	_check(profile.ingots == ingots_before - 8, "购买实际扣款")
	_check(ProfileStore.save_profile(profile), "养成持久化")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(profile.to_dict()))
	ProfileStore.profile = null
	_check(JSON.parse_string(JSON.stringify(ProfileStore.load_profile().to_dict())) == saved, "原生结算养成购买重载")
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._show_panel(&"map"); await _shot("new_save_map")
	hub._show_panel(&"develop")
	hub._panels[&"develop"]._select_character("guan_yu")
	hub._panels[&"develop"]._refresh()
	await _shot("new_save_develop")
	hub._show_panel(&"inventory"); await _shot("new_save_inventory")
	hub._show_panel(&"shop"); await _shot("new_save_shop")
	hub.queue_free()
	await get_tree().process_frame
	for flag in flags: GameFlow.set_gameplay_flag(flag, flags[flag])
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(slot + suffix))
	result["checks"] = checks; result["failures"] = failures
	var file := FileAccess.open(capture_dir.path_join("native_result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t")); file.close()
	print("NATIVE_PROGRESSION_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _process(delta: float) -> void:
	if not driving or main == null or not is_instance_valid(main) or not main.is_node_ready() or not main.battle_session.is_in_progress() or slots.is_empty(): return
	elapsed += delta
	if elapsed < next_budget: return
	next_budget = elapsed + .5
	var tower_count: int = main.tower_manager.get_child_count()
	if tower_count < main.stage_data.recommended_tower_count:
		var id := "guan_yu" if build_index % 2 == 0 else "liu_bei"
		var hero := GameFlow.load_character_data(id)
		if GameManager.gold >= hero.build_cost:
			var loadout := GameFlow.get_battle_loadout(ProfileStore.get_profile(), id)
			var stats := hero.compute_stats_at(loadout.level, loadout.rank)
			var best := 0; var score := -1
			for i in range(slots.size()):
				var coverage := 0
				for j in range(int(main.path_2d.curve.get_baked_length() / 40)):
					if slots[i].distance_to(main.path_2d.curve.sample_baked(j * 40.0)) <= stats.range: coverage += 1
				if coverage > score: score = coverage; best = i
			if main.build_manager.begin_drag(hero):
				main.build_manager._update_drag_at(slots[best]); main.build_manager.release_drag()
				_check(main.tower_manager.get_child_count() == tower_count + 1, "原生合法拖放建造")
				build_index += 1; slots.remove_at(best)
	else:
		for tower in main.tower_manager.get_children():
			if main.tower_manager.upgrade_tower(tower, main.stage_data): break
	if not GameManager.is_wave_active and GameManager.current_wave < GameManager.total_waves: main._try_start_wave()

func _shot(name: String) -> void:
	var prior_pause := get_tree().paused
	var prior_driving := driving
	driving = false
	if main != null: get_tree().paused = true
	await get_tree().create_timer(.1, true, false, true).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	_check(get_viewport().get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "原生截图 " + name)
	get_tree().paused = prior_pause
	driving = prior_driving
