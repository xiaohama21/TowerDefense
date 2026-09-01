extends RefCounted

class_name SettlementWheel

## 结算转盘（P0 3.3 拍板，阶段 8 提交 2）：胜利结算时剩余金币 ≥150 可抽 1 次（仅 1 次）；
## 奖池 5~7 件道具随机抽取（NUMBERS.md 10.9 草案）；失败作废由"仅胜利结算页出现转盘"保证。

const MIN_REMAINING_GOLD: int = 150
const CLOTH_ID := "yellow_turban_cloth"

## 奖池（权重）：黄巾布×2 30 / ×5 20 / 碎片×10 20 / ×20 10 / 科技点×1 5 / 黄巾布×10 5（求贤令条目随抽将暂时移除 v0.30.0）。
const POOL: Array[Dictionary] = [
	{"kind": "item", "item_id": CLOTH_ID, "amount": 2, "weight": 30},
	{"kind": "item", "item_id": CLOTH_ID, "amount": 5, "weight": 20},
	{"kind": "shards", "amount": 10, "weight": 20},
	{"kind": "shards", "amount": 20, "weight": 10},
	{"kind": "tech_points", "amount": 1, "weight": 5},
	{"kind": "item", "item_id": CLOTH_ID, "amount": 10, "weight": 5},
]


## 执行一次转盘抽取。返回 {kind, item_id?, amount, character_id?}；kind ∈ item/shards/tech_points。
## 碎片需要指定武将：优先随机一名已拥有武将，否则从全角色目录随机。
static func roll(profile: PlayerProfile) -> Dictionary:
	var picked := _pick_by_weight()
	if picked.is_empty():
		return {}
	var result := picked.duplicate(true)
	if str(result.get("kind", "")) == "shards":
		result["character_id"] = _pick_shard_character(profile)
	return result


static func _pick_by_weight() -> Dictionary:
	var total := 0
	for entry in POOL:
		total += int(entry.get("weight", 0))
	if total <= 0:
		return {}
	var roll := randi() % total
	var acc := 0
	for entry in POOL:
		acc += int(entry.get("weight", 0))
		if roll < acc:
			return entry
	return POOL[-1]


static func _pick_shard_character(profile: PlayerProfile) -> String:
	if profile == null:
		return ""
	var owned := profile.get_owned_character_ids()
	if not owned.is_empty():
		return owned[randi() % owned.size()]
	var all := GameFlow.get_all_character_ids()
	if not all.is_empty():
		return all[randi() % all.size()]
	return ""
