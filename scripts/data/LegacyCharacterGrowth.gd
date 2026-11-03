extends RefCounted
class_name LegacyCharacterGrowth

## Frozen schema-v6 bare stats; migration must survive removal of promotion resources.
const CHARACTERS := {
	"diao_chan": [
		18.0,
		2.0,
		145.0,
		0,
		1.4,
		"dancer"
	],
	"guan_yu": [
		64.0,
		5.5,
		130.0,
		0,
		1.15,
		"cavalry"
	],
	"huang_fu_song": [
		136.0,
		6.0,
		360.0,
		0,
		2.4,
		"catapult"
	],
	"huang_zhong": [
		48.0,
		4.5,
		205.0,
		0,
		1.25,
		"archer"
	],
	"liu_bei": [
		38.0,
		3.5,
		130.0,
		0,
		0.8,
		"tiger_guard"
	],
	"zhang_fei": [
		52.0,
		4.0,
		120.0,
		0,
		0.7,
		"tiger_guard"
	],
	"zhao_yun": [
		58.0,
		5.0,
		120.0,
		0,
		0.75,
		"cavalry"
	],
	"zhou_wei": [
		70.0,
		5.0,
		115.0,
		0,
		0.9,
		"tiger_guard"
	],
	"zhuge_liang": [
		55.0,
		4.5,
		190.0,
		0,
		1.3,
		"strategist"
	]
}
const PROMOTIONS := {
	"archer_crossbow": [
		1.25,
		1.1,
		0.9,
		"archer",
		20.0
	],
	"archer_piercing_cloud": [
		1.3,
		1.15,
		0.9,
		"archer",
		20.0
	],
	"archer_strong_bow": [
		1.15,
		1.1,
		0.95,
		"archer",
		10.0
	],
	"catapult_city_breaker": [
		1.35,
		1.1,
		0.9,
		"catapult",
		20.0
	],
	"catapult_earthquake": [
		1.3,
		1.1,
		0.9,
		"catapult",
		20.0
	],
	"catapult_thunder": [
		1.2,
		1.1,
		0.9,
		"catapult",
		10.0
	],
	"cavalry_heavy_armor": [
		1.35,
		1.0,
		0.85,
		"cavalry",
		20.0
	],
	"cavalry_iron_rider": [
		1.2,
		1.0,
		0.9,
		"cavalry",
		10.0
	],
	"cavalry_swift_raider": [
		1.3,
		1.0,
		0.9,
		"cavalry",
		20.0
	],
	"dancer_echo": [
		1.2,
		1.0,
		0.85,
		"dancer",
		20.0
	],
	"dancer_master": [
		1.1,
		1.0,
		0.85,
		"dancer",
		10.0
	],
	"dancer_phoenix": [
		1.25,
		1.0,
		0.8,
		"dancer",
		20.0
	],
	"strategist_heavenly_master": [
		1.25,
		1.1,
		0.9,
		"strategist",
		20.0
	],
	"strategist_mage": [
		1.15,
		1.1,
		0.95,
		"strategist",
		10.0
	],
	"strategist_sage": [
		1.3,
		1.1,
		0.9,
		"strategist",
		20.0
	],
	"tiger_guard_army": [
		1.2,
		1.0,
		0.95,
		"tiger_guard",
		10.0
	],
	"tiger_guard_guard": [
		1.25,
		1.0,
		0.9,
		"tiger_guard",
		20.0
	],
	"tiger_guard_vanguard": [
		1.35,
		1.0,
		0.9,
		"tiger_guard",
		20.0
	]
}

static func guard_for(character_id: String, entry: Dictionary) -> Dictionary:
	if not CHARACTERS.has(character_id):
		return {}
	var xp := maxi(int(entry.get("total_exp", 0)), 0)
	var level := 1
	while level < 30 and 40 * level + 15 * level * (level - 1) <= xp:
		level += 1
	var base: Array = CHARACTERS[character_id]
	var mult: Array = [1.0, 1.0, 1.0]
	var path = entry.get("promotion_path", [])
	if path is Array and not path.is_empty():
		var config: Array = PROMOTIONS.get(str(path.back()), [])
		if config.size() == 5 and config[3] == base[5] and level >= int(config[4]):
			mult = config
	return {
		"attack": round((float(base[0]) + float(base[1]) * (level - 1)) * float(mult[0])),
		"range": (float(base[2]) + float(base[3]) * (level - 1)) * float(mult[1]),
		"attack_interval": float(base[4]) * float(mult[2]),
	}
