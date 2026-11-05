extends Node

var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []
var button_audit: Array[Dictionary] = []
var _capture_dir := ""
var _slot := ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): _capture_dir = arg.trim_prefix("--capture-dir=")
	_slot = "user://.polish_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_slot)
	get_viewport().gui_embed_subwindows = true
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error("POLISH: " + message)

func _settle() -> void:
	for frame in range(4): await get_tree().process_frame

func _shot(name: String) -> void:
	if _capture_dir.is_empty(): return
	Input.warp_mouse(Vector2(1275, 5))
	await get_tree().create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	_check(get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(name + ".png")) == OK, "原生截图 " + name)
	captures.append(name)

func _buttons(node: Node, label: String) -> void:
	var list := node.find_children("*", "Button", true, false)
	if node is Button: list.append(node)
	for entry in list:
		var button: Button = entry
		var role := str(button.get_meta("ui_button_role", ""))
		_check(not role.is_empty(), label + " 皮肤登记 " + str(button.get_path()))
		var normal := button.get_theme_stylebox("normal")
		if role == "round_action": _check(absf(button.size.x-button.size.y) < 1.0,"圆形动作不被容器拉伸 " + label)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var style := button.get_theme_stylebox(state)
			_check(style != null and not style is StyleBoxEmpty, label + " 完整按钮状态 " + str(button.name) + " " + state)
			if state != "focus" and normal is StyleBoxTexture:
				_check(style is StyleBoxTexture and style.texture != null and style.texture.resource_path.begins_with("res://assets/ui/buttons/"), label + " 同源Kenney素材 " + str(button.name))
				if role == "round_action": _check(style.texture_margin_left == 0 and style.texture_margin_top == 0 and style.texture_margin_right == 0 and style.texture_margin_bottom == 0, label + " 圆盘整图缩放")
		var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
		_check(focus != null and focus.border_color.a > 0.0 and focus.border_width_left > 0, label + " 可见键盘焦点 " + str(button.name))
		button_audit.append({"screen":label,"path":str(button.get_path()),"role":role,"disabled":button.disabled,"text":button.text})

func _action(node: Node, text: String) -> Button:
	for button in node.find_children("*", "Button", true, false):
		if button.text == text and not button.is_queued_for_deletion(): return button
	return null

func _battle_buttons(battle: Node) -> void:
	var ui = battle.ui
	_check(ui._dialogue_text_label.get_theme_color("font_color") == UITheme.LIGHT_INK, "浅底对白深墨色")
	await _shot("battle_dialogue")
	ui.skip_dialogue()
	GameManager.gold = 10000
	GameFlow.set_gameplay_flag("manual_ultimate",true)
	var tower: Tower = battle.tower_manager.build_tower(Vector2(320,288), GameFlow.load_character_data("guan_yu"), null, GameFlow.get_battle_loadout(ProfileStore.get_profile(),"guan_yu"))
	_check(tower != null, "建塔供动作验收")
	tower.set_selected(true)
	await _settle()
	_buttons(ui,"battle_tower")
	await _shot("battle_tower_buttons")
	_check(_action(ui._tower_bar,"大招\nR") != null, "手动大招按钮可见")
	var upgrade := _action(ui._tower_bar,"升阶")
	_check(upgrade != null and not upgrade.disabled, "升阶按钮可用")
	upgrade.pressed.emit()
	await _settle()
	_check(tower.battle_rank == 1, "点击升阶实际提升一阶")
	while tower.battle_rank < battle.stage_data.max_inbattle_upgrade_level:
		_action(ui._tower_bar,"升阶").pressed.emit()
		await _settle()
	_check(_action(ui._tower_bar,"升阶").disabled, "满阶按钮禁用")
	_buttons(ui,"battle_tower_max")
	await _shot("battle_tower_max_buttons")
	_action(ui._tower_bar,"回收").pressed.emit()
	await _settle()
	_check(not is_instance_valid(tower) and not ui._tower_bar.visible, "回收释放塔并收起详情")
	GameFlow.set_gameplay_flag("manual_ultimate",false)
	ui.open_menu()
	await _settle()
	_check(ui.menu_button.get_popup().visible and ui.menu_button.get_popup().get_theme_color("font_hover_color") == UITheme.LIGHT_INK, "亮色战斗菜单")
	await _shot("battle_menu_buttons")
	ui.menu_button.get_popup().hide()
	battle._on_battle_supply_pressed()
	await _settle()
	_buttons(battle._battle_supply_popup,"battle_supply")
	await _shot("battle_supply_buttons")
	battle._battle_supply_popup.find_child("SupplyCloseButton",true,false).pressed.emit()
	await _settle()
	_check(not is_instance_valid(battle._battle_supply_popup), "军需关闭按钮")
	ui.show_result({"victory":true,"saved":true,"remaining_gold":200,"next_stage_name":"下一战"})
	await _settle()
	_buttons(ui._result_panel,"victory")
	await _shot("victory_buttons")
	ui.show_result_wheel_result("已领取奖励")
	_check(ui._result_wheel_button.disabled, "转盘领取后按钮禁用")
	await _shot("victory_claimed_buttons")
	ui.show_result({"victory":false})
	await _settle()
	_buttons(ui._result_panel,"defeat")
	await _shot("defeat_buttons")

func _test_combat() -> void:
	var path := Path2D.new()
	path.curve = Curve2D.new()
	path.curve.add_point(Vector2.ZERO)
	path.curve.add_point(Vector2(1000,0))
	add_child(path)
	var hero := GameFlow.load_character_data("zhou_wei")
	_check(not hero.skill_params.ultimate_death_fight.has("base_hp_threshold") and not hero.skill_params.ultimate_death_fight.has("low_hp_mult"), "取消基地生命参数")
	var prior_lives := GameManager.lives
	var prior_start := GameManager.starting_lives
	GameManager.starting_lives = 20
	for entry in [[51000,1,0.0,100,400],[50000,1,0.0,100,800],[49000,1,0.0,100,800],[50000,2,0.0,137,1129],[50000,10,0.2,100,1219]]:
		for lives in [20,10,1]:
			GameManager.lives = lives
			var tower := (load("res://scenes/Tower.tscn") as PackedScene).instantiate() as Tower
			add_child(tower)
			tower.apply_character(hero,{"level":1,"rank":2,"skill_levels":{"ultimate_death_fight":entry[1]}})
			tower.set_process(false)
			tower.global_position = Vector2(300,300)
			tower.damage = entry[3]
			tower.skill_amp = entry[2]
			tower.crit_rate = 0.0
			var enemy := (load("res://scenes/Enemy.tscn") as PackedScene).instantiate() as Enemy
			enemy.max_hp = 100000
			enemy.armor = 0
			enemy.speed = 0
			enemy.reward = 0
			path.add_child(enemy)
			enemy.set_process(false)
			enemy.global_position = Vector2(360,300)
			enemy.current_hp = entry[0]
			tower.target = enemy
			tower.rage = 100
			var hp := enemy.current_hp
			_check(tower._try_cast_ultimate(), "典韦大招实际释放")
			_check(hp - enemy.current_hp == entry[4], "斩杀/成长/取整伤害 " + str(entry) + " 基地" + str(lives))
			_check(tower.rage < 100 and GameManager.lives == lives, "耗怒且不扣基地生命")
			if int(entry[0]) <= 50000:
				var preview := SkillRegistry.damage_preview(hero,&"ultimate_death_fight",entry[1],entry[2],{"damage":entry[3]})
				_check(preview.contains("合计%d点" % entry[4]), "斩杀预览与真实伤害一致")
			tower.queue_free(); enemy.queue_free()
			await _settle()
	GameManager.lives = prior_lives
	GameManager.starting_lives = prior_start
	path.queue_free()

func _test_numbers() -> void:
	for id in GameFlow.get_all_character_ids():
		var hero := GameFlow.load_character_data(id)
		for skill in hero.get_skill_ids():
			_check(not SkillRegistry.trigger_text(skill).is_empty(), "27技能触发说明 " + str(skill))
			for item in SkillRegistry.effect_breakdown(hero,skill,10,0.2):
				_check(is_equal_approx(item.base + item.level_bonus + item.amp_bonus,item.current), "基础与增量合计 " + str(skill) + " " + item.key)
	var sun := GameFlow.load_character_data("huang_zhong")
	_check(is_equal_approx(SkillRegistry.effect_value(sun,&"passive_sentry","poison_dps",10,2.0),25.4), "毒秒伤按等级锁定且不受增幅影响")
	_check(is_equal_approx(SkillRegistry.effect_value(sun,&"passive_sentry","duration",10,0.2),3.6), "时长只受增幅不受等级")
	var dian := GameFlow.load_character_data("zhou_wei")
	_check(is_equal_approx(SkillRegistry.effect_value(dian,&"char_death_fight","chance",10,5.0),0.254), "概率只按等级增长")
	_check(SkillRegistry.effect_value(dian,&"ultimate_death_fight","target_hp_threshold",10,5.0) == 0.5, "半血阈值不成长")
	var flame := GameFlow.load_character_data("huang_fu_song")
	_check(SkillRegistry.effect_value(flame,&"char_burn_camp","burn_ratio",10,5.0) == float(flame.skill_params.char_burn_camp.burn_ratio), "固定灼烧倍率不成长")

func _run() -> void:
	var p := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(p)
	for id in GameFlow.get_all_character_ids():
		p.unlock_character(id)
		p.characters[id].total_exp = LevelCurve.exp_total_for_level(100)
		p.characters[id].rank = 5
		for skill in GameFlow.load_character_data(id).get_skill_ids(): p.characters[id].skill_levels[str(skill)] = 4
	p.add_item("skill_book",100)
	ProfileStore.save_profile(p)
	await _test_combat()
	_test_numbers()
	var main := (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	add_child(main)
	await _settle()
	_buttons(main,"main_menu")
	await _shot("main_menu_buttons")
	main.queue_free(); await _settle()
	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await _settle()
	for panel in [&"map",&"develop",&"tech",&"supply",&"shop",&"inventory",&"settings",&"encyclopedia"]:
		hub._show_panel(panel)
		await _settle()
		_buttons(hub,"hub_"+str(panel))
		await _shot("buttons_"+str(panel))
	hub._show_panel(&"develop")
	var develop = hub._panels[&"develop"]
	for id in GameFlow.get_all_character_ids():
		develop._select_character(id)
		develop._refresh()
		develop._tab_container.current_tab = 0
		await _settle()
		var cards: Array = develop._skill_tab.find_children("SkillCard_*","PanelContainer",true,false)
		_check(cards.size() == 3, "三技能卡 " + id)
		for card in cards:
			_check(card.find_child("SkillTrigger",true,false) != null and card.find_child("EffectBreakdown",true,false) != null, "触发与数值分区")
			for label in card.find_children("*","Label",true,false):
				_check(card.get_global_rect().grow(1).encloses(label.get_global_rect()), "技能文字完整卡内 " + id + " " + str(label.name))
		await _shot(id + "_skills")
		var scroll: ScrollContainer = develop._skill_tab.get_child(0)
		scroll.scroll_vertical = 100000
		await _settle()
		await _shot(id + "_ultimate")
		if id == "zhou_wei":
			scroll.scroll_vertical += int(cards[2].get_global_rect().position.y - scroll.get_global_rect().position.y) - 12
			await _settle()
			await _shot("zhou_wei_ultimate_top")
		_buttons(develop,"skills_"+id)
	develop._select_character("guan_yu")
	develop._refresh()
	await _settle()
	var old_level := ProfileStore.get_profile().get_skill_level("guan_yu", &"passive_green_dragon_stance")
	develop._skill_tab.find_child("UpgradeSkill",true,false).pressed.emit()
	await _settle()
	_check(ProfileStore.get_profile().get_skill_level("guan_yu", &"passive_green_dragon_stance") == old_level + 1, "升级按钮实际保存技能等级")
	develop._talent_button.pressed.emit()
	await _settle()
	_buttons(develop._talent_panel,"talent_tree")
	await _shot("talent_buttons")
	develop._talent_panel.node_buttons["physical_burst.slash"].pressed.emit()
	await _settle()
	_buttons(develop._talent_panel,"talent_detail")
	await _shot("talent_detail_buttons")
	develop._talent_panel.close_detail()
	develop._talent_panel.dismiss()
	await _settle()
	var before := ProfileStore.get_profile().to_dict()
	hub._show_panel(&"encyclopedia")
	var enc = hub._panels[&"encyclopedia"]
	enc._select_character("zhou_wei")
	enc._sim_level = 100
	enc._sim_rank_option.select(5)
	enc._sim_battle_rank = 3
	enc._on_sim_changed()
	enc._tab_container.current_tab = 1
	await _settle()
	await _shot("encyclopedia_skill_numbers")
	_check(ProfileStore.get_profile().to_dict() == before,"百科模拟不写档")
	var shop_profile := ProfileStore.get_profile()
	shop_profile.ingots = 500
	shop_profile.military_merit = 500
	ProfileStore.save_profile(shop_profile)
	hub._show_panel(&"shop")
	await _settle()
	var shop = hub._panels[&"shop"]
	var buy: Button = shop.find_child("ShopOffer_iron_1",true,false).find_child("BuyOffer",true,false)
	_check(not buy.disabled, "余额足够时购买可用")
	_buttons(shop,"shop_available")
	await _shot("shop_available_buttons")
	var iron_before: int = shop_profile.items.get("refined_iron",0)
	buy.pressed.emit()
	await _settle()
	_check(ProfileStore.get_profile().ingots == 492 and ProfileStore.get_profile().items.refined_iron == iron_before+1, "购买按钮实际扣款并发货")
	shop._switch_page(1)
	await _settle()
	_buttons(shop,"shop_exchange")
	await _shot("shop_exchange_buttons")
	var dialog := ConfirmationDialog.new()
	dialog.title = "统一确认按钮"
	dialog.dialog_text = "确认与取消均使用统一皮肤。"
	add_child(dialog)
	dialog.popup_centered(Vector2i(440,160))
	await _settle()
	_buttons(dialog,"confirmation")
	_check(dialog.get_label().get_theme_color("font_color") == UITheme.LIGHT_INK and dialog.ok_button_text == "确认" and dialog.cancel_button_text == "取消", "确认框可读中文动作")
	await _shot("confirmation_buttons")
	var signals := {"confirmed":0,"canceled":0}
	dialog.confirmed.connect(func() -> void: signals.confirmed += 1)
	dialog.canceled.connect(func() -> void: signals.canceled += 1)
	dialog.get_cancel_button().pressed.emit()
	await _settle()
	_check(signals.canceled == 1 and signals.confirmed == 0 and not dialog.visible, "取消动作只取消 " + str(signals))
	dialog.popup_centered(Vector2i(440,160))
	dialog.get_ok_button().pressed.emit()
	_check(signals.confirmed == 1 and signals.canceled == 1 and not dialog.visible, "确认动作只确认")
	dialog.queue_free(); hub.queue_free(); await _settle()
	GameFlow.select_stage(&"ch01_s01")
	GameFlow.set_squad(["liu_bei","guan_yu","diao_chan"])
	var squad := (load("res://scenes/SquadSelect.tscn") as PackedScene).instantiate()
	add_child(squad); await _settle()
	_buttons(squad,"squad")
	await _shot("squad_buttons")
	squad._open_confirm_popup(); await _settle()
	_buttons(squad,"squad_confirm")
	await _shot("squad_confirm_buttons")
	squad.queue_free(); await _settle()
	var battle := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(battle); await _settle()
	_buttons(battle,"battle")
	await _shot("battle_buttons")
	await _battle_buttons(battle)
	battle.queue_free(); await _settle()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_slot+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot+suffix))
	if not _capture_dir.is_empty():
		var report := FileAccess.open(_capture_dir.path_join("polish_preview.json"),FileAccess.WRITE)
		report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"buttons":button_audit},"  "))
	print("POLISH_RESULT: %s checks=%d failures=%d buttons=%d captures=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size(),button_audit.size(),captures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
