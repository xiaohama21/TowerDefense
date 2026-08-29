extends Resource

class_name ProfessionData

enum CombatRole {
	DAMAGE,
	CONTROL,
	SUPPORT,
	HYBRID,
}

enum AttackPattern {
	SINGLE_TARGET,
	AREA,
	PIERCING,
	AURA,
}

@export_category("Identity")
@export var profession_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var combat_role: CombatRole = CombatRole.DAMAGE
@export var attack_pattern: AttackPattern = AttackPattern.SINGLE_TARGET
@export var tags: Array[StringName] = []

@export_category("Base Modifiers")
@export_range(0.0, 10.0, 0.01) var damage_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.01) var range_multiplier: float = 1.0
@export_range(0.01, 10.0, 0.01) var attack_interval_multiplier: float = 1.0
## 最小射程（px，v0.11 投石车引入）：目标距离小于该值时无法攻击，0 表示无限制。
@export_range(0.0, 2000.0, 1.0) var min_range: float = 0.0
@export var behavior_id: StringName

@export_category("Ultimate & Rage (阶段 3 字段，v0.11.1 先行铺设)")
## 职业大招行为 ID（怒气驱动，见 CHARACTERS.md 4.6）。
@export var ultimate_id: StringName
## 积怒模式：hit+damage（输出）/ support（辅助增益），默认按 combat_role 推断、可显式覆盖。
@export var rage_gain_mode: StringName
@export_range(0, 99, 1) var ultimate_gain_per_hit: int = 4
@export_range(0.0, 99.0, 0.1) var ultimate_gain_per_damage: float = 0.1
@export_range(0, 99, 1) var support_ultimate_gain_per_tick: int = 2


func is_valid() -> bool:
	return not profession_id.is_empty() and not display_name.is_empty()
