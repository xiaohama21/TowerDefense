extends RefCounted

class_name SettlementWheel

## 结算转盘（P0 3.3 拍板，阶段 8 提交 2）：胜利结算时剩余金币 ≥150 可抽 1 次（仅 1 次）；
## 失败作废由"仅胜利结算页出现转盘"保证。
## v0.8.14：碎片条目随信物重构删除（奖池 6 → 4 条）。

const MIN_REMAINING_GOLD: int = 150
const CLOTH_ID := "yellow_turban_cloth"

## 奖池（权重）：黄巾布×2 30 / ×5 20 / 科技点×1 5 / 黄巾布×10 5
## （求贤令条目随抽将暂时移除 v0.30.0；碎片×10·×20 条目随 0.8.14 删除）。
const POOL: Array[Dictionary] = [
	{"kind": "item", "item_id": CLOTH_ID, "amount": 2, "weight": 30},
	{"kind": "item", "item_id": CLOTH_ID, "amount": 5, "weight": 20},
	{"kind": "tech_points", "amount": 1, "weight": 5},
	{"kind": "item", "item_id": CLOTH_ID, "amount": 10, "weight": 5},
]


## 执行一次转盘抽取。返回 {kind, item_id?, amount}；kind ∈ item/tech_points。
static func roll(_profile: PlayerProfile) -> Dictionary:
	var picked := _pick_by_weight()
	if picked.is_empty():
		return {}
	return picked.duplicate(true)


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
