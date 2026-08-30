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
@export_range(-1, 9999, 1) var armor: int = 0
@export_range(0, 9999, 1) var damage_to_base: int = 1
@export var special_behavior_id: StringName
## 敌人模板（v0.18.0，GDD modules/ENEMIES.md）：引用模板后 0/空哨兵字段继承模板值。
@export var template: EnemyTemplateData

@export_category("Rewards")
@export_range(0, 99999, 1) var currency_reward: int = 10
@export_range(0, 99999, 1) var kill_xp: int = 8

@export_category("Presentation")
@export var body_color: Color = Color.WHITE
@export var body_size: Vector2 = Vector2(34.0, 34.0)


func is_valid() -> bool:
	return not enemy_id.is_empty() and not display_name.is_empty() and max_hp > 0


## 模板合并（v0.18.0，GDD modules/ENEMIES.md）：无模板返回自身；
## 引用模板时，0/空哨兵字段取模板值，返回合并副本（EnemyManager 生成时自动应用）。
func resolved() -> EnemyData:
	if template == null:
		return self
	var copy := duplicate(true) as EnemyData
	copy.template = null
	if copy.max_hp <= 0:
		copy.max_hp = template.max_hp
	if copy.move_speed <= 0.0:
		copy.move_speed = template.move_speed
	if copy.armor < 0:
		copy.armor = template.armor
	if copy.damage_to_base <= 0:
		copy.damage_to_base = template.damage_to_base
	if copy.currency_reward <= 0:
		copy.currency_reward = template.currency_reward
	if copy.kill_xp <= 0:
		copy.kill_xp = template.kill_xp
	if copy.special_behavior_id.is_empty():
		copy.special_behavior_id = template.special_behavior_id
	if copy.tags.is_empty():
		copy.tags = template.tags.duplicate()
	if copy.body_color.a <= 0.0:
		copy.body_color = template.body_color
	if copy.body_size == Vector2.ZERO:
		copy.body_size = template.body_size
	return copy
