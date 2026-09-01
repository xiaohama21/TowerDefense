extends Node

signal gold_changed(new_amount: int)
signal lives_changed(new_amount: int)
signal wave_changed(current: int, total: int)
signal game_over
signal victory
## 击杀通知（v0.11.2）：龙魂叠层、技能返怒等按"最后一击武将"订阅。
signal enemy_killed_by_character(character_id: String)
## Boss 登场（v0.15.0 演出）：Boss 敌人出生时发出，供横幅/血条演出。
signal boss_entered(display_name: String)
## 击杀连击档位（阶段 8 提交 2）：达到 5/10/15 连击触发（tier 1/2/3，攻速 +5%/10%/15%）。
signal combo_changed(count: int, tier: int)
## 波次开始（阶段 8·提交 6 角色技能 B 被动）：每波首次漏怪标记随波重置。
signal wave_started(wave_index: int)
## 漏怪通知（阶段 8·提交 6）：敌人到达基地时发出（角色技能 B 被动触发源）。
signal enemy_leaked(damage: int)

## 连击规则（P1 4.1 拍板）：窗口 3s；召唤物计入、Boss 不计入普通连击；每波结束清零；
## 攻速奖励上限 +15%（tier 3）；暂停时 _process 停止计时，天然冻结连击窗口。
const COMBO_WINDOW_SECONDS: float = 3.0
const COMBO_TIER_STEP: int = 5
const MAX_COMBO_TIER: int = 3
## 辅助经验防刷（P1 4.5 拍板，阶段 8 提交 3）：每波上限 = 本波击杀经验总额 ×1.5（下限 10）；
## 光环覆盖按 5s 分段去重（10.6：+2 / 5秒 / 友方），同一增益对象短时重复不重复给满额。
const SUPPORT_WAVE_CAP_RATIO: float = 1.5
const SUPPORT_WAVE_CAP_FLOOR: int = 10
const SUPPORT_COVERAGE_WINDOW: float = 5.0

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
## 本局起始基地生命（阶段 8·提交 6）：周仓·死战按此计算 50% 阈值。
var starting_lives: int = 20
var is_wave_active: bool = false
var active_battle_session: BattleSession = null
## 每波首次漏怪已触发标记（B 被动：刘备·携民渡江 / 赵云·七进七出，每波一次）。
var _wave_first_leak_used: bool = false

## 击杀连击状态（局内临时，不写存档）。
var combo_count: int = 0
var combo_tier: int = 0
var _combo_window_left: float = 0.0
var _wave_kill_xp_total: int = 0
var _wave_support_xp_granted: int = 0
var _support_coverage_last_time: Dictionary = {}

func enemy_reached_base(damage: int = 1):
	if lives <= 0:
		return
	lives = max(lives - damage, 0)
	enemy_leaked.emit(damage)
	# 角色技能 B 被动（每波首次漏怪）：GameManager 仅分发一次，塔不各自记波。
	if not _wave_first_leak_used:
		_wave_first_leak_used = true
		for node in get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
			var tower := node as Tower
			if tower != null and is_instance_valid(tower):
				SkillRegistry.on_wave_first_leak(tower)

func enemy_died(
	reward: int,
	kill_xp: int = 0,
	source_character_id: String = "",
	damage_contributors: Dictionary = {},
	is_boss: bool = false,
	is_summon: bool = false
):
	gold += int(round(reward * Difficulty.reward_mult(GameFlow.selected_difficulty)))
	if kill_xp > 0:
		_wave_kill_xp_total += kill_xp
		kill_xp = int(round(kill_xp * Difficulty.reward_mult(GameFlow.selected_difficulty)))
		_distribute_kill_xp(kill_xp, source_character_id, damage_contributors)
	if not source_character_id.strip_edges().is_empty():
		enemy_killed_by_character.emit(source_character_id.strip_edges())
	# 连击（P0 4.1 拍板）：Boss 不计入普通连击，召唤物计入。
	if not is_boss:
		_advance_combo()


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


## 辅助贡献事件经验（GDD 10.6 落地，阶段 8 提交 3）：增益施加 +4/次，覆盖 +2/5秒/友方；
## 同塔 5s 内重复覆盖去重（v0.28.0：按塔实例，同角色多塔分别计数）；每波贡献不超过本波击杀经验 ×1.5（下限 10）。
func add_support_contribution(character_id: String, ally_ids: Array) -> void:
	if ally_ids.is_empty():
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	var per_character: Dictionary = _support_coverage_last_time.get(character_id, {})
	var fresh_cover := 0
	for raw_ally_id in ally_ids:
		var ally_id := str(raw_ally_id).strip_edges()
		if ally_id.is_empty():
			continue
		if now - float(per_character.get(ally_id, -999.0)) >= SUPPORT_COVERAGE_WINDOW:
			per_character[ally_id] = now
			fresh_cover += 1
	_support_coverage_last_time[character_id] = per_character
	var amount := 4 + 2 * fresh_cover
	var cap := maxi(int(round(_wave_kill_xp_total * SUPPORT_WAVE_CAP_RATIO)), SUPPORT_WAVE_CAP_FLOOR)
	if _wave_support_xp_granted >= cap:
		return
	amount = mini(amount, cap - _wave_support_xp_granted)
	_wave_support_xp_granted += amount
	_add_session_xp(character_id, amount)


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
	# 每波重置辅助经验统计（P1 4.5）：击杀经验总额与已发放贡献、覆盖去重表。
	_wave_kill_xp_total = 0
	_wave_support_xp_granted = 0
	_support_coverage_last_time.clear()
	# 每波重置首次漏怪标记（B 被动每波一次）。
	_wave_first_leak_used = false
	wave_started.emit(current_wave)
	return true

func wave_completed():
	if not is_wave_active:
		return
	is_wave_active = false
	current_wave += 1
	reset_combo()
	wave_changed.emit(current_wave, total_waves)
	if current_wave >= total_waves:
		victory.emit()


## 连击推进：窗口内击杀递增，否则重新从 1 开始；每 5 连击升一档并广播。
func _advance_combo() -> void:
	combo_count = combo_count + 1 if _combo_window_left > 0.0 else 1
	_combo_window_left = COMBO_WINDOW_SECONDS
	var new_tier := mini(int(combo_count / COMBO_TIER_STEP), MAX_COMBO_TIER)
	if new_tier > combo_tier:
		combo_tier = new_tier
		combo_changed.emit(combo_count, combo_tier)


## 每波结束清零（P1 4.1 拍板）。
func reset_combo() -> void:
	combo_count = 0
	combo_tier = 0
	_combo_window_left = 0.0


func _process(delta: float) -> void:
	# 暂停时（设置弹窗/结算）树暂停，本函数停止执行，连击窗口自然冻结。
	if _combo_window_left > 0.0:
		_combo_window_left = maxf(_combo_window_left - delta, 0.0)

func reset(starting_gold: int = 100, starting_lives: int = 20, wave_count: int = 5):
	gold = maxi(starting_gold, 0)
	lives = maxi(starting_lives, 0)
	starting_lives = maxi(starting_lives, 0)
	total_waves = maxi(wave_count, 1)
	_wave_first_leak_used = false
	current_wave = 0
	is_wave_active = false
	active_battle_session = null
