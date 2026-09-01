extends VBoxContainer

## 科技树面板（阶段 8 提交 3）：四类分页（军略/后勤/工事/将略）+ 成语命名 + 摘要列表 +
## 点击条目显示详细描述与数值；科技重置（v0.23.0 拍板）无条件——免费/不限次数/全额返还。

const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const TEXT_COLOR := Color(0.88, 0.9, 0.84)
const OK_COLOR := Color(0.55, 0.9, 0.6)
const LOCKED_COLOR := Color(0.55, 0.55, 0.55)
const DETAIL_COLOR := Color(0.72, 0.84, 0.95)

var _points_label: Label
var _detail_label: Label
var _tab_container: TabContainer


func _ready() -> void:
	add_theme_constant_override("separation", 8)
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

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	add_child(top_row)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 18)
	_points_label.add_theme_color_override("font_color", Color(0.65, 0.84, 1.0))
	top_row.add_child(_points_label)
	var reset_button := Button.new()
	reset_button.text = "重置科技（全额返还）"
	reset_button.custom_minimum_size = Vector2(200, 36)
	reset_button.add_theme_font_size_override("font_size", 15)
	reset_button.pressed.connect(_on_reset_pressed)
	top_row.add_child(reset_button)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tab_container)
	for category in TechTree.get_categories():
		var scroll := ScrollContainer.new()
		scroll.name = category
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var list := VBoxContainer.new()
		list.name = "List"
		list.add_theme_constant_override("separation", 6)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		_tab_container.add_child(scroll)
		for item in TechTree.get_items_by_category(category):
			_add_tech_row(list, item)

	_detail_label = Label.new()
	_detail_label.text = "点击科技条目查看详细说明"
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.add_theme_font_size_override("font_size", 15)
	_detail_label.add_theme_color_override("font_color", DETAIL_COLOR)
	_detail_label.custom_minimum_size = Vector2(0, 84)
	_detail_label.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(_detail_label)


func _add_tech_row(list: VBoxContainer, item: TechItemData) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_button := Button.new()
	name_button.text = "%s —— %s" % [item.name, item.summary]
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.add_theme_font_size_override("font_size", 16)
	name_button.pressed.connect(_on_item_selected.bind(item))
	row.add_child(name_button)
	var unlock_button := Button.new()
	unlock_button.text = "解锁（%d 点）" % item.cost
	unlock_button.custom_minimum_size = Vector2(150, 36)
	unlock_button.add_theme_font_size_override("font_size", 15)
	unlock_button.pressed.connect(_on_tech_unlock.bind(item.id, item.cost))
	row.add_child(unlock_button)
	row.set_meta("unlock_button", unlock_button)
	row.set_meta("tech_id", item.id)
	list.add_child(row)


func _refresh() -> void:
	var profile := ProfileStore.get_profile()
	_points_label.text = "科技点：%d" % profile.tech_points
	for category in TechTree.get_categories():
		var scroll := _tab_container.get_node(category)
		var list := scroll.get_node("List")
		for child in list.get_children():
			var row := child as HBoxContainer
			if row == null:
				continue
			var button: Button = row.get_meta("unlock_button")
			var item := TechTree.get_item(str(row.get_meta("tech_id")))
			if item == null:
				continue
			var unlocked := TechTree.is_unlocked(profile, item.id)
			var prereq_ok := TechTree.prerequisites_met(profile, item)
			var name_button := row.get_child(0) as Button
			if unlocked:
				button.text = "已解锁 ✓"
				button.disabled = true
				name_button.add_theme_color_override("font_color", OK_COLOR)
			elif not prereq_ok:
				button.text = "需前置科技"
				button.disabled = true
				name_button.add_theme_color_override("font_color", LOCKED_COLOR)
			else:
				button.text = "解锁（%d 点）" % item.cost
				button.disabled = profile.tech_points < item.cost
				name_button.add_theme_color_override("font_color", TEXT_COLOR)


func _on_item_selected(item: TechItemData) -> void:
	var unlocked := TechTree.is_unlocked(ProfileStore.get_profile(), item.id)
	_detail_label.text = "%s（%s）\n%s\n%s" % [
		item.name, "已解锁" if unlocked else "未解锁",
		item.description,
		_effect_text(item),
	]


func _effect_text(item: TechItemData) -> String:
	var parts: Array[String] = []
	for key in item.effect:
		parts.append("%s：%s" % [key, item.effect[key]])
	return "数值：%s" % "；".join(parts)


func _on_tech_unlock(tech_id: String, cost: int) -> void:
	if ProfileStore.get_profile().unlock_tech(tech_id, cost):
		ProfileStore.save_profile(ProfileStore.get_profile())
		_refresh()


func _on_reset_pressed() -> void:
	var profile := ProfileStore.get_profile()
	var refund := TechTree.reset_tech(profile)
	ProfileStore.save_profile(profile)
	_refresh()
	_detail_label.text = "科技已重置，返还 %d 科技点" % refund
