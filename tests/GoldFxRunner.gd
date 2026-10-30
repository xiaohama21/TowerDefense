extends Node

## 局内金币获取反馈回归（✅ 0.8.17.1 / DESIGN_REVIEW §12.7 / UI_LAYOUT §10 v0.20.67）。
## headless 断言：①FX 层不创建（零节点零差异）；②击杀金币经济链路零变化（含新信号载荷）；
## ③显示与真值分离（收入等落地滚动 / 支出即时落真值 / 1.0s 兜底）；④金币音已合成。

var failures: Array[String] = []
var _profile_file := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.goldfx_runner_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("GOLD_FX_TEST: %s" % message)


func _run() -> void:
	var ui := await _test_battle_scene()
	if ui != null:
		_test_economy_unchanged()
		await _test_display_separation(ui)
	_test_coin_sfx()
	_cleanup()
	_finish()


## ① headless 跳过 + 初始同步即时落真值；返回 UI 节点供后续用例。
func _test_battle_scene() -> Node:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	_check(packed != null, "Main.tscn 无法加载")
	if packed == null:
		return null
	var main := packed.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(main.get_node_or_null("GoldFxLayer") == null, "headless 不应创建 GoldFxLayer（§12.7 拍板 5）")
	_check(main._gold_fx == null, "headless 不应创建金币 FX 节点")
	var ui := main.get_node("UI")
	_check(ui._gold_fx_enabled == false, "headless 应关闭金币 FX（显示立即落真值）")
	_check(ui.gold_label.text == str(GameManager.gold), "初始金币应即时对齐真值（首帧同步不滚动）")
	return ui


## ② 击杀金币经济链路零变化 + 新信号载荷（入账额 / 击杀点 / 档位）。
func _test_economy_unchanged() -> void:
	var before: int = GameManager.gold
	var captured: Array = []
	var probe := func(amount: int, world_pos: Vector2, tier: int) -> void:
		captured.append([amount, world_pos, tier])
	GameManager.gold_gain_fx.connect(probe)
	GameManager.enemy_died(10, 0, "", {}, false, false, 0, Vector2(120.0, 240.0), 2)
	GameManager.gold_gain_fx.disconnect(probe)
	var expected := before + int(round(10 * Difficulty.reward_mult(GameFlow.selected_difficulty)))
	_check(GameManager.gold == expected, "击杀金币应仍在击杀帧按 reward_mult 到账（经济链路零变化）")
	_check(captured.size() == 1, "金币 FX 信号应广播一次")
	if captured.size() == 1:
		var payload: Array = captured[0]
		_check(int(payload[0]) == expected - before, "FX 载荷 amount 应等于真实入账额")
		_check(payload[1] == Vector2(120.0, 240.0), "FX 载荷应带击杀点世界坐标")
		_check(int(payload[2]) == 2, "FX 载荷应带击杀档位（2 = Boss）")


## ③ 显示与真值分离（headless 下手工开启 FX 开关，不涉及 FX 节点）。
func _test_display_separation(ui: Node) -> void:
	ui.set_gold_fx_enabled(true)
	var truth: int = GameManager.gold
	ui.update_gold(truth + 7, true)
	_check(ui._gold_display == truth + 7 and ui.gold_label.text == str(truth + 7),
		"开局同步（snap = true）应立即落真值（防开局数字滞留旧值）")
	ui.update_gold(truth + 14)
	_check(ui._gold_display == truth + 7 and ui.gold_label.text == str(truth + 7),
		"收入 FX 未落地时数字应保持旧值（等待落地）")
	ui.on_gold_fx_landed()
	await get_tree().create_timer(0.45).timeout
	_check(ui._gold_display == truth + 14 and ui.gold_label.text == str(truth + 14),
		"FX 落地后数字应在 0.25s 内滚动对齐真值")
	ui.update_gold(truth + 4)
	_check(ui._gold_display == truth + 4 and ui.gold_label.text == str(truth + 4),
		"支出应立即落真值、不滚动（§12.7 拍板 3）")
	ui.update_gold(truth + 60)
	await get_tree().create_timer(1.5).timeout
	_check(ui._gold_display == truth + 60, "1.0s 无 FX 落地应兜底对齐真值")
	ui.set_gold_fx_enabled(false)


## ④ 金币音随本小版本合成（headless 走哑音频）。
func _test_coin_sfx() -> void:
	_check(SfxLibrary.SFX_IDS.has(&"coin"), "音效目录应包含金币音 coin")
	SfxLibrary.play(&"coin", -30.0, 1.03)
	SfxLibrary.play(&"coin", -30.0, 0.97)


func _cleanup() -> void:
	get_tree().paused = false
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = _profile_file + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	for failure in failures:
		print("GOLD_FX_TEST_FAIL: %s" % failure)
	if failures.is_empty():
		print("GOLD_FX_TEST_OK")
		get_tree().quit(0)
	else:
		print("GOLD_FX_TEST_FAILED: %d" % failures.size())
		get_tree().quit(1)
