extends Resource

class_name EnemyData

@export_category("Identity")
@export var enemy_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var enemy_scene: PackedScene
@export var tags: Array[StringName] = []

@export_category("Combat")
@export_range(1, 999999, 1) var max_hp: int = 100
@export_range(0.0, 2000.0, 1.0) var move_speed: float = 80.0
@export_range(0, 9999, 1) var armor: int = 0
@export_range(0, 9999, 1) var damage_to_base: int = 1
@export var special_behavior_id: StringName

@export_category("Rewards")
@export_range(0, 99999, 1) var currency_reward: int = 10
@export_range(0, 99999, 1) var kill_xp: int = 8

@export_category("Presentation")
@export var body_color: Color = Color.WHITE
@export var body_size: Vector2 = Vector2(34.0, 34.0)


func is_valid() -> bool:
	return not enemy_id.is_empty() and not display_name.is_empty() and max_hp > 0
