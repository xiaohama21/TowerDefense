extends Resource

class_name CharacterData

@export_category("Identity")
@export var character_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var portrait: Texture2D
@export var profession: ProfessionData
@export var tags: Array[StringName] = []
@export var talent_tree_ids: Array[String] = []

@export_category("Deployment")
@export_range(0, 9999, 1) var build_cost: int = 50
@export_range(0, 99999, 1) var base_damage: int = 40
@export_range(0.0, 2000.0, 1.0) var base_range: float = 150.0
@export_range(0.01, 60.0, 0.01) var attack_interval: float = 0.8
@export_range(0.0, 5000.0, 1.0) var projectile_speed: float = 400.0

@export_category("Growth")
@export_range(0.0, 1.0, 0.0001) var attack_pct: float = 0.027
@export_range(0.0, 1.0, 0.0001) var range_pct_per_level: float = 0.0
@export_range(0.0, 1.0, 0.0001) var speed_pct_per_level: float = 0.0
@export_range(0.0, 1.0, 0.001) var per_rank_crit_rate: float = 0.0
@export_range(0.0, 1.0, 0.001) var per_rank_crit_damage: float = 0.0
@export_range(0.0, 1.0, 0.001) var per_rank_skill_amp: float = 0.0

@export_category("Title (v0.28 角色称号，纯记录无机制)")
## 原角色专属转职名保留为角色称号（CHARACTERS.md 4.5 称号表），仅作展示/记录。
@export var titles: Array[String] = []

@export_category("Three Skills")
@export var passive_ids: Array[StringName] = []
@export var ultimate_id: StringName
@export var skill_params: Dictionary = {}
@export var rage_gain_mode: StringName = &"hit+damage"
@export var rage_gain_per_hit: int = 4
@export var rage_gain_per_damage: float = 0.1
@export var support_rage_per_tick: int = 2

func get_skill_ids() -> Array[StringName]:
	var ids: Array[StringName] = passive_ids.duplicate()
	ids.append(ultimate_id)
	return ids

func is_skill_unlocked(skill_id: StringName, rank: int) -> bool:
	if skill_id == ultimate_id and not skill_id.is_empty():
		return true
	var slot := passive_ids.find(skill_id)
	return slot >= 0 and rank >= slot + 1

func skill_param(skill_id: StringName, key: String, fallback: float = 0.0) -> float:
	var params: Dictionary = skill_params.get(str(skill_id), {})
	return float(params.get(key, fallback))

func skill_strength(skill_id: StringName, rank: int, levels: Dictionary = {}, equipment_amp: float = 0.0) -> float:
	return SkillRegistry.level_multiplier(int(levels.get(str(skill_id), 1))) * (1.0 + per_rank_skill_amp * clampi(rank, 0, 5) + equipment_amp)

@export_category("Battle Rank Override (阶段 8，NUMBERS.md 10.9)")
## 角色级局内升阶步进覆盖（-1 = 继承职业配置；辅助定位角色如刘备在此配置辅助行数值）。
@export_range(-1.0, 1.0, 0.01) var battle_rank_damage_step_override: float = -1.0
@export_range(-1.0, 1.0, 0.01) var battle_rank_attack_speed_step_override: float = -1.0
@export_range(-1.0, 1.0, 0.01) var battle_rank_range_step_override: float = -1.0
@export_range(-1.0, 1.0, 0.01) var battle_rank_aoe_step_override: float = -1.0
@export_range(-1.0, 1.0, 0.01) var battle_rank_buff_duration_step_override: float = -1.0
@export_range(-1.0, 1.0, 0.01) var battle_rank_buff_power_step_override: float = -1.0

@export_category("Unlock")
@export var unlock_stage_id: StringName


## 局内升阶倍率来源（ENCYCLOPEDIA §4，NUMBERS.md 10.9）：倍率 = 1 + 步进 × 阶数。
## Tower.apply_battle_rank 与百科预览共用本实现，禁止另写一套公式。
static func rank_scale(step: float, rank: int) -> float:
	return 1.0 + step * maxi(rank, 0)


## 局内升阶步进解析（角色覆盖 -1 = 继承职业配置）。
func _resolve_rank_step(override_value: float, profession_default: float) -> float:
	return override_value if override_value >= 0.0 else profession_default


## 解析后的升阶步进（Tower 与百科预览共用同一来源）。
func get_battle_rank_steps() -> Dictionary:
	var prof := profession
	var defaults := {
		"damage": prof.battle_rank_damage_step if prof != null else 0.25,
		"attack_speed": prof.battle_rank_attack_speed_step if prof != null else 0.0,
		"range": prof.battle_rank_range_step if prof != null else 0.0,
		"aoe": prof.battle_rank_aoe_step if prof != null else 0.0,
		"buff_duration": prof.battle_rank_buff_duration_step if prof != null else 0.0,
		"buff_power": prof.battle_rank_buff_power_step if prof != null else 0.0,
	}
	return {
		"damage": _resolve_rank_step(battle_rank_damage_step_override, defaults.damage),
		"attack_speed": _resolve_rank_step(battle_rank_attack_speed_step_override, defaults.attack_speed),
		"range": _resolve_rank_step(battle_rank_range_step_override, defaults.range),
		"aoe": _resolve_rank_step(battle_rank_aoe_step_override, defaults.aoe),
		"buff_duration": _resolve_rank_step(battle_rank_buff_duration_step_override, defaults.buff_duration),
		"buff_power": _resolve_rank_step(battle_rank_buff_power_step_override, defaults.buff_power),
	}


func is_valid() -> bool:
	return not character_id.is_empty() and not display_name.is_empty() and profession != null


## Bare growth and legacy guard are compared before relics and battle modifiers.
func bare_stats_at(level: int, rank: int = 0) -> Dictionary:
	var r := clampi(rank, 0, 5)
	var steps := clampi(level, 1, 100) - 1
	return {
		"attack": int(round(base_damage * (1.0 + attack_pct * steps) * CharacterRank.ATTACK[r])),
		"range": base_range * (1.0 + range_pct_per_level * steps) * CharacterRank.RANGE[r],
		"attack_interval": attack_interval / (1.0 + speed_pct_per_level * steps) / CharacterRank.SPEED[r],
	}

func remaining_guard(level: int, rank: int, guard: Dictionary) -> Dictionary:
	var result := CharacterRank.normalize_guard(guard)
	var bare := bare_stats_at(level, rank)
	for key in result.keys():
		var caught_up := float(bare[key]) <= float(result[key]) if key == "attack_interval" else float(bare[key]) >= float(result[key])
		if caught_up:
			result.erase(key)
	return result

func compute_stats_at(level: int, rank: int = 0, relic: RelicData = null, battle_rank: int = 0, guard: Dictionary = {}, skill_levels: Dictionary = {}, weapon: WeaponData = null, talent_alloc: Dictionary = {}) -> Dictionary:
	var r := clampi(rank, 0, 5)
	var equipment := WeaponRegistry.bonuses(weapon, self)
	var talents := TalentRegistry.bonuses(str(character_id), TalentRegistry.normalize(str(character_id), level, talent_alloc))
	var equipment_amp := float(equipment.get("skill_amp", 0.0)) + float(talents.get("skill_amp", 0.0))
	var range_pct := float(equipment.get("range_pct", 0.0)) + float(talents.get("range_pct", 0.0))
	var bare := bare_stats_at(level, r)
	var protected := CharacterRank.normalize_guard(guard)
	for key in protected:
		bare[key] = minf(float(bare[key]), float(protected[key])) if key == "attack_interval" else maxf(float(bare[key]), float(protected[key]))
	var steps := clampi(level, 1, 100) - 1
	var bonus := clampi(relic.level_bonus, 0, 5) if relic != null else 0
	# Apply only the extra growth ratio to the protected bare value.
	var new_attack := base_damage * (1.0 + attack_pct * (steps + bonus)) * CharacterRank.ATTACK[r]
	if float(protected.get("attack", 0.0)) > float(bare_stats_at(level, r).attack):
		new_attack = float(bare.attack) * (1.0 + attack_pct * (steps + bonus)) / (1.0 + attack_pct * steps)
	var attack_key := "magic_attack_flat" if profession != null and profession.attack_damage_type == &"magic" else "physical_attack_flat"
	new_attack += float(equipment.get(attack_key, 0.0)) * (1.0 + attack_pct * (steps + bonus)) * CharacterRank.ATTACK[r]
	bare.attack = int(round(new_attack * (1.0 + float(talents.get("attack_pct", 0.0)))))
	bare.range = float(bare.range) * (1.0 + range_pct_per_level * (steps + bonus)) / (1.0 + range_pct_per_level * steps) + (relic.range_bonus if relic != null else 0.0)
	bare.attack_interval = float(bare.attack_interval) * (1.0 + speed_pct_per_level * steps) / (1.0 + speed_pct_per_level * (steps + bonus)) * (relic.attack_interval_factor if relic != null else 1.0)
	bare.attack_interval /= 1.0 + float(talents.get("speed_pct", 0.0))
	var stats := {
		"attack": int(bare.attack), "damage": int(bare.attack), "range": float(bare.range),
		"attack_interval": float(bare.attack_interval), "min_range": profession.min_range if profession != null else 0.0,
		"crit_rate": clampf(0.05 + per_rank_crit_rate * r + float(equipment.get("crit_rate", 0.0)) + float(talents.get("crit_rate", 0.0)), 0.0, 0.75),
		"crit_damage": 1.5 + per_rank_crit_damage * r + float(equipment.get("crit_damage", 0.0)) + float(talents.get("crit_damage", 0.0)), "skill_amp": per_rank_skill_amp * r + equipment_amp,
		"projectile_speed": projectile_speed + float(equipment.get("projectile_flat", 0.0)),
		"equipment": equipment,
		"talents": talents,
	}
	# Permanent skills share this path with combat, development and encyclopedia.
	for id in passive_ids:
		if not is_skill_unlocked(id, r):
			continue
		var power := skill_strength(id, r, skill_levels, equipment_amp)
		var params: Dictionary = skill_params.get(str(id), {})
		if id == &"passive_worship_moon":
			if battle_rank >= int(params.get("battle_rank", 3)):
				stats.skill_amp += float(params.get("skill_amp", 0.05)) * SkillRegistry.level_multiplier(int(skill_levels.get(str(id), 1)))
			continue
		if id == &"passive_fierce_flame":
			stats.damage += int(round(float(params.get("attack_flat", 0.0)) * power * (1.0 + attack_pct * (steps + bonus)) * CharacterRank.ATTACK[r] * (1.0 + float(talents.get("attack_pct", 0.0)))))
			stats.attack = stats.damage
			stats.range += float(params.get("range_flat", 0.0)) * power
		if id == &"trait_star_gazer":
			range_pct += float(params.get("range_bonus", 0.0)) * power
		if id == &"trait_dragon_spirit":
			stats.crit_damage += float(params.get("crit_damage", 0.0)) * power
		if id == &"passive_dragon_courage":
			stats.crit_rate = clampf(float(stats.crit_rate) + float(params.get("crit_rate", 0.0)) * power, 0.0, 0.75)

	stats.range = (float(stats.range) + float(equipment.get("range_flat", 0.0))) * (1.0 + range_pct)
	if battle_rank > 0:
		var steps_battle := get_battle_rank_steps()
		stats.damage = int(round(int(stats.damage) * rank_scale(steps_battle.damage, battle_rank)))
		stats.attack = stats.damage
		stats.range = float(stats.range) * rank_scale(steps_battle.range, battle_rank)
		stats.attack_interval = float(stats.attack_interval) / rank_scale(steps_battle.attack_speed, battle_rank)
	return stats
