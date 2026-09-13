extends Node

## 回归：科技树 v0.20.15 重构交互回归（BUGS B-046，程序 0.8.10.29）——
## ①切换节点不黑闪：非选中节点必须保持 pressed/hover_pressed 覆盖（移除会回落主题深色，B-034 同款）；
## ②详情「解锁」按钮点击可解锁：_unlock_button.pressed 必须已连接 _on_unlock_pressed。

var failures: Array[String] = []
var _profile_file := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.tech_unlock_runner_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("TECH_UNLOCK: %s" % message)


func _run() -> void:
	var profile := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(profile)
	profile.tech_points = 20
	# 预解锁链根 mil_dmg_1，令 mil_dmg_2 处于「可解锁」态（前置满足 + 点数充足）。
	var root := TechTree.get_item("mil_dmg_1")
	if root != null:
		profile.unlock_tech(root.id, root.cost)
	ProfileStore.save_profile(profile)

	var hub := (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	hub._show_panel(&"tech")
	for i in range(4):
		await get_tree().process_frame

	var tech := hub.get_node_or_null("HubPanel/Columns/Content/TechPanel") as Control
	_check(tech != null, "TechPanel 应已实例化")
	var target := TechTree.get_item("mil_dmg_2")
	_check(target != null, "mil_dmg_2 应存在")
	if tech == null or target == null:
		_finish()
		return

	# ① 非选中节点 pressed/hover_pressed 覆盖保持（防黑闪）。
	var idle_btn := tech._node_buttons["mil_dmg_1"] as Button
	_check(idle_btn != null, "mil_dmg_1 节点按钮应存在")
	if idle_btn != null:
		_check(idle_btn.has_theme_stylebox_override("pressed"), "非选中节点应持有 pressed 覆盖（防黑闪）")
		_check(idle_btn.has_theme_stylebox_override("hover_pressed"), "非选中节点应持有 hover_pressed 覆盖（防黑闪）")
		_check(not idle_btn.button_pressed, "非选中节点不应处于按下态")

	# ② 点击节点 → 解锁按钮可用 → 点击解锁 → 状态刷新入库。
	var node_btn := tech._node_buttons["mil_dmg_2"] as Button
	_check(node_btn != null, "mil_dmg_2 节点按钮应存在")
	if node_btn == null:
		_finish()
		return
	node_btn.emit_signal("pressed")
	for i in range(3):
		await get_tree().process_frame
	var unlock_btn := tech._unlock_button as Button
	_check(unlock_btn != null and unlock_btn.visible, "选中可解锁节点后解锁按钮应可见")
	_check(unlock_btn != null and not unlock_btn.disabled, "点数充足时解锁按钮应可用")
	_check(unlock_btn != null and unlock_btn.text == "解锁", "解锁按钮文案应为「解锁」")
	# 选中后其它节点仍保持 pressed 覆盖（回归 ①）。
	if idle_btn != null:
		_check(idle_btn.has_theme_stylebox_override("pressed"), "选中其它节点后非选中节点仍应持有 pressed 覆盖")
	if unlock_btn != null:
		unlock_btn.emit_signal("pressed")
	for i in range(3):
		await get_tree().process_frame
	var refreshed := ProfileStore.get_profile()
	_check(TechTree.is_unlocked(refreshed, "mil_dmg_2"), "点击解锁后 mil_dmg_2 应已解锁入库")
	_check(unlock_btn != null and unlock_btn.text == "已解锁 ✓", "解锁后按钮应刷新为「已解锁 ✓」")
	_check(unlock_btn != null and unlock_btn.disabled, "解锁后按钮应禁用")
	var bottom_label := node_btn.get_node_or_null("Content/BottomLabel") as Label
	_check(bottom_label != null and bottom_label.text == "✓", "已解锁节点底部应显示 ✓")

	# ③ 稀疏层列对齐（v0.20.51 / B-070）：将略 tier3「军府调度」必须与前置「官商合作」同列、
	#    且不在首列；军略 tier3「百战精锐」仍在首列（终极层虚线提示条口径不变）。
	tech._set_category("将略")
	for i in range(3):
		await get_tree().process_frame
	var supply_2 := tech._node_buttons.get("strat_supply_2") as Button
	var supply_3 := tech._node_buttons.get("strat_supply_3") as Button
	var first_col := tech._node_buttons.get("strat_rage_1") as Button
	_check(supply_2 != null and supply_3 != null and first_col != null, "将略节点按钮应齐备（含军府调度）")
	if supply_2 != null and supply_3 != null and first_col != null:
		_check(is_equal_approx(supply_3.global_position.x, supply_2.global_position.x),
			"军府调度应与前置「官商合作」同列（x %.1f vs %.1f）" % [supply_3.global_position.x, supply_2.global_position.x])
		_check(absf(supply_3.global_position.x - first_col.global_position.x) > 1.0,
			"军府调度不应落在首列（x %.1f vs %.1f）" % [supply_3.global_position.x, first_col.global_position.x])
	tech._set_category("军略")
	for i in range(3):
		await get_tree().process_frame
	var mil_1 := tech._node_buttons.get("mil_dmg_1") as Button
	var mil_3 := tech._node_buttons.get("mil_dmg_3") as Button
	if mil_1 != null and mil_3 != null:
		_check(is_equal_approx(mil_3.global_position.x, mil_1.global_position.x),
			"军略「百战精锐」应仍在首列（与精兵操练同列）")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("TECH_UNLOCK_TEST_OK")
		get_tree().quit(0)
	else:
		print("TECH_UNLOCK_FAILURES=%d" % failures.size())
		get_tree().quit(1)