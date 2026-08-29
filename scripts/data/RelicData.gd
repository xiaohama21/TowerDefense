extends Resource

class_name RelicData

## 信物（GDD modules/CHARACTERS.md 4.8）：绑定武将的固定效果专属道具。
## 无自由词条——效果键固定为伤害/射程/攻速三类加成。

@export var relic_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## 绑定武将（该武将才能装备）。
@export var character_id: StringName
## 全伤害加成（0.12 = +12%）。
@export_range(0.0, 1.0, 0.01) var damage_bonus: float = 0.0
## 射程加成（0.15 = +15%）。
@export_range(0.0, 1.0, 0.01) var range_bonus: float = 0.0
## 攻速倍率（0.9 = 快 10%）。
@export_range(0.1, 2.0, 0.01) var attack_interval_factor: float = 1.0
## 兑换所需碎片。
@export_range(0, 999, 1) var shard_cost: int = 60
