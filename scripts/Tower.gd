extends Node2D

class_name Tower

const BULLET_SCENE: PackedScene = preload("res://scenes/Bullet.tscn")
const TOWER_GROUP: StringName = &"towers"
const RANGE_FILL_COLOR := Color(0.22, 0.76, 0.88, 0.13)
const RANGE_BORDER_COLOR := Color(0.68, 0.97, 1.0, 0.96)
const RANGE_BORDER_WIDTH := 3.5
const PROFESSION_COLORS := {
	&"cavalry": Color(0.76, 0.24, 0.2, 1.0),
	&"pikeman": Color(0.3, 0.62, 0.45, 1.0),
	&"archer": Color(0.85, 0.55, 0.22, 1.0),
	&"strategist": Color(0.28, 0.5, 0.85, 1.0),
	&"dancer": Color(0.85, 0.42, 0.66, 1.0),
}

@export var range_radius: float = 150.0
@export var damage: int = 40
@export var attack_cooldown: float = 0.8
@export var bullet_speed: float = 400.0
@export var character_id: String = ""
@export var display_name: String = ""

# Keep this untyped: a freed Godot object can no longer satisfy a script-class
# annotation during the one frame before the reference is replaced.
var target = null
var is_selected: bool = false

var _profession_id: StringName = StringName()
var _hero_color: Color = Color(0.45, 0.55, 0.65, 1.0)
var _aim_angle: float = -PI / 2.0
var _attack_flash: float = 0.0

@onready var attack_timer: Timer = $AttackTimer
@onready var range_area: Area2D = $RangeArea
@onready var selection_area: Area2D = $SelectionArea
@onready var muzzle: Marker2D = $Muzzle
@onready var name_label: Label = $NameLabel


func _enter_tree() -> void:
	add_to_group(TOWER_GROUP)


func _ready() -> void:
	attack_timer.one_shot = true
	_rebuild_attack_timer()
	_rebuild_range_area()
	if not display_name.is_empty():
		name_label.text = display_name
	selection_area.input_event.connect(_on_selection_area_input_event)
	queue_redraw()


## Apply a CharacterData to this tower. Call after add_child() so all
## onready nodes are available.
func apply_character(character_data: CharacterData) -> void:
	character_id = character_data.character_id
	display_name = character_data.display_name
	damage = character_data.base_damage
	range_radius = character_data.base_range
	attack_cooldown = character_data.attack_interval
	bullet_speed = character_data.projectile_speed

	_profession_id = character_data.profession.profession_id if character_data.profession != null else StringName()
	_hero_color = PROFESSION_COLORS.get(_profession_id, Color(0.45, 0.55, 0.65, 1.0))
	name_label.text = display_name
	name_label.add_theme_color_override("font_color", _hero_color.lightened(0.35))
	_rebuild_attack_timer()
	_rebuild_range_area()
	queue_redraw()


func _rebuild_attack_timer() -> void:
	attack_timer.wait_time = maxf(attack_cooldown, 0.01)


func _rebuild_range_area() -> void:
	var circle := CircleShape2D.new()
	circle.radius = maxf(range_radius, 0.0)
	var collision_shape := range_area.get_node("CollisionShape2D") as CollisionShape2D
	collision_shape.shape = circle


func _unhandled_input(event: InputEvent) -> void:
	if not is_selected:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			set_selected(false)


func _process(_delta: float) -> void:
	if not _is_target_in_range(target):
		target = find_target()

	if target:
		_update_aim()
	if target and attack_timer.is_stopped():
		attack()

	if _attack_flash > 0.0:
		_attack_flash = maxf(_attack_flash - _delta, 0.0)
		queue_redraw()


func find_target() -> Enemy:
	var best_target: Enemy = null
	var best_progress := -1.0
	var range_squared := range_radius * range_radius

	for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		if global_position.distance_squared_to(enemy.global_position) > range_squared:
			continue
		if enemy.progress_ratio > best_progress:
			best_progress = enemy.progress_ratio
			best_target = enemy

	return best_target


func attack() -> void:
	if not _is_target_in_range(target):
		target = null
		return

	var bullet := BULLET_SCENE.instantiate() as Bullet
	if bullet == null:
		push_error("无法实例化子弹场景")
		return

	bullet.target = target
	bullet.damage = damage
	bullet.speed = bullet_speed
	bullet.source_character_id = character_id
	bullet.kind = _profession_id
	bullet.color = _hero_color

	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		bullet.free()
		return
	projectile_parent.add_child(bullet)
	bullet.global_position = muzzle.global_position
	_attack_flash = 0.18
	queue_redraw()
	attack_timer.start()


func _is_target_in_range(candidate) -> bool:
	# A typed Enemy reference can still point at a freed object for one frame.
	# Accept Object here so the validity check happens before any Enemy access.
	if not is_instance_valid(candidate):
		return false
	var enemy := candidate as Enemy
	if enemy == null or enemy.is_dead or not enemy.is_inside_tree():
		return false
	return global_position.distance_squared_to(enemy.global_position) <= range_radius * range_radius


func _update_aim() -> void:
	var direction := to_local(target.global_position)
	_aim_angle = direction.angle()
	muzzle.position = Vector2.from_angle(_aim_angle) * 30.0
	queue_redraw()


func set_selected(selected: bool) -> void:
	if is_selected == selected:
		return
	is_selected = selected
	queue_redraw()


func _on_selection_area_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var should_select := not is_selected
	for node in get_tree().get_nodes_in_group(TOWER_GROUP):
		if node == self:
			set_selected(should_select)
		elif node.has_method("set_selected"):
			node.set_selected(false)
	get_viewport().set_input_as_handled()


func _draw() -> void:
	_draw_base()
	_draw_body()
	_draw_weapon()
	if _attack_flash > 0.0:
		_draw_attack_flash()
	if is_selected:
		_draw_range()


func _draw_base() -> void:
	draw_circle(Vector2.ZERO, 22.0, _hero_color.darkened(0.45))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 28, _hero_color.darkened(0.15), 2.5, true)


func _draw_body() -> void:
	match _profession_id:
		&"cavalry":
			# 马身 + 骑手
			draw_set_transform(Vector2(0, 5), 0.0, Vector2(1.5, 1.0))
			draw_circle(Vector2.ZERO, 9.0, _hero_color.darkened(0.15))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_circle(Vector2(0, -6), 6.5, _hero_color)
		&"archer":
			draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 1.3))
			draw_circle(Vector2.ZERO, 8.5, _hero_color.darkened(0.1))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_circle(Vector2(0, -2), 6.0, _hero_color)
		&"strategist":
			var robe := PackedVector2Array([
				Vector2(0, -15), Vector2(11, 9), Vector2(7, 14),
				Vector2(-7, 14), Vector2(-11, 9),
			])
			draw_colored_polygon(robe, _hero_color.darkened(0.12))
			draw_circle(Vector2(0, -2), 6.5, _hero_color.lightened(0.18))
		&"dancer":
			var skirt := PackedVector2Array([
				Vector2(0, -13), Vector2(12, 4), Vector2(8, 13),
				Vector2(-8, 13), Vector2(-12, 4),
			])
			draw_colored_polygon(skirt, _hero_color)
			draw_circle(Vector2(0, -11), 5.5, _hero_color.lightened(0.25))
		_:
			draw_circle(Vector2.ZERO, 12.0, _hero_color)


func _draw_weapon() -> void:
	# Weapons are authored pointing "up" and rotated towards the aim angle.
	draw_set_transform(Vector2.ZERO, _aim_angle + PI / 2.0, Vector2.ONE)
	match _profession_id:
		&"cavalry":
			draw_line(Vector2(0, 6), Vector2(0, -34), Color(0.78, 0.75, 0.66, 1.0), 3.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-3, -34), Vector2(3, -34), Vector2(0, -43),
			]), Color(0.92, 0.93, 0.95, 1.0))
		&"archer":
			draw_arc(Vector2(0, -6), 15.0, -PI * 0.55, PI * 0.55, 14,
				Color(0.62, 0.45, 0.24, 1.0), 3.0)
			draw_line(Vector2(0, -21), Vector2(0, 9), Color(0.9, 0.9, 0.85, 1.0), 1.5)
		&"strategist":
			draw_line(Vector2(0, 10), Vector2(0, -30), Color(0.6, 0.5, 0.35, 1.0), 2.5)
			draw_circle(Vector2(0, -32), 5.0, _hero_color.lightened(0.3))
		&"dancer":
			draw_arc(Vector2(0, -2), 17.0, PI * 0.15, PI * 0.85, 12,
				_hero_color.lightened(0.3), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_attack_flash() -> void:
	draw_set_transform(Vector2.ZERO, _aim_angle + PI / 2.0, Vector2.ONE)
	draw_circle(Vector2(0, -40), 6.0, Color(1.0, 0.95, 0.6, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_range() -> void:
	draw_circle(Vector2.ZERO, range_radius, RANGE_FILL_COLOR, true, -1.0, true)
	draw_arc(Vector2.ZERO, range_radius, 0.0, TAU, 96, RANGE_BORDER_COLOR, RANGE_BORDER_WIDTH, true)
	draw_circle(Vector2.ZERO, 5.0, RANGE_BORDER_COLOR, true, -1.0, true)