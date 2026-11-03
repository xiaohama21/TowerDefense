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
	var caption := Label.new()
	caption.text = "%s   %d/10" % [("Ⅰ" if slot == 0 else "Ⅱ") if slot >= 0 else "R", level]
	caption.tooltip_text = title
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	header.add_child(caption)
	if not unlocked:
		var required := ConceptIcon.new()
		required.set_rank(slot + 1)
		header.add_child(required)
		header.add_child(ConceptIcon.new("lock", 22, "达到对应品阶后解锁"))
	else:
		header.add_child(ConceptIcon.new("rage" if slot < 0 else "ui_check", 22, "满100释放，设置可切手动" if slot < 0 else "自动生效"))
	var effects := SkillRegistry.effect_rows(character, skill_id, level, amp)
	for entries in effects:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		body.add_child(row)
		for entry in entries:
			row.add_child(ConceptIcon.new(str(entry[0]), 20, str(entry[2])))
			var value := Label.new()
			value.text = str(entry[1])
			value.tooltip_text = str(entry[2])
			value.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
			row.add_child(value)
	var rule := Label.new()
	rule.text = SkillRegistry.rule_text(skill_id)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	rule.add_theme_font_size_override("font_size", 12)
	body.add_child(rule)
	tooltip_text = title + "\n" + rule.text
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
