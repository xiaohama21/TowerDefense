extends SceneTree

func _init() -> void:
	var base := "res://assets/battle_visuals/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "render_manifest.json"))
	var failures: Array[String] = []
	for entry in manifest.entries:
		var image := Image.new()
		var code := image.load_svg_from_string(FileAccess.get_file_as_string(base + str(entry.svg)), 4.0)
		if code == OK:
			image.resize(int(entry.pixels), int(entry.pixels), Image.INTERPOLATE_LANCZOS)
			code = image.save_png(base + str(entry.png))
		if code != OK: failures.append(str(entry.svg) + ":" + str(code))
	print("BATTLE_SVG_RENDER: %d failures=%s" % [manifest.entries.size(), failures])
	quit(0 if failures.is_empty() else 1)
