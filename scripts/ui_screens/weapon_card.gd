extends Button
class_name WeaponCard

signal action_requested(weapon_id: String)

func configure(weapon: WeaponData, count: int = -1, available: int = -1, action: String = "", enabled: bool = true, selected: bool = false) -> void:
	name = "WeaponCard_" + str(weapon.weapon_id)
	tooltip_text = weapon.display_name + "\n" + WeaponRegistry.acquisition_text(weapon)
	set_meta("item_id", str(weapon.weapon_id))
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	button_pressed = selected
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 178 if not action.is_empty() else 140)
	UITheme.apply_light_selectable(self)
	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 10
	body.offset_right = -10
	body.offset_top = 8
	body.offset_bottom = -8
	body.add_theme_constant_override("separation", 5)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)
	header.add_child(ConceptIcon.new(str(weapon.weapon_id), 36, weapon.display_name))
	var title := _label(weapon.display_name)
	title.name = "ItemName"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)
	header.add_child(ConceptIcon.new("equipment_rarity_%d" % weapon.rarity, 18, "凡品；装备品质与武将品阶独立"))
	header.add_child(ConceptIcon.new("profession_" + str(weapon.profession_id), 24, "适用职业"))
	var description := _label(WeaponRegistry.brief_description(weapon))
	description.name = "ItemDescription"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	description.add_theme_font_size_override("font_size", 13)
	body.add_child(description)
	if not weapon.faction_limit.is_empty(): body.add_child(FactionUI.limit_row(weapon.faction_limit))
	if count >= 0:
		var label := _label("持有 %d · 可用 %d" % [count, maxi(available, 0)])
		label.tooltip_text = "持有%d件，未占用%d件（最多3件）" % [count, maxi(available, 0)]
		body.add_child(label)
	if not action.is_empty():
		var button := Button.new()
		button.name = "WeaponAction"
		button.text = action
		button.disabled = not enabled
		button.custom_minimum_size.y = 30
		UITheme.apply_light_selectable(button)
		button.pressed.connect(func() -> void: action_requested.emit(str(weapon.weapon_id)))
		body.add_child(button)
	body.minimum_size_changed.connect(func() -> void:
		custom_minimum_size.y = maxf(178 if not action.is_empty() else 140, body.get_combined_minimum_size().y + 16))

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	label.add_theme_font_size_override("font_size", 14)
	return label
