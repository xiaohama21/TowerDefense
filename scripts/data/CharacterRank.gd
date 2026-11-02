extends RefCounted
class_name CharacterRank

const LEVELS: Array[int] = [1, 20, 40, 60, 80, 100]
const KEYS: Array[String] = ["white", "green", "purple", "yellow", "orange", "red"]
const NAMES: Array[String] = ["白", "绿", "紫", "黄", "橙", "红"]
const COLORS: Array[Color] = [Color("#aab9c7"), Color("#38ae74"), Color("#925bd1"), Color("#dab235"), Color("#e58a3b"), Color("#d85454")]
const ATTACK: Array[float] = [1.0, 1.05, 1.10, 1.16, 1.22, 1.30]
const RANGE: Array[float] = [1.0, 1.01, 1.03, 1.04, 1.05, 1.06]
const SPEED: Array[float] = [1.0, 1.02, 1.04, 1.05, 1.06, 1.08]
const MATERIALS: Array[String] = ["general_seal", "refined_iron", "ebony"]
const COSTS: Array = [[0, 0, 0], [3, 4, 2], [6, 6, 4], [10, 8, 5], [15, 8, 6], [20, 10, 7]]

static func for_level(level: int) -> int:
	var result := 0
	for i in range(LEVELS.size()):
		if level >= LEVELS[i]:
			result = i
	return result

static func costs(rank: int) -> Dictionary:
	var result := {}
	if rank < 1 or rank >= LEVELS.size():
		return result
	for i in range(MATERIALS.size()):
		result[MATERIALS[i]] = int(COSTS[rank][i])
	return result

static func unlocked_slots(rank: int) -> int:
	return 1 + int(rank >= 1) + int(rank >= 2)

static func normalize_guard(value) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for key in ["attack", "range", "attack_interval"]:
			var raw = value.get(key, 0)
			if not (raw is float or raw is int):
				continue
			var number := float(raw)
			if is_finite(number) and number > 0.0:
				result[key] = number
	return result
