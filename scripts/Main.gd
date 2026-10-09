extends Node2D

const DEFAULT_STAGE_ID: StringName = &"ch01_s01"
## 局内军需（✅ 0.8.16 重构）：目录内 .tres 即道具配置（BattleSupplyData，多级承载 L1~L3）。
## 军需目录（BattleSupplyData.DIRECTORY）——局内面板与大厅「军需处」共用。
const BATTLE_SUPPLY_DIR := BattleSupplyData.DIRECTORY
## 局内军需面板版式（UI_LAYOUT §10）：908px 面板 = 左 476 卡列表 + 右 372 详情卡；遮罩自顶栏下缘起。
const SUPPLY_PANEL_WIDTH := 908.0
const SUPPLY_LIST_WIDTH := 476.0
const SUPPLY_DETAIL_WIDTH := 372.0
const SUPPLY_MASK_TOP := 80.0
## 战场光标层高度（B-079）：HUD（UI 默认 layer 1）之下——HUD 控件悬停优先，战场空地由本层接管。
const FIELD_CURSOR_LAYER: int = 0

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
## 局内军需状态（✅ 0.8.16）：道具目录 + 局外选带 + 局内购买态（均为本局临时状态）。
var _battle_supplies: Array[BattleSupplyData] = []
var _supply_by_id: Dictionary = {}
## 局外选带（`supply_loadout_ids`，槽位 = 2 + 科技「军府调度」1）：局内列表与带位区的来源。
var _supply_belt: Array[String] = []
## 已购军需 → 剩余次数（购买入带后才有键；未使用结算作废、不返还）。
var _supply_purchased: Dictionary = {}
var _battle_supply_popup: CanvasLayer = null
var _supply_card_nodes: Dictionary = {}
var _supply_slot_nodes: Array[Control] = []
var _supply_detail_nodes: Dictionary = {}
var _supply_selected_id: String = ""
## 点击卡片 = 固定选中（悬停预览不再覆盖详情）。
var _supply_pinned: bool = false
var _supply_gold_label: Label = null
## 隐匿漏怪提示（✅ 0.8.13.1）：每局最多提示一次，引导补破隐来源。
var _stealth_hint_shown: bool = false

func _ready():
	get_tree().paused = false
	ui.hide_result()
	stage_data = _resolve_stage_data()
	if stage_data == null:
		push_error("关卡数据加载失败")
		return

	_apply_stage_layout()
	_setup_field_cursor()
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
	GameManager.enemy_leaked.connect(_on_enemy_leaked)

	wave_manager.wave_completed.connect(_on_wave_completed)
	ui.next_wave_pressed.connect(_on_next_wave_pressed)
	ui.pause_pressed.connect(_on_pause_pressed)
	ui.settings_pressed.connect(_on_settings_pressed)
	ui.restart_pressed.connect(_on_restart_pressed)
	ui.card_drag_began.connect(_on_card_drag_began)
	ui.card_drag_released.connect(_on_card_drag_released)
	ui.card_drag_cancelled.connect(_on_card_drag_cancelled)
	ui.debug_wave_jump_requested.connect(_on_debug_wave_jump)
	ui.debug_clear_enemies_requested.connect(_on_debug_clear_enemies)
	ui.tower_upgrade_requested.connect(_on_tower_upgrade_requested)
	ui.tower_sell_requested.connect(_on_tower_sell_requested)
	ui.battle_supply_pressed.connect(_on_battle_supply_pressed)
	ui.ultimate_cast_requested.connect(_on_ultimate_cast_requested)
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


## 光标视觉系统（UI_LAYOUT §15，程序 0.8.12.0）：战场画布区准星光标（cross_large）。
## PASS 透传点击（塔选取走 Area2D 物理拾取）；HUD 在更高 CanvasLayer、建造拖拽覆盖层
## 为 STOP，各自接管自己的悬停区。
## 注（B-079）：铺满依赖 CanvasLayer / Control 父级——直挂 Node2D 时锚点不生效（size 恒 0、
## 永不 hover，准星光标从未出现），故本层自带 CanvasLayer（层号 < HUD）。
func _setup_field_cursor() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FieldCursorLayer"
	layer.layer = FIELD_CURSOR_LAYER
	add_child(layer)
	var field := Control.new()
	field.name = "FieldCursor"
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_PASS
	field.mouse_default_cursor_shape = Control.CURSOR_CROSS
	layer.add_child(field)


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


## 拖拽中右键取消（卡片按键路径，B-078）→ 取消拖拽，不建造不扣费。
func _on_card_drag_cancelled() -> void:
	build_manager.cancel_drag()


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
	tower.quick_cast_requested.connect(_on_tower_quick_cast_requested)
	tower.set_float_text_layer(self)
	SfxLibrary.play(&"build", -10.0)


## 就绪胶囊快放（v0.37.14 / UI_LAYOUT v0.20.33，入口 3）：点胶囊直发该塔大招——
## 不改变选中态；选中态下面板按钮 / R 键路径不变。
func _on_tower_quick_cast_requested(tower: Tower) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	if tower.cast_ultimate_manual():
		ui.show_status("%s 释放大招！" % tower.display_name, 1.0)
		if tower == _selected_tower:
			ui.show_tower_panel(tower, stage_data)
	else:
		ui.show_status("%s：范围内暂无目标" % tower.display_name)


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


## 漏怪提示（✅ 0.8.13.1）：隐匿单位突破防线时引导玩家补破隐来源（黄忠固有 /
## 借东风全图 / 舞娘 3 阶光环），或改用范围盲压；每局一次。
func _on_enemy_leaked(_damage: int) -> void:
	if _stealth_hint_shown or not GameManager.last_leak_was_stealth:
		return
	_stealth_hint_shown = true
	ui.show_status("隐匿单位突破防线：黄忠（固有）/ 借东风 / 舞娘 3 阶可破隐，或改用范围盲压", 3.5)


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
		[GameManager.enemy_leaked, Callable(self, "_on_enemy_leaked")],
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
		# 经验池注入定值（✅ 0.8.15 / NUMBERS 10.14）：纯增量、不扣武将所得，随战局提交写档。
		battle_session.finalize_exp_pool_injection(stage_data.participant_xp)
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
		"tech_points":
			return "科技点 ×%d" % int(result.get("amount", 0))
		_:
			return "未知奖励"


## 顶栏退出（GDD v0.9.3；v0.37.32 换 Kenney 亮色二次确认弹窗）：本局尚未出结果时弹确认
## ——中途退出收益作废（核心规则），会话由 _exit_tree 的弃置逻辑兜底清理。
func _on_exit_pressed() -> void:
	build_manager.cancel_drag()
	if battle_session != null and battle_session.is_in_progress():
		BattleConfirmDialog.open(self, "确认退出本关？",
			"退出将放弃本局未结算的收益与进度，且不会被写入存档。",
			"放弃并退出", _on_exit_confirmed, "继续战斗", "red")
	else:
		GameFlow.goto_hub()


func _on_exit_confirmed() -> void:
	build_manager.cancel_drag()
	GameFlow.clear_squad_relics()
	GameFlow.goto_hub()


## First clear grants unlocks and first-clear rewards; replays only grant the
## repeat rewards configured on the stage. 奖励数量按难度材料倍率缩放（GDD 10.7）。
## 战斗内设置（v0.19.2；v0.37.8 弹窗亮色化 B-055）：暂停并弹出设置面板（复用 SettingsPanel，
## 改动即时生效并持久化）。弹窗外框走 Kenney 亮蓝 DIALOG 语言（同 MainMenu「新的征程」确认弹窗）。
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
	dim.color = Color(0.02, 0.05, 0.09, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_popup.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_popup.add_child(center)
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UITheme.DIALOG_PANEL
	panel_style.border_color = UITheme.DIALOG_BORDER
	panel_style.set_border_width_all(3)
	panel_style.border_width_bottom = 7
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.02, 0.1, 0.18, 0.45)
	panel_style.shadow_size = 18
	panel_style.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var settings := preload("res://scripts/ui_screens/panels/SettingsPanel.gd").new()
	box.add_child(settings)
	var close_button := Button.new()
	close_button.text = "关闭设置"
	close_button.custom_minimum_size = Vector2(220, 48)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 18)
	UITheme.apply_kenney_rect_button(close_button, "blue", Color.WHITE)
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

## 顶栏重开（v0.37.32）：先弹 Kenney 亮色二次确认（防误触、与退出确认同语言），
## 确认后弃置本局会话、解除暂停并重载关卡（收益作废规则同退出）。
func _on_restart_pressed() -> void:
	build_manager.cancel_drag()
	BattleConfirmDialog.open(self, "确认重开本关？",
		"重开会放弃本局未结算的收益与进度，并从第一波重新开始本关。",
		"确认重开", _on_restart_confirmed, "继续战斗")


func _on_restart_confirmed() -> void:
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


## ============ 局内军需（✅ 0.8.16 重构：购买入带 → 择时使用；NUMBERS 10.15 / UI_LAYOUT §10） ============

## 加载军需道具：目录扫描 .tres（PCK 兼容），按军需池固定展示顺序排列；
## 同时解析局外选带（只保留「资源存在 + 已解锁」的条目）——局外未选带的已解锁件不进局内列表。
func _load_battle_supplies() -> void:
	_battle_supplies.clear()
	_supply_by_id.clear()
	_supply_purchased.clear()
	_battle_supplies = BattleSupplyData.load_catalog()
	for supply in _battle_supplies:
		_supply_by_id[str(supply.supply_id)] = supply
	_supply_belt = _resolve_supply_belt()
	var list_ids := _supply_list_ids()
	_supply_selected_id = list_ids[0] if not list_ids.is_empty() else ""


func _resolve_supply_belt() -> Array[String]:
	var belt: Array[String] = []
	var profile := ProfileStore.get_profile()
	if profile == null:
		return belt
	for value in profile.get_supply_loadout():
		var key := str(value)
		if _supply_by_id.has(key) and profile.is_supply_unlocked(key) and not belt.has(key):
			belt.append(key)
	return belt


## 局内列表 = 已选带件（可购买 / 可使用）+ 未解锁件（锁定示意）；已解锁但未选带的不出现。
func _supply_list_ids() -> Array[String]:
	var ids: Array[String] = []
	var profile := ProfileStore.get_profile()
	for supply_id in _supply_belt:
		ids.append(supply_id)
	for supply in _battle_supplies:
		var key := str(supply.supply_id)
		if ids.has(key):
			continue
		if profile == null or not profile.is_supply_unlocked(key):
			ids.append(key)
	return ids


## 军需带槽位上限（✅ 0.8.16）：默认 2 + 科技「军府调度」1 → 3。
func _supply_slot_limit() -> int:
	var tech_bonuses := TechTree.get_tech_bonuses(ProfileStore.get_profile())
	return PlayerProfile.BASE_SUPPLY_SLOTS + int(tech_bonuses.get("supply_slot_bonus", 0))


func _find_battle_supply(supply_id: String) -> BattleSupplyData:
	return _supply_by_id.get(supply_id) as BattleSupplyData


## 强化等级（0 = 未解锁）。
func _supply_level(supply_id: String) -> int:
	var profile := ProfileStore.get_profile()
	if profile == null:
		return 0
	return profile.get_supply_level(supply_id)


func _supply_paid_cost(supply: BattleSupplyData) -> int:
	var level := maxi(_supply_level(str(supply.supply_id)), 1)
	# 将略科技（阶段 8 提交 3）：军需折扣——支付 = 强化后费用 ×（1 − supply_discount_pct）向上取整。
	var tech_bonuses := TechTree.get_tech_bonuses(ProfileStore.get_profile())
	var discount := float(tech_bonuses.get("supply_discount_pct", 0)) / 100.0
	return maxi(ceili(supply.cost_at(level) * (1.0 - discount)), 1)


func _supply_uses_left(supply_id: String) -> int:
	return int(_supply_purchased.get(supply_id, 0))


func _is_supply_purchased(supply_id: String) -> bool:
	return _supply_purchased.has(supply_id)


## 金币变化时刷新军需面板置灰状态（波次中金币增长即时生效）。
func _on_gold_changed(_new_amount: int) -> void:
	if _battle_supply_popup != null and is_instance_valid(_battle_supply_popup):
		_refresh_battle_supply_popup()


## 打开军需弹窗（不暂停：波次中可战术性购买）。遮罩自顶栏下缘起，顶栏按钮行保持可见可点。
func _on_battle_supply_pressed() -> void:
	if _battle_supply_popup != null and is_instance_valid(_battle_supply_popup):
		return
	_supply_card_nodes.clear()
	_supply_slot_nodes.clear()
	_supply_detail_nodes.clear()
	_set_supply_button_highlight(true)
	var popup := CanvasLayer.new()
	popup.layer = 50
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(popup)
	_battle_supply_popup = popup
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.07, 0.12, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_top = SUPPLY_MASK_TOP
	popup.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = SUPPLY_MASK_TOP
	popup.add_child(center)
	center.add_child(_build_supply_panel())
	_refresh_battle_supply_popup()


## 开启态顶栏「军需」按钮金色高亮（UI_LAYOUT §10）。
func _set_supply_button_highlight(active: bool) -> void:
	if ui == null or not is_instance_valid(ui.supply_button):
		return
	if active:
		UITheme.apply_kenney_rect_button(ui.supply_button, "yellow", UITheme.INK, 6.0)
	else:
		UITheme.apply_kenney_rect_button(ui.supply_button, "blue", Color.WHITE, 6.0)


func _build_supply_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "BattleSupplyPanel"
	panel.custom_minimum_size = Vector2(SUPPLY_PANEL_WIDTH, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UITheme.LIGHT_PAGE_BG
	panel_style.border_color = UITheme.DIALOG_BORDER
	panel_style.set_border_width_all(3)
	panel_style.border_width_bottom = 7
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.024, 0.11, 0.196, 0.6)
	panel_style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	box.add_child(_build_supply_title())
	box.add_child(_build_supply_belt_row())
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 20)
	body_margin.add_theme_constant_override("margin_right", 20)
	body_margin.add_theme_constant_override("margin_top", 10)
	body_margin.add_theme_constant_override("margin_bottom", 12)
	box.add_child(body_margin)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body_margin.add_child(body)
	body.add_child(_build_supply_list())
	body.add_child(_build_supply_detail())
	box.add_child(_build_supply_foot())
	return panel


func _build_supply_title() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 54)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = UITheme.DIALOG_HEAD
	bar_style.set_corner_radius_all(15)
	bar.add_theme_stylebox_override("panel", bar_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 14)
	bar.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var title := Label.new()
	title.text = "军需"
	title.add_theme_font_override("font", UITheme.spaced_font(6))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(title)
	var chip := Label.new()
	chip.text = "购买入带 · 择时使用"
	chip.add_theme_font_size_override("font_size", 13)
	chip.add_theme_color_override("font_color", UITheme.MIST)
	chip.add_theme_stylebox_override("normal", UITheme.tag_style(Color(1, 1, 1, 0.2), 13, 4))
	row.add_child(chip)
	_supply_gold_label = Label.new()
	_supply_gold_label.text = "金币 0"
	_supply_gold_label.add_theme_font_size_override("font_size", 19)
	_supply_gold_label.add_theme_color_override("font_color", Color("#b07a00"))
	_supply_gold_label.add_theme_stylebox_override("normal", UITheme.tag_style(Color.WHITE, 14, 3))
	row.add_child(_supply_gold_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var close_button := Button.new()
	close_button.name = "SupplyCloseButton"
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 15)
	close_button.add_theme_color_override("font_color", Color.WHITE)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.3 if state == "normal" else 0.45)
		style.set_corner_radius_all(15)
		close_button.add_theme_stylebox_override(state, style)
	close_button.pressed.connect(_close_battle_supply_popup)
	row.add_child(close_button)
	return bar


## 带位区（标题下方单行）：军需带小标 + 槽位圆卡 ≤3——空槽 = 虚线圆「空」、
## 未购买 = 灰字、已购 = ✓ + 剩余次数（点击即使用）、用尽 = 灰显。
func _build_supply_belt_row() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 9)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var label := Label.new()
	label.text = "军需带"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	row.add_child(label)
	var limit := _supply_slot_limit()
	for index in range(limit):
		var slot := _build_supply_slot(index)
		_supply_slot_nodes.append(slot)
		row.add_child(slot)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var hint := Label.new()
	hint.text = "点击带内条目 = 使用（不弹二次确认）"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
	row.add_child(hint)
	return margin


func _build_supply_slot(index: int) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(152, 58)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = UITheme.LIGHT_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	slot.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	slot.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	var icon := _make_supply_icon(38)
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	info.add_child(name_label)
	var sub_label := Label.new()
	sub_label.add_theme_font_size_override("font_size", 10)
	sub_label.add_theme_color_override("font_color", UITheme.LIGHT_DESC)
	info.add_child(sub_label)
	var count_label := Label.new()
	count_label.add_theme_font_size_override("font_size", 15)
	count_label.add_theme_color_override("font_color", Color("#0e9f58"))
	row.add_child(count_label)
	slot.set_meta("supply_slot", {
		"root": slot, "icon": icon, "icon_text": icon.get_meta("icon_text", null),
		"name": name_label, "sub": sub_label, "count": count_label, "style": style,
	})
	# 点击整槽 = 使用（不弹二次确认）
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_use_supply_from_belt.bind(index))
	slot.add_child(button)
	slot.set_meta("supply_slot_button", button)
	return slot


func _make_supply_icon(diameter: float) -> DashedPill:
	var pill := DashedPill.new()
	pill.custom_minimum_size = Vector2(diameter, diameter)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.setup(Color("#f0f6fb"), Color("#9cbed9"), diameter * 0.5)
	var text := Label.new()
	text.name = "IconText"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", int(diameter * 0.42))
	text.add_theme_color_override("font_color", Color("#7fa3c2"))
	pill.add_child(text)
	pill.set_meta("icon_text", text)
	return pill


func _build_supply_list() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(SUPPLY_LIST_WIDTH, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.name = "SupplyList"
	list.custom_minimum_size = Vector2(SUPPLY_LIST_WIDTH - 6.0, 0)
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for supply_id in _supply_list_ids():
		var card := _build_supply_card(supply_id)
		list.add_child(card)
	return scroll


func _build_supply_card(supply_id: String) -> Control:
	var supply := _find_battle_supply(supply_id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 64)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = UITheme.LIGHT_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(13)
	card.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	margin.add_child(row)
	var icon := _make_supply_icon(44)
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = supply.display_name if supply != null else supply_id
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	info.add_child(name_label)
	var desc_label := Label.new()
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", UITheme.LIGHT_DESC)
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(desc_label)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 3)
	row.add_child(right)
	var cost_label := Label.new()
	cost_label.add_theme_font_size_override("font_size", 15)
	cost_label.add_theme_color_override("font_color", UITheme.LIGHT_GOLD_TEXT)
	cost_label.add_theme_stylebox_override("normal", UITheme.tag_style(Color("#fff8e0"), 9, 2))
	right.add_child(cost_label)
	var tag_label := Label.new()
	tag_label.add_theme_font_size_override("font_size", 11)
	right.add_child(tag_label)
	# 悬停 = 即时预览；点击整卡 = 固定选中
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_on_supply_card_hover.bind(supply_id))
	button.pressed.connect(_on_supply_card_pressed.bind(supply_id))
	card.add_child(button)
	_supply_card_nodes[supply_id] = {
		"root": card, "style": style, "icon": icon, "icon_text": icon.get_meta("icon_text", null),
		"name": name_label, "desc": desc_label, "cost": cost_label, "tag": tag_label,
	}
	return card


func _build_supply_detail() -> Control:
	var card := PanelContainer.new()
	card.name = "SupplyDetail"
	card.custom_minimum_size = Vector2(SUPPLY_DETAIL_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = UITheme.LIGHT_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	card.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	# 头部：54px 图标 + 名称 20px + tag 行
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 11)
	box.add_child(head)
	var icon := _make_supply_icon(54)
	head.add_child(icon)
	var head_info := VBoxContainer.new()
	head_info.add_theme_constant_override("separation", 4)
	head.add_child(head_info)
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
	head_info.add_child(name_label)
	var tag_row := HBoxContainer.new()
	tag_row.add_theme_constant_override("separation", 6)
	head_info.add_child(tag_row)
	var tag_a := Label.new()
	tag_a.add_theme_font_size_override("font_size", 11)
	tag_row.add_child(tag_a)
	var tag_b := Label.new()
	tag_b.add_theme_font_size_override("font_size", 11)
	tag_row.add_child(tag_b)
	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(SUPPLY_DETAIL_WIDTH - 34.0, 0)
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	box.add_child(desc)
	# 效果 / 持续 / 剩余 三格
	var fx_row := HBoxContainer.new()
	fx_row.add_theme_constant_override("separation", 8)
	box.add_child(fx_row)
	var keys := ["效果", "持续", "剩余"]
	var fx_values: Array[Label] = []
	var fx_units: Array[Label] = []
	for key in keys:
		var fx_box := PanelContainer.new()
		fx_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fx_style := StyleBoxFlat.new()
		fx_style.bg_color = UITheme.LIGHT_STAT_BG
		fx_style.border_color = Color("#bfdcef")
		fx_style.set_border_width_all(2)
		fx_style.set_corner_radius_all(11)
		fx_box.add_theme_stylebox_override("panel", fx_style)
		var fx_margin := MarginContainer.new()
		fx_margin.add_theme_constant_override("margin_left", 4)
		fx_margin.add_theme_constant_override("margin_right", 4)
		fx_margin.add_theme_constant_override("margin_top", 6)
		fx_margin.add_theme_constant_override("margin_bottom", 7)
		fx_box.add_child(fx_margin)
		var fx_column := VBoxContainer.new()
		fx_column.add_theme_constant_override("separation", 1)
		fx_margin.add_child(fx_column)
		var key_label := Label.new()
		key_label.text = key
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 11)
		key_label.add_theme_color_override("font_color", UITheme.LIGHT_MUTED)
		fx_column.add_child(key_label)
		var value_label := Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.add_theme_color_override("font_color", Color("#14538a"))
		fx_column.add_child(value_label)
		var unit_label := Label.new()
		unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unit_label.add_theme_font_size_override("font_size", 10)
		unit_label.add_theme_color_override("font_color", Color("#a8bccb"))
		fx_column.add_child(unit_label)
		fx_row.add_child(fx_box)
		fx_values.append(value_label)
		fx_units.append(unit_label)
	var rule := Label.new()
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size = Vector2(SUPPLY_DETAIL_WIDTH - 34.0, 0)
	rule.text = "购买不立即生效：先入「军需带」，点击带内条目才触发；同类增益不叠加、只刷新时长；对 Boss 生效但有抗性折减；结算开始后关闭购买。"
	rule.add_theme_font_size_override("font_size", 11)
	rule.add_theme_color_override("font_color", Color("#8a6d00"))
	var rule_style := StyleBoxFlat.new()
	rule_style.bg_color = Color("#fff8e0")
	rule_style.border_color = Color("#ecd9a0")
	rule_style.set_border_width_all(2)
	rule_style.set_corner_radius_all(9)
	rule_style.content_margin_left = 10
	rule_style.content_margin_right = 10
	rule_style.content_margin_top = 5
	rule_style.content_margin_bottom = 5
	rule.add_theme_stylebox_override("normal", rule_style)
	box.add_child(rule)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	box.add_child(action_row)
	var hint := Label.new()
	hint.text = "购买 = 入带（无二次确认）\n未使用结算作废、不返还"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("#a8bccb"))
	action_row.add_child(hint)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(action_spacer)
	var action := Button.new()
	action.name = "SupplyActionButton"
	action.custom_minimum_size = Vector2(190, 46)
	action.focus_mode = Control.FOCUS_NONE
	action.add_theme_font_override("font", UITheme.spaced_font(2))
	action.add_theme_font_size_override("font_size", 17)
	action.pressed.connect(_on_supply_action_pressed)
	action_row.add_child(action)
	_supply_detail_nodes = {
		"icon_text": icon.get_meta("icon_text", null), "name": name_label,
		"tag_a": tag_a, "tag_b": tag_b, "desc": desc,
		"fx0": fx_values[0], "fx1": fx_values[1], "fx2": fx_values[2],
		"fxu0": fx_units[0], "fxu1": fx_units[1], "fxu2": fx_units[2],
		"rule": rule, "button": action,
	}
	return card


func _build_supply_foot() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	var label := Label.new()
	label.text = "购买入带不立即生效 · 未使用结算作废；军需不暂停战斗，结算开始后关闭购买。"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UITheme.LIGHT_BODY)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#eef6fb")
	style.border_color = Color("#bfdcef")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	label.add_theme_stylebox_override("normal", style)
	margin.add_child(label)
	return margin


func _supply_glyph(supply: BattleSupplyData) -> String:
	if supply == null or supply.display_name.is_empty():
		return "?"
	return supply.display_name.substr(0, 1)


## ===== 刷新 =====

func _refresh_battle_supply_popup() -> void:
	if _battle_supply_popup == null or not is_instance_valid(_battle_supply_popup):
		return
	if _supply_gold_label != null and is_instance_valid(_supply_gold_label):
		_supply_gold_label.text = "金币 %d" % GameManager.gold
	_refresh_supply_belt()
	_refresh_supply_cards()
	_render_supply_detail(_supply_selected_id)


func _refresh_supply_belt() -> void:
	for index in range(_supply_slot_nodes.size()):
		var slot := _supply_slot_nodes[index]
		if slot == null or not is_instance_valid(slot):
			continue
		var meta: Dictionary = slot.get_meta("supply_slot", {})
		var button := slot.get_meta("supply_slot_button", null) as Button
		var supply_id := _supply_belt[index] if index < _supply_belt.size() else ""
		var supply := _find_battle_supply(supply_id)
		var icon_text := meta.get("icon_text") as Label
		var name_label := meta.get("name") as Label
		var sub_label := meta.get("sub") as Label
		var count_label := meta.get("count") as Label
		var style := meta.get("style") as StyleBoxFlat
		if supply == null or supply_id.is_empty():
			icon_text.text = ""
			name_label.text = "空"
			name_label.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)
			sub_label.text = ""
			count_label.text = ""
			style.bg_color = Color("#eef6fb")
			style.border_color = Color("#c3d2dd")
			button.disabled = true
			button.tooltip_text = "空槽：在军需处选带后可携带"
			continue
		var level := maxi(_supply_level(supply_id), 1)
		var left := _supply_uses_left(supply_id)
		icon_text.text = _supply_glyph(supply)
		name_label.text = supply.display_name
		if not _is_supply_purchased(supply_id):
			name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
			sub_label.text = "待购买"
			count_label.text = "未购买"
			count_label.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)
			style.bg_color = Color.WHITE
			style.border_color = UITheme.LIGHT_PANEL_BORDER
			button.disabled = true
			button.tooltip_text = "先在右侧详情卡购买入带"
		elif left > 0:
			name_label.add_theme_color_override("font_color", UITheme.LIGHT_INK)
			sub_label.text = "点击使用"
			count_label.text = "✓ %d" % left
			count_label.add_theme_color_override("font_color", Color("#0e9f58"))
			style.bg_color = Color.WHITE
			style.border_color = UITheme.LIGHT_PANEL_BORDER
			button.disabled = false
			button.tooltip_text = "点击使用「%s」（剩余 %d 次）" % [supply.display_name, left]
		else:
			name_label.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)
			sub_label.text = "已用尽"
			count_label.text = "0"
			count_label.add_theme_color_override("font_color", UITheme.LIGHT_LOCK)
			style.bg_color = Color("#eef3f7")
			style.border_color = Color("#d9e3ea")
			button.disabled = true
			button.tooltip_text = "本局次数已用尽"


func _refresh_supply_cards() -> void:
	for supply_id in _supply_card_nodes.keys():
		var nodes: Dictionary = _supply_card_nodes[supply_id]
		var supply := _find_battle_supply(supply_id)
		if supply == null:
			continue
		var level := _supply_level(supply_id)
		var locked := level <= 0
		var display_level := maxi(level, 1)
		var name_label := nodes["name"] as Label
		var desc_label := nodes["desc"] as Label
		var cost_label := nodes["cost"] as Label
		var tag_label := nodes["tag"] as Label
		var style := nodes["style"] as StyleBoxFlat
		var icon_text := nodes["icon_text"] as Label
		var paid := _supply_paid_cost(supply)
		icon_text.text = "锁" if locked else _supply_glyph(supply)
		name_label.text = supply.display_name
		desc_label.text = supply.summary_at(display_level)
		cost_label.text = "%d 金 · 限 %d" % [paid, supply.max_uses_at(display_level)]
		var gray := locked
		if locked:
			tag_label.text = "未解锁"
			_style_supply_tag(tag_label, UITheme.TAG_LOCK_FG, UITheme.TAG_LOCK_BG)
		elif _is_supply_purchased(supply_id):
			var left := _supply_uses_left(supply_id)
			if left > 0:
				tag_label.text = "已购 · 剩余 %d" % left
				_style_supply_tag(tag_label, UITheme.TAG_OK_FG, UITheme.TAG_OK_BG)
			else:
				tag_label.text = "已用尽"
				_style_supply_tag(tag_label, UITheme.TAG_LOCK_FG, UITheme.TAG_LOCK_BG)
				gray = true
		else:
			tag_label.text = "未购买"
			_style_supply_tag(tag_label, Color("#14538a"), UITheme.LIGHT_BLUE_SOFT)
			if GameManager.gold < paid:
				gray = true
		name_label.add_theme_color_override("font_color", UITheme.LIGHT_LOCK if gray else UITheme.LIGHT_INK)
		desc_label.add_theme_color_override("font_color", UITheme.LIGHT_LOCK if gray else UITheme.LIGHT_DESC)
		cost_label.add_theme_color_override("font_color", UITheme.LIGHT_LOCK if gray else UITheme.LIGHT_GOLD_TEXT)
		style.bg_color = Color("#eef3f7") if gray else Color.WHITE
		style.border_color = Color("#d9e3ea") if gray else UITheme.LIGHT_PANEL_BORDER
		if supply_id == _supply_selected_id:
			style.border_color = UITheme.LIGHT_GOLD_SELECT


func _style_supply_tag(label: Label, fg: Color, bg: Color) -> void:
	label.add_theme_color_override("font_color", fg)
	label.add_theme_stylebox_override("normal", UITheme.tag_style(bg, 8, 1))


func _render_supply_detail(supply_id: String) -> void:
	var supply := _find_battle_supply(supply_id)
	if supply == null or _supply_detail_nodes.is_empty():
		return
	var level := maxi(_supply_level(supply_id), 1)
	var locked := _supply_level(supply_id) <= 0
	var icon_text := _supply_detail_nodes.get("icon_text") as Label
	var name_label := _supply_detail_nodes.get("name") as Label
	var tag_a := _supply_detail_nodes.get("tag_a") as Label
	var tag_b := _supply_detail_nodes.get("tag_b") as Label
	var desc := _supply_detail_nodes.get("desc") as Label
	var button := _supply_detail_nodes.get("button") as Button
	if icon_text != null:
		icon_text.text = "锁" if locked else _supply_glyph(supply)
	if name_label != null:
		name_label.text = supply.display_name
	if locked:
		tag_a.text = "未解锁"
		_style_supply_tag(tag_a, UITheme.TAG_LOCK_FG, UITheme.TAG_LOCK_BG)
		tag_b.text = "军需处解锁"
		_style_supply_tag(tag_b, UITheme.LIGHT_GOLD_TEXT, Color("#fff8e0"))
		desc.text = "%s
解锁后可加入军需带并带入局内（军需处 · 军功解锁）。" % supply.description
	else:
		tag_a.text = "L%d" % level
		_style_supply_tag(tag_a, Color("#14538a"), UITheme.LIGHT_BLUE_SOFT)
		if _is_supply_purchased(supply_id):
			tag_b.text = "已入带 · 剩余 %d" % _supply_uses_left(supply_id)
			_style_supply_tag(tag_b, UITheme.TAG_OK_FG, UITheme.TAG_OK_BG)
		elif _supply_is_in_belt(supply_id):
			tag_b.text = "未购买"
			_style_supply_tag(tag_b, UITheme.LIGHT_GOLD_TEXT, Color("#fff8e0"))
		else:
			tag_b.text = "未选带"
			_style_supply_tag(tag_b, UITheme.TAG_LOCK_FG, UITheme.TAG_LOCK_BG)
		desc.text = supply.description
	var fx := _supply_detail_fx(supply, level)
	var fx0 := _supply_detail_nodes.get("fx0") as Label
	var fx1 := _supply_detail_nodes.get("fx1") as Label
	var fx2 := _supply_detail_nodes.get("fx2") as Label
	var fxu0 := _supply_detail_nodes.get("fxu0") as Label
	var fxu1 := _supply_detail_nodes.get("fxu1") as Label
	var fxu2 := _supply_detail_nodes.get("fxu2") as Label
	fx0.text = fx[0]
	fxu0.text = fx[1]
	fx1.text = fx[2]
	fxu1.text = fx[3]
	var max_uses := supply.max_uses_at(level)
	if _is_supply_purchased(supply_id):
		fx2.text = "%d / %d" % [_supply_uses_left(supply_id), max_uses]
		fxu2.text = "本局剩余次数"
	else:
		fx2.text = "— / %d" % max_uses
		fxu2.text = "本局可用次数"
	_refresh_supply_action_button()


## 效果 / 持续 / 剩余 三格文案（按军需类型与等级派生）。
func _supply_detail_fx(supply: BattleSupplyData, level: int) -> Array:
	var duration := supply.duration_at(level)
	if supply.heal_at(level) > 0:
		return ["生命 +%d" % supply.heal_at(level), "基地生命", "立即", "使用即生效"]
	if supply.instant_physical_at(level) > 0:
		return ["%d 物理" % supply.instant_physical_at(level), "全场敌军", "立即", "按护甲结算"]
	if supply.rage_gain_at(level) > 0:
		return ["怒气 +%d" % supply.rage_gain_at(level), "全队武将", "立即", "直接加怒"]
	if supply.burn_dps_at(level) > 0:
		return [
			"%d 魔法" % supply.instant_magic_at(level), "全场敌军",
			"灼烧 %.0f 秒" % duration, "%d / 秒" % supply.burn_dps_at(level),
		]
	if supply.attack_speed_bonus_at(level) > 0.0:
		return [
			"攻速 +%d%%" % roundi(supply.attack_speed_bonus_at(level) * 100.0), "全队武将",
			"%.0f 秒" % duration, "同类只刷新",
		]
	if supply.slow_factor_at(level) < 1.0:
		return [
			"减速 %d%%" % roundi((1.0 - supply.slow_factor_at(level)) * 100.0), "全场敌军",
			"%.0f 秒" % duration, "对 Boss 折减",
		]
	return ["—", "—", "—", "—"]


## 修整类（回复基地生命）在满生命时禁用（NUMBERS 10.15 边界规则「满血禁修整」；
## 上限 = 关卡起始生命 + 科技 / 遗物加成，与 UI.gd 生命占比同源）。
func _is_supply_heal_blocked(supply: BattleSupplyData) -> bool:
	return supply != null and supply.heal_at(1) > 0 and GameManager.lives >= GameManager.starting_lives


func _refresh_supply_action_button() -> void:
	var supply := _find_battle_supply(_supply_selected_id)
	var button := _supply_detail_nodes.get("button") as Button
	if supply == null or button == null or not is_instance_valid(button):
		return
	var settlement_started: bool = ui != null and ui.is_game_finished()
	if _supply_level(_supply_selected_id) <= 0:
		button.text = "未解锁"
		_set_supply_action_state(button, "grey", false)
		return
	if settlement_started:
		button.text = "结算中"
		_set_supply_action_state(button, "grey", false)
		return
	if _is_supply_purchased(_supply_selected_id):
		if _is_supply_heal_blocked(supply):
			button.text = "生命已满"
			_set_supply_action_state(button, "grey", false)
			return
		if _supply_uses_left(_supply_selected_id) <= 0:
			button.text = "已用尽"
			_set_supply_action_state(button, "grey", false)
		else:
			button.text = "使用"
			_set_supply_action_state(button, "yellow", true)
		return
	var paid := _supply_paid_cost(supply)
	button.text = "购买 %d 金币" % paid
	var affordable := GameManager.gold >= paid and _supply_is_in_belt(_supply_selected_id)
	_set_supply_action_state(button, "yellow" if affordable else "grey", affordable)


func _set_supply_action_state(button: Button, color_key: String, enabled: bool) -> void:
	var font_color := UITheme.INK if color_key == "yellow" else Color("#7d8fa0")
	UITheme.apply_kenney_rect_button(button, color_key, font_color, 10.0)
	button.disabled = not enabled


## ===== 交互 =====

func _supply_is_in_belt(supply_id: String) -> bool:
	return _supply_belt.has(supply_id)


## 悬停卡片 = 右侧即时预览（已固定选中则不再跟随）。
func _on_supply_card_hover(supply_id: String) -> void:
	if _supply_pinned:
		return
	_supply_selected_id = supply_id
	_render_supply_detail(supply_id)
	_refresh_supply_cards()


## 点击卡片 = 金框固定选中（悬停移开不丢）。
func _on_supply_card_pressed(supply_id: String) -> void:
	_supply_pinned = true
	_supply_selected_id = supply_id
	_render_supply_detail(supply_id)
	_refresh_supply_cards()


## 详情卡按钮：未购 = 购买入带；已购 = 使用；未解锁 / 用尽 / 结算中 = 只读。
func _on_supply_action_pressed() -> void:
	var supply := _find_battle_supply(_supply_selected_id)
	if supply == null:
		return
	if _supply_level(_supply_selected_id) <= 0 or (ui != null and ui.is_game_finished()):
		return
	if _is_supply_purchased(_supply_selected_id):
		_use_battle_supply(_supply_selected_id)
		return
	_buy_battle_supply(supply)


## 购买入带（✅ 0.8.16 / NUMBERS 10.15）：支付 = 强化后费用 ×（1 − 科技 supply_discount_pct）
## 向上取整；**不立即生效**、无二次确认；次数 = 强化后限次；未使用结算作废、不返还。
func _buy_battle_supply(supply: BattleSupplyData) -> void:
	var supply_id := str(supply.supply_id)
	if not _supply_is_in_belt(supply_id):
		ui.show_status("该军需未随军需带出征，请先在军需处选带")
		return
	if _is_supply_purchased(supply_id):
		return
	var paid := _supply_paid_cost(supply)
	if GameManager.gold < paid:
		ui.show_status("金币不足")
		return
	GameManager.gold -= paid
	var level := maxi(_supply_level(supply_id), 1)
	var uses := supply.max_uses_at(level)
	_supply_purchased[supply_id] = uses
	ui.show_status("%s：已入军需带（%d 金币 · 可用 %d 次）" % [supply.display_name, paid, uses])
	_refresh_battle_supply_popup()
	SfxLibrary.play(&"skill", -8.0)


## 使用（不弹二次确认）：点击带内条目或详情卡「使用」按钮。
func _use_supply_from_belt(index: int) -> void:
	if index < 0 or index >= _supply_belt.size():
		return
	_use_battle_supply(_supply_belt[index])


func _use_battle_supply(supply_id: String) -> void:
	var supply := _find_battle_supply(supply_id)
	if supply == null or not _is_supply_purchased(supply_id):
		return
	var left := _supply_uses_left(supply_id)
	if left <= 0:
		ui.show_status("该军需本局次数已用尽")
		return
	if ui != null and ui.is_game_finished():
		ui.show_status("结算已开始，无法使用军需")
		return
	if _is_supply_heal_blocked(supply):
		ui.show_status("基地生命已满，无需修整")
		return
	_supply_purchased[supply_id] = left - 1
	_apply_battle_supply(supply, maxi(_supply_level(supply_id), 1))
	_refresh_battle_supply_popup()
	SfxLibrary.play(&"skill", -8.0)


## 军需效果应用（NUMBERS 10.15，按强化等级取值）：修整 / 火攻 / 擂鼓 / 缓兵 / 掷石齐射 / 犒军。
func _apply_battle_supply(supply: BattleSupplyData, level: int) -> void:
	var supply_name := supply.display_name
	var heal := supply.heal_at(level)
	if heal > 0:
		GameManager.lives += heal
		ui.show_status("%s：基地生命 +%d" % [supply_name, heal])
	var magic := supply.instant_magic_at(level)
	var burn := supply.burn_dps_at(level)
	if magic > 0 or burn > 0:
		var burned := 0
		for enemy in enemy_manager.get_alive_enemies():
			if magic > 0:
				enemy.take_damage(magic, "", DamageTypes.MAGIC)
			if burn > 0:
				enemy.apply_burn(burn, supply.duration_at(level))
			burned += 1
		ui.show_status("%s：命中 %d 名敌人" % [supply_name, burned])
	# 掷石齐射（✅ 0.8.16 新军需 / STATS_PIPELINE v0.7）：军需独立来源物理直伤——
	# 不经塔的光环 / 编队 / 升阶桶，按护甲结算、吃目标侧减益。
	var physical := supply.instant_physical_at(level)
	if physical > 0:
		var struck := 0
		for enemy in enemy_manager.get_alive_enemies():
			enemy.take_damage(physical, "", DamageTypes.PHYSICAL)
			struck += 1
		ui.show_status("%s：命中 %d 名敌人（各 %d 物理）" % [supply_name, struck, physical])
	var speed_bonus := supply.attack_speed_bonus_at(level)
	if speed_bonus > 0.0:
		for node in get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
			var tower := node as Tower
			if tower != null and is_instance_valid(tower):
				tower.apply_attack_speed_buff(str(supply.supply_id), 1.0 + speed_bonus, supply.duration_at(level))
		ui.show_status("%s：全队攻速 +%d%%（%ds）" % [
			supply_name, roundi(speed_bonus * 100.0), int(supply.duration_at(level))
		])
	var slow := supply.slow_factor_at(level)
	if slow < 1.0:
		var slowed := 0
		for enemy in enemy_manager.get_alive_enemies():
			enemy.apply_slow(slow, supply.duration_at(level))
			slowed += 1
		ui.show_status("%s：全场减速 %d%%（%ds，%d 名敌人）" % [
			supply_name, roundi((1.0 - slow) * 100.0), int(supply.duration_at(level)), slowed
		])
	# 犒军（✅ 0.8.16 新军需 / STATS_PIPELINE v0.7）：直接加怒固定值——
	# 不吃科技 rage_gain_pct、不吃月幕倍率（走 Tower.grant_rage_flat）。
	var rage := supply.rage_gain_at(level)
	if rage > 0:
		for node in get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
			var tower := node as Tower
			if tower != null and is_instance_valid(tower):
				tower.grant_rage_flat(float(rage))
		ui.show_status("%s：全队怒气 +%d" % [supply_name, rage])


func _close_battle_supply_popup() -> void:
	if _battle_supply_popup != null and is_instance_valid(_battle_supply_popup):
		_battle_supply_popup.queue_free()
	_battle_supply_popup = null
	_supply_card_nodes.clear()
	_supply_slot_nodes.clear()
	_supply_detail_nodes.clear()
	_supply_gold_label = null
	_supply_pinned = false
	_set_supply_button_highlight(false)
