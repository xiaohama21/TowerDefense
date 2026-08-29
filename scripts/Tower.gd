extends Node2D

class_name Tower

const BULLET_SCENE: PackedScene = preload("res://scenes/Bullet.tscn")
const TOWER_GROUP: StringName = &"towers"
const RANGE_FILL_COLOR := Color(0.22, 0.76, 0.88, 0.13)
const RANGE_BORDER_COLOR := Color(0.68, 0.97, 1.0, 0.96)
const RANGE_BORDER_WIDTH := 3.5
## 局内升级每级伤害增幅（GDD 5.4：伤害 +25%/级，与 10.5 大招倍率同源）。
const UPGRADE_DAMAGE_STEP := 0.25
# 近战挥击表现（GDD modules/BEHAVIORS.md B.3.1）：武器从一侧扫到另一侧，
# 并带一道渐隐斩击弧；表现由 melee_thrust 执行器经 play_melee_hit() 触发。
const MELEE_SWING_DURATION := 0.22
const MELEE_SWING_FROM := -1.35
const MELEE_SWING_TO := 0.95
const MELEE_SLASH_RADIUS := 38.0
const PROFESSION_COLORS := {
	&"cavalry": Color(0.76, 0.24, 0.2, 1.0),
	&"pikeman": Color(0.3, 0.62, 0.45, 1.0),
	&"archer": Color(0.85, 0.55, 0.22, 1.0),
	&"strategist": Color(0.28, 0.5, 0.85, 1.0),
	&"dancer": Color(0.85, 0.42, 0.66, 1.0),
}

signal selection_changed(tower: Tower)

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

# 局内临时状态（GDD 5.4）：升级等级与总投入只存在于本局，不写入存档。
var battle_level: int = 0
var total_invested: int = 0
var build_cost: int = 0
var assigned_slot: Node = null

var _profession_id: StringName = StringName()
var _profession_name: String = ""
var _behavior_id: StringName = StringName()
var _base_damage: int = 40
var _hero_color: Color = Color(0.45, 0.55, 0.65, 1.0)
var _aim_angle: float = -PI / 2.0
var _attack_flash: float = 0.0
var _melee_swing: float = 0.0

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
## onready nodes are available. level/promotion 来自存档养成状态
## （GDD modules/CHARACTERS.md 4.4/4.5），属性经 compute_stats_at 统一计算。
func apply_character(character_data: CharacterData, level: int = 1, promotion: PromotionData = null) -> void:
	character_id = character_data.character_id
	display_name = character_data.display_name
	var stats := character_data.compute_stats_at(level, promotion)
	damage = stats.damage
	_base_damage = damage
	range_radius = stats.range
	attack_cooldown = stats.attack_interval
	bullet_speed = character_data.projectile_speed
	build_cost = character_data.build_cost

	_profession_id = character_data.profession.profession_id if character_data.profession != null else StringName()
	_profession_name = character_data.profession.display_name if character_data.profession != null else ""
	_behavior_id = character_data.profession.behavior_id if character_data.profession != null else StringName()
	if _behavior_id.is_empty():
		_behavior_id = &"single_target_burst"
	_hero_color = PROFESSION_COLORS.get(_profession_id, Color(0.45, 0.55, 0.65, 1.0))
	name_label.text = display_name
	name_label.add_theme_color_override("font_color", _hero_color.lightened(0.35))
	_rebuild_attack_timer()
	_rebuild_range_area()
	queue_redraw()


func get_profession_id() -> StringName:
	return _profession_id


func get_profession_name() -> String:
	return _profession_name


func get_upgrade_cost(upgrade_cost_factor: float) -> int:
	## 第 n 次升级费用 = build_cost × factor × n（n 从 1 起，向上取整）。
	return ceili(build_cost * upgrade_cost_factor * (battle_level + 1))


func get_sell_refund(sell_refund_ratio: float) -> int:
	## 回收返还 = 总投入 × 比例，向上取整（GDD 5.4）。
	return ceili(total_invested * sell_refund_ratio)


func apply_upgrade(spent_cost: int) -> void:
	battle_level += 1
	total_invested += spent_cost
	damage = int(round(_base_damage * (1.0 + UPGRADE_DAMAGE_STEP * battle_level)))
	queue_redraw()


func record_build_investment(cost: int) -> void:
	build_cost = cost if cost > 0 else build_cost
	total_invested = cost


func play_attack_flash() -> void:
	## 弹道类攻击的枪口闪光，由弹道执行器触发。
	_attack_flash = 0.18
	queue_redraw()


func play_melee_hit() -> void:
	## 近战挥击，由近战执行器触发；不产生枪口闪光。
	_melee_swing = MELEE_SWING_DURATION
	queue_redraw()


func is_swinging() -> bool:
	return _melee_swing > 0.0


func _swing_offset() -> float:
	if _melee_swing <= 0.0:
		return 0.0
	var t := 1.0 - _melee_swing / MELEE_SWING_DURATION
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	return lerpf(MELEE_SWING_FROM, MELEE_SWING_TO, eased)


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
	if _melee_swing > 0.0:
		_melee_swing = maxf(_melee_swing - _delta, 0.0)
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

	# 攻击行为按职业 behavior_id 分发（GDD modules/BEHAVIORS.md），
	# 塔脚本不硬编码任何职业的攻击逻辑与攻击表现。
	BehaviorRegistry.execute_attack(_behavior_id, self, target)
	attack_timer.start()


## 供弹道类行为执行器调用：生成并挂载一枚按职业着色的子弹。
## 伤害与职业克制由执行器负责写入。
func instantiate_bullet(target_enemy: Enemy) -> Bullet:
	var bullet := BULLET_SCENE.instantiate() as Bullet
	if bullet == null:
		push_error("无法实例化子弹场景")
		return null

	bullet.target = target_enemy
	bullet.damage = damage
	bullet.speed = bullet_speed
	bullet.source_character_id = character_id
	bullet.kind = _profession_id
	bullet.color = _hero_color

	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		bullet.free()
		return null
	projectile_parent.add_child(bullet)
	bullet.global_position = muzzle.global_position
	return bullet


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
	selection_changed.emit(self)


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
	if _melee_swing > 0.0:
		_draw_slash_arc()
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
		&"pikeman":
			# 剑客：挺拔身形 + 肩上剑刃
			draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 1.25))
			draw_circle(Vector2.ZERO, 8.0, _hero_color.darkened(0.1))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_circle(Vector2(0, -4), 6.0, _hero_color)
			var blade := PackedVector2Array([
				Vector2(9, 6), Vector2(13, -8), Vector2(10, -9), Vector2(7, 5),
			])
			draw_colored_polygon(blade, Color(0.88, 0.9, 0.93, 1.0))
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


func _draw_slash_arc() -> void:
	# 挥击弧：从挥击起点画到当前位置，随挥动渐隐，跟随瞄准方向；
	# 弧光按职业配色着色（骑兵偏红、剑客偏绿）。
	var t := 1.0 - _melee_swing / MELEE_SWING_DURATION
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var current := _aim_angle + lerpf(MELEE_SWING_FROM, MELEE_SWING_TO, eased)
	var start := _aim_angle + MELEE_SWING_FROM
	var alpha := clampf(0.9 - t * 0.75, 0.12, 0.9)
	var tint := Color(1.0, 0.98, 0.9).lerp(_hero_color, 0.35)
	draw_arc(Vector2.ZERO, MELEE_SLASH_RADIUS, start, current, 14,
		Color(tint.r, tint.g, tint.b, alpha), 4.0)


func _draw_weapon() -> void:
	# Weapons are authored pointing "up" and rotated towards the aim angle;
	# 近战挥击期间武器沿扫击方向偏转。
	draw_set_transform(Vector2.ZERO, _aim_angle + PI / 2.0 + _swing_offset(), Vector2.ONE)
	match _profession_id:
		&"cavalry":
			draw_line(Vector2(0, 6), Vector2(0, -34), Color(0.78, 0.75, 0.66, 1.0), 3.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-3, -34), Vector2(3, -34), Vector2(0, -43),
			]), Color(0.92, 0.93, 0.95, 1.0))
		&"pikeman":
			# 剑：指向瞄准方向的长刃 + 护手
			draw_line(Vector2(0, 6), Vector2(0, -26), Color(0.88, 0.9, 0.93, 1.0), 3.0)
			draw_line(Vector2(-6, -22), Vector2(6, -22), Color(0.5, 0.38, 0.2, 1.0), 3.0)
			draw_line(Vector2(0, 6), Vector2(0, 11), Color(0.5, 0.38, 0.2, 1.0), 4.0)
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