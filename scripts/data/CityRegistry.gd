extends RefCounted
class_name CityRegistry

const DIRECTORY := "res://resources/city"
static var _entries: Dictionary = {}

static func all() -> Array:
	if _entries.is_empty():
		for file in ResourceLoader.list_directory(DIRECTORY):
			if file.ends_with(".tres"):
				var entry := load(DIRECTORY + "/" + file) as CityEntryData
				if entry != null: _entries[entry.entry_id] = entry
	return _entries.values()

static func entry(id: StringName) -> CityEntryData:
	all()
	return _entries.get(id)

static func normalize_state(raw: Variant) -> Dictionary:
	var result := {"legacy_access": false, "visited": []}
	if not raw is Dictionary: return result
	result.legacy_access = raw.get("legacy_access", false) is bool and raw.get("legacy_access", false)
	var visited = raw.get("visited", [])
	if visited is Array:
		for id in visited:
			if not id is String: continue
			var data := entry(StringName(id))
			if data != null and data.implemented and not result.visited.has(id): result.visited.append(id)
	return result

static func is_open(profile: PlayerProfile, id: StringName) -> bool:
	var data := entry(id)
	if profile == null or data == null or not data.implemented: return false
	if data.prerequisite_stage.is_empty() or profile.city_state.legacy_access: return true
	var progress = profile.stage_progress.get(str(data.prerequisite_stage), {})
	if progress is Dictionary and progress.get("completed", false) == true: return true
	# Preserve access to investments and inventory already present in a profile.
	match id:
		&"develop":
			for hero in profile.characters.values():
				if int(hero.get("total_exp", 0)) > 0 or int(hero.get("rank", 0)) > 0: return true
		&"inventory":
			return not profile.items.is_empty() or not profile.weapons.is_empty() or not profile.relics.is_empty()
		&"tech":
			return profile.tech_points > 0 or not profile.tech_unlocks.is_empty()
		&"shop":
			return not profile.weapons.is_empty()
		&"supply":
			if not profile.supply_loadout_ids.is_empty(): return true
			for level in profile.supply_levels.values():
				if int(level) > 1: return true
	return false

static func is_new(profile: PlayerProfile, id: StringName) -> bool:
	return is_open(profile, id) and not profile.city_state.visited.has(str(id))

static func locked_reason(id: StringName) -> String:
	var data := entry(id)
	if data == null or not data.implemented: return "正在筹建，暂未开放。"
	var stage := GameFlow.load_stage_data(data.prerequisite_stage)
	return "通关第%d关后开放。" % stage.stage_number if stage != null else "继续推进主线后开放。"
