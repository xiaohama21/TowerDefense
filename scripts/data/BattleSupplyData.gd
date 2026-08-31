extends Resource

class_name BattleSupplyData

## 局内军需（GDD 阶段 8 提交 1，NUMBERS.md 10.9）：战斗内金币即买即用的一次性道具，
## 不进入背包、不影响结算；数值以本资源为准。

@export_category("Identity")
@export var supply_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_category("Purchase")
@export_range(0, 99999, 1) var cost: int = 50
@export_range(0, 99, 1) var max_uses: int = 1

@export_category("Effects (NUMBERS.md 10.9)")
## 修整：基地生命回复量（0 = 无效）。
@export_range(0, 999, 1) var heal_amount: int = 0
## 火攻：全场敌人立即伤害 + 灼烧（burn_dps/秒，持续 effect_duration）。
@export_range(0, 9999, 1) var instant_damage: int = 0
@export_range(0, 999, 1) var burn_dps: int = 0
## 擂鼓：全队攻速加成（0.3 = +30%）；缓兵：全场减速因子（0.6 = 减速 40%）。
@export_range(0.0, 1.0, 0.01) var attack_speed_bonus: float = 0.0
@export_range(0.05, 1.0, 0.01) var slow_factor: float = 1.0
@export_range(0.0, 60.0, 0.1) var effect_duration: float = 0.0


func is_valid() -> bool:
	return not supply_id.is_empty() and not display_name.is_empty() and cost > 0 and max_uses > 0
