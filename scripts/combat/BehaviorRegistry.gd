class_name BehaviorRegistry
extends RefCounted

## 最小行为注册表（GDD modules/BEHAVIORS.md）：战斗节点只按行为 ID 分发，
## 不在 Tower/Enemy 等脚本中硬编码职业/角色专属逻辑。
## 阶段 1 落地职业攻击行为（behavior_id）；大招/特性/敌人特殊行为随阶段 3 扩展。

const CAVALRY_TAG: StringName = &"cavalry"
## 虎贲职业克制：对带 cavalry 标签的敌人伤害 +15%（GDD 4.2，v0.28.0 由剑客更名）。
const TIGER_GUARD_COUNTER_ID: StringName = &"tiger_guard"
const TIGER_GUARD_COUNTER_MULTIPLIER: float = 1.15
## 投石车落点爆炸半径（GDD 4.2 抛射范围伤害，v0.11.1）。
const LOB_EXPLOSION_RADIUS: float = 90.0

## 大招显示名（v0.15.0 演出飘字）。
const ULTIMATE_NAMES := {
	&"ultimate_cavalry_breaker": "突击斩杀",
	&"ultimate_tiger_guard_sweep": "破阵",
	&"ultimate_archer_volley": "连珠齐射",
	&"ultimate_strategist_blaze": "火烧连营",
	&"ultimate_dancer_encourage": "倾城鼓舞",
	&"ultimate_catapult_barrage": "石破天惊",
}

static func ultimate_display_name(ultimate_id: StringName) -> String:
	return str(ULTIMATE_NAMES.get(ultimate_id, str(ultimate_id)))

## behavior_id -> 攻击执行器 Callable(tower: Tower, target: Enemy)
static var _attack_executors: Dictionary = {}
## ultimate_id -> 大招执行器 Callable(tower: Tower) -> bool（返回是否成功释放）
static var _ultimate_executors: Dictionary = {}

## 被动行为：无需敌方目标也持续触发（舞娘光环脉冲）。
const PASSIVE_BEHAVIORS: Array[StringName] = [&"attack_speed_aura"]


static func _ensure_registry() -> void:
	if not _attack_executors.is_empty():
		return
	# 弹道类：弓箭手/术士（单体结算，职业范围结算随阶段 3 拆分）。
	for behavior_id in [&"single_target_precision", &"area_spell"]:
		_attack_executors[behavior_id] = _attack_single_target_bullet
	# 近战类：直伤 + 武器挥击表现（无弹道）。骑兵与虎贲同属贴路近战职业。
	for behavior_id in [&"single_target_burst", &"melee_thrust"]:
		_attack_executors[behavior_id] = _attack_melee_swing
	# 抛射类：投石车，预判落点 + 范围伤害。
	_attack_executors[&"lob_aoe"] = _attack_lob_aoe
	# 被动光环类：舞娘，脉冲增益友方（无敌方目标也持续触发）。
	_attack_executors[&"attack_speed_aura"] = _attack_aura_pulse
	_ultimate_executors = {
		&"ultimate_cavalry_breaker": _ult_cavalry_breaker,
		&"ultimate_tiger_guard_sweep": _ult_tiger_guard_sweep,
		&"ultimate_archer_volley": _ult_archer_volley,
		&"ultimate_strategist_blaze": _ult_strategist_blaze,
		&"ultimate_dancer_encourage": _ult_dancer_encourage,
		&"ultimate_catapult_barrage": _ult_catapult_barrage,
	}


static func is_passive_behavior(behavior_id: StringName) -> bool:
	return PASSIVE_BEHAVIORS.has(behavior_id)


## 大招分发：按 ultimate_id 调用执行器；执行器返回 false（前置条件不满足，
## 如射程内无目标）时调用方保留怒气待发。未注册 ID 记警告并返回 false。
static func execute_ultimate(ultimate_id: StringName, tower: Tower) -> bool:
	_ensure_registry()
	var executor: Callable = _ultimate_executors.get(ultimate_id, Callable())
	if not executor.is_valid():
		push_warning("未注册的大招行为 ID：%s" % ultimate_id)
		return false
	return executor.call(tower)


## 执行一次职业攻击行为。返回 false 表示该 ID 未注册。
static func execute_attack(behavior_id: StringName, tower, target) -> bool:
	_ensure_registry()
	var executor: Callable = _attack_executors.get(behavior_id, Callable())
	if not executor.is_valid():
		push_warning("未注册的攻击行为 ID：%s" % behavior_id)
		return false
	executor.call(tower, target)
	return true


## 职业克制倍率：按职业与目标标签查询，默认 1.0。
static func get_profession_counter(profession_id: StringName, enemy_tags: Array[StringName]) -> float:
	if profession_id == TIGER_GUARD_COUNTER_ID and enemy_tags.has(CAVALRY_TAG):
		return TIGER_GUARD_COUNTER_MULTIPLIER
	return 1.0


static func _attack_single_target_bullet(tower: Tower, target: Enemy) -> void:
	## 弹道普攻（v0.31.4 / 0.8.6.2）：发射只创建弹道并锁定伤害；怒气 / 稳射等命中事件
	## 由子弹命中结算后回调 Tower.notify_attack_damage_dealt（目标死亡/丢失则整发作废）。
	var bullet := tower.instantiate_bullet(target)
	if bullet != null:
		bullet.damage = tower.finalize_damage(tower.damage, target)
		bullet.counts_as_attack = true
	# 弹道类攻击表现：枪口闪光（近战类由各自执行器触发挥击表现）。
	tower.play_attack_flash()


static func _attack_melee_swing(tower: Tower, target: Enemy) -> void:
	## 近战直伤 + 武器挥击表现；伤害走结算管线（克制/特性/增益）。
	var damage := tower.finalize_damage(tower.damage, target)
	target.take_damage(damage, tower.character_id)
	tower.notify_attack_damage_dealt(target, damage)
	tower.play_melee_hit()


## 命中后特性触发（v0.11.2）：张飞咆哮按概率减速目标。
## v0.31.4 / 0.8.6.2：由 Tower.notify_attack_damage_dealt 统一调用（近战与弹道命中共用）。
static func notify_hit_trait(tower: Tower, target: Enemy) -> void:
	if tower.get_trait_id() == &"trait_yanyan_roar":
		if randf() < tower.get_trait_param("chance", 0.3):
			target.apply_slow(
				tower.get_trait_param("slow_factor", 0.4),
				tower.get_trait_param("duration", 1.0),
			)
			tower.spawn_float_text("咆哮", Color(0.95, 0.6, 0.35))


static func _attack_lob_aoe(tower: Tower, target: Enemy) -> void:
	## 投石车抛射：预判落点（目标当前位置 + 移动方向 × 飞行时间位移），
	## 弹体飞向落点后造成范围伤害（GDD modules/BEHAVIORS.md lob_aoe）。
	var bullet := tower.instantiate_bullet(target)
	if bullet == null:
		return
	bullet.damage = tower.finalize_damage(tower.damage, target)
	bullet.counts_as_attack = true
	var flight_time := tower.global_position.distance_to(target.global_position) / maxf(bullet.speed, 1.0)
	var predicted := target.global_position + target.velocity_dir * target.speed * flight_time
	bullet.launch_lob(predicted, LOB_EXPLOSION_RADIUS * tower.get_battle_rank_aoe_multiplier())


## ============ 大招执行器（v0.11.2 数值生效，表现占位） ============
## 伤害统一走 tower.finalize_damage 管线；强度按 tower.ultimate_power() 缩放
## （10.5：×(1+0.25×局内等级)×转职倍率）。返回 false 时不清空怒气。

static func _ult_cavalry_breaker(tower: Tower) -> bool:
	# 突击斩杀：3×普攻单体；击杀返还 50% 怒气（受 charge 技能强化）。
	var target: Enemy = tower.target
	if target == null or not tower.is_target_valid(target):
		return false
	var hp_before := target.current_hp
	target.take_damage(tower.finalize_damage(int(round(tower.damage * 3.0 * tower.ultimate_power())), target), tower.character_id)
	if hp_before > 0 and target.current_hp <= 0:
		tower.gain_rage(tower.kill_rage_refund())
	tower.play_attack_flash()
	return true


static func _ult_tiger_guard_sweep(tower: Tower) -> bool:
	# 破阵：范围内敌人 1.5×普攻伤害并击退 40px + 附近 200px 友方攻速 +15%/5s（激励段）。
	var enemies := tower.enemies_in_range()
	if enemies.is_empty():
		return false
	for enemy in enemies:
		enemy.take_damage(tower.finalize_damage(int(round(tower.damage * 1.5 * tower.ultimate_power())), enemy), tower.character_id)
		enemy.progress = maxf(enemy.progress - 40.0, 0.0)
	var power_mult := tower.get_battle_rank_buff_power_multiplier()
	var duration_mult := tower.get_battle_rank_buff_duration_multiplier()
	for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var ally := node as Tower
		if ally == null or ally == tower or not is_instance_valid(ally):
			continue
		if tower.global_position.distance_to(ally.global_position) <= 200.0:
			ally.apply_attack_speed_buff("ult_tiger_guard_sweep", 1.0 + 0.15 * power_mult, 5.0 * duration_mult)
	tower.play_melee_hit()
	return true


static func _ult_archer_volley(tower: Tower) -> bool:
	# 连珠齐射：4 箭（0.8×普攻）优先低血量目标。
	var targets := tower.lowest_hp_targets_in_range(4)
	if targets.is_empty():
		return false
	for enemy in targets:
		var bullet := tower.instantiate_bullet(enemy)
		if bullet != null:
			bullet.damage = tower.finalize_damage(int(round(tower.damage * 0.8 * tower.ultimate_power())), enemy)
	tower.play_attack_flash()
	return true


static func _ult_strategist_blaze(tower: Tower) -> bool:
	# 大范围法术：目标区域 2×普攻范围伤害 + 减速 40%/2s。
	var center_target: Enemy = tower.target
	var center := Vector2.ZERO
	if center_target != null and tower.is_target_valid(center_target):
		center = center_target.global_position
	else:
		var enemies := tower.enemies_in_range()
		if enemies.is_empty():
			return false
		center = enemies[0].global_position
	for enemy in tower.enemies_in_range():
		var aoe_radius := tower.ultimate_aoe_radius(LOB_EXPLOSION_RADIUS + 30.0) * tower.get_battle_rank_aoe_multiplier()
		if enemy.global_position.distance_to(center) <= aoe_radius:
			enemy.take_damage(tower.finalize_damage(int(round(tower.damage * 2.0 * tower.ultimate_power())), enemy), tower.character_id)
			enemy.apply_slow(0.6, 2.0)
	tower.play_attack_flash()
	return true


static func _ult_dancer_encourage(tower: Tower) -> bool:
	# 全队鼓舞：攻速 +30%、伤害 +15%，持续 8 秒；升阶增强 buff 效果/时长（阶段 8）。
	var power_mult := tower.get_battle_rank_buff_power_multiplier()
	var duration_mult := tower.get_battle_rank_buff_duration_multiplier()
	for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var ally := node as Tower
		if ally != null and is_instance_valid(ally):
			ally.apply_team_buff("ult_dancer_encourage", 1.0 + 0.3 * power_mult, 1.0 + 0.15 * power_mult, 8.0 * duration_mult)
	tower.play_attack_flash()
	return true


static func _ult_catapult_barrage(tower: Tower) -> bool:
	# 投石齐射：3 连发快速抛射轰击目标区域（0.8×普攻/发）。
	var target: Enemy = tower.target
	if target == null or not tower.is_target_valid(target):
		return false
	for _i in range(3):
		var bullet := tower.instantiate_bullet(target)
		if bullet != null:
			bullet.damage = tower.finalize_damage(int(round(tower.damage * 0.8 * tower.ultimate_power())), target)
			var spread := Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
			bullet.launch_lob(target.global_position + spread, LOB_EXPLOSION_RADIUS * tower.get_battle_rank_aoe_multiplier())
	tower.play_attack_flash()
	return true


## ============ 特性与光环（v0.11.2 数值生效） ============

## 特性伤害倍率：武生（精英/Boss）、周仓（高血量）、百步穿杨（连续攻击）、火攻名家（范围）。
static func get_trait_damage_multiplier(tower: Tower, target: Enemy) -> float:
	match tower.get_trait_id():
		&"trait_wusheng":
			if target.tags.has(&"elite") or target.tags.has(&"boss"):
				return 1.0 + tower.get_trait_param("elite_damage_bonus", 0.25)
		&"trait_captain":
			if target.max_hp > 0 and float(target.current_hp) / float(target.max_hp) > 0.7:
				return 1.0 + tower.get_trait_param("high_hp_damage_bonus", 0.3)
		&"trait_hundred_step":
			var stacks := minf(float(tower.get_consecutive_hits()), tower.get_trait_param("max_stacks", 3.0))
			return 1.0 + stacks * tower.get_trait_param("step", 0.1)
		&"trait_royal_fire":
			if tower.get_behavior_id() == &"lob_aoe":
				return 1.0 + tower.get_trait_param("aoe_damage_bonus", 0.15)
	return 1.0


## 刘备仁德光环（不可叠加）：场上存在刘备塔时，其他塔伤害 +8%。
static func has_benevolence_aura(tower: Tower) -> bool:
	if tower.get_trait_id() == &"trait_benevolence":
		return false
	for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var other := node as Tower
		if other != null and other != tower and is_instance_valid(other) and other.get_trait_id() == &"trait_benevolence":
			return true
	return false


static func benevolence_bonus(tower: Tower) -> float:
	for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var other := node as Tower
		if other != null and other != tower and is_instance_valid(other) and other.get_trait_id() == &"trait_benevolence":
			return 1.0 + other.get_trait_param("aura_damage_bonus", 0.08)
	return 1.0


## 貂蝉月幕：自身大招积怒 +20%，友方大招积怒 +10%（貂蝉在场时）。
static func moon_veil_rage_multiplier(tower: Tower) -> float:
	if tower.get_trait_id() == &"trait_moon_veil":
		return 1.0 + tower.get_trait_param("self_rage_bonus", 0.2)
	for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var other := node as Tower
		if other != null and other != tower and is_instance_valid(other) and other.get_trait_id() == &"trait_moon_veil":
			return 1.0 + other.get_trait_param("ally_rage_bonus", 0.1)
	return 1.0


static func _attack_aura_pulse(tower: Tower, _target: Enemy) -> void:
	## 舞娘光环脉冲：增益射程内友方攻速 +20%/3s；升阶增强 buff 效果/时长（阶段 8）。
	## 辅助积怒与贡献经验经 gain_support_pulse 接入同一事件流。
	var power_mult := tower.get_battle_rank_buff_power_multiplier()
	var duration_mult := tower.get_battle_rank_buff_duration_multiplier()
	var allies := tower.allies_in_range()
	for ally in allies:
		ally.apply_attack_speed_buff("aura_attack", 1.0 + 0.2 * power_mult, 3.0 * duration_mult)
	tower.gain_support_pulse(allies)
	tower.play_attack_flash()
