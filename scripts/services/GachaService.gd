extends RefCounted

class_name GachaService

## 求贤抽奖（GDD modules/DROPS_GACHA.md 7.3，v0.14）：求贤令 ×1/抽，
## 常规池=已拥有武将（重复→碎片 20），每 10 抽保底未拥有角色（或碎片 40）。

const DUP_SHARDS := 20
const PITY_FALLBACK_SHARDS := 40
const PITY_INTERVAL := 10


## 执行单次求贤。返回 {type: "dup"/"pity_char"/"pity_shards", character_id: StringName, shards: int}。
static func pull(profile: PlayerProfile, chapter: ChapterData) -> Dictionary:
	var owned := profile.get_owned_character_ids()
	var pool := _get_pool(profile, chapter)
	if pool.is_empty():
		return {"type": "empty"}

	var pity := profile.get_gacha_pity()
	var total := profile.get_gacha_total()
	var next_total := total + 1
	var is_pity := next_total % PITY_INTERVAL == 0

	if is_pity:
		var unowned := _get_unowned_in_chapter(profile, chapter)
		if not unowned.is_empty():
			var picked := unowned[randi() % unowned.size()]
			profile.ensure_character(picked)
			profile.set_gacha_pity(0)
			profile.set_gacha_total(next_total)
			return {"type": "pity_char", "character_id": picked, "shards": 0}
		# 全员已拥有：保底折算碎片
		var fallback_cid := pool[randi() % pool.size()]
		profile.add_character_shards(fallback_cid, PITY_FALLBACK_SHARDS)
		profile.set_gacha_pity(0)
		profile.set_gacha_total(next_total)
		return {"type": "pity_shards", "character_id": fallback_cid, "shards": PITY_FALLBACK_SHARDS}

	# 常规抽取：随机已拥有武将 → 碎片
	var picked := pool[randi() % pool.size()]
	profile.add_character_shards(picked, DUP_SHARDS)
	profile.set_gacha_pity(pity)
	profile.set_gacha_total(next_total)
	return {"type": "dup", "character_id": picked, "shards": DUP_SHARDS}


## 常规池：已解锁章节中已拥有的武将（重复产出碎片）。
static func _get_pool(profile: PlayerProfile, chapter: ChapterData) -> Array[String]:
	var result: Array[String] = []
	for cid in profile.get_owned_character_ids():
		result.append(cid)
	return result


## 章节内未拥有武将（保底目标，v0.14.1 修正）：
## 主线首通角色在未通关其解锁关前不可被抽出（防抽奖绕过主线，GDD 7.3 铁律）；
## 全被主线锁定或全员已拥有时保底折算碎片。
static func _get_unowned_in_chapter(profile: PlayerProfile, chapter: ChapterData) -> Array[String]:
	var result: Array[String] = []
	if chapter == null:
		return result
	for stage in chapter.stages:
		if stage == null:
			continue
		for cid in stage.first_clear_unlock_character_ids:
			var cid_str := str(cid)
			if profile.has_character(cid_str) or result.has(cid_str):
				continue
			var character_data := GameFlow.load_character_data(cid_str)
			var unlock_stage := str(character_data.unlock_stage_id) if character_data != null else ""
			if unlock_stage.is_empty() or _is_stage_completed(profile, unlock_stage):
				result.append(cid_str)
	return result


static func _is_stage_completed(profile: PlayerProfile, stage_id: String) -> bool:
	var entry = profile.stage_progress.get(stage_id, {})
	return entry is Dictionary and entry.get("completed", false)

