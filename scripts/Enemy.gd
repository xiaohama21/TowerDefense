extends PathFollow2D

class_name Enemy

const ENEMY_GROUP: StringName = &"enemies"
## 隐匿（NUMBERS 10.16，✅ 0.8.13.1）：破隐扫描周期与现形闪光时长。
const STEALTH_SCAN_INTERVAL: float = 0.25
const REVEAL_FLASH_DURATION: float = 0.7

@export var speed: float = 100.0
@export var max_hp: int = 100
@export var armor: int = 0
@export var reward: int = 10
@export var kill_xp: int = 0
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
var special_cooldown: float = 0.0
## 特殊行为参数（B.3.2，✅ 0.8.13.2）：EnemyManager 从 EnemyData.special_params 写入，
## armor_aura / healer_aura 按 key 读取（缺省回退 BalanceData）。
var special_params: Dictionary = {}
# 减速 debuff（术士大招/张飞咆哮/诸葛亮光环等）：取最强因子，倒计时归零解除。
var slow_factor: float = 1.0
## 召唤物标记（阶段 8 提交 2）：连击计入召唤物（P1 4.1 拍板），由召唤方设置。
var is_summon: bool = false
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

@onready var hp_bar: ProgressBar = $HpBar
@onready var body: ColorRect = $Body
var _hit_flash_left: float = 0.0

func _enter_tree() -> void:
	add_to_group(ENEMY_GROUP)


func _ready() -> void:
	# PathFollow2D defaults to looping. Enemies must stop at the base instead.
	loop = false
	rotates = false
	max_hp = maxi(max_hp, 1)
	current_hp = max_hp
	progress = 0
	if hp_bar:
		hp_bar.visible = false
	# Boss 演出（v0.15.0）：登场信号 + 血条强化。
	if tags.has(&"boss"):
		GameManager.boss_entered.emit(str(display_name))
		if hp_bar:
			hp_bar.custom_minimum_size = Vector2(84, 12)
			hp_bar.modulate = Color(1.0, 0.85, 0.4)
			hp_bar.visible = true
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
	current_hp = maxi(current_hp - effective, 0)
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
			is_summon
		)

	queue_free()


## 治疗光环目标（healer_aura）：不超过最大生命。
func heal(amount: int) -> void:
	if is_dead:
		return
	current_hp = mini(current_hp + amount, max_hp)
	update_hp_bar()


func update_hp_bar() -> void:
	if hp_bar:
		# 满血隐藏、受击后显示（v0.12.2 优化：减少画面杂乱）
		# 隐匿未现形时同样隐藏血条（✅ 0.8.13.1）。
		hp_bar.visible = current_hp < max_hp and is_revealed()
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp


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
	# 血条宽度随体型、位置贴头顶（v0.12.2 优化）
	var bar := get_node_or_null("HpBar") as ProgressBar
	if bar:
		bar.size = Vector2(maxf(body_size.x, 24.0), 6.0)
		bar.position = Vector2(-bar.size.x / 2.0, -body_size.y * 0.5 - 12.0)
	queue_redraw()


func _draw() -> void:
	if body == null:
		return
	var half := body.size * 0.5
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
		for i in range(3):
			var angle := spin + float(i) * TAU / 3.0
			draw_circle(
				Vector2(cos(angle) * 8.0, -half.y - 16.0 + sin(angle) * 3.0),
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
	# 恐惧表现（当阳桥，v0.35.2 / 0.8.10.1）：紫色呼吸圆环（与眩晕小星区分）。
	if _fear_time_left > 0.0:
		var pulse := 0.5 + 0.5 * sin(_fear_pulse * 7.0)
		draw_arc(
			Vector2.ZERO, half.length() + 7.0 + pulse * 2.5, 0.0, TAU, 28,
			Color(0.62, 0.42, 0.95, 0.45 + 0.35 * pulse), 1.8
		)
