extends PanelContainer
class_name SkillCard

signal upgrade_requested(character_id: String, skill_id: StringName, expected_level: int)

func configure(character: CharacterData, skill_id: StringName, rank: int, level: int = 1, amp: float = 0.0, status: String = "", can_upgrade: bool = false, context: Dictionary = {}) -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	name = "SkillCard_" + str(skill_id)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := UITheme.light_card_style()
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	body.add_child(header)
	var title := SkillRegistry.get_skill_name(skill_id)
	var slot := character.passive_ids.find(skill_id)
	var unlocked := character.is_skill_unlocked(skill_id, rank)
	var icon := ConceptIcon.new(str(skill_id), 38, title)
	icon.modulate.a = 1.0 if unlocked else 0.4
	header.add_child(icon)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var caption := _label(title, 17, UITheme.LIGHT_INK)
	caption.name = "SkillName"
	heading.add_child(caption)
	var kind := ("被动Ⅰ" if slot == 0 else "被动Ⅱ") if slot >= 0 else "大招"
	heading.add_child(_label("%s · Lv.%d/%d" % [kind, level, SkillRegistry.MAX_LEVEL], 12, UITheme.LIGHT_MUTED))
	var state := _label("已解锁" if unlocked else "%s品阶解锁" % CharacterRank.NAMES[slot + 1], 12, UITheme.LIGHT_MUTED if unlocked else UITheme.LIGHT_LOCK, false)
	state.name = "SkillUnlockState"
	header.add_child(state)
	var trigger := _label("触发条件：" + SkillRegistry.trigger_text(skill_id), 13, UITheme.LIGHT_INK)
	trigger.name = "SkillTrigger"
	body.add_child(trigger)
	var description := _label(SkillRegistry.description_text(skill_id), 13, UITheme.LIGHT_BODY)
	description.name = "SkillDescription"
	body.add_child(description)
	body.add_child(_label("效果数值", 13, UITheme.LIGHT_ACCENT))
	var grid := GridContainer.new()
	grid.name = "EffectBreakdown"
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 5)
	body.add_child(grid)
	for text in ["效果项", "基础\nLv.1", "等级\n加成", "养成\n加成", "当前值"]:
		var label := _label(text, 11, UITheme.LIGHT_MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(label)
	for item in SkillRegistry.effect_breakdown(character, skill_id, level, amp, context):
		var row := HBoxContainer.new()
		row.custom_minimum_size.x = 76
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 4)
		grid.add_child(row)
		row.add_child(ConceptIcon.new(item.icon, 16, item.hint))
		var label := _label(item.label, 12, UITheme.LIGHT_BODY)
		label.tooltip_text = item.hint
		row.add_child(label)
		for key in ["base", "level_bonus", "amp_bonus", "current"]:
			var value := _label(SkillRegistry.format_effect_value(item.key, item[key], key in ["level_bonus", "amp_bonus"]), 12, UITheme.LIGHT_ACCENT if key == "current" else UITheme.LIGHT_INK, false)
			value.name = str(item.key) + "_" + key
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(value)
	var source := _label("等级只提升可成长项；固定数值和时长不随等级增长。养成加成含品阶、装备、天赋与当前模拟阶数。", 11, UITheme.LIGHT_MUTED)
	source.name = "SkillGrowthSources"
	body.add_child(source)
	var damage_text := SkillRegistry.damage_preview(character, skill_id, level, amp, context)
	if not damage_text.is_empty():
		body.add_child(_label("伤害预览", 13, UITheme.LIGHT_ACCENT))
		var damage := _label(damage_text, 12, UITheme.LIGHT_BODY)
		damage.name = "SkillDamagePreview"
		body.add_child(damage)
	var rule := _label("规则：" + SkillRegistry.rule_text(skill_id), 12, UITheme.LIGHT_MUTED)
	rule.name = "SkillRules"
	body.add_child(rule)
	tooltip_text = title + "\n" + trigger.text + "\n" + description.text + "\n" + rule.text
	if can_upgrade:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		body.add_child(row)
		var button := Button.new()
		button.name = "UpgradeSkill"
		button.text = "升级" if status == "升级" else status
		button.disabled = status != "升级"
		UITheme.apply_kenney_rect_button(button, "yellow", UITheme.INK, 5)
		button.custom_minimum_size.y = 30
		button.pressed.connect(func() -> void: upgrade_requested.emit(str(character.character_id), skill_id, level))
		row.add_child(button)
		if level < SkillRegistry.MAX_LEVEL:
			row.add_child(ConceptIcon.new("skill_book", 24, "升级消耗"))
			row.add_child(_label("×%d" % SkillRegistry.upgrade_cost(level), 13, UITheme.LIGHT_INK, false))

func _label(text: String, font_size: int, color: Color, wrap: bool = true) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label
