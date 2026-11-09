extends Node

const IDS := ["diao_chan","zhao_yun","zhuge_liang"]
const UITheme = preload("res://scripts/ui_screens/ui_theme.gd")
var checks := 0
var failures: Array[String] = []
var slot := ""

func _ready() -> void:
	slot = "user://.hero_models_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(slot)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("HERO_MODEL: " + message)

func tower_for(id: String, at: Vector2) -> Tower:
	var tower := (load("res://scenes/Tower.tscn") as PackedScene).instantiate() as Tower
	add_child(tower)
	tower.set_process(false)
	tower.apply_character(GameFlow.load_character_data(id), {"level":1,"rank":2})
	tower.position = at
	if tower._spine != null: tower._spine.set("update_mode",2)
	return tower

func pose(tower: Tower) -> String:
	return str(tower._spine.get_animation_state().get_track(0).get_animation().get_name())

func run() -> void:
	ProfileStore.create_new_profile(false)
	GameFlow.squad_character_ids = []
	GameFlow.clear_squad_relics()
	GameManager.reset(1000,20,1)
	if not ClassDB.class_exists("SpineSprite"):
		await run_fallback()
		finish()
		return
	for id in IDS:
		var tower := tower_for(id,Vector2(400,300))
		var ally := tower_for("guan_yu",Vector2(440,300))
		var spec := BattleVisualRegistry.hero(id)
		check(tower._spine != null and tower._use_spine_visual,id+" native actor")
		if tower._spine == null: get_tree().quit(1); return
		for facing in [-1,1]:
			tower._facing = facing
			tower._apply_spine_facing()
			check(is_equal_approx(tower._spine.scale.x,float(facing)*float(spec.native_facing)*float(spec.scale)),id+" facing "+str(facing))
		check(tower._spine.get_skeleton().get_skin() != null,id+" explicitly selected skin")
		var skeleton_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/battle_visuals/%s/%s.spine-json" % [id,id]))
		for bone_name in skeleton_data.skins[0].get("bones",[]):
			check(tower._spine.get_skeleton().find_bone(str(bone_name)).is_active(),id+" skin bone active "+str(bone_name))
		var avatar := UITheme.hero_avatar(id,id)
		check(avatar is TextureRect and avatar.texture != null and avatar.texture.resource_path == BattleVisualRegistry.PORTRAITS[id],id+" shared portrait")
		avatar.free()
		var lane := Path2D.new()
		lane.curve = Curve2D.new()
		lane.curve.add_point(Vector2(450,300))
		lane.curve.add_point(Vector2(1200,300))
		add_child(lane)
		var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Enemy
		enemy.max_hp = 10000; enemy.speed = 0; enemy.reward = 0
		lane.add_child(enemy); enemy.set_process(false)
		tower.target = enemy
		tower._update_aim()
		check(tower._facing == 1,id+" aims toward enemy")
		tower._play_spine_attack()
		check(pose(tower)=="Attack_A",id+" normal animation")
		check(is_equal_approx(tower._spine.get_animation_state().get_track(0).get_track_time(),float(spec.get("attack_start",0))),id+" release pose")
		tower.crit_rate = .75; tower.crit_damage = 1.5
		if id == "diao_chan":
			var before_hp := enemy.current_hp
			seed(431); var next_random := randf(); seed(431)
			BehaviorRegistry.execute_attack(&"attack_speed_aura",tower,null)
			check(ally._buff_sources.has("aura_attack") and enemy.current_hp==before_hp,"dancer actual pulse is instant support")
			check(is_equal_approx(randf(),next_random) and pose(tower)=="Attack_A","dancer pulse does not invent critical damage or consume RNG")
		elif id == "zhao_yun":
			check(is_equal_approx(tower.melee_hit_delay(),.11),"Zhao original melee timing")
			seed(8923); var sample := randf(); var next_random := randf(); seed(8923)
			tower.schedule_melee_hit(enemy,20)
			tower._process_pending_steps(.109)
			check(enemy.current_hp==10000,"Zhao no early damage")
			tower._process_pending_steps(.002)
			check(enemy.current_hp==10000-(30 if sample<.75 else 20) and is_equal_approx(randf(),next_random),"Zhao one real hit and one critical draw")
			var track: Object = tower._spine.get_animation_state().set_animation("Active_A",false,0)
			track.set_mix_duration(0); track.set_track_time(.5059); tower._spine.update_skeleton(0)
			var bone: Object = tower._spine.get_skeleton().find_bone("Character")
			var motion: Object = bone.get_pose()
			var setup: Object = bone.get_data().get_setup_pose()
			check(absf(float(motion.get_y())-float(setup.get_y()))<35 and tower.position==Vector2(400,300),"Zhao root stays near build point during native jump")
			tower._use_spine_visual = false
			check(is_equal_approx(tower.melee_hit_delay(),.11),"Zhao timing survives renderer fallback")
			tower._use_spine_visual = true
		else:
			BehaviorRegistry.execute_attack(&"area_spell",tower,enemy)
			var bullet: Bullet = null
			for child in get_children():
				if child is Bullet: bullet=child
			check(bullet != null and enemy.current_hp==10000,"Zhuge projectile launches now; damage waits for impact")
			if bullet != null:
				bullet.set_physics_process(false)
				bullet.damage = 20
				# Launch refreshes derived stats; inject the deterministic hit-time rate afterwards.
				tower.crit_rate = .75
				var critical_seed := 1
				seed(critical_seed)
				while randf() >= .75:
					critical_seed+=1; seed(critical_seed)
				seed(critical_seed); var sample := randf(); var next_random := randf(); seed(critical_seed)
				bullet.global_position=enemy.global_position
				bullet._physics_process(.001)
				check(sample<.75 and enemy.current_hp==9970 and pose(tower)=="Critical","Zhuge actual projectile critical changes pose at impact: hp=%d pose=%s roll=%f" % [enemy.current_hp,pose(tower),sample])
				check(is_equal_approx(randf(),next_random),"Zhuge impact consumes one original random draw")
		if id != "diao_chan":
			tower._spine_cast_busy_left=0
			tower._play_spine_idle(); tower._play_spine_attack()
			check(tower.attack_hit_damage(20,.99)==20 and pose(tower)=="Attack_A",id+" noncritical keeps normal pose")
			check(tower.attack_hit_damage(20,.01)==30 and pose(tower)=="Critical",id+" true critical pose")
			check(is_equal_approx(tower._spine.get_animation_state().get_track(0).get_track_time(),float(spec.critical_start)),id+" original critical impact frame")
		tower._play_spine_idle(); tower.rage=100
		var before := enemy.current_hp
		check(tower._try_cast_ultimate(),id+" real ultimate cast")
		check(pose(tower)==str(spec.ultimate) and tower.ultimate_hit_delay()==0,id+" mapped native cast with immediate effect")
		if id=="diao_chan": check(ally._buff_sources.has("char_moon_dance"),"moon dance real global buff")
		else: check(enemy.current_hp<before,id+" immediate original ultimate damage")
		tower._play_spine_attack()
		check(pose(tower)==str(spec.ultimate),id+" cast pose priority")
		tower._spine.get_animation_state().get_track(0).set_track_time(2)
		tower._spine.update_skeleton(0)
		tower._update_spine_animation(2)
		check(pose(tower)=="Idle",id+" returns to idle")
		for node in [tower,ally,lane]: node.queue_free()
		await get_tree().process_frame
	finish()

func run_fallback() -> void:
	for id in IDS:
		var tower := tower_for(id, Vector2(400,300))
		var ally := tower_for("guan_yu", Vector2(440,300))
		check(tower._spine == null and not tower._use_spine_visual, id+" procedural fallback")
		var avatar := UITheme.hero_avatar(id,id)
		check(avatar is TextureRect and avatar.texture != null and avatar.texture.resource_path == BattleVisualRegistry.PORTRAITS[id], id+" portrait without native runtime")
		avatar.free()
		var lane := Path2D.new()
		lane.curve = Curve2D.new()
		lane.curve.add_point(Vector2(450,300))
		lane.curve.add_point(Vector2(1200,300))
		add_child(lane)
		var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Enemy
		enemy.max_hp = 10000; enemy.speed = 0; enemy.reward = 0
		lane.add_child(enemy); enemy.set_process(false)
		tower.target = enemy
		if id == "diao_chan":
			seed(431); var next_random := randf(); seed(431)
			BehaviorRegistry.execute_attack(&"attack_speed_aura",tower,null)
			check(ally._buff_sources.has("aura_attack") and enemy.current_hp == 10000, "fallback Diao instant support without damage")
			check(is_equal_approx(randf(),next_random), "fallback support preserves RNG")
		elif id == "zhao_yun":
			BehaviorRegistry.execute_attack(&"single_target_burst",tower,enemy)
			check(tower.has_pending_combat_steps() and is_equal_approx(tower.melee_hit_delay(),.11), "fallback Zhao schedules original melee delay")
			tower._process_pending_steps(.109)
			check(enemy.current_hp == 10000, "fallback Zhao no early damage")
			tower._process_pending_steps(.002)
			check(enemy.current_hp < 10000 and not tower.has_pending_combat_steps(), "fallback Zhao resolves real attack once")
		else:
			BehaviorRegistry.execute_attack(&"area_spell",tower,enemy)
			var bullet: Bullet = null
			for child in get_children():
				if child is Bullet: bullet = child
			check(bullet != null and enemy.current_hp == 10000, "fallback Zhuge launches without early damage")
			if bullet != null:
				bullet.set_physics_process(false)
				bullet.global_position = enemy.global_position
				bullet._physics_process(.001)
				check(enemy.current_hp < 10000, "fallback Zhuge real projectile impact")
		tower.rage = 100
		var before := enemy.current_hp
		check(tower._try_cast_ultimate() and tower.ultimate_hit_delay() == 0, id+" fallback instant ultimate")
		check(ally._buff_sources.has("char_moon_dance") if id == "diao_chan" else enemy.current_hp < before, id+" fallback real ultimate effect")
		for node in [tower,ally,lane]: node.queue_free()
		await get_tree().process_frame

func finish() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(slot+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(slot+suffix))
	print("HERO_MODEL_RESULT: %s checks=%d native=%s failures=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,ClassDB.class_exists("SpineSprite"),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
