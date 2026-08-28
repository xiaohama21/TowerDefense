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

@export_category("Progression")
@export var prerequisite_stage_ids: Array[StringName] = []
@export var first_clear_unlock_character_ids: Array[StringName] = []
@export var first_clear_rewards: Array[ItemAmountData] = []
@export var repeat_clear_rewards: Array[ItemAmountData] = []
@export_range(0, 999999, 1) var participant_xp: int = 0


func is_valid() -> bool:
	if stage_id.is_empty() or chapter_id.is_empty() or display_name.is_empty() or waves.is_empty():
		return false
	for wave in waves:
		if wave == null or not wave.is_valid():
			return false
	return _are_rewards_valid(first_clear_rewards) and _are_rewards_valid(repeat_clear_rewards)


func _are_rewards_valid(rewards: Array[ItemAmountData]) -> bool:
	for reward in rewards:
		if reward == null or not reward.is_valid():
			return false
	return true
