extends Node2D

class_name Tower

const BULLET_SCENE: PackedScene = preload("res://scenes/Bullet.tscn")
const TOWER_GROUP: StringName = &"towers"
const RANGE_FILL_COLOR := Color(0.22, 0.76, 0.88, 0.13)
const RANGE_BORDER_COLOR := Color(0.68, 0.97, 1.0, 0.96)
## 选中环（v0.19.2）：金色光圈，选中塔明显可辨。
const SELECT_RING_COLOR := Color(1.0, 0.82, 0.3)
const RANGE_BORDER_WIDTH := 3.5
## 局内升级每级伤害增幅（GDD 5.4：伤害 +25%/级，与 10.5 大招倍率同源）。
## 局内升级伤害步进与大招步进（v0.18.0 起读 GameBalance 中心配置，默认与 .tres 一致）。
var _upgrade_damage_step: float = 0.25
var _ultimate_battle_step: float = 0.25
## 怒气上限（GDD 4.6）：满 100 自动释放大招。
## 怒气上限（CHARACTERS.md 4.6；v0.18.0 起读 GameBalance）。
var _max_rage: float = 100.0
# 近战挥击表现（GDD modules/BEHAVIORS.md B.3.1）：武器从一侧扫到另一侧，
# 并带一道渐隐斩击弧；表现由 melee_thrust 执行器经 play_melee_hit() 触发。
const MELEE_SWING_DURATION := 0.22
## 大招演出时长（v0.15.0）。
const ULT_VISUAL_DURATION := 0.55
const MELEE_SWING_FROM := -1.35
const MELEE_SWING_TO := 0.95
const MELEE_SLASH_RADIUS := 38.0
const PROFESSION_COLORS := {
	&"cavalry": Color(0.76, 0.24, 0.2, 1.0),
	&"pikeman": Color(0.3, 0.62, 0.45, 1.0),
	&"archer": Color(0.85, 0.55, 0.22, 1.0),
	&"strategist": Color(0.28, 0.5, 0.85, 1.0),
	&"dancer": Color(0.85, 0.42, 0.66, 1.0),
	&"catapult": Color(0.56, 0.51, 0.4, 1.0),
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

# 怒气（局内临时状态，GDD 4.6）：满 100 自动释放大招，不写存档。
var rage: float = 0.0
# 增益（舞娘光环/鼓舞）：攻速与伤害倍率，到期回落。
var attack_speed_buff: float = 1.0
var damage_buff: float = 1.0
var _buff_time_left: float = 0.0
# 龙魂击杀叠层（赵云特性）：击杀 +1 层攻速，目标丢失时清零。
var kill_stacks := 0

var _profession_id: StringName = StringName()
var _profession_name: String = ""
var _behavior_id: StringName = StringName()
var _base_damage: int = 40
var _min_range: float = 0.0
var _trait_id: StringName = StringName()
var _trait_params: Dictionary = {}
var _relic_damage_bonus: float = 0.0
## 科技树军事分支加成（GDD 10.7，v0.14.1）：全武将伤害 +%，经 finalize_damage 应用。
var _tech_damage_bonus: float = 0.0
## 编队羁绊同队攻击加成（GDD modules/CHARACTERS.md 4.8，v0.17.0）：finalize_damage 乘法区。
var _bond_damage_bonus: float = 0.0
## 局内遗物伤害加成（CHARACTERS.md 4.8，v0.19.0）：finalize_damage 乘法区。
var _battle_relic_damage_bonus: float = 0.0
var _rage_mode: StringName = &"hit+damage"
var _gain_per_hit: int = 4
var _gain_per_damage: float = 0.1
var _support_gain_per_tick: int = 2
var _ultimate_id: StringName = StringName()
var _ultimate_multiplier: float = 1.0
var _granted_skills: Array[StringName] = []
## 技能参数（v0.15.0，GDD BEHAVIORS.md B.3.5）：skill_id -> 数值字典，来自 PromotionData。
var _skill_params: Dictionary = {}
## 龙突（赵云）：击杀后下一次伤害加成，finalize_damage 一次性消耗。
var _next_attack_bonus: float = 0.0
## 手动大招（v0.15.0）：满怒待发状态与提示去抖。
var _ultimate_ready: bool = false
var _rage_ready_notified: bool = false
var _manual_ultimate_mode: bool = false
## 大招演出（v0.15.0）：专属视觉 ID 与计时。
var _ult_visual_id: StringName = StringName()
var _ult_visual_time: float = 0.0
## 浮字层（由 Main 注入；缺省回退到 current_scene 的 spawn_float_text_at）。
var _float_text_layer: Node = null
var _consecutive_hits: int = 0
var _last_attacked_target = null
var _aura_tick: float = 0.0
var _hero_color: Color = Color(0.45, 0.55, 0.65, 1.0)
var _aim_angle: float = -PI / 2.0
var _attack_flash: float = 0.0
var _melee_swing: float = 0.0
var _skill_flash: float = 0.0
var _skill_flash_color: Color = Color(1.0, 0.85, 0.4)

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
	GameManager.enemy_killed_by_character.connect(_on_enemy_killed)
	_rebuild_range_area()
	if not display_name.is_empty():
		name_label.text = display_name
	selection_area.input_event.connect(_on_selection_area_input_event)
	queue_redraw()


## Apply a CharacterData to this tower. Call after add_child() so all
## onready nodes are available. level/promotion 来自存档养成状态
## （GDD modules/CHARACTERS.md 4.4/4.5），属性经 compute_stats_at 统一计算。
func apply_character(character_data: CharacterData, loadout: Dictionary = {}) -> void:
	var level: int = int(loadout.get("level", 1))
	var promotion: PromotionData = loadout.get("promotion", null)
	var stars: int = int(loadout.get("stars", 0))
	var relic: RelicData = loadout.get("relic", null)
	character_id = character_data.character_id
	display_name = character_data.display_name
	var stats := character_data.compute_stats_at(level, promotion, stars, relic)
	damage = stats.damage
	_base_damage = damage
	range_radius = stats.range
	# 诸葛亮·观星：射程 +12%（特性静态加成）
	if _trait_id == &"trait_star_gazer":
		range_radius *= 1.0 + get_trait_param("range_bonus", 0.12)
	var relic_bonuses := GameFlow.get_battle_relic_bonuses()
	# 局内遗物射程加成（v0.19.0，与特性乘算）
	range_radius *= 1.0 + float(relic_bonuses.get("range_bonus_pct", 0)) / 100.0
	attack_cooldown = stats.attack_interval * float(relic_bonuses.get("attack_interval_factor", 1.0))
	_min_range = stats.min_range
	# 信物全伤害加成（finalize_damage 管线使用，v0.13）
	_relic_damage_bonus = relic.damage_bonus if relic != null else 0.0
	# 科技树军事分支（finalize_damage 管线使用，v0.14.1）
	_tech_damage_bonus = float(TechTree.get_tech_bonuses(ProfileStore.get_profile()).get("damage_pct", 0)) / 100.0
	_bond_damage_bonus = GameFlow.get_squad_bond_damage_bonus(GameFlow.squad_character_ids)
	# 局内遗物伤害加成（v0.19.0，与科技/信物/羁绊同区叠加）
	_battle_relic_damage_bonus = float(relic_bonuses.get("damage_bonus_pct", 0)) / 100.0
	var balance := GameBalance.get_balance()
	_upgrade_damage_step = balance.upgrade_damage_step
	_ultimate_battle_step = balance.ultimate_battle_step
	_max_rage = balance.max_rage
	bullet_speed = character_data.projectile_speed
	build_cost = character_data.build_cost

	_profession_id = character_data.profession.profession_id if character_data.profession != null else StringName()
	_profession_name = character_data.profession.display_name if character_data.profession != null else ""
	_behavior_id = character_data.profession.behavior_id if character_data.profession != null else StringName()
	if _behavior_id.is_empty():
		_behavior_id = &"single_target_burst"
	_trait_id = character_data.trait_id
	_trait_params = character_data.trait_params.duplicate(true)
	_granted_skills.assign(promotion.granted_skill_ids.duplicate()) if promotion != null else _granted_skills.clear()
	_skill_params = promotion.skill_params.duplicate(true) if promotion != null else {}
	_manual_ultimate_mode = GameFlow.is_gameplay_flag_enabled("manual_ultimate")
	_ultimate_multiplier = promotion.ultimate_multiplier if promotion != null else 1.0
	_ultimate_id = character_data.ultimate_override_id
	if _ultimate_id.is_empty() and character_data.profession != null:
		_ultimate_id = character_data.profession.ultimate_id
	_rage_mode = character_data.rage_gain_mode_override
	if _rage_mode.is_empty() and character_data.profession != null:
		_rage_mode = character_data.profession.rage_gain_mode
	if _rage_mode.is_empty() and character_data.profession != null:
		_rage_mode = &"support" if character_data.profession.combat_role == ProfessionData.CombatRole.SUPPORT else &"hit+damage"
	if character_data.profession != null:
		_gain_per_hit = character_data.profession.ultimate_gain_per_hit
		_gain_per_damage = character_data.profession.ultimate_gain_per_damage
		_support_gain_per_tick = character_data.profession.support_ultimate_gain_per_tick
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
	damage = int(round(_base_damage * (1.0 + _upgrade_damage_step * battle_level)))
	queue_redraw()


func record_build_investment(cost: int) -> void:
	build_cost = cost if cost > 0 else build_cost
	total_invested = cost


func play_attack_flash() -> void:
	## 弹道类攻击的枪口闪光，由弹道执行器触发。
	_attack_flash = 0.18
	SfxLibrary.play(&"attack", -16.0)
	queue_redraw()


func play_melee_hit() -> void:
	## 近战挥击，由近战执行器触发；不产生枪口闪光。
	_melee_swing = MELEE_SWING_DURATION
	SfxLibrary.play(&"attack", -14.0)
	queue_redraw()


	## 技能触发特效（v0.16.0）：扩散环随时间放大并淡出，由 SkillRegistry 触发点调用。
func play_skill_effect(color: Color = Color(1.0, 0.85, 0.4)) -> void:
	_skill_flash = 0.4
	_skill_flash_color = color
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
	var effective := attack_cooldown / (attack_speed_buff * (1.0 + 0.04 * kill_stacks))
	attack_timer.wait_time = maxf(effective, 0.05)


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
	var passive := BehaviorRegistry.is_passive_behavior(_behavior_id)
	if not passive and not _is_target_in_range(target):
		target = find_target()

	if _buff_time_left > 0.0:
		_buff_time_left = maxf(_buff_time_left - _delta, 0.0)
		if _buff_time_left <= 0.0:
			attack_speed_buff = 1.0
			damage_buff = 1.0
			_rebuild_attack_timer()
		queue_redraw()

	if target:
		_update_aim()

	# 大招释放（v0.15.0）：手动模式满怒待发，自动模式满怒即放。
	if rage >= _max_rage:
		if _manual_ultimate_mode:
			_ultimate_ready = true
			if not _rage_ready_notified:
				_rage_ready_notified = true
				spawn_float_text("大招就绪", Color(1.0, 0.85, 0.3), 16)
		else:
			_ultimate_ready = false
			_try_cast_ultimate()
	else:
		_ultimate_ready = false
		_rage_ready_notified = false

	if _ult_visual_time > 0.0:
		_ult_visual_time = maxf(_ult_visual_time - _delta, 0.0)
		queue_redraw()

	# 诸葛亮·观星：范围内敌人持续减速 8%（周期施加，取最强因子）
	_aura_tick = maxf(_aura_tick - _delta, 0.0)
	if _trait_id == &"trait_star_gazer" and _aura_tick <= 0.0:
		_aura_tick = 0.5
		for enemy in enemies_in_range():
			enemy.apply_slow(get_trait_param("aura_slow", 0.92), 0.6)

	if attack_timer.is_stopped() and (passive or target != null):
		attack()

	if _attack_flash > 0.0:
		_attack_flash = maxf(_attack_flash - _delta, 0.0)
		queue_redraw()
	if _melee_swing > 0.0:
		_melee_swing = maxf(_melee_swing - _delta, 0.0)
		queue_redraw()
	if _skill_flash > 0.0:
		_skill_flash = maxf(_skill_flash - _delta, 0.0)
		queue_redraw()


## 攻击时积怒（hit+damage 模式）：命中 +N，另按伤害折算（GDD 4.6/10.6）。
func gain_rage_for_attack(dealt: int) -> void:
	if _rage_mode != &"hit+damage":
		return
	gain_rage(float(_gain_per_hit) + float(dealt) * _gain_per_damage)


## 辅助脉冲积怒（support 模式）：触发增益 +N，每覆盖一名友方再 +N（10.6 粗化占位）。
func gain_support_pulse(allies_buffed: int) -> void:
	if _rage_mode != &"support" or allies_buffed <= 0:
		return
	gain_rage(float(_gain_per_hit) + float(_support_gain_per_tick) * allies_buffed)
	GameManager.add_support_contribution(character_id, allies_buffed)


func gain_rage(amount: float) -> void:
	if amount <= 0.0:
		return
	rage = minf(rage + amount * BehaviorRegistry.moon_veil_rage_multiplier(self), _max_rage)
	queue_redraw()


## 怒气满自动释放（GDD 4.6）；执行器返回 false（如射程内无目标）时保留怒气待发。
func _try_cast_ultimate() -> bool:
	if _ultimate_id.is_empty():
		return false
	# 先清怒再执行：大招击杀返怒（charge/职业基础 50%）在清零基础上叠加，
	# 避免返怒被调用方随后清怒覆盖（v0.15.0 修正 v0.11.2 遗留时序缺陷）。
	var spent := rage
	rage = 0.0
	if not BehaviorRegistry.execute_ultimate(_ultimate_id, self):
		rage = spent
		return false
	# 大招演出（v0.15.0）：专属视觉 + 大招名飘字 + 技能钩子。
	play_ultimate_visual(_ultimate_id)
	spawn_float_text(BehaviorRegistry.ultimate_display_name(_ultimate_id), Color(1.0, 0.85, 0.3), 20)
	SkillRegistry.on_ultimate_cast(self)
	return true


## 大招强度（10.5）：×(1 + 0.25 × 局内等级) × 转职 ultimate_multiplier。
func ultimate_power() -> float:
	return (1.0 + _ultimate_battle_step * battle_level) * _ultimate_multiplier


## charge 技能（突击骑）：大招击杀返怒 50% × 档位系数（每 5 级 +10%）。
func kill_rage_refund() -> float:
	return SkillRegistry.kill_rage_refund(self)


func has_skill(skill_id: StringName) -> bool:
	return _granted_skills.has(skill_id)


func get_skill_param(skill_id: StringName, key: String, default: float) -> float:
	var params: Dictionary = _skill_params.get(skill_id, {})
	return float(params.get(key, default))


func set_next_attack_bonus(bonus: float) -> void:
	_next_attack_bonus = maxf(bonus, 0.0)


## 大招范围（v0.15.0）：诸葛亮·奇谋按档位放大爆炸半径。
func ultimate_aoe_radius(base_radius: float) -> float:
	return base_radius * SkillRegistry.ultimate_aoe_radius_multiplier(self)


## 手动大招（GDD 10.5，v0.15.0）：满怒且射程内有目标时释放，成功清空怒气。
func cast_ultimate_manual() -> bool:
	if not _manual_ultimate_mode or rage < _max_rage:
		return false
	if _try_cast_ultimate():
		_ultimate_ready = false
		_rage_ready_notified = false
		queue_redraw()
		return true
	return false


## 手动模式下大招是否就绪（供属性面板按钮/提示使用）。
func is_ultimate_ready() -> bool:
	return _manual_ultimate_mode and _ultimate_ready and rage >= _max_rage


func set_float_text_layer(layer: Node) -> void:
	_float_text_layer = layer


## 战斗浮字（v0.15.0）：技能/大招/特性反馈飘字，挂到当前场景的浮字层。
func spawn_float_text(text: String, color: Color = Color.WHITE, size: int = 14) -> void:
	var layer := _float_text_layer
	if layer == null or not is_instance_valid(layer):
		layer = get_tree().current_scene
	if layer != null and layer.has_method("spawn_float_text_at"):
		layer.spawn_float_text_at(global_position + Vector2(0, -36), text, color, size)


## 大招专属视觉（v0.15.0）：执行器成功后由 _try_cast_ultimate 触发。
func play_ultimate_visual(ultimate_id: StringName) -> void:
	_ult_visual_id = ultimate_id
	_ult_visual_time = ULT_VISUAL_DURATION
	queue_redraw()


func is_target_valid(candidate) -> bool:
	return _is_target_in_range(candidate)


func get_trait_id() -> StringName:
	return _trait_id


func get_trait_param(key: String, default: float) -> float:
	return float(_trait_params.get(key, default))


func get_behavior_id() -> StringName:
	return _behavior_id


func get_consecutive_hits() -> int:
	return _consecutive_hits


## 伤害结算管线：基础值 × 增益 × 职业克制 × 特性（含刘备光环）。
func finalize_damage(base: int, target: Enemy) -> int:
	var value := float(base) * damage_buff * (1.0 + _relic_damage_bonus) * (1.0 + _tech_damage_bonus) * (1.0 + _bond_damage_bonus) * (1.0 + _battle_relic_damage_bonus)
	value *= BehaviorRegistry.get_profession_counter(_profession_id, target.tags)
	if BehaviorRegistry.has_benevolence_aura(self):
		value *= BehaviorRegistry.benevolence_bonus(self)
	value *= BehaviorRegistry.get_trait_damage_multiplier(self, target)
	value *= SkillRegistry.passive_damage_multiplier(self, target)
	if _next_attack_bonus > 0.0:
		value *= 1.0 + _next_attack_bonus
		_next_attack_bonus = 0.0
		spawn_float_text(SkillRegistry.get_skill_name(&"dragon_rush"), Color(0.6, 0.9, 1.0))
	return int(round(value))


func enemies_in_range() -> Array[Enemy]:
	var result: Array[Enemy] = []
	var min_range_squared := _min_range * _min_range
	for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		var distance_squared := global_position.distance_squared_to(enemy.global_position)
		if distance_squared <= range_radius * range_radius and distance_squared >= min_range_squared:
			result.append(enemy)
	return result


func allies_in_range() -> Array[Tower]:
	var result: Array[Tower] = []
	for node in get_tree().get_nodes_in_group(TOWER_GROUP):
		var other := node as Tower
		if other == null or other == self or not is_instance_valid(other):
			continue
		if global_position.distance_to(other.global_position) <= range_radius:
			result.append(other)
	return result


func lowest_hp_targets_in_range(count: int) -> Array[Enemy]:
	var enemies := enemies_in_range()
	enemies.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.current_hp < b.current_hp)
	return enemies.slice(0, mini(count, enemies.size()))


func apply_attack_speed_buff(multiplier: float, duration: float) -> void:
	attack_speed_buff = maxf(attack_speed_buff, multiplier)
	_buff_time_left = maxf(_buff_time_left, duration)
	_rebuild_attack_timer()
	queue_redraw()


func apply_team_buff(speed_multiplier: float, damage_multiplier: float, duration: float) -> void:
	attack_speed_buff = maxf(attack_speed_buff, speed_multiplier)
	damage_buff = maxf(damage_buff, damage_multiplier)
	_buff_time_left = maxf(_buff_time_left, duration)
	_rebuild_attack_timer()
	queue_redraw()


func _on_enemy_killed(character_id: String) -> void:
	if character_id != self.character_id:
		return
	# 赵云·龙魂：击杀叠攻速（可叠加；目标丢失时重置）
	if _trait_id == &"trait_dragon_spirit":
		kill_stacks = mini(kill_stacks + 1, 10)
		_rebuild_attack_timer()
		spawn_float_text("龙魂 ×%d" % kill_stacks, Color(0.75, 0.9, 1.0))
	SkillRegistry.on_kill(self, null)


func find_target() -> Enemy:
	var best_target: Enemy = null
	var best_progress := -1.0
	var range_squared := range_radius * range_radius
	var min_range_squared := _min_range * _min_range

	for node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		var distance_squared := global_position.distance_squared_to(enemy.global_position)
		if distance_squared > range_squared:
			continue
		# 最小射程（投石车等）：目标过近时忽略，交由其他单位处理。
		if distance_squared < min_range_squared:
			continue
		if enemy.progress_ratio > best_progress:
			best_progress = enemy.progress_ratio
			best_target = enemy

	return best_target


func attack() -> void:
	var passive := BehaviorRegistry.is_passive_behavior(_behavior_id)
	if not passive:
		if not _is_target_in_range(target):
			target = null
			return
		# 百步穿杨：连续攻击同一目标时伤害递增，换目标重置
		if target == _last_attacked_target:
			_consecutive_hits += 1
		else:
			_consecutive_hits = 1
			_last_attacked_target = target

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
	var distance_squared := global_position.distance_squared_to(enemy.global_position)
	if distance_squared > range_radius * range_radius:
		return false
	# 最小射程：目标进入近距离后无法继续攻击（投石车弱点）。
	if distance_squared < _min_range * _min_range:
		return false
	return true


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
	if _skill_flash > 0.0:
		_draw_skill_flash()
	_draw_rage_bar()
	if _ult_visual_time > 0.0:
		_draw_ultimate_visual()
	if is_selected:
		_draw_range()
		# 选中环（v0.19.2）：塔身外金色光圈，强化选中反馈。
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, SELECT_RING_COLOR, 3.0, true)


## 技能扩散环（v0.16.0）：半径随进度放大、颜色淡出。
func _draw_skill_flash() -> void:
	var t := 1.0 - _skill_flash / 0.4
	var radius := lerpf(10.0, 40.0, t)
	var alpha := clampf(1.0 - t, 0.0, 1.0)
	var color := Color(_skill_flash_color.r, _skill_flash_color.g, _skill_flash_color.b, alpha)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, color, 3.0)
	draw_circle(Vector2.ZERO, radius * 0.35, Color(color.r, color.g, color.b, alpha * 0.25))


func _draw_rage_bar() -> void:
	# 怒气条（v0.15.0 美化）：分段槽 + 边框；满怒金色脉动（手动模式提示）。
	if rage <= 0.0:
		return
	var ratio := clampf(rage / _max_rage, 0.0, 1.0)
	var full := ratio >= 1.0
	var pulse := 1.0 + (0.08 * sin(Time.get_ticks_msec() * 0.006) if full else 0.0)
	var width := 34.0 * pulse
	var height := 6.0
	var origin := Vector2(-width / 2.0, 28)
	draw_rect(Rect2(origin, Vector2(width, height)), Color(0.0, 0.0, 0.0, 0.6))
	var fill_color := Color(1.0, 0.82, 0.3, 1.0) if full else Color(0.3, 0.62, 0.95, 0.95)
	draw_rect(Rect2(origin + Vector2(1, 1), Vector2((width - 2.0) * ratio, height - 2.0)), fill_color)
	if full:
		draw_rect(Rect2(origin, Vector2(width, height)), Color(1.0, 0.9, 0.5, 0.9), false, 1.0)
	for i in range(1, 4):
		var x := origin.x + width * i / 4.0
		draw_line(Vector2(x, origin.y), Vector2(x, origin.y + height), Color(0.0, 0.0, 0.0, 0.35), 1.0)


## 大招专属视觉（v0.15.0，GDD 阶段 5 提交 1）：按 ultimate_id 绘制差异化演出，
## 由 _try_cast_ultimate 成功后触发，持续 ULT_VISUAL_DURATION。
func _draw_ultimate_visual() -> void:
	var t := 1.0 - _ult_visual_time / ULT_VISUAL_DURATION
	var alpha := clampf(1.0 - t * 0.7, 0.1, 1.0)
	var gold := Color(1.0, 0.85, 0.35, alpha)
	match _ult_visual_id:
		&"ultimate_cavalry_breaker":
			# 突击斩杀：大斩弧沿瞄准方向横扫 + 刀光
			var start := _aim_angle - 1.2
			var sweep := lerpf(0.0, 2.4, t)
			draw_arc(Vector2.ZERO, 52.0, start, start + sweep, 18, gold, 6.0)
			draw_line(Vector2.ZERO, Vector2.from_angle(_aim_angle) * 62.0, Color(1.0, 0.95, 0.7, alpha * 0.9), 3.0)
		&"ultimate_pikeman_sweep":
			# 横扫千军：扩散圆环 + 六向震地线
			draw_arc(Vector2.ZERO, 30.0 + 46.0 * t, 0.0, TAU, 28, Color(0.6, 1.0, 0.7, alpha), 5.0)
			for i in range(6):
				var ang := _aim_angle + TAU * i / 6.0
				draw_line(Vector2.from_angle(ang) * 34.0, Vector2.from_angle(ang) * (34.0 + 26.0 * t), Color(0.7, 1.0, 0.8, alpha), 2.5)
		&"ultimate_archer_volley":
			# 连珠齐射：枪口连闪三点
			for i in range(3):
				var dir := Vector2.from_angle(_aim_angle + (i - 1) * 0.22)
				draw_circle(dir * 30.0, maxf(2.0, 5.0 - i * 1.4), gold)
		&"ultimate_strategist_blaze":
			# 火烧连营：旋转法阵 + 扩散火环
			var spin := t * TAU
			draw_arc(Vector2.ZERO, 34.0, spin, spin + 4.6, 20, Color(1.0, 0.6, 0.3, alpha), 4.0)
			draw_arc(Vector2.ZERO, 46.0, -spin, -spin + 4.6, 20, Color(1.0, 0.75, 0.4, alpha * 0.8), 3.0)
			draw_arc(Vector2.ZERO, 20.0 + 30.0 * t, 0.0, TAU, 24, Color(1.0, 0.5, 0.25, alpha * 0.7), 3.0)
		&"ultimate_dancer_encourage":
			# 倾城鼓舞：双粉环扩散
			draw_arc(Vector2.ZERO, 24.0 + 40.0 * t, 0.0, TAU, 26, Color(1.0, 0.65, 0.85, alpha), 4.0)
			draw_arc(Vector2.ZERO, 34.0 + 40.0 * t, 0.0, TAU, 26, Color(1.0, 0.8, 0.9, alpha * 0.7), 2.5)
		&"ultimate_catapult_barrage":
			# 石破天惊：抛射弧线示意
			var p0 := Vector2.ZERO
			var p1 := Vector2.from_angle(_aim_angle) * 70.0
			var mid := p0.lerp(p1, 0.5) + Vector2.UP * 46.0
			var prev := p0
			for i in range(8):
				var tt := float(i) / 7.0
				var point := p0.lerp(mid, tt).lerp(mid.lerp(p1, tt), tt)
				draw_line(prev, point, gold, 3.0)
				prev = point
		_:
			draw_arc(Vector2.ZERO, 20.0 + 40.0 * t, 0.0, TAU, 24, gold, 4.0)


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
		&"catapult":
			# 投石车：车架 + 双轮 + 配重
			draw_rect(Rect2(-14, -2, 28, 10), _hero_color.darkened(0.2))
			draw_circle(Vector2(-9, 10), 5.0, _hero_color.darkened(0.4))
			draw_circle(Vector2(9, 10), 5.0, _hero_color.darkened(0.4))
			draw_circle(Vector2(6, -6), 5.0, Color(0.35, 0.33, 0.3, 1.0))
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
		&"catapult":
			# 抛臂：长杆 + 末端勺兜
			draw_line(Vector2(-4, 10), Vector2(0, -30), Color(0.45, 0.36, 0.24, 1.0), 3.5)
			draw_arc(Vector2(0, -30), 5.0, 0.0, TAU, 10, Color(0.35, 0.33, 0.3, 1.0), 3.0, true)
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
