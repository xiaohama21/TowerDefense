extends Resource

class_name StageData

@export_category("Identity")
@export var stage_id: StringName
@export var chapter_id: StringName
@export_range(1, 999, 1) var stage_number: int = 1
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var stage_scene: PackedScene

@export_category("Rules")
@export_range(1, 99, 1) var starting_lives: int = 20
@export_range(0, 99999, 1) var starting_currency: int = 100
@export_range(1, 99, 1) var squad_size: int = 4
@export_range(1, 99, 1) var build_slot_count: int = 10
@export var waves: Array[WaveData] = []

@export_category("In-battle Economy")
## 局内升级/回收参数（GDD 5.4）。第 n 次升级费用 = build_cost × upgrade_cost_factor × n；
## 回收返还 = 总投入 × sell_refund_ratio（向上取整）。均为局内临时数值，不入存档。
@export_range(0, 9, 1) var max_inbattle_upgrade_level: int = 2
@export_range(0.0, 10.0, 0.05) var upgrade_cost_factor: float = 0.8
@export_range(0.0, 1.0, 0.05) var sell_refund_ratio: float = 0.6

@export_category("Layout")
## 战场布局（v0.9 数据驱动化）。path_points 为直角折线拐点（含图外出入口延长段），
## 建造位与装饰格子由关卡数据而非场景硬编码提供；道路格子由 path_points 逐格推导。
## 开场剧情（v0.12）：战斗开始前播放；空则无对话。
@export var dialogue: DialogueData
## 地图主题（v0.12，见 GridBackground 调色板）：grass / fire / night ...
@export var theme: StringName = &"grass"
@export var path_points: Array[Vector2] = []
## 分叉路径（v0.11.3 s08 试点）：召唤护卫自此路径进场；空则无双路。
@export var fork_path_points: Array[Vector2] = []
@export var build_slot_positions: Array[Vector2] = []
## 结构化建造位（v0.14.1，GDD 5.1）：位置/类型/预锁位；非空时优先于 build_slot_positions。
@export var build_slots: Array[BuildSlotData] = []
@export var decor_cells: Array[Vector2i] = []

@export_category("Progression")
@export var prerequisite_stage_ids: Array[StringName] = []
@export var first_clear_unlock_character_ids: Array[StringName] = []
@export var first_clear_rewards: Array[ItemAmountData] = []
## Boss 首掉信物（v0.13）：首次通关直接授予（如章节 Boss → 专属信物）。
@export var first_clear_relic: RelicData
@export var repeat_clear_rewards: Array[ItemAmountData] = []
## 概率掉落（v0.13）：重复通关时逐条掷点，命中计入战局掉落。
@export var probability_drops: Array[DropEntryData] = []
@export_range(0, 999999, 1) var participant_xp: int = 0


func is_valid() -> bool:
	if stage_id.is_empty() or chapter_id.is_empty() or display_name.is_empty() or waves.is_empty():
		return false
	for wave in waves:
		if wave == null or not wave.is_valid():
			return false
	for slot in build_slots:
		if slot == null:
			return false
	return _are_rewards_valid(first_clear_rewards) and _are_rewards_valid(repeat_clear_rewards)


## 生效建造位（v0.14.1）：build_slots 非空时用之；否则由 build_slot_positions 推导
## （全部通用位、未锁定），保持旧关卡配置向后兼容。
func get_build_slot_data() -> Array[BuildSlotData]:
	if not build_slots.is_empty():
		return build_slots
	var result: Array[BuildSlotData] = []
	for position in build_slot_positions:
		var slot := BuildSlotData.new()
		slot.position = position
		result.append(slot)
	return result


func _are_rewards_valid(rewards: Array[ItemAmountData]) -> bool:
	for reward in rewards:
		if reward == null or not reward.is_valid():
			return false
	return true

