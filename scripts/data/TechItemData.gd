extends Resource

class_name TechItemData

## 科技树条目（GDD modules/NUMBERS.md 10.7，v0.18.0 配置化）：
## 三分支各 3 层，条目配置在 `resources/tech/tech_tree.tres`。
## 字段名与 v0.14 代码字典保持一致（id/branch/tier/name/desc/cost/requires/effect）。

@export var id: String = ""
@export var branch: String = ""
## 科技分类（阶段 8 提交 3，v0.23.0 拍板）：军略（职业强化）/后勤（经济节奏）/工事（防御）/将略（机制）。
@export var category: String = ""
@export_range(1, 3, 1) var tier: int = 1
@export var name: String = ""
## 一行摘要（列表展示，成语/词语命名见 name）。
@export var summary: String = ""
## 详细描述与数值（点击条目后展示）。
@export var description: String = ""
@export var desc: String = ""
@export_range(1, 99, 1) var cost: int = 1
## 前置科技 id（空 = 无前置）。
@export var requires: String = ""
## 效果键值（start_gold / damage_pct / base_hp），与存档/战斗加成读取一致。
@export var effect: Dictionary = {}


func is_valid() -> bool:
	return not id.is_empty() and not category.is_empty() and not name.is_empty() \
		and not summary.is_empty() and cost > 0 and not effect.is_empty()
