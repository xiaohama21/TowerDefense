extends RefCounted
class_name SkillRegistry

const MAX_LEVEL := 10
const COSTS := [1, 1, 2, 2, 3, 3, 4, 4, 5]
const KITS := {
	"guan_yu": ["passive_green_dragon_stance", "passive_warm_wine", "char_green_dragon"],
	"zhang_fei": ["trait_yanyan_roar", "passive_yanhan", "char_dangyang_roar"],
	"liu_bei": ["trait_benevolence", "passive_diligence", "char_carry_people"],
	"huang_zhong": ["trait_hundred_step", "passive_sentry", "char_dingjun"],
	"diao_chan": ["trait_moon_veil", "passive_worship_moon", "char_moon_dance"],
	"huang_fu_song": ["passive_fierce_flame", "passive_detonation", "char_burn_camp"],
	"zhao_yun": ["trait_dragon_spirit", "passive_dragon_courage", "char_seven_charges"],
	"zhou_wei": ["trait_vanguard", "char_death_fight", "ultimate_death_fight"],
	"zhuge_liang": ["trait_star_gazer", "passive_momentum", "char_borrow_wind"],
}
const NAMES := {
	"passive_green_dragon_stance": "青龙势", "passive_warm_wine": "温酒", "char_green_dragon": "青龙偃月",
	"trait_yanyan_roar": "燕人咆哮", "passive_yanhan": "燕颔", "char_dangyang_roar": "当阳桥",
	"trait_benevolence": "仁德", "passive_diligence": "砥砺", "char_carry_people": "携民渡江",
	"trait_hundred_step": "百步穿杨", "passive_sentry": "哨戒", "char_dingjun": "定军山",
	"trait_moon_veil": "月华", "passive_worship_moon": "拜月", "char_moon_dance": "凤仪鼓舞",
	"passive_fierce_flame": "烈焰", "passive_detonation": "爆燃", "char_burn_camp": "长社焚营",
	"trait_dragon_spirit": "龙魂", "passive_dragon_courage": "龙胆", "char_seven_charges": "七进七出",
	"trait_vanguard": "陷阵", "char_death_fight": "死战", "ultimate_death_fight": "麦城死战",
	"trait_star_gazer": "观星", "passive_momentum": "乘势", "char_borrow_wind": "借东风",
}
const DESCRIPTIONS := {
	"passive_green_dragon_stance": "普攻按命中次数累计，周期性打出必定暴击的一击。",
	"passive_warm_wine": "青龙偃月的最后一击完成后，短时间提升自身攻击速度。",
	"char_green_dragon": "对目标连续斩击，造成真实伤害。击杀后的溢出伤害带入下一击，并按击杀数返还怒气。",
	"trait_yanyan_roar": "普攻命中时有概率追加物理伤害，并使存活目标陷入恐惧、沿路径后退。",
	"passive_yanhan": "自身击杀敌人时额外获得怒气，更快积满大招。",
	"char_dangyang_roar": "对射程内敌人造成物理伤害，先使其恐惧后退，恐惧结束后再施加减速。",
	"trait_benevolence": "提升射程内友方的基础攻击；不同刘备的光环可叠加，最多达到叠层上限。",
	"passive_diligence": "提升射程内友方的暴击率；不同刘备的光环可叠加，最多达到叠层上限。",
	"char_carry_people": "短时间提升射程内友方的攻击速度，帮助队伍集中输出。",
	"trait_hundred_step": "连续普攻同一敌人时逐次增加普攻伤害，达到上限后保持；换目标重新累计。",
	"passive_sentry": "普攻命中后使敌人中毒，在持续时间内每秒造成固定伤害。",
	"char_dingjun": "使射程内敌人受到更多伤害，同时短时间提升自身攻击、攻速和暴击率。",
	"trait_moon_veil": "提升自身和射程内友方的怒气获取速度，帮助队伍更频繁地施放大招。",
	"passive_worship_moon": "本技能解锁后，局内升至指定阶数时提升自身技能增幅。",
	"char_moon_dance": "短时间提升全队攻击速度，支援全场友方输出。",
	"passive_fierce_flame": "常驻提升自身基础攻击、射程和普攻溅射半径。",
	"passive_detonation": "被自身灼烧的敌人死亡时发生爆炸，对死亡位置附近的敌人造成物理伤害。",
	"char_burn_camp": "轰击目标所在位置，对落点范围内的敌人造成物理伤害，并附加持续灼烧。",
	"trait_dragon_spirit": "常驻提升自身穿甲和暴击伤害，强化对高护甲敌人的输出。",
	"passive_dragon_courage": "常驻提升自身暴击率，使攻击更容易打出暴击。",
	"char_seven_charges": "攻击射程内生命最低的多个敌人，对每个目标造成物理伤害，并短时间提升自身攻速。",
	"trait_vanguard": "常驻提升自身穿甲，削弱敌方护甲对攻击的阻挡。",
	"char_death_fight": "普攻命中时有概率追加一次高额物理伤害。",
	"ultimate_death_fight": "对当前目标造成高额物理伤害；基地生命较低时，伤害进一步提升。",
	"trait_star_gazer": "常驻扩大自身射程，并持续减速射程内的敌人。",
	"passive_momentum": "施放借东风时，射程内每名受控敌人都会增加本次技能增幅，最多达到增幅上限。",
	"char_borrow_wind": "对全图敌人造成魔法伤害，并使隐匿敌人现形，让所有友方都能攻击它们。",
}
const EFFECT_LABELS := {
	"mult": "技能伤害", "speed_bonus": "攻速", "attack_flat": "基础攻击",
	"range_flat": "射程", "range_bonus": "射程", "splash_flat": "溅射半径",
	"crit_rate": "暴击率", "crit_damage": "暴击伤害", "penetration": "穿甲",
	"kill_rage": "击杀返怒", "kill_cap": "返怒上限", "self_rage": "自身积怒",
	"ally_rage": "友方积怒", "vulnerability": "易伤", "attack_bonus": "自身攻击",
	"attack_step": "每次叠加", "attack_cap": "伤害上限", "slow_strength": "减速",
	"fear_duration": "恐惧时间", "poison_dps": "中毒秒伤", "burn_ratio": "灼烧秒伤",
	"skill_amp": "技能增幅", "amp_per_enemy": "每名受控敌人", "amp_cap": "增幅上限",
	"reveal_duration": "现形时间", "duration": "持续时间", "slow_duration": "减速时间",
	"radius": "效果半径", "targets": "目标数", "segments": "连击数",
	"hit_every": "必暴间隔", "max_stacks": "叠层上限", "chance": "触发率",
	"battle_rank": "局内阶数", "base_hp_threshold": "基地生命", "low_hp_mult": "低血增伤",
}

static func is_known(id: StringName) -> bool:
	return NAMES.has(str(id))

static func get_skill_name(id: StringName) -> String:
	return str(NAMES.get(str(id), ""))

static func description_text(id: StringName) -> String:
	return str(DESCRIPTIONS.get(str(id), ""))

static func level_multiplier(level: int) -> float:
	return 1.0 + 0.03 * (clampi(level, 1, MAX_LEVEL) - 1)

static func upgrade_cost(level: int) -> int:
	return int(COSTS[level - 1]) if level >= 1 and level < MAX_LEVEL else 0

static func normalize_levels(character_id: String, raw) -> Dictionary:
	var result := {}
	for id in KITS.get(character_id, []):
		var value = raw.get(id, 1) if raw is Dictionary else 1
		var level := 1
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			if is_finite(float(value)): level = int(clampf(float(value), 1, MAX_LEVEL))
		elif value is String and value.is_valid_int():
			level = int(clampf(float(value), 1, MAX_LEVEL))
		result[id] = level
	return result

static func param(tower: Tower, id: StringName, key: String, fallback: float = 0.0) -> float:
	return tower.get_skill_param(id, key, fallback)

static func strength(tower: Tower, id: StringName) -> float:
	return level_multiplier(tower.get_skill_level(id)) * tower.skill_output_multiplier()

static func duration(tower: Tower, id: StringName, key: String = "duration") -> float:
	return param(tower, id, key) * tower.skill_output_multiplier()

static func rage_multiplier(tower: Tower) -> float:
	var total := 0.0
	if tower.has_skill(&"trait_moon_veil"):
		total += param(tower, &"trait_moon_veil", "self_rage") * strength(tower, &"trait_moon_veil")
	var best := 0.0
	for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var other := node as Tower
		if other == null or other == tower or other.is_queued_for_deletion() or not other.has_skill(&"trait_moon_veil"): continue
		if tower.global_position.distance_to(other.global_position) <= other.range_radius:
			best = maxf(best, param(other, &"trait_moon_veil", "ally_rage") * strength(other, &"trait_moon_veil"))
	return 1.0 + total + best

static func on_attack_hit(tower: Tower, victim: Enemy, _dealt: int) -> void:
	tower.skill_hit_counter += 1
	if tower.has_skill(&"trait_hundred_step"):
		var victim_id := victim.get_instance_id()
		tower.skill_consecutive_hits = tower.skill_consecutive_hits + 1 if tower.skill_last_target_id == victim_id else 1
		tower.skill_last_target_id = victim_id
	if not is_instance_valid(victim) or victim.is_dead: return
	if tower.has_skill(&"passive_sentry"):
		victim.apply_poison(int(param(tower, &"passive_sentry", "poison_dps")), duration(tower, &"passive_sentry"), tower.character_id, tower)
	for id in [&"trait_yanyan_roar", &"char_death_fight"]:
		if not tower.has_skill(id): continue
		# Upgrade affects configured probability; no pity and no amplification of probability.
		var chance := clampf(param(tower, id, "chance") * level_multiplier(tower.get_skill_level(id)), 0.0, 1.0)
		if randf() < chance:
			var amount := tower.finalize_damage(int(round(tower.damage * param(tower, id, "mult") * strength(tower, id))), victim, DamageTypes.PHYSICAL)
			tower.deal_damage(victim, amount, DamageTypes.PHYSICAL)
			if id == &"trait_yanyan_roar" and not victim.is_dead: victim.apply_fear(duration(tower, id, "fear_duration"))
			tower.play_skill_effect()

static func on_kill(tower: Tower) -> void:
	if tower.has_skill(&"passive_yanhan"):
		tower.grant_rage_flat(param(tower, &"passive_yanhan", "kill_rage") * strength(tower, &"passive_yanhan"))

static func attack_multiplier(tower: Tower, victim: Enemy) -> float:
	if tower.has_skill(&"trait_hundred_step") and tower.skill_last_target_id == victim.get_instance_id():
		return 1.0 + minf(param(tower, &"trait_hundred_step", "attack_step") * tower.skill_consecutive_hits, param(tower, &"trait_hundred_step", "attack_cap")) * strength(tower, &"trait_hundred_step")
	return 1.0

static func tick(tower: Tower, delta: float) -> void:
	tower.skill_aura_tick -= delta
	if tower.skill_aura_tick > 0.0: return
	tower.skill_aura_tick = 0.25
	if tower.has_skill(&"trait_star_gazer"):
		var slow := param(tower, &"trait_star_gazer", "slow_strength") * strength(tower, &"trait_star_gazer")
		for enemy in tower.enemies_in_range(): enemy.apply_slow(1.0 - slow, 0.5 * tower.skill_output_multiplier())
	if tower.has_skill(&"trait_benevolence") or tower.has_skill(&"passive_diligence"):
		tower.skill_support_tick -= 0.25
		if tower.skill_support_tick <= 0.0:
			tower.skill_support_tick = tower.attack_cooldown
			tower.record_support_contribution(tower.allies_in_range())

static func execute_ultimate(id: StringName, tower: Tower) -> bool:
	var enemies := tower.enemies_in_range()
	var power := strength(tower, id)
	match id:
		&"char_green_dragon":
			return _cast_green_dragon(tower)
		&"char_dangyang_roar":
			if enemies.is_empty(): return false
			for enemy in enemies:
				tower.deal_damage(enemy, tower.finalize_damage(int(round(tower.damage * param(tower, id, "mult") * power)), enemy, DamageTypes.PHYSICAL), DamageTypes.PHYSICAL)
				if not enemy.is_dead: enemy.apply_fear(duration(tower, id, "fear_duration"), maxf(1.0 - param(tower, id, "slow_strength") * power, 0.05), duration(tower, id, "slow_duration"))
		&"char_carry_people", &"char_moon_dance":
			var allies := tower.allies_in_range() if id == &"char_carry_people" else _all_towers(tower)
			if allies.is_empty(): return false
			for ally in allies:
				ally.apply_attack_speed_buff(str(id), 1.0 + param(tower, id, "speed_bonus") * power * tower.get_battle_rank_buff_power_multiplier(), duration(tower, id) * tower.get_battle_rank_buff_duration_multiplier())
		&"char_dingjun":
			if enemies.is_empty(): return false
			for enemy in enemies: enemy.apply_vulnerability(param(tower, id, "vulnerability") * power, duration(tower, id))
			tower.apply_skill_stat_buff(str(id), param(tower, id, "attack_bonus") * power, param(tower, id, "crit_rate") * power, duration(tower, id))
			tower.apply_attack_speed_buff(str(id), 1.0 + param(tower, id, "speed_bonus") * power, duration(tower, id))
		&"char_burn_camp":
			if enemies.is_empty(): return false
			var center: Vector2 = enemies[0].global_position
			if tower.is_target_valid(tower.target): center = tower.target.global_position
			var dps := int(round(tower.damage * param(tower, id, "burn_ratio")))
			for enemy in enemies:
				if enemy.global_position.distance_to(center) <= param(tower, id, "radius") * tower.get_battle_rank_aoe_multiplier():
					enemy.apply_burn(dps, duration(tower, id), tower)
					tower.deal_damage(enemy, tower.finalize_damage(int(round(tower.damage * param(tower, id, "mult") * power)), enemy, DamageTypes.PHYSICAL), DamageTypes.PHYSICAL)
		&"char_seven_charges":
			var targets := tower.lowest_hp_targets_in_range(int(param(tower, id, "targets")))
			if targets.is_empty(): return false
			for enemy in targets: tower.deal_damage(enemy, tower.finalize_damage(int(round(tower.damage * param(tower, id, "mult") * power)), enemy, DamageTypes.PHYSICAL), DamageTypes.PHYSICAL)
			tower.apply_attack_speed_buff(str(id), 1.0 + param(tower, id, "speed_bonus") * power, duration(tower, id))
		&"ultimate_death_fight":
			var victim = tower.target
			if not tower.is_target_valid(victim): return false
			var mult := param(tower, id, "mult") * power
			if float(GameManager.lives) <= float(GameManager.starting_lives) * param(tower, id, "base_hp_threshold"): mult *= param(tower, id, "low_hp_mult")
			tower.deal_damage(victim, tower.finalize_damage(int(round(tower.damage * mult)), victim, DamageTypes.PHYSICAL), DamageTypes.PHYSICAL)
		&"char_borrow_wind":
			var all_enemies := tower.get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP)
			if all_enemies.is_empty(): return false
			var controlled := 0
			if tower.has_skill(&"passive_momentum"):
				for enemy in enemies:
					if enemy.is_controlled(): controlled += 1
				var extra := minf(controlled * param(tower, &"passive_momentum", "amp_per_enemy"), param(tower, &"passive_momentum", "amp_cap")) * level_multiplier(tower.get_skill_level(&"passive_momentum"))
				power = level_multiplier(tower.get_skill_level(id)) * (tower.skill_output_multiplier() + extra)
			for node in all_enemies:
				var enemy := node as Enemy
				if enemy == null or enemy.is_dead: continue
				enemy.apply_reveal(duration(tower, id, "reveal_duration"))
				tower.deal_damage(enemy, tower.finalize_damage(int(round(tower.damage * param(tower, id, "mult") * power)), enemy, DamageTypes.MAGIC), DamageTypes.MAGIC)
		_:
			return false
	tower.play_skill_effect()
	return true

static func _all_towers(tower: Tower) -> Array[Tower]:
	var result: Array[Tower] = []
	for node in tower.get_tree().get_nodes_in_group(Tower.TOWER_GROUP):
		var ally := node as Tower
		if ally != null and not ally.is_queued_for_deletion(): result.append(ally)
	return result

static func _cast_green_dragon(tower: Tower) -> bool:
	var victim = tower.target
	if not tower.is_target_valid(victim): return false
	var id := &"char_green_dragon"
	var count := int(param(tower, id, "segments"))
	var per_segment := int(round(tower.damage * param(tower, id, "mult") * strength(tower, id)))
	var strike := {"target_id": victim.get_instance_id(), "carry": 0, "kills": 0, "struck": []}
	tower.begin_melee_flurry(count)
	for i in range(count):
		var last := i == count - 1
		tower.schedule_combat_step(tower.flurry_hit_delay(i), func() -> void: _green_dragon_segment(tower, strike, per_segment, last))
	return true

static func _green_dragon_segment(tower: Tower, strike: Dictionary, amount: int, last: bool) -> void:
	var victim = instance_from_id(int(strike.target_id)) if int(strike.target_id) != 0 else null
	if not tower.is_target_valid(victim): victim = _next_green_dragon_target(tower, strike.struck)
	if victim != null:
		var final_amount := tower.finalize_damage(amount, victim, DamageTypes.TRUE) + int(strike.carry)
		var before: int = victim.current_hp
		var consumed := ceili(float(before) / victim.get_vulnerability_multiplier())
		tower.deal_damage(victim, final_amount, DamageTypes.TRUE)
		strike.carry = maxi(final_amount - consumed, 0)
		strike.struck.append(victim.get_instance_id())
		if victim.is_dead:
			strike.kills += 1
			strike.target_id = 0
		else: strike.target_id = victim.get_instance_id()
	if last:
		var id := &"char_green_dragon"
		tower.grant_rage_flat(minf(float(strike.kills) * param(tower, id, "kill_rage"), param(tower, id, "kill_cap")) * strength(tower, id))
		if tower.has_skill(&"passive_warm_wine"):
			var wine := &"passive_warm_wine"
			tower.apply_attack_speed_buff(str(wine), 1.0 + param(tower, wine, "speed_bonus") * strength(tower, wine), duration(tower, wine))

static func _next_green_dragon_target(tower: Tower, struck: Array) -> Enemy:
	var best: Enemy = null
	for enemy in tower.enemies_in_range():
		if not struck.has(enemy.get_instance_id()) and tower.is_target_valid(enemy) and (best == null or enemy.progress_ratio > best.progress_ratio): best = enemy
	return best

static func on_burned_death(tower: Tower, center: Vector2) -> void:
	var id := &"passive_detonation"
	if not tower.has_skill(id) or tower.is_queued_for_deletion(): return
	for node in tower.get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_dead and enemy.global_position.distance_to(center) <= param(tower, id, "radius"):
			tower.deal_damage(enemy, tower.finalize_damage(int(round(tower.damage * param(tower, id, "mult") * strength(tower, id))), enemy, DamageTypes.PHYSICAL), DamageTypes.PHYSICAL)

static func effect_rows(character: CharacterData, id: StringName, level: int, amp: float) -> Array:
	var rows: Array = []
	var row: Array = []
	var params: Dictionary = character.skill_params.get(str(id), {})
	var power := level_multiplier(level) * (1.0 + amp)
	var icons := {"mult": "dmg_magic" if id == &"char_borrow_wind" else ("dmg_true" if id == &"char_green_dragon" else "dmg_physical"), "speed_bonus": "stat_attack_speed", "attack_flat": "dmg_physical", "range_flat": "stat_range", "range_bonus": "stat_range", "splash_flat": "stat_splash", "crit_rate": "stat_crit_rate", "crit_damage": "stat_crit_damage", "penetration": "stat_armor_pen", "kill_rage": "rage", "kill_cap": "rage", "self_rage": "rage", "ally_rage": "rage", "vulnerability": "status_vulnerable", "attack_bonus": "dmg_physical", "attack_step": "dmg_physical", "attack_cap": "dmg_physical", "slow_strength": "status_slow", "fear_duration": "status_fear", "poison_dps": "status_poison", "burn_ratio": "status_burn", "skill_amp": "stat_skill_amp", "amp_per_enemy": "stat_skill_amp", "amp_cap": "stat_skill_amp", "reveal_duration": "status_reveal", "duration": "cooldown", "slow_duration": "status_slow", "radius": "stat_splash", "targets": str(id), "segments": str(id), "hit_every": str(id), "max_stacks": str(id), "chance": str(id), "battle_rank": "battle_rank_3", "base_hp_threshold": "base_hp", "low_hp_mult": "dmg_physical"}
	var hints := {"speed_bonus": "攻击速度提升", "range_flat": "射程固定加值", "range_bonus": "射程百分比提升", "splash_flat": "溅射范围固定加值", "crit_rate": "暴击率提升", "crit_damage": "暴击伤害提升", "penetration": "百分比穿甲", "kill_rage": "每次击杀返怒", "vulnerability": "受所有来源伤害提升", "attack_bonus": "自身物理攻击提升", "slow_strength": "减速强度", "fear_duration": "恐惧时长", "poison_dps": "固定中毒秒伤", "skill_amp": "自身技能增幅", "amp_per_enemy": "每个受控目标增加本次技能增幅", "amp_cap": "本次增幅上限", "reveal_duration": "命中现形时长", "slow_duration": "恐惧结束后减速时长", "radius": "效果半径（px）", "targets": "最多目标数", "segments": "连击段数", "hit_every": "必定暴击的命中周期", "battle_rank": "局内升阶门槛", "mult": "技能伤害倍率", "chance": "命中触发概率（无保底）", "attack_flat": "基础攻击固定加值", "duration": "持续时间", "attack_step": "连续同目标每次增加", "attack_cap": "连续同目标加成上限", "kill_cap": "单次返怒上限", "self_rage": "自身怒气获取", "ally_rage": "射程内友方怒气获取", "max_stacks": "不同刘备覆盖的最多层数", "burn_ratio": "面板攻击乘该倍率，固定秒伤", "base_hp_threshold": "基地生命比例条件", "low_hp_mult": "低血条件额外倍率"}
	for key in params:
		var value := float(params[key])
		var text := ""
		if key in ["duration", "fear_duration", "slow_duration", "reveal_duration"]:
			text = String.num(value * (1.0 + amp), 2) + "s"
		elif key in ["poison_dps"]:
			text = String.num(value, 0) + "/秒"
		elif key == "burn_ratio":
			text = "×" + String.num(value, 2) + "/秒"
		elif key in ["radius", "targets", "segments", "hit_every", "max_stacks", "battle_rank"]:
			text = String.num(value, 0)
		elif key in ["low_hp_mult", "base_hp_threshold"]:
			text = "×" + String.num(value, 2) if key == "low_hp_mult" else "≤" + String.num(value * 100.0, 2) + "%"
		elif key == "chance":
			text = String.num(value * level_multiplier(level) * 100.0, 2) + "%"
		elif key in ["attack_flat", "range_flat", "splash_flat", "kill_rage", "kill_cap"]:
			text = "+" + String.num(value * power, 2)
		elif key == "mult":
			text = "×" + String.num(value * power, 2)
		elif key in ["amp_per_enemy", "amp_cap", "skill_amp"]:
			text = "+" + String.num(value * level_multiplier(level) * 100.0, 2) + "%"
		else:
			text = "+" + String.num(value * power * 100.0, 2) + "%"
		var icon_key: String = str(icons.get(key, ""))
		# Reuse existing generic system glyphs; every conceptual icon resolves in v2.
		if UITheme.hud_icon(icon_key) == null: icon_key = "char_death_fight" if id == &"ultimate_death_fight" else str(id)
		# Keep the first three fields stable for existing consumers.
		row.append([icon_key, text, str(hints.get(key, key)), str(EFFECT_LABELS.get(key, key))])
		if row.size() == 3:
			rows.append(row)
			row = []
	if not row.is_empty(): rows.append(row)
	return rows

static func rule_text(id: StringName) -> String:
	match id:
		&"passive_green_dragon_stance": return "每累计3次命中，第3次必定触发；换目标不重置。"
		&"passive_warm_wine": return "最后一击完成后生效。"
		&"char_green_dragon": return "三击逐拍结算；溢血带入下一击，击杀返还。"
		&"trait_yanyan_roar", &"char_death_fight": return "命中后概率追加；无保底，追加不再触发普攻事件。"
		&"passive_yanhan": return "每次击杀获得；仅击杀者生效。"
		&"char_dangyang_roar": return "先反向行军，结束后再减速；两段不重叠。"
		&"trait_benevolence", &"passive_diligence": return "每名覆盖者增加一层；离开覆盖移除。"
		&"char_carry_people": return "射程内一次施加；同源只刷新。"
		&"trait_hundred_step": return "连续命中同目标累加；换目标重置，只作用于普攻。"
		&"passive_sentry": return "命中后持续生效；固定秒伤，不受增减伤影响。"
		&"char_dingjun": return "射程内同类不叠加，自身同时获得三项限时提升。"
		&"trait_moon_veil": return "自身与射程内友方分别生效。"
		&"passive_worship_moon": return "升至局内3阶后生效；需先解锁本技能。"
		&"char_moon_dance": return "全队一次施加；同源只刷新。"
		&"passive_fierce_flame", &"trait_dragon_spirit", &"passive_dragon_courage", &"trait_vanguard": return "解锁后常驻；基础加值参与成长。"
		&"passive_detonation": return "由本塔施加的灼烧目标死亡时触发；按死亡位置结算。"
		&"char_burn_camp": return "落点范围直接命中，并附加固定秒伤。"
		&"char_seven_charges": return "射程内最多5个目标各结算一次，并提升自身。"
		&"ultimate_death_fight": return "当前目标单次结算；基地生命不高于50%时翻倍。"
		&"trait_star_gazer": return "解锁后常驻，射程内持续施加。"
		&"passive_momentum": return "施放时按射程内受控数量计算，只影响本次。"
		&"char_borrow_wind": return "全图命中并使隐匿单位现形，所有友方均可索敌。"
	return ""
