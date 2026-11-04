extends RefCounted
class_name TalentRegistry

const IDS := ["physical_burst", "physical_area", "magic_burst", "magic_area", "support_control", "support_buff", "armor_break", "rage", "control", "buff", "economy"]
const THRESHOLDS := [0, 4, 8, 12]
static var _trees: Dictionary = {}
static var _assignments: Dictionary = {}
static var _bonuses: Dictionary = {}

static func get_tree_data(id: String) -> TalentTreeData:
	if not IDS.has(id): return null
	if not _trees.has(id): _trees[id] = load("res://resources/talents/%s.tres" % id) as TalentTreeData
	return _trees[id]

static func tree_ids(character_id: String) -> Array[String]:
	if not _assignments.has(character_id):
		var path := "res://resources/characters/%s.tres" % character_id
		var character = load(path) if ResourceLoader.exists(path) else null
		var ids: Array[String] = []
		if character != null:
			for id in character.talent_tree_ids:
				if IDS.has(id) and not ids.has(id): ids.append(id)
		_assignments[character_id] = ids
	return _assignments[character_id].duplicate()

static func points_for_level(level: int) -> int:
	return 2 * floori(float(clampi(level, 1, 100)) / 5.0)

static func spent(alloc: Dictionary, tree_id: String = "") -> int:
	var total := 0
	for id in alloc:
		if tree_id.is_empty() or str(id).begins_with(tree_id + "."): total += int(alloc[id])
	return total

static func node_data(id: String) -> Dictionary:
	var tree := get_tree_data(id.get_slice(".", 0))
	return tree.get_node_data(id) if tree != null else {}

static func _rank(value) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT: return 0
	if not is_finite(float(value)) or float(value) != floorf(float(value)): return 0
	return int(clampf(float(value), 0.0, 2.0))

static func normalize(character_id: String, level: int, raw) -> Dictionary:
	var result := {}
	if not raw is Dictionary: return result
	var remaining := points_for_level(level)
	for tree_id in tree_ids(character_id):
		var tree := get_tree_data(tree_id)
		if tree == null: continue
		var tree_spent := 0
		for node in tree.nodes:
			var id := str(node.id)
			var rank := _rank(raw.get(id, 0))
			for _point in range(rank):
				if remaining <= 0 or tree_spent < THRESHOLDS[int(node.tier) - 1]: break
				result[id] = int(result.get(id, 0)) + 1
				tree_spent += 1
				remaining -= 1
	return result

static func allocation_status(character_id: String, level: int, alloc: Dictionary, id: String) -> String:
	var node := node_data(id)
	if node.is_empty() or not tree_ids(character_id).has(id.get_slice(".", 0)): return "未解锁"
	if int(alloc.get(id, 0)) >= 2: return "已满级"
	if spent(alloc, id.get_slice(".", 0)) < THRESHOLDS[int(node.tier) - 1]: return "本树门槛未达"
	if spent(alloc) >= points_for_level(level): return "点数不足"
	return "分配"

static func node_effects(node: Dictionary, rank: int) -> Dictionary:
	var result := {}
	if rank <= 0: return result
	for key in node.effects:
		result[key] = float(node.effects[key]) * rank
	if rank == 2:
		for key in node.level2_overrides: result[key] = float(node.level2_overrides[key])
	return result

static func bonuses(character_id: String, alloc: Dictionary) -> Dictionary:
	# Canonical ordering keeps cache keys stable and does not retain mutable profile dictionaries.
	var keys := alloc.keys()
	keys.sort()
	var parts := PackedStringArray([character_id])
	for id in keys: parts.append(str(id) + ":" + str(alloc[id]))
	var cache_key := "|".join(parts)
	if _bonuses.has(cache_key): return _bonuses[cache_key].duplicate(true)
	var result := {}
	for tree_id in tree_ids(character_id):
		var tree := get_tree_data(tree_id)
		if tree == null: continue
		for node in tree.nodes:
			var effects := node_effects(node, _rank(alloc.get(str(node.id), 0)))
			for key in effects:
				result[key] = float(result.get(key, 0.0)) + float(effects[key])
	if _bonuses.size() >= 256: _bonuses.clear()
	_bonuses[cache_key] = result.duplicate(true)
	return result

static func skill_amp(character_id: String, alloc: Dictionary, ultimate: bool = false) -> float:
	var values := bonuses(character_id, alloc)
	return float(values.get("skill_amp", 0.0)) + (float(values.get("ultimate_amp", 0.0)) if ultimate else 0.0)
