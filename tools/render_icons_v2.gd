extends SceneTree

## SVG → PNG uses the same ThorVG decoder as the game. Never touches legacy files.
func _init() -> void:
	var base := "res://assets/ui/icons/v2/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "manifest.json"))
	var failures: Array[String] = []
	var selected: PackedStringArray = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--icons="):
			selected = argument.trim_prefix("--icons=").split(",", false)
	var rendered := 0
	for entry in manifest.icons:
		if not selected.is_empty() and not selected.has(str(entry.id)):
			continue
		rendered += 1
		var svg := FileAccess.get_file_as_string(base + str(entry.svg))
		var image := Image.new()
		var code := image.load_svg_from_string(svg, 4.0)
		if code != OK:
			failures.append("%s SVG error=%d" % [entry.id, code])
			continue
		var pixels := int(entry.pixels)
		image.resize(pixels, pixels, Image.INTERPOLATE_LANCZOS)
		code = _save_png_atomic(image, base + str(entry.png))
		if code != OK:
			failures.append("%s PNG error=%d" % [entry.id, code])
		if entry.category == "cursor":
			var large := Image.new()
			large.load_svg_from_string(svg, 4.0)
			large.resize(64, 64, Image.INTERPOLATE_LANCZOS)
			code = _save_png_atomic(large, base + str(entry.png).trim_suffix(".png") + "_2x.png")
			if code != OK: failures.append("%s cursor 2x error=%d" % [entry.id, code])
	print("Icon render: %d icons; failures=%s" % [rendered, failures])
	quit(0 if failures.is_empty() else 1)

func _save_png_atomic(image: Image, path: String) -> Error:
	var temporary := path + ".write.tmp"
	var code: Error = OK
	for attempt in range(3):
		code = image.save_png(temporary)
		if code == OK:
			code = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
		if code == OK: return OK
		if FileAccess.file_exists(temporary): DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		if attempt < 2: OS.delay_msec(200)
	return code
