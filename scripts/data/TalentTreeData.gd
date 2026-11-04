extends Resource
class_name TalentTreeData

@export var tree_id: String = ""
@export var display_name: String = ""
@export var role: String = ""
@export var icon_key: String = ""
@export var nodes: Array[Dictionary] = []

func get_node_data(id: String) -> Dictionary:
	for entry in nodes:
		if str(entry.get("id", "")) == id:
			return entry.duplicate(true)
	return {}
