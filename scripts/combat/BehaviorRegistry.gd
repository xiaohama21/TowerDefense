class_name BehaviorRegistry
extends RefCounted

## 最小行为注册表（GDD modules/BEHAVIORS.md）：战斗节点只按行为 ID 分发，
## 不在 Tower/Enemy 等脚本中硬编码职业/角色专属逻辑。
## 阶段 1 落地职业攻击行为（behavior_id）；大招/特性/敌人特殊行为随阶段 3 扩展。

const CAVALRY_TAG: StringName = &"cavalry"
## 枪兵职业克制：对带 cavalry 标签的敌人伤害 +15%（GDD 4.2）。
const PIKEMAN_COUNTER_ID: StringName = &"pikeman"
const PIKEMAN_COUNTER_MULTIPLIER: float = 1.15

## behavior_id -> 攻击执行器 Callable(tower: Tower, target: Enemy)
static var _attack_executors: Dictionary = {}


static func _ensure_registry() -> void:
	if not _attack_executors.is_empty():
		return
	# 弹道类：弓箭手/术士/舞娘（单体结算，职业范围/光环结算随阶段 3 拆分）。
	for behavior_id in [&"single_target_precision", &"area_spell", &"attack_speed_aura"]:
		_attack_executors[behavior_id] = _attack_single_target_bullet
	# 近战类：直伤 + 武器挥击表现（无弹道）。骑兵与剑客同属贴路近战职业。
	for behavior_id in [&"single_target_burst", &"melee_thrust"]:
		_attack_executors[behavior_id] = _attack_melee_swing


## 执行一次职业攻击行为。返回 false 表示该 ID 未注册。
static func execute_attack(behavior_id: StringName, tower, target) -> bool:
	_ensure_registry()
	var executor: Callable = _attack_executors.get(behavior_id, Callable())
	if not executor.is_valid():
		push_warning("未注册的攻击行为 ID：%s" % behavior_id)
		return false
	executor.call(tower, target)
	return true


## 职业克制倍率：按职业与目标标签查询，默认 1.0。
static func get_profession_counter(profession_id: StringName, enemy_tags: Array[StringName]) -> float:
	if profession_id == PIKEMAN_COUNTER_ID and enemy_tags.has(CAVALRY_TAG):
		return PIKEMAN_COUNTER_MULTIPLIER
	return 1.0


static func _attack_single_target_bullet(tower: Tower, target: Enemy) -> void:
	var bullet := tower.instantiate_bullet(target)
	if bullet != null:
		bullet.damage = int(round(tower.damage * get_profession_counter(tower.get_profession_id(), target.tags)))
	# 弹道类攻击表现：枪口闪光（近战类由各自执行器触发挥击表现）。
	tower.play_attack_flash()


static func _attack_melee_swing(tower: Tower, target: Enemy) -> void:
	## 近战直伤 + 武器挥击表现；伤害含职业克制（剑客对 cavalry 标签 +15%）。
	var damage := int(round(tower.damage * get_profession_counter(tower.get_profession_id(), target.tags)))
	target.take_damage(damage, tower.character_id)
	tower.play_melee_hit()
