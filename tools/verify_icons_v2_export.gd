extends SceneTree

## Godot --main-pack <exported exe> --script <absolute path to this file>.
## Release templates ignore --script; the engine mounts only the embedded PCK.
## Also load the default startup scene and optionally capture its viewport.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	var base := "res://assets/ui/icons/v2/"
	var manifest_path := base + "manifest.json"
	if not FileAccess.file_exists(manifest_path):
		push_error("Export has no icon manifest")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var count := 0
	var legacy_excluded := true
	for entry in manifest.get("icons", []):
		var texture := load(base + str(entry.png)) as Texture2D
		if texture == null or texture.get_width() != int(entry.pixels):
			errors.append("Unavailable icon: " + str(entry.id))
		else:
			count += 1
	for path in ["res://assets/ui/icons/icons_hud/coin.png", "res://assets/ui/icons/star.png", "res://assets/ui/cursors/pointer_toon_a.png", "res://icon.svg"]:
		if ResourceLoader.exists(path):
			legacy_excluded = false
			errors.append("Legacy export: " + path)
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	if version != "0.9.1.1" or count != 273:
		errors.append("Version/count mismatch")
	var profile_store := root.get_node("ProfileStore")
	var isolated_path := "user://.icons_export_%d.json" % Time.get_ticks_usec()
	profile_store.call("configure_paths", isolated_path)
	var menu := (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	await create_timer(0.5).timeout
	var report_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var capture_path := arg.trim_prefix("--capture=")
			var result := root.get_texture().get_image().save_png(capture_path)
			if result != OK:
				errors.append("Capture failed")
		if arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
	var report := {"version": version, "icons_loaded_from_pack": count, "legacy_icons_excluded": legacy_excluded, "default_scene_loaded": menu.name, "errors": errors}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  ") + "\n")
	print("ICONS_EXPORT_%s %s" % ["OK" if errors.is_empty() else "FAIL", JSON.stringify(report)])
	menu.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
