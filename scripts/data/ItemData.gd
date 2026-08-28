extends Resource

class_name ItemData

enum ItemType {
	CURRENCY,
	GACHA_TOKEN,
	PROMOTION_MATERIAL,
	CHARACTER_SHARD,
	CONSUMABLE,
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
