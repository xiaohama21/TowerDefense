extends "res://tests/ChapterBalanceRunner.gd"

## 0.9.7：隔离新档，真实连续关卡/结算/养成。失败只作测量，不产生收益。
var policy := ""
var progression_rows: Array = []
var outcomes: Array = []
var checks := 0
var no_defense := false
const REPORT := "res://build/progression_balance_latest.json"
const CHOICES := [["guan_yu", "liu_bei"], ["guan_yu", "liu_bei"], ["guan_yu", "zhang_fei", "liu_bei"], ["guan_yu", "huang_zhong", "huang_fu_song", "liu_bei"], ["guan_yu", "huang_zhong", "huang_fu_song", "diao_chan"], ["guan_yu", "zhou_wei", "huang_fu_song", "huang_zhong"], ["zhao_yun", "zhou_wei", "huang_fu_song", "huang_zhong"], ["guan_yu", "huang_zhong", "huang_fu_song", "zhuge_liang"]]

func _check(condition: bool, message: String) -> void:
	checks += 1
	super._check(condition, message)

func _run() -> void:
	GameFlow.clear_squad_relics()
	GameFlow.selected_difficulty = Difficulty.NORMAL
	var prior_manual := GameFlow.is_gameplay_flag_enabled("manual_ultimate")
	GameFlow.set_gameplay_flag("manual_ultimate", false)
	for choice in ["balanced", "equipment_talents"]:
		policy = choice
		_check(GameFlow.start_new_game(), "建立真实新档")
		var cleared := 0
		var farms := 0
		var failed_attempts := 0
		for number in range(1, 9):
			_develop(number)
			var won := await _attempt(number, false)
			if not won: failed_attempts += 1
			for retry in range(12):
				if won or number == 1: break
				# 仅刷当前最高已通关关卡；用该关合法阵容赚真实资源。
				_develop(number - 1)
				if not await _attempt(number - 1, true): break
				farms += 1
				_develop(number)
				won = await _attempt(number, false)
				if not won: failed_attempts += 1
			if not won: break
			cleared = number
		outcomes.append({"policy": policy, "cleared": cleared, "farms": farms, "failed_attempts": failed_attempts, "profile": _snapshot()})
		_check(cleared == 8, "新档可合法推进全章：" + policy)
		_check(farms == 0 and failed_attempts == 0, "首章标准策略无需额外刷关：" + policy)
	policy = "defeat_guard"; no_defense = true
	_check(not await _attempt(1, false), "不建塔的失败不会推进存档或领取收益")
	var audit := _audit_curves_and_resources()
	var report_path := REPORT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-path="): report_path = argument.trim_prefix("--report-path=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"program": ProjectSettings.get_setting("application/config/version"), "delta": VIRTUAL_DELTA, "seed": 20261105, "difficulty": "normal", "excluded": ["tech", "supplies", "relics", "shop_purchases"], "checks": checks, "outcomes": outcomes, "attempts": progression_rows, "audit": audit, "failures": failures}, "\t")); file.close()
	GameFlow.set_gameplay_flag("manual_ultimate", prior_manual)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_profile_file + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_profile_file + suffix))
	print("PROGRESSION_RESULT: %s checks=%d attempts=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, progression_rows.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _attempt(number: int, farming: bool) -> bool:
	var profile := ProfileStore.get_profile()
	var stage := GameFlow.load_stage_data(StringName("ch01_s%02d" % number))
	_check(GameFlow.is_stage_unlocked(profile, stage), "关卡前置合法")
	for id in CHOICES[number - 1]: _check(profile.has_character(id), "不预发武将 " + id)
	var before := profile.to_dict()
	var loadouts := _snapshot()
	seed_offset = progression_rows.size() * 97
	await _simulate_stage(number, 1)
	var row: Dictionary = chapter_rows.back().duplicate(true)
	row.erase("level")
	row["policy"] = policy; row["farming"] = farming; row["before"] = loadouts
	var session: BattleSession = GameManager.active_battle_session
	if row.victory:
		var first := not profile.stage_progress.has(str(stage.stage_id))
		GameFlow.collect_stage_rewards(session, stage, first)
		GameFlow.award_tech_points(session, first)
		session.add_participation_xp(session.get_deployed_character_ids(), stage.participant_xp)
		session.finalize_exp_pool_injection(stage.participant_xp)
		row["rewards"] = {"xp": session.get_pending_xp_by_character(), "pool": session.get_pending_exp_pool(), "items": session.get_pending_loot(), "weapons": session.get_pending_weapons(), "ingots": session.get_pending_ingots(), "lord_exp": session.get_pending_lord_exp()}
		_check(session.mark_victory({"remaining_lives": GameManager.lives, "completed_waves": GameManager.current_wave, "difficulty": "normal"}), "标记胜利")
		_check(ProfileStore.commit_victory(session), "真实结算成功")
		var saved := ProfileStore.get_profile().to_dict()
		_check(ProfileStore.commit_victory(session) and ProfileStore.get_profile().to_dict() == saved, "重复结算幂等")
		_reload()
	else:
		session.mark_defeat()
		_check(ProfileStore.get_profile().to_dict() == before, "失败零收益")
	row["after"] = _snapshot()
	progression_rows.append(row)
	print("PROGRESSION_ROW " + JSON.stringify({"policy": policy, "stage": row.stage, "farming": farming, "victory": row.victory, "lives": row.lives, "levels": row.before.heroes, "pool": row.after.pool}))
	return bool(row.victory)

func _reload() -> void:
	var saved := ProfileStore.get_profile().to_dict()
	_check(ProfileStore.save_profile(ProfileStore.get_profile()), "养成持久化")
	ProfileStore.profile = null
	var loaded := ProfileStore.load_profile()
	# Godot JSON将无类型容器内整数读为float；比较双方序列化形态，仍完整核验每个字段。
	_check(JSON.parse_string(JSON.stringify(loaded.to_dict())) == JSON.parse_string(JSON.stringify(saved)), "完整存档重载一致")

func _develop(number: int) -> void:
	var profile := ProfileStore.get_profile()
	var ids: Array = CHOICES[number - 1]
	# 每次补一级，优先最低等级并以阵容顺序打破平局。
	for step in range(1000):
		var best := ""; var lowest := 101
		for id in ids:
			if not profile.has_character(id): continue
			var level := GameFlow.get_character_level(profile, id)
			if level < lowest and profile.exp_pool_level_up_cost(id) <= profile.exp_pool:
				lowest = level; best = id
		if best.is_empty(): break
		_check(profile.level_up_with_exp_pool(best), "合法经验池分配")
	for id in ids:
		if not profile.has_character(id): continue
		while profile.rank_up_status(id) == "进阶":
			_check(profile.advance_character_rank(id), "合法材料进阶")
		if policy == "equipment_talents":
			for weapon in WeaponRegistry.for_character(GameFlow.load_character_data(id)):
				if profile.weapon_available(str(weapon.weapon_id), id) > 0:
					_check(profile.set_character_weapon(id, str(weapon.weapon_id)), "掉落装备合法配装"); break
			for tree_id in TalentRegistry.tree_ids(id):
				for node in TalentRegistry.get_tree_data(tree_id).nodes:
					var key := str(node.id)
					while profile.talent_allocation_status(id, key) == "分配":
						_check(profile.allocate_talent(id, key, int(profile.get_talent_alloc(id).get(key, 0))), "免费天赋合法点数")
	_reload()

func _snapshot() -> Dictionary:
	var profile := ProfileStore.get_profile()
	var heroes := {}
	for id in profile.get_owned_character_ids():
		heroes[id] = {"level": GameFlow.get_character_level(profile, id), "rank": profile.get_character_rank(id), "xp": profile.get_character_exp(id), "weapon": profile.get_character_weapon_id(id), "talents": profile.get_talent_alloc(id)}
	return {"heroes": heroes, "pool": profile.exp_pool, "items": profile.items.duplicate(), "weapons": profile.weapons.duplicate(), "ingots": profile.ingots, "lord_exp": profile.lord_exp, "lord_level": ShopRegistry.lord_progress(profile.lord_exp).level, "merit": profile.military_merit}

func _validate_stage_row(row: Dictionary) -> void:
	_check(GameManager.gold >= 0 and row.spent >= 0, "战斗预算非负")

func _use_budget() -> void:
	if no_defense: return
	if chapter_groups.size() < chapter_stage.recommended_tower_count and not slots.is_empty():
		var id := squad[build_index % squad.size()]
		var hero := GameFlow.load_character_data(id)
		if GameManager.gold >= hero.build_cost:
			var loadout := GameFlow.get_battle_loadout(ProfileStore.get_profile(), id)
			var best := 0; var score := -1.0
			var stats := hero.compute_stats_at(loadout.level, loadout.rank, loadout.relic, 0, loadout.growth_guard, loadout.skill_levels, loadout.weapon, loadout.talent_alloc)
			for i in range(slots.size()):
				var coverage := 0.0
				for path in chapter_manager.paths.values():
					if path == null: continue
					for j in range(int(path.curve.get_baked_length() / 40)):
						var distance := slots[i].distance_to(path.curve.sample_baked(j * 40.0))
						if distance <= float(stats.range) and distance >= float(stats.min_range): coverage += 1.0
				if coverage > score: score = coverage; best = i
			var tower: Tower = _tower_manager.build_tower(slots[best], hero, null, loadout)
			tower.process_mode = Node.PROCESS_MODE_DISABLED
			if not GameManager.active_battle_session.deployed_character_ids.has(id):
				GameManager.active_battle_session.deployed_character_ids.append(id)
			chapter_groups.append({"tower": tower, "remaining": 0.0, "ult_count": 0})
			spend += hero.build_cost; build_index += 1; slots.remove_at(best)
			return
	if chapter_groups.size() >= chapter_stage.recommended_tower_count or slots.is_empty():
		for entry in chapter_groups:
			var before := GameManager.gold
			if _tower_manager.upgrade_tower(entry.tower, chapter_stage): spend += before - GameManager.gold; return

func _audit_curves_and_resources() -> Dictionary:
	var curve: Array = []
	var prior := 0
	for level in range(2, 101):
		var total := LevelCurve.exp_total_for_level(level)
		var need := total - LevelCurve.exp_total_for_level(level - 1)
		_check(need >= prior and LevelCurve.level_from_total_exp(total) == level and LevelCurve.level_from_total_exp(total - 1) == level - 1, "连续经验边界 %d" % level)
		curve.append({"level": level, "total": total, "need": need}); prior = need
	_check(LevelCurve.exp_total_for_level(100) == 79770, "满级投入保持")
	var resources: Array = []
	for number in range(1, 9):
		var stage := GameFlow.load_stage_data(StringName("ch01_s%02d" % number))
		var first := {}; var repeat := {}; var expected := {}
		for reward in stage.first_clear_rewards: first[str(reward.item.item_id)] = reward.amount
		for reward in stage.repeat_clear_rewards: repeat[str(reward.item.item_id)] = reward.amount
		for drop in stage.probability_drops: expected[str(drop.item.item_id)] = drop.amount * drop.chance
		resources.append({"stage": str(stage.stage_id), "first": first, "repeat_guaranteed": repeat, "random_expectation": expected, "repeat_weapon_chance": stage.repeat_weapon_drop_chance})
	var prices: Array = []
	for offer in ShopRegistry.all_offers():
		prices.append({"id": str(offer.id), "price": int(offer.price), "currency": str(offer.currency), "level": int(offer.level), "limit": int(offer.limit), "items": offer.items, "stage": str(offer.get("unlock_stage", ""))})
	return {"curve": curve, "drops": resources, "shop": prices, "loadouts": _audit_loadouts()}

func _audit_loadouts() -> Array:
	var rows: Array = []
	for id in GameFlow.get_all_character_ids():
		var hero := GameFlow.load_character_data(id)
		for level in [1, 10, 20, 40, 60, 80, 100]:
			var rank := 0
			for r in range(1, 6):
				if level >= CharacterRank.LEVELS[r]: rank = r
			var base := hero.compute_stats_at(level, rank)
			var options: Array = [{"name": "bare", "weapon": null, "alloc": {}}]
			for weapon in WeaponRegistry.for_character(hero): options.append({"name": str(weapon.weapon_id), "weapon": weapon, "alloc": {}})
			for tree_id in TalentRegistry.tree_ids(id):
				var profile := PlayerProfile.new()
				profile.unlock_character(id, {"total_exp": LevelCurve.exp_total_for_level(level), "rank": rank})
				_spend_tree(profile, id, tree_id, 20)
				options.append({"name": tree_id, "weapon": null, "alloc": profile.get_talent_alloc(id)})
			# 三树均摊，含最高层门槛，组合采用同一合法点数预算。
			var mixed := PlayerProfile.new()
			mixed.unlock_character(id, {"total_exp": LevelCurve.exp_total_for_level(level), "rank": rank})
			for step in range(TalentRegistry.points_for_level(level)):
				var tree_ids := TalentRegistry.tree_ids(id)
				_spend_tree(mixed, id, tree_ids[step % tree_ids.size()], 1)
			var weapons := WeaponRegistry.for_character(hero)
			options.append({"name": "mixed_gear_talents", "weapon": weapons[0] if not weapons.is_empty() else null, "alloc": mixed.get_talent_alloc(id)})
			for option in options:
				var stats := hero.compute_stats_at(level, rank, null, 0, {}, {}, option.weapon, option.alloc)
				var points := TalentRegistry.spent(option.alloc)
				_check(points <= TalentRegistry.points_for_level(level) and stats.attack_interval >= .2 and stats.crit_rate <= .75 and stats.range > 0, "合法组合与属性上限 " + id)
				rows.append({"hero": id, "level": level, "rank": rank, "option": option.name, "points": points, "attack": stats.attack, "interval": stats.attack_interval, "range": stats.range, "crit_rate": stats.crit_rate, "crit_damage": stats.crit_damage, "skill_amp": stats.skill_amp, "talents": stats.talents, "sheet_dps_ratio": (float(stats.damage) / stats.attack_interval) / (float(base.damage) / base.attack_interval), "range_ratio": float(stats.range) / base.range})
	return rows

func _spend_tree(profile: PlayerProfile, id: String, tree_id: String, budget: int) -> void:
	var left := budget
	for node in TalentRegistry.get_tree_data(tree_id).nodes:
		var key := str(node.id)
		while left > 0 and profile.talent_allocation_status(id, key) == "分配":
			_check(profile.allocate_talent(id, key, int(profile.get_talent_alloc(id).get(key, 0))), "分析分配走真实门槛")
			left -= 1
