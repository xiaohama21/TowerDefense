extends Node2D

const STAGE_RESOURCE_PATH: String = "res://resources/stages/chapter_01/ch01_s01.tres"
const CHARACTER_RESOURCE_DIR: String = "res://resources/characters"
const INITIAL_CHARACTER_IDS: Array[String] = ["liu_bei", "guan_yu"]

@onready var enemy_manager = $EnemyManager
@onready var tower_manager = $TowerManager
@onready var wave_manager = $WaveManager
@onready var build_manager = $BuildManager
@onready var ui = $UI

var battle_session: BattleSession
var stage_data: StageData
var _available_characters: Array[CharacterData] = []
var _selected_character: CharacterData = null

func _ready():
	get_tree().paused = false
	stage_data = load(STAGE_RESOURCE_PATH) as StageData
	if stage_data == null:
		push_error("关卡数据加载失败: %s" % STAGE_RESOURCE_PATH)
		return

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
	build_manager.tower_built.connect(_on_tower_built)

	ui.set_stage_name(stage_data.display_name)
	ui.setup_character_bar(_available_characters)
	_select_character(str(_available_characters[0].character_id))

	ui.update_gold(GameManager.gold)
	ui.update_lives(GameManager.lives)
	ui.update_wave(GameManager.current_wave, GameManager.total_waves)
	ui.show_status("选择武将后点击绿色 + 建造，再开始第 1 波", 3.0)


## New profiles start with the initial squad; later stages gate additional
## characters through first-clear unlocks.
func _ensure_initial_profile() -> void:
	var profile := ProfileStore.get_profile()
	var changed := false
	for character_id in INITIAL_CHARACTER_IDS:
		if not profile.has_character(character_id):
			profile.ensure_character(character_id)
			changed = true
	if changed:
		ProfileStore.save_profile(profile)


func _load_available_characters(profile: PlayerProfile) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for character_id in profile.get_owned_character_ids():
		var character_data := load(
			"%s/%s.tres" % [CHARACTER_RESOURCE_DIR, character_id]
		) as CharacterData
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
			ui.set_selected_character(character_id)
			return


func _on_tower_built(_slot: Node) -> void:
	if battle_session == null or _selected_character == null:
		return
	var character_id := str(_selected_character.character_id)
	if not battle_session.deployed_character_ids.has(character_id):
		battle_session.deployed_character_ids.append(character_id)

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

func _on_game_over():
	if battle_session != null:
		ProfileStore.finish_defeat(battle_session, {
			"remaining_lives": GameManager.lives,
			"completed_waves": GameManager.current_wave,
		})
	ui.show_message("游戏结束！\n本局临时收益未保存")
	get_tree().paused = true

func _on_victory():
	var saved := false
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
	ui.show_message("胜利！\n关卡进度已保存" if saved else "胜利！\n存档写入失败")
	get_tree().paused = true


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
	else:
		rewards = stage_data.repeat_clear_rewards
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
