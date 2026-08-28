extends Resource

class_name ItemAmountData

@export var item: ItemData
@export_range(1, 999999, 1) var amount: int = 1


func is_valid() -> bool:
	return item != null and amount > 0
