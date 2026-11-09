extends Node

## Separate portrait instance: combat actors always keep all source attachments.
const HIDDEN := ["weapon", "weapon2", "weapon_stick"]
var output := "res://build/hero_portraits_0.9.8.2"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func hide_portrait_weapons(actor: Node2D) -> void:
	for name in HIDDEN:
		actor.get_skeleton().find_slot(name).get_pose().set_attachment(null)
		actor.get_skeleton().find_slot(name).get_pose().set_color(Color.TRANSPARENT)
		actor.get_skeleton().find_slot(name).get_applied_pose().set_attachment(null)
		actor.get_skeleton().find_slot(name).get_applied_pose().set_color(Color.TRANSPARENT)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var view := SubViewport.new()
	view.size = Vector2i(1536,1024)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var spec := BattleVisualRegistry.hero("diao_chan")
	var actor := BattleVisualRegistry.create_actor(spec)
	view.add_child(actor)
	actor.position = Vector2(768,780)
	actor.scale = Vector2(-1,1) * float(spec.scale) * 4
	actor.set("update_mode",2)
	actor.connect("before_world_transforms_change",hide_portrait_weapons)
	var track: Object = actor.get_animation_state().set_animation("Idle",false,0)
	track.set_mix_duration(0)
	track.set_track_time(0)
	for _frame in range(3):
		actor.update_skeleton(0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	for name in HIDDEN: assert(actor.get_skeleton().find_slot(name).get_pose().get_attachment() == null)
	assert(view.get_texture().get_image().save_png(output.path_join("diao_chan_portrait.png")) == OK)
	var metadata := {"program":"0.9.8.2","id":"diao_chan","pose":"Idle","at":0,"facing":1,"hidden_slots":HIDDEN,"origin":[768,780],"render_magnification":4,"combat_resources_modified":false}
	var file := FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"\t"))
	file.close()
	print("HERO_PORTRAIT_CAPTURE: PASS")
	get_tree().quit()
