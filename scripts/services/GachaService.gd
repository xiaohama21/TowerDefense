extends RefCounted

class_name GachaService

## 求贤抽奖（GDD modules/DROPS_GACHA.md 7.3，v0.14；v0.30.0 起入口/掉落关闭，服务保留）：
## 求贤令 ×1/抽，常规池 = 已拥有武将，每 10 抽保底一个未拥有角色。
## ✅ 0.8.14 信物重构：**碎片整体删除**——重复抽出与保底落空均不再折算碎片（返回空产出标记），
## 存档 characters[id].shards 随 schema v4 迁移清理。

const PITY_INTERVAL := 10


## 执行单次求贤。返回 {type: "dup"/"pity_char"/"pity_empty", character_id: StringName}。
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
			return {"type": "pity_char", "character_id": picked}
		# 全员已拥有或全被主线锁定：不产出碎片（0.8.14 删除折算），返回空保底标记。
		profile.set_gacha_pity(0)
		profile.set_gacha_total(next_total)
		return {"type": "pity_empty"}

	# 常规抽取：已拥有武将重复（碎片折算已于 0.8.14 删除，仅消耗求贤令计数）。
	var picked := pool[randi() % pool.size()]
	profile.set_gacha_pity(pity)
	profile.set_gacha_total(next_total)
	return {"type": "dup", "character_id": picked}


## 常规池：已拥有的武将（v0.30.0 起抽将入口关闭，池子保留供恢复时复用）。
static func _get_pool(profile: PlayerProfile, _chapter: ChapterData) -> Array[String]:
	var result: Array[String] = []
	for cid in profile.get_owned_character_ids():
		result.append(cid)
	return result


## 章节内未拥有武将（保底目标，v0.14.1 修正）：
## 主线首通角色在未通关其解锁关前不可被抽出（防抽奖绕过主线，GDD 7.3 铁律）；
## 全被主线锁定或全员已拥有时返回空（0.8.14 起不再折算碎片）。
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
