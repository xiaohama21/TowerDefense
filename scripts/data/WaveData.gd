extends Resource

class_name WaveData

@export var wave_id: StringName
@export_range(1, 999, 1) var wave_number: int = 1
@export var spawn_groups: Array[EnemySpawnData] = []
@export_range(0.0, 300.0, 0.1) var preparation_time: float = 0.0
@export_range(0, 99999, 1) var completion_currency: int = 0
@export var is_boss_wave: bool = false


func is_valid() -> bool:
	if wave_id.is_empty() or spawn_groups.is_empty():
		return false
	for spawn_group in spawn_groups:
		if spawn_group == null or not spawn_group.is_valid():
			return false
	return true
