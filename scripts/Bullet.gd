extends Node2D

class_name Bullet

var target: Enemy = null
var damage: int = 10
var speed: float = 400.0
var source_character_id: String = ""
var max_lifetime: float = 5.0
var hit_radius: float = 6.0

## 抛射模式（v0.11 投石车 lob_aoe）：飞向固定落点（而非追踪目标），
## 到达后以 explosion_radius 造成范围伤害；arc height 仅作绘制抬升。
var lob_landing := Vector2.ZERO
var explosion_radius := 0.0
var lob_arc_height := 56.0
var _lob_total_distance := 0.0
var _lob_traveled := 0.0

## Attack module driven by the tower profession: &"archer" / &"strategist" /
## &"dancer" each get a distinct projectile look.
var kind: StringName = StringName()
var color: Color = Color.WHITE

var _lifetime: float = 0.0
var _pulse: float = 0.0


func _physics_process(delta: float) -> void:
	_lifetime += delta
	_pulse += delta * 10.0
	if _lifetime >= max_lifetime:
		queue_free()
		return

	if explosion_radius > 0.0 and lob_landing != Vector2.ZERO:
		_process_lob(delta)
		return

	if not is_instance_valid(target) or target.is_dead:
		queue_free()
		return

	var offset := target.global_position - global_position
	var distance := offset.length()
	var travel_distance := maxf(speed, 0.0) * delta

	# Hit immediately when this frame's movement can reach the target. This
	# avoids fast bullets skipping past it on a low frame rate.
	if distance <= hit_radius or travel_distance >= distance:
		target.take_damage(damage, source_character_id)
		queue_free()
		return

	var direction := offset / distance
	global_position += direction * travel_distance
	rotation = direction.angle()
	queue_redraw()


## 启动抛射：设定落点与爆炸半径，飞行总距离据此计算。
func launch_lob(landing: Vector2, radius: float) -> void:
	lob_landing = landing
	explosion_radius = radius
	_lob_total_distance = global_position.distance_to(landing)


func _process_lob(delta: float) -> void:
	var offset := lob_landing - global_position
	var travel_distance := maxf(speed, 0.0) * delta
	_lob_traveled += travel_distance
	if offset.length() <= travel_distance:
		global_position = lob_landing
		_explode()
		queue_free()
		return
	global_position += offset.normalized() * travel_distance
	queue_redraw()


## 落点范围伤害：对该范围内所有存活敌人结算（来源计入经验归属台账）。
func _explode() -> void:
	var enemies := get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP)
	for node in enemies:
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(lob_landing) <= explosion_radius:
			enemy.take_damage(damage, source_character_id)


func _draw_lob() -> void:
	# 抛射表现：地面阴影 + 抬升的石弹（sin 弧），落地前一圈冲击预备线。
	var t := clampf(_lob_traveled / maxf(_lob_total_distance, 0.01), 0.0, 1.0)
	var height := sin(t * PI) * lob_arc_height
	draw_circle(Vector2.ZERO, 5.0, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(Vector2(0, -height), 8.0, color.lightened(0.1))
	draw_arc(Vector2(0, -height), 8.0, 0.0, TAU, 14, color.darkened(0.35), 2.0, true)
	if t > 0.6:
		var ring_alpha := (t - 0.6) / 0.4 * 0.5
		draw_arc(Vector2.ZERO, explosion_radius * (t - 0.6) / 0.4, 0.0, TAU, 24,
			Color(1.0, 0.9, 0.6, ring_alpha), 2.0, true)


func _draw() -> void:
	if explosion_radius > 0.0:
		_draw_lob()
		return
	match kind:
		&"archer":
			# 箭矢：杆 + 箭头 + 尾羽
			draw_line(Vector2(-12, 0), Vector2(8, 0), Color(0.72, 0.55, 0.3, 1.0), 2.5)
			draw_colored_polygon(PackedVector2Array([
				Vector2(14, 0), Vector2(7, -3), Vector2(7, 3),
			]), Color(0.92, 0.93, 0.95, 1.0))
			draw_line(Vector2(-12, 0), Vector2(-16, -4), Color(0.9, 0.35, 0.3, 1.0), 1.5)
			draw_line(Vector2(-12, 0), Vector2(-16, 4), Color(0.9, 0.35, 0.3, 1.0), 1.5)
		&"strategist":
			# 法球：光晕 + 核心，随脉冲缩放
			var radius := 7.0 + sin(_pulse) * 1.5
			draw_circle(Vector2.ZERO, radius + 4.0, Color(color.r, color.g, color.b, 0.28))
			draw_circle(Vector2.ZERO, radius, color.lightened(0.25))
			draw_arc(Vector2.ZERO, radius + 1.5, 0.0, TAU, 16, Color.WHITE, 1.0, true)
		&"dancer":
			# 音波环：双层圆环扩散
			var ring_radius := 5.0 + fmod(_pulse, 4.0)
			draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 20,
				Color(color.r, color.g, color.b, 0.9), 2.5, true)
			draw_arc(Vector2.ZERO, ring_radius * 0.55, 0.0, TAU, 16,
				Color(color.r, color.g, color.b, 0.55), 1.5, true)
		_:
			draw_circle(Vector2.ZERO, 5.0, color)
			draw_circle(Vector2.ZERO, 2.5, Color.WHITE)