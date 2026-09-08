extends Node2D

const DEFAULT_STAGE_ID: StringName = &"ch01_s01"
## 局内军需（阶段 8 提交 1）：目录内 .tres 即道具配置（BattleSupplyData）。
const BATTLE_SUPPLY_DIR := "res://resources/battle_supplies"

@onready var enemy_manager = $EnemyManager
@onready var tower_manager = $TowerManager
@onready var wave_manager = $WaveManager
@onready var build_manager = $BuildManager
@onready var ui = $UI
@onready var grid_background: GridBackground = $GridBackground
@onready var path_2d: Path2D = $Path2D
@onready var spawn_marker: Node2D = $SpawnMarker
@onready var base_marker: Node2D = $BaseMarker
var battle_session: BattleSession
var stage_data: StageData
var _available_characters: Array[CharacterData] = []
var _selected_tower: Tower = null
## 战斗内设置弹窗（v0.19.2）：打开时暂停，关闭后恢复。
var _settings_popup: CanvasLayer = null
var _was_paused_before_settings: bool = false
## Boss 横幅去抖（v0.15.0）：同名 Boss 短时间只播一次。
var _last_boss_banner_msec: int = 0
## 局内军需状态（阶段 8 提交 1）：道具列表与剩余次数（本局临时状态）。
var _battle_supplies: Array[BattleSupplyData] = []
var _supply_uses_left: Dictionary = {}
var _battle_supply_popup: CanvasLayer = null
var _supply_buttons: Dictionary = {}

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
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.lives_changed.connect(ui.update_lives)
	GameManager.wave_changed.connect(ui.update_wave)
	GameManager.game_over.connect(_on_game_over)
	GameManager.victory.connect(_on_victory)
	GameManager.boss_entered.connect(_on_boss_entered)
	GameManager.combo_changed.connect(_on_combo_changed)

	wave_manager.wave_completed.connect(_on_wave_completed)
	ui.next_wave_pressed.connect(_on_next_wave_pressed)
	ui.pause_pressed.connect(_on_pause_pressed)
	ui.settings_pressed.connect(_on_settings_pressed)
	ui.restart_pressed.connect(_on_restart_pressed)
	ui.card_drag_began.connect(_on_card_drag_began)
	ui.card_drag_released.connect(_on_card_drag_released)
	ui.debug_wave_jump_requested.connect(_on_debug_wave_jump)
	ui.debug_clear_enemies_requested.connect(_on_debug_clear_enemies)
	ui.tower_upgrade_requested.connect(_on_tower_upgrade_requested)
	ui.tower_sell_requested.connect(_on_tower_sell_requested)
	ui.battle_supply_pressed.connect(_on_battle_supply_pressed)
	ui.ultimate_cast_requested.connect(_on_ultimate_cast_requested)
	ui.character_skill_cast_requested.connect(_on_character_skill_cast_requested)
	ui.result_next_pressed.connect(_on_result_next_pressed)
	ui.result_retry_pressed.connect(_on_result_retry_pressed)
	ui.result_menu_pressed.connect(_on_result_menu_pressed)
	ui.result_wheel_pressed.connect(_on_result_wheel_pressed)
	ui.exit_pressed.connect(_on_exit_pressed)
	build_manager.tower_built.connect(_on_tower_built)
	build_manager.drag_finished.connect(_on_drag_finished)
	tower_manager.tower_created.connect(_on_tower_created)

	ui.set_stage_name(stage_data.display_name)
	ui.setup_character_bar(_available_characters)
	_load_battle_supplies()

	ui.update_gold(GameManager.gold)
	ui.update_lives(GameManager.lives)
	ui.update_wave(GameManager.current_wave, GameManager.total_waves)
	ui.show_status("按住顶部武将卡片拖到空地建造：松手放置 · 右键 / ESC 取消", 4.0)

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
	grid_background.configure(road_cells, stage_data.decor_cells, entry_cell, base_cell, stage_data.theme, stage_data.forbidden_cells, stage_data.decor_types)
	build_manager.setup_free_build(road_cells, stage_data.forbidden_cells)

	spawn_marker.position = _first_in_map_point(stage_data.path_points, true)
	base_marker.position = _first_in_map_point(stage_data.path_points, false)


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


## 拖拽建造（v0.33.3）：武将卡片按下 → 本方法 → BuildManager.begin_drag。
func _on_card_drag_began(character_id: String) -> void:
	for character_data in _available_characters:
		if str(character_data.character_id) == character_id:
			if not build_manager.begin_drag(character_data):
				ui.clear_card_hold()
			return


## 拖拽建造：卡片松手 → BuildManager.release_drag（可建即直建，其余取消）。
func _on_card_drag_released(_character_id: String) -> void:
	build_manager.release_drag()


## 拖拽结束（放置或取消）→ UI 复位卡片按下的金色高亮。
func _on_drag_finished(_placed: bool) -> void:
	ui.clear_card_hold()


func _on_tower_built(character_id: String) -> void:
	if battle_session == null or character_id.is_empty():
		return
	if not battle_session.deployed_character_ids.has(character_id):
		battle_session.deployed_character_ids.append(character_id)


func _on_tower_created(tower: Tower) -> void:
	tower.selection_changed.connect(_on_tower_selection_changed)
	tower.set_float_text_layer(self)
	SfxLibrary.play(&"build", -10.0)


func _on_tower_selection_changed(tower: Tower) -> void:
	if tower.is_selected:
		# 选中已建塔时取消拖拽（互斥，拖拽中理论上被覆盖层拦截）
		build_manager.cancel_drag()
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
		ui.show_status("升阶成功")
		ui.show_tower_panel(_selected_tower, stage_data)
		SfxLibrary.play(&"build", -12.0)
	elif _selected_tower.battle_rank >= stage_data.max_inbattle_upgrade_level:
		ui.show_status("已达到本关升阶上限")
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


## 角色技能（阶段 8·提交 6）：属性面板"释放技能"按钮（手动模式）。
func _on_character_skill_cast_requested() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	if _selected_tower.cast_character_skill():
		ui.show_status("%s 释放 %s！" % [_selected_tower.display_name, SkillRegistry.get_character_skill_name(_selected_tower.get_character_skill_id())], 1.0)
		ui.refresh_tower_panel()
	else:
		ui.show_status("技能未就绪或范围内无目标")


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
	# 波次完成奖励（阶段 8 提交 2）：部分关卡启用 completion_currency（每波 10~20 金）。
	var completed_index := GameManager.current_wave
	if completed_index >= 0 and completed_index < wave_manager.waves.size():
		var completed_wave: WaveData = wave_manager.waves[completed_index]
		if completed_wave != null and completed_wave.completion_currency > 0:
			# 后勤科技（阶段 8 提交 3）：波次奖励 +20/40%。
			var tech_bonuses := TechTree.get_tech_bonuses(ProfileStore.get_profile())
			var wave_bonus := 1.0 + float(tech_bonuses.get("wave_reward_pct", 0)) / 100.0
			var reward := maxi(ceili(completed_wave.completion_currency * wave_bonus), 1)
			GameManager.gold += reward
			ui.show_status(
				"第 %d 波完成：+%d 金币" % [completed_index + 1, reward],
				1.2
			)
	GameManager.wave_completed()
	if GameFlow.is_gameplay_flag_enabled("auto_next_wave"):
		_try_start_wave()


## 击杀连击奖励（P1 4.1 拍板）：5/10/15 连击全队攻速 +5%/+10%/+15%（3s，上限 +15%）。
func _on_combo_changed(count: int, tier: int) -> void:
	if tier <= 0:
		return
	var speed_bonus := 0.05 * tier
	for node in get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var tower := node as Tower
		if tower != null and is_instance_valid(tower):
			tower.apply_attack_speed_buff("combo", 1.0 + speed_bonus, 3.0)
	ui.show_status(
		"%d 连击！全队攻速 +%d%%（3s）" % [count, int(speed_bonus * 100)],
		1.2
	)


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
	build_manager.cancel_drag()
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
	# v0.21.1 修复：先收集奖励再 mark_victory，与一键通关（MapPanel）顺序统一，
	# 避免胜利状态后 is_in_progress() 守卫拦截首通解锁/掉落写入。
	if battle_session != null:
		var profile := ProfileStore.get_profile()
		var first_clear := not profile.stage_progress.has(stage_data.stage_id)
		GameFlow.collect_stage_rewards(battle_session, stage_data, first_clear)
		GameFlow.award_tech_points(battle_session, first_clear)
		battle_session.add_participation_xp(
			battle_session.get_deployed_character_ids(),
			stage_data.participant_xp
		)
		if battle_session.mark_victory({
			"remaining_lives": GameManager.lives,
			"completed_waves": GameManager.current_wave,
			"difficulty": Difficulty.key_name(GameFlow.selected_difficulty),
		}):
			saved = ProfileStore.commit_victory(battle_session)
			xp_by_character = battle_session.get_pending_xp_by_character()
			loot = battle_session.get_pending_loot()
			unlock_names = _resolve_character_names(battle_session.get_pending_unlocks())
	build_manager.cancel_drag()
	ui.show_result({
		"victory": true,
		"xp_by_character": xp_by_character,
		"loot": loot,
		"unlock_names": unlock_names,
		"saved": saved,
		"next_stage_name": _next_stage_display_name(),
		"remaining_gold": GameManager.gold,
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


## 结算转盘（阶段 8 提交 2）：胜利结算页抽 1 次（≥150 金），结果直接入档。
func _on_result_wheel_pressed() -> void:
	var result := SettlementWheel.roll(ProfileStore.get_profile())
	if result.is_empty():
		ui.show_result_wheel_result("转盘暂无可抽奖励")
		return
	if not ProfileStore.commit_settlement_reward(result):
		ui.show_result_wheel_result("转盘入账失败，请重试")
		return
	SfxLibrary.play(&"skill", -6.0)
	ui.show_result_wheel_result("转盘奖励：%s" % _format_settlement_reward(result))


func _format_settlement_reward(result: Dictionary) -> String:
	match str(result.get("kind", "")):
		"item":
			return "%s ×%d" % [
				GameFlow.get_item_display_name(str(result.get("item_id", ""))),
				int(result.get("amount", 0)),
			]
		"shards":
			var character := GameFlow.load_character_data(str(result.get("character_id", "")))
			return "%s 碎片 ×%d" % [
				character.display_name if character != null else "武将",
				int(result.get("amount", 0)),
			]
		"tech_points":
			return "科技点 ×%d" % int(result.get("amount", 0))
		_:
			return "未知奖励"


## 顶栏退出（GDD v0.9.3）：本局尚未出结果时弹确认——中途退出收益作废
## （核心规则），会话由 _exit_tree 的弃置逻辑兜底清理。
func _on_exit_pressed() -> void:
	build_manager.cancel_drag()
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
	build_manager.cancel_drag()
	GameFlow.clear_squad_relics()
	GameFlow.goto_hub()
	dialog.queue_free()


## First clear grants unlocks and first-clear rewards; replays only grant the
## repeat rewards configured on the stage. 奖励数量按难度材料倍率缩放（GDD 10.7）。
## 战斗内设置（v0.19.2）：暂停并弹出设置面板（复用 SettingsPanel，改动即时生效并持久化）。
func _on_settings_pressed() -> void:
	if _settings_popup != null and is_instance_valid(_settings_popup):
		return
	build_manager.cancel_drag()
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
	build_manager.cancel_drag()
	get_tree().paused = not get_tree().paused
	if get_tree().paused:
		ui.show_status("游戏已暂停")
	else:
		ui.show_status("游戏继续")

func _on_restart_pressed():
	build_manager.cancel_drag()
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


## ============ 局内军需（阶段 8 提交 1，NUMBERS.md 10.9） ============

## 加载军需道具：目录扫描 .tres（PCK 兼容），按费用升序固定展示顺序。
func _load_battle_supplies() -> void:
	_battle_supplies.clear()
	_supply_uses_left.clear()
	for entry in ResourceLoader.list_directory(BATTLE_SUPPLY_DIR):
		if not entry.ends_with(".tres"):
			continue
		var supply := load(BATTLE_SUPPLY_DIR + "/" + entry) as BattleSupplyData
		if supply == null or not supply.is_valid():
			push_warning("军需资源无效：%s" % entry)
			continue
		_battle_supplies.append(supply)
		_supply_uses_left[str(supply.supply_id)] = supply.max_uses
	_battle_supplies.sort_custom(func(a: BattleSupplyData, b: BattleSupplyData) -> bool:
		return a.cost < b.cost)


func _find_battle_supply(supply_id: String) -> BattleSupplyData:
	for supply in _battle_supplies:
		if str(supply.supply_id) == supply_id:
			return supply
	return null


## 金币变化时刷新军需面板置灰状态（波次中金币增长即时生效）。
func _on_gold_changed(_new_amount: int) -> void:
	if _battle_supply_popup != null and is_instance_valid(_battle_supply_popup):
		_refresh_battle_supply_popup()


## 打开军需弹窗（不暂停：波次中可战术性购买）。
func _on_battle_supply_pressed() -> void:
	if _battle_supply_popup != null and is_instance_valid(_battle_supply_popup):
		return
	_supply_buttons.clear()
	var popup := CanvasLayer.new()
	popup.layer = 50
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(popup)
	_battle_supply_popup = popup
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(center)
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.075, 0.12, 0.97)
	panel_style.border_color = Color(0.25, 0.43, 0.68, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "军需"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.93, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for supply in _battle_supplies:
		var button := Button.new()
		button.custom_minimum_size = Vector2(400, 58)
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_on_battle_supply_buy.bind(str(supply.supply_id)))
		box.add_child(button)
		_supply_buttons[str(supply.supply_id)] = button
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(400, 44)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.pressed.connect(_close_battle_supply_popup)
	box.add_child(close_button)
	_refresh_battle_supply_popup()


func _refresh_battle_supply_popup() -> void:
	if _battle_supply_popup == null or not is_instance_valid(_battle_supply_popup):
		return
	for supply in _battle_supplies:
		var key := str(supply.supply_id)
		var button := _supply_buttons.get(key) as Button
		if button == null or not is_instance_valid(button):
			continue
		var uses_left := int(_supply_uses_left.get(key, 0))
		# 将略科技折扣（阶段 8 提交 3）：按钮展示实际支付价。
		var tech_bonuses := TechTree.get_tech_bonuses(ProfileStore.get_profile())
		var discount := float(tech_bonuses.get("supply_discount_pct", 0)) / 100.0
		var paid := maxi(ceili(supply.cost * (1.0 - discount)), 1)
		button.text = "%s —— %s\n%d 金币 · 剩余 %d" % [
			supply.display_name, supply.description, paid, uses_left
		]
		button.disabled = uses_left <= 0 or GameManager.gold < paid


func _close_battle_supply_popup() -> void:
	if _battle_supply_popup != null and is_instance_valid(_battle_supply_popup):
		_battle_supply_popup.queue_free()
	_battle_supply_popup = null
	_supply_buttons.clear()


func _on_battle_supply_buy(supply_id: String) -> void:
	var supply := _find_battle_supply(supply_id)
	if supply == null:
		return
	var uses_left := int(_supply_uses_left.get(supply_id, 0))
	if uses_left <= 0:
		ui.show_status("该军需已用尽")
		return
	if GameManager.gold < supply.cost:
		ui.show_status("金币不足")
		return
	# 将略科技（阶段 8 提交 3）：军需折扣。
	var tech_bonuses := TechTree.get_tech_bonuses(ProfileStore.get_profile())
	var discount := float(tech_bonuses.get("supply_discount_pct", 0)) / 100.0
	var paid := maxi(ceili(supply.cost * (1.0 - discount)), 1)
	GameManager.gold -= paid
	_supply_uses_left[supply_id] = uses_left - 1
	_apply_battle_supply(supply)
	_refresh_battle_supply_popup()
	SfxLibrary.play(&"skill", -8.0)


## 军需效果应用（NUMBERS.md 10.9）：修整/火攻/擂鼓/缓兵。
func _apply_battle_supply(supply: BattleSupplyData) -> void:
	if supply.heal_amount > 0:
		GameManager.lives += supply.heal_amount
		ui.show_status("%s：基地生命 +%d" % [supply.display_name, supply.heal_amount])
	if supply.instant_damage > 0 or supply.burn_dps > 0:
		var count := 0
		for enemy in enemy_manager.get_alive_enemies():
			if supply.instant_damage > 0:
				enemy.take_damage(supply.instant_damage)
			if supply.burn_dps > 0:
				enemy.apply_burn(supply.burn_dps, supply.effect_duration)
			count += 1
		ui.show_status("%s：命中 %d 名敌人" % [supply.display_name, count])
	if supply.attack_speed_bonus > 0.0:
		for node in get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
			var tower := node as Tower
			if tower != null and is_instance_valid(tower):
				tower.apply_attack_speed_buff(str(supply.supply_id), 1.0 + supply.attack_speed_bonus, supply.effect_duration)
		ui.show_status("%s：全队攻速 +%d%%（%ds）" % [supply.display_name, int(supply.attack_speed_bonus * 100), int(supply.effect_duration)])
	if supply.slow_factor < 1.0:
		var count := 0
		for enemy in enemy_manager.get_alive_enemies():
			enemy.apply_slow(supply.slow_factor, supply.effect_duration)
			count += 1
		ui.show_status("%s：全场减速 %d%%（%ds，%d 名敌人）" % [supply.display_name, int((1.0 - supply.slow_factor) * 100), int(supply.effect_duration), count])
