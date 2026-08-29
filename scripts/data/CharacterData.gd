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

@export_category("Unlock")
@export var unlock_stage_id: StringName


func is_valid() -> bool:
	return not character_id.is_empty() and not display_name.is_empty() and profession != null
