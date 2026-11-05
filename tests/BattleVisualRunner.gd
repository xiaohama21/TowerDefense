extends Node

var checks := 0
var failures: Array[String] = []
var slot := ""
var path: Path2D

func _ready() -> void:
	slot = "user://.battle_visual_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(slot)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("BATTLE_VISUAL: " + message)

func tower_for(id: String) -> Tower:
	var tower := (load("res://scenes/Tower.tscn") as PackedScene).instantiate() as Tower
	add_child(tower); tower.set_process(false)
	tower.apply_character(GameFlow.load_character_data(id), {"level": 1, "rank": 0})
	tower.crit_rate = 0
	return tower

func run() -> void:
	ProfileStore.create_new_profile(false)
	GameFlow.squad_character_ids = []; GameFlow.clear_squad_relics()
	GameManager.reset(1000, 20, 1)
	path = Path2D.new(); path.curve = Curve2D.new()
	path.curve.add_point(Vector2(200, 200)); path.curve.add_point(Vector2(1200, 200))
	add_child(path)
	var native := ClassDB.class_exists("SpineSprite")
	for id in ["guan_yu", "liu_bei"]:
		var tower := tower_for(id)
		check(tower._use_spine_visual == native, id + " renderer availability")
		var spec := BattleVisualRegistry.hero(id)
		var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Enemy
		enemy.max_hp = 1000; enemy.speed = 0; enemy.reward = 0
		path.add_child(enemy); enemy.set_process(false)
		for fallback in [false, true]:
			if fallback: tower._use_spine_visual = false
			check(is_equal_approx(tower.melee_hit_delay(), float(spec.hit)), id + " timing independent of renderer")
			check(is_equal_approx(tower.ultimate_hit_delay(), float(spec.ult_hit)), id + " ultimate timing independent of renderer")
			var before := enemy.current_hp
			tower.schedule_melee_hit(enemy, 10)
			tower._process_pending_steps(float(spec.hit) - .001)
			check(enemy.current_hp == before, id + " no damage before hit frame")
			tower._process_pending_steps(.002)
			check(enemy.current_hp == before - 10 and not tower.has_pending_combat_steps(), id + " one hit at original frame")
			tower.attack_cooldown = .05
			check(tower.melee_hit_delay() <= .04 + .000001, id + " high speed timing clamp")
			tower.attack_cooldown = 1.0
		tower.queue_free(); enemy.queue_free()
		await get_tree().process_frame
	var reassigned := tower_for("guan_yu")
	var first := reassigned._spine
	reassigned.apply_character(GameFlow.load_character_data("liu_bei"), {"level": 1, "rank": 0})
	if native: check(reassigned._spine != first and first.get_parent() == null, "reassign removes previous actor")
	reassigned.apply_character(GameFlow.load_character_data("zhang_fei"), {"level": 1, "rank": 0})
	check(reassigned._spine == null and not reassigned._use_spine_visual, "uncovered identity uses procedural actor")
	reassigned.queue_free(); await get_tree().process_frame
	check(BattleVisualRegistry.create_actor({}) == null, "empty registry fallback")
	check(BattleVisualRegistry.create_actor({"data": "res://assets/battle_visuals/missing.tres"}) == null, "missing resource fallback")
	for id in BattleVisualRegistry.ENEMIES:
		var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Enemy
		enemy.enemy_id = id; enemy.max_hp = 1000; enemy.reward = 0
		path.add_child(enemy); enemy.set_process(false)
		check((enemy._visual_actor != null) == native, id + " native identity")
		check(enemy.body.visible != native, id + " legacy body visibility")
		if native:
			if id == "yellow_turban_general":
				enemy.tags = [&"boss"]
				check(is_equal_approx(enemy.get_hp_bar_size().x, maxf(84, float(enemy._visual_profile.width) * float(enemy._visual_profile.scale) + 24)), "Boss bar follows rendered width")
			enemy.velocity_dir = Vector2.LEFT; enemy._update_visual_actor()
			check(enemy._visual_actor.scale.x < 0, id + " left facing")
			enemy.velocity_dir = Vector2.DOWN; enemy._update_visual_actor()
			check(enemy._visual_actor.scale.x < 0, id + " vertical holds facing")
			enemy.progress = 400; enemy.velocity_dir = Vector2.RIGHT
			enemy._fear_time_left = 1; enemy._process(.1)
			check(enemy.progress < 400 and enemy._visual_actor.scale.x < 0, id + " fear matches displacement")
			var before := enemy.progress
			enemy.apply_stun(.5); enemy._process(.1)
			check(enemy.progress == before and enemy._visual_animation == "Stun", id + " stun stops movement")
			check(enemy.get_hp_bar_rect().end.y <= float(enemy._visual_profile.foot) - float(enemy._visual_profile.top) * float(enemy._visual_profile.scale) - 9.9, id + " head clearance")
			enemy._hit_flash_left = .1; enemy._apply_body_modulate()
			check(enemy._visual_actor.modulate == enemy.body.modulate, id + " damage tint")
			enemy.set_process(true); enemy.die(true)
			check(enemy.is_dead and enemy._visual_animation == "Death" and not enemy.is_in_group(Enemy.ENEMY_GROUP), id + " death leaves combat immediately")
			enemy._advance_death_fade(.5)
		else: enemy.queue_free()
		await get_tree().process_frame
	path.queue_free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(slot + suffix))
	print("BATTLE_VISUAL_RESULT: %s checks=%d native=%s failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, native, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
