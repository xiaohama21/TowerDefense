extends PanelContainer
class_name SkillCard

signal upgrade_requested(character_id: String, skill_id: StringName, expected_level: int)

func configure(character: CharacterData, skill_id: StringName, rank: int, level: int = 1, amp: float = 0.0, status: String = "", can_upgrade: bool = false) -> void:
	name = "SkillCard_" + str(skill_id)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := UITheme.light_card_style()
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	body.add_child(header)
	var icon_id := "char_death_fight" if skill_id == &"ultimate_death_fight" else str(skill_id)
	var title := SkillRegistry.get_skill_name(skill_id)
	var slot := character.passive_ids.find(skill_id)
	var unlocked := character.is_skill_unlocked(skill_id, rank)
	var icon := ConceptIcon.new(icon_id, 38, title)
	icon.modulate.a = 1.0 if unlocked else 0.4
	header.add_child(icon)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 2)
	header.add_child(heading)
	var caption := _text_label(title, 17, UITheme.LIGHT_INK)
	caption.name = "SkillName"
	heading.add_child(caption)
	var kind := ("被动Ⅰ" if slot == 0 else "被动Ⅱ") if slot >= 0 else "大招"
	heading.add_child(_text_label("%s · Lv.%d/%d" % [kind, level, SkillRegistry.MAX_LEVEL], 12, UITheme.LIGHT_MUTED))
	var state := HBoxContainer.new()
	state.add_theme_constant_override("separation", 4)
	header.add_child(state)
	if not unlocked:
		var required := ConceptIcon.new()
		required.set_rank(slot + 1)
		state.add_child(required)
		state.add_child(_text_label("%s品阶解锁" % CharacterRank.NAMES[slot + 1], 12, UITheme.LIGHT_LOCK, false))
	else:
		state.add_child(ConceptIcon.new("rage" if slot < 0 else "ui_check", 22, "满100释放，设置可切手动" if slot < 0 else "自动生效"))
		state.add_child(_text_label("怒气满100释放" if slot < 0 else "已解锁", 12, UITheme.LIGHT_MUTED, false))
	var description := _text_label(SkillRegistry.description_text(skill_id), 14, UITheme.LIGHT_BODY)
	description.name = "SkillDescription"
	body.add_child(description)
	var effects := SkillRegistry.effect_rows(character, skill_id, level, amp)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)
	for entries in effects:
		for entry in entries:
			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 5)
			grid.add_child(row)
			row.add_child(ConceptIcon.new(str(entry[0]), 20, str(entry[2])))
			var label := _text_label(str(entry[3]), 13, UITheme.LIGHT_MUTED)
			label.tooltip_text = str(entry[2])
			row.add_child(label)
			var value := Label.new()
			value.text = str(entry[1])
			value.tooltip_text = str(entry[2])
			value.add_theme_font_size_override("font_size", 14)
			value.add_theme_color_override("font_color", UITheme.LIGHT_INK)
			row.add_child(value)
	var rule := _text_label("规则：" + SkillRegistry.rule_text(skill_id), 12, UITheme.LIGHT_MUTED)
	body.add_child(rule)
	tooltip_text = title + "\n" + description.text + "\n" + rule.text
	if can_upgrade:
		var row := HBoxContainer.new()
		body.add_child(row)
		var button := Button.new()
		button.name = "UpgradeSkill"
		button.text = "升级" if status == "升级" else status
		button.disabled = status != "升级"
		UITheme.apply_light_selectable(button)
		button.pressed.connect(func() -> void: upgrade_requested.emit(str(character.character_id), skill_id, level))
		row.add_child(button)
		if level < SkillRegistry.MAX_LEVEL:
			row.add_child(ConceptIcon.new("skill_book", 24, "升级消耗"))
			var cost := Label.new()
			cost.text = "×%d" % SkillRegistry.upgrade_cost(level)
			cost.add_theme_color_override("font_color", UITheme.LIGHT_INK)
			row.add_child(cost)

func _text_label(text: String, font_size: int, color: Color, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label
