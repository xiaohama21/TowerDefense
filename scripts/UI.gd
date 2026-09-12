extends CanvasLayer

signal next_wave_pressed
signal pause_pressed
## 战斗内设置（v0.19.2）：暂停并打开设置弹窗。
signal settings_pressed
## 局内军需（阶段 8 提交 1）：打开军需弹窗。
signal battle_supply_pressed
signal restart_pressed
## 拖拽建造（v0.33.3）：武将卡片按下/松手 → Main → BuildManager 开始/结束拖拽。
signal card_drag_began(character_id: String)
signal card_drag_released(character_id: String)
signal debug_wave_jump_requested(wave_index: int)
signal debug_clear_enemies_requested
signal tower_upgrade_requested
signal tower_sell_requested
## 手动大招（v0.15.0）：属性面板"释放大招"按钮。
signal ultimate_cast_requested
signal result_next_pressed
signal result_retry_pressed
signal result_menu_pressed
signal result_wheel_pressed
signal exit_pressed
signal dialogue_finished

## 局内面板亮色化（v0.37.32）：卡片/塔面板改 Kenney 亮蓝白语言
## （底 #f7fbfe / 描边 #9fd0ea），与大厅、战斗顶栏（#eef8fe + #7ec8ea 细线）统一。
const PANEL_STYLE_BG := Color("#f7fbfe")
const PANEL_STYLE_BORDER := Color("#9fd0ea")
## 基地生命两态（v0.37.32 / UI_LAYOUT §10）：常态绿，≤30% 危急变红并脉动。
const LIVES_COLOR_OK := Color("#0e9f58")
const LIVES_COLOR_LOW := Color("#e5484d")
const LIVES_LOW_RATIO := 0.3
## 建造卡立绘头像（0.8.11.1）：character_id → 圆形透明 PNG（SpineSprite Idle 首帧截取，
## 素材与 D69 试点同口径本地存放不入库）；无条目/缺素材回退概念色占位圆。
const CHARACTER_AVATAR_TEXTURES := {
	"guan_yu": "res://assets/characters/guan_yu/hero_guan_yu_a_avatar.png",
}

@onready var gold_label: Label = $Root/TopBar/Margin/Content/GoldLabel
@onready var lives_label: Label = $Root/TopBar/Margin/Content/LivesLabel
@onready var wave_label: Label = $Root/TopBar/Margin/Content/WaveLabel
@onready var stage_label: Label = $Root/TopBar/Margin/Content/StageLabel
@onready var next_wave_button: Button = $Root/TopBar/Margin/Content/NextWaveButton
@onready var supply_button: Button = $Root/TopBar/Margin/Content/SupplyButton
@onready var pause_button: Button = $Root/TopBar/Margin/Content/PauseButton
@onready var settings_button: Button = $Root/TopBar/Margin/Content/SettingsButton
@onready var restart_button: Button = $Root/TopBar/Margin/Content/RestartButton
@onready var exit_button: Button = $Root/TopBar/Margin/Content/ExitButton
@onready var message_panel: PanelContainer = $Root/MessagePanel
@onready var message_label: Label = $Root/MessagePanel/Margin/MessageLabel
@onready var status_label: Label = $Root/StatusLabel
@onready var character_bar: HBoxContainer = $Root/BottomBar/CharacterBar
@onready var _bottom_bar: PanelContainer = $Root/BottomBar
@onready var _build_hint: Label = $Root/BuildHint

const DEBUG_PANEL_SCRIPT := preload("res://scripts/DebugPanel.gd")

var _status_request_id: int = 0
var _previous_paused_state: bool = false
## 建造栏卡片（v0.33.3 重设计）：character_id → {id, panel, name, profession, lv, cost}。
var _character_cards: Dictionary = {}
var _character_costs: Dictionary = {}
## 当前按下（正在拖拽）的卡片 id：按下金色高亮，松手/取消复位。
var _held_card_id: String = ""
var _dialogue_panel: Control = null
## 基地生命危急态（v0.37.32）：≤30% 红字 + 脉动；_lives_pulse 为脉动相位累加。
var _lives_low: bool = false
var _lives_pulse: float = 0.0

# 武将属性面板（升级/回收）当前展示的塔与关卡规则；塔被回收后引用失效。
var _panel_tower: Tower = null
var _panel_stage_data: StageData = null
var _tower_panel: PanelContainer
var _tower_title_label: Label
var _tower_attr_label: Label
var _tower_upgrade_button: Button
var _tower_sell_button: Button
var _tower_ultimate_button: Button
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
	_style_top_bar_buttons()
	next_wave_button.pressed.connect(_on_next_wave_button_pressed)
	supply_button.pressed.connect(func() -> void: battle_supply_pressed.emit())
	pause_button.pressed.connect(_on_pause_button_pressed)
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	restart_button.pressed.connect(_on_restart_button_pressed)
	exit_button.pressed.connect(func() -> void: exit_pressed.emit())

	_create_tower_panel()
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


## 顶栏按钮换肤（v0.37.32 / UI_LAYOUT §10）：黄 开始第 N 波 / 蓝 军需 / 灰 暂停·设置·重开 /
## 红 退出，与大厅 Kenney 亮蓝按钮同源（素材 assets/ui/buttons/rect）。
func _style_top_bar_buttons() -> void:
	UITheme.apply_kenney_rect_button(next_wave_button, "yellow", UITheme.INK, 8.0)
	UITheme.apply_kenney_rect_button(supply_button, "blue", Color.WHITE, 6.0)
	UITheme.apply_kenney_rect_button(pause_button, "grey", UITheme.INK, 6.0)
	UITheme.apply_kenney_rect_button(settings_button, "grey", UITheme.INK, 6.0)
	UITheme.apply_kenney_rect_button(restart_button, "grey", UITheme.INK, 6.0)
	UITheme.apply_kenney_rect_button(exit_button, "red", Color.WHITE, 6.0)


func set_stage_name(stage_name: String) -> void:
	stage_label.text = stage_name


## 调试辅助面板（仅调试构建创建）：加金币、跳波次、清场，方便测试。
func _create_debug_panel() -> void:
	var panel := DEBUG_PANEL_SCRIPT.new()
	panel.position = Vector2(640, 84)
	panel.wave_jump_requested.connect(debug_wave_jump_requested.emit)
	panel.clear_enemies_requested.connect(debug_clear_enemies_requested.emit)
	$Root.add_child(panel)


func setup_character_bar(characters: Array) -> void:
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
		var level := GameFlow.get_character_level(ProfileStore.get_profile(), character_id)

		# 卡片（0.8.11.1 底部横版，卡条 80px 高）= 拖拽手柄：48px 圆头像（关羽等有
		# 素材角色用立绘纹理、其余概念色占位）+ 右侧 武将名 / Lv（蓝）/ 费用（金）。
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(124, 68)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_card_gui_input.bind(character_id))
		character_bar.add_child(panel)

		var content := HBoxContainer.new()
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 8)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(content)

		var avatar: Control = _make_card_avatar(character_id, character_data.display_name)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(avatar)

		var info := VBoxContainer.new()
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_theme_constant_override("separation", 1)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(info)

		var name_label := Label.new()
		name_label.text = character_data.display_name
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(name_label)

		var lv_label := Label.new()
		lv_label.text = "Lv.%d" % level
		lv_label.add_theme_font_size_override("font_size", 11)
		lv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(lv_label)

		var cost_label := Label.new()
		cost_label.text = "%d 金" % character_data.build_cost
		cost_label.add_theme_font_size_override("font_size", 11)
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(cost_label)

		_character_costs[character_id] = character_data.build_cost
		_character_cards[character_id] = {
			"id": character_id,
			"panel": panel,
			"avatar": avatar,
			"name": name_label,
			"lv": lv_label,
			"cost": cost_label,
		}
	_refresh_character_bar_affordance()


## 建造卡头像（0.8.11.1）：注册表有素材且可加载 → 圆形立绘 TextureRect；
## 否则概念色圆 + 姓氏首字占位（avatar_label 同款）。
func _make_card_avatar(character_id: String, display_name: String) -> Control:
	const diameter := 48.0
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
func _on_card_gui_input(event: InputEvent, character_id: String) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		if GameManager.gold < int(_character_costs.get(character_id, 0)):
			return
		_held_card_id = character_id
		_apply_card_style(_character_cards.get(character_id, {}))
		card_drag_began.emit(character_id)
	elif _held_card_id == character_id:
		clear_card_hold()
		card_drag_released.emit(character_id)


## 松手/取消/开始失败（Main 回调）→ 复位卡片按下的金色高亮。
func clear_card_hold() -> void:
	if _held_card_id.is_empty():
		return
	_held_card_id = ""
	for key in _character_cards.keys():
		_apply_card_style(_character_cards[key])


## 卡片样式刷新：按住=金色高亮；金币不足=灰字 + 红边框红费用；默认=面板边框。
func _apply_card_style(card: Variant) -> void:
	if not (card is Dictionary):
		return
	var panel: PanelContainer = card.get("panel")
	var affordable: bool = GameManager.gold >= int(_character_costs.get(card.get("id", ""), 0))
	var held: bool = _held_card_id == str(card.get("id", ""))
	var border := PANEL_STYLE_BORDER
	var bg := UITheme.LIGHT_CARD_BG
	if held:
		border = UITheme.LIGHT_GOLD_SELECT
		bg = Color("#fff7dc")
	elif not affordable:
		border = Color("#e0a09a")
		bg = Color("#fff5f3")
	if is_instance_valid(panel):
		panel.add_theme_stylebox_override("panel", _make_card_style(border, bg))
	var avatar: Control = card.get("avatar")
	var name_label: Label = card.get("name")
	var lv_label: Label = card.get("lv")
	var cost_label: Label = card.get("cost")
	if is_instance_valid(avatar):
		avatar.modulate = Color(1, 1, 1, 0.45) if not affordable else Color.WHITE
	if is_instance_valid(name_label):
		name_label.add_theme_color_override("font_color",
			UITheme.LIGHT_LOCK if not affordable else UITheme.LIGHT_INK)
	if is_instance_valid(lv_label):
		lv_label.add_theme_color_override("font_color",
			UITheme.LIGHT_LOCK if not affordable else UITheme.LIGHT_ACCENT)
	if is_instance_valid(cost_label):
		cost_label.add_theme_color_override("font_color",
			Color("#d0453f") if not affordable else UITheme.LIGHT_GOLD_TEXT)


func _make_card_style(border_color: Color, bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style


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
	if is_instance_valid(_tower_panel) and _tower_panel.visible \
			and _tower_panel.get_global_rect().has_point(screen_pos):
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
	gold_label.text = "金币：%d" % max(new_amount, 0)
	_refresh_tower_panel()
	_refresh_character_bar_affordance()


func update_lives(new_amount: int) -> void:
	lives_label.text = "生命：%d" % max(new_amount, 0)
	_refresh_lives_color(new_amount)
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
	wave_label.text = "波次：%d / %d" % [clampi(displayed_wave, 0, total), total]


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


func _refresh_action_buttons() -> void:
	if not is_instance_valid(next_wave_button):
		return

	var all_waves_completed := GameManager.current_wave >= GameManager.total_waves
	var game_finished := all_waves_completed or GameManager.lives <= 0
	next_wave_button.disabled = (
		GameManager.is_wave_active
		or game_finished
	)
	pause_button.disabled = game_finished
	settings_button.disabled = game_finished
	supply_button.disabled = game_finished

	if all_waves_completed:
		next_wave_button.text = "全部波次完成"
	elif GameManager.is_wave_active:
		next_wave_button.text = "第 %d 波进行中…" % (GameManager.current_wave + 1)
	else:
		next_wave_button.text = "开始第 %d 波" % (GameManager.current_wave + 1)

	pause_button.text = "继续" if get_tree().paused else "暂停"


func _on_next_wave_button_pressed() -> void:
	if not next_wave_button.disabled:
		next_wave_pressed.emit()


func _on_pause_button_pressed() -> void:
	pause_pressed.emit()


func _on_restart_button_pressed() -> void:
	restart_pressed.emit()


## 武将属性面板（GDD v0.9.2）：点击已建塔，在地图正下方展示职业、局内
## 等级与伤害/攻速/射程；升级与回收入口并入面板。
func _create_tower_panel() -> void:
	_tower_panel = PanelContainer.new()
	_tower_panel.name = "TowerPanel"
	_tower_panel.visible = false
	_tower_panel.add_theme_stylebox_override("panel", _make_panel_style())
	$Root.add_child(_tower_panel)
	_tower_panel.anchor_left = 0.5
	_tower_panel.anchor_right = 0.5
	_tower_panel.anchor_top = 1.0
	_tower_panel.anchor_bottom = 1.0
	_tower_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tower_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tower_panel.offset_left = -230.0
	_tower_panel.offset_right = 230.0
	_tower_panel.offset_top = -14.0
	_tower_panel.offset_bottom = -14.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	_tower_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_tower_title_label = Label.new()
	_tower_title_label.add_theme_font_size_override("font_size", 18)
	_tower_title_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.8))
	_tower_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_tower_title_label)

	_tower_attr_label = Label.new()
	_tower_attr_label.add_theme_font_size_override("font_size", 15)
	_tower_attr_label.add_theme_color_override("font_color", UITheme.BLUE)
	_tower_attr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_tower_attr_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)

	_tower_upgrade_button = Button.new()
	_tower_upgrade_button.custom_minimum_size = Vector2(0, 40)
	_tower_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tower_upgrade_button.add_theme_font_size_override("font_size", 16)
	_tower_upgrade_button.pressed.connect(func() -> void: tower_upgrade_requested.emit())
	buttons.add_child(_tower_upgrade_button)

	_tower_sell_button = Button.new()
	_tower_sell_button.custom_minimum_size = Vector2(0, 40)
	_tower_sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tower_sell_button.add_theme_font_size_override("font_size", 16)
	_tower_sell_button.pressed.connect(func() -> void: tower_sell_requested.emit())
	buttons.add_child(_tower_sell_button)

	# 手动大招（v0.15.0）：仅手动模式显示，满怒可点。
	_tower_ultimate_button = Button.new()
	_tower_ultimate_button.custom_minimum_size = Vector2(0, 40)
	_tower_ultimate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tower_ultimate_button.add_theme_font_size_override("font_size", 16)
	_tower_ultimate_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_tower_ultimate_button.pressed.connect(func() -> void: ultimate_cast_requested.emit())
	buttons.add_child(_tower_ultimate_button)


func show_tower_panel(tower: Tower, stage_data: StageData) -> void:
	_panel_tower = tower
	_panel_stage_data = stage_data
	_tower_panel.visible = true
	_refresh_tower_panel()
	_refresh_bottom_bar_visible()


func hide_tower_panel() -> void:
	_panel_tower = null
	_panel_stage_data = null
	_tower_panel.visible = false
	_refresh_bottom_bar_visible()


## 刷新当前塔面板（Main 在角色技能释放后调用）。
func refresh_tower_panel() -> void:
	_refresh_tower_panel()


func _refresh_tower_panel() -> void:
	if _tower_panel == null or not _tower_panel.visible:
		return
	var tower := _panel_tower as Tower
	if tower == null or not is_instance_valid(tower):
		hide_tower_panel()
		return

	var max_level: int = _panel_stage_data.max_inbattle_upgrade_level if _panel_stage_data != null else 0
	_tower_title_label.text = "%s · %s · 局内阶数 %d/%d" % [
		tower.display_name, tower.get_profession_name(), tower.battle_rank, max_level
	]
	var attacks_per_second := 1.0 / maxf(tower.attack_cooldown, 0.01)
	var attr_text := "伤害 %d　　攻速 %.2f 次/秒　　射程 %d" % [
		tower.damage, attacks_per_second, int(tower.range_radius)
	]
	# 阶段 8：AOE 职业（投石车/术士）显示爆散范围，升阶范围提升可见。
	if tower.get_battle_rank_aoe_multiplier() > 1.001:
		attr_text += "　　爆散 %d" % ceili(BehaviorRegistry.LOB_EXPLOSION_RADIUS * tower.get_battle_rank_aoe_multiplier())
	_tower_attr_label.text = attr_text

	if _panel_stage_data != null and tower.battle_rank < max_level:
		var cost := tower.get_upgrade_cost(_panel_stage_data.upgrade_cost_factor)
		_tower_upgrade_button.text = "升阶（%d 金币）" % cost
		_tower_upgrade_button.disabled = GameManager.gold < cost
	else:
		_tower_upgrade_button.text = "已满阶"
		_tower_upgrade_button.disabled = true

	var refund := tower.get_sell_refund(_panel_stage_data.sell_refund_ratio if _panel_stage_data != null else 0.6)
	_tower_sell_button.text = "回收（返还 %d）" % refund
	_tower_sell_button.disabled = false

	var manual_mode: bool = GameFlow.is_gameplay_flag_enabled("manual_ultimate")
	# 手动动作槽（v0.37.12 / UI_LAYOUT v0.20.32 §10）：现网 action[0] = 大招（R 恒主位），
	# 未来「可手动」技能登记后由 Tower.get_manual_actions() 按序追加（Q 预留），此处数据驱动渲染。
	var actions: Array = tower.get_manual_actions() if manual_mode else []
	_tower_ultimate_button.visible = not actions.is_empty()
	if _tower_ultimate_button.visible:
		var action: Dictionary = actions[0]
		if action.get("ready", false):
			_tower_ultimate_button.text = "释放大招！（R）"
			_tower_ultimate_button.disabled = false
		else:
			_tower_ultimate_button.text = "怒气未满"
			_tower_ultimate_button.disabled = true


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


## 底部建造卡条显隐（0.8.11.1）：塔详情面板 / 结算展示期间收起让位；
## 剧情对话面板已上移（448..638）不遮卡条，对话期保持可建造。
func _refresh_bottom_bar_visible() -> void:
	if _bottom_bar == null:
		return
	var blocked: bool = (_tower_panel != null and _tower_panel.visible) \
		or (_result_center != null and _result_center.visible)
	_bottom_bar.visible = not blocked


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

	_tower_panel.visible = false
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
