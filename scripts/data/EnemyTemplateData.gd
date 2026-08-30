extends Resource

class_name EnemyTemplateData

## 敌人模板（GDD modules/ENEMIES.md，v0.18.0 阶段 6 试点）：新章节敌人的派生基准。
## `EnemyData.template` 引用模板后，自身字段为 0/空哨兵时继承模板值（resolved() 合并）。
## 哨兵约定：max_hp/move_speed/damage_to_base/currency_reward/kill_xp=0、
## armor=-1、special_behavior_id/tags 为空、body_color 全透明、body_size 零向量 = 继承。

@export var template_id: StringName
@export var display_name: String = ""
@export var tags: Array[StringName] = []

@export_category("Combat (0/空 = 未覆盖)")
@export_range(0, 999999, 1) var max_hp: int = 0
@export_range(0.0, 2000.0, 1.0) var move_speed: float = 0.0
## -1 = 未覆盖（0 是合法护甲值）。
@export_range(-1, 9999, 1) var armor: int = -1
@export_range(0, 9999, 1) var damage_to_base: int = 0
@export var special_behavior_id: StringName

@export_category("Rewards (0 = 未覆盖)")
@export_range(0, 99999, 1) var currency_reward: int = 0
@export_range(0, 99999, 1) var kill_xp: int = 0

@export_category("Presentation (空 = 未覆盖)")
@export var body_color: Color = Color(0, 0, 0, 0)
@export var body_size: Vector2 = Vector2.ZERO


func is_valid() -> bool:
	return not template_id.is_empty()