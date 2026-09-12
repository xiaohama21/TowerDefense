extends Resource

class_name ItemData

enum ItemType {
	CURRENCY,
	GACHA_TOKEN,
	PROMOTION_MATERIAL,
	CHARACTER_SHARD,
	CONSUMABLE,
	# 遗物（v0.37.10 / 0.8.11.6）：局内遗物（编队选带、永久持有）由消耗品改列本类；
	# 追加在枚举末尾——.tres 以数值存储 item_type，不得在中间插入以免错位。
	RELIC,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

@export_category("Identity")
@export var item_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.CURRENCY
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D
@export var tags: Array[StringName] = []

@export_category("Inventory")
@export_range(1, 999999, 1) var max_stack: int = 9999


func is_valid() -> bool:
	return not item_id.is_empty() and not display_name.is_empty() and max_stack > 0
