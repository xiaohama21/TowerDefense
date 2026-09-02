extends Node

## GameFlow：阶段 1 界面流程控制器（主菜单 → 选关 → 编队 → 战斗）。
## 持有"本次选择的关卡与出战编队"这类跨场景临时状态；持久化仍只走 ProfileStore。

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const GAME_HUB_SCENE := "res://scenes/GameHub.tscn"
const SQUAD_SELECT_SCENE := "res://scenes/SquadSelect.tscn"
const BATTLE_SCENE := "res://scenes/Main.tscn"
const SETTINGS_PATH := "user://settings.cfg"
const CHAPTER_SCENE_DIR := "res://resources/chapters"
const STAGE_RESOURCE_DIR := "res://resources/stages"
const CHARACTER_RESOURCE_DIR := "res://resources/characters"
const PROMOTION_RESOURCE_DIR := "res://resources/promotions"
const RELIC_RESOURCE_DIR := "res://resources/relics"
const ITEM_RESOURCE_DIR := "res://resources/items"
const BOND_RESOURCE_DIR := "res://resources/bonds"
const BATTLE_RELIC_RESOURCE_DIR := "res://resources/battle_relics"

## 新档初始武将（v0.30.6 回滚：恢复刘备、关羽；v0.30.2"仅刘备"调整作废，
## s01 首通奖励不再发放关羽，避免重复获取困惑）。
const INITIAL_CHARACTER_IDS: Array[String] = ["liu_bei", "guan_yu"]

var selected_stage_id: StringName = &""
var squad_character_ids: Array[String] = []

## 本次出征选带的局内遗物（v0.19.0，CHARACTERS.md 4.8）：出征即消耗库存各 1 件，
## 仅本局生效；重试保留，离场/进入下一关时清空（GameFlow.clear_squad_relics）。
var squad_relic_ids: Array[String] = []
## 游戏大厅当前页签（map/develop/settings），战斗结算"返回大厅"时恢复。
var hub_active_panel: StringName = &"map"
## 当前难度（0=轻松 1=标准 2=困难），默认标准。
var selected_difficulty: int = 1


## 新的征程：清空现有档案并发放初始武将。
func start_new_game() -> bool:
	var profile := ProfileStore.create_new_profile(true)
	if profile == null:
		return false
	ensure_initial_characters(profile)
	return ProfileStore.save_profile(profile)


func has_existing_save() -> bool:
	return FileAccess.file_exists(ProfileStore.get_profile_path())


## 保证初始武将已入库（幂等）；战斗场景启动时也会调用以兜底。
func ensure_initial_characters(profile: PlayerProfile) -> void:
	if profile == null:
		return
	var changed := false
	for character_id in INITIAL_CHARACTER_IDS:
		if not profile.has_character(character_id):
			profile.ensure_character(character_id)
			changed = true
	if changed:
		ProfileStore.save_profile(profile)


## 关卡解锁判定：前置关卡全部通关（GDD 5.1 prerequisite_stage_ids）。
func is_stage_unlocked(profile: PlayerProfile, stage_data: StageData) -> bool:
	if profile == null or stage_data == null:
		return false
	for prerequisite in stage_data.prerequisite_stage_ids:
		var entry = profile.stage_progress.get(str(prerequisite), {})
		if not (entry is Dictionary) or not entry.get("completed", false):
			return false
	return true


func get_chapter() -> ChapterData:
	return load("res://resources/chapters/chapter_01.tres") as ChapterData


## 按关卡编号排序的章节关卡列表。
func get_sorted_stages(chapter: ChapterData) -> Array[StageData]:
	var stages: Array[StageData] = []
	if chapter != null:
		for stage in chapter.stages:
			if stage is StageData:
				stages.append(stage)
	stages.sort_custom(func(a: StageData, b: StageData) -> bool: return a.stage_number < b.stage_number)
	return stages


## 按章节推进顺序取下一关（不存在则返回 null）。
func get_next_stage_id(current_stage_id: StringName) -> StringName:
	var chapter := get_chapter()
	var stages := get_sorted_stages(chapter)
	for index in range(stages.size()):
		if stages[index].stage_id == current_stage_id and index + 1 < stages.size():
			return stages[index + 1].stage_id
	return &""


## 按约定目录 resources/stages/<chapter_id>/<stage_id>.tres 查找关卡数据。
func load_stage_data(stage_id: StringName) -> StageData:
	if stage_id.is_empty():
		return null
	# PCK 导出包中 DirAccess.list_dir_begin/get_next 迭代不可用（Godot 已知限制），
	# 统一改用 ResourceLoader.list_directory（文件系统与 PCK 均支持，v0.19.6 修复）。
	for entry in ResourceLoader.list_directory(STAGE_RESOURCE_DIR):
		var path: String = "%s/%s/%s.tres" % [STAGE_RESOURCE_DIR, entry, stage_id]
		if ResourceLoader.exists(path):
			return load(path) as StageData
	return null


## 武将图鉴（v0.11.3）：扫描角色目录返回全部角色 ID（含未拥有）。
func get_all_character_ids() -> Array[String]:
	var result: Array[String] = []
	for entry in ResourceLoader.list_directory(CHARACTER_RESOURCE_DIR):
		if entry.ends_with(".tres"):
			result.append(entry.trim_suffix(".tres"))
	result.sort()
	return result


## 全部羁绊配置（v0.17.0，GDD modules/CHARACTERS.md 4.8）：扫描 `resources/bonds/`。
func get_all_bonds() -> Array[BondData]:
	var result: Array[BondData] = []
	for entry in ResourceLoader.list_directory(BOND_RESOURCE_DIR):
		if entry.ends_with(".tres"):
			var bond := load("%s/%s" % [BOND_RESOURCE_DIR, entry]) as BondData
			if bond != null and bond.is_valid():
				result.append(bond)
	return result


## 羁绊进度（v0.17.0）：编队中各羁绊的上场数/满员数；active=全员上场（满员激活）。
func get_bond_progress(squad_ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var squad := {}
	for character_id in squad_ids:
		squad[str(character_id)] = true
	for bond in get_all_bonds():
		var count := 0
		for member_id in bond.member_ids:
			if squad.has(str(member_id)):
				count += 1
		result.append({
			"bond": bond,
			"count": count,
			"total": bond.member_ids.size(),
			"active": count == bond.member_ids.size(),
		})
	return result


## 编队同队攻击加成（v0.17.0）：全部激活羁绊 damage_bonus 之和（finalize_damage 乘法区）。
func get_squad_bond_damage_bonus(squad_ids: Array) -> float:
	var bonus := 0.0
	for progress in get_bond_progress(squad_ids):
		if progress.get("active", false):
			bonus += (progress["bond"] as BondData).damage_bonus
	return bonus

## 难度解锁：困难需该关标准难度通关（v0.14.1 接通写档：结算按难度记录）。
func is_difficulty_unlocked(profile: PlayerProfile, stage_id: StringName, difficulty: int) -> bool:
	if difficulty <= Difficulty.NORMAL:
		return true
	var entry = profile.stage_progress.get(str(stage_id), {})
	if entry is Dictionary:
		var diffs: Dictionary = entry.get("difficulties", {})
		return diffs.has(Difficulty.key_name(Difficulty.NORMAL))
	return false


## 求贤单抽：扣求贤令 → GachaService → 写回存档。返回结果字典或空（令不足）。
func pull_gacha(profile: PlayerProfile) -> Dictionary:
	if profile == null:
		return {}
	var token_count := _coerce_int(profile.items.get("gacha_token", 0))
	if token_count < 1:
		return {}
	profile.spend_item("gacha_token", 1)
	var result := GachaService.pull(profile, get_chapter())
	save_profile_quiet()
	return result


func _coerce_int(value) -> int:
	return int(value) if value != null else 0


func save_profile_quiet() -> void:
	if profile_storage_has_profile():
		save_profile(get_profile())


func profile_storage_has_profile() -> bool:
	return true


func save_profile(profile: PlayerProfile) -> bool:
	return ProfileStore.save_profile(profile)


func get_profile() -> PlayerProfile:
	return ProfileStore.get_profile()


## 图鉴获取方式文案：unlock_stage_id → 关卡名；空 → 初始武将。
## 战斗出场配置（v0.13）：等级/转职/星级/信物一次取齐，供建造管线使用。
func get_battle_loadout(profile: PlayerProfile, character_id: String) -> Dictionary:
	return {
		"level": get_character_level(profile, character_id),
		"promotion": get_active_promotion(profile, character_id),
		"stars": profile.get_character_stars(character_id) if profile != null else 0,
		"relic": get_equipped_relic(profile, character_id),
	}


## 该武将当前装备的信物（characters[id].relic 指向 RelicData 资源）。
func get_equipped_relic(profile: PlayerProfile, character_id: String) -> RelicData:
	if profile == null:
		return null
	var equipped: String = str(profile.get_character(character_id).get("relic", ""))
	if equipped.is_empty():
		return null
	var path: String = RELIC_RESOURCE_DIR + "/" + equipped + ".tres"
	if ResourceLoader.exists(path):
		return load(path) as RelicData
	return null


## 该武将对应的信物定义（未拥有也可查询，用于图鉴与兑换）。
func get_relic_for_character(character_id: String) -> RelicData:
	for entry in ResourceLoader.list_directory(RELIC_RESOURCE_DIR):
		if entry.ends_with(".tres"):
			var rpath: String = RELIC_RESOURCE_DIR + "/" + entry
			var relic := load(rpath) as RelicData
			if relic != null and relic.character_id == StringName(character_id):
				return relic
	return null


func get_acquisition_text(character_id: String) -> String:
	var character_data := load_character_data(character_id)
	if character_data == null:
		return "配置缺失"
	if character_data.unlock_stage_id.is_empty():
		return "初始解锁"
	var stage := load_stage_data(character_data.unlock_stage_id)
	if stage != null:
		return "通关「%s」首通解锁" % stage.display_name
	return "随章节更新解锁"


func load_character_data(character_id: String) -> CharacterData:
	var path: String = "%s/%s.tres" % [CHARACTER_RESOURCE_DIR, character_id]
	return load(path) as CharacterData if ResourceLoader.exists(path) else null


## 武将当前等级（由存档 total_exp 推导，GDD modules/NUMBERS.md 10.1）。
func get_character_level(profile: PlayerProfile, character_id: String) -> int:
	if profile == null:
		return 1
	return LevelCurve.level_from_total_exp(profile.get_character_exp(character_id))


## 当前生效的转职（promotion_path 末位；未转职返回 null）。
func get_active_promotion(profile: PlayerProfile, character_id: String) -> PromotionData:
	if profile == null:
		return null
	var entry := profile.get_character(character_id)
	var promotion_path: Array = entry.get("promotion_path", [])
	if promotion_path.is_empty():
		return null
	return load_promotion_data(str(promotion_path[promotion_path.size() - 1]))


## 按 id 加载转职资源（`res://resources/promotions/{id}.tres`）；不存在返回 null。
func load_promotion_data(promotion_id: String) -> PromotionData:
	if promotion_id.is_empty():
		return null
	var path: String = "%s/%s.tres" % [PROMOTION_RESOURCE_DIR, promotion_id]
	return load(path) as PromotionData if ResourceLoader.exists(path) else null


## 武将当前可选的转职候选（阶段 6 图结构，v0.17.0）：
## 未转职返回 `character.promotion_ids` 首条一转路线；已转职返回当前转职的
## `next_promotion_ids` 分支候选（校验 parent_id=当前生效转职，且路径未含该候选，
## 防跳级/回退/重复转职）。
func get_promotion_candidates(profile: PlayerProfile, character_id: String) -> Array[PromotionData]:
	var candidates: Array[PromotionData] = []
	if profile == null:
		return candidates
	var character := load_character_data(character_id)
	if character == null:
		return candidates
	var active := get_active_promotion(profile, character_id)
	if active == null:
		if not character.promotion_ids.is_empty():
			var first := load_promotion_data(str(character.promotion_ids[0]))
			if first != null:
				candidates.append(first)
		return candidates
	var path: Array = profile.get_character(character_id).get("promotion_path", [])
	for next_id in active.next_promotion_ids:
		var candidate := load_promotion_data(str(next_id))
		if candidate == null or str(candidate.parent_id) != str(active.promotion_id):
			continue
		if path.has(str(candidate.promotion_id)):
			continue
		candidates.append(candidate)
	return candidates


func get_item_display_name(item_id: String) -> String:
	var item := load_item_data(item_id)
	return item.display_name if item != null else str(item_id)


## 按 id 加载道具资源（`res://resources/items/{id}.tres`）；不存在返回 null。
func load_item_data(item_id: String) -> ItemData:
	var path := "%s/%s.tres" % [ITEM_RESOURCE_DIR, item_id]
	if ResourceLoader.exists(path):
		return load(path) as ItemData
	return null


## 关卡结算固定奖励（v0.15.1 抽公共，正常胜利与"一键通关（测试）"共用同一条规则）：
## 首通=解锁武将 + 首通奖励 + Boss 首通信物；重复=重复奖励 + 概率掉落掷点；
## 数量按难度材料倍率缩放（Difficulty.material_mult，取整保底 ≥1）。
func collect_stage_rewards(session: BattleSession, stage: StageData, first_clear: bool) -> void:
	if session == null or stage == null:
		return
	var mult := Difficulty.material_mult(selected_difficulty)
	var rewards: Array = []
	if first_clear:
		for character_id in stage.first_clear_unlock_character_ids:
			session.add_unlock(str(character_id))
		rewards = stage.first_clear_rewards
		if stage.first_clear_relic != null:
			session.add_relic(str(stage.first_clear_relic.relic_id))
	else:
		rewards = stage.repeat_clear_rewards
		for drop in stage.probability_drops:
			if drop == null or drop.item == null or drop.amount <= 0:
				continue
			if randf() <= drop.chance:
				session.add_loot(str(drop.item.item_id), maxi(1, int(round(drop.amount * mult))))
	for reward in rewards:
		if reward == null or reward.item == null or reward.amount <= 0:
			continue
		session.add_loot(str(reward.item.item_id), maxi(1, int(round(reward.amount * mult))))


## 科技点发放（v0.15.1 抽公共）：首通 +2 / 重复 +1 × 难度材料倍率。
func award_tech_points(session: BattleSession, first_clear: bool) -> void:
	if session == null:
		return
	var base := 2 if first_clear else 1
	var amount := int(round(base * Difficulty.material_mult(selected_difficulty)))
	if amount > 0:
		session.add_tech_points(amount)


func select_stage(stage_id: StringName) -> void:
	selected_stage_id = stage_id


func set_squad(character_ids: Array[String]) -> void:
	squad_character_ids = character_ids.duplicate()


func set_squad_relics(relic_ids: Array[String]) -> void:
	squad_relic_ids.clear()
	for relic_id in relic_ids:
		var key := str(relic_id).strip_edges()
		if not key.is_empty() and not squad_relic_ids.has(key):
			squad_relic_ids.append(key)


func clear_squad_relics() -> void:
	squad_relic_ids.clear()


## 局内遗物数据加载（v0.19.0）：relic_id 即 items 的 item_id；失败返回 null。
func load_battle_relic_data(relic_id: String) -> BattleRelicData:
	var key := str(relic_id).strip_edges()
	if key.is_empty():
		return null
	return load("%s/%s.tres" % [BATTLE_RELIC_RESOURCE_DIR, key]) as BattleRelicData


## 背包中拥有的遗物 ID 列表（items 库存 × 对应 BattleRelicData 存在）。
func get_owned_relic_ids(profile: PlayerProfile) -> Array[String]:
	var result: Array[String] = []
	for key in profile.items.keys():
		var item_id := str(key)
		if int(profile.items.get(key, 0)) <= 0:
			continue
		var relic := load_battle_relic_data(item_id)
		if relic != null and relic.is_valid():
			result.append(item_id)
	result.sort()
	return result


## 已选遗物加成汇总（v0.19.0）：伤害/射程百分比加算、攻速连乘、金币/生命加算。
func get_battle_relic_bonuses() -> Dictionary:
	var result := {
		"damage_bonus_pct": 0,
		"attack_interval_factor": 1.0,
		"range_bonus_pct": 0,
		"start_gold": 0,
		"base_hp_bonus": 0,
	}
	for relic_id in squad_relic_ids:
		var relic := load_battle_relic_data(relic_id)
		if relic == null or not relic.is_valid():
			continue
		result["damage_bonus_pct"] = int(result["damage_bonus_pct"]) + relic.damage_bonus_pct
		result["attack_interval_factor"] = float(result["attack_interval_factor"]) * relic.attack_interval_factor
		result["range_bonus_pct"] = int(result["range_bonus_pct"]) + relic.range_bonus_pct
		result["start_gold"] = int(result["start_gold"]) + relic.start_gold
		result["base_hp_bonus"] = int(result["base_hp_bonus"]) + relic.base_hp_bonus
	return result


## 出征消耗：扣除已选遗物库存各 1 件（胜/负均消耗；写档由调用方负责）。
func consume_squad_relics(profile: PlayerProfile) -> void:
	for relic_id in squad_relic_ids:
		profile.spend_item(relic_id, 1)


func goto_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


## 读取设置面板持久化的游戏性开关（如剧情速进）。
func is_gameplay_flag_enabled(flag: String) -> bool:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	return bool(config.get_value("gameplay", flag, false))


func set_gameplay_flag(flag: String, value: bool) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("gameplay", flag, value)
	config.save(SETTINGS_PATH)


func goto_hub() -> void:
	_change_scene(GAME_HUB_SCENE)


func goto_squad_select(difficulty: int = 1) -> void:
	selected_difficulty = difficulty
	_change_scene(SQUAD_SELECT_SCENE)


func goto_battle() -> void:
	_change_scene(BATTLE_SCENE)


func _change_scene(scene_path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
