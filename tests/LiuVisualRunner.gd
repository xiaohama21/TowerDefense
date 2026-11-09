extends Node

var checks := 0
var failures: Array[String] = []
var slot := ""
var variant := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="): variant=arg.trim_prefix("--variant=")
	slot = "user://.liu_visual_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(slot)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("LIU_VISUAL: " + message)

func name_of(tower: Tower) -> String:
	return str(tower._spine.get_animation_state().get_track(0).get_animation().get_name())

func make_tower(id: String, position_at: Vector2) -> Tower:
	var tower := (load("res://scenes/Tower.tscn") as PackedScene).instantiate() as Tower
	add_child(tower); tower.set_process(false)
	tower.apply_character(GameFlow.load_character_data(id), {"level": 1, "rank": 2})
	if id == "liu_bei" and not variant.is_empty():
		var specs: Dictionary = preload("res://tools/capture_liu_variants.gd").VARIANTS
		assert(specs.has(variant))
		tower._spine.free()
		tower._spine_profile.merge({"attack_time_scale":1.0,"attack_duration":.33,"critical_start":.11,"critical_time_scale":1.0,"ultimate":"XX","ult_time_scale":1.0,"support":"Active_A"},true)
		tower._spine_profile.merge(specs[variant],true)
		tower._spine_profile["native_facing"]=specs[variant].facing
		tower._spine=BattleVisualRegistry.create_actor(tower._spine_profile)
		tower.add_child(tower._spine)
		tower._play_spine_idle()
	tower.position = position_at
	return tower

func run() -> void:
	ProfileStore.create_new_profile(false); GameManager.reset(1000, 20, 1)
	GameFlow.squad_character_ids = []; GameFlow.clear_squad_relics()
	var tower := make_tower("liu_bei", Vector2(300,300))
	var ally := make_tower("guan_yu", Vector2(320,300))
	var spec := tower._spine_profile
	var ultimate := str(spec.get("ultimate", "XX"))
	check(tower._use_spine_visual, "native refined rig")
	if not tower._use_spine_visual: get_tree().quit(1); return
	tower._facing = 1; tower._apply_spine_facing()
	var native_facing:float=float(tower._spine_profile.get("native_facing",1))
	check(tower._spine.scale.x * native_facing > 0 and is_equal_approx(tower._spine.scale.y,float(tower._spine_profile.scale)), "right three-quarter scale")
	tower._facing = -1; tower._apply_spine_facing()
	check(tower._spine.scale.x * native_facing < 0, "left three-quarter mirror")
	tower._play_spine_attack()
	check(name_of(tower) == "Attack_A", "actual normal attack")
	check(is_equal_approx(tower._spine.get_animation_state().get_track(0).get_time_scale(), float(spec.get("attack_time_scale", 1.0))), "source attack playback matches combat hit time")
	tower.crit_rate = .75; tower.crit_damage = 1.5
	check(tower.attack_hit_damage(20, .9) == 20 and name_of(tower) == "Attack_A", "non-critical never uses critical pose")
	check(tower.attack_hit_damage(20, .01) == 30 and name_of(tower) == "Critical", "actual critical damage drives critical pose")
	check(is_equal_approx(tower._spine.get_animation_state().get_track(0).get_track_time(), float(spec.get("critical_start", .11))), "critical enters original hit frame")
	var lane := Path2D.new(); lane.curve = Curve2D.new()
	lane.curve.add_point(Vector2(300,300)); lane.curve.add_point(Vector2(2000,300)); add_child(lane)
	var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.max_hp = 1000; enemy.speed = 0; enemy.reward = 0
	lane.add_child(enemy); enemy.set_process(false)
	seed(8923); var expected_sample := randf(); var next_sample := randf(); seed(8923)
	tower.schedule_melee_hit(enemy,20)
	tower._process_pending_steps(.109)
	check(enemy.current_hp == 1000, "enlarged art does not advance damage")
	tower._process_pending_steps(.002)
	check(enemy.current_hp == 1000 - (30 if expected_sample < .75 else 20), "scheduled real hit preserves critical damage")
	check(is_equal_approx(randf(), next_sample), "exactly one original hit-time random draw")
	tower._play_spine_idle(); tower._support_visual_cooldown = 0
	tower.skill_aura_tick = 0; tower.skill_support_tick = 0
	SkillRegistry.tick(tower,.25)
	ally.refresh_aura_damage_bonus()
	check(name_of(tower) == str(spec.get("support", "Idle")) and ally._aura_attack_flat > 0, "real aura effect uses available original pose")
	tower._play_spine_attack()
	check(name_of(tower) == "Attack_A", "normal attack interrupts low-priority aura gesture")
	tower.play_support_animation()
	check(name_of(tower) == "Attack_A", "aura does not interrupt attack")
	tower.rage = 100
	check(tower._try_cast_ultimate(), "actual carry-people cast succeeds")
	check(name_of(tower) == ultimate and tower.ultimate_hit_delay() == 0 and not ally._buff_sources.is_empty(), "cast pose with immediate ally effect")
	var dealt := tower.attack_hit_damage(20,.01)
	check(dealt == 30 and name_of(tower) == ultimate, "cast pose priority never blocks critical damage")
	tower._spine.get_animation_state().get_track(0).set_track_time(1.5)
	tower._spine.update_skeleton(0)
	tower._update_spine_animation(.6)
	check(name_of(tower) == "Idle", "cast returns to idle")
	for node in [tower,ally,lane]: node.queue_free()
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(slot + suffix))
	print("LIU_VISUAL_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
