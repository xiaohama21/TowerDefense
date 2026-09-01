extends RefCounted

class_name TechTree

## 科技树（GDD modules/NUMBERS.md 10.7，v0.14；v0.18.0 条目配置化）：
## 三分支各 3 层，条目在 `resources/tech/tech_tree.tres`（TechItemData）。
## 全局加成合计 ≤ ±15% 强度。

const TREE_PATH := "res://resources/tech/tech_tree.tres"
const CATEGORY_ORDER: Array[String] = ["军略", "后勤", "工事", "将略"]
## 全局加成合计上限（10.7 原则）：伤害类 ≤15%、职业类 ≤10%、机制类 ≤10%。
const DAMAGE_PCT_CAP: int = 15
const PROFESSION_PCT_CAP: int = 10
const MECHANIC_PCT_CAP: int = 10

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


static func get_categories() -> Array[String]:
	return CATEGORY_ORDER.duplicate()


## 按分类取条目（分类内按 tier 升序）。
static func get_items_by_category(category: String) -> Array[TechItemData]:
	var result: Array[TechItemData] = []
	for item in get_items():
		if item.category == category:
			result.append(item)
	result.sort_custom(func(a: TechItemData, b: TechItemData) -> bool:
		if a.tier == b.tier:
			return a.id < b.id
		return a.tier < b.tier
	)
	return result


static func is_unlocked(profile: PlayerProfile, tech_id: String) -> bool:
	return profile != null and profile.has_tech(tech_id)


## 前置科技是否已解锁（无前置则 true）。
static func prerequisites_met(profile: PlayerProfile, item: TechItemData) -> bool:
	var requires: String = item.requires
	if requires.is_empty():
		return true
	return is_unlocked(profile, requires)


## 无条件重置（v0.23.0 拍板）：免费、不限次数、全额返还科技点；已解锁科技不丢失。
static func reset_tech(profile: PlayerProfile) -> int:
	if profile == null:
		return 0
	var refund := 0
	for tech_id in profile.tech_unlocks:
		var item := get_item(tech_id)
		if item != null:
			refund += item.cost
	profile.tech_unlocks.clear()
	profile.tech_points += refund
	return refund


## 汇总已解锁科技的战斗效果加成（含阶段 8 提交 3 新键，按 10.7 原则封顶）。
static func get_tech_bonuses(profile: PlayerProfile) -> Dictionary:
	var bonuses := {
		"start_gold": 0, "damage_pct": 0, "base_hp": 0,
		"wave_reward_pct": 0, "sell_refund_pct": 0, "upgrade_discount_pct": 0,
		"supply_discount_pct": 0, "rage_gain_pct": 0,
		"profession_tiger_guard_damage_pct": 0, "profession_cavalry_damage_pct": 0,
		"profession_archer_attack_speed_pct": 0, "profession_strategist_damage_pct": 0,
		"profession_dancer_buff_power_pct": 0, "profession_catapult_damage_pct": 0,
	}
	if profile == null:
		return bonuses
	for tech_id in profile.tech_unlocks:
		var item := get_item(tech_id)
		if item == null:
			continue
		for key in item.effect:
			bonuses[key] = bonuses.get(key, 0) + int(item.effect[key])
	bonuses["damage_pct"] = mini(bonuses.get("damage_pct", 0), DAMAGE_PCT_CAP)
	for key in [
		"profession_tiger_guard_damage_pct", "profession_cavalry_damage_pct",
		"profession_archer_attack_speed_pct", "profession_strategist_damage_pct",
		"profession_dancer_buff_power_pct", "profession_catapult_damage_pct",
	]:
		bonuses[key] = mini(bonuses.get(key, 0), PROFESSION_PCT_CAP)
	for key in [
		"sell_refund_pct", "upgrade_discount_pct", "supply_discount_pct", "rage_gain_pct",
	]:
		bonuses[key] = mini(bonuses.get(key, 0), MECHANIC_PCT_CAP)
	bonuses["wave_reward_pct"] = mini(bonuses.get("wave_reward_pct", 0), 40)
	return bonuses
