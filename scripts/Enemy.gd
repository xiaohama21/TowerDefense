extends PathFollow2D

class_name Enemy

const ENEMY_GROUP: StringName = &"enemies"

@export var speed: float = 100.0
@export var max_hp: int = 100
@export var armor: int = 0
@export var reward: int = 10
@export var kill_xp: int = 0
@export var damage_to_base: int = 1
@export var enemy_id: StringName = &""
# 兵种/阵营标签（GDD 5.5），职业克制与掉落倾向按标签查询。
var tags: Array[StringName] = []

var current_hp: int = 0
var is_dead: bool = false
var last_damage_source_character_id: String = ""
# character_id -> 累计有效伤害，供击杀经验归属规则（GDD 4.4）分摊使用。
var damage_contributors: Dictionary = {}
# 当前移动方向（抛射预判落点用）；初始朝右，随实际位移刷新。
var velocity_dir: Vector2 = Vector2.RIGHT
# 减速 debuff（术士大招/张飞咆哮/诸葛亮光环等）：取最强因子，倒计时归零解除。
var slow_factor: float = 1.0
var _slow_time_left: float = 0.0

@onready var hp_bar: ProgressBar = $HpBar
@onready var body: ColorRect = $Body

func _enter_tree() -> void:
	add_to_group(ENEMY_GROUP)


func _ready() -> void:
	# PathFollow2D defaults to looping. Enemies must stop at the base instead.
	loop = false
	rotates = false
	max_hp = maxi(max_hp, 1)
	current_hp = max_hp
	progress = 0
	update_hp_bar()
	queue_redraw()


func _process(delta: float) -> void:
	if is_dead:
		return

	if _slow_time_left > 0.0:
		_slow_time_left = maxf(_slow_time_left - delta, 0.0)
		if _slow_time_left <= 0.0:
			slow_factor = 1.0

	var before := global_position
	progress += speed * slow_factor * delta
	var delta_pos := global_position - before
	if delta_pos.length_squared() > 0.01:
		velocity_dir = delta_pos.normalized()

	if progress_ratio >= 1.0 - 0.0001:
		GameManager.enemy_reached_base(damage_to_base)
		die(false)


## 施加减速：多来源叠加时取最强因子（最小值），时长刷新。
func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, clampf(factor, 0.05, 1.0))
	_slow_time_left = maxf(_slow_time_left, duration)


func take_damage(amount: int, source_character_id: String = "") -> void:
	if is_dead or amount <= 0:
		return
	var source_id := source_character_id.strip_edges()
	if not source_id.is_empty():
		last_damage_source_character_id = source_id

	# 护甲减算保留 10% 伤害下限，高护甲也不完全免伤（GDD 5.5）。
	var effective := maxi(amount - armor, ceili(amount * 0.1))
	current_hp = maxi(current_hp - effective, 0)
	if not source_id.is_empty():
		damage_contributors[source_id] = int(damage_contributors.get(source_id, 0)) + effective
	update_hp_bar()

	if current_hp <= 0:
		die(true)


func die(give_reward: bool) -> void:
	if is_dead:
		return
	is_dead = true

	if give_reward:
		GameManager.enemy_died(reward, kill_xp, last_damage_source_character_id, damage_contributors)

	queue_free()


func update_hp_bar() -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp


func set_color(color: Color) -> void:
	var body := get_node_or_null("Body") as ColorRect
	if body:
		body.color = color
	queue_redraw()


func set_body_size(body_size: Vector2) -> void:
	var body := get_node_or_null("Body") as ColorRect
	if body:
		body.size = body_size
		body.position = -body_size * 0.5
	queue_redraw()


func _draw() -> void:
	if body == null:
		return
	var half := body.size * 0.5
	# 黄巾头带：横跨头顶的黄色布条
	var band_rect := Rect2(
		Vector2(-half.x * 0.72, -half.y - 7.0),
		Vector2(half.x * 1.44, 5.0)
	)
	draw_rect(band_rect, Color(0.85, 0.68, 0.2, 1.0))
	draw_rect(band_rect, Color(0.6, 0.45, 0.12, 1.0), false, 1.0)
	# 头带结
	draw_circle(Vector2(half.x * 0.55, -half.y - 4.0), 2.5, Color(0.85, 0.68, 0.2, 1.0))
	# 眼睛
	draw_circle(Vector2(half.x * 0.35, -half.y * 0.3), 2.0, Color(0.95, 0.96, 0.97, 1.0))
	draw_circle(Vector2(half.x * 0.35, -half.y * 0.3), 1.0, Color(0.1, 0.1, 0.12, 1.0))
