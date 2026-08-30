extends Resource

class_name BattleRelicData

## 局内遗物（GDD modules/CHARACTERS.md 4.8，v0.19.0 阶段 7）：出征前选带、仅本局生效。
## relic_id 即 items 库存的 item_id（背包可见）；效果字段 0/1.0 = 无效。
## 伤害加成走 finalize_damage 乘法区；攻速/射程乘算；初始金币/基地生命加算。

@export_category("Identity")
@export var relic_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_category("Effects (0/1.0 = 无效)")
## 全伤害 +%（finalize_damage 乘法区，与科技/信物/羁绊叠加）。
@export_range(0, 100, 1) var damage_bonus_pct: int = 0
## 攻速倍率（<1 更快；1.0 = 无效）。
@export_range(0.5, 2.0, 0.01) var attack_interval_factor: float = 1.0
## 射程 +%（乘算）。
@export_range(0, 200, 1) var range_bonus_pct: int = 0
## 初始金币 +（加算）。
@export_range(0, 9999, 1) var start_gold: int = 0
## 基地生命 +（加算）。
@export_range(0, 999, 1) var base_hp_bonus: int = 0


func is_valid() -> bool:
	return not relic_id.is_empty() and not display_name.is_empty() and _has_any_effect()


func _has_any_effect() -> bool:
	return damage_bonus_pct > 0 or not is_equal_approx(attack_interval_factor, 1.0) \
		or range_bonus_pct > 0 or start_gold > 0 or base_hp_bonus > 0
