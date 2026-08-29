extends Node2D

class_name Bullet

var target: Enemy = null
var damage: int = 10
var speed: float = 400.0
var source_character_id: String = ""
var max_lifetime: float = 5.0
var hit_radius: float = 6.0

## Attack module driven by the tower profession: &"cavalry" / &"archer" /
## &"strategist" / &"dancer" each get a distinct projectile look.
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


func _draw() -> void:
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