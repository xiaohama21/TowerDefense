extends Node

var output := "res://build/liu_motion_0.9.8.1"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var view := SubViewport.new(); view.size = Vector2i(512,512); view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(view)
	var spec := BattleVisualRegistry.hero("liu_bei")
	var actor := BattleVisualRegistry.create_actor(spec)
	view.add_child(actor); actor.position += Vector2(256,350)
	actor.set_process(false); actor.set_physics_process(false)
	actor.set("update_mode", 2) # Spine Manual: keep the requested time through rendering.
	var state: Object = actor.get_animation_state()
	var poses := {"Idle":1.0,"Move":.6667,"Attack_A":.8667,"Critical":1.3667,"Appear":1.4667,"Stun":1.0,"Death":.8333}
	var rows: Array = []
	for facing in [-1,1]:
		actor.scale.x = float(facing) * float(spec.native_facing) * float(spec.scale)
		for pose in poses:
			for index in range(16):
				state.clear_tracks(); actor.get_skeleton().set_to_setup_pose()
				var track: Object = state.set_animation(pose,false,0)
				track.set_mix_duration(0)
				track.set_track_time(float(poses[pose])*float(index)/15)
				actor.update_skeleton(0)
				await get_tree().process_frame; await RenderingServer.frame_post_draw
				assert(is_equal_approx(track.get_track_time(), float(poses[pose])*float(index)/15))
				var filename := "%s_%s_%02d.png" % ["left" if facing<0 else "right",pose,index]
				view.get_texture().get_image().save_png(output.path_join(filename))
				rows.append({"file":filename,"pose":pose,"facing":facing,"at":float(poses[pose])*float(index)/15})
	var file := FileAccess.open(output.path_join("motion.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t")); file.close()
	print("LIU_MOTION_CAPTURE: %d frames" % rows.size())
	get_tree().quit()
