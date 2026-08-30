extends Resource

class_name TechItemData

## 科技树条目（GDD modules/NUMBERS.md 10.7，v0.18.0 配置化）：
## 三分支各 3 层，条目配置在 `resources/tech/tech_tree.tres`。
## 字段名与 v0.14 代码字典保持一致（id/branch/tier/name/desc/cost/requires/effect）。

@export var id: String = ""
@export var branch: String = ""
@export_range(1, 3, 1) var tier: int = 1
@export var name: String = ""
@export var desc: String = ""
@export_range(1, 99, 1) var cost: int = 1
## 前置科技 id（空 = 无前置）。
@export var requires: String = ""
## 效果键值（start_gold / damage_pct / base_hp），与存档/战斗加成读取一致。
@export var effect: Dictionary = {}


func is_valid() -> bool:
	return not id.is_empty() and not branch.is_empty() and not name.is_empty() and cost > 0 and not effect.is_empty()