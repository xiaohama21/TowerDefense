extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://scenes/Enemy.tscn")

## 特殊行为参数（GDD modules/BEHAVIORS.md B.3.2，v0.11.3；数值 v0.18.0 起读 GameBalance 中心配置）。

@onready var path: Path2D = $"../Path2D"

## 分叉路径（s08 试点，Main 按 StageData.fork_path_points 注入）。
var fork_path: Path2D = null


## Spawn an enemy from an EnemyData resource. Configure before add_child(),
## because add_child triggers Enemy._ready().
func spawn_enemy_from_data(enemy_data: EnemyData) -> Enemy:
	return _spawn_on(path, enemy_data)


func _spawn_on(target_path: Path2D, enemy_data: EnemyData) -> Enemy:
	# 模板合并（v0.18.0）：引用模板的敌人先解析出完整字段再生成。
	enemy_data = enemy_data.resolved()
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	if enemy == null:
		push_error("无法实例化敌人场景")
		return null

	enemy.enemy_id = enemy_data.enemy_id
	enemy.display_name = enemy_data.display_name
	enemy.special_behavior_id = enemy_data.special_behavior_id
	# 隐匿状态（NUMBERS 10.16，✅ 0.8.13.1）：必须在 add_child 之前写入（_ready 依赖）。
	enemy.stealth = enemy_data.stealth
	enemy.special_cooldown = 1.5 if not enemy_data.special_behavior_id.is_empty() else 0.0
	enemy.speed = enemy_data.move_speed
	enemy.max_hp = int(round(enemy_data.max_hp * Difficulty.enemy_hp_mult(GameFlow.selected_difficulty)))
	enemy.armor = enemy_data.armor
	# 特殊行为参数（✅ 0.8.13.2）：armor_aura / healer_aura 读取；须在 add_child 前写入。
	enemy.special_params = enemy_data.special_params.duplicate()
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


## 当前存活敌人列表（阶段 8 军需：火攻/缓兵等全场效果使用）。
func get_alive_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_dead:
			result.append(enemy)
	return result


## 敌人特殊行为执行（GDD B.3.2）：healer_aura 治疗光环、summon_guard 召唤护卫。
func _process_special_behaviors(delta: float) -> void:
	for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy.special_behavior_id.is_empty():
			continue
		enemy.special_cooldown = maxf(enemy.special_cooldown - delta, 0.0)
		if enemy.special_cooldown > 0.0:
			continue
		var balance := GameBalance.get_balance()
		match enemy.special_behavior_id:
			&"healer_aura":
				enemy.special_cooldown = _special_float(enemy, "interval", balance.healer_interval)
				_heal_nearby(enemy)
			&"armor_aura":
				enemy.special_cooldown = _special_float(enemy, "interval", balance.armor_aura_interval)
				_apply_armor_aura(enemy)
			&"summon_guard":
				enemy.special_cooldown = balance.summon_interval
				_summon_guards(enemy)


## 特殊行为参数读取（✅ 0.8.13.2）：special_params 缺键回退 BalanceData（NUMBERS 10.17）。
func _special_float(enemy: Enemy, key: String, default_value: float) -> float:
	return float(enemy.special_params.get(key, default_value))


func _heal_nearby(source: Enemy) -> void:
	var balance := GameBalance.get_balance()
	var amount := int(_special_float(source, "amount", float(balance.healer_amount)))
	var radius := _special_float(source, "radius", balance.healer_radius)
	for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead or enemy == source:
			continue
		if enemy.current_hp < enemy.max_hp and enemy.global_position.distance_to(source.global_position) <= radius:
			enemy.heal(amount)


## 护甲光环（armor_aura，✅ 0.8.13.2 / NUMBERS 10.17）：半径内友军（含自身）加甲，
## 被覆盖单位写 duration 窗口（默认 2 个刷新周期）——施法者阵亡 / 离开半径靠窗口过期恢复。
func _apply_armor_aura(source: Enemy) -> void:
	var balance := GameBalance.get_balance()
	var bonus := int(_special_float(source, "armor_bonus", float(balance.armor_aura_bonus)))
	var radius := _special_float(source, "radius", balance.armor_aura_radius)
	var duration := _special_float(source, "duration", balance.armor_aura_duration)
	if bonus <= 0 or radius <= 0.0:
		return
	for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(source.global_position) <= radius:
			enemy.apply_armor_aura_bonus(bonus, duration)


func _summon_guards(boss: Enemy) -> void:
	var soldier := load("res://resources/enemies/yellow_turban/yellow_turban_soldier.tres") as EnemyData
	if soldier == null:
		return
	for _i in range(GameBalance.get_balance().summon_count):
		var guard := _spawn_on(fork_path if fork_path != null else path, soldier)
		if guard == null:
			continue
		# 召唤物标记（阶段 8 提交 2）：连击计入召唤物、图鉴/百科可见性后续按此区分。
		guard.is_summon = true
		# 岔路召唤：护卫自岔路入口进场（无岔路时在 Boss 身后沿主路出现）
		guard.progress = 0.0 if fork_path != null else maxf(boss.progress - 60.0, 0.0)
