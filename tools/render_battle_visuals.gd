extends SceneTree

func _init() -> void:
	var base := "res://assets/battle_visuals/"
	var manifest_path := base + "render_manifest.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="): manifest_path = arg.trim_prefix("--manifest=")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var failures: Array[String] = []
	for entry in manifest.entries:
		var image := Image.new()
		var code := image.load_svg_from_string(FileAccess.get_file_as_string(base + str(entry.svg)), 4.0)
		if code == OK:
			image.resize(int(entry.get("width", entry.pixels)), int(entry.get("height", entry.pixels)), Image.INTERPOLATE_LANCZOS)
			code = image.save_png(base + str(entry.png))
		if code != OK: failures.append(str(entry.svg) + ":" + str(code))
	print("BATTLE_SVG_RENDER: %d failures=%s" % [manifest.entries.size(), failures])
	quit(0 if failures.is_empty() else 1)
