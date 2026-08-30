extends RefCounted

class_name TechTree

## 科技树（GDD modules/NUMBERS.md 10.7，v0.14；v0.18.0 条目配置化）：
## 三分支各 3 层，条目在 `resources/tech/tech_tree.tres`（TechItemData）。
## 全局加成合计 ≤ ±15% 强度。

const TREE_PATH := "res://resources/tech/tech_tree.tres"

static var _cached: Array[TechItemData] = []


static func get_items() -> Array[TechItemData]:
	if _cached.is_empty():
		var tree := load(TREE_PATH) as TechTreeData
		if tree != null:
			_cached = tree.items
	return _cached


static func get_item(tech_id: String) -> TechItemData:
	for item in get_items():
		if item.id == tech_id:
			return item
	return null


static func is_unlocked(profile: PlayerProfile, tech_id: String) -> bool:
	return profile != null and profile.has_tech(tech_id)


## 前置科技是否已解锁（无前置则 true）。
static func prerequisites_met(profile: PlayerProfile, item: TechItemData) -> bool:
	var requires: String = item.requires
	if requires.is_empty():
		return true
	return is_unlocked(profile, requires)


## 汇总已解锁科技的战斗效果加成。
static func get_tech_bonuses(profile: PlayerProfile) -> Dictionary:
	var bonuses := {"start_gold": 0, "damage_pct": 0, "base_hp": 0}
	if profile == null:
		return bonuses
	for tech_id in profile.tech_unlocks:
		var item := get_item(tech_id)
		if item == null:
			continue
		for key in item.effect:
			bonuses[key] = bonuses.get(key, 0) + int(item.effect[key])
	return bonuses