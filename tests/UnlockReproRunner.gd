extends Node

## 回归测试（v0.21.1）：手动通关（Main._on_victory）与一键通关（MapPanel）两条
## 结算路径的英雄解锁行为。路径 A 复现 v0.21.1 修复前的旧顺序（先 mark_victory
## 再收集奖励），验证结算窗口守卫放宽后不再丢解锁；路径 B 验证统一后的新顺序。
## 使用一次性隔离存档槽，不触碰玩家真实存档。

var failures: Array[String] = []
var _profile_file := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.unlock_repro_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("UNLOCK_REPRO: %s" % message)


func _run() -> void:
	var s02 := GameFlow.load_stage_data(&"ch01_s02")
	_check(s02 != null, "s02 应可加载")
	if s02 == null:
		_finish()
		return

	# 路径 A：旧顺序（先 mark_victory 再 collect_stage_rewards）——结算窗口守卫放宽后仍应正常。
	var manual_profile := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(manual_profile)
	var manual_session := BattleSession.new("ch01_s02")
	manual_session.mark_victory({"difficulty": "normal"})
	GameFlow.collect_stage_rewards(manual_session, s02, true)
	_check(manual_session.get_pending_unlocks().size() == 1,
		"手动路径应收集到 1 个解锁（实际 %d）" % manual_session.get_pending_unlocks().size())
	_check(manual_session.get_pending_loot().size() > 0, "手动路径应收集到首通掉落")
	var saved_manual := ProfileStore.commit_victory(manual_session, manual_profile)
	_check(saved_manual, "手动路径提交应成功")
	_check(manual_profile.has_character("zhang_fei"), "手动路径提交后应解锁张飞")

	# 路径 B：统一顺序（MapPanel 与修复后 Main._on_victory：先 collect 再 mark_victory）。
	var quick_profile := ProfileStore.create_new_profile(false)
	GameFlow.ensure_initial_characters(quick_profile)
	var quick_session := BattleSession.new("ch01_s02")
	GameFlow.collect_stage_rewards(quick_session, s02, true)
	quick_session.mark_victory({"difficulty": "normal"})
	_check(quick_session.get_pending_unlocks().size() == 1,
		"一键路径应收集到 1 个解锁（实际 %d）" % quick_session.get_pending_unlocks().size())
	var saved_quick := ProfileStore.commit_victory(quick_session, quick_profile)
	_check(saved_quick, "一键路径提交应成功")
	_check(quick_profile.has_character("zhang_fei"), "一键路径提交后应解锁张飞")

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("UNLOCK_REPRO_OK")
		get_tree().quit(0)
	else:
		print("UNLOCK_REPRO_FAILED: %d" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)
