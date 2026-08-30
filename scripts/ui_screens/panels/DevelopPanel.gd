extends VBoxContainer

## 武将养成面板（GDD 阶段 2，v0.10.1 移入游戏大厅）：等级/经验、属性
## （等级+转职实时计算）、一转流程（等级+材料校验、不可逆确认、扣料写档）。

signal back_requested

const TITLE_COLOR := Color(0.92, 0.78, 0.42)
const TEXT_COLOR := Color(0.88, 0.9, 0.84)
const OK_COLOR := Color(0.55, 0.9, 0.6)
const BAD_COLOR := Color(0.9, 0.45, 0.4)
const ACCENT_COLOR := Color(0.65, 0.84, 1.0)
const EXP_SCROLL_ID := "exp_scroll"

var _profile: PlayerProfile
var _owned: Array[CharacterData] = []
var _locked_ids: Array[String] = []
var _selected_id: String = ""

var _character_buttons: Dictionary = {}
var _detail_name_label: Label
var _exp_bar: ProgressBar
var _exp_label: Label
var _stats_label: Label
var _promotion_label: Label
var _promotion_buttons: Array[Button] = []
var _promotion_buttons_box: VBoxContainer
var _stars_label: Label
var _promote_star_button: Button
var _relic_label: Label
var _relic_button: Button
var _gacha_label: Label
var _gacha_button: Button
var _exp_scroll_label: Label
var _exp_scroll_button: Button
var _exp_scroll_hint: Label


func _ready() -> void:
	_profile = ProfileStore.get_profile()
	_load_owned_characters()
	add_theme_constant_override("separation", 12)
	_build_ui()
	if not _owned.is_empty() and _selected_id.is_empty():
		_select_character(str(_owned[0].character_id))
	_refresh()


func _on_shown() -> void:
	# 每次切回面板时刷新（战斗结算后等级/材料可能已变化）。
	_refresh()


func _load_owned_characters() -> void:
	for character_id in _profile.get_owned_character_ids():
		var character_data := GameFlow.load_character_data(character_id)
		if character_data != null:
			_owned.append(character_data)
	# 武将图鉴（v0.11.3）：全角色目录 - 已拥有 = 未解锁
	var owned_set := {}
	for character_data in _owned:
		owned_set[str(character_data.character_id)] = true
	for character_id in GameFlow.get_all_character_ids():
		if not owned_set.has(character_id):
			_locked_ids.append(character_id)


func _build_ui() -> void:
	var title := Label.new()
	title.text = "武将养成"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	add_child(title)

	var gacha_row := HBoxContainer.new()
	gacha_row.add_theme_constant_override("separation", 16)
	add_child(gacha_row)

	_gacha_label = Label.new()
	_gacha_label.add_theme_font_size_override("font_size", 17)
	_gacha_label.add_theme_color_override("font_color", ACCENT_COLOR)
	gacha_row.add_child(_gacha_label)

	_gacha_button = Button.new()
	_gacha_button.custom_minimum_size = Vector2(180, 40)
	_gacha_button.add_theme_font_size_override("font_size", 16)
	_gacha_button.pressed.connect(_on_gacha_pressed)
	gacha_row.add_child(_gacha_button)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	add_child(columns)

	var list_box := VBoxContainer.new()
	list_box.custom_minimum_size = Vector2(220, 0)
	list_box.add_theme_constant_override("separation", 8)
	columns.add_child(list_box)

	if _owned.is_empty():
		var empty := Label.new()
		empty.text = "暂无武将，请先开始游戏"
		empty.add_theme_font_size_override("font_size", 17)
		list_box.add_child(empty)

	for character_data in _owned:
		var character_id := str(character_data.character_id)
		var level := GameFlow.get_character_level(_profile, character_id)
		var button := Button.new()
		button.text = "%s · Lv.%d" % [character_data.display_name, level]
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 17)
		button.toggle_mode = true
		button.pressed.connect(_on_character_pressed.bind(character_id))
		list_box.add_child(button)
		_character_buttons[character_id] = button

	if not _locked_ids.is_empty():
		var hint := Label.new()
		hint.text = "未解锁武将"
		hint.add_theme_font_size_override("font_size", 15)
		hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.58))
		list_box.add_child(hint)
	for character_id in _locked_ids:
		var character_data := GameFlow.load_character_data(character_id)
		if character_data == null:
			continue
		var locked_button := Button.new()
		locked_button.text = "%s · %s" % [character_data.display_name, GameFlow.get_acquisition_text(character_id)]
		locked_button.custom_minimum_size = Vector2(0, 40)
		locked_button.add_theme_font_size_override("font_size", 13)
		locked_button.add_theme_color_override("font_color", Color(0.55, 0.57, 0.53))
		locked_button.disabled = true
		list_box.add_child(locked_button)

	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 10)
	columns.add_child(detail_box)

	_detail_name_label = Label.new()
	_detail_name_label.add_theme_font_size_override("font_size", 24)
	_detail_name_label.add_theme_color_override("font_color", TEXT_COLOR)
	detail_box.add_child(_detail_name_label)

	_exp_bar = ProgressBar.new()
	_exp_bar.custom_minimum_size = Vector2(0, 22)
	_exp_bar.show_percentage = false
	detail_box.add_child(_exp_bar)

	_exp_label = Label.new()
	_exp_label.add_theme_font_size_override("font_size", 16)
	_exp_label.add_theme_color_override("font_color", ACCENT_COLOR)
	detail_box.add_child(_exp_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 18)
	_stats_label.add_theme_color_override("font_color", TEXT_COLOR)
	detail_box.add_child(_stats_label)

	_promotion_label = Label.new()
	_promotion_label.add_theme_font_size_override("font_size", 17)
	_promotion_label.add_theme_color_override("font_color", TEXT_COLOR)
	_promotion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_promotion_label)

	_promotion_buttons_box = VBoxContainer.new()
	_promotion_buttons_box.add_theme_constant_override("separation", 8)
	detail_box.add_child(_promotion_buttons_box)

	_stars_label = Label.new()
	_stars_label.add_theme_font_size_override("font_size", 17)
	_stars_label.add_theme_color_override("font_color", ACCENT_COLOR)
	detail_box.add_child(_stars_label)

	_promote_star_button = Button.new()
	_promote_star_button.text = "升 星"
	_promote_star_button.custom_minimum_size = Vector2(220, 44)
	_promote_star_button.add_theme_font_size_override("font_size", 17)
	_promote_star_button.pressed.connect(_on_promote_star_pressed)
	detail_box.add_child(_promote_star_button)

	_relic_label = Label.new()
	_relic_label.add_theme_font_size_override("font_size", 17)
	_relic_label.add_theme_color_override("font_color", TEXT_COLOR)
	_relic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_relic_label)

	_relic_button = Button.new()
	_relic_button.custom_minimum_size = Vector2(220, 44)
	_relic_button.add_theme_font_size_override("font_size", 17)
	_relic_button.pressed.connect(_on_relic_pressed)
	detail_box.add_child(_relic_button)

	# 练兵令（测试，v0.15.1）：消耗 1 枚使选中武将直接升 1 级（上限 30）。
	var exp_scroll_row := HBoxContainer.new()
	exp_scroll_row.add_theme_constant_override("separation", 12)
	detail_box.add_child(exp_scroll_row)
	_exp_scroll_label = Label.new()
	_exp_scroll_label.add_theme_font_size_override("font_size", 17)
	_exp_scroll_label.add_theme_color_override("font_color", ACCENT_COLOR)
	exp_scroll_row.add_child(_exp_scroll_label)
	_exp_scroll_button = Button.new()
	_exp_scroll_button.text = "使用练兵令（测试：直接升 1 级）"
	_exp_scroll_button.custom_minimum_size = Vector2(260, 40)
	_exp_scroll_button.add_theme_font_size_override("font_size", 15)
	_exp_scroll_button.pressed.connect(_on_exp_scroll_pressed)
	exp_scroll_row.add_child(_exp_scroll_button)
	_exp_scroll_hint = Label.new()
	_exp_scroll_hint.add_theme_font_size_override("font_size", 14)
	_exp_scroll_hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.58))
	exp_scroll_row.add_child(_exp_scroll_hint)


func _on_character_pressed(character_id: String) -> void:
	_select_character(character_id)
	_refresh()


func _select_character(character_id: String) -> void:
	_selected_id = character_id
	for key in _character_buttons.keys():
		var button := _character_buttons[key] as Button
		if is_instance_valid(button):
			button.set_pressed_no_signal(str(key) == character_id)


func _selected_character() -> CharacterData:
	for character_data in _owned:
		if str(character_data.character_id) == _selected_id:
			return character_data
	return null


func _refresh() -> void:
	_refresh_gacha()
	var character := _selected_character()
	if character == null:
		return

	var level := GameFlow.get_character_level(_profile, _selected_id)
	var promotion := GameFlow.get_active_promotion(_profile, _selected_id)
	var progress := LevelCurve.progress_at(_profile.get_character_exp(_selected_id))
	var stats := character.compute_stats_at(level, promotion)

	_detail_name_label.text = "%s · %s · 等级 %d" % [
		character.display_name,
		character.profession.display_name if character.profession != null else "未知职业",
		level,
	]
	_exp_bar.max_value = maxi(int(progress.exp_for_next), 1)
	_exp_bar.value = int(progress.exp_into_level)
	if progress.is_max_level:
		_exp_label.text = "经验 %d（已达第一章等级上限 %d）" % [_profile.get_character_exp(_selected_id), LevelCurve.MAX_LEVEL]
	else:
		_exp_label.text = "经验 %d · 距下一级还需 %d" % [
			int(progress.exp_into_level), int(progress.exp_for_next) - int(progress.exp_into_level),
		]
	_stats_label.text = "伤害 %d　　攻速 %.2f 次/秒　　射程 %d" % [
		stats.damage, 1.0 / maxf(stats.attack_interval, 0.01), int(stats.range),
	]
	_refresh_promotion(character, level)
	_refresh_stars(level)
	_refresh_relic(character)
	_refresh_exp_scroll(level)


## 转职候选（阶段 6 图结构，v0.17.0）：未转职展示一转；已转职展示二转分支列表。
## 条件（等级/材料）逐条展示，满足才可点击；候选由 GameFlow 图结构校验保证合法性。
func _refresh_promotion(character: CharacterData, level: int) -> void:
	for button in _promotion_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_promotion_buttons.clear()
	_promotion_label.visible = true

	var active := GameFlow.get_active_promotion(_profile, _selected_id)
	var candidates := GameFlow.get_promotion_candidates(_profile, _selected_id)
	if active == null and character.promotion_ids.is_empty():
		_promotion_label.text = "暂无转职路线"
		return
	if candidates.is_empty():
		if active != null:
			_promotion_label.text = "已转职：%s（%s）——已至该路线终点" % [active.display_name, active.description]
		else:
			_promotion_label.text = "转职配置缺失：%s" % str(character.promotion_ids[0])
		return

	_promotion_label.text = "已转职：%s（%s）——选择二转路线：" % [active.display_name, active.description] if active != null else "一转路线："
	for promotion in candidates:
		var level_ok := level >= promotion.required_level
		var lines: Array[String] = [
			"%s：%s —— %s" % ["二转" if active != null else "一转", promotion.display_name, promotion.description],
			"等级需求 %d：%s" % [promotion.required_level, "已达标" if level_ok else "当前 %d" % level],
		]
		var materials_ok := true
		for cost in promotion.item_costs:
			if cost == null or cost.item == null:
				continue
			var owned: int = int(_profile.items.get(str(cost.item.item_id), 0))
			var enough: bool = owned >= cost.amount
			materials_ok = materials_ok and enough
			lines.append("%s：%d/%d %s" % [
				cost.item.display_name, owned, cost.amount, "已备齐" if enough else "不足",
			])
		var label := Label.new()
		label.text = "\n".join(lines)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", OK_COLOR if (level_ok and materials_ok) else BAD_COLOR)
		_promotion_buttons_box.add_child(label)

		var button := Button.new()
		button.text = "转职为「%s」" % promotion.display_name
		button.custom_minimum_size = Vector2(240, 40)
		button.add_theme_font_size_override("font_size", 16)
		button.disabled = not (level_ok and materials_ok)
		button.pressed.connect(_on_promote_pressed.bind(promotion))
		_promotion_buttons_box.add_child(button)
		_promotion_buttons.append(button)


## 练兵令（测试，v0.15.1）：数量展示、满级/不足禁用。
func _refresh_exp_scroll(level: int) -> void:
	var count: int = int(_profile.items.get(EXP_SCROLL_ID, 0))
	_exp_scroll_label.text = "练兵令 ×%d" % count
	_exp_scroll_button.disabled = _selected_id.is_empty() or count <= 0 or level >= LevelCurve.MAX_LEVEL
	_exp_scroll_hint.text = "（仅测试发放，使用后直接升 1 级）"


func _on_exp_scroll_pressed() -> void:
	if _selected_id.is_empty():
		return
	var level := GameFlow.get_character_level(_profile, _selected_id)
	if level >= LevelCurve.MAX_LEVEL:
		_exp_scroll_hint.text = "已达等级上限，无法使用"
		return
	if not _profile.spend_item(EXP_SCROLL_ID, 1):
		_exp_scroll_hint.text = "练兵令不足"
		return
	var current_total := _profile.get_character_exp(_selected_id)
	var next_total := LevelCurve.exp_total_for_level(level + 1)
	_profile.add_character_exp(_selected_id, next_total - current_total)
	ProfileStore.save_profile(_profile)
	_exp_scroll_hint.text = "已使用：等级提升至 %d" % (level + 1)
	_refresh()


func _on_promote_pressed(promotion: PromotionData) -> void:
	if promotion == null:
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "转职为「%s」？\n转职不可逆，将消耗转职材料。" % promotion.display_name
	dialog.ok_button_text = "确认转职"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(_apply_promotion.bind(promotion, dialog))
	dialog.cancelled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _apply_promotion(promotion: PromotionData, dialog: ConfirmationDialog) -> void:
	var character := _selected_character()
	if character == null or promotion == null:
		dialog.queue_free()
		return
	# 防御：候选必须是当前图结构的合法下一步（防跳级/回退/重复转职）。
	var valid := false
	for candidate in GameFlow.get_promotion_candidates(_profile, _selected_id):
		if str(candidate.promotion_id) == str(promotion.promotion_id):
			valid = true
			break
	if not valid:
		dialog.queue_free()
		return
	for cost in promotion.item_costs:
		if cost == null or cost.item == null:
			continue
		if not _profile.spend_item(str(cost.item.item_id), cost.amount):
			dialog.queue_free()
			return
	var entry := _profile.get_character(_selected_id)
	var promotion_path: Array = entry.get("promotion_path", [])
	var new_path := []
	for existing in promotion_path:
		new_path.append(str(existing))
	new_path.append(str(promotion.promotion_id))
	_profile.set_promotion_path(_selected_id, new_path)
	ProfileStore.save_profile(_profile)
	dialog.queue_free()
	_refresh()


## 星级（GDD 4.8 升星）：碎片逐星 20/40/80/160，成长系数 +5%/星。
func _refresh_stars(_level: int) -> void:
	var stars := _profile.get_character_stars(_selected_id)
	var shards: int = int(_profile.get_character(_selected_id).get("shards", 0))
	var stars_text := ""
	for _i in range(stars):
		stars_text += "★"
	if stars >= 5:
		_stars_label.text = "星级：%s（已满星）" % stars_text
		_promote_star_button.visible = false
		return
	_stars_label.text = "星级：%s" % (stars_text if stars_text != "" else "☆")
	var cost: int = [20, 40, 80, 160][stars]
	_promote_star_button.visible = true
	_promote_star_button.text = "升星（碎片 %d/%d）" % [int(shards), cost]
	_promote_star_button.disabled = int(shards) < cost


func _on_promote_star_pressed() -> void:
	if _profile.promote_character_star(_selected_id):
		ProfileStore.save_profile(_profile)
	_refresh()


## 信物（GDD 4.8）：碎片兑换 + 装备/卸下；建造时经 loadout 生效。
func _refresh_relic(character: CharacterData) -> void:
	var relic := GameFlow.get_relic_for_character(_selected_id)
	if relic == null:
		_relic_label.text = "信物：暂未开放"
		_relic_button.visible = false
		return
	var owned := _profile.has_relic(str(relic.relic_id))
	var equipped: String = str(_profile.get_character(_selected_id).get("relic", ""))
	if owned:
		var is_equipped := equipped == str(relic.relic_id)
		_relic_label.text = "信物：%s —— %s%s" % [
			relic.display_name, relic.description, "（已装备）" if is_equipped else "（未装备）",
		]
		_relic_button.text = "卸下信物" if is_equipped else "装备信物"
		_relic_button.visible = true
		_relic_button.disabled = false
	else:
		var shards: int = int(_profile.get_character(_selected_id).get("shards", 0))
		_relic_label.text = "信物：%s（%s）· 碎片 %d 兑换" % [relic.display_name, relic.description, relic.shard_cost]
		_relic_button.text = "碎片兑换"
		_relic_button.visible = true
		_relic_button.disabled = shards < relic.shard_cost


func _on_relic_pressed() -> void:
	var relic := GameFlow.get_relic_for_character(_selected_id)
	if relic == null:
		return
	if _profile.has_relic(str(relic.relic_id)):
		var equipped: String = str(_profile.get_character(_selected_id).get("relic", ""))
		var next_relic := "" if equipped == str(relic.relic_id) else str(relic.relic_id)
		_profile.set_character_relic(_selected_id, next_relic)
	else:
		if not _profile.spend_shards(_selected_id, relic.shard_cost):
			return
		_profile.add_relic(str(relic.relic_id))
		_profile.set_character_relic(_selected_id, str(relic.relic_id))
	ProfileStore.save_profile(_profile)
	_refresh()


## 求贤（GDD modules/DROPS_GACHA.md 7.3，v0.14.1 入口落地）：
## 消耗求贤令×1 单抽；重复武将转碎片，每 10 抽保底未拥有角色（或碎片折算）。
func _refresh_gacha() -> void:
	var tokens: int = int(_profile.items.get("gacha_token", 0))
	_gacha_label.text = "求贤令：%d" % tokens
	_gacha_button.text = "求 贤（×1）"
	_gacha_button.disabled = tokens < 1


func _on_gacha_pressed() -> void:
	var result := GameFlow.pull_gacha(_profile)
	if result.is_empty():
		_show_gacha_result("求贤令不足或卡池为空")
		return
	_show_gacha_result(_gacha_result_text(result))
	_refresh()


func _gacha_result_text(result: Dictionary) -> String:
	var character_id := str(result.get("character_id", ""))
	var character := GameFlow.load_character_data(character_id)
	var name_text := character.display_name if character != null else character_id
	match result.get("type", ""):
		"pity_char":
			return "保底：获得新武将「%s」！" % name_text
		"pity_shards":
			return "保底：%s 碎片 ×%d" % [name_text, int(result.get("shards", 0))]
		"dup":
			return "%s 碎片 ×%d（重复武将转化）" % [name_text, int(result.get("shards", 0))]
		_:
			return "求贤结果异常"


func _show_gacha_result(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "求贤"
	dialog.dialog_text = message
	dialog.ok_button_text = "好"
	dialog.popup_centered()
	add_child(dialog)

