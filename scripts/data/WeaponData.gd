extends ItemData
class_name WeaponData

@export var profession_id: StringName
@export var faction_limit: Array[StringName] = []
@export_range(1, 2, 1) var set_number: int = 1
@export var affixes: Dictionary = {}
@export var unlock_stage_id: StringName
@export var shop_price: int = 120

var weapon_id: StringName:
	get: return item_id

func fits(character: CharacterData) -> bool:
	return character != null and character.profession != null and character.profession.profession_id == profession_id and FactionRegistry.item_allows(faction_limit, character)

func is_valid() -> bool:
	return super.is_valid() and not profession_id.is_empty() and affixes.size() == 2 and item_type == ItemType.EQUIPMENT and FactionRegistry.valid_limits(faction_limit)
