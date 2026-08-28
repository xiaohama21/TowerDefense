extends Node

signal wave_completed

@onready var enemy_manager = $"../EnemyManager"

var waves: Array[WaveData] = []

var is_spawning: bool = false


func configure_waves(stage_waves: Array) -> void:
	waves.clear()
	for wave in stage_waves:
		if wave is WaveData:
			waves.append(wave)


func start_wave(wave_index: int):
	if wave_index < 0 or wave_index >= waves.size() or is_spawning:
		return
	if not GameManager.start_wave():
		return

	var wave: WaveData = waves[wave_index]
	is_spawning = true

	for group in wave.spawn_groups:
		for i in range(group.count):
			if group.enemy != null:
				enemy_manager.spawn_enemy_from_data(group.enemy)
			if group.spawn_interval > 0.0:
				# 波次计时器随游戏暂停，避免暂停时仍在后台刷怪。
				await get_tree().create_timer(group.spawn_interval, false).timeout

	is_spawning = false

func _process(_delta):
	if GameManager.is_wave_active and not is_spawning:
		# 检查是否还有敌人存活
		var enemies = get_tree().get_nodes_in_group("enemies")
		if enemies.is_empty():
			wave_completed.emit()
