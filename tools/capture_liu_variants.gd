extends Node

var output := "res://build/liu_variants_0.9.8.1"
const VARIANTS := {
	"a_158":{"data":"res://assets/battle_visuals/liu_bei/variants/a_158/liu_bei_158-data.tres","scale":.53,"facing":-1},
	"b_original":{"data":"res://assets/battle_visuals/liu_bei/variants/b_original/liu_bei_original-data.tres","scale":.43,"facing":1},
}

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var view:=SubViewport.new();view.size=Vector2i(1024,1024);view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(view)
	var rows:Array=[]
	for id in VARIANTS:
		var spec:Dictionary=VARIANTS[id]
		var actor:Node2D=ClassDB.instantiate("SpineSprite")
		actor.set("skeleton_data_res",load(spec.data));view.add_child(actor)
		actor.set("update_mode",2);actor.position=Vector2(512,780)
		var state:Object=actor.get_animation_state()
		var poses:Dictionary={"Idle":1.0 if id=="a_158" else 1.3,"Move":.6667 if id=="a_158" else .5,"Attack_A":.33,"Critical":.44,"Active_A":.4,"XX":.55,"Stun":1.0 if id=="a_158" else .5,"Death":.8333 if id=="a_158" else .4}
		for facing in [-1,1]:
			actor.scale=Vector2(facing*float(spec.facing),1)*float(spec.scale)*4
			for pose in poses:
				for index in range(16):
					state.clear_tracks();actor.get_skeleton().set_to_setup_pose()
					var track:Object=state.set_animation(pose,false,0);assert(track!=null)
					var at:float=float(poses[pose])*index/15
					track.set_mix_duration(0);track.set_track_time(at);actor.update_skeleton(0)
					await get_tree().process_frame;await RenderingServer.frame_post_draw
					assert(is_equal_approx(track.get_track_time(),at))
					var frame:=view.get_texture().get_image();var rect:=frame.get_used_rect()
					var file:="%s_%s_%s_%02d.png"%[id,"left" if facing<0 else "right",pose,index]
					frame.save_png(output.path_join(file))
					rows.append({"variant":id,"pose":pose,"facing":facing,"time":at,"bbox":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"file":file,"game_scale":spec.scale,"preview_scale":4})
		actor.queue_free();await get_tree().process_frame
	var file:=FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close()
	print("LIU_VARIANTS_CAPTURE: %d frames"%rows.size());get_tree().quit()
