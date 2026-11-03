extends SceneTree

## SVG → PNG uses the same ThorVG decoder as the game. Never touches legacy files.
func _init() -> void:
	var base := "res://assets/ui/icons/v2/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "manifest.json"))
	var failures: Array[String] = []
	for entry in manifest.icons:
		var svg := FileAccess.get_file_as_string(base + str(entry.svg))
		var image := Image.new()
		var code := image.load_svg_from_string(svg, 4.0)
		if code != OK:
			failures.append("%s SVG error=%d" % [entry.id, code])
			continue
		var pixels := int(entry.pixels)
		image.resize(pixels, pixels, Image.INTERPOLATE_LANCZOS)
		code = image.save_png(base + str(entry.png))
		if code != OK:
			failures.append("%s PNG error=%d" % [entry.id, code])
		if entry.category == "cursor":
			var large := Image.new()
			large.load_svg_from_string(svg, 4.0)
			large.resize(64, 64, Image.INTERPOLATE_LANCZOS)
			large.save_png(base + str(entry.png).trim_suffix(".png") + "_2x.png")
	print("Icon render: %d icons; failures=%s" % [manifest.icons.size(), failures])
	quit(0 if failures.is_empty() else 1)
