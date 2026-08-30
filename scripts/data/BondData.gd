extends Resource

class_name BondData

## 羁绊（GDD modules/CHARACTERS.md 4.8，v0.17.0 阶段 6 试点）：编队组合加成。
## 全部成员上场（满员）即激活；成员含未登场武将时为预览（不可激活）。

@export var bond_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## 成员武将 id（全部上场即激活）。
@export var member_ids: Array[StringName] = []
## 同队攻击加成（finalize_damage 乘法区，v0.17.0）。
@export_range(0.0, 1.0, 0.001) var damage_bonus: float = 0.0


func is_valid() -> bool:
	return not bond_id.is_empty() and not display_name.is_empty() and member_ids.size() >= 2