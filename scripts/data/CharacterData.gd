extends Resource

class_name CharacterData

@export_category("Identity")
@export var character_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var portrait: Texture2D
@export var profession: ProfessionData
@export var tags: Array[StringName] = []

@export_category("Deployment")
@export_range(0, 9999, 1) var build_cost: int = 50
@export_range(0, 99999, 1) var base_damage: int = 40
@export_range(0.0, 2000.0, 1.0) var base_range: float = 150.0
@export_range(0.01, 60.0, 0.01) var attack_interval: float = 0.8
@export_range(0.0, 5000.0, 1.0) var projectile_speed: float = 400.0

@export_category("Growth")
@export_range(0.0, 1000.0, 0.1) var damage_growth_per_level: float = 4.0
@export_range(0.0, 100.0, 0.1) var range_growth_per_level: float = 0.0
@export var promotion_ids: Array[StringName] = []

@export_category("Title (v0.28 角色称号，纯记录无机制)")
## 原角色专属转职名保留为角色称号（CHARACTERS.md 4.5 称号表），仅作展示/记录。
@export var titles: Array[String] = []

@export_category("Character Skill (阶段 8·提交 6，CHARACTER_SKILLS.md v0.1)")
## 角色专属技能 ID（武将差异化；A 主动冷却 / B 条件触发，与职业技能解耦、不参与档位）。
@export var character_skill_id: StringName
## 角色技能数值参数（行为脚本按 ID 读取，复用 skill_params 模式）。
@export var character_skill_params: Dictionary = {}

@export_category("Trait & Ultimate (阶段 3 字段，v0.11.1 先行铺设)")
## 常驻被动特性 ID（行为脚本按 ID 注册，见 CHARACTERS.md 4.7）。
@export var trait_id: StringName
## 特性数值参数，行为脚本按 ID 读取，避免为每个特性改数据类。
@export var trait_params: Dictionary = {}
## 角色专属大招覆盖（远期，预留；空则用职业默认大招）。
@export var ultimate_override_id: StringName
## 角色级积怒模式覆盖（v0.11.2 勘误：空则按职业默认/combat_role 推断；刘备=support）。
@export var rage_gain_mode_override: StringName

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


## 静态特性射程加成倍率（Tower.apply_character 与百科预览共用；当前仅观星）。
func get_static_range_multiplier() -> float:
	if trait_id == &"trait_star_gazer":
		return 1.0 + float(trait_params.get("range_bonus", 0.12))
	return 1.0


func is_valid() -> bool:
	return not character_id.is_empty() and not display_name.is_empty() and profession != null


## 按等级与转职计算实战属性（GDD modules/NUMBERS.md 10.2）：
## 伤害/射程为加法成长后乘转职倍率，攻速为 interval 直接乘转职倍率（越小越快）。
## 战斗建造与养成界面共用此实现，保证两处所见一致。
func compute_stats_at(level: int, promotion: PromotionData = null, stars: int = 0, relic: RelicData = null, battle_rank: int = 0) -> Dictionary:
	var effective_level := maxi(level, 1)
	var promo_damage := promotion.damage_multiplier if promotion != null else 1.0
	var promo_range := promotion.range_multiplier if promotion != null else 1.0
	var promo_interval := promotion.attack_interval_multiplier if promotion != null else 1.0
	var level_steps := effective_level - 1
	# 升星（GDD 4.8）：成长系数 +5%/星（不加直接数值）。
	var star_growth := damage_growth_per_level * (1.0 + 0.05 * clampi(stars, 0, 5))
	var relic_range := relic.range_bonus if relic != null else 0.0
	var relic_interval := relic.attack_interval_factor if relic != null else 1.0
	var stats := {
		"damage": int(round((base_damage + star_growth * level_steps) * promo_damage)),
		"range": (base_range + range_growth_per_level * level_steps) * promo_range + relic_range,
		"attack_interval": attack_interval * promo_interval * relic_interval,
		"min_range": profession.min_range if profession != null else 0.0,
	}
	# 局内升阶预览（ENCYCLOPEDIA §2.2/§4，默认 0 不影响既有调用）：
	# 伤害/射程乘 rank_scale、攻速 interval 取倒数同式，与 Tower.apply_battle_rank 共享实现。
	if battle_rank > 0:
		var steps := get_battle_rank_steps()
		stats.damage = int(round(int(stats.damage) * rank_scale(steps.damage, battle_rank)))
		stats.range = float(stats.range) * rank_scale(steps.range, battle_rank)
		stats.attack_interval = float(stats.attack_interval) / rank_scale(steps.attack_speed, battle_rank)
	return stats

