extends Node

## 0.8.17.4 / B-071、B-072、B-074：空带、购买/使用、回血上限与结算只读。
var failures: Array[String] = []
var _profile_path := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_profile_path = "user://.supply_state_%d.json" % Time.get_ticks_usec()
	ProfileStore.configure_paths(_profile_path)
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("SUPPLY_STATE: " + message)

func _run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(profile)
	profile.add_military_merit(2000)
	profile.unlock_supply("stone_volley", 340)
	profile.unlock_supply("reward_army", 425)
	profile.upgrade_supply("repair")
	profile.upgrade_supply("repair")
	profile.set_supply_loadout([], 2)
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.ui.skip_dialogue()
	main._on_battle_supply_pressed()
	await get_tree().process_frame
	_check(main._supply_list_ids().is_empty(), "全解锁空带应显示空列表")
	_check(main._battle_supply_popup.find_child("SupplyEmptyState", true, false) != null, "空带必须显示选带引导")
	var action := main._supply_detail_nodes["button"] as Button
	_check(action.disabled and action.text == "未选带", "空带操作按钮必须有禁用文案")
	_check(not main._supply_detail_nodes["fx_row"].visible, "空态不得显示效果残留")

	main._close_battle_supply_popup()
	await get_tree().process_frame
	profile.set_supply_loadout(["repair", "war_drum"], 2)
	main._load_battle_supplies()
	main._on_battle_supply_pressed()
	await get_tree().process_frame
	var repair := main._find_battle_supply("repair") as BattleSupplyData
	GameManager.gold = 1000
	var initial_lives: int = GameManager.starting_lives
	main._on_supply_card_pressed("repair")
	action = main._supply_detail_nodes["button"] as Button
	_check(action.disabled, "满血修整不可购买")
	main._buy_battle_supply(repair)
	_check(GameManager.gold == 1000 and not main._is_supply_purchased("repair"), "满血购买不得扣金或入带")
	GameManager.lives = initial_lives - 1
	main._buy_battle_supply(repair)
	_check(main._supply_uses_left("repair") == 2, "L3 修整购买应入带两次")
	main._use_battle_supply("repair")
	_check(GameManager.lives == initial_lives, "只缺一点时修整必须夹到本局上限")
	_check(main._supply_uses_left("repair") == 1, "有效使用消耗一次")
	_check((main._supply_slot_nodes[0].get_meta("supply_slot_button") as Button).disabled, "满血带内修整按钮必须禁用")
	main._use_battle_supply("repair")
	_check(GameManager.lives == initial_lives and main._supply_uses_left("repair") == 1, "满血使用不得消耗次数")
	GameManager.starting_lives = initial_lives + 7
	GameManager.lives = initial_lives + 6
	main._apply_battle_supply(repair, 3)
	_check(GameManager.lives == initial_lives + 7, "回血应使用含科技/遗物加成的本局上限")
	main._apply_battle_supply(repair, 3)
	_check(GameManager.lives == initial_lives + 7, "满血直接效果调用不得溢出")

	main._buy_battle_supply(main._find_battle_supply("war_drum"))
	main._on_supply_card_pressed("war_drum")
	var gold_before: int = GameManager.gold
	var uses_before: int = main._supply_uses_left("war_drum")
	GameManager.current_wave = GameManager.total_waves
	main._on_victory()
	_check((main._supply_detail_nodes["button"] as Button).disabled, "结算操作必须禁用")
	for nodes in main._supply_card_nodes.values():
		_check((nodes["button"] as Button).disabled, "结算列表卡必须禁用")
	for slot in main._supply_slot_nodes:
		_check((slot.get_meta("supply_slot_button") as Button).disabled, "结算带位必须禁用")
	main._on_supply_card_hover("repair")
	main._on_supply_card_pressed("repair")
	_check(main._supply_selected_id == "war_drum", "结算悬停/点击不得更改选择")
	main._buy_battle_supply(repair)
	main._use_battle_supply("war_drum")
	_check(GameManager.gold == gold_before and main._supply_uses_left("war_drum") == uses_before, "结算不得扣金或次数")
	GameManager.lives -= 1
	var lives_before: int = GameManager.lives
	main._apply_battle_supply(repair, 3)
	_check(GameManager.lives == lives_before, "结算直接效果入口也必须只读")
	main._close_battle_supply_popup()
	main.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	# 战败走独立结算入口，也必须同步禁用已打开的军需面板。
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.ui.skip_dialogue()
	GameManager.gold = 1000
	main._buy_battle_supply(main._find_battle_supply("war_drum"))
	main._on_battle_supply_pressed()
	main._on_supply_card_pressed("war_drum")
	gold_before = GameManager.gold
	uses_before = main._supply_uses_left("war_drum")
	GameManager.lives = 0
	main._on_game_over()
	_check((main._supply_detail_nodes["button"] as Button).disabled, "战败必须同步禁用详情操作")
	for nodes in main._supply_card_nodes.values():
		_check((nodes["button"] as Button).disabled, "战败必须同步禁用列表卡")
	for slot in main._supply_slot_nodes:
		_check((slot.get_meta("supply_slot_button") as Button).disabled, "战败必须同步禁用带位")
	main._on_supply_action_pressed()
	_check(GameManager.gold == gold_before and main._supply_uses_left("war_drum") == uses_before, "战败不得扣金或次数")
	main._close_battle_supply_popup()
	main.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = _profile_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("SUPPLY_STATE_%s failures=%d" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
