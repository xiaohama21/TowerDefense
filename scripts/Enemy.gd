extends PathFollow2D

class_name Enemy

const ENEMY_GROUP: StringName = &"enemies"
## 隐匿（NUMBERS 10.16，✅ 0.8.13.1）：破隐扫描周期与现形闪光时长。
const STEALTH_SCAN_INTERVAL: float = 0.25
const REVEAL_FLASH_DURATION: float = 0.7
## 阶段推进表现（三阶段 Boss，✅ 0.8.13.5 张角）：金色扩散环时长。
const PHASE_FLASH_DURATION: float = 0.9

## 血条（UI_LAYOUT §10 · 程序 0.8.16.4「方案 A 墨槽胶囊」）：三档——普通 max(体型宽,24)×6 /
## 精英「体型宽 + 6」×8 + 白框 / Boss ≥84×12 + 金框 + 三刻度（25/50/75%）。
## 几何：中心 x = 体型中心 x（居中）；条底 = 身体顶 −10（头带占 −7…−2，故留 3px 不压模型）。
enum HpBarTier { NORMAL, ELITE, BOSS }

const HP_BAR_BOTTOM_OFFSET: float = 10.0
const HP_BAR_MIN_WIDTH: float = 24.0
const HP_BAR_HEIGHTS := [6.0, 8.0, 12.0]
const HP_BAR_ELITE_WIDTH_BONUS: float = 6.0
const HP_BAR_BOSS_MIN_WIDTH: float = 84.0
const HP_BAR_BOSS_WIDTH_BONUS: float = 24.0
const HP_BAR_LOW_RATIO: float = 0.30
## 头顶避让（与血条同源）：眩晕三小星中心 = 条顶 −7；阶段点中心 = 条顶 −16。
const HP_BAR_STUN_OFFSET: float = 7.0
const HP_BAR_PHASE_OFFSET: float = 16.0
## 掉血残影：受击瞬间取旧比例，保持 HP_GHOST_HOLD 后按 HP_GHOST_FADE 秒回落到当前血量。
const HP_GHOST_HOLD: float = 0.25
const HP_GHOST_FADE: float = 0.35
const HP_BAR_SLOT_TOP := Color(0.055, 0.082, 0.11, 1.0)
const HP_BAR_SLOT_BOTTOM := Color(0.024, 0.035, 0.051, 1.0)
const HP_BAR_FILL_TOP := Color(1.0, 0.545, 0.471, 1.0)
const HP_BAR_FILL_MID := Color(0.898, 0.282, 0.302, 1.0)
const HP_BAR_FILL_BOTTOM := Color(0.62, 0.122, 0.169, 1.0)
const HP_BAR_FILL_LOW_TOP := Color(1.0, 0.616, 0.525, 1.0)
const HP_BAR_FILL_LOW_MID := Color(0.937, 0.314, 0.247, 1.0)
const HP_BAR_FILL_LOW_BOTTOM := Color(0.647, 0.133, 0.165, 1.0)
const HP_BAR_GHOST := Color(1.0, 0.89, 0.847, 0.78)
const HP_BAR_ELITE_FRAME := Color(0.949, 0.969, 0.98, 0.92)
const HP_BAR_BOSS_FRAME := Color(0.867, 0.686, 0.314, 0.95)
const HP_BAR_SHADOW := Color(0.0, 0.0, 0.0, 0.45)
const HP_BAR_INK_RING := Color(0.0, 0.0, 0.0, 0.55)
const HP_BAR_TICK := Color(0.094, 0.024, 0.039, 0.7)
const HP_BAR_GLOSS := Color(1.0, 1.0, 1.0, 0.5)
const HP_BAR_LOW_GLOW := Color(1.0, 0.376, 0.306, 0.34)

@export var speed: float = 100.0
@export var max_hp: int = 100
@export var armor: int = 0
@export var reward: int = 10
@export var kill_xp: int = 0
## 军功掉落（✅ 0.8.16 / NUMBERS 10.15）：由 EnemyManager 从 EnemyData 传入，击杀结算上报。
@export var merit_reward: int = 0
@export var damage_to_base: int = 1
@export var enemy_id: StringName = &""
## 显示名（v0.15.0 Boss 演出横幅使用，由 EnemyManager 从 EnemyData 传入）。
var display_name: String = ""
# 兵种/阵营标签（GDD 5.5），职业克制与掉落倾向按标签查询。
var tags: Array[StringName] = []

var current_hp: int = 0
var is_dead: bool = false
var last_damage_source_character_id: String = ""
# character_id -> 累计有效伤害，供击杀经验归属规则（GDD 4.4）分摊使用。
var damage_contributors: Dictionary = {}
# 当前移动方向（抛射预判落点用）；初始朝右，随实际位移刷新。
var velocity_dir: Vector2 = Vector2.RIGHT
# 特殊行为（GDD modules/BEHAVIORS.md B.3.2）：healer_aura / summon_guard 等，
# 由 EnemyManager 按 ID 执行；cooldown 为行为计时器。
var special_behavior_id: StringName = &""
## 附加行为（✅ 0.8.13.4 多行为支持）：主行为之外的行为 ID 列表，与主行为分别独立冷却。
var extra_behavior_ids: Array[StringName] = []
## 行为冷却表（✅ 0.8.13.4）：behavior_id -> 剩余秒数；每行为独立计时。
var special_cooldowns: Dictionary = {}

func get_special_cooldown(behavior_id: StringName) -> float:
	return float(special_cooldowns.get(behavior_id, 0.0))

func set_special_cooldown(behavior_id: StringName, value: float) -> void:
	special_cooldowns[behavior_id] = value


## 阶段推进（✅ 0.8.13.5 张角三阶段）：金色扩散环 + 阶段点一次性表现，
## 由 EnemyManager 在召唤档案切换时调用（阶段差异可感知，BEHAVIORS B.3.2）。
func trigger_phase_advance() -> void:
	phase_index += 1
	_phase_flash_left = PHASE_FLASH_DURATION
	queue_redraw()
## 特殊行为参数（B.3.2，✅ 0.8.13.2）：EnemyManager 从 EnemyData.special_params 写入，
## armor_aura / healer_aura 按 key 读取（缺省回退 BalanceData）。
var special_params: Dictionary = {}
# 减速 debuff（术士大招/张飞咆哮/诸葛亮光环等）：取最强因子，倒计时归零解除。
var slow_factor: float = 1.0
## 召唤物标记（阶段 8 提交 2）：连击计入召唤物（P1 4.1 拍板），由召唤方设置。
var is_summon: bool = false
## 已召唤数量（✅ 0.8.13.4 召唤上限）：max_summons 上限计数（张宝 = 4）；
## 三阶段 Boss（✅ 0.8.13.5）按阶段档案重置，配额逐阶段独立。
var summoned_count: int = 0
## 召唤档案序号（✅ 0.8.13.5 张角三阶段）：special_params.summon_profiles 的当前命中项，
## -1 = 尚未初始化（EnemyManager 按 HP 比例推进）。
var summon_profile_index: int = -1
## 当前阶段序号（1 起，阶段推进时 +1）：阶段表现与测试锚点（P1/P2/P3）。
var phase_index: int = 1
var _phase_flash_left: float = 0.0
## 隐匿状态（✅ 0.8.13.1）：不可被“以单位为目标”的攻击选中；范围/无差别区域可命中。
## 由 EnemyManager 依 EnemyData.stealth 写入；能否被某塔选中见 is_visible_to()。
var stealth: bool = false
var _stealth_revealed: bool = false
var _stealth_scan_tick: float = 0.0
var _reveal_flash_left: float = 0.0
## 护甲光环（armor_aura，✅ 0.8.13.2）：EnemyManager 周期刷新写入，窗口过期自动失效
## （施法者阵亡 / 离开半径无需额外清理）；先加甲后算减伤（NUMBERS 10.17）。
var _armor_aura_bonus: int = 0
var _armor_aura_until_ms: int = -1
var _slow_time_left: float = 0.0
## 灼烧（阶段 8 军需·火攻，为阶段 9 特性铺路）：每秒 burn_dps，取更大值刷新时长。
var burn_dps: int = 0
var _burn_time_left: float = 0.0
var _burn_acc: float = 0.0
## 定军标记（黄忠·定军山，阶段 8·提交 6）：character_id -> 剩余秒数；
## 被标记目标受该武将塔普攻伤害 +15%（SkillRegistry.passive_damage_multiplier 读取）。
var marks: Dictionary = {}
## 眩晕（震山·震地，提交 7）：时长类控制——剩余秒数内停止移动；
## 同一敌人叠晕由施法者塔内置冷却（2.5s）防抖，见 SkillRegistry.try_apply_tremor_stun。
var _stun_time_left: float = 0.0
var _stun_pulse: float = 0.0
## 恐惧（张飞·当阳桥，v0.35.2 / 0.8.10.1）：时长类控制——剩余秒数内沿路径
## 反向行军、速度取基础移速（不受减速影响）；可携带随附减速，恐惧结束时施加
## （当阳桥两段顺序控制：恐惧 1s → 减速 60%/2s，NUMBERS 10.10 / STATS_PIPELINE §6）。
var _fear_time_left: float = 0.0
var _fear_pulse: float = 0.0
var _fear_follow_slow_factor: float = 0.0
var _fear_follow_slow_duration: float = 0.0
## 易伤（天师·奇门，提交 7）：剩余秒数内受所有来源伤害 +_vulnerability_bonus；
## 同类不叠加（取更强加成）、时长刷新（NUMBERS 10.10）。
var _vulnerability_bonus: float = 0.0
var _vulnerability_time_left: float = 0.0

@onready var body: ColorRect = $Body
var _hit_flash_left: float = 0.0
## 体型（Body ColorRect 尺寸；血条宽度 / 头顶挂点均以此为准）。
var _body_size := Vector2(40.0, 40.0)
## 掉血残影比例与停留计时（血条白段，见 _process）。
var _hp_ghost_ratio: float = 1.0
var _hp_ghost_hold: float = 0.0

func _enter_tree() -> void:
	add_to_group(ENEMY_GROUP)


func _ready() -> void:
	# PathFollow2D defaults to looping. Enemies must stop at the base instead.
	loop = false
	rotates = false
	max_hp = maxi(max_hp, 1)
	current_hp = max_hp
	progress = 0
	if body:
		_body_size = body.size
	# Boss 演出（v0.15.0）：登场信号；血条三档由 tags 判定（见 get_hp_bar_tier），绘制在 _draw。
	if tags.has(&"boss"):
		GameManager.boss_entered.emit(str(display_name))
	update_hp_bar()
	_refresh_stealth_visual()
	if stealth:
		# 隐匿登场预警（音效；虚影由 _draw 表达）。
		SfxLibrary.play(&"alert", -8.0)
	queue_redraw()


func _process(delta: float) -> void:
	if is_dead:
		return

	if _hit_flash_left > 0.0:
		_hit_flash_left = maxf(_hit_flash_left - delta, 0.0)
		if _hit_flash_left <= 0.0:
			_apply_body_modulate()

	# 掉血残影（血条白段）：停留后按比例回落到当前血量；仅回落期间重绘。
	if _hp_ghost_ratio > get_hp_ratio():
		if _hp_ghost_hold > 0.0:
			_hp_ghost_hold = maxf(_hp_ghost_hold - delta, 0.0)
		else:
			var ghost_floor := get_hp_ratio()
			_hp_ghost_ratio = maxf(
				ghost_floor,
				_hp_ghost_ratio - (_hp_ghost_ratio - ghost_floor) / HP_GHOST_FADE * delta
			)
		queue_redraw()
	else:
		_hp_ghost_ratio = get_hp_ratio()

	# 隐匿（NUMBERS 10.16，✅ 0.8.13.1）：0.25s 扫描破隐覆盖 + 现形闪光衰减。
	if stealth:
		_stealth_scan_tick = maxf(_stealth_scan_tick - delta, 0.0)
		if _stealth_scan_tick <= 0.0:
			_stealth_scan_tick = STEALTH_SCAN_INTERVAL
			refresh_stealth_reveal()
	if _reveal_flash_left > 0.0:
		_reveal_flash_left = maxf(_reveal_flash_left - delta, 0.0)
		queue_redraw()

	if _slow_time_left > 0.0:
		_slow_time_left = maxf(_slow_time_left - delta, 0.0)
		if _slow_time_left <= 0.0:
			slow_factor = 1.0

	if _burn_time_left > 0.0:
		_burn_time_left = maxf(_burn_time_left - delta, 0.0)
		_burn_acc += float(burn_dps) * delta
		if _burn_acc >= 1.0:
			var tick := int(_burn_acc)
			_burn_acc -= tick
			take_damage(tick, "", DamageTypes.MAGIC)

	if not marks.is_empty():
		var expired_marks: Array[String] = []
		for key in marks.keys():
			marks[key] = maxf(float(marks[key]) - delta, 0.0)
			if float(marks[key]) <= 0.0:
				expired_marks.append(str(key))
		for key in expired_marks:
			marks.erase(key)

	if _vulnerability_time_left > 0.0:
		_vulnerability_time_left = maxf(_vulnerability_time_left - delta, 0.0)
		if _vulnerability_time_left <= 0.0:
			_vulnerability_bonus = 0.0

	# 恐惧（当阳桥，v0.35.2 / 0.8.10.1）：时长衰减；到期瞬间施加随附减速
	# （两段顺序控制——恐惧期间不提前挂减速，避免与「反向行军、移速不变」语义冲突）。
	if _fear_time_left > 0.0:
		_fear_time_left = maxf(_fear_time_left - delta, 0.0)
		_fear_pulse += delta
		if _fear_time_left <= 0.0:
			if _fear_follow_slow_factor > 0.0 and _fear_follow_slow_duration > 0.0:
				apply_slow(_fear_follow_slow_factor, _fear_follow_slow_duration)
			_fear_follow_slow_factor = 0.0
			_fear_follow_slow_duration = 0.0
		queue_redraw()

	# 阶段推进表现（✅ 0.8.13.5 张角三阶段）：扩散环衰减，结束即停重绘。
	if _phase_flash_left > 0.0:
		_phase_flash_left = maxf(_phase_flash_left - delta, 0.0)
		queue_redraw()

	# 眩晕（震地，提交 7）：期间停止移动、进度不推进；Boss 控制抗性折减随阶段 9 统一落地。
	if _stun_time_left > 0.0:
		_stun_time_left = maxf(_stun_time_left - delta, 0.0)
		_stun_pulse += delta
		queue_redraw()
	else:
		var before := global_position
		if _fear_time_left > 0.0:
			# 恐惧：沿路径反向行军，速度取基础移速（不受减速影响）。
			progress = maxf(progress - speed * delta, 0.0)
		else:
			progress += speed * slow_factor * delta
		var delta_pos := global_position - before
		if delta_pos.length_squared() > 0.01:
			velocity_dir = delta_pos.normalized()

	if progress_ratio >= 1.0 - 0.0001:
		GameManager.last_leak_was_stealth = stealth
		GameManager.enemy_reached_base(damage_to_base)
		die(false)


## 施加定军标记：多来源按角色分别计时，时长刷新。
func apply_mark(character_id: String, duration: float) -> void:
	if is_dead or duration <= 0.0 or character_id.is_empty():
		return
	marks[character_id] = maxf(float(marks.get(character_id, 0.0)), duration)


func has_mark(character_id: String) -> bool:
	return not character_id.is_empty() and character_id in marks and float(marks.get(character_id, 0.0)) > 0.0


## 施加减速：多来源叠加时取最强因子（最小值），时长刷新。
func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, clampf(factor, 0.05, 1.0))
	_slow_time_left = maxf(_slow_time_left, duration)


## 施加灼烧：多来源叠加时取更大每秒伤害，时长刷新。
func apply_burn(dps: int, duration: float) -> void:
	if is_dead or dps <= 0 or duration <= 0.0:
		return
	burn_dps = maxi(burn_dps, dps)
	_burn_time_left = maxf(_burn_time_left, duration)


## 施加眩晕（震地，提交 7）：时长类控制，取更长剩余时长；期间停止移动。
func apply_stun(duration: float) -> void:
	if is_dead or duration <= 0.0:
		return
	_stun_time_left = maxf(_stun_time_left, duration)
	queue_redraw()


## 施加恐惧（张飞·当阳桥，v0.35.2 / 0.8.10.1）：时长类控制——期间沿路径反向
## 行军、移速不变（不受减速影响）；可携带随附减速（两段顺序控制，恐惧结束时施加）。
## 同类不叠加只刷新时长（NUMBERS 10.10）；Boss 抗性折减随阶段 9 统一落地。
func apply_fear(duration: float, follow_slow_factor: float = 0.0, follow_slow_duration: float = 0.0) -> void:
	if is_dead or duration <= 0.0:
		return
	_fear_time_left = maxf(_fear_time_left, duration)
	if follow_slow_factor > 0.0 and follow_slow_duration > 0.0:
		_fear_follow_slow_factor = follow_slow_factor
		_fear_follow_slow_duration = follow_slow_duration
	queue_redraw()


## 施加易伤（奇门，提交 7）：同类不叠加（取更强加成）、时长刷新（NUMBERS 10.10）；
## 作用在 Enemy.take_damage——所有来源伤害（普攻/技能/灼烧等）均受益。
func apply_vulnerability(bonus: float, duration: float) -> void:
	if is_dead or duration <= 0.0 or bonus <= 0.0:
		return
	_vulnerability_bonus = maxf(_vulnerability_bonus, bonus)
	_vulnerability_time_left = maxf(_vulnerability_time_left, duration)
	queue_redraw()


## 易伤倍率：有效期内 1 + bonus，否则 1.0。
func get_vulnerability_multiplier() -> float:
	if _vulnerability_time_left <= 0.0:
		return 1.0
	return 1.0 + _vulnerability_bonus


## ============ 隐匿与破隐（NUMBERS 10.16，✅ 0.8.13.1） ============

## 是否处于隐匿（数据字段口径；能否被某塔选中见 is_visible_to）。
func is_stealthed() -> bool:
	return stealth


## 对指定塔是否可见：非隐匿恒可见；隐匿需该塔持有破隐（Tower.reveals_stealth）。
func is_visible_to(tower) -> bool:
	if not stealth:
		return true
	return tower != null and is_instance_valid(tower) and tower.reveals_stealth()


## 当前是否已现形（表现口径：虚影 vs 正常 + 血条）。
func is_revealed() -> bool:
	return not stealth or _stealth_revealed


## 0.25s 低频扫描（✅ 0.8.13.1）：任一“持破隐且自身在其射程内”的塔覆盖即现形；
## 破隐不做一次性现形——离开覆盖自动恢复隐匿（NUMBERS 10.16）。
func refresh_stealth_reveal() -> void:
	if not stealth:
		return
	var revealed := false
	for node in get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var tower := node as Tower
		if tower == null or not is_instance_valid(tower) or not tower.reveals_stealth():
			continue
		if global_position.distance_to(tower.global_position) <= tower.range_radius:
			revealed = true
			break
	_set_stealth_revealed(revealed)


func _set_stealth_revealed(value: bool) -> void:
	if value == _stealth_revealed:
		return
	_stealth_revealed = value
	if value:
		_reveal_flash_left = REVEAL_FLASH_DURATION
		SfxLibrary.play(&"skill", -16.0)
	_refresh_stealth_visual()


## 虚影透明度：隐匿且未现形 = 半透明（保留行进警示）。
func _ghost_alpha() -> float:
	return 0.4 if (stealth and not _stealth_revealed) else 1.0


## 体色统一出口（受击闪光 × 虚影透明度）。
func _apply_body_modulate() -> void:
	if body == null:
		return
	var tint := Color(1.0, 0.45, 0.4) if _hit_flash_left > 0.0 else Color(1.0, 1.0, 1.0)
	tint.a = _ghost_alpha()
	body.modulate = tint


func _refresh_stealth_visual() -> void:
	_apply_body_modulate()
	update_hp_bar()
	queue_redraw()


## ============ 护甲光环（armor_aura，NUMBERS 10.17，✅ 0.8.13.2） ============

## 写入光环加成（同源取最大、窗口取更晚到期；到期判定见 get_armor_aura_bonus）。
func apply_armor_aura_bonus(value: int, duration: float) -> void:
	if value <= 0 or duration <= 0.0:
		return
	_armor_aura_bonus = maxi(_armor_aura_bonus, value)
	_armor_aura_until_ms = maxi(_armor_aura_until_ms, Time.get_ticks_msec() + int(round(duration * 1000.0)))


## 当前生效的护甲光环加成（窗口过期即 0）。
func get_armor_aura_bonus() -> int:
	if _armor_aura_until_ms >= 0 and Time.get_ticks_msec() < _armor_aura_until_ms:
		return _armor_aura_bonus
	_armor_aura_bonus = 0
	return 0


## 有效甲值唯一出口（基础甲 + 生效中光环）：结算 / 调试统一读此值。
func get_effective_armor() -> int:
	return maxi(armor + get_armor_aura_bonus(), 0)


## 伤害入口（NUMBERS 10.12，✅ 0.8.13.0 护甲模型替换）：
## damage_type = 物理 / 魔法 / 真实（DamageTypes）；pen_ratios = 百分比穿甲
## （{来源 key: 比值}，同源取最高由调用方聚合、跨源乘算、单源 ≤30%）；
## pen_flat = 固定穿透（百分比之后扣减）。
func take_damage(
	amount: int,
	source_character_id: String = "",
	damage_type: StringName = DamageTypes.PHYSICAL,
	pen_ratios: Dictionary = {},
	pen_flat: int = 0
) -> void:
	if is_dead or amount <= 0:
		return
	var source_id := source_character_id.strip_edges()
	if not source_id.is_empty():
		last_damage_source_character_id = source_id

	# 易伤（奇门）：所有来源伤害先乘易伤倍率（同类不叠加只刷新，NUMBERS 10.10）。
	var scaled := int(round(float(amount) * get_vulnerability_multiplier()))
	if scaled <= 0:
		return
	# 护甲结算（类型系数 → 百分比穿甲 → 固定穿透 → 比值减伤）；真实伤害恒满伤。
	var effective := _apply_armor(scaled, damage_type, pen_ratios, pen_flat)
	if effective <= 0:
		return
	var hp_ratio_before := get_hp_ratio()
	current_hp = maxi(current_hp - effective, 0)
	if get_hp_ratio() < hp_ratio_before:
		_hp_ghost_ratio = maxf(_hp_ghost_ratio, hp_ratio_before)
		_hp_ghost_hold = HP_GHOST_HOLD
	if not source_id.is_empty():
		damage_contributors[source_id] = int(damage_contributors.get(source_id, 0)) + effective
	_hit_flash_left = 0.12
	_apply_body_modulate()
	update_hp_bar()

	if current_hp <= 0:
		die(true)


## 护甲结算唯一实现（NUMBERS 10.12，✅ 0.8.13.0）：
## 1) 类型系数 armor_eff = max(armor × f_type, 0)；2) 百分比穿甲跨来源乘算 Π(1 − pᵢ)、
## 单源 ≤30%；3) 固定穿透后置；4) 减伤 m = armor_f / (armor_f + C)，无保底；
## 真实伤害（f_type = 0）恒为满伤。勿在调用侧另写护甲公式。
func _apply_armor(amount: int, damage_type: StringName, pen_ratios: Dictionary, pen_flat: int) -> int:
	# 光环加甲（✅ 0.8.13.2）：先加甲再走类型系数 → 穿甲 → 固定穿透（NUMBERS 10.17）。
	var armor_eff := maxf(float(get_effective_armor()) * DamageTypes.armor_factor(damage_type), 0.0)
	if armor_eff <= 0.0:
		return amount
	var remaining := 1.0
	for key in pen_ratios:
		var ratio := clampf(float(pen_ratios[key]), 0.0, DamageTypes.MAX_PENETRATION_RATIO)
		remaining *= 1.0 - ratio
	var armor_final := maxf(armor_eff * remaining - maxf(float(pen_flat), 0.0), 0.0)
	var constant := maxf(GameBalance.get_balance().armor_constant, 1.0)
	var reduction := armor_final / (armor_final + constant)
	return maxi(int(round(float(amount) * (1.0 - reduction))), 0)

func die(give_reward: bool) -> void:
	if is_dead:
		return
	is_dead = true

	if give_reward:
		GameManager.enemy_died(
			reward,
			kill_xp,
			last_damage_source_character_id,
			damage_contributors,
			tags.has(&"boss"),
			is_summon,
			merit_reward
		)

	queue_free()


## 治疗光环目标（healer_aura）：不超过最大生命。
func heal(amount: int) -> void:
	if is_dead:
		return
	current_hp = mini(current_hp + amount, max_hp)
	update_hp_bar()


## 血量变化后重绘（满血隐藏 / 隐匿未现形隐藏，规则见 should_show_hp_bar）。
func update_hp_bar() -> void:
	queue_redraw()


func set_color(color: Color) -> void:
	var body := get_node_or_null("Body") as ColorRect
	if body:
		body.color = color
	queue_redraw()


func set_body_size(body_size: Vector2) -> void:
	var body := get_node_or_null("Body") as ColorRect
	if body:
		body.size = body_size
		body.position = -body_size * 0.5
	# 血条随体型（宽 / 档高 / 头顶挂点见 _draw_hp_bar 与 get_hp_bar_rect）。
	_body_size = body_size
	queue_redraw()


func _draw() -> void:
	if body == null:
		return
	var half := body.size * 0.5
	# 头顶血条（v0.20.59 / 0.8.16.4）：先画，随后的头带 / 星星 / 阶段点盖在其上。
	_draw_hp_bar()
	# 黄巾头带：横跨头顶的黄色布条
	var band_rect := Rect2(
		Vector2(-half.x * 0.72, -half.y - 7.0),
		Vector2(half.x * 1.44, 5.0)
	)
	draw_rect(band_rect, Color(0.85, 0.68, 0.2, 1.0))
	draw_rect(band_rect, Color(0.6, 0.45, 0.12, 1.0), false, 1.0)
	# 头带结
	draw_circle(Vector2(half.x * 0.55, -half.y - 4.0), 2.5, Color(0.85, 0.68, 0.2, 1.0))
	# 眼睛
	draw_circle(Vector2(half.x * 0.35, -half.y * 0.3), 2.0, Color(0.95, 0.96, 0.97, 1.0))
	draw_circle(Vector2(half.x * 0.35, -half.y * 0.3), 1.0, Color(0.1, 0.1, 0.12, 1.0))
	draw_circle(Vector2(half.x * 0.35, -half.y * 0.3), 1.0, Color(0.1, 0.1, 0.12, 1.0))
	# 眩晕表现（震地，提交 7）：头顶旋转三小星，眩晕结束自动消失（queue_redraw 由计时驱动）。
	if _stun_time_left > 0.0:
		var spin := _stun_pulse * 6.0
		var stun_y := hp_bar_top_y() - HP_BAR_STUN_OFFSET
		for i in range(3):
			var angle := spin + float(i) * TAU / 3.0
			draw_circle(
				Vector2(cos(angle) * 8.0, stun_y + sin(angle) * 3.0),
				2.4, Color(1.0, 0.85, 0.35, 0.95)
			)
	# 隐匿表现（✅ 0.8.13.1）：未现形 = 淡蓝虚线警示环；现形瞬间 = 青色扩散环。
	if stealth:
		if not _stealth_revealed:
			var dash_radius := half.length() + 9.0
			var segments := 12
			for i in range(segments):
				if i % 2 == 1:
					continue
				var a0 := float(i) / float(segments) * TAU
				var a1 := (float(i) + 0.6) / float(segments) * TAU
				draw_arc(Vector2.ZERO, dash_radius, a0, a1, 3, Color(0.62, 0.72, 0.95, 0.55), 1.6)
		if _reveal_flash_left > 0.0:
			var reveal_t := _reveal_flash_left / REVEAL_FLASH_DURATION
			draw_arc(Vector2.ZERO, half.length() + 10.0 + (1.0 - reveal_t) * 14.0, 0.0, TAU, 26,
				Color(0.55, 0.9, 1.0, reveal_t * 0.8), 2.0)
	# 阶段推进表现（✅ 0.8.13.5 张角三阶段）：金色扩散环 + 阶段点（头顶 HP 条下方）。
	if _phase_flash_left > 0.0:
		var phase_t := _phase_flash_left / PHASE_FLASH_DURATION
		draw_arc(Vector2.ZERO, half.length() + 12.0 + (1.0 - phase_t) * 28.0, 0.0, TAU, 32,
			Color(1.0, 0.84, 0.38, phase_t * 0.85), 2.6)
	if phase_index > 1:
		var pip_y := hp_bar_top_y() - HP_BAR_PHASE_OFFSET
		var pip_start := -(float(phase_index - 1) * 7.0) * 0.5
		for pip in range(phase_index):
			draw_circle(Vector2(pip_start + float(pip) * 7.0, pip_y), 2.2,
				Color(1.0, 0.84, 0.38, 0.9))

	# 恐惧表现（当阳桥，v0.35.2 / 0.8.10.1）：紫色呼吸圆环（与眩晕小星区分）。
	if _fear_time_left > 0.0:
		var pulse := 0.5 + 0.5 * sin(_fear_pulse * 7.0)
		draw_arc(
			Vector2.ZERO, half.length() + 7.0 + pulse * 2.5, 0.0, TAU, 28,
			Color(0.62, 0.42, 0.95, 0.45 + 0.35 * pulse), 1.8
		)


## ---------------------------------------------------------------
## 血条（UI_LAYOUT §10 · 程序 0.8.16.4「方案 A · 墨槽胶囊」）
## ---------------------------------------------------------------
## 档位：Boss > 精英 > 普通（tags 由 EnemyManager 在 add_child 前写入）。
func get_hp_bar_tier() -> int:
	if tags.has(&"boss"):
		return HpBarTier.BOSS
	if tags.has(&"elite"):
		return HpBarTier.ELITE
	return HpBarTier.NORMAL


## 血条尺寸：普通 max(体型宽, 24)×6 ｜ 精英「体型宽 + 6」×8 ｜ Boss ≥84×12。
func get_hp_bar_size() -> Vector2:
	var tier := get_hp_bar_tier()
	var width := maxf(_body_size.x, HP_BAR_MIN_WIDTH)
	if tier == HpBarTier.ELITE:
		width += HP_BAR_ELITE_WIDTH_BONUS
	elif tier == HpBarTier.BOSS:
		width = maxf(HP_BAR_BOSS_MIN_WIDTH, _body_size.x + HP_BAR_BOSS_WIDTH_BONUS)
	return Vector2(width, float(HP_BAR_HEIGHTS[tier]))


## 血条矩形（敌人局部坐标）：水平居中于体型、条底 = 身体顶 −10；绘制与测试同源。
func get_hp_bar_rect() -> Rect2:
	var bar_size := get_hp_bar_size()
	var bar_bottom := -_body_size.y * 0.5 - HP_BAR_BOTTOM_OFFSET
	return Rect2(Vector2(-bar_size.x * 0.5, bar_bottom - bar_size.y), bar_size)


## 条顶 y：眩晕三小星（条顶 −7）与阶段点（条顶 −16）的避让锚点。
func hp_bar_top_y() -> float:
	return get_hp_bar_rect().position.y


func get_hp_ratio() -> float:
	return clampf(float(current_hp) / float(maxi(max_hp, 1)), 0.0, 1.0)


## 血条可见规则（不变）：满血隐藏、隐匿未现形隐藏。
func should_show_hp_bar() -> bool:
	return current_hp < max_hp and is_revealed()


func _draw_hp_bar() -> void:
	if not should_show_hp_bar():
		return
	var tier := get_hp_bar_tier()
	var rect := get_hp_bar_rect()
	var bar_size := rect.size
	var ratio := get_hp_ratio()
	var inner_pos := rect.position + Vector2(1.0, 1.0)
	var inner_size := bar_size - Vector2(2.0, 2.0)
	var low := ratio <= HP_BAR_LOW_RATIO
	# 外投影 → 槽（深墨渐变）→ 内 1px 墨圈 → 档位外框（精英白 / Boss 金）。
	_draw_bar_capsule(rect.position + Vector2(0.0, 1.0), bar_size, HP_BAR_SHADOW)
	_draw_bar_gradient(
		rect.position, bar_size,
		HP_BAR_SLOT_TOP, HP_BAR_SLOT_TOP.lerp(HP_BAR_SLOT_BOTTOM, 0.56), HP_BAR_SLOT_BOTTOM
	)
	_draw_bar_outline(rect.position, bar_size, HP_BAR_INK_RING, 1.0)
	if tier == HpBarTier.ELITE:
		_draw_bar_outline(
			rect.position - Vector2(1.0, 1.0), bar_size + Vector2(2.0, 2.0), HP_BAR_ELITE_FRAME, 1.0
		)
	elif tier == HpBarTier.BOSS:
		_draw_bar_outline(
			rect.position - Vector2(1.0, 1.0), bar_size + Vector2(2.0, 2.0), HP_BAR_BOSS_FRAME, 1.0
		)
	# 低血警示：静态外发光环（不做逐帧脉动，避免同屏敌人全体重绘）。
	if low:
		_draw_bar_outline(
			rect.position - Vector2(1.5, 1.5), bar_size + Vector2(3.0, 3.0), HP_BAR_LOW_GLOW, 1.5
		)
	# 掉血残影：受击瞬间的旧血量白段（最窄退化为圆点）。
	if _hp_ghost_ratio > ratio:
		_draw_bar_capsule(
			inner_pos,
			Vector2(maxf(inner_size.x * _hp_ghost_ratio, inner_size.y), inner_size.y),
			HP_BAR_GHOST
		)
	# 填充：圆头 + 竖渐变（三停）+ 顶部 1px 高光。
	var fill_size := Vector2(maxf(inner_size.x * ratio, 0.0), inner_size.y)
	if fill_size.x > 0.0:
		_draw_bar_gradient(
			inner_pos, fill_size,
			HP_BAR_FILL_LOW_TOP if low else HP_BAR_FILL_TOP,
			HP_BAR_FILL_LOW_MID if low else HP_BAR_FILL_MID,
			HP_BAR_FILL_LOW_BOTTOM if low else HP_BAR_FILL_BOTTOM
		)
		if fill_size.x > inner_size.y:
			var cap := inner_size.y * 0.5
			draw_line(
				inner_pos + Vector2(cap, 0.5),
				inner_pos + Vector2(fill_size.x - cap, 0.5),
				HP_BAR_GLOSS, 1.0
			)
	# Boss 三刻度（25 / 50 / 75%）：压在填充之上，与金框配套。
	if tier == HpBarTier.BOSS:
		for tick_index in range(1, 4):
			var tick_x := inner_pos.x + inner_size.x * 0.25 * float(tick_index)
			draw_line(
				Vector2(tick_x, inner_pos.y + 1.0),
				Vector2(tick_x, inner_pos.y + inner_size.y - 1.0),
				HP_BAR_TICK, 1.0
			)


## 实心胶囊（圆头）：矩形 + 两端圆；宽度不足两倍高时退化为圆点。
func _draw_bar_capsule(pos: Vector2, size: Vector2, color: Color) -> void:
	var radius := size.y * 0.5
	if size.x <= size.y:
		draw_circle(pos + size * 0.5, maxf(size.x * 0.5, 0.0), color)
		return
	draw_rect(Rect2(pos + Vector2(radius, 0.0), Vector2(size.x - radius * 2.0, size.y)), color)
	draw_circle(pos + Vector2(radius, radius), radius, color)
	draw_circle(pos + Vector2(size.x - radius, radius), radius, color)


## 竖渐变胶囊：按顶点 y 取三停色（top → mid@56% → bottom），draw_polygon 顶点插值。
func _draw_bar_gradient(
	pos: Vector2, size: Vector2, top_color: Color, mid_color: Color, bottom_color: Color
) -> void:
	var radius := size.y * 0.5
	if size.x <= size.y:
		draw_circle(pos + size * 0.5, maxf(size.x * 0.5, 0.0), mid_color)
		return
	var points := PackedVector2Array()
	var segments := 6
	points.append(pos + Vector2(radius, 0.0))
	points.append(pos + Vector2(size.x - radius, 0.0))
	for i in range(1, segments + 1):
		var right_angle := -PI * 0.5 + PI * float(i) / float(segments)
		points.append(pos + Vector2(
			size.x - radius + cos(right_angle) * radius,
			radius + sin(right_angle) * radius
		))
	for i in range(1, segments + 1):
		var left_angle := PI * 0.5 + PI * float(i) / float(segments)
		points.append(pos + Vector2(
			radius + cos(left_angle) * radius,
			radius + sin(left_angle) * radius
		))
	var colors := PackedColorArray()
	var denom := maxf(size.y, 0.001)
	for point in points:
		var t := clampf((point.y - pos.y) / denom, 0.0, 1.0)
		colors.append(_bar_gradient_color(t, top_color, mid_color, bottom_color))
	draw_polygon(points, colors)


## 三停色采样（mid 停在 56%，与规格稿一致）。
func _bar_gradient_color(t: float, top_color: Color, mid_color: Color, bottom_color: Color) -> Color:
	if t <= 0.56:
		return top_color.lerp(mid_color, clampf(t / 0.56, 0.0, 1.0))
	return mid_color.lerp(bottom_color, clampf((t - 0.56) / 0.44, 0.0, 1.0))


## 胶囊描边：两段半圆 + 上下两条直线（与塔怒气条同款画法）。
func _draw_bar_outline(pos: Vector2, size: Vector2, color: Color, width: float) -> void:
	var radius := size.y * 0.5
	if size.x <= size.y * 2.0:
		draw_arc(pos + size * 0.5, maxf(size.x * 0.5, 0.1), 0.0, TAU, 20, color, width)
		return
	draw_arc(pos + Vector2(radius, radius), radius, PI * 0.5, PI * 1.5, 12, color, width)
	draw_arc(pos + Vector2(size.x - radius, radius), radius, -PI * 0.5, PI * 0.5, 12, color, width)
	draw_line(pos + Vector2(radius, 0.0), pos + Vector2(size.x - radius, 0.0), color, width)
	draw_line(pos + Vector2(radius, size.y), pos + Vector2(size.x - radius, size.y), color, width)
