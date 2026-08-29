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

	GameManager.reset(
		stage_data.starting_currency,
		stage_data.starting_lives,
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

	wave_manager.wave_completed.connect(_on_wave_completed)
	ui.next_wave_pressed.connect(_on_next_wave_pressed)
	ui.pause_pressed.connect(_on_pause_pressed)
	ui.restart_pressed.connect(_on_restart_pressed)
	ui.character_selected.connect(_on_character_selected)
	ui.debug_wave_jump_requested.connect(_on_debug_wave_jump)
	ui.debug_clear_enemies_requested.connect(_on_debug_clear_enemies)
	ui.tower_upgrade_requested.connect(_on_tower_upgrade_requested)
	ui.tower_sell_requested.connect(_on_tower_sell_requested)
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
	for index in range(stage_data.build_slot_positions.size()):
		var slot := BUILD_SLOT_SCENE.instantiate() as BuildSlot
		slot.slot_id = index + 1
		build_slots_container.add_child(slot)
		slot.position = stage_data.build_slot_positions[index]


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


func _disconnect_game_signals() -> void:
	var callbacks := [
		[GameManager.gold_changed, Callable(ui, "update_gold")],
		[GameManager.lives_changed, Callable(ui, "update_lives")],
		[GameManager.wave_changed, Callable(ui, "update_wave")],
		[GameManager.game_over, Callable(self, "_on_game_over")],
		[GameManager.victory, Callable(self, "_on_victory")],
	]
	for pair in callbacks:
		var signal_ref: Signal = pair[0]
		var callback: Callable = pair[1]
		if signal_ref.is_connected(callback):
			signal_ref.disconnect(callback)

func _on_next_wave_pressed():
	if not GameManager.is_wave_active and GameManager.current_wave < GameManager.total_waves:
		ui.hide_message()
		wave_manager.start_wave(GameManager.current_wave)
		ui.update_wave(GameManager.current_wave, GameManager.total_waves)

func _on_wave_completed():
	GameManager.wave_completed()


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
	build_manager.cancel_pending()
	if battle_session != null:
		ProfileStore.finish_defeat(battle_session, {
			"remaining_lives": GameManager.lives,
			"completed_waves": GameManager.current_wave,
		})
	ui.show_result({"victory": false})
	get_tree().paused = true

func _on_victory():
	var saved := false
	var xp_by_character: Dictionary = {}
	var loot: Dictionary = {}
	var unlock_names: Array[String] = []
	if battle_session != null and battle_session.mark_victory({
		"remaining_lives": GameManager.lives,
		"completed_waves": GameManager.current_wave,
	}):
		_collect_stage_rewards()
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
	GameFlow.goto_battle()


func _on_result_retry_pressed() -> void:
	GameFlow.select_stage(stage_data.stage_id)
	GameFlow.goto_battle()


func _on_result_menu_pressed() -> void:
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
		dialog.cancelled.connect(dialog.queue_free)
		dialog.close_requested.connect(dialog.queue_free)
		get_tree().root.add_child(dialog)
		dialog.popup_centered()
	else:
		GameFlow.goto_hub()


func _on_exit_confirmed(dialog: ConfirmationDialog) -> void:
	GameFlow.goto_hub()
	dialog.queue_free()


## First clear grants unlocks and first-clear rewards; replays only grant the
## repeat rewards configured on the stage.
func _collect_stage_rewards() -> void:
	var profile := ProfileStore.get_profile()
	var first_clear := not profile.stage_progress.has(stage_data.stage_id)
	var rewards: Array = []
	if first_clear:
		for character_id in stage_data.first_clear_unlock_character_ids:
			battle_session.add_unlock(str(character_id))
		rewards = stage_data.first_clear_rewards
		# Boss 首掉信物（GDD 4.8）
		if stage_data.first_clear_relic != null:
			battle_session.add_relic(str(stage_data.first_clear_relic.relic_id))
	else:
		rewards = stage_data.repeat_clear_rewards
		# 概率掉落（v0.13）：逐条掷点
		for drop in stage_data.probability_drops:
			if drop == null or drop.item == null or drop.amount <= 0:
				continue
			if randf() <= drop.chance:
				battle_session.add_loot(str(drop.item.item_id), drop.amount)
	for reward in rewards:
		if reward == null or reward.item == null or reward.amount <= 0:
			continue
		battle_session.add_loot(str(reward.item.item_id), reward.amount)

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
