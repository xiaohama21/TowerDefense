extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://scenes/Enemy.tscn")

## 特殊行为参数（GDD modules/BEHAVIORS.md B.3.2，v0.11.3）。
const HEALER_INTERVAL := 2.0
const HEALER_AMOUNT := 15
const HEALER_RADIUS := 120.0
const SUMMON_INTERVAL := 8.0
const SUMMON_COUNT := 2

@onready var path: Path2D = $"../Path2D"

## 分叉路径（s08 试点，Main 按 StageData.fork_path_points 注入）。
var fork_path: Path2D = null


## Spawn an enemy from an EnemyData resource. Configure before add_child(),
## because add_child triggers Enemy._ready().
func spawn_enemy_from_data(enemy_data: EnemyData) -> Enemy:
	return _spawn_on(path, enemy_data)


func _spawn_on(target_path: Path2D, enemy_data: EnemyData) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	if enemy == null:
		push_error("无法实例化敌人场景")
		return null

	enemy.enemy_id = enemy_data.enemy_id
	enemy.special_behavior_id = enemy_data.special_behavior_id
	enemy.special_cooldown = 1.5 if not enemy_data.special_behavior_id.is_empty() else 0.0
	enemy.speed = enemy_data.move_speed
	enemy.max_hp = int(round(enemy_data.max_hp * Difficulty.enemy_hp_mult(GameFlow.selected_difficulty)))
	enemy.armor = enemy_data.armor
	enemy.tags = (enemy_data.tags as Array[StringName]).duplicate()
	enemy.reward = enemy_data.currency_reward
	enemy.kill_xp = enemy_data.kill_xp
	enemy.damage_to_base = enemy_data.damage_to_base
	enemy.set_color(enemy_data.body_color)
	enemy.set_body_size(enemy_data.body_size)

	target_path.add_child(enemy)
	return enemy


func _process(delta: float) -> void:
	_process_special_behaviors(delta)


## 敌人特殊行为执行（GDD B.3.2）：healer_aura 治疗光环、summon_guard 召唤护卫。
func _process_special_behaviors(delta: float) -> void:
	for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.special_behavior_id.is_empty():
			continue
		enemy.special_cooldown = maxf(enemy.special_cooldown - delta, 0.0)
		if enemy.special_cooldown > 0.0:
			continue
		match enemy.special_behavior_id:
			&"healer_aura":
				enemy.special_cooldown = HEALER_INTERVAL
				_heal_nearby(enemy)
			&"summon_guard":
				enemy.special_cooldown = SUMMON_INTERVAL
				_summon_guards(enemy)


func _heal_nearby(source: Enemy) -> void:
	for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy == source:
			continue
		if enemy.current_hp < enemy.max_hp and enemy.global_position.distance_to(source.global_position) <= HEALER_RADIUS:
			enemy.heal(HEALER_AMOUNT)


func _summon_guards(boss: Enemy) -> void:
	var soldier := load("res://resources/enemies/yellow_turban/yellow_turban_soldier.tres") as EnemyData
	if soldier == null:
		return
	for _i in range(SUMMON_COUNT):
		var guard := _spawn_on(fork_path if fork_path != null else path, soldier)
		if guard == null:
			continue
		# 岔路召唤：护卫自岔路入口进场（无岔路时在 Boss 身后沿主路出现）
		guard.progress = 0.0 if fork_path != null else maxf(boss.progress - 60.0, 0.0)
