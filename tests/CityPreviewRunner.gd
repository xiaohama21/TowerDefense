extends Node

var output := "res://build/verify_city_0.10.1/screenshots"
var hub: Control
var shots: Array[String] = []

func _ready() -> void:
	ProfileStore.configure_paths("user://.city_preview.json")
	call_deferred("run")

func capture(name: String) -> void:
	Input.warp_mouse(Vector2(5,5))
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))==OK)
	shots.append(name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for mode in ["day","dusk"]:
		var image := Image.new()
		assert(image.load_svg_from_string(FileAccess.get_file_as_string("res://docs/ui_concept/city_0.10.1/"+mode+".svg"))==OK)
		assert(image.save_png("res://docs/ui_concept/city_0.10.1/"+mode+".png")==OK)
		GameFlow.start_new_game()
		GameFlow.hub_active_panel = &"city"
		hub = load("res://scenes/GameHub.tscn").instantiate()
		hub.city_palette = mode
		add_child(hub)
		await capture(mode+"_new")
		hub.queue_free()
		await get_tree().process_frame
	GameFlow.start_new_game()
	var profile := ProfileStore.get_profile()
	for i in range(1,9): profile.mark_stage_completed("ch01_s%02d" % i,{"difficulty":"normal"})
	profile.city_state.legacy_access = true
	profile.ingots = 240; profile.military_merit = 1242
	profile.lord_exp = 140
	ProfileStore.save_profile(profile)
	hub = load("res://scenes/GameHub.tscn").instantiate()
	add_child(hub)
	await capture("city_unlocked")
	hub._buttons[&"encyclopedia"].pressed.emit()
	await capture("first_visit")
	hub._close_intro()
	await capture("encyclopedia")
	for id in [&"map",&"command",&"develop",&"shop",&"settings"]:
		hub._show_panel(id,false)
		await capture(str(id))
	hub._show_panel(&"city")
	hub._system_menu.show()
	await capture("system_menu")
	hub._system_menu.hide()
	hub._describe(&"stable")
	await capture("construction")
	get_window().size = Vector2i(1600,900)
	await capture("wide_city")
	hub.queue_free()
	await get_tree().process_frame
	var file := FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"program":ProjectSettings.get_setting("application/config/version"),"screenshots":shots},"\t"))
	file.close()
	print("CITY_PREVIEW_RESULT: PASS screenshots=%d" % shots.size())
	get_tree().quit()
