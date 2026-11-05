extends Node

var output := "res://build/liu_design_0.9.8.1"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var view := SubViewport.new()
	view.size = Vector2i(1024,1024); view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(view)
	for id in ["guan_yu","liu_bei"]:
		var spec := BattleVisualRegistry.hero(id)
		var actor := BattleVisualRegistry.create_actor(spec)
		view.add_child(actor); actor.set("update_mode",2)
		actor.scale = Vector2(float(spec.get("native_facing",-1)),1) * float(spec.scale) * 4
		actor.position = Vector2(512,780)
		var state: Object = actor.get_animation_state()
		var poses := {"Idle":0.0,"Attack_A":float(spec.get("attack_source_hit",spec.hit))}
		if id == "liu_bei": poses.merge({"Critical":.3,"Appear":.6})
		for pose in poses:
			state.clear_tracks(); actor.get_skeleton().set_to_setup_pose()
			var track: Object = state.set_animation(pose,false,0)
			track.set_mix_duration(0); track.set_track_time(float(poses[pose])); actor.update_skeleton(0)
			await get_tree().process_frame; await RenderingServer.frame_post_draw
			assert(is_equal_approx(track.get_track_time(),float(poses[pose])))
			view.get_texture().get_image().save_png(output.path_join(id+"_"+pose+".png"))
		actor.queue_free(); await get_tree().process_frame
	print("LIU_DESIGN_CAPTURE: 6 high-resolution native frames")
	get_tree().quit()
