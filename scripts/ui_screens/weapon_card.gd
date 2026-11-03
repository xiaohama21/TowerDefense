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
	custom_minimum_size = Vector2(0, 144 if not action.is_empty() else 124)
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
	header.add_child(ConceptIcon.new("equipment_rarity_%d" % weapon.rarity, 18, "凡品；装备品质与武将品阶独立"))
	header.add_child(ConceptIcon.new("profession_" + str(weapon.profession_id), 24, "适用职业"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	if count >= 0:
		var label := _label("×%d" % count)
		label.tooltip_text = "持有%d件，未占用%d件（最多3件）" % [count, maxi(available, 0)]
		header.add_child(label)
		if available >= 0:
			header.add_child(ConceptIcon.new("ui_equip", 18, "已装配件数"))
			header.add_child(_label("×%d" % maxi(count - available, 0)))
	for effect in WeaponRegistry.effect_rows(weapon):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		body.add_child(row)
		row.add_child(ConceptIcon.new(str(effect[0]), 20, str(effect[2])))
		var value := _label(str(effect[1]))
		value.tooltip_text = str(effect[2])
		row.add_child(value)
	if not action.is_empty():
		var button := Button.new()
		button.name = "WeaponAction"
		button.text = action
		button.disabled = not enabled
		button.custom_minimum_size.y = 30
		UITheme.apply_light_selectable(button)
		button.pressed.connect(func() -> void: action_requested.emit(str(weapon.weapon_id)))
		body.add_child(button)

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	label.add_theme_font_size_override("font_size", 14)
	return label
