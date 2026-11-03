extends RefCounted
class_name BehaviorRegistry
const LOB_EXPLOSION_RADIUS := 90.0
const TIGER_GUARD_COUNTER_ID := &"tiger_guard"
const CAVALRY_TAG := &"cavalry"
const TIGER_GUARD_COUNTER_MULTIPLIER := 1.15

static func ultimate_display_name(id: StringName) -> String:
	return SkillRegistry.get_skill_name(id)

static func is_passive_behavior(id: StringName) -> bool:
	return id == &"attack_speed_aura"

static func execute_attack(id: StringName, tower: Tower, target) -> bool:
	match id:
		&"single_target_precision", &"area_spell": _attack_single_target_bullet(tower, target)
		&"single_target_burst", &"melee_thrust": _attack_melee_swing(tower, target)
		&"lob_aoe": _attack_lob_aoe(tower, target)
		&"attack_speed_aura": _attack_aura_pulse(tower, target)
		_: _attack_single_target_bullet(tower, target)
	return true

static func get_profession_counter(profession_id: StringName, enemy_tags: Array[StringName]) -> float:
	if profession_id == TIGER_GUARD_COUNTER_ID and enemy_tags.has(CAVALRY_TAG):
		return TIGER_GUARD_COUNTER_MULTIPLIER
	return 1.0

static func _attack_single_target_bullet(tower: Tower, target: Enemy) -> void:
	## 弹道普攻（v0.31.4 / 0.8.6.2）：发射只创建弹道并锁定伤害；怒气与技能命中事件
	## 由子弹命中结算后回调 Tower.notify_attack_damage_dealt（目标死亡/丢失则整发作废）。
	var bullet := tower.instantiate_bullet(target)
	if bullet != null:
		bullet.damage = tower.finalize_damage(tower.damage, target, &"", false)
		bullet.counts_as_attack = true
	# 弹道类攻击表现：枪口闪光（近战类由各自执行器触发挥击表现）。
	tower.play_attack_flash()

static func _attack_melee_swing(tower: Tower, target: Enemy) -> void:
	## 近战「起手 → 命中帧结算」（0.8.16.6 / BEHAVIORS B.3.1.1）：挥击立即播，
	## 伤害与命中事件（怒气 / 命中钩子 / 命中特性）延迟到命中帧落地；伤害值在起手锁定
	## （与弹道发射锁定同源）。命中帧取值与上限见 Tower.melee_hit_delay()。
	var damage := tower.finalize_damage(tower.damage, target, &"", false)
	tower.play_melee_hit()
	tower.schedule_melee_hit(target, damage)



static func _attack_lob_aoe(tower: Tower, target: Enemy) -> void:
	## 投石车抛射：预判落点（目标当前位置 + 移动方向 × 飞行时间位移），
	## 弹体飞向落点后造成范围伤害（GDD modules/BEHAVIORS.md lob_aoe）。
	var bullet := tower.instantiate_bullet(target)
	if bullet == null:
		return
	bullet.damage = tower.finalize_damage(tower.damage, target, &"", false)
	bullet.counts_as_attack = true
	var flight_time := tower.global_position.distance_to(target.global_position) / maxf(bullet.speed, 1.0)
	var predicted := target.global_position + target.velocity_dir * target.speed * flight_time
	bullet.launch_lob(predicted, tower.splash_radius(LOB_EXPLOSION_RADIUS))


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
