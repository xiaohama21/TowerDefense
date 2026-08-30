extends Node2D

const BUILD_SLOT_SCENE: PackedScene = preload("res://scenes/BuildSlot.tscn")
const DEFAULT_STAGE_ID: StringName = &"ch01_s01"

@onready var enemy_manager = $EnemyManager
@onready var tower_manager = $TowerManager
@onready var wave_manager = $WaveManager
@onready var build_manager = $BuildManager
@onready var ui = $UI
@onready var grid_background: GridBackground = $GridBackground
@onready var path_2d: Path2D = $Path2D
@onready var spawn_marker: Node2D = $SpawnMarker
@onready var base_marker: Node2D = $BaseMarker
@onready var build_slots_container: Node2D = $BuildSlots

var battle_session: BattleSession
var stage_data: StageData
var _available_characters: Array[CharacterData] = []
var _selected_character: CharacterData = null
var _selected_tower: Tower = null
## 战斗内设置弹窗（v0.19.2）：打开时暂停，关闭后恢复。
var _settings_popup: CanvasLayer = null
var _was_paused_before_settings: bool = false
## Boss 横幅去抖（v0.15.0）：同名 Boss 短时间只播一次。
var _last_boss_banner_msec: int = 0

func _ready():
	get_tree().paused = false
	ui.hide_result()
	stage_data = _resolve_stage_data()
	if stage_data == null:
		push_error("关卡数据加载失败")
		return

	_apply_stage_layout()
	_ensure_initial_profile()
	_available_characters = _load_available_characters(ProfileStore.get_profile())
	if _available_characters.is_empty():
		push_error("没有可出战的武将")
		return

	var tech_bonuses := TechTree.get_tech_bonuses(ProfileStore.get_profile())
	# 局内遗物开局加成（v0.19.0，CHARACTERS.md 4.8）：初始金币/基地生命加算。
	var relic_bonuses := GameFlow.get_battle_relic_bonuses()
	GameManager.reset(
		stage_data.starting_currency + int(tech_bonuses.get("start_gold", 0)) + int(relic_bonuses.get("start_gold", 0)),
		stage_data.starting_lives + int(tech_bonuses.get("base_hp", 0)) + int(relic_bonuses.get("base_hp_bonus", 0)),
		stage_data.waves.size()
	)
	battle_session = BattleSession.new(stage_data.stage_id)
	GameManager.set_battle_session(battle_session)
	wave_manager.configure_waves(stage_data.waves)

	# Keep autoload signal connections idempotent when the scene is reloaded.
	_disconnect_game_signals()
	GameManager.gold_changed.connect(ui.update_gold)
	GameManager.lives_changed.connect(ui.update_lives)
	GameManager.wave_changed.connect(ui.update_wave)
	GameManager.game_over.connect(_on_game_over)
	GameManager.victory.connect(_on_victory)
	GameManager.boss_entered.connect(_on_boss_entered)

	wave_manager.wave_completed.connect(_on_wave_completed)
	ui.next_wave_pressed.connect(_on_next_wave_pressed)
	ui.pause_pressed.connect(_on_pause_pressed)
	ui.settings_pressed.connect(_on_settings_pressed)
	ui.restart_pressed.connect(_on_restart_pressed)
	ui.character_selected.connect(_on_character_selected)
	ui.debug_wave_jump_requested.connect(_on_debug_wave_jump)
	ui.debug_clear_enemies_requested.connect(_on_debug_clear_enemies)
	ui.tower_upgrade_requested.connect(_on_tower_upgrade_requested)
	ui.tower_sell_requested.connect(_on_tower_sell_requested)
	ui.ultimate_cast_requested.connect(_on_ultimate_cast_requested)
	ui.result_next_pressed.connect(_on_result_next_pressed)
	ui.result_retry_pressed.connect(_on_result_retry_pressed)
	ui.result_menu_pressed.connect(_on_result_menu_pressed)
	ui.exit_pressed.connect(_on_exit_pressed)
	build_manager.tower_built.connect(_on_tower_built)
	tower_manager.tower_created.connect(_on_tower_created)

	ui.set_stage_name(stage_data.display_name)
	ui.setup_character_bar(_available_characters)
	_select_character(str(_available_characters[0].character_id))

	ui.update_gold(GameManager.gold)
	ui.update_lives(GameManager.lives)
	ui.update_wave(GameManager.current_wave, GameManager.total_waves)
	ui.show_status("选择武将后点击绿色 + 建造，再开始第 1 波", 3.0)

	# 开场剧情（GDD modules/STAGES.md 5.1）：设置开启"剧情速进"时自动跳过。
	if stage_data.dialogue != null and not stage_data.dialogue.lines.is_empty() 			and not GameFlow.is_gameplay_flag_enabled("skip_dialogue"):
		ui.show_dialogue(stage_data.dialogue.lines)


## Battle scene entry: GameFlow carries the selected stage; direct scene runs
## (tests) fall back to the default teaching stage.
func _resolve_stage_data() -> StageData:
	var stage_id := GameFlow.selected_stage_id
	if stage_id.is_empty():
		stage_id = DEFAULT_STAGE_ID
	var data := GameFlow.load_stage_data(stage_id)
	if data == null and stage_id != DEFAULT_STAGE_ID:
		data = GameFlow.load_stage_data(DEFAULT_STAGE_ID)
	return data


## 战场布局由 StageData 驱动（GDD 5.6）：路径、道路瓦片、出入口地标与建造位。
func _apply_stage_layout() -> void:
	if stage_data.path_points.is_empty():
		push_warning("关卡 %s 未配置布局数据，沿用场景默认" % stage_data.stage_id)
		return

	var curve := Curve2D.new()
	for point in stage_data.path_points:
		curve.add_point(point)
	path_2d.curve = curve

	var road_cells := GridBackground.derive_road_cells(stage_data.path_points)
	# 分叉路径（s08 试点）：召唤护卫自岔路进场；岔路道路格并入背景绘制。
	if not stage_data.fork_path_points.is_empty():
		var fork_curve := Curve2D.new()
		for point in stage_data.fork_path_points:
			fork_curve.add_point(point)
		var fork_path := Path2D.new()
		fork_path.name = "ForkPath2D"
		fork_path.curve = fork_curve
		add_child(fork_path)
		enemy_manager.fork_path = fork_path
		road_cells.append_array(GridBackground.derive_road_cells(stage_data.fork_path_points))
	var entry_cell := _first_in_map_road_cell(road_cells, true)
	var base_cell := _first_in_map_road_cell(road_cells, false)
	grid_background.configure(road_cells, stage_data.decor_cells, entry_cell, base_cell, stage_data.theme)

	spawn_marker.position = _first_in_map_point(stage_data.path_points, true)
	base_marker.position = _first_in_map_point(stage_data.path_points, false)

	for existing_slot in build_slots_container.get_children():
		existing_slot.queue_free()
	var slot_data := stage_data.get_build_slot_data()
	for index in range(slot_data.size()):
		var slot := BUILD_SLOT_SCENE.instantiate() as BuildSlot
		slot.slot_id = index + 1
		slot.apply_slot_data(slot_data[index])
		build_slots_container.add_child(slot)
		slot.position = slot_data[index].position


func _first_in_map_road_cell(cells: Array[Vector2i], from_start: bool) -> Vector2i:
	var indices := range(cells.size())
	if not from_start:
		indices.reverse()
	for index in indices:
		if cells[index].x >= 0 and cells[index].x < GridBackground.COLS \
				and cells[index].y >= 0 and cells[index].y < GridBackground.ROWS:
			return cells[index]
	return Vector2i(-1, -1)


func _first_in_map_point(points: Array[Vector2], from_start: bool) -> Vector2:
	var indices := range(points.size())
	if not from_start:
		indices.reverse()
	for index in indices:
		var point := points[index]
		if point.x >= 0 and point.x <= 1280 and point.y >= 0 and point.y <= 720:
			return point
	return points[0] if not points.is_empty() else Vector2.ZERO


## New profiles start with the initial squad; later stages gate additional
## characters through first-clear unlocks.
func _ensure_initial_profile() -> void:
	GameFlow.ensure_initial_characters(ProfileStore.get_profile())


## 出战编队过滤（GDD 阶段 1 编队界面）：GameFlow.squad 为空时（如测试直开）
## 回退为全部已拥有武将。
func _load_available_characters(profile: PlayerProfile) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	var squad := GameFlow.squad_character_ids
	for character_id in profile.get_owned_character_ids():
		if not squad.is_empty() and not squad.has(character_id):
			continue
		var character_data := GameFlow.load_character_data(character_id)
		if character_data != null:
			result.append(character_data)
	if result.is_empty() and not squad.is_empty():
		for character_id in profile.get_owned_character_ids():
			var character_data := GameFlow.load_character_data(character_id)
			if character_data != null:
				result.append(character_data)
	return result


func _on_character_selected(character_id: String) -> void:
	_select_character(character_id)


func _select_character(character_id: String) -> void:
	for character_data in _available_characters:
		if str(character_data.character_id) == character_id:
			_selected_character = character_data
			build_manager.selected_character = character_data
			# 切换武将时取消待确认建造（预览的武将已变化）
			build_manager.cancel_pending()
			ui.set_selected_character(character_id)
			return


func _on_tower_built(_slot: Node) -> void:
	if battle_session == null or _selected_character == null:
		return
	var character_id := str(_selected_character.character_id)
	if not battle_session.deployed_character_ids.has(character_id):
		battle_session.deployed_character_ids.append(character_id)


func _on_tower_created(tower: Tower) -> void:
	tower.selection_changed.connect(_on_tower_selection_changed)
	tower.set_float_text_layer(self)
	SfxLibrary.play(&"build", -10.0)


func _on_tower_selection_changed(tower: Tower) -> void:
	if tower.is_selected:
		# 选中已建塔时取消待确认建造（互斥）
		build_manager.cancel_pending()
		if _selected_tower != null and is_instance_valid(_selected_tower) and _selected_tower != tower:
			_selected_tower.set_selected(false)
		_selected_tower = tower
		ui.show_tower_panel(tower, stage_data)
	elif _selected_tower == tower:
		_selected_tower = null
		ui.hide_tower_panel()


func _on_tower_upgrade_requested() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	if tower_manager.upgrade_tower(_selected_tower, stage_data):
		ui.show_status("升级完成，伤害提升 25%")
		ui.show_tower_panel(_selected_tower, stage_data)
		SfxLibrary.play(&"build", -12.0)
	elif _selected_tower.battle_level >= stage_data.max_inbattle_upgrade_level:
		ui.show_status("已达到本关升级上限")
	else:
		ui.show_status("金币不足")


func _on_tower_sell_requested() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	var refund := _selected_tower.get_sell_refund(stage_data.sell_refund_ratio)
	if tower_manager.sell_tower(_selected_tower, stage_data):
		ui.show_status("已回收，返还 %d 金币" % refund)
		_selected_tower = null
		ui.hide_tower_panel()


## Boss 登场横幅（v0.15.0）：2.5 秒内只播一次。
func _on_boss_entered(display_name: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_boss_banner_msec < 2500:
		return
	_last_boss_banner_msec = now
	ui.show_boss_banner(display_name)


## 手动大招（v0.15.0）：属性面板按钮触发。
func _on_ultimate_cast_requested() -> void:
	_try_cast_selected_ultimate()


## R 键释放大招（v0.15.0，仅手动模式且选中塔）。
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_try_cast_selected_ultimate()


func _try_cast_selected_ultimate() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	if _selected_tower.cast_ultimate_manual():
		ui.show_status("%s 释放大招！" % _selected_tower.display_name, 1.0)
		ui.show_tower_panel(_selected_tower, stage_data)
	else:
		ui.show_status("怒气未满或范围内无目标")


## 战斗浮字（v0.15.0）：技能/大招/特性反馈飘字（世界坐标）。
func spawn_float_text_at(world_pos: Vector2, text: String, color: Color, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 50
	add_child(label)
	label.global_position = world_pos + Vector2(-30, 0)
	label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 34.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.35)
	tween.tween_callback(label.queue_free)


func _disconnect_game_signals() -> void:
	var callbacks := [
		[GameManager.gold_changed, Callable(ui, "update_gold")],
		[GameManager.lives_changed, Callable(ui, "update_lives")],
		[GameManager.wave_changed, Callable(ui, "update_wave")],
		[GameManager.game_over, Callable(self, "_on_game_over")],
		[GameManager.victory, Callable(self, "_on_victory")],
		[GameManager.boss_entered, Callable(self, "_on_boss_entered")],
	]
	for pair in callbacks:
		var signal_ref: Signal = pair[0]
		var callback: Callable = pair[1]
		if signal_ref.is_connected(callback):
			signal_ref.disconnect(callback)

func _on_next_wave_pressed():
	_try_start_wave()


## 波次开启（v0.15.3）：手动按钮与"自动开启下一波"共用；
## 空闲且未到总波数时才会真正开波（自动模式在最后一波胜利后不会误开）。
func _try_start_wave() -> void:
	if not GameManager.is_wave_active and GameManager.current_wave < GameManager.total_waves:
		ui.hide_message()
		wave_manager.start_wave(GameManager.current_wave)
		ui.update_wave(GameManager.current_wave, GameManager.total_waves)

func _on_wave_completed():
	GameManager.wave_completed()
	if GameFlow.is_gameplay_flag_enabled("auto_next_wave"):
		_try_start_wave()


## 调试：从任意波次直接开打（仅调试构建的测试面板会触发）。
func _on_debug_wave_jump(wave_index: int) -> void:
	if (
		GameManager.is_wave_active
		or GameManager.lives <= 0
		or wave_index < 0
		or wave_index >= GameManager.total_waves
	):
		ui.show_status("调试：当前无法跳转波次")
		return
	GameManager.current_wave = wave_index
	ui.hide_message()
	wave_manager.start_wave(wave_index)
	ui.update_wave(GameManager.current_wave, GameManager.total_waves)
	ui.show_status("调试：已开始第 %d 波" % (wave_index + 1))


func _on_debug_clear_enemies() -> void:
	wave_manager.debug_clear_enemies()
	ui.show_status("调试：已清空场上敌人", 1.5)

func _on_game_over():
	SfxLibrary.play(&"defeat", -8.0)
	build_manager.cancel_pending()
	if battle_session != null:
		ProfileStore.finish_defeat(battle_session, {
			"remaining_lives": GameManager.lives,
			"completed_waves": GameManager.current_wave,
		})
	ui.show_result({"victory": false})
	get_tree().paused = true

func _on_victory():
	SfxLibrary.play(&"victory", -8.0)
	var saved := false
	var xp_by_character: Dictionary = {}
	var loot: Dictionary = {}
	var unlock_names: Array[String] = []
	if battle_session != null and battle_session.mark_victory({
		"remaining_lives": GameManager.lives,
		"completed_waves": GameManager.current_wave,
		"difficulty": Difficulty.key_name(GameFlow.selected_difficulty),
	}):
		var profile := ProfileStore.get_profile()
		var first_clear := not profile.stage_progress.has(stage_data.stage_id)
		GameFlow.collect_stage_rewards(battle_session, stage_data, first_clear)
		GameFlow.award_tech_points(battle_session, first_clear)
		battle_session.add_participation_xp(
			battle_session.get_deployed_character_ids(),
			stage_data.participant_xp
		)
		saved = ProfileStore.commit_victory(battle_session)
		xp_by_character = battle_session.get_pending_xp_by_character()
		loot = battle_session.get_pending_loot()
		unlock_names = _resolve_character_names(battle_session.get_pending_unlocks())
	build_manager.cancel_pending()
	ui.show_result({
		"victory": true,
		"xp_by_character": xp_by_character,
		"loot": loot,
		"unlock_names": unlock_names,
		"saved": saved,
		"next_stage_name": _next_stage_display_name(),
	})
	get_tree().paused = true


func _resolve_character_names(character_ids: Array[String]) -> Array[String]:
	var names: Array[String] = []
	for character_id in character_ids:
		var character_data := GameFlow.load_character_data(character_id)
		names.append(character_data.display_name if character_data != null else character_id)
	return names


func _next_stage_display_name() -> String:
	var next_stage_id := GameFlow.get_next_stage_id(stage_data.stage_id)
	if next_stage_id.is_empty():
		return ""
	var next_stage := GameFlow.load_stage_data(next_stage_id)
	return next_stage.display_name if next_stage != null else str(next_stage_id)


func _on_result_next_pressed() -> void:
	var next_stage_id := GameFlow.get_next_stage_id(stage_data.stage_id)
	if next_stage_id.is_empty():
		return
	GameFlow.select_stage(next_stage_id)
	GameFlow.clear_squad_relics()
	GameFlow.goto_battle()


func _on_result_retry_pressed() -> void:
	GameFlow.select_stage(stage_data.stage_id)
	GameFlow.goto_battle()


func _on_result_menu_pressed() -> void:
	GameFlow.clear_squad_relics()
	GameFlow.goto_hub()


## 顶栏退出（GDD v0.9.3）：本局尚未出结果时弹确认——中途退出收益作废
## （核心规则），会话由 _exit_tree 的弃置逻辑兜底清理。
func _on_exit_pressed() -> void:
	if battle_session != null and battle_session.is_in_progress():
		var dialog := ConfirmationDialog.new()
		dialog.process_mode = Node.PROCESS_MODE_ALWAYS
		dialog.dialog_text = "退出将放弃本局未结算的收益，确定退出？"
		dialog.ok_button_text = "放弃并退出"
		dialog.cancel_button_text = "继续战斗"
		dialog.confirmed.connect(_on_exit_confirmed.bind(dialog))
		dialog.canceled.connect(dialog.queue_free)
		dialog.close_requested.connect(dialog.queue_free)
		get_tree().root.add_child(dialog)
		dialog.popup_centered()
	else:
		GameFlow.goto_hub()


func _on_exit_confirmed(dialog: ConfirmationDialog) -> void:
	GameFlow.clear_squad_relics()
	GameFlow.goto_hub()
	dialog.queue_free()


## First clear grants unlocks and first-clear rewards; replays only grant the
## repeat rewards configured on the stage. 奖励数量按难度材料倍率缩放（GDD 10.7）。
## 战斗内设置（v0.19.2）：暂停并弹出设置面板（复用 SettingsPanel，改动即时生效并持久化）。
func _on_settings_pressed() -> void:
	if _settings_popup != null and is_instance_valid(_settings_popup):
		return
	_was_paused_before_settings = get_tree().paused
	get_tree().paused = true
	ui.show_status("已打开设置")
	_settings_popup = CanvasLayer.new()
	_settings_popup.layer = 60
	_settings_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_settings_popup)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_popup.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_popup.add_child(center)
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.075, 0.12, 0.97)
	panel_style.border_color = Color(0.25, 0.43, 0.68, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var settings := preload("res://scripts/ui_screens/panels/SettingsPanel.gd").new()
	box.add_child(settings)
	var close_button := Button.new()
	close_button.text = "关闭设置"
	close_button.custom_minimum_size = Vector2(200, 46)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(_on_settings_popup_closed)
	box.add_child(close_button)


func _on_settings_popup_closed() -> void:
	if _settings_popup != null and is_instance_valid(_settings_popup):
		_settings_popup.queue_free()
	_settings_popup = null
	if not _was_paused_before_settings:
		get_tree().paused = false
	ui.hide_status()


func _on_pause_pressed():
	if GameManager.lives <= 0 or GameManager.current_wave >= GameManager.total_waves:
		return
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		ui.show_status("游戏已暂停")
	else:
		ui.show_status("游戏继续")

func _on_restart_pressed():
	_discard_active_session()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _exit_tree() -> void:
	_discard_active_session()


func _discard_active_session() -> void:
	if battle_session == null or not battle_session.is_in_progress():
		return
	battle_session.abandon()
	ProfileStore.discard_session(battle_session)
	GameManager.set_battle_session(null)
