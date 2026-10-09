extends CanvasLayer

## ☰ 菜单（0.8.17.0）：id = MENU_* 常量，Main 路由到 继续 / 设置 / 重开 / 退出。
signal menu_action_requested(action_id: int)
## 军需槽右键（0.8.17.0）：打开军需面板（完整购买 / 使用入口，不暂停）。
signal supply_popup_requested
## 拖拽建造（v0.33.3）：武将卡片按下/松手 → Main → BuildManager 开始/结束拖拽。
signal card_drag_began(character_id: String)
signal card_drag_released(character_id: String)
## 拖拽中右键取消（Godot 拖拽期鼠标事件交「被按下控件」= 卡片，覆盖层收不到，B-078）。
signal card_drag_cancelled()
signal debug_wave_jump_requested(wave_index: int)
signal debug_clear_enemies_requested
signal tower_upgrade_requested
signal tower_sell_requested
## 手动大招（v0.15.0）：塔详情卡行末「大招 R」，R 键同效（Main 输入）。
signal ultimate_cast_requested
signal result_next_pressed
signal result_retry_pressed
signal result_menu_pressed
signal result_wheel_pressed
signal dialogue_finished

## ☰ 菜单动作 id（Main 路由：继续 / 设置 / 重开 / 退出）。
const MENU_RESUME := 0
const MENU_SETTINGS := 1
const MENU_RESTART := 2
const MENU_EXIT := 3

## 局内 HUD v2 皮肤（UI_LAYOUT §10 v0.20.41 定稿）：深墨绿 + 暖金；地图 / 道路不改色。
const HUD_SLOT_SIZE := 76.0
const HUD_SLOT_AVATAR := 46.0
const HUD_COST_PILL := Vector2(48.0, 22.0)
## 手动大招模式追加第 6 卡时使用的圆盘直径（升阶 / 回收 / 大招同规格 46px，UI_LAYOUT §10）。
const HUD_DISC_SIZE := 46.0

## 局内面板亮色化（v0.37.32）：卡片/塔面板改 Kenney 亮蓝白语言
## （底 #f7fbfe / 描边 #9fd0ea），与大厅、战斗顶栏（#eef8fe + #7ec8ea 细线）统一。
const PANEL_STYLE_BG := Color("#f7fbfe")
const PANEL_STYLE_BORDER := Color("#9fd0ea")
## 基地生命两态（v0.37.32 / UI_LAYOUT §10 v2 令牌）：常态绿 #4ec97e，≤30% 危急变红脉动。
const LIVES_COLOR_OK := Color("#4ec97e")
const LIVES_COLOR_LOW := Color("#ef5b52")
const LIVES_LOW_RATIO := 0.3
## 建造卡立绘头像（0.8.11.1）：character_id → 圆形透明 PNG（SpineSprite Idle 首帧截取，
## 素材随仓库入库 / 0.8.16.2·ART_ASSETS §5.8）；无条目/缺素材回退概念色占位圆。
const CHARACTER_AVATAR_TEXTURES := {
	"guan_yu": "res://assets/characters/guan_yu/hero_guan_yu_a_avatar.png",
}

@onready var gold_pill: PanelContainer = $Root/TopBar/Margin/Content/CoinPill
@onready var gold_label: Label = $Root/TopBar/Margin/Content/CoinPill/PillMargin/PillRow/CoinLabel
@onready var coin_icon: TextureRect = $Root/TopBar/Margin/Content/CoinPill/PillMargin/PillRow/CoinIcon
@onready var lives_label: Label = $Root/TopBar/Margin/Content/LivesPill/PillMargin/PillRow/LivesLabel
@onready var lives_icon: TextureRect = $Root/TopBar/Margin/Content/LivesPill/PillMargin/PillRow/LivesIcon
@onready var wave_label: Label = $Root/TopBar/Margin/Content/WavePill/PillMargin/PillRow/WaveLabel
@onready var wave_icon: TextureRect = $Root/TopBar/Margin/Content/WavePill/PillMargin/PillRow/WaveIcon
@onready var stage_label: Label = $Root/TopBar/Margin/Content/StageChip/ChipMargin/StageLabel
@onready var menu_button: MenuButton = $Root/TopBar/Margin/Content/MenuButton
@onready var message_panel: PanelContainer = $Root/MessagePanel
@onready var message_label: Label = $Root/MessagePanel/Margin/MessageLabel
@onready var status_label: Label = $Root/StatusLabel
@onready var character_bar: HBoxContainer = $Root/BottomBar/DockMargin/Dock/CharacterBar
## 军需槽容器（0.8.17.0）：Main 按局外选带填充 ≤3 槽（购买 / 使用 / 右键开军需面板）。
@onready var supply_bar: HBoxContainer = $Root/BottomBar/DockMargin/Dock/SupplyBar
@onready var _dock: HBoxContainer = $Root/BottomBar/DockMargin/Dock
@onready var _bottom_bar: PanelContainer = $Root/BottomBar
@onready var _build_hint: Label = $Root/BuildHint

const DEBUG_PANEL_SCRIPT := preload("res://scripts/DebugPanel.gd")

var _status_request_id: int = 0
var _previous_paused_state: bool = false
## 建造栏卡片（0.8.17.0 v2 卡面）：character_id → {id, panel, avatar, cost_pill, cost_label}。
var _character_cards: Dictionary = {}
var _character_costs: Dictionary = {}
## 未满编虚线空槽（UI_LAYOUT §10 v2：槽数 = 关卡出战上限）。
var _empty_slots: HBoxContainer = null
## 塔详情卡条（选中塔时整块替换建造位，同规格 5 卡 + 手动大招第 6 卡）。
var _tower_bar: HBoxContainer = null
## 当前按下（正在拖拽）的卡片 id：按下金色高亮，松手/取消复位。
var _held_card_id: String = ""
var _dialogue_panel: Control = null
## 基地生命危急态（v0.37.32）：≤30% 红字 + 脉动；_lives_pulse 为脉动相位累加。
var _lives_low: bool = false
var _lives_pulse: float = 0.0

# 塔详情卡条当前展示的塔与关卡规则；塔被回收后引用失效。
var _panel_tower: Tower = null
var _panel_stage_data: StageData = null
var _boss_banner: Label
var _boss_banner_timer: SceneTreeTimer = null
var _result_panel: PanelContainer
var _result_center: CenterContainer
var _result_title_label: Label
var _result_lines_label: Label
var _result_next_button: Button
var _result_wheel_button: Button
var _result_wheel_label: Label
var _wheel_rolled: bool = false
var _dialogue_layer: Control
var _dialogue_speaker_label: Label
var _dialogue_text_label: Label
var _dialogue_lines: Array = []
var _dialogue_index: int = 0
var _dialogue_advance_after_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_hud_glyphs()
	_style_hud_controls()
	_create_bottom_slots()
	_create_result_panel()
	_create_dialogue_layer()
	_create_boss_banner()

	if OS.is_debug_build():
		_create_debug_panel()

	update_gold(GameManager.gold)
	update_lives(GameManager.lives)
	update_wave(GameManager.current_wave, GameManager.total_waves)
	_previous_paused_state = get_tree().paused
	_refresh_action_buttons()
	_show_build_hint_once()


## 顶栏图徽落位（AGENTS §6 图徽优先）：金币 / 基地生命 / 波次三胶囊 = 透明符号 + 数值，
## 不再写「金币 / 生命 / 波次」名词；缺图按 §6 虚线圆占位并登记 ART_PROMPTS。
func _setup_hud_glyphs() -> void:
	_apply_glyph(coin_icon, "coin")
	_apply_glyph(lives_icon, "base_hp")
	_apply_glyph(wave_icon, "wave_flag")


func _apply_glyph(rect: TextureRect, icon_name: String) -> void:
	if rect == null:
		return
	var texture := UITheme.hud_icon(icon_name)
	if texture == null:
		push_warning("HUD 图徽缺失：%s（按 AGENTS §6 用虚线圆占位并登记 ART_PROMPTS）" % icon_name)
		rect.visible = false
		return
	rect.texture = texture


## ☰ 菜单（UI_LAYOUT §10 v2）：收录 继续 / 设置 / 重开 / 退出，ESC 同效（Main 输入）。
func _style_hud_controls() -> void:
	if menu_button == null:
		return
	menu_button.add_theme_stylebox_override("normal", _make_flat_style(
		UITheme.HUD_CARD_BG, Color(UITheme.HUD_LINE.r, UITheme.HUD_LINE.g, UITheme.HUD_LINE.b, 0.55), 10, 2))
	menu_button.add_theme_stylebox_override("hover", _make_flat_style(
		Color(0.09, 0.16, 0.12, 0.95), UITheme.HUD_LINE, 10, 2))
	menu_button.add_theme_stylebox_override("pressed", _make_flat_style(
		UITheme.HUD_BG_DEEP, UITheme.HUD_LINE, 10, 2))
	menu_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	menu_button.add_theme_color_override("font_color", UITheme.HUD_VALUE)
	menu_button.add_theme_color_override("font_hover_color", Color("#ffe9b0"))
	menu_button.add_theme_color_override("font_pressed_color", UITheme.HUD_VALUE)
	menu_button.add_theme_font_size_override("font_size", 22)
	var popup := menu_button.get_popup()
	if popup == null:
		return
	popup.clear()
	popup.add_item("暂停", MENU_RESUME)
	popup.add_item("设置", MENU_SETTINGS)
	popup.add_item("重开", MENU_RESTART)
	popup.add_item("退出", MENU_EXIT)
	popup.add_theme_stylebox_override("panel", _make_flat_style(UITheme.HUD_BG, UITheme.HUD_LINE, 8, 2))
	popup.add_theme_stylebox_override("hover", _make_flat_style(
		Color(0.12, 0.2, 0.15, 0.98), UITheme.HUD_LINE, 6, 1))
	popup.add_theme_color_override("font_color", UITheme.HUD_TEXT)
	popup.add_theme_color_override("font_hover_color", UITheme.HUD_VALUE)
	popup.add_theme_font_size_override("font_size", 17)
	popup.id_pressed.connect(activate_menu_action)


## ☰ 菜单动作出口（popup 点击 / ESC 菜单项）：Main 统一路由。
func activate_menu_action(action_id: int) -> void:
	menu_action_requested.emit(action_id)


## ESC 同效（Main 输入）：在 ☰ 按钮下缘弹出菜单。
func open_menu() -> void:
	if menu_button == null or not is_instance_valid(menu_button):
		return
	_refresh_action_buttons()
	var popup := menu_button.get_popup()
	if popup == null:
		return
	var rect := menu_button.get_global_rect()
	popup.position = Vector2i(int(rect.end.x) - 200, int(rect.end.y) + 4)
	popup.popup()


## HUD v2 通用描边底（深墨绿 + 暖金）：槽 / 菜单 / 费用胶囊共用。
func _make_flat_style(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


func set_stage_name(stage_name: String) -> void:
	stage_label.text = stage_name


## 调试辅助面板（仅调试构建创建）：加金币、跳波次、清场，方便测试。
func _create_debug_panel() -> void:
	var panel := DEBUG_PANEL_SCRIPT.new()
	panel.position = Vector2(640, 84)
	panel.wave_jump_requested.connect(debug_wave_jump_requested.emit)
	panel.clear_enemies_requested.connect(debug_clear_enemies_requested.emit)
	$Root.add_child(panel)


## 底栏两段结构（0.8.17.0 / UI_LAYOUT §10）：[建造位 | 塔详情] → 竖虚线 → 军需槽。
## 建造位与塔详情共用同一块位置（选中塔时整块替换），军需槽不随选中态变化。
func _create_bottom_slots() -> void:
	_style_dock_divider()
	_empty_slots = HBoxContainer.new()
	_empty_slots.name = "EmptySlots"
	_empty_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty_slots.add_theme_constant_override("separation", 10)
	_empty_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(_empty_slots)
	_dock.move_child(_empty_slots, character_bar.get_index() + 1)

	_tower_bar = HBoxContainer.new()
	_tower_bar.name = "TowerBar"
	_tower_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_tower_bar.add_theme_constant_override("separation", 10)
	_tower_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tower_bar.visible = false
	_dock.add_child(_tower_bar)
	_dock.move_child(_tower_bar, 0)


## 底栏分隔（UI_LAYOUT §10 v2）：建造位与军需槽之间的竖虚线——暖金 40% 透明度，
## 4 段 8px 短线；槽位整块替换（建造位 / 塔详情）时保持不动。
func _style_dock_divider() -> void:
	var divider := $Root/BottomBar/DockMargin/Dock/Divider as Control
	if divider == null:
		return
	var color := Color(UITheme.HUD_LINE.r, UITheme.HUD_LINE.g, UITheme.HUD_LINE.b, 0.4)
	for index in range(4):
		var dash := ColorRect.new()
		dash.color = color
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dash.position = Vector2(0, float(index) * 13.0)
		dash.size = Vector2(2, 8)
		divider.add_child(dash)


## 建造位（UI_LAYOUT §10 v2）：关卡出战上限枚 76×76 槽——46px 圆头像 + 右下角费用胶囊；
## 未满显虚线空槽。卡片即拖拽手柄（按下金色高亮；金币不足 = 灰头像 + 红框 + 红费用）。
func setup_character_bar(characters: Array, squad_limit: int = 0) -> void:
	for entry in _character_cards.values():
		var panel: Control = entry.get("panel") if entry is Dictionary else null
		if is_instance_valid(panel):
			panel.queue_free()
	_character_cards.clear()
	_character_costs.clear()
	_held_card_id = ""

	for character_data in characters:
		if character_data == null:
			continue
		var character_id := str(character_data.character_id)
		var card := _build_character_card(character_id, character_data)
		_character_costs[character_id] = character_data.build_cost
		_character_cards[character_id] = card
		character_bar.add_child(card["panel"])
	_build_empty_slots(maxi(squad_limit - _character_cards.size(), 0))
	_refresh_character_bar_affordance()


## 单张建造卡：76×76 槽 = 46px 圆头像 + 右下角 金币图徽 + 费用。
func _build_character_card(character_id: String, character_data: CharacterData) -> Dictionary:
	var panel := _make_slot_shell()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# 光标（UI_LAYOUT §15）：悬停手型；拖拽期由本卡承担拖拽光标（见 _set_card_cursor）。
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_card_gui_input.bind(character_id))
	var body := _slot_body(panel)
	var avatar: Control = _make_card_avatar(character_id, character_data.display_name)
	avatar.position = Vector2((HUD_SLOT_SIZE - HUD_SLOT_AVATAR) * 0.5, 4.0)
	avatar.size = Vector2(HUD_SLOT_AVATAR, HUD_SLOT_AVATAR)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(avatar)
	var pill := _make_cost_pill(character_data.build_cost, true)
	body.add_child(pill["root"])
	return {
		"id": character_id,
		"panel": panel,
		"avatar": avatar,
		"cost_pill": pill["root"],
		"cost_label": pill["label"],
	}


## 未满编虚线空槽（UI_LAYOUT §10 v2：槽数 = 关卡出战上限）。
func _build_empty_slots(count: int) -> void:
	if _empty_slots == null:
		return
	for child in _empty_slots.get_children():
		child.queue_free()
	for _index in range(count):
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(HUD_SLOT_SIZE, HUD_SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pill := DashedPill.new()
		pill.setup(Color(0, 0, 0, 0),
			Color(UITheme.HUD_LINE.r, UITheme.HUD_LINE.g, UITheme.HUD_LINE.b, 0.4), 12.0)
		pill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(pill)
		_empty_slots.add_child(slot)


## 槽壳（76×76 深墨绿圆角卡）：PanelContainer 会铺满直接子节点，故内容统一挂 _slot_body。
func _make_slot_shell() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(HUD_SLOT_SIZE, HUD_SLOT_SIZE)
	panel.add_theme_stylebox_override("panel", _make_flat_style(
		UITheme.HUD_CARD_BG,
		Color(UITheme.HUD_LINE.r, UITheme.HUD_LINE.g, UITheme.HUD_LINE.b, 0.5), 12, 2))
	return panel


func _slot_body(panel: PanelContainer) -> Control:
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(body)
	return body


## 右下角费用胶囊（图徽 + 数值，AGENTS §6）：金币不足 = 红底白字。
func _make_cost_pill(cost: int, affordable: bool) -> Dictionary:
	var root := PanelContainer.new()
	root.custom_minimum_size = HUD_COST_PILL
	root.position = Vector2(
		HUD_SLOT_SIZE - HUD_COST_PILL.x - 3.0, HUD_SLOT_SIZE - HUD_COST_PILL.y - 3.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_stylebox_override("panel", _make_flat_style(
		UITheme.HUD_COST_BG if affordable else Color("#c2604f"), Color(0, 0, 0, 0), 11, 0))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(13, 13)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = UITheme.hud_icon("coin")
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = str(cost)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UITheme.HUD_COST_TEXT if affordable else Color.WHITE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return {"root": root, "label": label, "icon": icon}


## 建造卡头像（0.8.11.1）：注册表有素材且可加载 → 圆形立绘 TextureRect；
## 否则概念色圆 + 姓氏首字占位（avatar_label 同款）。
func _make_card_avatar(character_id: String, display_name: String) -> Control:
	const diameter := HUD_SLOT_AVATAR
	var tex_path: String = CHARACTER_AVATAR_TEXTURES.get(character_id, "")
	if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path)
		if tex != null:
			var rect := TextureRect.new()
			rect.custom_minimum_size = Vector2(diameter, diameter)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture = tex
			return rect
	return UITheme.avatar_label(
		display_name.left(1),
		UITheme.character_avatar_color_key(character_id), diameter, 22)


## 建造栏负担标识（v0.12.2 / v0.33.3 卡片重设计）：金币不足整卡置灰 + 费用红色。
func _refresh_character_bar_affordance() -> void:
	for key in _character_cards.keys():
		_apply_card_style(_character_cards[key])


## 卡片按下 → 开始拖拽（金币不足不可拖；拖拽本身的金币校验由 BuildManager 兜底）。
## 拖拽中右键 → 取消（Godot 按住左键期间把鼠标事件交给「被按下控件」= 本卡，覆盖层收不到）。
func _on_card_gui_input(event: InputEvent, character_id: String) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if mouse_event.pressed and _held_card_id == character_id:
			clear_card_hold()
			card_drag_cancelled.emit()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		if GameManager.gold < int(_character_costs.get(character_id, 0)):
			return
		_held_card_id = character_id
		_apply_card_style(_character_cards.get(character_id, {}))
		_set_card_cursor(character_id, Control.CURSOR_DRAG)
		card_drag_began.emit(character_id)
	elif _held_card_id == character_id:
		clear_card_hold()
		card_drag_released.emit(character_id)


## 松手/取消/开始失败（Main 回调）→ 复位卡片按下的金色高亮与拖拽光标。
func clear_card_hold() -> void:
	if _held_card_id.is_empty():
		return
	var held_id := _held_card_id
	_held_card_id = ""
	for key in _character_cards.keys():
		_apply_card_style(_character_cards[key])
	_set_card_cursor(held_id, Control.CURSOR_POINTING_HAND)


## 建造卡光标切换（UI_LAYOUT §15 / B-077）：Godot 按住左键期间光标形状取 `mouse_focus`——
## 即按下时的控件（= 建造卡）而非指针下的拖拽覆盖层，故拖拽光标必须由卡片自身承担。
func _set_card_cursor(character_id: String, shape: Control.CursorShape) -> void:
	var entry: Dictionary = _character_cards.get(character_id, {})
	var panel: Control = entry.get("panel")
	if is_instance_valid(panel):
		panel.mouse_default_cursor_shape = shape


## 卡片样式刷新：按住=金色高亮；金币不足=灰字 + 红边框红费用；默认=面板边框。
func _apply_card_style(card: Variant) -> void:
	if not (card is Dictionary):
		return
	var character_id := str(card.get("id", ""))
	var panel: PanelContainer = card.get("panel")
	var affordable: bool = GameManager.gold >= int(_character_costs.get(character_id, 0))
	var held: bool = _held_card_id == character_id
	var border := Color(UITheme.HUD_LINE.r, UITheme.HUD_LINE.g, UITheme.HUD_LINE.b, 0.5)
	if held:
		border = UITheme.HUD_ACTION
	elif not affordable:
		border = Color(0.76, 0.38, 0.31, 0.9)
	if is_instance_valid(panel):
		panel.add_theme_stylebox_override("panel", _make_flat_style(
			Color("#2a3d2f") if held else UITheme.HUD_CARD_BG, border, 12, 3 if held else 2))
	var avatar: Control = card.get("avatar")
	if is_instance_valid(avatar):
		avatar.modulate = Color(1, 1, 1, 0.45) if not affordable else Color.WHITE
	var cost_pill: Control = card.get("cost_pill")
	if is_instance_valid(cost_pill):
		cost_pill.add_theme_stylebox_override("panel", _make_flat_style(
			UITheme.HUD_COST_BG if affordable else Color("#c2604f"), Color(0, 0, 0, 0), 11, 0))
	var cost_label: Label = card.get("cost_label")
	if is_instance_valid(cost_label):
		cost_label.add_theme_color_override("font_color",
			UITheme.HUD_COST_TEXT if affordable else Color.WHITE)


## 拖拽建造（v0.33.3）：屏幕坐标是否落在战斗 UI 区——顶栏/卡条整条横向区、
## 对话底栏 / 塔面板 / 结算 / 消息。拖入则虚影隐藏、松手取消。
## 调试面板为开发辅助浮层（不拦截点击），不计入，避免遮挡行 2 可建格。
func is_point_over_battle_ui(screen_pos: Vector2) -> bool:
	# 0.8.11.1 布局：顶栏整行 0..80、底部建造卡条整行 640..720；战场 row1..7 完整可建。
	if screen_pos.y <= 80.0 or screen_pos.y >= 640.0:
		return true
	if _result_panel != null and _result_panel.visible:
		return true
	if _dialogue_layer != null and _dialogue_layer.visible and is_instance_valid(_dialogue_panel) \
			and _dialogue_panel.get_global_rect().has_point(screen_pos):
		return true
	if message_panel.visible and message_panel.get_global_rect().has_point(screen_pos):
		return true
	return false


func _process(_delta: float) -> void:
	# UI 始终处理，暂停后仍可继续或重开游戏。
	_refresh_wave_label()
	if _lives_low:
		_lives_pulse += _delta * 5.2
		lives_label.modulate = Color(1, 1, 1, 0.6 + 0.4 * (0.5 + 0.5 * sin(_lives_pulse)))
	if get_tree().paused != _previous_paused_state:
		_previous_paused_state = get_tree().paused
		_refresh_action_buttons()


func update_gold(new_amount: int) -> void:
	# AGENTS §6 图徽优先：金币为纯数值（名词由顶栏金币图徽承载）。
	gold_label.text = "%d" % max(new_amount, 0)
	_refresh_tower_bar()
	_refresh_character_bar_affordance()
	_refresh_character_bar_affordance()


func update_lives(new_amount: int) -> void:
	lives_label.text = "%d" % max(new_amount, 0)
	_refresh_lives_color(new_amount)
	_refresh_action_buttons()
	_refresh_action_buttons()


## 基地生命两态（UI_LAYOUT §10，v0.37.32 落地）：常态绿 #0e9f58；
## ≤30% 变红 #e5484d 并在 _process 里脉动呼吸（透明度 0.6~1.0）。
func _refresh_lives_color(amount: int) -> void:
	var max_lives := maxi(GameManager.starting_lives, 1)
	_lives_low = float(max(amount, 0)) / float(max_lives) <= LIVES_LOW_RATIO
	lives_label.add_theme_color_override("font_color",
		LIVES_COLOR_LOW if _lives_low else LIVES_COLOR_OK)
	if not _lives_low:
		lives_label.modulate = Color.WHITE


func update_wave(current: int, total: int) -> void:
	_refresh_wave_label(current, total)
	_refresh_action_buttons()


func _refresh_wave_label(current: int = -1, total: int = -1) -> void:
	if current < 0:
		current = GameManager.current_wave
	if total < 0:
		total = GameManager.total_waves
	var displayed_wave := current + 1 if GameManager.is_wave_active else current
	wave_label.text = "%d / %d" % [clampi(displayed_wave, 0, total), total]


func show_message(message: String) -> void:
	message_label.text = message
	message_panel.visible = true


func hide_message() -> void:
	message_panel.visible = false


func hide_status() -> void:
	_status_request_id += 1
	status_label.visible = false


func show_status(message: String, duration: float = 1.5) -> void:
	_status_request_id += 1
	var request_id := _status_request_id
	status_label.text = message
	status_label.visible = true

	await get_tree().create_timer(duration, true).timeout
	if request_id == _status_request_id:
		status_label.visible = false


## 战局是否已结束（全部波次完成 / 基地生命归零）：结算开始后禁购买 · 使用军需（✅ 0.8.16，
## Main 军需面板唯一判定入口——原 `ui.game_finished` 属性在 UI.gd 中并不存在，见 BUGS B-067）。
func is_game_finished() -> bool:
	return GameManager.current_wave >= GameManager.total_waves or GameManager.lives <= 0


## ☰ 菜单状态刷新（0.8.17.0）：「开始第 N 波」按钮取消后，本函数只维护菜单项
## （暂停 / 继续 + 结算期禁用）——波次状态由出口波次旗帜（WaveFlag，Main 持有）表达。
func _refresh_action_buttons() -> void:
	if menu_button == null or not is_instance_valid(menu_button):
		return
	var popup := menu_button.get_popup()
	if popup == null:
		return
	var game_finished := is_game_finished()
	popup.set_item_text(popup.get_item_index(MENU_RESUME), "继续" if get_tree().paused else "暂停")
	popup.set_item_disabled(popup.get_item_index(MENU_RESUME), game_finished)
	popup.set_item_disabled(popup.get_item_index(MENU_SETTINGS), game_finished)


## 塔详情（UI_LAYOUT §10 v2）：选中塔 → 建造位整块替换为同规格 5 卡
## （头像 / 伤害 / 攻速 / 升阶 / 回收）；手动大招模式追加第 6 卡（动作词，R 键同效）。
## 详情只显示伤害与攻速（图徽 + 数值）——不显示等阶、无射程数值（选中即显示射程圈）。
func show_tower_bar(tower: Tower, stage_data: StageData) -> void:
	_panel_tower = tower
	_panel_stage_data = stage_data
	if _tower_bar == null:
		return
	character_bar.visible = false
	if _empty_slots != null:
		_empty_slots.visible = false
	_tower_bar.visible = true
	_refresh_tower_bar()


func hide_tower_bar() -> void:
	_panel_tower = null
	_panel_stage_data = null
	if _tower_bar != null:
		_tower_bar.visible = false
	if character_bar != null:
		character_bar.visible = true
	_refresh_bottom_bar_visible()


## 刷新塔详情（Main 在升阶 / 大招后调用；金币变化时刷新费用胶囊）。
func refresh_tower_bar() -> void:
	_refresh_tower_bar()


func _refresh_tower_bar() -> void:
	if _tower_bar == null or not _tower_bar.visible:
		return
	var tower := _panel_tower as Tower
	if tower == null or not is_instance_valid(tower):
		hide_tower_bar()
		return
	for child in _tower_bar.get_children():
		child.queue_free()

	_tower_bar.add_child(_make_avatar_slot(str(tower.character_id), str(tower.display_name)))
	_tower_bar.add_child(_make_stat_slot(_damage_icon_name(tower.get_attack_damage_type()), str(tower.damage)))
	_tower_bar.add_child(_make_stat_slot(
		"stat_attack_speed", "%.2f" % (1.0 / maxf(tower.attack_cooldown, 0.01))))

	var max_level: int = _panel_stage_data.max_inbattle_upgrade_level if _panel_stage_data != null else 0
	var maxed: bool = _panel_stage_data != null and tower.battle_rank >= max_level
	var upgrade_cost := 0
	var upgrade_affordable := false
	if not maxed:
		upgrade_cost = tower.get_upgrade_cost(_panel_stage_data.upgrade_cost_factor)
		upgrade_affordable = GameManager.gold >= upgrade_cost
	_tower_bar.add_child(_make_action_slot(
		"升阶", "gold", upgrade_cost, upgrade_affordable, maxed,
		func() -> void: tower_upgrade_requested.emit()))
	var refund := tower.get_sell_refund(_panel_stage_data.sell_refund_ratio if _panel_stage_data != null else 0.6)
	_tower_bar.add_child(_make_action_slot(
		"回收", "red", refund, true, false,
		func() -> void: tower_sell_requested.emit()))
	# 手动大招（v0.15.0）：仅手动模式且已登记动作时出现；R 键同效（Main 输入）。
	if GameFlow.is_gameplay_flag_enabled("manual_ultimate"):
		var actions: Array = tower.get_manual_actions()
		if not actions.is_empty():
			var ready := bool(actions[0].get("ready", false))
			_tower_bar.add_child(_make_action_slot(
				"大招 R", "gold", 0, ready, false,
				func() -> void: ultimate_cast_requested.emit(), true))


## 伤害类型图徽（AGENTS §6：伤害必带类型）：物理 / 魔法 / 真实。
func _damage_icon_name(damage_type: StringName) -> String:
	match damage_type:
		&"magic":
			return "dmg_magic"
		&"true":
			return "dmg_true"
		_:
			return "dmg_physical"


func _make_avatar_slot(character_id: String, display_name: String) -> Control:
	var slot := _make_slot_shell()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := _slot_body(slot)
	var avatar: Control = _make_card_avatar(character_id, display_name)
	avatar.position = Vector2((HUD_SLOT_SIZE - HUD_SLOT_AVATAR) * 0.5, 4.0)
	avatar.size = Vector2(HUD_SLOT_AVATAR, HUD_SLOT_AVATAR)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(avatar)
	return slot


## 属性卡（伤害 / 攻速）：图徽 + 数值。
func _make_stat_slot(icon_name: String, value_text: String) -> Control:
	var slot := _make_slot_shell()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := _slot_body(slot)
	var glyph := _make_glyph(icon_name, 34.0)
	glyph.position = Vector2((HUD_SLOT_SIZE - 34.0) * 0.5, 5.0)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(glyph)
	var label := Label.new()
	label.text = value_text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UITheme.HUD_VALUE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.position = Vector2(2.0, HUD_SLOT_SIZE - 27.0)
	label.size = Vector2(HUD_SLOT_SIZE - 4.0, 22.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(label)
	return slot


## 图徽控件（透明符号裸符号落位；缺图 = 虚线圆占位，AGENTS §6）。
func _make_glyph(icon_name: String, diameter: float) -> Control:
	var texture := UITheme.hud_icon(icon_name)
	if texture != null:
		var rect := TextureRect.new()
		rect.texture = texture
		# 先定 expand 再设尺寸：TextureRect 未忽略纹理尺寸时 minimum_size = 160px，
		# 会把 size 钳到 160（图徽巨大化溢出卡片，0.8.17.0 目视验收修复）。
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(diameter, diameter)
		rect.size = Vector2(diameter, diameter)
		return rect
	push_warning("HUD 图徽缺失：%s（按 AGENTS §6 虚线圆占位）" % icon_name)
	var pill := DashedPill.new()
	pill.custom_minimum_size = Vector2(diameter, diameter)
	pill.size = Vector2(diameter, diameter)
	pill.setup(Color(0, 0, 0, 0), UITheme.HUD_LINE, diameter * 0.5)
	return pill


## 动作卡（升阶 / 回收 / 大招）：46px 圆盘 + 动作词 + 右下角费用胶囊；
## 满阶 = 灰显不显费用；金币不足 = 费用胶囊红底（点击仍可，由 Main 提示）。
func _make_action_slot(text: String, kind: String, cost: int, affordable: bool, maxed: bool,
		on_pressed: Callable, no_cost: bool = false) -> Control:
	var slot := _make_slot_shell()
	var body := _slot_body(slot)
	var disc := Button.new()
	disc.custom_minimum_size = Vector2(HUD_DISC_SIZE, HUD_DISC_SIZE)
	disc.size = Vector2(HUD_DISC_SIZE, HUD_DISC_SIZE)
	disc.position = Vector2((HUD_SLOT_SIZE - HUD_DISC_SIZE) * 0.5, 4.0)
	disc.text = text
	disc.focus_mode = Control.FOCUS_NONE
	disc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	disc.add_theme_font_size_override("font_size", 13)
	var top := UITheme.HUD_DISC_GOLD if kind == "gold" else UITheme.HUD_DISC_RED
	var bottom := UITheme.HUD_DISC_GOLD_DEEP if kind == "gold" else UITheme.HUD_DISC_RED_DEEP
	var ink := Color("#2a1c05") if kind == "gold" else Color.WHITE
	disc.add_theme_stylebox_override("normal", _make_flat_style(bottom, top, int(HUD_DISC_SIZE * 0.5), 2))
	disc.add_theme_stylebox_override("hover", _make_flat_style(top, Color.WHITE, int(HUD_DISC_SIZE * 0.5), 2))
	disc.add_theme_stylebox_override("pressed", _make_flat_style(top, Color.WHITE, int(HUD_DISC_SIZE * 0.5), 3))
	disc.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	disc.add_theme_color_override("font_color", ink)
	disc.add_theme_color_override("font_hover_color", ink)
	disc.add_theme_color_override("font_pressed_color", ink)
	if maxed:
		disc.modulate = Color(1, 1, 1, 0.45)
	disc.pressed.connect(on_pressed)
	body.add_child(disc)
	if not maxed and not no_cost:
		var pill := _make_cost_pill(cost, affordable)
		body.add_child(pill["root"])
	return slot


## 金币获取反馈锚点（DESIGN_REVIEW §12.7 拍板 8）：顶栏金币胶囊中心（屏幕坐标）。
func get_gold_anchor() -> Vector2:
	if gold_pill == null or not is_instance_valid(gold_pill):
		return Vector2.ZERO
	return gold_pill.get_global_rect().get_center()


## Boss 登场横幅（v0.15.0）：顶部大字号金字，放大淡入 → 停留 → 淡出。
func _create_boss_banner() -> void:
	_boss_banner = Label.new()
	_boss_banner.name = "BossBanner"
	_boss_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_banner.add_theme_font_size_override("font_size", 44)
	_boss_banner.add_theme_color_override("font_color", UITheme.RED)
	_boss_banner.add_theme_color_override("font_outline_color", Color(0.4, 0.1, 0.05))
	_boss_banner.add_theme_constant_override("outline_size", 10)
	_boss_banner.visible = false
	_boss_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_banner.offset_top = 90.0
	add_child(_boss_banner)


func show_boss_banner(display_name: String) -> void:
	if _boss_banner == null:
		return
	_boss_banner.text = "⚠ %s 降临 ⚠" % display_name
	_boss_banner.visible = true
	_boss_banner.modulate.a = 0.0
	_boss_banner.scale = Vector2(1.6, 1.6)
	var tween := create_tween()
	tween.tween_property(_boss_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_boss_banner, "modulate:a", 1.0, 0.25)
	tween.tween_interval(1.1)
	tween.tween_property(_boss_banner, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: _boss_banner.visible = false)


## 开场剧情对话层（GDD modules/STAGES.md 5.1）：底部叙事面板，
## 点击任意处推进，"跳过"直接结束；展示期间为模态（阻挡地图点击）。
func _create_dialogue_layer() -> void:
	# v0.12.3 修复：整层不拦截鼠标（IGNORE），地图在剧情展示期间保持可交互；
	# 只有底部对话面板（STOP）接收点击用于推进。
	_dialogue_layer = Control.new()
	_dialogue_layer.name = "DialogueLayer"
	_dialogue_layer.visible = false
	_dialogue_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_dialogue_layer)
	_dialogue_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_layer.add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 190)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_dialogue_input)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	_dialogue_layer.add_child(panel)
	_dialogue_panel = panel
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 120.0
	panel.offset_right = -120.0
	# 0.8.11.1：底部建造卡条常驻 640..720，对话面板上移让位（448..638）。
	panel.offset_top = -272.0
	panel.offset_bottom = -82.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_dialogue_speaker_label = Label.new()
	_dialogue_speaker_label.add_theme_font_size_override("font_size", 21)
	_dialogue_speaker_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	vbox.add_child(_dialogue_speaker_label)

	_dialogue_text_label = Label.new()
	_dialogue_text_label.add_theme_font_size_override("font_size", 19)
	_dialogue_text_label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.9))
	_dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_dialogue_text_label)

	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 12)
	vbox.add_child(hint_row)

	var hint := Label.new()
	hint.text = "点击对话框继续 ▼（地图可正常建造）"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", UITheme.BLUE)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_row.add_child(hint)

	var skip_button := Button.new()
	skip_button.text = "跳过对话"
	skip_button.custom_minimum_size = Vector2(120, 34)
	skip_button.add_theme_font_size_override("font_size", 15)
	skip_button.pressed.connect(_finish_dialogue)
	hint_row.add_child(skip_button)


func show_dialogue(lines: Array) -> void:
	_dialogue_lines = lines
	_dialogue_index = 0
	_dialogue_layer.visible = true
	_refresh_bottom_bar_visible()
	# 打开瞬间与每次推进后的短防抖：快速连点不会一次跳过多行。
	_dialogue_advance_after_msec = Time.get_ticks_msec() + 200
	_show_current_line()


func _show_current_line() -> void:
	if _dialogue_index >= _dialogue_lines.size():
		_finish_dialogue()
		return
	var line: DialogueLineData = _dialogue_lines[_dialogue_index]
	_dialogue_speaker_label.text = line.speaker
	_dialogue_text_label.text = line.text


func _on_dialogue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed 			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_try_advance_dialogue()


func _try_advance_dialogue() -> void:
	var now := Time.get_ticks_msec()
	if now < _dialogue_advance_after_msec:
		return
	_dialogue_advance_after_msec = now + 180
	_advance_dialogue()


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_lines.size():
		_finish_dialogue()
	else:
		_show_current_line()


func _finish_dialogue() -> void:
	_dialogue_layer.visible = false
	dialogue_finished.emit()
	_refresh_bottom_bar_visible()


func skip_dialogue() -> void:
	_finish_dialogue()


func is_dialogue_active() -> bool:
	return _dialogue_layer != null and _dialogue_layer.visible


## 底部栏显隐（0.8.17.0）：结算面板展示期间收起让位；剧情对话面板已上移（448..638）
## 不遮底栏，对话期保持建造 / 塔详情 / 军需槽可点。
func _refresh_bottom_bar_visible() -> void:
	if _bottom_bar == null:
		return
	_bottom_bar.visible = _result_center == null or not _result_center.visible


## 建造引导提示（0.8.11.1）：开局一次性淡入停留淡出（卡条已移底部，提示补位）。
func _show_build_hint_once() -> void:
	if _build_hint == null:
		return
	_build_hint.visible = true
	_build_hint.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_build_hint, "modulate:a", 1.0, 0.5)
	tween.tween_interval(5.0)
	tween.tween_property(_build_hint, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: _build_hint.visible = false)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_STYLE_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = PANEL_STYLE_BORDER
	style.set_corner_radius_all(10)
	return style


## 结算面板（GDD 阶段 1）：胜利/失败、经验明细、掉落与新武将。
## 由全屏 CenterContainer 承载以保证严格居中；展示期间整体可见，
## 并以其默认 STOP 鼠标过滤充当模态（遮住后方顶栏与地图点击）。
func _create_result_panel() -> void:
	_result_center = CenterContainer.new()
	_result_center.name = "ResultCenter"
	_result_center.visible = false
	$Root.add_child(_result_center)
	_result_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_result_panel = PanelContainer.new()
	_result_panel.name = "ResultPanel"
	_result_panel.custom_minimum_size = Vector2(460, 0)
	_result_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_result_center.add_child(_result_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_result_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.name = "ResultTitle"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	_result_title_label = title

	var lines := Label.new()
	lines.name = "ResultLines"
	lines.add_theme_font_size_override("font_size", 19)
	lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lines)
	_result_lines_label = lines

	var wheel_button := Button.new()
	wheel_button.name = "ResultWheelButton"
	wheel_button.custom_minimum_size = Vector2(0, 42)
	wheel_button.add_theme_font_size_override("font_size", 17)
	wheel_button.pressed.connect(func() -> void: result_wheel_pressed.emit())
	vbox.add_child(wheel_button)
	_result_wheel_button = wheel_button

	var wheel_label := Label.new()
	wheel_label.name = "ResultWheelLabel"
	wheel_label.add_theme_font_size_override("font_size", 16)
	wheel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wheel_label.add_theme_color_override("font_color", UITheme.GOLD)
	wheel_label.visible = false
	vbox.add_child(wheel_label)
	_result_wheel_label = wheel_label

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	vbox.add_child(buttons)

	_result_next_button = Button.new()
	_result_next_button.custom_minimum_size = Vector2(170, 46)
	_result_next_button.add_theme_font_size_override("font_size", 18)
	_result_next_button.pressed.connect(func() -> void: result_next_pressed.emit())
	buttons.add_child(_result_next_button)

	var retry_button := Button.new()
	retry_button.custom_minimum_size = Vector2(150, 46)
	retry_button.add_theme_font_size_override("font_size", 18)
	retry_button.text = "重试本关"
	retry_button.pressed.connect(func() -> void: result_retry_pressed.emit())
	buttons.add_child(retry_button)

	var menu_button := Button.new()
	menu_button.custom_minimum_size = Vector2(150, 46)
	menu_button.add_theme_font_size_override("font_size", 18)
	menu_button.text = "返回选关"
	menu_button.pressed.connect(func() -> void: result_menu_pressed.emit())
	buttons.add_child(menu_button)


func show_result(data: Dictionary) -> void:
	var victory: bool = data.get("victory", false)
	var title := _result_title_label
	var lines := _result_lines_label
	title.text = "胜 利" if victory else "战 败"
	title.add_theme_color_override("font_color",
		UITheme.GREEN if victory else UITheme.RED)

	var line_parts: Array[String] = []
	if victory:
		var xp_by_character: Dictionary = data.get("xp_by_character", {})
		for character_id in xp_by_character.keys():
			line_parts.append("%s +%d 经验" % [
				GameFlow.load_character_data(str(character_id)).display_name
					if GameFlow.load_character_data(str(character_id)) != null else str(character_id),
				int(xp_by_character[character_id]),
			])
		var loot: Dictionary = data.get("loot", {})
		for item_id in loot.keys():
			line_parts.append("%s ×%d" % [GameFlow.get_item_display_name(str(item_id)), int(loot[item_id])])
		for unlock_name in data.get("unlock_names", []):
			line_parts.append("新武将加入：%s" % unlock_name)
		if line_parts.is_empty():
			line_parts.append("守住了全部波次")
		if not data.get("saved", false):
			line_parts.append("警告：存档写入失败，本次收益未保存")
	else:
		line_parts.append("基地陷落，本局收益未保存（失败不产生任何成长）")
	lines.text = "\n".join(line_parts)

	var next_stage_name := str(data.get("next_stage_name", ""))
	_result_next_button.visible = victory and not next_stage_name.is_empty()
	_result_next_button.text = "下一关：%s" % next_stage_name

	# 结算转盘（阶段 8 提交 2）：胜利且剩余金币 ≥150 可抽 1 次（仅 1 次）。
	_wheel_rolled = false
	_result_wheel_label.visible = false
	var remaining_gold := int(data.get("remaining_gold", 0))
	if victory and remaining_gold >= SettlementWheel.MIN_REMAINING_GOLD:
		_result_wheel_button.visible = true
		_result_wheel_button.disabled = false
		_result_wheel_button.text = "结算转盘：剩余金币 %d 可抽 1 次" % remaining_gold
	else:
		_result_wheel_button.visible = false

	hide_tower_bar()
	_result_center.visible = true
	_result_panel.visible = true
	_refresh_bottom_bar_visible()


## 转盘结果展示（阶段 8 提交 2）：入账成功后由 Main 调用；单次点击后禁用。
func show_result_wheel_result(text: String) -> void:
	if _wheel_rolled:
		return
	_wheel_rolled = true
	_result_wheel_button.disabled = true
	_result_wheel_button.text = "转盘已抽取"
	_result_wheel_label.text = text
	_result_wheel_label.visible = true


func hide_result() -> void:
	_result_center.visible = false
	_result_panel.visible = false
	_refresh_bottom_bar_visible()
