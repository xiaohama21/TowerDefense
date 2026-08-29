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

func enemy_died(
	reward: int,
	kill_xp: int = 0,
	source_character_id: String = "",
	damage_contributors: Dictionary = {}
):
	gold += reward
	if kill_xp > 0:
		_distribute_kill_xp(kill_xp, source_character_id, damage_contributors)


## 击杀经验归属（GDD 4.4）：发出的经验总量守恒等于 kill_xp；最后一击得 50%
## （向上取整），其余由所有对该敌人造成过伤害的武将均分（含最后一击者，
## 余数归最后一击）。保证辅助/低攻速职业也能积累经验。
func _distribute_kill_xp(kill_xp: int, last_hitter_id: String, contributors: Dictionary) -> void:
	var last_id := last_hitter_id.strip_edges()
	var participant_ids: Array[String] = []
	for key in contributors.keys():
		var participant_id := str(key).strip_edges()
		if not participant_id.is_empty() and not participant_ids.has(participant_id):
			participant_ids.append(participant_id)
	if participant_ids.is_empty() and not last_id.is_empty():
		participant_ids.append(last_id)
	if participant_ids.is_empty():
		return

	var last_share := ceili(kill_xp * 0.5)
	if not last_id.is_empty():
		_add_session_xp(last_id, last_share)

	var pool := kill_xp - last_share
	if pool <= 0:
		return
	var count := participant_ids.size()
	var even_share := floori(pool / float(count))
	var remainder := pool - even_share * count
	for participant_id in participant_ids:
		var amount := even_share
		if participant_id == last_id:
			amount += remainder
		_add_session_xp(participant_id, amount)


func _add_session_xp(character_id: String, amount: int) -> void:
	if active_battle_session == null or amount <= 0:
		return
	# 向下取整：逐事件修正不超出名义值（8×1.4 名义 11.2，分两笔各 5 → 合计 10）。
	var corrected := int(amount * _xp_correction_factor(character_id))
	if corrected > 0:
		active_battle_session.add_xp(character_id, corrected)


## 落后补正（GDD 4.4/10.6，v0.11.1）：武将等级低于编队平均 1 级以上时，
## 经验获取 +20%/级差（上限 +60%）；高于平均不衰减。
func _xp_correction_factor(character_id: String) -> float:
	if active_battle_session == null:
		return 1.0
	var deployed := active_battle_session.get_deployed_character_ids()
	if deployed.size() <= 1:
		return 1.0
	var profile := ProfileStore.get_profile()
	var level_sum := 0
	for deployed_id in deployed:
		level_sum += GameFlow.get_character_level(profile, deployed_id)
	var average := float(level_sum) / deployed.size()
	var my_level := GameFlow.get_character_level(profile, character_id)
	var behind := average - my_level
	if behind < 1.0:
		return 1.0
	return minf(1.0 + 0.2 * behind, 1.6)


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
