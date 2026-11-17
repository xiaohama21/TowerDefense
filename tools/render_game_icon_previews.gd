extends SceneTree

func _init() -> void:
	var failed := false
	for source in OS.get_cmdline_user_args():
		var image := Image.new()
		var error := image.load_svg_from_string(FileAccess.get_file_as_string(source), 4.0)
		if error == OK:
			error = image.save_png(source.trim_suffix(".svg") + "_1024.png")
		if error == OK:
			image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
			error = image.save_png(source.trim_suffix(".svg") + ".png")
		if error != OK:
			push_error("Icon preview failed: %s (%d)" % [source, error])
			failed = true
	print("GAME_ICON_NATIVE_PREVIEWS_%s" % ("FAIL" if failed else "OK"))
	quit(1 if failed else 0)
