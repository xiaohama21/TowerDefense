extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	print("PACKAGE_%s: %s" % ["PASS" if ok else "FAIL", message])
	failed = failed or not ok

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--release-extension=") and not ClassDB.class_exists("SpineSprite"):
			_check(GDExtensionManager.load_extension(arg.trim_prefix("--release-extension=")) == GDExtensionManager.LOAD_STATUS_OK, "load shipped Spine DLL")
	_check(ClassDB.class_exists("SpineSprite"), "Spine runtime")
	_check(ProjectSettings.get_setting("application/config/version") == "0.9.6.2", "project version 0.9.6.2")
	var flow = root.get_node("GameFlow")
	var store = root.get_node("ProfileStore")
	var registry = load("res://scripts/data/WeaponRegistry.gd")
	var skills = load("res://scripts/combat/SkillRegistry.gd")
	var shop = load("res://scripts/data/ShopRegistry.gd")
	store.configure_paths("user://.gear_export_%d.json" % Time.get_ticks_usec())
	_check(flow.start_new_game(), "isolated new profile")
	var profile = store.get_profile()
	_check(profile.to_dict().schema_version == 11, "schema v11")
	_check(profile.ingots == 0 and profile.lord_exp == 0 and profile.shop_state.rotation.size() == 2, "new profile economic defaults")
	_check(shop.all_offers().size() == 31 and shop.exp_for_level(100) == 27225 and shop.data().tier_levels == [1,10,20,40,60,80], "packaged catalog and lord curve")
	var migrated = store._migrate_to_current({"schema_version":9,"military_merit":321,"weapons":{"equipment_long_spear_1":1}})
	_check(migrated.ok and migrated.data.schema_version == 11 and migrated.data.ingots == 0 and migrated.data.lord_exp == 0 and migrated.data.military_merit == 321 and migrated.data.weapons.equipment_long_spear_1 == 1, "packaged v9 migration preserves existing economy and gear")
	_check(flow.get_all_character_ids().size() == 9, "nine three-skill characters retained")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/icons/v2/manifest.json"))
	var count := 0
	for entry in manifest.icons:
		if load("res://assets/ui/icons/v2/" + str(entry.png)) != null: count += 1
	_check(count == 395, "395 packaged icons including 110 talents")
	var factions = load("res://scripts/data/FactionRegistry.gd")
	var faction_counts := {"wei":0, "shu":0, "wu":0, "qun":0}
	var faction_ui = load("res://scripts/ui_screens/faction_ui.gd")
	for faction in factions.IDS:
		var badge = faction_ui.badge(faction)
		_check(badge.find_child("FactionName",true,false).text == factions.display_name(faction) and badge.find_child("FactionFlag",true,false).texture != null, "packaged faction flag and visible name " + str(faction))
		badge.free()
	for id in flow.get_all_character_ids():
		var hero = flow.load_character_data(str(id))
		_check(factions.is_valid_id(hero.faction) and not hero.tags.has(&"shu") and not hero.tags.has(&"han"), "packaged faction resource " + str(id))
		faction_counts[str(hero.faction)] += 1
	_check(faction_counts == {"wei":1, "shu":5, "wu":1, "qun":2}, "packaged nine faction assignments")
	for entry in [["huang_zhong","孙尚香","鹊画弓",["弓腰姬","淬毒箭","枭姬奋威"]],["zhou_wei","典韦","双铁戟",["破阵双戟","古之恶来","宛城死战"]]]:
		var hero = flow.load_character_data(entry[0])
		_check(hero.display_name == entry[1], "packaged replacement identity " + str(entry[1]))
		var relic = flow.get_relic_for_character(entry[0])
		_check(relic != null and relic.display_name == entry[2] and relic.effect_lines().is_empty() and not relic.is_optional_slot(), "packaged locked relic " + str(entry[2]))
		var ids = hero.get_skill_ids()
		for index in range(ids.size()): _check(skills.get_skill_name(ids[index]) == entry[3][index], "packaged replacement skill " + str(entry[3][index]))
	for stage in flow.get_sorted_stages(flow.get_chapter()):
		_check(stage.faction_rule.is_empty() and stage.allows_character(flow.load_character_data("guan_yu")), "packaged unrestricted chapter " + str(stage.stage_id))
	var rule_stage = flow.load_stage_data(&"ch01_s01").duplicate(true)
	rule_stage.faction_rule = {"allow":["shu","qun"],"deny":["shu"]}
	_check(not flow.squad_allowed_for_stage(rule_stage,["guan_yu"]) and flow.squad_allowed_for_stage(rule_stage,["diao_chan"]), "packaged stage faction intersection")

	var talents = load("res://scripts/data/TalentRegistry.gd")
	_check(talents.IDS.size() == 11, "11 packaged talent trees")
	var talent_nodes := 0
	for tree_id in talents.IDS:
		var tree = talents.get_tree_data(tree_id)
		_check(tree != null and tree.nodes.size() == 10, "packaged talent tree " + str(tree_id))
		for node in tree.nodes:
			talent_nodes += 1
			_check(load("res://assets/ui/icons/v2/" + str(node.get("icon_key", "")) + ".png") != null, "packaged dedicated talent icon " + str(node.id))
			_check(not str(node.name).is_empty() and not str(node.description).is_empty() and not node.effects.is_empty(), "packaged talent node " + str(node.id))
	_check(talent_nodes == 110, "110 packaged talent nodes")
	var theme = load("res://scripts/ui_screens/ui_theme.gd")
	var dian = flow.load_character_data("zhou_wei")
	var execute: Dictionary = dian.skill_params.ultimate_death_fight
	_check(execute.mult == 4.0 and execute.target_hp_threshold == 0.5 and execute.execute_bonus_mult == 4.0 and not execute.has("base_hp_threshold") and not execute.has("low_hp_mult"), "packaged Dian Wei target-health execution parameters")
	var preview_text: String = skills.damage_preview(dian,&"ultimate_death_fight",2,0.0,{"damage":137})
	_check(preview_text.contains("合计1129点") and preview_text.contains("目标生命≤50%"), "packaged execution preview rounding and condition")
	var action := Button.new()
	theme.apply_kenney_round_button(action,"yellow",theme.INK)
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var round_style = action.get_theme_stylebox(state)
		_check(round_style is StyleBoxTexture and round_style.texture != null and round_style.texture_margin_left == 0 and round_style.texture_margin_top == 0, "packaged round action whole-image scaling " + state)
	action.free()
	var dialog := ConfirmationDialog.new()
	root.add_child(dialog)
	dialog.popup_centered(Vector2i(440,160))
	await process_frame
	await process_frame
	_check(dialog.get_label().get_theme_color("font_color") == theme.LIGHT_INK and dialog.ok_button_text == "确认" and dialog.cancel_button_text == "取消", "packaged confirmation readable Chinese actions")
	for button in [dialog.get_ok_button(),dialog.get_cancel_button()]:
		for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			_check(not button.get_theme_stylebox(state) is StyleBoxEmpty, "packaged dialog complete button state " + state)
	dialog.queue_free()
	for icon_id in ["ingot", "lord_level", "lord_exp", "equipment_rarity_0", "equipment_rarity_1", "equipment_rarity_2", "equipment_rarity_3", "equipment_rarity_4", "trait_vanguard", "ultimate_death_fight"]:
		_check(theme.hud_icon(icon_id) != null, "packaged economic/quality icon " + icon_id)
	_check(registry.IDS.size() == 12, "12 packaged weapons")
	for id in registry.IDS:
		var weapon = registry.get_weapon(id)
		_check(weapon != null and weapon.is_valid() and weapon.icon != null and weapon.affixes.size() == 2, "weapon resource " + str(id))
		profile.add_weapon(id, 3)
	profile.unlock_character("guan_yu")
	profile.unlock_character("zhuge_liang")
	for id in flow.get_all_character_ids(): profile.unlock_character(id)
	var hub = load("res://scenes/GameHub.tscn").instantiate()
	root.add_child(hub)
	await process_frame
	hub._show_panel(&"develop")
	var panel = hub._panels[&"develop"]
	panel._select_character("guan_yu")
	panel._refresh()
	_check(panel._tab_container.get_tab_count() == 4 and panel._weapon_tab.find_children("WeaponCard_*", "Button", true, false).size() == 2, "packaged equipment UI")
	_check(_items_readable(panel._weapon_tab), "packaged develop weapon names and brief descriptions")
	profile.add_character_exp("guan_yu", LevelCurve.exp_total_for_level(100))
	panel._on_shown()
	panel._select_character("guan_yu")
	panel._refresh()
	panel._talent_button.pressed.emit()
	_check(panel._talent_panel.node_buttons.size() == 30 and profile.talent_points_remaining("guan_yu") == 40, "packaged talent popup and 40 points")
	_check(panel._allocate_talent("physical_burst.slash", 0) and profile.get_talent_alloc("guan_yu").get("physical_burst.slash") == 1, "packaged talent allocation saves")
	panel._talent_panel.node_buttons["physical_burst.slash"].pressed.emit()
	_check(panel._talent_panel.detail_panel != null and panel._talent_panel.detail_action != null, "packaged node opens talent detail")
	panel._talent_panel.close_detail()
	var talent_snapshot = profile.get_talent_alloc("guan_yu")
	store._writes_blocked = true
	_check(not panel._allocate_talent("physical_burst.swift", 0) and profile.get_talent_alloc("guan_yu") == talent_snapshot, "packaged talent failed save rolls back")
	store._writes_blocked = false
	_check(panel._reset_talents("guan_yu", talent_snapshot) and profile.talent_points_remaining("guan_yu") == 40, "packaged free talent reset")

	panel._talent_panel.dismiss()
	_check(panel._equip_weapon("guan_yu", "equipment_long_spear_1") and profile.get_character_weapon_id("guan_yu") == "equipment_long_spear_1", "packaged equip and save")
	_check(not profile.set_character_weapon("zhuge_liang", "equipment_long_spear_1"), "packaged profession restriction")
	hub._show_panel(&"encyclopedia")
	var enc = hub._panels[&"encyclopedia"]
	enc._select_character("zhuge_liang")
	var snapshot = profile.to_dict()
	enc._sim_weapon_id = "equipment_bamboo_banner_1"
	enc._on_sim_changed()
	await process_frame
	_check(profile.to_dict() == snapshot and enc._weapon_tab.find_children("WeaponCard_*", "Button", true, false).size() == 2, "packaged read-only weapon preview")
	enc._sim_level = 100
	enc._on_sim_changed()
	enc._talent_button.pressed.emit()
	var talent_sim_snapshot = profile.to_dict()
	enc._allocate_sim_talent("magic_area.focus", 0)
	_check(enc._sim_talent_alloc.get("magic_area.focus") == 1 and profile.to_dict() == talent_sim_snapshot, "packaged talent simulation read-only")

	enc._talent_panel.dismiss()
	enc._faction_buttons[&"shu"].pressed.emit()
	_check(enc._character_buttons.size() == 5, "packaged shu filter")
	enc._faction_buttons[&"qun"].pressed.emit()
	_check(enc._character_buttons.size() == 2, "packaged qun filter")
	for faction in [&"wei", &"wu"]:
		enc._faction_buttons[faction].pressed.emit()
		_check(enc._character_buttons.size() == 1 and enc._talent_button != null and enc._sim_panel.visible, "packaged faction replacement " + str(faction))
	enc._faction_buttons[&""].pressed.emit()
	enc._select_character("zhuge_liang")
	_check(enc._character_buttons.size() == 9 and profile.to_dict() == talent_sim_snapshot, "packaged restore faction filter without saves")
	_check(_items_readable(enc._weapon_tab), "packaged encyclopedia weapon names and brief descriptions")
	var skill_margin = panel._skill_tab.find_child("SkillContentMargin", true, false)
	_check(skill_margin != null and skill_margin.get_theme_constant("margin_left") == 16 and skill_margin.get_theme_constant("margin_top") == 14 and skill_margin.get_child(0).get_theme_constant("separation") == 12, "packaged develop skill page spacing")
	_check(enc._skill_tab.get_parent().get_theme_constant("margin_left") == 16 and enc._skill_tab.get_parent().get_theme_constant("margin_top") == 14 and enc._skill_tab.get_theme_constant("separation") == 12, "packaged encyclopedia skill page spacing")
	for id in flow.get_all_character_ids():
		panel._select_character(id)
		panel._refresh()
		_check_skill_cards(panel, flow.load_character_data(id), skills, "develop")
	var skill_snapshot = profile.to_dict()
	for id in flow.get_all_character_ids():
		enc._select_character(id)
		enc._sim_rank_option.select(5)
		enc._on_sim_changed()
		_check_skill_cards(enc, flow.load_character_data(id), skills, "encyclopedia")
	_check(profile.to_dict() == skill_snapshot, "skill encyclopedia leaves profile unchanged")
	profile.ingots = 500
	profile.military_merit = 500
	_check(store.save_profile(profile), "packaged shop fixture saved")
	hub._show_panel(&"shop")
	var shop_panel = hub._panels[&"shop"]
	await process_frame
	_check(hub._buttons.size() == 8 and shop_panel.find_child("LordLevel",true,false).text == "Lv.1" and shop_panel.find_children("ShopOffer_*","PanelContainer",true,false).size() == 21, "packaged shop navigation and initial shelves")
	var economic_snapshot = profile.to_dict()
	store._writes_blocked = true
	_check(not store.buy_shop_offer("iron_1",int(profile.shop_state.revision)) and not store.refresh_shop(int(profile.shop_state.revision)) and profile.to_dict() == economic_snapshot, "packaged failed saves roll back purchase and refresh")
	store._writes_blocked = false
	var iron_before: int = int(profile.items.get("refined_iron",0))
	shop_panel.find_child("ShopOffer_iron_1",true,false).find_child("BuyOffer",true,false).pressed.emit()
	_check(profile.ingots == 492 and int(profile.items.refined_iron) == iron_before + 1 and shop_panel.find_child("IngotBalance",true,false).text == "492", "packaged material purchase button and balance")
	economic_snapshot = profile.to_dict()
	_check(not store.buy_shop_offer("iron_1",0) and profile.to_dict() == economic_snapshot, "packaged stale click rejected")
	shop_panel.find_child("RefreshShop",true,false).pressed.emit()
	_check(profile.ingots == 482 and profile.shop_state.refresh_step == 1 and shop.refresh_price(profile) == 20 and profile.shop_state.rotation.size() == 2, "packaged refresh button and next price")
	economic_snapshot = profile.to_dict()
	shop_panel._switch_page(1)
	_check(profile.to_dict() == economic_snapshot, "packaged page switching keeps rotation")
	shop_panel.find_child("ShopOffer_merit_iron_shield",true,false).find_child("BuyOffer",true,false).pressed.emit()
	_check(profile.military_merit == 260 and profile.ingots == 482 and int(profile.items.iron_shield) == 1, "packaged merit purchase uses separate currency")
	economic_snapshot = profile.to_dict()
	_check(not store.buy_shop_offer("merit_iron_shield",int(profile.shop_state.revision)) and profile.to_dict() == economic_snapshot, "packaged relic permanent limit")
	profile.mark_stage_completed("ch01_s01",{"difficulty":"normal"})
	economic_snapshot = profile.to_dict()
	_check(not store.buy_shop_offer("equipment_ring_blade_1",int(profile.shop_state.revision)) and profile.to_dict() == economic_snapshot, "packaged full equipment rejects deduction")
	profile.weapons.equipment_ring_blade_1 = 2
	_check(store.buy_shop_offer("equipment_ring_blade_1",int(profile.shop_state.revision)) and profile.weapon_count("equipment_ring_blade_1") == 3 and profile.ingots == 362, "packaged equipment purchase")
	hub._show_panel(&"inventory")
	var inventory = hub._panels[&"inventory"]
	inventory._show_detail("iron_shield")
	_check(inventory.find_child("ShopAcquisition",true,false).text.contains("兑换"), "packaged inventory shop source")
	profile.lord_exp = 440
	flow.selected_difficulty = 0
	_check(not ResourceLoader.exists("res://tests/GearRunner.tscn") and not FileAccess.file_exists("res://AGENTS.md"), "development files excluded")
	var session = load("res://scripts/services/BattleSession.gd").new("ch01_s08")
	flow.collect_stage_rewards(session, flow.load_stage_data(&"ch01_s08"), true)
	_check(session.pending_weapons.size() == 3, "packaged first clear three weapons")
	_check(session.get_pending_ingots() == 30 and session.get_pending_lord_exp() == 80, "packaged first-clear economic rewards")
	var seals: int = int(profile.items.get("general_seal", 0))
	var material_seals: int = int(session.pending_loot.get("general_seal", 0))
	session.mark_victory()
	_check(store.commit_victory(session) and int(profile.items.get("general_seal", 0)) == seals + material_seals + 6, "packaged overflow three weapons to six seals")
	_check(profile.ingots == 392 and profile.lord_exp == 520 and shop.lord_progress(profile.lord_exp).level == 10 and profile.shop_state.refresh_step == 0 and profile.shop_state.rotation.size() == 3 and (profile.shop_state.rotation.has("rot_book_2") or profile.shop_state.rotation.has("rot_seal_3")), "packaged victory level-up and new-tier guaranteed rotation")
	economic_snapshot = profile.to_dict()
	_check(store.commit_victory(session) and profile.to_dict() == economic_snapshot, "packaged duplicate victory keeps economy and rotation")
	hub._show_panel(&"map")
	var map = hub._panels[&"map"]
	map._select_stage(flow.load_stage_data(&"ch01_s01"))
	map._on_difficulty_changed(true,1)
	var detail_economy = map._detail_rewards.get_child(0)
	_check(detail_economy.get_child(0).get_child(1).text == "+20" and detail_economy.get_child(1).get_child(1).text == "+38", "packaged map hard repeat economy preview")
	hub.queue_free()
	await process_frame
	flow.selected_stage_id = &"ch01_s01"
	flow.selected_difficulty = 0
	var squad: Array[String] = ["liu_bei", "guan_yu"]
	flow.squad_character_ids = squad
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.ui.skip_dialogue()
	var character = flow.load_character_data("guan_yu")
	var tower = main.tower_manager.build_tower(Vector2(240, 200), character, null, flow.get_battle_loadout(profile, "guan_yu"))
	var character_level: int = flow.get_character_level(profile, "guan_yu")
	var growth: float = 1.0 + character.attack_pct * (character_level - 1)
	_check(tower != null and tower.damage == int(round((character.base_damage + 6) * growth)) and absf(tower.crit_rate - 0.09) < 0.001, "packaged battle uses weapon attack and crit")
	_check(profile.allocate_talent("guan_yu", "physical_burst.slash", 0) and store.save_profile(profile), "packaged battle talent fixture saved")
	tower.apply_character(character, flow.get_battle_loadout(profile, "guan_yu"))
	_check(tower.damage == int(round((character.base_damage + 6) * growth * 1.006)) and absf(tower.talent_bonuses.attack_pct - 0.006) < 0.00001, "packaged battle applies talent loadout")
	main._try_start_wave()
	await create_timer(2.0).timeout
	_check(root.get_node("GameManager").is_wave_active and main.enemy_manager.get_alive_enemies().size() > 0, "first wave starts")
	var ingots_before: int = profile.ingots
	var exp_before: int = profile.lord_exp
	main._on_victory()
	_check(profile.ingots == ingots_before + 10 and profile.lord_exp == exp_before + 25 and main.ui._result_reward_icons.get_child(0).get_child(1).text == "×10" and main.ui._result_reward_icons.get_child(1).get_child(1).text == "×25" and main.ui._result_lines_label.text.contains("升级！"), "packaged battle victory saves economy and displays level-up")
	main.ui.show_result({"victory":true,"saved":false,"economy":{"ingots":30,"lord_exp":80},"lord_before":1,"lord_after":2})
	_check(main.ui._result_reward_icons.get_child_count() == 0 and not main.ui._result_lines_label.text.contains("升级！"), "packaged failed settlement hides economic rewards and level-up")
	paused = false
	main.queue_free()
	await process_frame
	print("PACKAGE_VERIFY_" + ("FAIL" if failed else "OK"))
	quit(1 if failed else 0)

func _check_skill_cards(panel, character, skills, context: String) -> void:
	for id in character.get_skill_ids():
		var card = panel._skill_tab.find_child("SkillCard_" + str(id), true, false)
		var title = card.find_child("SkillName", true, false) if card != null else null
		var description = card.find_child("SkillDescription", true, false) if card != null else null
		var readable: bool = title != null and description != null and title.text == skills.get_skill_name(id) and description.text == skills.description_text(id) and not description.text.is_empty()
		var labels: Array[String] = []
		if card != null:
			var main_icon = card.get_child(0).get_child(0).get_child(0)
			readable = readable and main_icon is TextureRect and main_icon.texture != null and main_icon.tooltip_text == skills.get_skill_name(id)
			for label in card.find_children("*", "Label", true, false): labels.append(label.text)
		for row in skills.effect_rows(character, id, 1, 0.0):
			for entry in row:
				readable = readable and entry.size() == 5 and labels.has(str(entry[3]))
		var trigger = card.find_child("SkillTrigger",true,false) if card != null else null
		var table = card.find_child("EffectBreakdown",true,false) if card != null else null
		readable = readable and trigger != null and trigger.text == "触发条件：" + skills.trigger_text(id) and table != null and table.columns == 5
		_check(readable, "%s skill name, description and effect labels: %s" % [context, id])

func _items_readable(container) -> bool:
	var cards = container.find_children("WeaponCard_*", "Button", true, false)
	if cards.is_empty(): return false
	for card in cards:
		var title = card.find_child("ItemName", true, false)
		var description = card.find_child("ItemDescription", true, false)
		if title == null or description == null or title.text.is_empty() or description.text.is_empty(): return false
	return true
