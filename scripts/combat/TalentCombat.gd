extends RefCounted
class_name TalentCombat

static func value(tower: Tower, key: String) -> float:
	return float(tower.talent_bonuses.get(key, 0.0))

static func reset(tower: Tower) -> void:
	tower.talent_state = {"kill_left": 0.0, "post_left": 0.0, "fury_left": 0.0, "last_target": 0, "hits": 0, "gold_fraction": 0.0, "leak_wave": -1}

static func tick(tower: Tower, delta: float) -> void:
	if tower.talent_bonuses.is_empty(): return
	var previous := speed_multiplier(tower)
	for key in ["kill_left", "post_left", "fury_left"]:
		tower.talent_state[key] = maxf(float(tower.talent_state.get(key, 0.0)) - delta, 0.0)
	if not is_equal_approx(previous, speed_multiplier(tower)): tower._rebuild_attack_timer()

static func speed_multiplier(tower: Tower) -> float:
	var bonus := value(tower, "kill_speed_pct") if float(tower.talent_state.get("kill_left", 0.0)) > 0.0 else 0.0
	if tower.rage >= tower._max_rage * 0.5: bonus += value(tower, "high_rage_speed_pct")
	return 1.0 + bonus

static func rage_bonus(tower: Tower) -> float:
	return value(tower, "rage_pct") + (value(tower, "post_ultimate_rage_pct") if float(tower.talent_state.get("post_left", 0.0)) > 0.0 else 0.0)

static func hit_rage(tower: Tower) -> float:
	return value(tower, "hit_rage_flat") + (value(tower, "post_ultimate_hit_rage") if float(tower.talent_state.get("fury_left", 0.0)) > 0.0 else 0.0)

static func damage_multiplier(tower: Tower, enemy: Enemy, damage_type: StringName, kind: StringName) -> float:
	if tower.talent_bonuses.is_empty() or not is_instance_valid(enemy): return 1.0
	var bonus := value(tower, "physical_damage_pct") if damage_type == DamageTypes.PHYSICAL else (value(tower, "magic_damage_pct") if damage_type == DamageTypes.MAGIC else 0.0)
	if kind == &"attack": bonus += value(tower, "attack_damage_pct")
	var elite := enemy.tags.has(&"elite")
	var boss := enemy.tags.has(&"boss")
	if elite: bonus += value(tower, "elite_damage_pct")
	if boss: bonus += value(tower, "boss_damage_pct")
	if elite or boss: bonus += value(tower, "elite_boss_damage_pct")
	if enemy.get_armor_aura_bonus() > 0: bonus += value(tower, "aura_armor_damage_pct")
	if enemy.get_hp_ratio() <= 0.5: bonus += value(tower, "low_hp_damage_pct")
	if enemy.is_controlled():
		bonus += value(tower, "controlled_damage_pct")
		if elite or boss: bonus += value(tower, "controlled_elite_damage_pct")
	return 1.0 + clampf(bonus, 0.0, 0.3)

static func penetration(tower: Tower, enemy: Enemy = null, kind: StringName = &"skill") -> Dictionary:
	var ratio := value(tower, "armor_pen_pct")
	if kind == &"ultimate": ratio += value(tower, "ultimate_pen_pct")
	if kind == &"attack" and is_instance_valid(enemy) and int(tower.talent_state.get("last_target", 0)) == enemy.get_instance_id(): ratio += value(tower, "same_target_pen_pct")
	var flat := value(tower, "armor_pen_flat")
	if float(tower.talent_state.get("kill_left", 0.0)) > 0.0: flat += value(tower, "kill_pen_flat")
	return {"ratio": clampf(ratio, 0.0, 0.3), "flat": int(round(flat))}

static func on_attack_target(tower: Tower, enemy: Enemy) -> void:
	if not is_instance_valid(enemy): return
	if not enemy.is_dead and value(tower, "slow_on_hit") > 0.0:
		enemy.apply_slow(maxf(1.0 - value(tower, "slow_on_hit") * (1.0 + value(tower, "slow_strength_pct")), 0.05), 2.0 * (1.0 + value(tower, "control_duration_pct")), SkillRegistry.slow_source(tower, &"talent_slow_on_hit"))

static func on_attack(tower: Tower, enemy: Enemy) -> void:
	if tower.talent_bonuses.is_empty(): return
	tower.talent_state["hits"] = int(tower.talent_state.get("hits", 0)) + 1
	tower.talent_state["last_target"] = enemy.get_instance_id() if is_instance_valid(enemy) else 0
	var every := int(value(tower, "armor_ignore_every"))
	if every > 0 and int(tower.talent_state.hits) % every == 0 and is_instance_valid(enemy) and not enemy.is_dead:
		var amount := tower.finalize_damage(int(round(tower.damage * value(tower, "armor_ignore_mult"))), enemy, DamageTypes.TRUE)
		tower.deal_damage(enemy, amount, DamageTypes.TRUE, &"talent")
		tower.play_skill_effect()

static func on_kill(tower: Tower, enemy: Enemy, kind: StringName) -> int:
	if tower.talent_bonuses.is_empty(): return 0
	tower.talent_state["kill_left"] = 2.0
	tower.grant_rage_flat(value(tower, "kill_rage_flat") + (value(tower, "ultimate_kill_rage") if kind == &"ultimate" else 0.0))
	tower._rebuild_attack_timer()
	var bonus := value(tower, "kill_gold_pct")
	if enemy.tags.has(&"elite"): bonus += value(tower, "elite_gold_pct")
	if enemy.tags.has(&"boss"): bonus += value(tower, "boss_gold_pct")
	var credited := int(round(enemy.reward * Difficulty.reward_mult(GameFlow.selected_difficulty)))
	var fraction := float(tower.talent_state.get("gold_fraction", 0.0)) + credited * clampf(bonus, 0.0, 0.3)
	var extra := floori(fraction + 0.0000001)
	tower.talent_state["gold_fraction"] = maxf(fraction - extra, 0.0)
	return extra

static func on_ultimate_end(tower: Tower) -> void:
	if tower.talent_bonuses.is_empty(): return
	tower.talent_state["post_left"] = 2.0
	tower.talent_state["fury_left"] = 3.0

static func on_leak(tower: Tower) -> void:
	if int(tower.talent_state.get("leak_wave", -1)) == GameManager.current_wave: return
	tower.talent_state["leak_wave"] = GameManager.current_wave
	tower.grant_rage_flat(value(tower, "leak_rage_flat"))
