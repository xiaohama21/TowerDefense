extends Node

var checks := 0
var failures: Array[String] = []
var _slot := ""
const SHU := ["liu_bei", "guan_yu", "zhang_fei", "zhao_yun", "zhuge_liang"]

func _ready() -> void:
	_slot = "user://.factions_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("FACTION: " + message)

func _same_visible_image(source: Image, imported: Image) -> bool:
	if source.get_size() != imported.get_size(): return false
	source.convert(Image.FORMAT_RGBA8)
	imported.convert(Image.FORMAT_RGBA8)
	imported.clear_mipmaps()
	var expected := source.get_data()
	var actual := imported.get_data()
	for pixel in range(0, expected.size(), 4):
		if expected[pixel + 3] != actual[pixel + 3]: return false
		if expected[pixel + 3] > 32:
			for channel in range(3):
				if expected[pixel + channel] != actual[pixel + channel]: return false
	return true

func _run() -> void:
	var p := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(p)
	ProfileStore.save_profile(p)
	_test_catalog()
	_test_rules()
	_test_items()
	_test_legacy()
	await _test_encyclopedia()
	await _test_squad()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot + suffix))
	print("FACTION_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_catalog() -> void:
	var counts := {&"wei": 0, &"shu": 0, &"wu": 0, &"qun": 0}
	for id in GameFlow.get_all_character_ids():
		var character := GameFlow.load_character_data(str(id))
		_check(character.is_valid(), "合法角色 " + str(id))
		var expected: StringName = &"shu" if SHU.has(str(id)) else (&"wu" if str(id) == "huang_zhong" else (&"wei" if str(id) == "zhou_wei" else &"qun"))
		_check(character.faction == expected, "归属 " + str(id))
		counts[character.faction] += 1
		for tag in [&"shu", &"wei", &"wu", &"qun", &"han"]: _check(not character.tags.has(tag), "用途标签已迁出阵营 " + str(id) + " " + str(tag))
		_check(not character.tags.is_empty(), "保留用途标签 " + str(id))
		var baseline := character.compute_stats_at(40, 2)
		var alternate := character.duplicate(true) as CharacterData
		alternate.faction = &"wei"
		_check(alternate.compute_stats_at(40, 2) == baseline, "归属本身不改属性 " + str(id))
	_check(counts == {&"wei": 1, &"shu": 5, &"wu": 1, &"qun": 2}, "九将魏1蜀5吴1群2")
	for faction in FactionRegistry.IDS:
		_check(UITheme.hud_icon_sized(FactionRegistry.icon_key(faction), 22) != null, "四阵营图徽 " + str(faction))
		var image_path := "res://assets/ui/icons/v2/" + FactionRegistry.icon_key(faction) + ".png"
		var source := Image.load_from_file(image_path)
		var imported := (load(image_path) as Texture2D).get_image()
		_check(_same_visible_image(source, imported), "运行旗帜与PNG母版一致 " + str(faction))
		var badge := FactionUI.badge(faction)
		_check(badge.find_child("FactionName", true, false).text == FactionRegistry.display_name(faction), "阵营中文名称常显 " + str(faction))
		_check(badge.find_child("FactionFlag", true, false).texture != null, "旗帜与中文同源 " + str(faction))
		badge.free()
	var bonds := GameFlow.get_bond_progress(["liu_bei", "guan_yu", "zhang_fei"])
	_check(bonds.size() == 2 and is_equal_approx(GameFlow.get_squad_bond_damage_bonus(["liu_bei", "guan_yu", "zhang_fei"]), 0.05), "原两组羁绊保留")

func _test_rules() -> void:
	var shu := GameFlow.load_character_data("guan_yu")
	var qun := GameFlow.load_character_data("diao_chan")
	for stage in GameFlow.get_sorted_stages(GameFlow.get_chapter()):
		_check(stage.faction_rule.is_empty(), "第一章不限 " + str(stage.stage_id))
		for id in GameFlow.get_all_character_ids(): _check(stage.allows_character(GameFlow.load_character_data(str(id))), "本章可用 " + str(stage.stage_id) + " " + str(id))
	var stage := GameFlow.load_stage_data(&"ch01_s01").duplicate(true) as StageData
	stage.faction_rule = {"allow": ["shu"]}
	_check(stage.is_valid() and stage.allows_character(shu) and not stage.allows_character(qun), "限用阵营")
	_check(GameFlow.squad_allowed_for_stage(stage, ["guan_yu", "liu_bei"]) and not GameFlow.squad_allowed_for_stage(stage, ["guan_yu", "diao_chan"]), "整队判断")
	stage.faction_rule = {"deny": [&"shu"]}
	_check(stage.allows_character(qun) and not stage.allows_character(shu), "禁用阵营")
	stage.faction_rule = {"allow": ["shu", "qun"], "deny": ["shu"]}
	_check(not stage.allows_character(shu) and stage.allows_character(qun), "禁用优先")
	stage.faction_rule = {"allow": [], "deny": []}
	_check(stage.allows_character(shu) and stage.allows_character(qun), "空集合不限")
	for invalid in [{"allow": "shu"}, {"allow": [true]}, {"allow": ["han"]}, {"deny": null}, {"blocked": []}, {"deny": [1]}]:
		stage.faction_rule = invalid
		_check(not stage.is_valid() and not stage.allows_character(shu) and not GameFlow.squad_allowed_for_stage(stage, ["guan_yu"]), "无效规则拒绝 " + str(invalid))
	_check(not GameFlow.squad_allowed_for_stage(stage, []) and not GameFlow.squad_allowed_for_stage(null, ["guan_yu"]), "空队/空关卡拒绝")

func _test_items() -> void:
	var shu := GameFlow.load_character_data("guan_yu")
	var qun := shu.duplicate(true) as CharacterData
	qun.faction = &"qun"
	for id in WeaponRegistry.IDS: _check(WeaponRegistry.get_weapon(id).faction_limit.is_empty(), "原武器不限 " + id)
	for relic in GameFlow.get_optional_relics(): _check(relic.faction_limit.is_empty(), "原信物不限 " + str(relic.relic_id))
	for supply in BattleSupplyData.load_catalog(): _check(supply.faction_limit.is_empty(), "原军需不限 " + str(supply.supply_id))
	var weapon := WeaponRegistry.get_weapon("equipment_long_spear_1").duplicate(true) as WeaponData
	weapon.faction_limit = [&"qun"]
	_check(weapon.fits(qun) and not weapon.fits(shu), "武器阵营限制")
	_check(not weapon.fits(GameFlow.load_character_data("diao_chan")), "武器继续要求职业")
	_check(WeaponRegistry.bonuses(weapon, shu).is_empty() and not WeaponRegistry.bonuses(weapon, qun).is_empty(), "不匹配不计属性")
	var relic := GameFlow.load_relic_data("relic_taiping_yaoshu").duplicate(true) as RelicData
	relic.faction_limit = [&"qun"]
	_check(not relic.fits(shu) and relic.fits(qun), "信物阵营匹配")
	_check(shu.compute_stats_at(10, 0, relic) == shu.compute_stats_at(10, 0), "限定信物不能绕过计算")
	_check(qun.compute_stats_at(10, 0, relic) != qun.compute_stats_at(10, 0), "匹配信物仍生效")
	var supply := BattleSupplyData.load_catalog()[0].duplicate(true) as BattleSupplyData
	supply.faction_limit = [&"qun"]
	_check(supply.fits(qun) and not supply.fits(shu), "军需匹配接口")
	weapon.faction_limit = [&"wrong"]
	relic.faction_limit = [&"wrong"]
	supply.faction_limit = [&"wrong"]
	_check(not weapon.is_valid() and not relic.is_valid() and not supply.is_valid(), "无效物品限制拒绝")
	var p := PlayerProfile.from_dict({"characters": {"guan_yu": {}}, "weapons": {"equipment_long_spear_1": 1}, "relics": {"relic_taiping_yaoshu": true}})
	var live_weapon := WeaponRegistry.get_weapon("equipment_long_spear_1")
	var live_relic := GameFlow.load_relic_data("relic_taiping_yaoshu")
	var original_weapon := live_weapon.faction_limit.duplicate()
	var original_relic := live_relic.faction_limit.duplicate()
	live_weapon.faction_limit = [&"qun"]
	live_relic.faction_limit = [&"qun"]
	var before := p.to_dict()
	_check(not p.set_character_weapon("guan_yu", "equipment_long_spear_1") and p.to_dict() == before, "不能绕过武器装配且不改档")
	p.add_relic("relic_taiping_yaoshu")
	before = p.to_dict()
	_check(not p.set_character_relic("guan_yu", "relic_taiping_yaoshu") and p.to_dict() == before, "不能绕过信物装配且不改档")
	live_weapon.faction_limit.assign(original_weapon)
	live_relic.faction_limit.assign(original_relic)

func _test_legacy() -> void:
	var p := PlayerProfile.from_dict({"schema_version": 11, "characters": {"guan_yu": {"total_exp": LevelCurve.exp_total_for_level(100), "rank": 2, "talent_alloc": {"physical_burst.slash": 2}, "skill_levels": {"dragon_sweep": 3}}}, "squad_character_ids": ["guan_yu"]})
	var raw := p.to_dict()
	_check(PlayerProfile.CURRENT_SCHEMA_VERSION == 11 and raw.schema_version == 11, "schema11保持")
	_check(not raw.characters.guan_yu.has("faction") and p.get_talent_alloc("guan_yu").get("physical_burst.slash") == 2, "阵营不写进度且天赋保留")
	_check(PlayerProfile.from_dict(raw).to_dict() == raw, "旧档幂等")

func _test_encyclopedia() -> void:
	var p := ProfileStore.get_profile()
	var before := p.to_dict()
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._show_panel(&"encyclopedia")
	var enc = hub._panels[&"encyclopedia"]
	_check(enc._character_buttons.size() == 9 and enc._faction_buttons.size() == 5, "全量九将与五筛选")
	enc._select_character("guan_yu")
	enc._sim_level = 35
	enc._on_sim_changed()
	enc._faction_buttons[&"shu"].pressed.emit()
	await get_tree().process_frame
	_check(enc._character_buttons.size() == 5 and enc._selected_character_id == "guan_yu" and enc._sim_level == 35, "蜀筛选保留选中与模拟")
	_check(enc._character_buttons.has("zhuge_liang") and not p.characters.has("zhuge_liang"), "未拥有武将可筛选")
	for id in enc._character_buttons: _check(GameFlow.load_character_data(id).faction == &"shu", "结果全属蜀 " + id)
	enc._faction_buttons[&"qun"].pressed.emit()
	await get_tree().process_frame
	_check(enc._character_buttons.size() == 2 and GameFlow.load_character_data(enc._selected_character_id).faction == &"qun" and enc._sim_level == 1, "群筛选切首名并清模拟")
	for faction in [&"wei", &"wu"]:
		enc._faction_buttons[faction].pressed.emit()
		await get_tree().process_frame
		_check(enc._character_buttons.size() == 1 and enc._sim_panel.visible and enc._talent_button != null, "魏吴新角色可查看 " + str(faction))
		_check(GameFlow.load_character_data(enc._selected_character_id).faction == faction, "筛选归属一致 " + str(faction))
	var originals: Array[String] = enc._character_ids.duplicate()
	enc._character_ids.erase("huang_zhong")
	enc._apply_faction_filter(&"wu")
	_check(enc._character_buttons.is_empty() and enc._selected_character_id.is_empty() and not enc._sim_panel.visible, "未来空阵营清详情")
	_check(enc._detail_box.find_child("FactionEmpty", true, false) != null and enc._talent_button == null, "空态无旧天赋入口")
	enc._open_talents()
	_check(enc._talent_panel == null, "空态不能打开旧武将天赋")
	enc._character_ids.assign(originals)
	enc._faction_buttons[&"qun"].pressed.emit()
	enc._switch_mode(&"enemy")
	_check(not enc._faction_row.visible and enc._enemy_buttons.size() == enc._enemy_ids.size(), "敌人列表独立")
	enc._switch_mode(&"character")
	_check(enc._faction_filter == &"qun" and enc._character_buttons.size() == 2, "返回保留筛选")
	enc._faction_buttons[&""].pressed.emit()
	_check(enc._character_buttons.size() == 9 and p.to_dict() == before, "恢复全部且筛选/模拟不写档")
	hub.queue_free()
	await get_tree().process_frame

func _test_squad() -> void:
	var p := ProfileStore.get_profile()
	p.ensure_character("diao_chan")
	GameFlow.select_stage(&"ch01_s01")
	GameFlow.set_squad(["guan_yu", "diao_chan"])
	GameFlow.save_squad_to_profile(p)
	ProfileStore.save_profile(p)
	var before := p.to_dict()
	var stage := GameFlow.load_stage_data(&"ch01_s01")
	var original := stage.faction_rule.duplicate(true)
	stage.faction_rule = {"allow": ["qun"]}
	var squad := (load("res://scenes/SquadSelect.tscn") as PackedScene).instantiate()
	add_child(squad)
	await get_tree().process_frame
	_check(squad._selected_ids == ["diao_chan"] and p.to_dict() == before, "限制关恢复记忆过滤，旧记忆保留")
	_check(squad._card_widgets.guan_yu.button.disabled and not squad._card_widgets.diao_chan.button.disabled, "不符合阵营禁选")
	squad._on_character_toggled(true, "guan_yu")
	_check(squad._selected_ids == ["diao_chan"], "点选限制门禁")
	squad._selected_ids.assign(["guan_yu"])
	squad._open_confirm_popup()
	_check(squad._confirm_popup == null, "非法编队不开确认")
	squad._on_confirm_deploy()
	_check(p.to_dict() == before, "非法确认不写档")
	GameFlow.set_squad(["guan_yu"])
	var current := get_tree().current_scene
	GameFlow.goto_battle()
	_check(get_tree().current_scene == current, "最终入场门禁")
	stage.faction_rule = original
	squad.queue_free()
	await get_tree().process_frame
	for invalid in [{"allow":42}, {"deny":null}, {"unknown":[]}, {"allow":["han"]}]:
		stage.faction_rule = invalid
		squad = (load("res://scenes/SquadSelect.tscn") as PackedScene).instantiate()
		add_child(squad)
		await get_tree().process_frame
		_check(squad.find_child("FactionRuleInvalid", true, false) != null and squad._selected_ids.is_empty(), "无效规则安全显示 " + str(invalid))
		for id in squad._card_widgets: _check(squad._card_widgets[id].button.disabled, "无效规则全部禁选 " + str(id))
		squad._open_confirm_popup()
		_check(squad._confirm_popup == null, "无效规则不能确认")
		squad.queue_free()
		await get_tree().process_frame
	stage.faction_rule = original
