extends VBoxContainer

## 科技树面板（GDD v0.14）：三分支科技列表，科技点解锁。

const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const TEXT_COLOR := Color(0.88, 0.9, 0.84)
const OK_COLOR := Color(0.55, 0.9, 0.6)
const LOCKED_COLOR := Color(0.55, 0.55, 0.55)

var _points_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_build_ui()
	_refresh()


func _on_shown() -> void:
	_refresh()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "科技树"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	add_child(title)

	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 18)
	_points_label.add_theme_color_override("font_color", ACCENT)
	add_child(_points_label)

	for branch in [["经济", "eco"], ["军事", "mil"], ["基建", "inf"]]:
		var branch_label := Label.new()
		branch_label.text = "—— %s ——" % branch[0]
		branch_label.add_theme_font_size_override("font_size", 16)
		branch_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.58))
		add_child(branch_label)
		for item in TechTree.ITEMS:
			if item.branch != branch[0]:
				continue
			add_child(_make_tech_row(item))


func _make_tech_row(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.text = "%s（%s）" % [item.name, item.desc]
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var unlock_button := Button.new()
	unlock_button.text = "解锁（%d 点）" % item.cost
	unlock_button.custom_minimum_size = Vector2(140, 36)
	unlock_button.add_theme_font_size_override("font_size", 15)
	unlock_button.pressed.connect(_on_tech_unlock.bind(item.id, item.cost))
	row.add_child(unlock_button)
	# 标记以便刷新
	row.set_meta("tech_id", item.id)
	row.set_meta("unlock_button", unlock_button)
	set_meta("tech_row_" + item.id, row)
	return row


func _refresh() -> void:
	var profile := ProfileStore.get_profile()
	_points_label.text = "科技点：%d" % profile.tech_points
	for item in TechTree.ITEMS:
		var row: HBoxContainer = get_meta("tech_row_" + item.id, null)
		if row == null:
			continue
		var button: Button = row.get_meta("unlock_button")
		var unlocked := TechTree.is_unlocked(profile, item.id)
		var prereq_ok := TechTree.prerequisites_met(profile, item)
		if unlocked:
			button.text = "已解锁 ✓"
			button.disabled = true
			name_label_color(row, OK_COLOR)
		elif not prereq_ok:
			button.text = "需前置科技"
			button.disabled = true
			name_label_color(row, LOCKED_COLOR)
		else:
			button.text = "解锁（%d 点）" % item.cost
			button.disabled = profile.tech_points < item.cost
			name_label_color(row, TEXT_COLOR)


func name_label_color(row: HBoxContainer, color: Color) -> void:
	row.get_child(0).add_theme_color_override("font_color", color)


func _on_tech_unlock(tech_id: String, cost: int) -> void:
	if ProfileStore.get_profile().unlock_tech(tech_id, cost):
		ProfileStore.save_profile(ProfileStore.get_profile())
		_refresh()


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


const ACCENT := Color(0.65, 0.84, 1.0)
