extends Node

## GameFlow：阶段 1 界面流程控制器（主菜单 → 选关 → 编队 → 战斗）。
## 持有"本次选择的关卡与出战编队"这类跨场景临时状态；持久化仍只走 ProfileStore。

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const GAME_HUB_SCENE := "res://scenes/GameHub.tscn"
const SQUAD_SELECT_SCENE := "res://scenes/SquadSelect.tscn"
const BATTLE_SCENE := "res://scenes/Main.tscn"
const CHAPTER_SCENE_DIR := "res://resources/chapters"
const STAGE_RESOURCE_DIR := "res://resources/stages"
const CHARACTER_RESOURCE_DIR := "res://resources/characters"
const PROMOTION_RESOURCE_DIR := "res://resources/promotions"
const ITEM_RESOURCE_DIR := "res://resources/items"

## 新档初始武将（GDD 阶段 0 交付：刘备、关羽）。
const INITIAL_CHARACTER_IDS: Array[String] = ["liu_bei", "guan_yu"]

var selected_stage_id: StringName = &""
var squad_character_ids: Array[String] = []
## 游戏大厅当前页签（map/develop/settings），战斗结算"返回大厅"时恢复。
var hub_active_panel: StringName = &"map"


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
	var stages_dir := DirAccess.open(STAGE_RESOURCE_DIR)
	if stages_dir == null:
		return null
	stages_dir.list_dir_begin()
	var entry := stages_dir.get_next()
	while not entry.is_empty():
		if stages_dir.current_is_dir() and not entry.begins_with("."):
			var path: String = "%s/%s/%s.tres" % [STAGE_RESOURCE_DIR, entry, stage_id]
			if ResourceLoader.exists(path):
				stages_dir.list_dir_end()
				return load(path) as StageData
		entry = stages_dir.get_next()
	stages_dir.list_dir_end()
	return null


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
	var promotion_id := str(promotion_path[promotion_path.size() - 1])
	var path: String = "%s/%s.tres" % [PROMOTION_RESOURCE_DIR, promotion_id]
	return load(path) as PromotionData if ResourceLoader.exists(path) else null


func get_item_display_name(item_id: String) -> String:
	var path := "%s/%s.tres" % [ITEM_RESOURCE_DIR, item_id]
	if ResourceLoader.exists(path):
		var item := load(path) as ItemData
		if item != null:
			return item.display_name
	return str(item_id)


func select_stage(stage_id: StringName) -> void:
	selected_stage_id = stage_id


func set_squad(character_ids: Array[String]) -> void:
	squad_character_ids = character_ids.duplicate()


func goto_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


func goto_hub() -> void:
	_change_scene(GAME_HUB_SCENE)


func goto_squad_select() -> void:
	_change_scene(SQUAD_SELECT_SCENE)


func goto_battle() -> void:
	_change_scene(BATTLE_SCENE)


func _change_scene(scene_path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
