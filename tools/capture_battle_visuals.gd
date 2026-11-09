extends Node

## Native Spine frames. Run with a renderer, never --headless.
var checks := 0
var failures: Array[String] = []
var rows: Array = []
var output := "res://build/battle_visual_frames_latest"
var root: Window

func _ready() -> void:
	root = get_tree().root
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var view := SubViewport.new()
	view.size = Vector2i(256, 256)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for id in BattleVisualRegistry.HEROES.keys() + BattleVisualRegistry.ENEMIES.keys():
		var spec := BattleVisualRegistry.hero(id) if BattleVisualRegistry.HEROES.has(id) else BattleVisualRegistry.enemy(id)
		var actor := BattleVisualRegistry.create_actor(spec)
		check(actor != null, id + " native rig")
		if actor == null: continue
		view.add_child(actor)
		actor.position += Vector2(128, 170)
		actor.set_process(false); actor.set_physics_process(false)
		actor.set("update_mode", 2) # Spine Manual: native screenshots have exact timestamps.
		var state: Object = actor.get_animation_state()
		for facing in [-1, 1]:
			actor.scale.x = facing * float(spec.get("native_facing", -1)) * float(spec.scale)
			var poses := ["Idle", "Move", "Attack_A", str(spec.get("ultimate", "XX")), "Stun", "Death"]
			if spec.has("critical"): poses.append(str(spec.critical))
			for pose in poses:
				state.clear_tracks()
				actor.get_skeleton().set_to_setup_pose()
				var track: Object = state.set_animation(pose, false, 0)
				check(track != null, id + " " + pose)
				if track == null: continue
				track.set_mix_duration(0)
				var at := .125
				if pose == "Idle": at = 0.0
				if pose == "Attack_A": at = float(spec.get("attack_source_hit", spec.get("hit", .11)))
				if pose == "XX": at = float(spec.get("ult_hit", 0.0))
				if pose == "Death": at = .3
				if pose == "Critical": at = float(spec.get("critical_start", .11))
				track.set_track_time(at)
				actor.update_skeleton(0.0)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				check(is_equal_approx(track.get_track_time(), at), id + " " + pose + " exact frame time")
				var frame := view.get_texture().get_image()
				var bounds := frame.get_used_rect()
				var filename := "%s_%s_%s.png" % [id, "left" if facing < 0 else "right", pose]
				check(bounds.size.x > 12 and bounds.size.y > 20, filename + " rendered pixels")
				check(frame.save_png(output.path_join(filename)) == OK, filename + " save")
				rows.append({"id": id, "pose": pose, "facing": facing, "at": at, "bbox": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y], "file": filename})
		if id == "liu_bei":
			view.size = Vector2i(512, 512)
			actor.scale = Vector2(float(spec.get("native_facing", -1)), 1) * 2
			actor.position = Vector2(256, 390)
			state.clear_tracks(); actor.get_skeleton().set_to_setup_pose()
			state.set_animation("Idle", false, 0); actor.update_skeleton(0)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			view.get_texture().get_image().save_png(output.path_join("liu_bei_portrait_frame.png"))
			view.size = Vector2i(256, 256)
		actor.queue_free(); await get_tree().process_frame
	for id in BattleVisualRegistry.ENEMIES:
		var lane := Path2D.new(); lane.curve = Curve2D.new()
		lane.curve.add_point(Vector2(128, 170)); lane.curve.add_point(Vector2(500, 170)); view.add_child(lane)
		var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Enemy
		enemy.enemy_id = id; enemy.max_hp = 1000; enemy.speed = 0
		if id == "yellow_turban_sergeant": enemy.tags = [&"elite"]
		if id == "yellow_turban_general": enemy.tags = [&"boss"]
		lane.add_child(enemy); enemy.set_process(false)
		enemy.current_hp = 500; enemy.apply_stun(.5); enemy._update_visual_actor(); enemy.update_hp_bar()
		await get_tree().process_frame; await RenderingServer.frame_post_draw
		check(view.get_texture().get_image().save_png(output.path_join(id + "_status.png")) == OK, id + " HP/stun native frame")
		lane.queue_free(); await get_tree().process_frame
	var file := FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"program": ProjectSettings.get_setting("application/config/version"), "checks": checks, "failures": failures, "frames": rows}, "\t")); file.close()
	print("BATTLE_FRAMES_RESULT: %s checks=%d frames=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, rows.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
