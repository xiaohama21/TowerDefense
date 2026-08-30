extends VBoxContainer

## 背包面板（GDD v0.15.1）：查看玩家全部道具（名称/数量/类型/描述）；
## 附测试发放"练兵令 ×10"（仅测试辅助，不影响正式数值与结算）。

signal back_requested

const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const TEXT_COLOR := Color(0.88, 0.9, 0.84)
const DIM_COLOR := Color(0.6, 0.62, 0.58)
const ACCENT_COLOR := Color(0.65, 0.84, 1.0)
const EXP_SCROLL_ID := "exp_scroll"
## 测试发放的局内遗物（v0.19.0，CHARACTERS.md 4.8）：全部 5 件各 1。
const TEST_RELIC_IDS: Array[String] = ["wolf_tooth", "iron_shield", "war_drums", "scout_eye", "provision_bag"]

const ITEM_TYPE_NAMES := ["货币", "抽奖券", "材料", "碎片", "消耗品"]

var _item_box: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_build_ui()
	_refresh()


func _on_shown() -> void:
	# 每次切回面板时刷新（战斗结算/发放后数量可能已变化）。
	_refresh()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "背包"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	add_child(title)

	# 测试发放行（v0.15.1）：提供测试道具获取途径，仅测试使用。
	var grant_row := HBoxContainer.new()
	grant_row.add_theme_constant_override("separation", 16)
	add_child(grant_row)
	var grant_hint := Label.new()
	grant_hint.text = "测试工具："
	grant_hint.add_theme_font_size_override("font_size", 17)
	grant_hint.add_theme_color_override("font_color", DIM_COLOR)
	grant_row.add_child(grant_hint)
	var grant_button := Button.new()
	grant_button.text = "获得练兵令 ×10"
	grant_button.custom_minimum_size = Vector2(200, 40)
	grant_button.add_theme_font_size_override("font_size", 16)
	grant_button.pressed.connect(_on_grant_exp_scroll)
	grant_row.add_child(grant_button)
	var relic_grant_button := Button.new()
	relic_grant_button.text = "获得测试遗物 ×1（各）"
	relic_grant_button.custom_minimum_size = Vector2(220, 40)
	relic_grant_button.add_theme_font_size_override("font_size", 16)
	relic_grant_button.pressed.connect(_on_grant_test_relics)
	grant_row.add_child(relic_grant_button)
	var grant_note := Label.new()
	grant_note.text = "（仅测试发放，不进掉落表）"
	grant_note.add_theme_font_size_override("font_size", 15)
	grant_note.add_theme_color_override("font_color", DIM_COLOR)
	grant_row.add_child(grant_note)

	var hint := Label.new()
	hint.text = "道具清单"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", DIM_COLOR)
	add_child(hint)

	# 背包列表滚动（v0.19.3）：道具多时纵向滚动，避免溢出。
	var item_scroll := ScrollContainer.new()
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(item_scroll)
	_item_box = VBoxContainer.new()
	_item_box.add_theme_constant_override("separation", 6)
	_item_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_scroll.add_child(_item_box)


func _on_grant_exp_scroll() -> void:
	var profile := ProfileStore.get_profile()
	profile.add_item(EXP_SCROLL_ID, 10)
	ProfileStore.save_profile()
	_refresh()


func _on_grant_test_relics() -> void:
	var profile := ProfileStore.get_profile()
	for relic_id in TEST_RELIC_IDS:
		profile.add_item(relic_id, 1)
	ProfileStore.save_profile()
	_refresh()


func _refresh() -> void:
	for child in _item_box.get_children():
		child.queue_free()
	var profile := ProfileStore.get_profile()
	var entries: Array = []
	for key in profile.items.keys():
		var item_id := str(key)
		var amount := int(profile.items.get(key, 0))
		if amount > 0:
			entries.append([item_id, amount])
	entries.sort()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "背包空空如也——通关掉落、一键通关或测试发放会获得道具。"
		empty.add_theme_font_size_override("font_size", 17)
		empty.add_theme_color_override("font_color", DIM_COLOR)
		_item_box.add_child(empty)
		return
	for entry in entries:
		_item_box.add_child(_make_item_row(str(entry[0]), int(entry[1])))


func _make_item_row(item_id: String, amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var item := GameFlow.load_item_data(item_id)
	var display_name := item.display_name if item != null else item_id
	var type_name: String = ITEM_TYPE_NAMES[item.item_type] if item != null and item.item_type >= 0 and item.item_type < ITEM_TYPE_NAMES.size() else "未知"
	var name_label := Label.new()
	name_label.text = "%s ×%d　[%s]" % [display_name, amount, type_name]
	name_label.custom_minimum_size = Vector2(300, 0)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(name_label)
	var desc_label := Label.new()
	desc_label.text = item.description if item != null and not item.description.is_empty() else "（无描述）"
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", DIM_COLOR)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc_label)
	row.set_meta("item_id", item_id)
	return row
