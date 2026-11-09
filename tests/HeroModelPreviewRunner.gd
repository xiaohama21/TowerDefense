extends Node

## Native visual fixture; test-only unlocks/currency/target HP are not balance evidence.
const IDS := ["diao_chan", "zhao_yun", "zhuge_liang"]
var slot := ""
var output := "res://build/verify_heroes_0.9.8.2/native"
var checks := 0
var failures: Array[String] = []
var flags := {}
var main: Node
var towers := {}
var observed := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().gui_embed_subwindows = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	slot = "user://.hero_preview_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(slot)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("HERO_PREVIEW: " + message)

func shot(name: String, mouse_at := Vector2(1275,5)) -> void:
	var paused := get_tree().paused
	if main != null: get_tree().paused = true
	Input.warp_mouse(mouse_at)
	await get_tree().create_timer(.12,true,false,true).timeout
	if name.begins_with("drag_"):
		main.build_manager._update_drag_at(mouse_at)
		var ghost: Tower = main.build_manager._ghost
		check(main.build_manager._drag_valid and ghost.is_visible_in_tree() and ghost._spine != null and ghost.character_id == name.trim_prefix("drag_"), "visible same-model drag ghost " + name)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	check(get_viewport().get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"capture "+name)
	get_tree().paused = paused

func check_portrait(node: Node, id: String) -> void:
	var found := false
	for rect in node.find_children("*","TextureRect",true,false):
		if rect.is_visible_in_tree() and rect.texture != null and rect.texture.resource_path == BattleVisualRegistry.PORTRAITS[id]:
			found = true
	check(found,"visible same-model UI portrait "+id)

func run() -> void:
	for flag in ["manual_ultimate","skip_dialogue","auto_next_wave"]:
		flags[flag] = GameFlow.is_gameplay_flag_enabled(flag)
		GameFlow.set_gameplay_flag(flag,flag != "auto_next_wave")
	var profile := ProfileStore.create_new_profile(false)
	for id in IDS:
		profile.unlock_character(id)
		profile.characters[id].rank = 2
	profile.unlock_character("guan_yu")
	ProfileStore.save_profile(profile)
	GameFlow.selected_stage_id = &"ch01_s01"
	GameFlow.selected_difficulty = Difficulty.NORMAL
	GameFlow.squad_character_ids.assign(IDS)
	GameFlow.clear_squad_relics()
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	for panel_id in [&"develop", &"encyclopedia"]:
		hub._show_panel(panel_id)
		var panel = hub._panels[panel_id]
		for id in IDS + ["guan_yu"]:
			panel._select_character(id)
			if panel_id == &"develop": panel._refresh()
			await shot(str(panel_id)+"_"+id)
			check_portrait(panel,id)
	hub.queue_free()
	await get_tree().process_frame
	var squad := (load("res://scenes/SquadSelect.tscn") as PackedScene).instantiate()
	add_child(squad)
	await shot("squad_heroes")
	for id in IDS + ["guan_yu"]: check_portrait(squad,id)
	squad.queue_free()
	await get_tree().process_frame
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	for child in main.ui.get_node("Root").get_children():
		if child.get_script() == load("res://scripts/DebugPanel.gd"): child.visible = false
	GameManager.gold = 1000
	var positions := {"diao_chan":Vector2(520,200),"zhao_yun":Vector2(440,200),"zhuge_liang":Vector2(600,200)}
	for id in IDS:
		var hero := GameFlow.load_character_data(id)
		check(main.build_manager.begin_drag(hero),id+" begin actual drag")
		main.build_manager._update_drag_at(positions[id])
		await shot("drag_"+id,positions[id])
		main.build_manager._update_drag_at(positions[id])
		main.build_manager.release_drag()
		for tower in main.tower_manager.get_children():
			if tower.character_id == id: towers[id] = tower
		check(towers.has(id),id+" actual drag deployment")
		if not towers.has(id): get_tree().quit(1); return
		observed[id] = {}
		if id != "diao_chan":
			towers[id]._base_crit_rate = .75
			towers[id].refresh_aura_damage_bonus()
	var target := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Enemy
	target.enemy_id = "yellow_turban_soldier"
	target.max_hp = 100000; target.speed = 0; target.reward = 0
	main.path_2d.add_child(target)
	target.progress = 560
	seed(620)
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		for id in IDS:
			var track: Object = towers[id]._spine.get_animation_state().get_track(0)
			observed[id][str(track.get_animation().get_name())] = true
	check(target.current_hp < target.max_hp,"natural melee/projectile damage")
	check(towers.zhao_yun._buff_sources.has("aura_attack"),"natural Diao support pulse")
	for id in IDS:
		check(observed[id].has("Attack_A"),id+" natural normal animation")
		if id != "diao_chan": check(observed[id].has("Critical"),id+" actual damage critical animation")
	await shot("battle_heroes")
	for id in IDS:
		var tower: Tower = towers[id]
		tower.rage = 100
		tower._manual_ultimate_mode = true
		check(tower.cast_ultimate_manual(),id+" actual manual ultimate")
		await get_tree().create_timer(.08).timeout
		check(str(tower._spine.get_animation_state().get_track(0).get_animation().get_name()) == str(BattleVisualRegistry.hero(id).ultimate),id+" native cast pose")
		await shot("cast_"+id)
		await get_tree().create_timer(.7).timeout
	main.queue_free(); main = null
	await get_tree().process_frame
	for flag in flags: GameFlow.set_gameplay_flag(flag,flags[flag])
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(slot+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(slot+suffix))
	var result := {"program":"0.9.8.2","checks":checks,"failures":failures,"observed":observed,"fixture":"isolated unlocked rank2 heroes, 1000 build gold, stationary 100000HP target, 75% critical for native branch coverage; not balance evidence"}
	var file := FileAccess.open(output.path_join("native_result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")); file.close()
	print("HERO_PREVIEW_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
