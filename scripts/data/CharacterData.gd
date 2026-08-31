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
@export var initial_skill_ids: Array[StringName] = []
@export var promotion_ids: Array[StringName] = []

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


func is_valid() -> bool:
	return not character_id.is_empty() and not display_name.is_empty() and profession != null


## 按等级与转职计算实战属性（GDD modules/NUMBERS.md 10.2）：
## 伤害/射程为加法成长后乘转职倍率，攻速为 interval 直接乘转职倍率（越小越快）。
## 战斗建造与养成界面共用此实现，保证两处所见一致。
func compute_stats_at(level: int, promotion: PromotionData = null, stars: int = 0, relic: RelicData = null) -> Dictionary:
	var effective_level := maxi(level, 1)
	var promo_damage := promotion.damage_multiplier if promotion != null else 1.0
	var promo_range := promotion.range_multiplier if promotion != null else 1.0
	var promo_interval := promotion.attack_interval_multiplier if promotion != null else 1.0
	var level_steps := effective_level - 1
	# 升星（GDD 4.8）：成长系数 +5%/星（不加直接数值）。
	var star_growth := damage_growth_per_level * (1.0 + 0.05 * clampi(stars, 0, 5))
	var relic_range := relic.range_bonus if relic != null else 0.0
	var relic_interval := relic.attack_interval_factor if relic != null else 1.0
	return {
		"damage": int(round((base_damage + star_growth * level_steps) * promo_damage)),
		"range": (base_range + range_growth_per_level * level_steps) * promo_range + relic_range,
		"attack_interval": attack_interval * promo_interval * relic_interval,
		"min_range": profession.min_range if profession != null else 0.0,
	}
