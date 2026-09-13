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
	enemy.extra_behavior_ids.assign(enemy_data.extra_behavior_ids)
	# 隐匿状态（NUMBERS 10.16，✅ 0.8.13.1）：必须在 add_child 之前写入（_ready 依赖）。
	enemy.stealth = enemy_data.stealth
	enemy.speed = enemy_data.move_speed
	enemy.max_hp = int(round(enemy_data.max_hp * Difficulty.enemy_hp_mult(GameFlow.selected_difficulty)))
	enemy.armor = enemy_data.armor
	# 特殊行为参数（✅ 0.8.13.2）：armor_aura / healer_aura 读取；须在 add_child 前写入。
	enemy.special_params = enemy_data.special_params.duplicate()
	# 多行为冷却初始化（✅ 0.8.13.4）：每个行为独立计时、统一 1.5s 首延迟。
	for behavior_id in get_behavior_ids_for(enemy):
		enemy.set_special_cooldown(behavior_id, 1.5)
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


## 敌人特殊行为执行（GDD B.3.2）：按「主行为 + 附加行为」逐个调度（✅ 0.8.13.4 多行为），
## 每个行为独立冷却；special_params["<行为>_min_hp_ratio"] 为可选血量门控（阶段行为）。
func _process_special_behaviors(delta: float) -> void:
	for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		for behavior_id in get_behavior_ids_for(enemy):
			var cooldown := maxf(enemy.get_special_cooldown(behavior_id) - delta, 0.0)
			enemy.set_special_cooldown(behavior_id, cooldown)
			if cooldown > 0.0 or not _behavior_phase_ready(enemy, behavior_id):
				continue
			_run_special_behavior(enemy, behavior_id)


## 行为 ID 列表（✅ 0.8.13.4）：主行为在前、附加行为随后（去重、保序）。
func get_behavior_ids_for(enemy: Enemy) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not enemy.special_behavior_id.is_empty():
		ids.append(enemy.special_behavior_id)
	for extra_id in enemy.extra_behavior_ids:
		if not extra_id.is_empty() and not ids.has(extra_id):
			ids.append(extra_id)
	return ids


## 阶段门控（✅ 0.8.13.4）：special_params["<behavior_id>_min_hp_ratio"] 有值时，
## HP 比例高于阈值不触发——且不消耗冷却，跌破阈值当帧即可触发（张宝 P2 召唤 = 0.5）。
func _behavior_phase_ready(enemy: Enemy, behavior_id: StringName) -> bool:
	var gate := float(enemy.special_params.get("%s_min_hp_ratio" % str(behavior_id), 0.0))
	if gate <= 0.0:
		return true
	return float(enemy.current_hp) / float(maxi(enemy.max_hp, 1)) <= gate


## 行为分发（✅ 0.8.13.4）：按行为 ID 执行并写入各自冷却。
func _run_special_behavior(enemy: Enemy, behavior_id: StringName) -> void:
	var balance := GameBalance.get_balance()
	match behavior_id:
		&"healer_aura":
			enemy.set_special_cooldown(behavior_id,
				_special_float(enemy, behavior_id, "interval", balance.healer_interval))
			_heal_nearby(enemy)
		&"armor_aura":
			enemy.set_special_cooldown(behavior_id,
				_special_float(enemy, behavior_id, "interval", balance.armor_aura_interval))
			_apply_armor_aura(enemy)
		&"summon_guard":
			enemy.set_special_cooldown(behavior_id,
				_special_float(enemy, behavior_id, "summon_interval", balance.summon_interval))
			_summon_guards(enemy)
		&"seal_domain":
			enemy.set_special_cooldown(behavior_id,
				_special_float(enemy, behavior_id, "interval", balance.seal_domain_interval))
			_apply_seal_domain(enemy)


## 特殊行为参数读取（✅ 0.8.13.2 / 多行为 ✅ 0.8.13.4）：优先读 special_params[<behavior_id>]
## 嵌套字典，缺键回退扁平键与 BalanceData 缺省（NUMBERS 10.17·10.20）。
func _special_float(enemy: Enemy, behavior_id: StringName, key: String, default_value: float) -> float:
	var scope: Variant = enemy.special_params.get(str(behavior_id), null)
	if scope is Dictionary and scope.has(key):
		return float(scope[key])
	return float(enemy.special_params.get(key, default_value))


func _heal_nearby(source: Enemy) -> void:
	var balance := GameBalance.get_balance()
	var amount := int(_special_float(source, &"healer_aura", "amount", float(balance.healer_amount)))
	var radius := _special_float(source, &"healer_aura", "radius", balance.healer_radius)
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
	var bonus := int(_special_float(source, &"armor_aura", "armor_bonus", float(balance.armor_aura_bonus)))
	var radius := _special_float(source, &"armor_aura", "radius", balance.armor_aura_radius)
	var duration := _special_float(source, &"armor_aura", "duration", balance.armor_aura_duration)
	if bonus <= 0 or radius <= 0.0:
		return
	for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(source.global_position) <= radius:
			enemy.apply_armor_aura_bonus(bonus, duration)


## 召唤（summon_guard，✅ 0.8.13.4 参数化）：召唤对象 / 数量 / 间隔 / 上限均可由 special_params 覆盖
## （缺省黄巾步卒 ×2 / 8s / 无上限）；有岔路自岔路入口进场，无岔路时在 Boss 身后 60px 沿主路出现。
func _summon_guards(boss: Enemy) -> void:
	var balance := GameBalance.get_balance()
	var summon_id := str(boss.special_params.get("summon_enemy_id", "yellow_turban_soldier"))
	var guard_data := load("res://resources/enemies/yellow_turban/%s.tres" % summon_id) as EnemyData
	if guard_data == null:
		return
	var count := int(_special_float(boss, &"summon_guard", "summon_count", float(balance.summon_count)))
	var max_summons := int(boss.special_params.get("max_summons", 0))
	if max_summons > 0:
		count = mini(count, maxi(max_summons - boss.summoned_count, 0))
	if count <= 0:
		return
	for _i in range(count):
		var guard := _spawn_on(fork_path if fork_path != null else path, guard_data)
		if guard == null:
			continue
		# 召唤物标记（阶段 8 提交 2）：连击计入召唤物、图鉴/百科可见性后续按此区分。
		guard.is_summon = true
		boss.summoned_count += 1
		# 岔路召唤：护卫自岔路入口进场（无岔路时在 Boss 身后沿主路出现）
		guard.progress = 0.0 if fork_path != null else maxf(boss.progress - 60.0, 0.0)


## 术法压制领域（seal_domain，✅ 0.8.13.4 / NUMBERS 10.20）：对半径内塔施加减攻速状态，
## 塔侧写入 duration 窗口、过期自动恢复（施法者阵亡 / 离开半径无需清理）。
func _apply_seal_domain(source: Enemy) -> void:
	var balance := GameBalance.get_balance()
	var radius := _special_float(source, &"seal_domain", "radius", balance.seal_domain_radius)
	var multiplier := _special_float(source, &"seal_domain", "speed_multiplier", balance.seal_domain_speed_multiplier)
	var duration := _special_float(source, &"seal_domain", "duration", balance.seal_domain_duration)
	if radius <= 0.0 or multiplier >= 1.0 or duration <= 0.0:
		return
	for node in get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var tower := node as Tower
		if tower == null or not is_instance_valid(tower):
			continue
		if tower.global_position.distance_to(source.global_position) <= radius:
			tower.apply_attack_speed_debuff("enemy_seal_domain", multiplier, duration)
