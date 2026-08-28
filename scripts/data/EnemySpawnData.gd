extends Resource

class_name EnemySpawnData

@export var enemy: EnemyData
@export_range(1, 999, 1) var count: int = 1
@export_range(0.0, 60.0, 0.05) var spawn_interval: float = 1.0
@export_range(0.0, 300.0, 0.05) var start_delay: float = 0.0
@export var path_id: StringName = &"main"


func is_valid() -> bool:
	return enemy != null and count > 0 and spawn_interval >= 0.0 and start_delay >= 0.0
