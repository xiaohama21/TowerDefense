extends RefCounted

class_name TechTree

## 科技树（GDD modules/NUMBERS.md 10.7，v0.14）：三分支各 3 层。
## 全局加成合计 ≤ ±15% 强度。

const ITEMS := [
	{"id": "eco_gold_1", "branch": "经济", "tier": 1, "name": "军资扩编", "desc": "初始金币 +20", "cost": 1, "effect": {"start_gold": 20}},
	{"id": "eco_gold_2", "branch": "经济", "tier": 2, "name": "粮草丰盈", "desc": "初始金币 +40", "cost": 2, "effect": {"start_gold": 40}, "requires": "eco_gold_1"},
	{"id": "eco_gold_3", "branch": "经济", "tier": 3, "name": "国库充盈", "desc": "初始金币 +60", "cost": 3, "effect": {"start_gold": 60}, "requires": "eco_gold_2"},
	{"id": "mil_dmg_1", "branch": "军事", "tier": 1, "name": "精兵操练", "desc": "全武将伤害 +2%", "cost": 1, "effect": {"damage_pct": 2}},
	{"id": "mil_dmg_2", "branch": "军事", "tier": 2, "name": "老兵经验", "desc": "全武将伤害 +4%", "cost": 2, "effect": {"damage_pct": 4}, "requires": "mil_dmg_1"},
	{"id": "mil_dmg_3", "branch": "军事", "tier": 3, "name": "百战精锐", "desc": "全武将伤害 +6%", "cost": 3, "effect": {"damage_pct": 6}, "requires": "mil_dmg_2"},
	{"id": "inf_hp_1", "branch": "基建", "tier": 1, "name": "城墙加固", "desc": "基地生命 +1", "cost": 1, "effect": {"base_hp": 1}},
	{"id": "inf_hp_2", "branch": "基建", "tier": 2, "name": "箭塔增筑", "desc": "基地生命 +2", "cost": 2, "effect": {"base_hp": 2}, "requires": "inf_hp_1"},
	{"id": "inf_hp_3", "branch": "基建", "tier": 3, "name": "城防翻新", "desc": "基地生命 +3", "cost": 3, "effect": {"base_hp": 3}, "requires": "inf_hp_2"},
]


static func get_item(tech_id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == tech_id:
			return item
	return {}


static func is_unlocked(profile: PlayerProfile, tech_id: String) -> bool:
	return profile != null and profile.has_tech(tech_id)


## 前置科技是否已解锁（无前置则 true）。
static func prerequisites_met(profile: PlayerProfile, item: Dictionary) -> bool:
	var requires: String = item.get("requires", "")
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
		if item.is_empty():
			continue
		var effect: Dictionary = item.get("effect", {})
		for key in effect:
			bonuses[key] = bonuses.get(key, 0) + int(effect[key])
	return bonuses
