extends RefCounted

class_name SkillRegistry

## 转职技能注册表（GDD modules/BEHAVIORS.md B.3.5，v0.15.0）：
## 技能 = 转职授予的被动/条件触发能力；战斗脚本只调用钩子，不在
## Tower/Enemy 等脚本中写死技能逻辑。数值经 PromotionData.skill_params 读取。
## v0.28.0（阶段 8·提交 6）：
## ①职业技能收敛——每职业 1 技能（6 技能），移除龙突/凶威/斩获；稳射改保底触发；
## ②档位口径（v0.27.4 拍板）：档位系数 s = 1 + 0.1 × min(battle_rank/5, 4)，
##   仅职业技能适用、以局内升阶 battle_rank 为准；角色技能不参与 s；
## ③角色技能（武将专属差异化，CHARACTER_SKILLS.md v0.1）：A 主动冷却制 /
##   B 条件触发被动，与职业层解耦。
## v0.32.0（阶段 8·提交 7，职业技能双轨）：
## ①二转新技能线接入 6 个新技能（assault/guard/chain_arrow/mystic_gate/echo/tremor），
##   新技能线节点显式配置「核心技能 + 新技能」两 id，无代码级父节点继承；
## ②军旗光环移出本表乘区（收敛进 Tower 常驻光环伤害桶，STATS_PIPELINE 增益档次 1）；
## ③新增敌人减益：易伤（奇门）、眩晕（震地）。

const MAX_TIERS := 4
const TIER_STEP := 0.1

const SKILL_NAMES := {
	&"charge": "蓄力",
	&"command": "军旗",
	&"steady": "稳射",
	&"inspire": "鼓舞",
	&"siege": "破城",
	&"wisdom": "奇谋",
	# 二转新技能线（提交 7）
	&"assault": "突袭",
	&"guard": "护卫",
	&"chain_arrow": "连矢",
	&"mystic_gate": "奇门",
	&"echo": "余音",
	&"tremor": "震地",
}

const KNOWN_SKILLS: Array[StringName] = [
	&"charge", &"command", &"steady", &"inspire", &"siege", &"wisdom",
	&"assault", &"guard", &"chain_arrow", &"mystic_gate", &"echo", &"tremor",
]

## 角色技能显示名（武将专属差异化，CHARACTER_SKILLS.md v0.1）。
const CHARACTER_SKILL_NAMES := {
	&"char_green_dragon": "青龙偃月",
	&"char_dangyang_roar": "当阳桥",
	&"char_carry_people": "携民渡江",
	&"char_dingjun": "定军山",
	&"char_moon_dance": "月下舞",
	&"char_burn_camp": "焚营",
	&"char_seven_charges": "七进七出",
	&"char_death_fight": "死战",
	&"char_borrow_wind": "借东风",
}

## B 型条件触发被动（无冷却、不自动释放）：每波首次漏怪 / 基地低血。
const CHARACTER_SKILL_B_TYPE: Array[StringName] = [
	&"char_carry_people", &"char_seven_charges", &"char_death_fight",
]


## 档位系数：s = 1 + 0.1 × min(battle_rank/5, 4)（每 5 阶一档，上限 +40%）。
## 仅职业技能适用；角色技能与档位无关（v0.27.4 拍板）。
static func tier_multiplier(tower: Tower) -> float:
	var tiers := mini(int(tower.battle_rank / 5), MAX_TIERS)
	return 1.0 + TIER_STEP * tiers


static func get_skill_name(skill_id: StringName) -> String:
	return str(SKILL_NAMES.get(skill_id, str(skill_id)))


static func get_character_skill_name(skill_id: StringName) -> String:
	return str(CHARACTER_SKILL_NAMES.get(skill_id, str(skill_id)))


static func has_skill(tower: Tower, skill_id: StringName) -> bool:
	return tower != null and is_instance_valid(tower) and tower.has_skill(skill_id)


## 技能参数（基准值 × 档位系数由各触发点自行乘）。未持有技能时返回默认值。
static func param(tower: Tower, skill_id: StringName, key: String, default: float) -> float:
	if not has_skill(tower, skill_id):
		return default
	return float(tower.get_skill_param(skill_id, key, default))


## ============ 角色技能（武将专属差异化） ============

static func get_character_skill_id(tower: Tower) -> StringName:
	if tower == null or not is_instance_valid(tower):
		return StringName()
	return tower.get_character_skill_id()


static func has_character_skill(tower: Tower, skill_id: StringName = StringName()) -> bool:
	if tower == null or not is_instance_valid(tower):
		return false
	var actual := tower.get_character_skill_id()
	if actual.is_empty():
		return false
	if not skill_id.is_empty():
		return actual == skill_id
	return true


static func is_character_skill_b_type(tower: Tower) -> bool:
	return CHARACTER_SKILL_B_TYPE.has(get_character_skill_id(tower))


## 角色技能冷却（A 主动）：参数可覆盖默认值；B 被动返回 0。
static func character_skill_cooldown(tower: Tower) -> float:
	if not has_character_skill(tower) or is_character_skill_b_type(tower):
		return 0.0
	return float(tower.get_character_skill_param("cooldown", 0.0))


static func character_param(tower: Tower, skill_id: StringName, key: String, default: float) -> float:
	if not has_character_skill(tower, skill_id):
		return default
	return float(tower.get_character_skill_param(key, default))


## 角色技能释放（A 由冷却就绪/手动按钮触发；B 由漏怪/基地低血钩子触发）。
## 返回 false 表示前置条件不满足（如 A 主动射程内无目标），调用方不进入冷却。
static func cast_character_skill(tower: Tower) -> bool:
	if tower == null or not is_instance_valid(tower) or not has_character_skill(tower):
		return false
	match get_character_skill_id(tower):
		&"char_green_dragon":
			return _cast_green_dragon(tower)
		&"char_dangyang_roar":
			return _cast_dangyang_roar(tower)
		&"char_carry_people":
			return _cast_carry_people(tower)
		&"char_dingjun":
			return _cast_dingjun(tower)
		&"char_moon_dance":
			return _cast_moon_dance(tower)
		&"char_burn_camp":
			return _cast_burn_camp(tower)
		&"char_seven_charges":
			return _cast_seven_charges(tower)
		&"char_death_fight":
			return _cast_death_fight(tower)
		&"char_borrow_wind":
			return _cast_borrow_wind(tower)
	return false


## 漏怪钩子（B 被动·每波首次漏怪）：GameManager 每波仅分发一次；
## 死战（基地低血）不走漏怪钩子，由 check_base_low 轮询触发。
static func on_wave_first_leak(tower: Tower) -> void:
	var skill_id := get_character_skill_id(tower)
	if skill_id == &"char_carry_people" or skill_id == &"char_seven_charges":
		cast_character_skill(tower)


## 基地低血钩子（B 被动·周仓死战）：Tower._process 轮询调用，首次触发后常驻。
static func check_base_low(tower: Tower) -> void:
	if tower == null or not is_instance_valid(tower) or tower.is_character_skill_activated():
		return
	if not has_character_skill(tower, &"char_death_fight"):
		return
	if GameManager.lives <= GameManager.starting_lives * character_param(tower, &"char_death_fight", "hp_threshold", 0.5):
		tower.set_character_skill_activated(true)
		cast_character_skill(tower)


## 冷却就绪钩子（A 主动）：自动模式立即释放；手动模式由面板按钮触发。
static func on_character_skill_ready(tower: Tower) -> void:
	if not has_character_skill(tower) or is_character_skill_b_type(tower):
		return
	if not GameFlow.is_gameplay_flag_enabled("manual_ultimate"):
		tower.cast_character_skill()


## ============ 职业技能钩子（每职业 1 个，效果 × 档位系数 s） ============

## 攻击命中钩子（普攻实际命中造成伤害后由 Tower.notify_attack_damage_dealt 调用）：
## v0.31.4/0.8.6.2 命中口径——实际命中即计数（击杀那发计入）；追加顺延至目标存活的下一次命中。
## 提交 7 扩展：稳射（保底追加）/ 连矢（概率追加）/ 突袭（精英命中叠层）/ 护卫（近战概率拖回）。
static func on_attack_hit(tower: Tower, target: Enemy, _dealt: int) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	_steady_proc(tower, target)
	_chain_arrow_proc(tower, target)
	_assault_gain_on_hit(tower, target)
	_guard_proc(tower, target)


## 稳射（保底追加）：每 every 次命中必触发一次 mult×s 追加伤害。
static func _steady_proc(tower: Tower, target: Enemy) -> void:
	if not has_skill(tower, &"steady"):
		return
	tower.steady_attack_counter += 1
	if target == null or target.is_dead:
		return
	var s := tier_multiplier(tower)
	var every := maxi(int(param(tower, &"steady", "every", 5.0)), 1)
	if tower.steady_attack_counter < every:
		return
	tower.steady_attack_counter = 0
	var extra := int(round(tower.damage * param(tower, &"steady", "mult", 0.6) * s))
	if extra > 0:
		_deliver_extra_damage(tower, target, extra, get_skill_name(&"steady"), Color(1.0, 0.9, 0.4))


## 连矢（概率追加）：命中 chance×s 概率触发 mult×s 追加箭矢；roll 中但目标已死
## （击杀那发）顺延至下一次存活命中，不吞触发。
static func _chain_arrow_proc(tower: Tower, target: Enemy) -> void:
	if not has_skill(tower, &"chain_arrow"):
		return
	var s := tier_multiplier(tower)
	var chance := param(tower, &"chain_arrow", "chance", 0.2)
	var trigger := tower.chain_arrow_pending
	if not trigger and randf() < chance:
		trigger = true
	if not trigger:
		return
	if target == null or target.is_dead:
		tower.chain_arrow_pending = true
		return
	tower.chain_arrow_pending = false
	var extra := int(round(tower.damage * param(tower, &"chain_arrow", "mult", 0.5) * s))
	_deliver_extra_damage(tower, target, extra, get_skill_name(&"chain_arrow"), Color(0.75, 0.95, 0.6))


## 突袭（精英/Boss 命中叠层来源 2）：对精英/Boss 每 hit_every 次自身命中 +1 层。
static func _assault_gain_on_hit(tower: Tower, target: Enemy) -> void:
	if not has_skill(tower, &"assault"):
		return
	if target == null:
		return
	if not (target.tags.has(&"elite") or target.tags.has(&"boss")):
		return
	tower.assault_hit_counter += 1
	var every := maxi(int(param(tower, &"assault", "hit_every", 4.0)), 1)
	if tower.assault_hit_counter < every:
		return
	tower.assault_hit_counter = 0
	_add_assault_stack(tower)


## 护卫（近战命中概率拖回拦截）：命中 chance×s 概率将目标沿路径拖回 pull px；
## 内置冷却 cooldown s 防「钉死」（复用破阵 enemy.progress 位移）。
static func _guard_proc(tower: Tower, target: Enemy) -> void:
	if not has_skill(tower, &"guard"):
		return
	if tower.guard_cooldown_left > 0.0 or target == null or target.is_dead:
		return
	var s := tier_multiplier(tower)
	if randf() >= param(tower, &"guard", "chance", 0.25) * s:
		return
	tower.guard_cooldown_left = param(tower, &"guard", "cooldown", 2.5)
	target.progress = maxf(target.progress - param(tower, &"guard", "pull", 20.0), 0.0)
	tower.spawn_float_text(get_skill_name(&"guard"), Color(0.6, 0.9, 1.0))
	tower.play_skill_effect(Color(0.6, 0.9, 1.0))
	SfxLibrary.play(&"skill", -8.0)


## 追加伤害统一交付：走 finalize_damage 管线 + 飘字/扩散环/音效。
static func _deliver_extra_damage(tower: Tower, target: Enemy, amount: int, label: String, color: Color) -> void:
	if amount <= 0 or tower == null or not is_instance_valid(tower) or target == null or target.is_dead:
		return
	target.take_damage(tower.finalize_damage(amount, target), tower.character_id)
	tower.spawn_float_text(label, color)
	tower.play_skill_effect(color)
	SfxLibrary.play(&"skill", -8.0)


## 突袭叠层叠加：击杀（on_kill）与精英/Boss 命中来源共用；满层不叠加。
static func _add_assault_stack(tower: Tower) -> void:
	if tower == null or not is_instance_valid(tower) or not has_skill(tower, &"assault"):
		return
	var max_stacks := maxi(int(param(tower, &"assault", "max_stacks", 3.0)), 1)
	if tower.assault_stacks >= max_stacks:
		return
	tower.assault_stacks = mini(tower.assault_stacks + 1, max_stacks)
	tower.spawn_float_text("%s %d/%d" % [get_skill_name(&"assault"), tower.assault_stacks, max_stacks], Color(0.6, 0.9, 1.0))


## 突袭层消耗（Tower.attack 普攻前调用）：有层则消耗 1 层，挂载该次普攻 +bonus×s。
static func try_consume_assault(tower: Tower) -> void:
	if tower == null or not is_instance_valid(tower) or not has_skill(tower, &"assault"):
		return
	if tower.assault_stacks <= 0:
		return
	tower.assault_stacks -= 1
	tower.set_next_attack_bonus(&"assault", param(tower, &"assault", "bonus", 0.25) * tier_multiplier(tower))


## 击杀钩子（Enemy 死亡结算后由 Tower 订阅调用）：
## charge（蓄力强化线）= 击杀后下一次攻击加成（next_hit_bonus 配置）；
## assault（骁骑）= 击杀任意敌人 +1 层。
static func on_kill(tower: Tower, _enemy: Enemy) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	if has_skill(tower, &"charge"):
		var next_hit_bonus := param(tower, &"charge", "next_hit_bonus", 0.0)
		if next_hit_bonus > 0.0:
			tower.set_next_attack_bonus(&"charge", next_hit_bonus * tier_multiplier(tower))
			tower.spawn_float_text(get_skill_name(&"charge") + "+", Color(0.6, 0.9, 1.0))
			tower.play_skill_effect(Color(0.6, 0.9, 1.0))
			SfxLibrary.play(&"skill", -8.0)
	_add_assault_stack(tower)


## 大招释放钩子（大招执行器成功后调用）：鼓舞 / 余音 / 奇谋飘字。
static func on_ultimate_cast(tower: Tower) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	var s := tier_multiplier(tower)
	SfxLibrary.play(&"ultimate", -6.0)
	tower.play_skill_effect(Color(1.0, 0.8, 0.95))
	if has_skill(tower, &"inspire"):
		var speed_bonus := param(tower, &"inspire", "team_speed_bonus", 0.06) * s
		var duration := param(tower, &"inspire", "duration", 8.0) * tower.get_battle_rank_buff_duration_multiplier()
		speed_bonus *= tower.get_battle_rank_buff_power_multiplier()
		for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
			var ally := node as Tower
			if ally != null and is_instance_valid(ally):
				ally.apply_attack_speed_buff("skill_inspire", 1.0 + speed_bonus, duration)
		tower.spawn_float_text(get_skill_name(&"inspire"), Color(1.0, 0.75, 0.9))
	if has_skill(tower, &"echo"):
		var damage_bonus := param(tower, &"echo", "team_damage_bonus", 0.08) * s
		var echo_duration := param(tower, &"echo", "duration", 5.0) * tower.get_battle_rank_buff_duration_multiplier()
		damage_bonus *= tower.get_battle_rank_buff_power_multiplier()
		for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
			var ally := node as Tower
			if ally != null and is_instance_valid(ally):
				ally.apply_team_buff("skill_echo", 1.0, 1.0 + damage_bonus, echo_duration)
		tower.spawn_float_text(get_skill_name(&"echo"), Color(0.85, 0.9, 0.55))
	if has_skill(tower, &"wisdom"):
		tower.spawn_float_text(get_skill_name(&"wisdom"), Color(0.7, 0.85, 1.0))


## 奇门（天师）：大招落点命中敌人施加易伤（同类不叠加、时长刷新，NUMBERS 10.10）。
## 由术士大招执行器（_ult_strategist_blaze）对范围内敌人调用。
static func apply_mystic_gate(tower: Tower, enemy: Enemy) -> void:
	if tower == null or not is_instance_valid(tower) or enemy == null or enemy.is_dead:
		return
	if not has_skill(tower, &"mystic_gate"):
		return
	var s := tier_multiplier(tower)
	var bonus := param(tower, &"mystic_gate", "vulnerability", 0.1) * s
	var duration := param(tower, &"mystic_gate", "duration", 4.0)
	enemy.apply_vulnerability(bonus, duration)


## 震地（震山）：大招每发落点命中敌人眩晕 duration×s；同一敌人内置冷却防 3 连发叠晕。
## 由 Bullet._explode（大招抛射弹）对落点范围内敌人调用。
static func try_apply_tremor_stun(tower: Tower, enemy: Enemy) -> void:
	if tower == null or not is_instance_valid(tower) or enemy == null or enemy.is_dead:
		return
	if not has_skill(tower, &"tremor"):
		return
	var key := enemy.get_instance_id()
	var cooldowns: Dictionary = tower.tremor_stun_cooldowns
	if float(cooldowns.get(key, 0.0)) > 0.0:
		return
	var s := tier_multiplier(tower)
	var duration := param(tower, &"tremor", "stun_duration", 0.5) * s
	enemy.apply_stun(duration)
	cooldowns[key] = param(tower, &"tremor", "cooldown", 2.5)
	tower.spawn_float_text(get_skill_name(&"tremor"), Color(1.0, 0.8, 0.5))


## 常驻伤害倍率（叠加进 Tower.finalize_damage）：投石车·破城（条件增伤，档次 3 预算）+
## 黄忠·定军山易伤标记。军旗光环已收敛进 Tower 常驻光环伤害桶（档次 1，STATS_PIPELINE）。
static func passive_damage_multiplier(tower: Tower, target: Enemy) -> float:
	var multiplier := 1.0
	if has_skill(tower, &"siege") and (target.tags.has(&"elite") or target.tags.has(&"boss")):
		multiplier *= 1.0 + param(tower, &"siege", "elite_damage_bonus", 0.1) * tier_multiplier(tower)
	# 定军山：被定军标记的目标受该塔普攻伤害 +15%。
	if has_character_skill(tower, &"char_dingjun") and target.has_mark(tower.character_id):
		multiplier *= 1.0 + character_param(tower, &"char_dingjun", "mark_damage_bonus", 0.15)
	return multiplier


## 大招范围倍率（术士·奇谋，供术士大招计算爆炸半径）。
static func ultimate_aoe_radius_multiplier(tower: Tower) -> float:
	if has_skill(tower, &"wisdom"):
		return 1.0 + param(tower, &"wisdom", "aoe_radius_bonus", 0.1) * tier_multiplier(tower)
	return 1.0

## 大招击杀返怒（骑兵·蓄力强化；无 charge 时返回职业基础 50%）。
static func kill_rage_refund(tower: Tower) -> float:
	if has_skill(tower, &"charge"):
		return param(tower, &"charge", "base_refund", 50.0) * tier_multiplier(tower)
	return 50.0


## ============ 角色技能执行器（演出：飘字 + 扩散环 + 音效） ============

## 关羽·青龙偃月（A/CD18）：2.5× 普攻单体伤害；击杀则冷却 -6s。
static func _cast_green_dragon(tower: Tower) -> bool:
	var target: Enemy = tower.target
	if target == null or not tower.is_target_valid(target):
		return false
	var hp_before := target.current_hp
	target.take_damage(tower.finalize_damage(int(round(tower.damage * character_param(tower, &"char_green_dragon", "mult", 2.5))), target), tower.character_id)
	if hp_before > 0 and target.current_hp <= 0:
		tower.refund_character_skill_cooldown(character_param(tower, &"char_green_dragon", "kill_cd_refund", 6.0))
	tower.spawn_float_text(get_character_skill_name(&"char_green_dragon"), Color(0.6, 0.95, 0.75))
	tower.play_skill_effect(Color(0.6, 0.95, 0.75))
	SfxLibrary.play(&"skill", -7.0)
	return true


## 张飞·当阳桥（A/CD22）：范围内敌人恐惧 1s（反向行军、移速不变）→ 结束后
## 减速 60% 2s（两段顺序控制，v0.35.2 / 0.8.10.1；CHARACTER_SKILLS / NUMBERS 10.10）。
static func _cast_dangyang_roar(tower: Tower) -> bool:
	var enemies := tower.enemies_in_range()
	if enemies.is_empty():
		return false
	for enemy in enemies:
		enemy.apply_fear(
			character_param(tower, &"char_dangyang_roar", "fear_duration", 1.0),
			character_param(tower, &"char_dangyang_roar", "slow_factor", 0.4),
			character_param(tower, &"char_dangyang_roar", "slow_duration", 2.0)
		)
	tower.spawn_float_text(get_character_skill_name(&"char_dangyang_roar"), Color(0.95, 0.6, 0.35))
	tower.play_skill_effect(Color(0.95, 0.6, 0.35))
	SfxLibrary.play(&"skill", -7.0)
	return true


## 刘备·携民渡江（B·每波首次漏怪）：全队攻速 +15% 5s。
static func _cast_carry_people(tower: Tower) -> bool:
	var speed_bonus := character_param(tower, &"char_carry_people", "team_speed_bonus", 0.15)
	var duration := character_param(tower, &"char_carry_people", "duration", 5.0)
	for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var ally := node as Tower
		if ally != null and is_instance_valid(ally):
			ally.apply_attack_speed_buff("char_carry_people", 1.0 + speed_bonus, duration)
	tower.spawn_float_text(get_character_skill_name(&"char_carry_people"), Color(0.7, 0.95, 0.8))
	tower.play_skill_effect(Color(0.7, 0.95, 0.8))
	SfxLibrary.play(&"skill", -8.0)
	return true


## 黄忠·定军山（A/CD18）：2.5× 单体伤害；未击杀则目标被定军标记 5s（普攻易伤 +15%）。
static func _cast_dingjun(tower: Tower) -> bool:
	var target: Enemy = tower.target
	if target == null or not tower.is_target_valid(target):
		return false
	var hp_before := target.current_hp
	target.take_damage(tower.finalize_damage(int(round(tower.damage * character_param(tower, &"char_dingjun", "mult", 2.5))), target), tower.character_id)
	if hp_before > 0 and target.current_hp > 0:
		target.apply_mark(tower.character_id, character_param(tower, &"char_dingjun", "mark_duration", 5.0))
	tower.spawn_float_text(get_character_skill_name(&"char_dingjun"), Color(0.85, 0.75, 0.4))
	tower.play_skill_effect(Color(0.85, 0.75, 0.4))
	SfxLibrary.play(&"skill", -7.0)
	return true


## 貂蝉·月下舞（A/CD25）：全队怒气 +10（自身 +15）；怒气资源类间接关联为允许例外。
static func _cast_moon_dance(tower: Tower) -> bool:
	var team_rage := character_param(tower, &"char_moon_dance", "team_rage", 10.0)
	var self_rage := team_rage + character_param(tower, &"char_moon_dance", "self_rage_extra", 5.0)
	for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var ally := node as Tower
		if ally == null or not is_instance_valid(ally):
			continue
		ally.gain_rage(self_rage if ally == tower else team_rage)
	tower.spawn_float_text(get_character_skill_name(&"char_moon_dance"), Color(1.0, 0.7, 0.9))
	tower.play_skill_effect(Color(1.0, 0.7, 0.9))
	SfxLibrary.play(&"skill", -7.0)
	return true


## 皇甫嵩·焚营（A/CD20）：目标区域 1.5× 范围伤害 + 灼烧 3s（每秒 0.25×）。
static func _cast_burn_camp(tower: Tower) -> bool:
	var center_target: Enemy = tower.target
	var center := Vector2.ZERO
	if center_target != null and tower.is_target_valid(center_target):
		center = center_target.global_position
	else:
		var enemies := tower.enemies_in_range()
		if enemies.is_empty():
			return false
		center = enemies[0].global_position
	var aoe_radius := character_param(tower, &"char_burn_camp", "aoe_radius", 90.0)
	var burn_dps := int(round(tower.damage * character_param(tower, &"char_burn_camp", "burn_dps_mult", 0.25)))
	var burn_duration := character_param(tower, &"char_burn_camp", "burn_duration", 3.0)
	for enemy in tower.enemies_in_range():
		if enemy.global_position.distance_to(center) <= aoe_radius:
			enemy.take_damage(tower.finalize_damage(int(round(tower.damage * character_param(tower, &"char_burn_camp", "mult", 1.5))), enemy), tower.character_id)
			enemy.apply_burn(burn_dps, burn_duration)
	tower.spawn_float_text(get_character_skill_name(&"char_burn_camp"), Color(1.0, 0.55, 0.3))
	tower.play_skill_effect(Color(1.0, 0.55, 0.3))
	SfxLibrary.play(&"skill", -7.0)
	return true


## 赵云·七进七出（B·每波首次漏怪）：射程内所有敌人 1× 范围伤害 + 自身攻速 +30% 3s。
static func _cast_seven_charges(tower: Tower) -> bool:
	for enemy in tower.enemies_in_range():
		enemy.take_damage(tower.finalize_damage(int(round(tower.damage * character_param(tower, &"char_seven_charges", "mult", 1.0))), enemy), tower.character_id)
	tower.apply_attack_speed_buff("char_seven_charges", 1.0 + character_param(tower, &"char_seven_charges", "speed_bonus", 0.3), character_param(tower, &"char_seven_charges", "duration", 3.0))
	tower.spawn_float_text(get_character_skill_name(&"char_seven_charges"), Color(0.7, 0.85, 1.0))
	tower.play_skill_effect(Color(0.7, 0.85, 1.0))
	SfxLibrary.play(&"skill", -8.0)
	return true


## 周仓·死战（B·基地生命 ≤50%）：周仓攻速 +30% 常驻（仅触发一次）。
static func _cast_death_fight(tower: Tower) -> bool:
	tower.set_character_skill_activated(true)
	tower.set_character_skill_speed_bonus(character_param(tower, &"char_death_fight", "speed_bonus", 0.3))
	tower.spawn_float_text(get_character_skill_name(&"char_death_fight"), Color(0.9, 0.45, 0.35))
	tower.play_skill_effect(Color(0.9, 0.45, 0.35))
	SfxLibrary.play(&"skill", -8.0)
	return true


## 诸葛亮·借东风（A/CD30）：全图友方塔攻速 +20%、弹道速度 +50% 持续 8s。
static func _cast_borrow_wind(tower: Tower) -> bool:
	var speed_bonus := character_param(tower, &"char_borrow_wind", "team_speed_bonus", 0.2)
	var bullet_speed_bonus := character_param(tower, &"char_borrow_wind", "bullet_speed_bonus", 0.5)
	var duration := character_param(tower, &"char_borrow_wind", "duration", 8.0)
	for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var ally := node as Tower
		if ally == null or not is_instance_valid(ally):
			continue
		ally.apply_attack_speed_buff("char_borrow_wind", 1.0 + speed_bonus, duration)
		ally.apply_bullet_speed_buff("char_borrow_wind", 1.0 + bullet_speed_bonus, duration)
	tower.spawn_float_text(get_character_skill_name(&"char_borrow_wind"), Color(0.6, 0.85, 1.0))
	tower.play_skill_effect(Color(0.6, 0.85, 1.0))
	SfxLibrary.play(&"skill", -6.0)
	return true
