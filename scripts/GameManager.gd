extends Node

signal gold_changed(new_amount: int)
signal lives_changed(new_amount: int)
signal wave_changed(current: int, total: int)
signal game_over
signal victory

var gold: int = 100:
	set(value):
		gold = value
		gold_changed.emit(gold)

var lives: int = 20:
	set(value):
		lives = value
		lives_changed.emit(lives)
		if lives <= 0:
			game_over.emit()

var current_wave: int = 0
var total_waves: int = 5
var is_wave_active: bool = false
var active_battle_session: BattleSession = null

func enemy_reached_base(damage: int = 1):
	if lives <= 0:
		return
	lives = max(lives - damage, 0)

func enemy_died(reward: int, kill_xp: int = 0, source_character_id: String = ""):
	gold += reward
	if active_battle_session != null and kill_xp > 0 and not source_character_id.strip_edges().is_empty():
		active_battle_session.add_xp(source_character_id, kill_xp)


func set_battle_session(session: BattleSession) -> void:
	active_battle_session = session

func start_wave():
	if is_wave_active or current_wave >= total_waves or lives <= 0:
		return false
	is_wave_active = true
	return true

func wave_completed():
	if not is_wave_active:
		return
	is_wave_active = false
	current_wave += 1
	wave_changed.emit(current_wave, total_waves)
	if current_wave >= total_waves:
		victory.emit()

func reset(starting_gold: int = 100, starting_lives: int = 20, wave_count: int = 5):
	gold = maxi(starting_gold, 0)
	lives = maxi(starting_lives, 0)
	total_waves = maxi(wave_count, 1)
	current_wave = 0
	is_wave_active = false
	active_battle_session = null
