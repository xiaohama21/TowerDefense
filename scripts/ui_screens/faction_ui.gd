extends RefCounted
class_name FactionUI

static func badge(faction: StringName, pixels: int = 22) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "FactionBadge"
	row.set_meta("faction_id", str(faction))
	row.tooltip_text = FactionRegistry.display_name(faction) + "阵营"
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var icon := ConceptIcon.new(FactionRegistry.icon_key(faction), pixels, FactionRegistry.display_name(faction) + "阵营")
	icon.name = "FactionFlag"
	row.add_child(icon)
	var label := Label.new()
	label.name = "FactionName"
	label.text = FactionRegistry.display_name(faction)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row

static func limit_row(limits: Array[StringName], action: String = "限用") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "FactionLimit"
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = action
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	row.add_child(label)
	for faction in limits: row.add_child(badge(faction, 20))
	return row
