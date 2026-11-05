extends RefCounted
class_name FactionRegistry

const IDS: Array[StringName] = [&"wei", &"shu", &"wu", &"qun"]
const NAMES := {&"wei": "魏", &"shu": "蜀", &"wu": "吴", &"qun": "群"}

static func is_valid_id(value: Variant) -> bool:
	return (value is String or value is StringName) and IDS.has(StringName(value))

static func display_name(faction: StringName) -> String:
	return NAMES.get(faction, "未知")

static func icon_key(faction: StringName) -> String:
	return "faction_" + str(faction) if is_valid_id(faction) else ""

static func valid_limits(limits: Variant) -> bool:
	if not (limits is Array or limits is PackedStringArray): return false
	for faction in limits:
		if not is_valid_id(faction): return false
	return true

static func item_allows(limits: Variant, character: CharacterData) -> bool:
	if character == null or not is_valid_id(character.faction) or not valid_limits(limits): return false
	return limits.is_empty() or limits.has(character.faction)

static func valid_rule(rule: Dictionary) -> bool:
	for key in rule:
		if key not in ["allow", "deny"] or not valid_limits(rule[key]): return false
	return true

static func rule_allows(rule: Dictionary, character: CharacterData) -> bool:
	if not valid_rule(rule) or character == null or not is_valid_id(character.faction): return false
	return item_allows(rule.get("allow", []), character) and not rule.get("deny", []).has(character.faction)
