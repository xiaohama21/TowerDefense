extends Resource

class_name PromotionData

@export_category("Graph")
@export var promotion_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var parent_id: StringName
@export var next_promotion_ids: Array[StringName] = []
@export var target_profession: ProfessionData

@export_category("Requirements")
@export_range(1, 999, 1) var required_level: int = 10
@export var item_costs: Array[ItemAmountData] = []

@export_category("Changes")
@export_range(0.0, 100.0, 0.01) var damage_multiplier: float = 1.0
@export_range(0.0, 100.0, 0.01) var range_multiplier: float = 1.0
@export_range(0.01, 100.0, 0.01) var attack_interval_multiplier: float = 1.0
@export var granted_skill_ids: Array[StringName] = []
@export var visual_variant_id: StringName


func is_valid() -> bool:
	if promotion_id.is_empty() or display_name.is_empty() or required_level < 1:
		return false
	for item_cost in item_costs:
		if item_cost == null or not item_cost.is_valid():
			return false
	return true
