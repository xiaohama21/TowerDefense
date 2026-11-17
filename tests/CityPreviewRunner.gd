extends Node

var output := "res://build/verify_city_0.10.1.2/screenshots"
var hub: Control
var shots: Array[String] = []

func _ready() -> void:
	ProfileStore.configure_paths("user://.city_preview.json")
	call_deferred("run")

func capture(name: String, keep_mouse: bool = false) -> void:
	if not keep_mouse: Input.warp_mouse(Vector2(5,5))
	for frame in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))==OK)
	shots.append(name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for mode in ["day","dusk"]:
		var image := Image.new()
		assert(image.load_svg_from_string(FileAccess.get_file_as_string("res://docs/ui_concept/city_0.10.1.2/"+mode+".svg"))==OK)
		assert(image.save_png("res://docs/ui_concept/city_0.10.1.2/"+mode+".png")==OK)
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
	var gate: Button = hub._buttons[&"map"]
	Input.warp_mouse(hub._city.position + (gate.position+Vector2(100,105))*hub._city.scale)
	var motion := InputEventMouseMotion.new()
	motion.position = hub._city.position + (gate.position+Vector2(100,105))*hub._city.scale
	motion.global_position = motion.position
	get_viewport().push_input(motion,true)
	for frame in range(4): await get_tree().process_frame
	assert(gate.is_hovered())
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(output.path_join("gate_hover.png"))==OK)
	shots.append("gate_hover")
	Input.warp_mouse(Vector2(5,5))
	gate.grab_focus()
	await capture("gate_focus")
	gate.release_focus()
	hub._buttons[&"encyclopedia"].pressed.emit()
	await capture("first_visit")
	hub._close_intro()
	await capture("encyclopedia")
	for id in [&"map",&"command",&"develop",&"shop",&"settings",&"inventory",&"tech",&"supply"]:
		hub._show_panel(id,false)
		await capture(str(id))
	hub._show_panel(&"city")
	hub._system_menu.show()
	await capture("system_menu")
	hub._system_menu.hide()
	var menu: Button = hub.get_node("SystemMenuButton")
	motion.position = menu.get_global_rect().get_center()
	motion.global_position = motion.position
	get_viewport().push_input(motion,true)
	var held := InputEventMouseButton.new()
	held.position = motion.position
	held.global_position = motion.position
	held.button_index = MOUSE_BUTTON_LEFT
	held.pressed = true
	get_viewport().push_input(held,true)
	assert(menu.is_pressed())
	await capture("menu_pressed",true)
	held.pressed = false
	get_viewport().push_input(held,true)
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
