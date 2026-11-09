extends Node

const NEW_HEROES := ["diao_chan", "zhao_yun", "zhuge_liang"]
var output := "res://build/hero_models_skin_0.9.8.2"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var view := SubViewport.new()
	view.size = Vector2i(1536,1024)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var rows: Array = []
	var clipped: Array = []
	for id in BattleVisualRegistry.HEROES:
		var spec := BattleVisualRegistry.hero(id)
		var actor := BattleVisualRegistry.create_actor(spec)
		assert(actor != null)
		view.add_child(actor)
		actor.position = Vector2(768,780)
		actor.set("update_mode",2)
		var state: Object = actor.get_animation_state()
		var poses := ["Idle", "Attack_A", str(spec.get("critical", "Critical")), str(spec.get("ultimate", "XX")), "Move", "Stun", "Death"] if id in NEW_HEROES else ["Idle"]
		for facing in [-1,1]:
			actor.scale = Vector2(facing * float(spec.get("native_facing",-1)),1) * float(spec.scale) * 4
			for pose in poses:
				for index in range(16 if id in NEW_HEROES else 1):
					state.clear_tracks()
					actor.get_skeleton().set_to_setup_pose()
					var track: Object = state.set_animation(pose,false,0)
					assert(track != null)
					var duration: float = track.get_animation().get_duration()
					var at := duration * float(index) / 15
					track.set_mix_duration(0)
					track.set_track_time(at)
					actor.update_skeleton(0)
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
					assert(is_equal_approx(track.get_track_time(),at))
					var frame := view.get_texture().get_image()
					var bounds := frame.get_used_rect()
					var file := "%s_%s_%s_%02d.png" % [id,"left" if facing<0 else "right",pose,index]
					assert(bounds.has_area())
					if bounds.position.x<=0 or bounds.position.y<=0 or bounds.end.x>=view.size.x or bounds.end.y>=view.size.y: clipped.append(file)
					assert(frame.save_png(output.path_join(file)) == OK)
					rows.append({"id":id,"pose":pose,"facing":facing,"at":at,"duration":duration,"file":file,"bbox":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"game_scale":spec.scale,"render_magnification":4})
		actor.queue_free()
		await get_tree().process_frame
	var file := FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"program":ProjectSettings.get_setting("application/config/version"),"frames":rows,"clipped":clipped},"\t"))
	file.close()
	print("HERO_MODEL_CAPTURE: %d frames; clipped=%s" % [rows.size(),clipped])
	get_tree().quit(0 if clipped.is_empty() else 1)
