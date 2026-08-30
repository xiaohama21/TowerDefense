extends Resource

class_name BuildSlotData

## 建造位结构化（GDD modules/STAGES.md 5.1，v0.14.1 落地）：
## 坐标 + 类型（软引导，不限制放置）+ 预锁位（花金币解锁）。

enum SlotType {
	ANY,
	MELEE,
	RANGED,
}

@export var position: Vector2
@export var slot_type: SlotType = SlotType.ANY
@export var locked: bool = false
## 预锁位解锁费用（GDD 5.1：50~80/个）。
@export_range(0, 999, 1) var unlock_cost: int = 60


func is_valid() -> bool:
	return unlock_cost >= 0


func type_label() -> String:
	match slot_type:
		SlotType.MELEE:
			return "近战"
		SlotType.RANGED:
			return "远程"
		_:
			return "通用"
