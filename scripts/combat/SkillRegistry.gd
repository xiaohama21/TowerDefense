extends RefCounted

class_name SkillRegistry

## 转职技能注册表（GDD modules/BEHAVIORS.md B.3.5，v0.15.0）：
## 技能 = 转职授予的被动/条件触发能力；战斗脚本只调用钩子，不在
## Tower/Enemy 等脚本中写死技能逻辑。数值经 PromotionData.skill_params 读取，
## 档位系数 s = 1 + 0.1 × min(battle_rank/5, 4)（每 5 阶一档，上限 +40%）。

const MAX_TIERS := 4
const TIER_STEP := 0.1

const SKILL_NAMES := {
	&"charge": "蓄力",
	&"ferocity": "凶威",
	&"command": "统军令",
	&"steady": "稳射",
	&"inspire": "鼓舞",
	&"siege": "攻城锤",
	&"bulwark": "斩获",
	&"dragon_rush": "龙突",
	&"wisdom": "奇谋",
}

const KNOWN_SKILLS: Array[StringName] = [
	&"charge", &"ferocity", &"command", &"steady", &"inspire",
	&"siege", &"bulwark", &"dragon_rush", &"wisdom",
]


## 档位系数：s = 1 + 0.1 × min(battle_rank/5, 4)。
static func tier_multiplier(tower: Tower) -> float:
	var tiers := mini(int(tower.battle_rank / 5), MAX_TIERS)
	return 1.0 + TIER_STEP * tiers


static func get_skill_name(skill_id: StringName) -> String:
	return str(SKILL_NAMES.get(skill_id, str(skill_id)))


static func has_skill(tower: Tower, skill_id: StringName) -> bool:
	return tower != null and is_instance_valid(tower) and tower.has_skill(skill_id)


## 技能参数（基准值 × 档位系数）。未持有技能时返回默认值。
static func param(tower: Tower, skill_id: StringName, key: String, default: float) -> float:
	if not has_skill(tower, skill_id):
		return default
	return float(tower.get_skill_param(skill_id, key, default))


## 攻击命中钩子（普攻结算后由行为执行器调用）。
static func on_attack_hit(tower: Tower, target: Enemy, _dealt: int) -> void:
	if not has_skill(tower, &"ferocity") and not has_skill(tower, &"steady"):
		return
	if target == null or target.is_dead:
		return
	var s := tier_multiplier(tower)
	if has_skill(tower, &"ferocity") and randf() < param(tower, &"ferocity", "chance", 0.15):
		var extra := int(round(tower.damage * param(tower, &"ferocity", "mult", 0.5) * s))
		if extra > 0:
			target.take_damage(tower.finalize_damage(extra, target), tower.character_id)
			tower.spawn_float_text(get_skill_name(&"ferocity"), Color(0.95, 0.5, 0.3))
			tower.play_skill_effect(Color(0.95, 0.5, 0.3))
			SfxLibrary.play(&"skill", -8.0)
	if has_skill(tower, &"steady") and randf() < param(tower, &"steady", "chance", 0.2):
		var extra := int(round(tower.damage * param(tower, &"steady", "mult", 0.6) * s))
		if extra > 0:
			target.take_damage(tower.finalize_damage(extra, target), tower.character_id)
			tower.spawn_float_text(get_skill_name(&"steady"), Color(1.0, 0.9, 0.4))
			tower.play_skill_effect(Color(1.0, 0.9, 0.4))
			SfxLibrary.play(&"skill", -8.0)


## 击杀钩子（Enemy 死亡结算后由 Tower 订阅调用）。
static func on_kill(tower: Tower, _enemy: Enemy) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	var s := tier_multiplier(tower)
	if has_skill(tower, &"bulwark"):
		var bonus := int(round(param(tower, &"bulwark", "gold", 2.0) * s))
		if bonus > 0:
			GameManager.gold += bonus
			tower.spawn_float_text("%s +%d" % [get_skill_name(&"bulwark"), bonus], Color(1.0, 0.85, 0.4))
			tower.play_skill_effect(Color(1.0, 0.85, 0.4))
			SfxLibrary.play(&"kill", -9.0)
	if has_skill(tower, &"dragon_rush"):
		var bonus := param(tower, &"dragon_rush", "next_hit_bonus", 0.25) * s
		tower.set_next_attack_bonus(bonus)
		tower.spawn_float_text(get_skill_name(&"dragon_rush"), Color(0.6, 0.9, 1.0))
		tower.play_skill_effect(Color(0.6, 0.9, 1.0))
		SfxLibrary.play(&"skill", -8.0)


## 大招释放钩子（大招执行器成功后调用）。
static func on_ultimate_cast(tower: Tower) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	var s := tier_multiplier(tower)
	SfxLibrary.play(&"ultimate", -6.0)
	tower.play_skill_effect(Color(1.0, 0.8, 0.95))
	if has_skill(tower, &"inspire"):
		var speed_bonus := param(tower, &"inspire", "team_speed_bonus", 0.06) * s
		# 升阶 buff 增强（阶段 8）：施加方升阶后效果/时长放大。
		var duration := param(tower, &"inspire", "duration", 8.0) * tower.get_battle_rank_buff_duration_multiplier()
		speed_bonus *= tower.get_battle_rank_buff_power_multiplier()
		for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
			var ally := node as Tower
			if ally != null and is_instance_valid(ally):
				ally.apply_attack_speed_buff(1.0 + speed_bonus, duration)
		tower.spawn_float_text(get_skill_name(&"inspire"), Color(1.0, 0.75, 0.9))
	if has_skill(tower, &"wisdom"):
		tower.spawn_float_text(get_skill_name(&"wisdom"), Color(0.7, 0.85, 1.0))


## 常驻伤害倍率（叠加进 Tower.finalize_damage）：刘备·统军令光环 + 皇甫嵩·攻城锤。
static func passive_damage_multiplier(tower: Tower, target: Enemy) -> float:
	var multiplier := 1.0
	if has_skill(tower, &"siege") and (target.tags.has(&"elite") or target.tags.has(&"boss")):
		multiplier *= 1.0 + param(tower, &"siege", "elite_damage_bonus", 0.1) * tier_multiplier(tower)
	if has_skill(tower, &"command"):
		# 自身不吃统军令（周围友方受益）。
		multiplier *= 1.0
	for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var other := node as Tower
		if other == null or other == tower or not is_instance_valid(other):
			continue
		if not has_skill(other, &"command"):
			continue
		var radius := param(other, &"command", "radius", 150.0)
		if tower.global_position.distance_to(other.global_position) <= radius:
			multiplier *= 1.0 + param(other, &"command", "ally_damage_bonus", 0.04) * tier_multiplier(other)
	return multiplier


## 大招范围倍率（诸葛亮·奇谋，供术士大招计算爆炸半径）。
static func ultimate_aoe_radius_multiplier(tower: Tower) -> float:
	if has_skill(tower, &"wisdom"):
		return 1.0 + param(tower, &"wisdom", "aoe_radius_bonus", 0.1) * tier_multiplier(tower)
	return 1.0


## 大招击杀返怒（关羽·charge 强化；无 charge 时返回职业基础 50%）。
static func kill_rage_refund(tower: Tower) -> float:
	if has_skill(tower, &"charge"):
		return param(tower, &"charge", "base_refund", 50.0) * tier_multiplier(tower)
	return 50.0
