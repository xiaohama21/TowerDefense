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
@export var behavior_id: StringName


func is_valid() -> bool:
	return not profession_id.is_empty() and not display_name.is_empty()
