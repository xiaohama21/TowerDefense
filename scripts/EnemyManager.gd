extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://scenes/Enemy.tscn")

@onready var path: Path2D = $"../Path2D"


func spawn_enemy(enemy_type: String = "slime") -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	if enemy == null:
		push_error("无法实例化敌人场景")
		return null

	# Configure before add_child(), because add_child triggers Enemy._ready().
	match enemy_type:
		"slime":
			enemy.enemy_id = &"slime"
			enemy.speed = 80.0
			enemy.max_hp = 100
			enemy.reward = 10
			enemy.kill_xp = 8
			enemy.set_color(Color.GREEN)
		"goblin":
			enemy.enemy_id = &"goblin"
			enemy.speed = 120.0
			enemy.max_hp = 200
			enemy.reward = 15
			enemy.kill_xp = 12
			enemy.set_color(Color.RED)
		"boss":
			enemy.enemy_id = &"boss"
			enemy.speed = 40.0
			enemy.max_hp = 800
			enemy.reward = 50
			enemy.kill_xp = 100
			enemy.damage_to_base = 5
			enemy.set_color(Color.PURPLE)
			enemy.set_body_size(Vector2(60, 60))
		_:
			push_warning("未知敌人类型 '%s'，将使用 slime 配置" % enemy_type)
			enemy.speed = 80.0
			enemy.max_hp = 100
			enemy.reward = 10
			enemy.kill_xp = 8
			enemy.set_color(Color.GREEN)

	path.add_child(enemy)
	return enemy


## Spawn an enemy from an EnemyData resource. Configure before add_child(),
## because add_child triggers Enemy._ready().
func spawn_enemy_from_data(enemy_data: EnemyData) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	if enemy == null:
		push_error("无法实例化敌人场景")
		return null

	enemy.enemy_id = enemy_data.enemy_id
	enemy.speed = enemy_data.move_speed
	enemy.max_hp = enemy_data.max_hp
	enemy.reward = enemy_data.currency_reward
	enemy.kill_xp = enemy_data.kill_xp
	enemy.damage_to_base = enemy_data.damage_to_base
	enemy.set_color(enemy_data.body_color)
	enemy.set_body_size(enemy_data.body_size)

	path.add_child(enemy)
	return enemy
