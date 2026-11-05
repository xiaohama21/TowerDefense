extends PanelContainer
class_name LockedRelicCard

func _init(relic: RelicData) -> void:
	name = "LockedExclusiveRelic"
	set_meta("relic_id", str(relic.relic_id))
	add_theme_stylebox_override("panel", UITheme.light_card_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	row.add_child(ConceptIcon.new(str(relic.relic_id), 34, relic.display_name))
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	row.add_child(content)
	var title := Label.new()
	title.name = "ExclusiveRelicName"
	title.text = relic.display_name + " · 未开放"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	content.add_child(title)
	var description := Label.new()
	description.name = "ExclusiveRelicDescription"
	description.text = relic.description + " 专属槽暂未开放，不参与战斗。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 13)
	description.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	content.add_child(description)
