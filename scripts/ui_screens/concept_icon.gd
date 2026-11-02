extends TextureRect
class_name ConceptIcon

var placeholder_color := Color("#7d9cb4")

func _init(icon_name: String = "", pixels: int = 24, hint: String = "", tint: Color = Color("#7d9cb4")) -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2(pixels, pixels)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tooltip_text = hint
	placeholder_color = tint
	UITheme.apply_hud_icon(self, icon_name, pixels)

func set_rank(rank: int) -> void:
	var r := clampi(rank, 0, 5)
	placeholder_color = CharacterRank.COLORS[r]
	tooltip_text = CharacterRank.NAMES[r]
	UITheme.apply_hud_icon(self, "rank_" + CharacterRank.KEYS[r], int(custom_minimum_size.x))
	queue_redraw()

static func rank_texture(rank: int, pixels: int = 24) -> Texture2D:
	var r := clampi(rank, 0, 5)
	var available := UITheme.hud_icon("rank_" + CharacterRank.KEYS[r])
	if available != null:
		return available
	var bitmap := Image.create(pixels, pixels, false, Image.FORMAT_RGBA8)
	var center := Vector2(pixels, pixels) * 0.5
	for y in range(pixels):
		for x in range(pixels):
			var delta := Vector2(x + 0.5, y + 0.5) - center
			if absf(delta.length() - pixels * 0.38) <= 0.8 and fposmod(delta.angle(), TAU / 12.0) < TAU / 20.0:
				bitmap.set_pixel(x, y, CharacterRank.COLORS[r])
	return ImageTexture.create_from_image(bitmap)

func _draw() -> void:
	if texture != null:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	for i in range(12):
		var start := float(i) * TAU / 12.0
		draw_arc(center, radius, start, start + TAU / 20.0, 4, placeholder_color, 1.5, true)
