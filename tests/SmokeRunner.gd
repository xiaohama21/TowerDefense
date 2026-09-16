extends Node

var failures: Array[String] = []
var warnings: Array[String] = []


var _profile_file := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 隔离存档槽：测试直开 Main.tscn 会触发初始武将写档与等级查询，
	# 不得读写玩家真实存档（模式同 FlowRunner/Stage0Runner）。
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.smoke_runner_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("SMOKE_TEST: %s" % message)


## 拖拽用例辅助（v0.33.3）：从 start_row 起找 count 个可建空地格
## （非道路 / 非禁建 / 未占用；行 ≥3 避开顶栏与卡条 UI 区）。
func _find_buildable_cells(build_manager: Node, count: int, start_row: int = 3) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(start_row, GridBackground.ROWS):
		for col in range(GridBackground.COLS):
			var cell := Vector2i(col, row)
			if build_manager._road_cells.has(cell) or build_manager._forbidden_cells.has(cell):
				continue
			if build_manager._is_cell_occupied(cell):
				continue
			result.append(cell)
			if result.size() >= count:
				return result
	return result


func _tower_at_cell(tower_manager: Node, cell: Vector2i) -> Tower:
	for child in tower_manager.get_children():
		var tower := child as Tower
		if tower == null or not is_instance_valid(tower):
			continue
		var tower_cell := Vector2i(
			floori(tower.global_position.x / GridBackground.GRID_SIZE),
			floori(tower.global_position.y / GridBackground.GRID_SIZE)
		)
		if tower_cell == cell:
			return tower
	return null


## 光标用例辅助（B-077·B-078）：拖拽建造走 UI 卡片按键路径，需合成鼠标按键事件。
func _mouse_button(button: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(600, 400)
	event.global_position = event.position
	return event


## 遗留槽位坐标（v0.33.3 槽位视觉已移除，StageData.build_slots 数据废弃保留）：
## 转成网格坐标供拖拽用例复用原槽位布局，保持后续用例的塔位几何不变。
func _legacy_slot_cells(build_manager: Node, stage_data: StageData) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for entry in stage_data.get_build_slot_data():
		var cell := Vector2i(
			floori(entry.position.x / GridBackground.GRID_SIZE),
			floori(entry.position.y / GridBackground.GRID_SIZE)
		)
		if result.has(cell):
			continue
		if build_manager._road_cells.has(cell) or build_manager._forbidden_cells.has(cell):
			continue
		result.append(cell)
	return result


## 经验池（✅ 0.8.15.0 / DESIGN_REVIEW §12.6.1 / NUMBERS 10.14 / CHARACTERS 4.4）回归：
## ① 注入 = roundi((击杀经验总量 + participant_xp × 出战人数) × 50%)，含难度倍率、纯增量；
## ② 失败 / 放弃作废；③ 池内分配仅限已拥有且未满级、余额不足拒绝、不可逆；
## ④ 「直接升级」消耗 = 升级到下一级差额；⑤ 练兵令（exp_scroll）整体删除防线。
func _test_exp_pool_0815() -> void:
	var session := BattleSession.create("ch01_s01", ["guan_yu", "liu_bei", "zhang_fei", "huang_zhong"])
	session.add_kill_xp_base(527)
	_check(session.get_pending_exp_pool() == 0, "未结算前不应写入经验池注入")
	_check(session.finalize_exp_pool_injection(50) == 364,
		"注入应为 roundi((527 + 50×4) × 0.5) = 364")
	session.finalize_exp_pool_injection(50)
	_check(session.get_pending_exp_pool() == 364, "重复结算应保持同一定值（幂等）")
	_check(session.pending_xp_by_character.is_empty(), "注入不应扣减 / 改写武将所得经验（纯增量）")
	# 难度口径：上报的是按 reward_mult 缩放后的击杀经验（困难 ×1.6），participant_xp 不缩放。
	var hard_session := BattleSession.create("ch01_s01", ["guan_yu"])
	hard_session.add_kill_xp_base(int(round(527 * 1.6)))
	_check(hard_session.finalize_exp_pool_injection(50) == 447,
		"困难注入应含 reward_mult ×1.6：roundi((843 + 50) × 0.5) = 447")
	# 失败 / 放弃作废：注入量与基数一并清空（沿用现有结算语义）。
	var fail_session := BattleSession.create("ch01_s01", ["guan_yu"])
	fail_session.add_kill_xp_base(500)
	fail_session.finalize_exp_pool_injection(60)
	fail_session.mark_discarded()
	_check(fail_session.get_pending_exp_pool() == 0 and fail_session.kill_xp_base == 0,
		"失败 / 放弃应作废经验池注入与基数")
	# 池内分配（不可逆）：未拥有 / 满级 / 余额不足一律拒绝。
	var profile := PlayerProfile.new()
	profile.add_exp_pool(1000)
	_check(profile.get_exp_pool() == 1000, "结算注入应累计经验池余额")
	_check(not profile.allocate_exp_pool("guan_yu", 100), "未拥有武将不可分配经验池")
	profile.unlock_character("guan_yu")
	_check(profile.can_allocate_exp_pool("guan_yu"), "已拥有且未满级武将应可分配")
	_check(profile.allocate_exp_pool("guan_yu", 300), "余额充足时分配应成功")
	_check(profile.get_character_exp("guan_yu") == 300 and profile.get_exp_pool() == 700,
		"分配应扣池并写入 characters[id].total_exp")
	_check(not profile.allocate_exp_pool("guan_yu", 800), "余额不足应拒绝分配")
	_check(profile.get_exp_pool() == 700, "拒绝分配不应改动余额（无部分写入）")
	# 「直接升级」：消耗 = 升级到下一级所需差额（300 exp = Lv4 → Lv5 门槛 340，差额 40）。
	_check(profile.exp_pool_level_up_cost("guan_yu") == 40,
		"Lv4（300 exp）直接升级消耗应为 40（Lv5 门槛 340 − 300）")
	_check(profile.level_up_with_exp_pool("guan_yu"), "池内经验充足时应直接升级成功")
	_check(GameFlow.get_character_level(profile, "guan_yu") == 5 and profile.get_exp_pool() == 660,
		"直接升级应消耗池内经验并提升 1 级")
	profile.add_character_exp("guan_yu",
		LevelCurve.exp_total_for_level(LevelCurve.max_level()) - profile.get_character_exp("guan_yu"))
	_check(GameFlow.get_character_level(profile, "guan_yu") == LevelCurve.max_level(),
		"测试前置：该武将应已满级")
	_check(not profile.can_allocate_exp_pool("guan_yu"), "满级武将不可分配经验池")
	_check(not profile.allocate_exp_pool("guan_yu", 10), "满级武将分配应被拒绝（30 级封顶不产池经验）")
	_check(profile.exp_pool_level_up_cost("guan_yu") == 0, "满级武将直接升级消耗应为 0（按钮禁用依据）")
	# 练兵令删除防线（0.8.15.0）：道具资源 / 目录 / 存档残留三处均不得存在。
	_check(not ResourceLoader.exists("res://resources/items/exp_scroll.tres"), "练兵令道具资源应已删除")
	var item_paths := _collect_resource_paths("res://resources/items")
	var has_exp_scroll := false
	for path in item_paths:
		if path.get_file().get_basename() == "exp_scroll":
			has_exp_scroll = true
	_check(not has_exp_scroll, "道具目录不应残留练兵令资源")
	var legacy := PlayerProfile.from_dict({"schema_version": 5, "items": {"exp_scroll": 5, "yellow_turban_cloth": 2}})
	_check(int(legacy.items.get("exp_scroll", 0)) == 0, "加载旧档不应保留练兵令数量（防御性清理）")
	_check(int(legacy.items.get("yellow_turban_cloth", 0)) == 2, "防御性清理不应影响其他道具")


## 军功 + 军需重构（✅ 0.8.16.0 / DESIGN_REVIEW §12.6.2 / NUMBERS 10.15 / SAVE_DATA 8 / STATS_PIPELINE v0.7）回归：
## ① 军功逐敌档位表（步卒 / 弓手 1、轻骑 / 祭酒 2、精英 3、Boss 25、终 Boss 张角 40）；
## ② 各关合计 71 / 90 / 129 / 144 / 145 / 208 / 167 / 288 = 全章 1242，困难精确 ×1.5 = 1863
##   （精确累计、结算 roundi 取整——逐笔取整会把 1~3 军功放大成 2/5，全章偏到 2228）；
## ③ 与经验同通道：胜利写档、失败 / 放弃作废（mark_discarded / clear_pending_rewards 清零）；
## ④ 军需 6 件目录 · 逐级费用 / 限次 / 幅度 / 解锁 340·425 / 强化 150·300；
## ⑤ 军需带（基础 2 槽 + 科技「军府调度」1）与 schema v6。
## 敌人血条三档（UI_LAYOUT §10 / 程序 0.8.16.4「墨槽胶囊」）：普通 max(体型宽,24)×6 /
## 精英「体型宽 + 6」×8 + 白框 / Boss 84×12 + 金框刻度；水平居中于体型、条底 = 身体顶 −10。
## 不入树（避免污染 enemies 组）：仅用场景副本验证几何与可见规则纯计算。
func _test_enemy_hp_bar_0816() -> void:
	var cases := [
		[load("res://resources/enemies/yellow_turban/yellow_turban_soldier.tres"), Enemy.HpBarTier.NORMAL, Vector2(34, 6)],
		[load("res://resources/enemies/yellow_turban/yellow_turban_elite_sergeant.tres"), Enemy.HpBarTier.ELITE, Vector2(56, 8)],
		[load("res://resources/enemies/yellow_turban/yellow_turban_general.tres"), Enemy.HpBarTier.BOSS, Vector2(84, 12)],
	]
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	for entry in cases:
		var data := entry[0] as EnemyData
		if data == null or enemy_scene == null:
			_check(false, "血条断言：敌人数据 / 场景应可加载")
			return
		var enemy := enemy_scene.instantiate() as Enemy
		enemy.tags.assign(data.tags)
		enemy.max_hp = 100
		enemy.current_hp = 100
		enemy.set_body_size(data.body_size)
		# 不入树时 @onready 未就绪：手动注入 Body 引用（take_damage → _apply_body_modulate 需要）。
		enemy.body = enemy.get_node_or_null("Body") as ColorRect
		_check(enemy.get_hp_bar_tier() == int(entry[1]),
			"血条档位：%s 应为 %d（实际 %d）" % [data.enemy_id, int(entry[1]), enemy.get_hp_bar_tier()])
		var expected := entry[2] as Vector2
		_check(enemy.get_hp_bar_size() == expected,
			"血条尺寸：%s 应为 %s（实际 %s）" % [data.enemy_id, str(expected), str(enemy.get_hp_bar_size())])
		var rect := enemy.get_hp_bar_rect()
		_check(is_equal_approx(rect.position.x, -rect.size.x * 0.5),
			"血条应水平居中于体型：%s" % data.enemy_id)
		_check(is_equal_approx(rect.position.y + rect.size.y + 10.0, -data.body_size.y * 0.5),
			"血条底应距身体顶 10px（不压头带，头带占 −7…−2）：%s" % data.enemy_id)
		_check(is_equal_approx(enemy.hp_bar_top_y(), rect.position.y),
			"眩晕三小星 / 阶段点锚点应取条顶：%s" % data.enemy_id)
		# 可见规则（不变）：满血隐藏 → 受击显示 → 隐匿未现形隐藏。
		_check(not enemy.should_show_hp_bar(), "满血应隐藏血条：%s" % data.enemy_id)
		enemy.take_damage(30)
		_check(enemy.should_show_hp_bar(), "受击后应显示血条：%s" % data.enemy_id)
		_check(is_equal_approx(enemy._hp_ghost_ratio, 1.0) and enemy._hp_ghost_hold > 0.0,
			"受击瞬间应留下掉血残影（旧比例 1.0 + 停留计时）：%s" % data.enemy_id)
		enemy.stealth = true
		enemy._set_stealth_revealed(false)
		_check(not enemy.should_show_hp_bar(),
			"隐匿未现形应隐藏血条：%s" % data.enemy_id)
		enemy.free()


## 一击必杀血条定格（UI_LAYOUT §10 / 程序 0.8.16.5）：满血敌人被单次受击直接打死时，
## 血量同一帧 100% → 0 并 queue_free（无「掉血但活着」的帧）→ 死亡点补播 0.50s 血条定格。
func _test_kill_bar_flash_0816() -> void:
	var enemy_scene := load("res://scenes/Enemy.tscn") as PackedScene
	var data := load("res://resources/enemies/yellow_turban/yellow_turban_soldier.tres") as EnemyData
	if data == null or enemy_scene == null:
		_check(false, "一击必杀定格：敌人数据 / 场景应可加载")
		return
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.max_hp = 100
	enemy.current_hp = 100
	enemy.body = enemy.get_node_or_null("Body") as ColorRect
	enemy.set_body_size(data.body_size)
	# 判定（纯函数）：入伤前满血 + 非隐匿未现形 → 补定格；已受伤 / 隐匿 → 不补。
	_check(enemy.should_flash_kill_bar(1.0), "满血一击必杀应补血条定格")
	_check(not enemy.should_flash_kill_bar(0.83), "已受过伤（血条显示过）的敌人不补定格")
	enemy.stealth = true
	enemy._set_stealth_revealed(false)
	_check(not enemy.should_flash_kill_bar(1.0), "隐匿未现形的一击必杀不补定格")
	enemy.stealth = false
	# 非致死受击不得登记定格（血条本身会显示，走常规路径）。
	enemy.take_damage(30)
	_check(not enemy._kill_bar_flash and not enemy.is_dead, "非致死受击不应登记定格")
	# 满血一击必杀：走 take_damage → die() 全链路（奖励清零，避免污染后续用例的账面）。
	enemy.current_hp = enemy.max_hp
	enemy.reward = 0
	enemy.kill_xp = 0
	enemy.merit_reward = 0
	enemy.take_damage(999)
	_check(enemy.is_dead, "满血一击必杀应致死")
	_check(not enemy._kill_bar_flash, "die() 应消费定格登记（测试环境不入树，不生成节点）")
	enemy.free()
	# 定格曲线（纯函数）：0.20s 填充打空 / 0.36s 白残影拖尾结束 / 0.35s 起淡出 / 0.50s 归零。
	# 脚本按路径取用（headless 下全局类缓存不保证含新 class_name）。
	var flash_script := load("res://scripts/EnemyKillBarFlash.gd") as GDScript
	if flash_script == null:
		_check(false, "定格脚本应可加载")
		return
	_check(is_equal_approx(flash_script.fill_ratio_at(0.0), 1.0), "定格 t=0 填充应为满")
	_check(is_equal_approx(flash_script.fill_ratio_at(flash_script.FILL_DRAIN), 0.0),
		"定格填充应在 0.20s 打空")
	_check(is_equal_approx(flash_script.ghost_ratio_at(0.0), 1.0), "定格 t=0 残影应为满")
	_check(is_equal_approx(flash_script.ghost_ratio_at(flash_script.GHOST_DRAIN), 0.0),
		"定格白残影应在 0.36s 拖尾结束")
	_check(flash_script.ghost_ratio_at(0.10) > flash_script.fill_ratio_at(0.10),
		"定格残影应滞后于填充（白色拖尾）")
	_check(is_equal_approx(flash_script.alpha_at(flash_script.FADE_START), 1.0),
		"定格在 0.35s 前应保持不透明")
	_check(is_equal_approx(flash_script.alpha_at(flash_script.DURATION), 0.0),
		"定格结束应完全淡出")
	_check(flash_script.DURATION > flash_script.GHOST_DRAIN
		and flash_script.GHOST_DRAIN > flash_script.FILL_DRAIN,
		"定格时长应满足 填充 < 残影 < 总时长")
	# 场景与档位注入（不入树，仅验证可实例化 + setup 生效）。
	var flash_scene := load("res://scenes/EnemyKillBarFlash.tscn") as PackedScene
	_check(flash_scene != null, "定格场景应可加载")
	if flash_scene == null:
		return
	var flash := flash_scene.instantiate() as Node2D
	_check(flash != null and flash.z_index == 49, "定格应为 Node2D 且 z_index 49（低于飘字 50）")
	if flash == null:
		return
	flash.setup(Rect2(-17.0, -33.0, 34.0, 6.0), Enemy.HpBarTier.ELITE)
	_check(flash.bar_tier == Enemy.HpBarTier.ELITE and is_equal_approx(flash.bar_rect.size.x, 34.0),
		"定格应可写入矩形与档位（尺寸由 Enemy 侧算好）")
	flash.free()


func _test_merit_supply_0816() -> void:
	var merit_by_enemy := {
		"yellow_turban_soldier": 1, "yellow_turban_archer": 1,
		"yellow_turban_cavalry": 2, "yellow_turban_sorcerer": 2,
		"yellow_turban_sergeant": 3, "yellow_turban_berserker": 3,
		"yellow_turban_elite_sergeant": 3, "yellow_turban_heavy_berserker": 3,
		"yellow_turban_stealth_assassin": 3, "yellow_turban_stealth_healer": 3,
		"yellow_turban_armor_aura_caster": 3,
		"yellow_turban_general": 25, "yellow_turban_rebel_general": 25,
		"yellow_turban_heaven_general": 40,
	}
	for enemy_key in merit_by_enemy:
		var enemy_data := load("res://resources/enemies/yellow_turban/%s.tres" % enemy_key) as EnemyData
		_check(enemy_data != null and enemy_data.merit_reward == int(merit_by_enemy[enemy_key]),
			"敌人 %s 军功应为 %d（NUMBERS 10.15 档位表）" % [enemy_key, int(merit_by_enemy[enemy_key])])

	# 各关合计（不含 Boss 召唤物）与困难精确 ×1.5：同一遍扫描同时累计基础值与困难值。
	var expected_stage_merit := {
		"ch01_s01": 71, "ch01_s02": 90, "ch01_s03": 129, "ch01_s04": 144,
		"ch01_s05": 145, "ch01_s06": 208, "ch01_s07": 167, "ch01_s08": 288,
	}
	var chapter_merit := 0
	var hard_session := BattleSession.create("smoke_merit_chapter", ["guan_yu"])
	var hard_mult := Difficulty.merit_mult(Difficulty.HARD)
	for stage_key in expected_stage_merit:
		var merit_stage := load("res://resources/stages/chapter_01/%s.tres" % stage_key) as StageData
		if merit_stage == null:
			_check(false, "军功用例关卡应可加载: %s" % stage_key)
			continue
		var stage_merit := 0
		for merit_wave in merit_stage.waves:
			for merit_group in merit_wave.spawn_groups:
				if merit_group == null or merit_group.enemy == null:
					continue
				var merit_data := merit_group.enemy.resolved()
				var merit_count := int(merit_group.count)
				stage_merit += merit_data.merit_reward * merit_count
				hard_session.add_merit_scaled(merit_data.merit_reward * merit_count, hard_mult)
		chapter_merit += stage_merit
		_check(stage_merit == int(expected_stage_merit[stage_key]),
			"%s 军功合计应为 %d（NUMBERS 10.15）" % [stage_key, int(expected_stage_merit[stage_key])])
	_check(chapter_merit == 1242, "全章军功应为 1242（71 波 / 813 出怪）")
	_check(hard_session.get_pending_merit() == 1863,
		"困难全章军功应为精确 ×1.5 = 1863（逐笔取整会放大到 2228）")

	# 作废语义：与经验同通道——失败 / 退出 / 崩溃不带出。
	var discard_session := BattleSession.create("smoke_merit_discard", ["guan_yu"])
	discard_session.add_merit_scaled(40, 1.5)
	_check(discard_session.get_pending_merit() == 60, "军功应含难度倍率（终 Boss 档 40 × 1.5 = 60）")
	discard_session.mark_discarded()
	_check(discard_session.get_pending_merit() == 0, "失败 / 退出应作废本局军功（不带出）")
	var clear_session := BattleSession.create("smoke_merit_clear", ["guan_yu"])
	clear_session.add_merit(7)
	clear_session.clear_pending_rewards()
	_check(clear_session.get_pending_merit() == 0, "clear_pending_rewards 应清零军功暂存")

	# 写档链路：胜利 → apply_battle_session 写 military_merit；消费 / 余额不足拒绝。
	var merit_profile := PlayerProfile.new()
	merit_profile.unlock_character("guan_yu")
	var victory_session := BattleSession.create("ch01_s01", ["guan_yu"])
	victory_session.add_merit_scaled(100, 1.5)
	victory_session.mark_victory({"difficulty": "normal"})
	_check(merit_profile.apply_battle_session(victory_session), "胜利战局应可应用到档案（含军功）")
	_check(merit_profile.get_military_merit() == 150, "胜利结算应把军功写入档案（100 × 1.5 = 150）")
	_check(not merit_profile.spend_military_merit(200), "军功余额不足应拒绝消费")
	_check(merit_profile.get_military_merit() == 150, "拒绝消费不应改动军功余额")
	_check(merit_profile.spend_military_merit(150) and merit_profile.get_military_merit() == 0,
		"军功应可用于消费（解锁 / 强化）")

	# 军需目录与逐级数值（NUMBERS 10.15 表）：费用 / 限次 / 幅度 / 解锁。
	var catalog := BattleSupplyData.load_catalog()
	_check(catalog.size() == 6, "军需池应为 6 件")
	var expected_supply_order: Array[String] = [
		"repair", "fire_attack", "war_drum", "slow_down", "stone_volley", "reward_army",
	]
	var catalog_order: Array[String] = []
	for catalog_item in catalog:
		catalog_order.append(str(catalog_item.supply_id))
	_check(catalog_order == expected_supply_order,
		"军需目录顺序应为 修整 / 火攻 / 擂鼓 / 缓兵 / 掷石齐射 / 犒军（固定展示顺序）")
	for catalog_item in catalog:
		var supply_id := str(catalog_item.supply_id)
		match supply_id:
			"repair":
				_check(catalog_item.merit_unlock_cost == 0 and catalog_item.cost_at(1) == 60
					and catalog_item.cost_at(2) == 55 and catalog_item.cost_at(3) == 50
					and catalog_item.max_uses_at(1) == 1 and catalog_item.max_uses_at(3) == 2
					and catalog_item.heal_at(1) == 10 and catalog_item.heal_at(2) == 12
					and catalog_item.heal_at(3) == 14,
					"修整应为 60/55/50 金 · 限 1/1/2 · 生命 +10/12/14（基础已解锁）")
			"fire_attack":
				_check(catalog_item.merit_unlock_cost == 0 and catalog_item.cost_at(1) == 80
					and catalog_item.cost_at(3) == 70 and catalog_item.max_uses_at(2) == 1
					and catalog_item.instant_magic_at(1) == 50 and catalog_item.instant_magic_at(3) == 80
					and catalog_item.burn_dps_at(1) == 25 and catalog_item.burn_dps_at(3) == 40
					and is_equal_approx(catalog_item.duration_at(1), 3.0),
					"火攻应为 80/75/70 金 · 限 1 · 立即 50/65/80 魔法 + 灼烧 25/32/40 ×3s")
			"war_drum":
				_check(catalog_item.merit_unlock_cost == 0 and catalog_item.cost_at(1) == 50
					and catalog_item.cost_at(3) == 40 and catalog_item.max_uses_at(1) == 2
					and catalog_item.max_uses_at(3) == 3
					and is_equal_approx(catalog_item.attack_speed_bonus_at(1), 0.30)
					and is_equal_approx(catalog_item.attack_speed_bonus_at(3), 0.45)
					and is_equal_approx(catalog_item.duration_at(1), 8.0),
					"擂鼓应为 50/45/40 金 · 限 2/2/3 · 攻速 +30/37/45% ×8s")
			"slow_down":
				_check(catalog_item.merit_unlock_cost == 0 and catalog_item.cost_at(1) == 40
					and catalog_item.cost_at(3) == 32 and catalog_item.max_uses_at(1) == 2
					and is_equal_approx(catalog_item.slow_factor_at(1), 0.60)
					and is_equal_approx(catalog_item.slow_factor_at(2), 0.53)
					and is_equal_approx(catalog_item.slow_factor_at(3), 0.45)
					and is_equal_approx(catalog_item.duration_at(1), 5.0)
					and is_equal_approx(catalog_item.duration_at(3), 7.0),
					"缓兵应为 40/36/32 金 · 限 2 · 减速 40/47/55%（时长 5/6/7s）")
			"stone_volley":
				_check(catalog_item.merit_unlock_cost == 340 and catalog_item.cost_at(1) == 70
					and catalog_item.cost_at(3) == 70 and catalog_item.max_uses_at(3) == 1
					and catalog_item.is_physical_strike()
					and catalog_item.instant_physical_at(1) == 60
					and catalog_item.instant_physical_at(2) == 85
					and catalog_item.instant_physical_at(3) == 110,
					"掷石齐射应为 70 金 · 限 1 · 全场各 60/85/110 物理（解锁 340）")
			"reward_army":
				_check(catalog_item.merit_unlock_cost == 425 and catalog_item.cost_at(1) == 50
					and catalog_item.max_uses_at(1) == 1 and catalog_item.rage_gain_at(1) == 20
					and catalog_item.rage_gain_at(2) == 28 and catalog_item.rage_gain_at(3) == 36,
					"犒军应为 50 金 · 限 1 · 怒气 +20/28/36（解锁 425）")
			_:
				_check(false, "军需目录出现未登记条目: %s" % supply_id)

	# 解锁 / 强化（不可逆、封顶 L3）与军需带槽位（基础 2 + 科技「军府调度」1 → 3）。
	_check(PlayerProfile.CURRENT_SCHEMA_VERSION == 6, "存档 schema 应为 v6（0.8.16 军功 + 军需）")
	_check(PlayerProfile.SUPPLY_MAX_LEVEL == 3 and PlayerProfile.BASE_SUPPLY_SLOTS == 2,
		"军需强化上限应为 3 级、军需带基础槽位应为 2")
	_check(PlayerProfile.supply_upgrade_cost(1) == 150 and PlayerProfile.supply_upgrade_cost(2) == 300
		and PlayerProfile.supply_upgrade_cost(3) == 0,
		"强化费用应为 L1→L2 = 150 / L2→L3 = 300 / 满级 0")
	var supply_profile := PlayerProfile.new()
	_check(supply_profile.is_supply_unlocked("repair") and supply_profile.is_supply_unlocked("fire_attack")
		and supply_profile.is_supply_unlocked("war_drum") and supply_profile.is_supply_unlocked("slow_down")
		and supply_profile.get_supply_level("repair") == 1,
		"基础 4 件军需应默认「已解锁 + L1」（裸档与读档同语义）")
	_check(not supply_profile.is_supply_unlocked("stone_volley")
		and not supply_profile.is_supply_unlocked("reward_army")
		and supply_profile.get_supply_level("stone_volley") == 0,
		"掷石齐射 / 犒军应默认未解锁（等级 0）")
	_check(not supply_profile.unlock_supply("stone_volley", 340), "军功不足时解锁应被拒绝")
	_check(not supply_profile.is_supply_unlocked("stone_volley"), "解锁失败不应写入解锁状态")
	supply_profile.add_military_merit(1000)
	_check(supply_profile.unlock_supply("stone_volley", 340)
		and supply_profile.get_military_merit() == 660
		and supply_profile.get_supply_level("stone_volley") == 1,
		"解锁掷石齐射应扣 340 军功并置 L1")
	_check(supply_profile.upgrade_supply("stone_volley")
		and supply_profile.get_supply_level("stone_volley") == 2
		and supply_profile.get_military_merit() == 510,
		"强化 L1→L2 应扣 150 军功")
	_check(supply_profile.upgrade_supply("stone_volley")
		and supply_profile.get_supply_level("stone_volley") == 3
		and supply_profile.get_military_merit() == 210,
		"强化 L2→L3 应扣 300 军功")
	_check(not supply_profile.upgrade_supply("stone_volley"), "满级军需不应再强化（不可逆且封顶）")
	# 选带：仅已解锁、去重、不得超槽位；toggle 语义 = 再点移出。
	_check(supply_profile.toggle_supply_loadout("repair", 2), "已解锁军需应可入带")
	_check(supply_profile.toggle_supply_loadout("repair", 2), "再次点击应把该件移出军需带")
	_check(supply_profile.get_supply_loadout().is_empty(), "移出后军需带应为空")
	_check(not supply_profile.toggle_supply_loadout("reward_army", 2), "未解锁军需不可入带")
	_check(supply_profile.toggle_supply_loadout("repair", 2)
		and supply_profile.toggle_supply_loadout("stone_volley", 2),
		"两件已解锁军需应可入带（基础 2 槽）")
	_check(not supply_profile.toggle_supply_loadout("fire_attack", 2), "超槽位应拒绝入带")
	_check(supply_profile.get_supply_loadout().size() == 2, "拒绝入带不应改动军需带")
	_check(not supply_profile.set_supply_loadout(["repair", "repair"], 3), "重复条目应被拒绝")
	_check(not supply_profile.set_supply_loadout(["repair", "reward_army"], 3), "含未解锁条目应被拒绝")
	_check(supply_profile.set_supply_loadout(["repair", "stone_volley", "fire_attack"], 3),
		"科技「军府调度」+1 时应可带 3 件")
	# 科技「军府调度」（strat_supply_3）：将略 tier 3、前置 strat_supply_2、效果 +1 槽。
	var has_supply_tech := false
	for tech_item in TechTree.get_items():
		if str(tech_item.id) == "strat_supply_3":
			has_supply_tech = true
			_check(str(tech_item.requires) == "strat_supply_2"
				and int(tech_item.effect.get("supply_slot_bonus", 0)) == 1,
				"「军府调度」应为将略 tier 3 / 前置 strat_supply_2 / 军需带 +1 槽")
	_check(has_supply_tech, "科技树应含「军府调度」（strat_supply_3，0.8.16 新增）")
	var slot_bonuses := TechTree.get_tech_bonuses(supply_profile)
	_check(int(slot_bonuses.get("supply_slot_bonus", 0)) == 0,
		"未解锁「军府调度」时槽位加成为 0（加成键默认存在）")


func _run() -> void:
	_check_resource_integrity()
	# 经验池（✅ 0.8.15 / NUMBERS 10.14）：注入定值 / 分配 / 直接升级 / 练兵令删除防线。
	_test_exp_pool_0815()
	# 军功 + 军需（✅ 0.8.16 / NUMBERS 10.15）：军功档位与合计 / 军需目录 · 解锁强化 · 选带 / schema v6。
	_test_merit_supply_0816()
	# 敌人血条三档（UI_LAYOUT §10 / 程序 0.8.16.4）：几何 · 居中 · 不压头带 · 掉血残影 · 满血隐藏。
	_test_enemy_hp_bar_0816()
	# 一击必杀血条定格（UI_LAYOUT §10 / 程序 0.8.16.5）：满血一击致死 → 死亡点补播 0.5s 血条定格。
	_test_kill_bar_flash_0816()
	# 遗物类目（v0.37.10 / 0.8.11.6）：5 件局内遗物物品分类=遗物（消耗品练兵令已随 0.8.15.0 删除）。
	for relic_id in ["wolf_tooth", "iron_shield", "provision_bag", "scout_eye", "war_drums"]:
		var relic_item := load("res://resources/items/%s.tres" % relic_id) as ItemData
		_check(relic_item != null and relic_item.item_type == ItemData.ItemType.RELIC,
			"遗物 %s 物品分类应为遗物" % relic_id)

	# 阶段 8 提交 6（v0.31.0）：职业级转职树——骑兵树铁骑 → 玄甲（强化）/骁骑（新技能）双分支。
	var promo_iron := load("res://resources/promotions/cavalry_iron_rider.tres") as PromotionData
	var promo_heavy := load("res://resources/promotions/cavalry_heavy_armor.tres") as PromotionData
	var promo_raider := load("res://resources/promotions/cavalry_swift_raider.tres") as PromotionData
	_check(promo_iron != null and promo_heavy != null and promo_raider != null, "骑兵职业树二转分支资源应齐全")
	if promo_iron and promo_heavy and promo_raider:
		_check(promo_iron.next_promotion_ids.size() == 2
			and promo_iron.next_promotion_ids.has(&"cavalry_heavy_armor")
			and promo_iron.next_promotion_ids.has(&"cavalry_swift_raider"), "铁骑应配置玄甲/骁骑两个二转分支")
		_check(str(promo_heavy.parent_id) == "cavalry_iron_rider"
			and str(promo_raider.parent_id) == "cavalry_iron_rider", "二转候选 parent 应指向铁骑")
		_check(promo_heavy.ultimate_multiplier > 1.0
			and promo_heavy.damage_multiplier > promo_iron.damage_multiplier, "玄甲应强化大招与三围")
	# 同职业角色共享同一转职树（关羽/赵云均为骑兵，promotion_ids 应一致）。
	var guan_yu_data := load("res://resources/characters/guan_yu.tres") as CharacterData
	var zhao_yun_data := load("res://resources/characters/zhao_yun.tres") as CharacterData
	_check(guan_yu_data != null and zhao_yun_data != null
		and guan_yu_data.promotion_ids == zhao_yun_data.promotion_ids
		and not guan_yu_data.promotion_ids.is_empty(), "同职业角色应共享同一职业转职树")
	# 角色称号（v0.28 纯记录无机制；v0.37.10 关羽正式称号定稿=武圣，旧专属转职名不再展示）。
	_check(guan_yu_data != null and guan_yu_data.titles == ["武圣"],
		"关羽称号应为武圣（v0.37.10 正式定稿）")
	_check(zhao_yun_data != null and zhao_yun_data.titles == ["龙骧卫"], "赵云称号应为龙骧卫")

	# 阶段 6（v0.17.0）：羁绊试点——资源齐全、桃园满员激活 +5%、五虎将缺员预览不激活。
	var taoyuan := load("res://resources/bonds/taoyuan_oath.tres") as BondData
	var five_tigers := load("res://resources/bonds/five_tigers.tres") as BondData
	_check(taoyuan != null and taoyuan.is_valid(), "桃园结义羁绊配置应有效")
	_check(five_tigers != null and five_tigers.is_valid(), "五虎将羁绊配置应有效")
	_check(GameFlow.get_squad_bond_damage_bonus([]) == 0.0, "空编队羁绊加成应为 0")
	_check(is_equal_approx(GameFlow.get_squad_bond_damage_bonus(["liu_bei", "guan_yu", "zhang_fei"]), 0.05),
		"桃园结义三人同队攻击应 +5%")
	_check(GameFlow.get_squad_bond_damage_bonus(["guan_yu", "zhang_fei", "zhao_yun", "huang_zhong"]) == 0.0,
		"五虎将缺马超（预览）不应激活加成")

	# 阶段 8 提交 6（v0.31.0）：转职候选图——未转职给一转（铁骑），铁骑给两个二转分支。
	var stage6_profile := ProfileStore.get_profile()
	if stage6_profile != null:
		stage6_profile.ensure_character("guan_yu")
		stage6_profile.set_promotion_path("guan_yu", [])
		var first_round := GameFlow.get_promotion_candidates(stage6_profile, "guan_yu")
		_check(first_round.size() == 1 and str(first_round[0].promotion_id) == "cavalry_iron_rider",
			"未转职关羽应只有一转候选（铁骑）")
		stage6_profile.set_promotion_path("guan_yu", ["cavalry_iron_rider"])
		var second_round := GameFlow.get_promotion_candidates(stage6_profile, "guan_yu")
		_check(second_round.size() == 2, "铁骑应提供两个二转分支候选")
		stage6_profile.set_promotion_path("guan_yu", ["cavalry_iron_rider", "cavalry_heavy_armor"])
		var second_active := GameFlow.get_active_promotion(stage6_profile, "guan_yu")
		_check(second_active != null and str(second_active.promotion_id) == "cavalry_heavy_armor",
			"二转后生效转职应为路径末位（玄甲）")
		var stage6_guan_yu := load("res://resources/characters/guan_yu.tres") as CharacterData
		if stage6_guan_yu != null and second_active != null:
			var xuanjia_stats := stage6_guan_yu.compute_stats_at(20, second_active)
			var xuanjia_expected := int(round((stage6_guan_yu.base_damage + stage6_guan_yu.damage_growth_per_level * 19) * 1.35))
			_check(int(xuanjia_stats["damage"]) == xuanjia_expected,
				"二转玄甲伤害倍率应生效（×1.35，含 20 级成长）")
		# 还原共享存档状态，避免污染后续建塔用例（塔伤害断言基于未转职）。
		stage6_profile.set_promotion_path("guan_yu", [])
	# 阶段 6 提交 2（v0.18.0）：数值配置中心化——game_balance 可加载且 LevelCurve/Difficulty 生效。
	var balance := GameBalance.get_balance()
	_check(balance != null and balance.is_valid(), "game_balance 中心配置应有效")
	_check(LevelCurve.max_level() == 30 and LevelCurve.exp_total_for_level(10) == 1440,
		"等级曲线应读中心配置（30 级封顶、10 级 1440 经验）")
	_check(is_equal_approx(Difficulty.enemy_hp_mult(Difficulty.HARD), 1.4)
		and is_equal_approx(Difficulty.reward_mult(Difficulty.HARD), 1.6)
		and is_equal_approx(Difficulty.material_mult(Difficulty.HARD), 2.0),
		"难度倍率应读中心配置（困难 1.4/1.6/2.0）")
	_check(Difficulty.count() == 2 and Difficulty.name(Difficulty.NORMAL) == "标准"
		and Difficulty.name(Difficulty.HARD) == "困难"
		and Difficulty.key_name(Difficulty.NORMAL) == "normal",
		"难度应两档化（标准/困难，data-driven difficulty_presets，v0.31.2）")

	# 阶段 6 提交 2（v0.18.0）：敌人模板——模板可加载、哨兵字段继承、显式字段覆盖。
	var heavy_cavalry := load("res://resources/enemy_templates/heavy_cavalry.tres") as EnemyTemplateData
	_check(heavy_cavalry != null and heavy_cavalry.is_valid(), "高护甲骑兵模板应可加载")
	if heavy_cavalry != null:
		var derived := EnemyData.new()
		derived.enemy_id = &"smoke_derived"
		derived.display_name = "模板派生测试敌"
		derived.template = heavy_cavalry
		# 哨兵约定（ENEMIES.md）：0/空字段继承模板值。
		derived.max_hp = 0
		derived.move_speed = 0.0
		derived.armor = -1
		derived.damage_to_base = 0
		derived.currency_reward = 0
		derived.kill_xp = 0
		derived.body_color = Color(0, 0, 0, 0)
		derived.body_size = Vector2.ZERO
		var merged := derived.resolved()
		_check(merged != derived and merged.max_hp == 180 and merged.move_speed == 145.0 and merged.armor == 32,
			"模板派生应继承血量/速度/护甲")
		_check(merged.currency_reward == 14 and merged.kill_xp == 12 and merged.damage_to_base == 2,
			"模板派生应继承奖励与漏怪伤害")
		var overridden := EnemyData.new()
		overridden.enemy_id = &"smoke_overridden"
		overridden.display_name = "模板覆盖测试敌"
		overridden.template = heavy_cavalry
		overridden.max_hp = 300
		overridden.armor = 0
		var merged2 := overridden.resolved()
		_check(merged2.max_hp == 300 and merged2.armor == 0, "显式字段应覆盖模板值")

	# 阶段 6 提交 2（v0.18.0）+ 阶段 8 提交 3 / 16：科技树配置化——四类分页、32 项、加成汇总来自配置。
	var tech_items := TechTree.get_items()
	_check(tech_items.size() == 32, "科技树配置应含 32 项（军略15/后勤5/工事3/将略9，0.8.16 新增「军府调度」）")
	_check(TechTree.get_categories() == ["军略", "后勤", "工事", "将略"], "科技树应为四类分页（军略/后勤/工事/将略）")
	_check(TechTree.get_items_by_category("军略").size() == 15, "军略分类应含 15 项（职业强化）")
	# 独立临时档案验证加成，避免解锁污染共享存档（后续伤害断言不受 +6% 影响）。
	var tech_profile := PlayerProfile.new()
	tech_profile.add_tech_points(30)
	tech_profile.unlock_tech("mil_dmg_1", 1)
	tech_profile.unlock_tech("mil_dmg_2", 2)
	_check(TechTree.get_tech_bonuses(tech_profile).get("damage_pct", 0) == 6,
			"军事分支加成应来自配置（精兵 2% + 老兵 4%）")
	# 阶段 8 提交 3：职业分支/机制分支效果与无条件重置。
	tech_profile.unlock_tech("prof_tiger_guard_2", 2)
	tech_profile.unlock_tech("eco_wave_2", 2)
	tech_profile.unlock_tech("strat_refund_1", 1)
	var tech_bonuses := TechTree.get_tech_bonuses(tech_profile)
	_check(int(tech_bonuses.get("profession_tiger_guard_damage_pct", 0)) == 6, "虎贲职业加成应来自配置")
	_check(int(tech_bonuses.get("wave_reward_pct", 0)) == 40, "波次奖励科技应生效（+40%）")
	_check(int(tech_bonuses.get("sell_refund_pct", 0)) == 5, "回收率科技应生效（+5%）")
	var reset_refund := TechTree.reset_tech(tech_profile)
	_check(reset_refund == 8, "无条件重置应全额返还科技点（1+2+2+2+1）")
	_check(tech_profile.tech_unlocks.is_empty() and tech_profile.tech_points == 30,
		"重置后应清空科技并返还累计消耗")

	# 阶段 7（v0.19.0）：局内遗物——5 件可加载、汇总叠加、永久使用（v0.33.1，选带不消耗库存）、s08 掉落、fast_charger 配置。
	var battle_relic_ids: Array[String] = ["wolf_tooth", "iron_shield", "war_drums", "scout_eye", "provision_bag"]
	var loaded_relics := 0
	for relic_id in battle_relic_ids:
		var relic := GameFlow.load_battle_relic_data(relic_id)
		if relic != null and relic.is_valid():
			loaded_relics += 1
	_check(loaded_relics == 5, "局内遗物 5 件应全部可加载")
	var stage7_profile := ProfileStore.get_profile()
	if stage7_profile != null:
		for relic_id in battle_relic_ids:
			stage7_profile.add_item(relic_id, 1)
		_check(GameFlow.get_owned_relic_ids(stage7_profile).size() == 5, "背包应可枚举全部 5 件遗物")
		GameFlow.set_squad_relics(["wolf_tooth", "war_drums", "scout_eye", "provision_bag", "wolf_tooth"])
		var relic_bonuses := GameFlow.get_battle_relic_bonuses()
		_check(GameFlow.squad_relic_ids.size() == 4, "同 ID 遗物不应重复选带")
		_check(int(relic_bonuses["damage_bonus_pct"]) == 5 and int(relic_bonuses["start_gold"]) == 50,
			"遗物汇总应叠加伤害/初始金币")
		GameFlow.set_squad_relics(["iron_shield", "wolf_tooth"])
		var relic_bonuses_2 := GameFlow.get_battle_relic_bonuses()
		_check(int(relic_bonuses_2["base_hp_bonus"]) == 10 and int(relic_bonuses_2["damage_bonus_pct"]) == 5,
			"遗物汇总应叠加基地生命")
		_check(is_equal_approx(float(relic_bonuses["attack_interval_factor"]), 0.95)
			and int(relic_bonuses["range_bonus_pct"]) == 10, "遗物汇总应叠加攻速/射程")
		# ✅ v0.33.1：遗物改永久使用——选带不消耗库存（consume_squad_relics 已随 B-019 移除）。
		_check(int(stage7_profile.items.get("wolf_tooth", 0)) == 1
			and int(stage7_profile.items.get("iron_shield", 0)) == 1
			and int(stage7_profile.items.get("provision_bag", 0)) == 1,
			"遗物应永久使用——选带/结算均不消耗库存")
		GameFlow.clear_squad_relics()
	var stage7_cavalry := load("res://resources/enemies/yellow_turban/yellow_turban_cavalry.tres") as EnemyData
	_check(stage7_cavalry != null and stage7_cavalry.special_behavior_id == &"fast_charger",
		"黄巾轻骑应配置 fast_charger 行为")
	var s08_stage := load("res://resources/stages/chapter_01/ch01_s08.tres") as StageData
	var s08_has_wolf := false
	if s08_stage != null:
		for reward in s08_stage.first_clear_rewards:
			if reward != null and reward.item != null and str(reward.item.item_id) == "wolf_tooth":
				s08_has_wolf = true
	_check(s08_stage != null and s08_has_wolf, "s08 首通掉落应含狼牙符")

	# 装饰素材（v0.16.0，GDD 5.7 第三步）：assets/map/decor 纹理应齐全（v0.33.4 目录迁移）。
	for decor_name in ["tree", "rock", "banner", "torch"]:
		_check(ResourceLoader.exists("res://assets/map/decor/%s.png" % decor_name),
			"装饰素材 %s.png 应存在" % decor_name)

	# 音效库（v0.16.0）：全部音效已合成且播放不报错（headless 走哑音频）。
	_check(SfxLibrary.get_synthesized_count() == SfxLibrary.SFX_IDS.size(),
		"音效库应合成本阶段全部音效")
	SfxLibrary.play(&"attack", -30.0)
	SfxLibrary.play(&"skill", -30.0)
	SfxLibrary.play(&"ultimate", -30.0)
	SfxLibrary.play(&"victory", -30.0)

	var packed := load("res://scenes/Main.tscn") as PackedScene
	_check(packed != null, "Main.tscn 无法加载")
	if packed == null:
		_finish()
		return

	# 测试直开战斗场景时 GameFlow 未选关，Main 回退到默认教学关。
	var stage_data := load("res://resources/stages/chapter_01/ch01_s01.tres") as StageData
	_check(stage_data != null, "默认关卡数据应可加载")

	var main := packed.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(GameManager.gold == stage_data.starting_currency, "初始金币应来自关卡配置（starting_currency）")
	_check(GameManager.lives == stage_data.starting_lives, "初始生命应来自关卡配置（starting_lives）")
	# v0.33.3：建造方式唯一化为拖拽——战场不再生成建造位 / 推荐位 / 预锁位。
	_check(get_tree().get_nodes_in_group("build_slots").is_empty(), "v0.33.3 起战场不应再生成建造位")
	_check(main.get_node_or_null("BuildSlots") == null, "v0.33.3 起 Main 不应再有 BuildSlots 节点")

	var build_manager := main.get_node("BuildManager")
	var tower_manager := main.get_node("TowerManager")
	var guan_yu := load("res://resources/characters/guan_yu.tres") as CharacterData
	var liu_bei := load("res://resources/characters/liu_bei.tres") as CharacterData

	# —— 拖拽建造（v0.33.3，唯一建造方式）——
	# 落点优先取遗留槽位坐标（保持后续用例的塔位几何），不足时回退自由空地扫描。
	var slot_cells := _legacy_slot_cells(build_manager, stage_data)
	# 顶栏/卡条覆盖行 0-1（y ≤ 158 视为 UI 区），优先选行 ≥2 的槽位格。
	var preferred_cells: Array[Vector2i] = []
	var rest_cells: Array[Vector2i] = []
	for slot_cell in slot_cells:
		if slot_cell.y >= 2:
			preferred_cells.append(slot_cell)
		else:
			rest_cells.append(slot_cell)
	preferred_cells.append_array(rest_cells)
	var free_cells := preferred_cells if preferred_cells.size() >= 3 else _find_buildable_cells(build_manager, 3)
	_check(free_cells.size() >= 3, "冒烟地图应存在至少 3 个可建空地（拖拽用例前置）")
	if free_cells.size() >= 3:
		var cell_a: Vector2i = free_cells[0]
		var cell_b: Vector2i = free_cells[1]
		var cell_c: Vector2i = free_cells[2]
		# 金币恰好 = 造价：拖出松手直建，扣费成功。
		GameManager.gold = guan_yu.build_cost
		_check(build_manager.begin_drag(guan_yu), "金币充足时应能开始拖拽")
		_check(build_manager.is_dragging(), "拖拽开始后应处于拖拽态")
		build_manager._update_drag_at(build_manager.cell_center(cell_a))
		_check(build_manager.can_build_at(cell_a), "可建空地应判定可建")
		build_manager.release_drag()
		await get_tree().process_frame
		_check(GameManager.gold == 0, "松手直建应扣除造价")
		_check(_tower_at_cell(tower_manager, cell_a) != null, "松手直建应在落点生成防御塔")
		_check(not build_manager.is_dragging(), "释放后拖拽应结束")
		# 金币不足：无法开始拖拽。
		_check(not build_manager.begin_drag(liu_bei), "金币不足时应拒绝开始拖拽")
		_check(not build_manager.is_dragging(), "被拒绝的开始拖拽不应进入拖拽态")
		# 已占用格：可拖但落点不可建，松手不建造不扣费。
		GameManager.gold = 9999
		_check(build_manager.begin_drag(liu_bei), "金币充足时应能再次拖拽")
		build_manager._update_drag_at(build_manager.cell_center(cell_a))
		_check(not build_manager.can_build_at(cell_a), "已占用格应判定不可建")
		_check(not build_manager._drag_valid, "落点不可建时虚影应标红")
		build_manager.release_drag()
		await get_tree().process_frame
		_check(GameManager.gold == 9999, "落点不可建时松手不应扣费")
		# 第二个可建格成功建塔。
		build_manager.begin_drag(liu_bei)
		build_manager._update_drag_at(build_manager.cell_center(cell_b))
		_check(build_manager._drag_valid, "可建落点应判定有效（绿格）")
		build_manager.release_drag()
		await get_tree().process_frame
		_check(_tower_at_cell(tower_manager, cell_b) != null, "金币充足时第二个落点应建塔成功")
		# 道路 / 禁建 / 越界判定。
		GameManager.gold = 9999
		build_manager.begin_drag(guan_yu)
		var road_cells_array: Array = build_manager._road_cells.keys()
		if not road_cells_array.is_empty():
			build_manager._update_drag_at(build_manager.cell_center(road_cells_array[0] as Vector2i))
			_check(not build_manager._drag_valid, "道路格应判定不可建")
		var forbidden_array: Array = build_manager._forbidden_cells.keys()
		if not forbidden_array.is_empty():
			build_manager._update_drag_at(build_manager.cell_center(forbidden_array[0] as Vector2i))
			_check(not build_manager._drag_valid, "禁建地形应判定不可建")
		_check(not build_manager.can_build_at(Vector2i(99, 99)), "越界格应判定不可建")
		_check(not build_manager.can_build_at(Vector2i(-1, 0)), "负坐标格应判定不可建")
		build_manager.cancel_drag()
		_check(not build_manager.is_dragging(), "取消后拖拽应结束且不扣费")
		# 拖入顶栏等 UI 区：虚影隐藏、松手取消不扣费。
		var gold_before_ui_release := GameManager.gold
		build_manager.begin_drag(guan_yu)
		build_manager._update_drag_at(Vector2(640, 60))
		_check(build_manager._drag_over_ui, "拖入顶栏区域应标记为 UI 区（虚影隐藏）")
		build_manager.release_drag()
		_check(not build_manager.is_dragging() and GameManager.gold == gold_before_ui_release,
			"UI 区松手应取消且不扣费")
		# 拖拽可视反馈：落点格 + 武将虚影（攻击范围圈随 is_selected 由塔自身绘制）。
		build_manager.begin_drag(guan_yu)
		build_manager._update_drag_at(build_manager.cell_center(cell_c))
		_check(build_manager._cell_tint != null and build_manager._cell_tint.visible
			and build_manager._drag_valid, "可建落点应显示绿色格提示")
		_check(build_manager._ghost != null and is_instance_valid(build_manager._ghost)
			and build_manager._ghost.visible and build_manager._ghost.is_selected,
			"拖拽时应显示带范围圈的武将虚影")
		build_manager.cancel_drag()
		# 拖拽光标 / 右键取消 / 战场准星（UI_LAYOUT §15，BUGS B-077·B-078·B-079）：Godot 按住左键期间
		# 光标形状取「被按下控件链」（= 按下时的建造卡），指针下的拖拽覆盖层不参与——拖拽光标必须由
		# 卡片承担；拖拽中右键同样只到卡片，取消须走卡片信号。
		GameManager.gold = 9999
		var ui := main.get_node("UI")
		var card: Control = ui._character_cards["guan_yu"]["panel"]
		_check(card.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"建造卡默认应为悬停手型（UI_LAYOUT §15 卡片行）")
		ui._on_card_gui_input(_mouse_button(MOUSE_BUTTON_LEFT, true), "guan_yu")
		_check(build_manager.is_dragging(), "建造卡按下应开始拖拽（UI 卡片路径）")
		_check(card.mouse_default_cursor_shape == Control.CURSOR_DRAG,
			"拖拽期建造卡应切拖拽光标 hand_closed（B-077）")
		ui._on_card_gui_input(_mouse_button(MOUSE_BUTTON_RIGHT, true), "guan_yu")
		_check(not build_manager.is_dragging(), "拖拽中右键应取消拖拽（B-078）")
		_check(card.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
			"取消后建造卡光标应复位悬停手型")
		var field_cursor := main.get_node_or_null("FieldCursorLayer/FieldCursor") as Control
		_check(field_cursor != null and field_cursor.mouse_filter == Control.MOUSE_FILTER_PASS
			and field_cursor.mouse_default_cursor_shape == Control.CURSOR_CROSS
			and field_cursor.size.x >= 1280.0 and field_cursor.size.y >= 720.0,
			"战场 FieldCursor 应铺满且为准星光标（B-079：Node2D 父级不传导锚点）")
	var enemy_manager := main.get_node("EnemyManager")
	# 程序化构造 EnemyData，替代旧的硬编码 spawn_enemy("boss")。
	var boss_data := EnemyData.new()
	boss_data.enemy_id = &"smoke_boss"
	boss_data.display_name = "冒烟测试 Boss"
	boss_data.max_hp = 800
	boss_data.move_speed = 40.0
	boss_data.currency_reward = 50
	boss_data.kill_xp = 100
	boss_data.damage_to_base = 5
	boss_data.body_color = Color.PURPLE
	boss_data.body_size = Vector2(60, 60)
	boss_data.tags = [&"boss"]
	# Boss 演出（v0.15.0）：生成即发 boss_entered 信号（横幅/血条强化）。
	var boss_entered_names: Array[String] = []
	GameManager.boss_entered.connect(func(name: String) -> void: boss_entered_names.append(name))
	var boss := enemy_manager.spawn_enemy_from_data(boss_data) as Enemy
	await get_tree().process_frame
	_check(boss != null and boss.current_hp == 800, "Boss 应以 800 HP 初始化")
	_check(boss_entered_names.size() == 1 and boss_entered_names[0] == "冒烟测试 Boss",
		"Boss 生成应触发 boss_entered 信号（横幅演出）")
	if boss:
		boss.set_process(false)
		boss.global_position = tower_manager.get_child(0).global_position + Vector2(30, 0)

	var first_tower := tower_manager.get_child(0) as Tower
	_check(first_tower.damage == guan_yu.base_damage, "塔伤害应来自武将数据")
	_check(first_tower.character_id == guan_yu.character_id, "塔应记录武将 ID")
	var second_tower := tower_manager.get_child(1) as Tower
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	first_tower._on_selection_area_input_event(get_viewport(), click, 0)
	_check(first_tower.is_selected and not second_tower.is_selected, "点击塔后应显示该塔范围")
	second_tower._on_selection_area_input_event(get_viewport(), click, 0)
	_check(not first_tower.is_selected and second_tower.is_selected, "切换塔时只能保留一个范围")
	second_tower._on_selection_area_input_event(get_viewport(), click, 0)
	_check(not second_tower.is_selected, "再次点击已选塔应关闭范围")
	await get_tree().process_frame
	_check(first_tower.find_target() == boss, "塔应锁定射程内 Boss")
	first_tower.target = boss
	first_tower.attack()
	_check(first_tower.is_swinging(), "骑兵攻击应触发挥击动作（无弹道）")
	_check(boss.current_hp < 800, "骑兵近战攻击应对 Boss 造成伤害")
	if is_instance_valid(boss):
		boss.die(false)

	var wave_manager := main.get_node("WaveManager")
	var soldier := load("res://resources/enemies/yellow_turban/yellow_turban_soldier.tres") as EnemyData
	var spawn := EnemySpawnData.new()
	spawn.enemy = soldier
	spawn.count = 1
	spawn.spawn_interval = 0.0
	var wave := WaveData.new()
	wave.wave_id = &"smoke_wave"
	wave.wave_number = 1
	wave.spawn_groups = [spawn]
	# 阶段 8 提交 2（P0 3.3）：波次完成金币奖励。
	wave.completion_currency = 10
	wave_manager.configure_waves([wave])
	GameManager.total_waves = 1
	GameManager.reset_combo()
	var gold_before_wave := GameManager.gold
	wave_manager.start_wave(0)
	await get_tree().process_frame
	_check(GameManager.is_wave_active, "开波后应进入战斗状态")
	var wave_enemies := get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP)
	_check(wave_enemies.size() == 1, "测试波次应生成一只敌人")
	if not wave_enemies.is_empty():
		(wave_enemies[0] as Enemy).take_damage(9999)
	for _i in range(5):
		await get_tree().process_frame
	_check(GameManager.current_wave == 1 and not GameManager.is_wave_active, "击杀最后一只敌人后应完成波次")
	# 击杀奖励（士兵 10 金）+ 波次奖励（completion_currency 10 金）。
	_check(GameManager.gold == gold_before_wave + 20,
		"波次完成应发放击杀奖励与 completion_currency（实际 +%d）" % (GameManager.gold - gold_before_wave))
	_check(GameManager.combo_count == 0 and GameManager.combo_tier == 0, "每波结束应清零连击")
	# 连击档位（P0 4.1）：5/10/15 连击进入 1/2/3 档，每波结束清零。
	GameManager._advance_combo()
	GameManager._advance_combo()
	GameManager._advance_combo()
	GameManager._advance_combo()
	GameManager._advance_combo()
	_check(GameManager.combo_count == 5 and GameManager.combo_tier == 1,
		"5 连击应进入连击档位 1（实际 count=%d tier=%d）" % [GameManager.combo_count, GameManager.combo_tier])
	for _i in range(5):
		GameManager._advance_combo()
	_check(GameManager.combo_tier == 2, "10 连击应进入连击档位 2（实际 tier=%d）" % GameManager.combo_tier)
	for _i in range(5):
		GameManager._advance_combo()
	_check(GameManager.combo_tier == 3, "15 连击应进入连击档位 3（实际 tier=%d）" % GameManager.combo_tier)
	GameManager.reset_combo()
	_check(GameManager.combo_count == 0 and GameManager.combo_tier == 0, "波次结束/重开应清零连击")

	# 局内升级/回收（GDD 5.4）：费用 = 造价×0.8×次数，返还 = 总投入×0.6（向上取整）。
	var zhang_fei := load("res://resources/characters/zhang_fei.tres") as CharacterData
	_check(zhang_fei != null and stage_data != null, "张飞与关卡数据应可加载")
	var zhang_cell := Vector2i(-1, -1)
	for candidate in _legacy_slot_cells(build_manager, stage_data):
		if not build_manager._is_cell_occupied(candidate):
			zhang_cell = candidate
			break
	if zhang_cell.x < 0:
		var zhang_fallback := _find_buildable_cells(build_manager, 1)
		if zhang_fallback.size() >= 1:
			zhang_cell = zhang_fallback[0]
	if zhang_fei != null and stage_data != null and zhang_cell.x >= 0:
		# 波次测试把 GameManager 推到了终局状态，先复位再验证局内建造/升级。
		GameManager.reset(9999, 20, stage_data.waves.size())
		# 拖拽建造按设计在暂停态不可用，先恢复（暂停来自前面波次测试的暂停按钮用例）。
		get_tree().paused = false
		# 前面波次测试可能已触发结算/选中塔面板，关闭避免其全屏/面板区拦截拖拽落点。
		var smoke_ui := main.get_node("UI")
		smoke_ui.hide_result()
		smoke_ui.hide_tower_panel()
		_check(build_manager.begin_drag(zhang_fei), "复位后应能开始张飞拖拽")
		build_manager._update_drag_at(build_manager.cell_center(zhang_cell))
		_check(build_manager._drag_valid, "张飞落点应判定可建")
		build_manager.release_drag()
		await get_tree().process_frame
		var spear_tower := tower_manager.get_child(tower_manager.get_child_count() - 1) as Tower
		_check(spear_tower != null and _tower_at_cell(tower_manager, zhang_cell) != null, "张飞塔应拖拽建造成功")
		if spear_tower != null:
			var upgrade_cost_1 := spear_tower.get_upgrade_cost(stage_data.upgrade_cost_factor)
			_check(upgrade_cost_1 == ceili(zhang_fei.build_cost * 0.8), "第一次升阶费用应为造价×0.8")
			_check(tower_manager.upgrade_tower(spear_tower, stage_data), "金币充足时应能升阶")
			_check(spear_tower.battle_rank == 1, "升阶后局内阶数应为 1")
			_check(spear_tower.damage == int(round(zhang_fei.base_damage * 1.15)), "虎贲一阶伤害应为 +15%")
			_check(is_equal_approx(spear_tower.attack_cooldown, zhang_fei.attack_interval / 1.08), "虎贲一阶攻速应为 +8%")
			_check(is_equal_approx(spear_tower.range_radius, zhang_fei.base_range * 1.03), "虎贲一阶射程应为 +3%")
			_check(tower_manager.upgrade_tower(spear_tower, stage_data), "第二次升阶应成功")
			_check(tower_manager.upgrade_tower(spear_tower, stage_data), "第三次升阶应成功")
			_check(spear_tower.battle_rank == stage_data.max_inbattle_upgrade_level, "升阶应止步于本关上限")
			_check(not tower_manager.upgrade_tower(spear_tower, stage_data), "超过上限后升阶应失败")

			# 近战行为集成（虎贲）（GDD modules/BEHAVIORS.md melee_thrust）：
			# 直伤一次带骑兵标签的轻骑，验证 15% 克制与近战无弹道。
			var cavalry_data := load("res://resources/enemies/yellow_turban/yellow_turban_cavalry.tres") as EnemyData
			var melee_target := enemy_manager.spawn_enemy_from_data(cavalry_data) as Enemy
			_check(melee_target != null, "近战用例应能生成轻骑")
			if melee_target != null:
				melee_target.set_process(false)
				# 升阶测试已把塔升到满阶（rank 3），提高测试敌人血量避免被秒杀，
				# 保证克制/光环伤害断言可精确比较。
				melee_target.max_hp = 999
				melee_target.current_hp = 999
				melee_target.global_position = spear_tower.global_position + Vector2(60, 0)
				spear_tower.target = melee_target
				spear_tower.attack()
				# 刘备塔在场：仁德光环使其他塔伤害 +8%（v0.11.2 特性生效）；
				# 轻骑重标甲 2（NUMBERS 10.12 / 0.8.13.0）：物理减伤 2/52。
				var benevolence := 1.08
				var melee_base := int(round(spear_tower.damage * 1.15 * benevolence))
				var melee_expected := int(round(float(melee_base) * (1.0 - 2.0 / 52.0)))
				_check(
					melee_target.current_hp == melee_target.max_hp - melee_expected,
					"虎贲近战直伤应含 15% 骑兵克制、8% 仁德光环与轻骑甲 2 减伤"
				)
				_check(spear_tower.is_swinging(), "近战攻击应触发挥击动作而非枪口闪光")
				melee_target.die(false)

			var invested := spear_tower.total_invested
			var refund := spear_tower.get_sell_refund(stage_data.sell_refund_ratio)
			_check(refund == ceili(invested * 0.6), "回收返还应为总投入×0.6（向上取整）")
			var gold_before_sell := GameManager.gold
			_check(tower_manager.sell_tower(spear_tower, stage_data), "回收应成功")
			_check(GameManager.gold == gold_before_sell + refund, "回收后应返还金币")
			await get_tree().process_frame
			_check(_tower_at_cell(tower_manager, zhang_cell) == null, "回收后落点格应可复用")
		# 待删除的张飞塔会跑完最后一帧 _process（角色技能就绪时自动释放当阳桥，
		# 对后续手动摆放的用例敌人施加恐惧/减速状态）。先等一帧让 queue_free
		# 生效，隔离后续用例。
		await get_tree().process_frame

	# 局内军需（✅ 0.8.16 重构 / NUMBERS.md 10.15）：6 件资源齐全、逐级（L1~L3）数值已配置。
	var supply_repair := load("res://resources/battle_supplies/repair.tres") as BattleSupplyData
	var supply_fire := load("res://resources/battle_supplies/fire_attack.tres") as BattleSupplyData
	var supply_drum := load("res://resources/battle_supplies/war_drum.tres") as BattleSupplyData
	var supply_slow := load("res://resources/battle_supplies/slow_down.tres") as BattleSupplyData
	var supply_stone := load("res://resources/battle_supplies/stone_volley.tres") as BattleSupplyData
	var supply_rage := load("res://resources/battle_supplies/reward_army.tres") as BattleSupplyData
	_check(supply_repair != null and supply_fire != null and supply_drum != null
		and supply_slow != null and supply_stone != null and supply_rage != null, "六件军需资源应可加载")
	if supply_repair != null and supply_fire != null and supply_drum != null \
			and supply_slow != null and supply_stone != null and supply_rage != null:
		_check(supply_repair.is_valid() and supply_fire.is_valid() and supply_drum.is_valid()
			and supply_slow.is_valid() and supply_stone.is_valid() and supply_rage.is_valid(),
			"军需资源配置应有效")
		_check(supply_repair.heal_at(1) == 10 and supply_repair.heal_at(3) == 14
			and supply_fire.instant_magic_at(1) == 50 and supply_fire.burn_dps_at(3) == 40
			and is_equal_approx(supply_drum.attack_speed_bonus_at(1), 0.30)
			and is_equal_approx(supply_slow.slow_factor_at(3), 0.45)
			and supply_stone.instant_physical_at(3) == 110 and supply_rage.rage_gain_at(2) == 28,
			"军需逐级效果数值应已配置（NUMBERS 10.15）")
	# 灼烧（火攻）：每秒 burn_dps 持续扣血，25/s × 3s = 75。
	var burn_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
	_check(burn_target != null, "灼烧用例应能生成敌人")
	if burn_target != null:
		burn_target.set_process(false)
		burn_target.current_hp = burn_target.max_hp
		burn_target.apply_burn(25, 3.0)
		for _i in range(60):
			burn_target._process(0.05)
		var burn_dealt := burn_target.max_hp - burn_target.current_hp
		_check(abs(burn_dealt - 75) <= 1, "灼烧 3 秒应造成约 75 点伤害（实际 %d）" % burn_dealt)
		burn_target.die(false)

	# 军功上报链路（✅ 0.8.16 / NUMBERS 10.15）：击杀 → GameManager._report_merit → 战局，含难度倍率。
	var merit_session := BattleSession.create("smoke_merit_stage", ["guan_yu"])
	GameManager.set_battle_session(merit_session)
	GameFlow.selected_difficulty = Difficulty.NORMAL
	var merit_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
	_check(merit_enemy != null, "军功用例应能生成敌人")
	if merit_enemy != null:
		merit_enemy.take_damage(9999, "guan_yu")
		_check(merit_session.get_pending_merit() == 1, "击杀步卒应上报 1 军功（标准 ×1.0）")
	GameFlow.selected_difficulty = Difficulty.HARD
	var hard_merit_session := BattleSession.create("smoke_merit_hard", ["guan_yu"])
	GameManager.set_battle_session(hard_merit_session)
	for _merit_index in range(2):
		var hard_merit_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		if hard_merit_enemy != null:
			hard_merit_enemy.take_damage(9999, "guan_yu")
	_check(hard_merit_session.get_pending_merit() == 3,
		"困难击杀 2 名步卒应累计 roundi(1.5 × 2) = 3（精确累计，逐笔取整会得 4）")
	GameFlow.selected_difficulty = Difficulty.NORMAL
	GameManager.set_battle_session(null)

	# 掷石齐射（✅ 0.8.16 / STATS_PIPELINE v0.7）：军需独立来源物理直伤，按护甲结算、不经塔任何桶。
	if supply_stone != null:
		var strike_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		if strike_target != null:
			strike_target.set_process(false)
			var strike_hp_before := strike_target.current_hp
			main._apply_battle_supply(supply_stone, 1)
			_check(strike_hp_before - strike_target.current_hp == 60,
				"掷石齐射 L1 应对 0 甲目标造成 60 物理伤害（实为 %d）" % (strike_hp_before - strike_target.current_hp))
			strike_target.die(false)
		var armored_data := load("res://resources/enemies/yellow_turban/yellow_turban_sergeant.tres") as EnemyData
		var armored_target := enemy_manager.spawn_enemy_from_data(armored_data) as Enemy
		if armored_target != null:
			armored_target.set_process(false)
			var armored_hp_before := armored_target.current_hp
			main._apply_battle_supply(supply_stone, 1)
			_check(armored_hp_before - armored_target.current_hp == 52,
				"掷石齐射应按护甲结算（8 甲：60 ×(1 − 8/58) ≈ 52，实为 %d）"
					% (armored_hp_before - armored_target.current_hp))
			armored_target.die(false)
	# 犒军（✅ 0.8.16 / STATS_PIPELINE v0.7）：直接加怒固定值——不吃科技 rage_gain_pct、不吃月幕倍率。
	if supply_rage != null and tower_manager.get_child_count() > 0:
		var rage_tower := tower_manager.get_child(0) as Tower
		if rage_tower != null:
			rage_tower.rage = 0.0
			rage_tower._tech_rage_gain_pct = 0.5
			main._apply_battle_supply(supply_rage, 1)
			_check(is_equal_approx(rage_tower.rage, 20.0),
				"犒军 L1 应直接 +20 怒气（不吃科技怒气%% 与月幕倍率，实为 %.1f）" % rage_tower.rage)
			rage_tower._tech_rage_gain_pct = 0.0
			rage_tower.rage = 0.0
	# 满生命禁修整（NUMBERS 10.15 边界规则）：满血使用被拒、次数不消耗；非满血正常生效。
	if supply_repair != null:
		main._supply_purchased["repair"] = 1
		GameManager.lives = GameManager.starting_lives
		var full_lives := GameManager.lives
		main._use_battle_supply("repair")
		_check(GameManager.lives == full_lives and main._supply_uses_left("repair") == 1,
			"满生命时修整应被拒绝（次数不消耗）")
		var wounded_lives := maxi(GameManager.starting_lives - 12, 1)
		GameManager.lives = wounded_lives
		main._use_battle_supply("repair")
		_check(GameManager.lives == wounded_lives + 10, "非满生命时修整应 +10 基地生命")
		main._supply_purchased.erase("repair")
		GameManager.lives = GameManager.starting_lives

	# 等级曲线（GDD modules/NUMBERS.md 10.1）
	_check(LevelCurve.exp_total_for_level(10) == 1440, "10 级累计经验应为 1440")
	_check(LevelCurve.level_from_total_exp(0) == 1, "0 经验应为 1 级")
	_check(LevelCurve.level_from_total_exp(1439) == 9 and LevelCurve.level_from_total_exp(1440) == 10,
		"等级应按累计经验推导")
	_check(LevelCurve.level_from_total_exp(999999) == LevelCurve.max_level(), "等级不应超过上限")

	# 等级与转职属性应用（GDD 4.4/4.5）：伤害 = (基础 + 成长×(级-1)) × 转职倍率
	var charger := load("res://resources/promotions/cavalry_iron_rider.tres") as PromotionData
	_check(charger != null and not charger.item_costs.is_empty(), "一转配置应含材料消耗")
	GameManager.reset(9999, 20, stage_data.waves.size())
	var leveled_tower: Tower = tower_manager.build_tower(Vector2(60, 640), guan_yu, null, {"level": 10, "promotion": charger})
	_check(leveled_tower != null, "应以等级/转职参数建造武将塔")
	if leveled_tower:
		var expected_damage := int(round((guan_yu.base_damage + guan_yu.damage_growth_per_level * 9) * charger.damage_multiplier))
		_check(leveled_tower.damage == expected_damage, "10 级 + 铁骑伤害应为 %d" % expected_damage)
		_check(is_equal_approx(leveled_tower.attack_cooldown, guan_yu.attack_interval * charger.attack_interval_multiplier),
			"转职攻速倍率应生效")
		leveled_tower.queue_free()
	var fresh_tower: Tower = tower_manager.build_tower(Vector2(140, 640), guan_yu, null, {"level": 1})
	_check(fresh_tower != null and fresh_tower.damage == guan_yu.base_damage, "1 级无转职应为基础伤害")
	if fresh_tower:
		fresh_tower.queue_free()

	# 投石车（v0.11.1）：职业倍率、min_range 门控、抛射 AOE。
	var huang_fu_song := load("res://resources/characters/huang_fu_song.tres") as CharacterData
	_check(huang_fu_song != null, "皇甫嵩数据应可加载")
	if huang_fu_song != null:
		var catapult_tower: Tower = tower_manager.build_tower(Vector2(60, 100), huang_fu_song, null, {"level": 1})
		_check(catapult_tower != null, "应能建造投石车")
		if catapult_tower:
			_check(catapult_tower.damage == 136 and catapult_tower.range_radius == 360.0
				and is_equal_approx(catapult_tower.attack_cooldown, 2.4),
				"投石车应按 .tres 绝对值配置（136 伤/360 程/2.4s 攻速）")
			catapult_tower.set_process(false)
			var close_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
			close_enemy.set_process(false)
			close_enemy.global_position = catapult_tower.global_position + Vector2(100, 0)
			_check(catapult_tower.find_target() == null, "投石车应无法选取最小射程内的目标")
			var aoe_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
			aoe_target.set_process(false)
			aoe_target.global_position = catapult_tower.global_position + Vector2(250, 0)
			_check(catapult_tower.find_target() == aoe_target, "投石车应能选取射程内且不小于最小射程的目标")
			# 抛射 AOE：预判落点附近的第二只敌人同时受创。
			# 用 300HP 伍长做靶（投石车 136 伤会秒杀步卒，导致目标被释放）。
			var sergeant_data := load("res://resources/enemies/yellow_turban/yellow_turban_sergeant.tres") as EnemyData
			var splash_enemy := enemy_manager.spawn_enemy_from_data(sergeant_data) as Enemy
			splash_enemy.set_process(false)
			splash_enemy.global_position = aoe_target.global_position + Vector2(60, 0)
			var aoe_bearer := enemy_manager.spawn_enemy_from_data(sergeant_data) as Enemy
			aoe_bearer.set_process(false)
			aoe_bearer.global_position = aoe_target.global_position
			catapult_tower.target = aoe_bearer
			catapult_tower.attack()
			for _i in range(80):
				await get_tree().physics_frame
			_check(is_instance_valid(aoe_bearer) and aoe_bearer.current_hp < aoe_bearer.max_hp,
				"抛射应命中预判落点附近的目标")
			_check(is_instance_valid(splash_enemy) and splash_enemy.current_hp < splash_enemy.max_hp,
				"落点范围伤害应波及邻近敌人")
			catapult_tower.queue_free()


	# 虎贲职业克制（GDD 4.2，profession_id=tiger_guard）：对 cavalry 标签敌人伤害 +15%。
	_check(is_equal_approx(
		BehaviorRegistry.get_profession_counter(&"tiger_guard", [&"cavalry"] as Array[StringName]), 1.15
	), "虎贲对骑兵标签应有 1.15 克制倍率")
	_check(is_equal_approx(
		BehaviorRegistry.get_profession_counter(&"tiger_guard", [&"infantry"] as Array[StringName]), 1.0
	), "虎贲对步兵标签应无克制")
	_check(is_equal_approx(
		BehaviorRegistry.get_profession_counter(&"cavalry", [&"cavalry"] as Array[StringName]), 1.0
	), "其他职业不应触发虎贲克制")

	# 伤害类型与护甲结算（NUMBERS 10.12，✅ 0.8.13.0；§4.4 算例逐条）。
	var armor_probe_data := EnemyData.new()
	armor_probe_data.enemy_id = &"smoke_armor_probe"
	armor_probe_data.display_name = "护甲算例桩"
	armor_probe_data.max_hp = 100000
	armor_probe_data.move_speed = 0.0
	armor_probe_data.currency_reward = 0
	var armor_probe := enemy_manager.spawn_enemy_from_data(armor_probe_data) as Enemy
	if armor_probe != null:
		armor_probe.set_process(false)
		armor_probe.armor = 0
		var probe_before := armor_probe.current_hp
		armor_probe.take_damage(1000)
		_check(probe_before - armor_probe.current_hp == 1000, "护甲算例：无甲 1000 伤害应满伤")
		armor_probe.armor = 10
		probe_before = armor_probe.current_hp
		armor_probe.take_damage(1000)
		_check(probe_before - armor_probe.current_hp == 833, "护甲算例：甲 10 物理应 ×(1−10/60) = 833")
		probe_before = armor_probe.current_hp
		armor_probe.take_damage(1000, "", DamageTypes.MAGIC)
		_check(probe_before - armor_probe.current_hp == 909, "护甲算例：甲 10 魔法应 ×(1−5/55) = 909")
		armor_probe.armor = 20
		probe_before = armor_probe.current_hp
		armor_probe.take_damage(1000)
		_check(probe_before - armor_probe.current_hp == 714, "护甲算例：甲 20 物理应 ×(1−20/70) = 714")
		armor_probe.armor = 30
		probe_before = armor_probe.current_hp
		armor_probe.take_damage(1000)
		_check(probe_before - armor_probe.current_hp == 625, "护甲算例：甲 30 物理应 ×(1−30/80) = 625")
		probe_before = armor_probe.current_hp
		armor_probe.take_damage(1000, "", DamageTypes.PHYSICAL, {"a": 0.20, "b": 0.25}, 0)
		_check(probe_before - armor_probe.current_hp == 735, "护甲算例：甲 30 + 双源穿甲 20%/25% 乘算应 = 735")
		probe_before = armor_probe.current_hp
		armor_probe.take_damage(1000, "", DamageTypes.PHYSICAL, {"a": 0.20}, 0)
		_check(probe_before - armor_probe.current_hp == 676, "护甲算例：同源取最高（20%）不连乘应 = 676")
		probe_before = armor_probe.current_hp
		armor_probe.take_damage(1000, "", DamageTypes.PHYSICAL, {"a": 0.20}, 4)
		_check(probe_before - armor_probe.current_hp == 714, "护甲算例：固定穿透在百分比之后（24−4=20）应 = 714")
		probe_before = armor_probe.current_hp
		armor_probe.take_damage(1000, "", DamageTypes.PHYSICAL, {"a": 0.5}, 0)
		_check(probe_before - armor_probe.current_hp == 704, "护甲算例：单源穿甲应 clamp ≤30%（甲 30 → 21）应 = 704")
		probe_before = armor_probe.current_hp
		armor_probe.take_damage(1000, "", DamageTypes.TRUE)
		_check(probe_before - armor_probe.current_hp == 1000, "护甲算例：真实伤害应无视护甲与减伤")
		armor_probe.queue_free()

	# 0.8.13.1（NUMBERS 10.12 / ENEMIES 5.5.5）：第一章全敌甲值表逐敌断言。
	# B-059 回归护栏：黄巾力士 .tres 曾因 armor 键重复（10 后跟旧 0）静默回退为 0。
	var c13_armor_table := {
		"yellow_turban_soldier": 0,
		"yellow_turban_archer": 0,
		"yellow_turban_cavalry": 2,
		"yellow_turban_sorcerer": 4,
		"yellow_turban_sergeant": 8,
		"yellow_turban_berserker": 10,
		"yellow_turban_general": 20,
		"yellow_turban_stealth_assassin": 0,
	}
	for c13_armor_id in c13_armor_table:
		var c13_armor_enemy := load("res://resources/enemies/yellow_turban/%s.tres" % c13_armor_id) as EnemyData
		_check(c13_armor_enemy != null, "第一章敌人数据应可加载: %s" % c13_armor_id)
		if c13_armor_enemy != null:
			var c13_armor_expected := int(c13_armor_table[c13_armor_id])
			_check(c13_armor_enemy.armor == c13_armor_expected,
				"%s 甲值应为 %d（实为 %d，B-059）" % [c13_armor_id, c13_armor_expected, c13_armor_enemy.armor])

	# 隐匿与破隐（NUMBERS 10.16，✅ 0.8.13.1）：索敌过滤 / 三条破隐来源 / 范围盲压双路径。
	var c13_stealth_data := load("res://resources/enemies/yellow_turban/yellow_turban_stealth_assassin.tres") as EnemyData
	_check(c13_stealth_data != null and c13_stealth_data.stealth, "夜行刺应配置 stealth = true")
	if c13_stealth_data != null:
		_check(c13_stealth_data.max_hp == 260 and is_equal_approx(c13_stealth_data.move_speed, 100.0)
			and c13_stealth_data.armor == 0 and c13_stealth_data.damage_to_base == 4
			and c13_stealth_data.currency_reward == 25 and c13_stealth_data.kill_xp == 22,
			"夜行刺数值应按 NUMBERS 10.16（260HP / 100 速 / 0 甲 / 漏 4 / 25 金 / 22 经验）")
		var c13_probe := enemy_manager.spawn_enemy_from_data(c13_stealth_data) as Enemy
		_check(c13_probe != null and c13_probe.is_stealthed(), "夜行刺生成后应处于隐匿")
		GameManager.gold = 9999
		var c13_watch: Tower = tower_manager.build_tower(Vector2(64, 704), guan_yu, null, {"level": 1})
		if c13_probe != null and c13_watch != null:
			c13_watch.set_process(false)
			c13_probe.set_process(false)
			c13_probe.global_position = c13_watch.global_position + Vector2(80, 0)
			_check(not c13_watch.reveals_stealth(), "未破隐的塔不应持有破隐")
			_check(not c13_probe.is_visible_to(c13_watch), "隐匿单位对未破隐的塔应不可见")
			_check(c13_watch.find_target() == null, "未破隐的塔不应选中隐匿单位（find_target 过滤）")
			_check(c13_watch.enemies_in_range().has(c13_probe),
				"范围查询 enemies_in_range 应仍包含隐匿单位（范围盲压双路径）")
			# 破隐来源 2：限时全图（诸葛亮·借东风）。
			c13_watch.apply_stealth_reveal_buff("char_borrow_wind", 5.0)
			_check(c13_watch.reveals_stealth(), "限时破隐 buff 应使塔持有破隐")
			_check(c13_probe.is_visible_to(c13_watch), "持破隐的塔应可见隐匿单位")
			_check(c13_watch.find_target() == c13_probe, "持破隐的塔应能选中隐匿单位")
			c13_probe.refresh_stealth_reveal()
			_check(c13_probe.is_revealed(), "进入破隐覆盖后隐匿单位应现形")
			c13_watch.queue_free()
		if c13_probe != null:
			c13_probe.queue_free()
		# 破隐来源 1：黄忠固有（trait_params.reveal_stealth，覆盖 = 自身射程）。
		var c13_sentry_data := load("res://resources/characters/huang_zhong.tres") as CharacterData
		_check(c13_sentry_data != null
			and float(c13_sentry_data.trait_params.get("reveal_stealth", 0.0)) > 0.0,
			"黄忠应配置固有破隐特性参数（trait_params.reveal_stealth）")
		var c13_sentry: Tower = tower_manager.build_tower(Vector2(320, 704), c13_sentry_data, null, {"level": 1})
		if c13_sentry != null:
			c13_sentry.set_process(false)
			_check(c13_sentry.has_inherent_reveal() and c13_sentry.reveals_stealth(),
				"黄忠塔应带固有破隐（has_inherent_reveal / reveals_stealth）")
			c13_sentry.queue_free()
		# 破隐来源 2 数据面：借东风暴露 reveal_stealth 参数（SkillRegistry 读取）。
		var c13_zhuge := load("res://resources/characters/zhuge_liang.tres") as CharacterData
		_check(c13_zhuge != null
			and float(c13_zhuge.character_skill_params.get("reveal_stealth", 0.0)) > 0.0,
			"诸葛亮·借东风应暴露 reveal_stealth 参数")
	# 破隐来源 3：貂蝉局内 3 阶光环（半径 = 舞娘射程）——走真实升阶路径，
	# 不手动调 refresh_aura_damage_bonus()，守卫「升阶即时刷新光环」（BUGS B-060）。
	var c13_dancer_data := load("res://resources/characters/diao_chan.tres") as CharacterData
	var c13_dancer: Tower = tower_manager.build_tower(Vector2(560, 704), c13_dancer_data, null, {"level": 1})
	var c13_ally: Tower = tower_manager.build_tower(Vector2(640, 704), liu_bei, null, {"level": 1})
	if c13_dancer != null and c13_ally != null:
		c13_dancer.set_process(false)
		c13_ally.set_process(false)
		_check(not c13_ally.reveals_stealth(), "2 阶及以下的舞娘不应提供破隐光环")
		var c13_rank_start := c13_dancer.battle_rank
		var c13_upgraded := true
		while c13_dancer.battle_rank < Tower.DANCER_REVEAL_RANK:
			if not tower_manager.upgrade_tower(c13_dancer, stage_data):
				c13_upgraded = false
				break
		_check(c13_upgraded and c13_dancer.battle_rank == Tower.DANCER_REVEAL_RANK,
			"舞娘应能由 %d 阶升到 %d 阶破隐档" % [c13_rank_start, Tower.DANCER_REVEAL_RANK])
		_check(c13_dancer.reveals_stealth(), "3 阶舞娘自身应持有破隐（升阶即时刷新光环，B-060）")
		_check(c13_ally.reveals_stealth(), "3 阶舞娘射程内的友方应获得破隐（升阶即时刷新光环，B-060）")
		c13_dancer.queue_free()
		c13_ally.queue_free()



	# 0.8.13.2（NUMBERS 10.17）：第一章新精英四类数值 + 甲光环（armor_aura）机制。
	var c132_new_table := {
		"yellow_turban_heavy_berserker": {"hp": 640, "speed": 42.0, "armor": 22, "leak": 3, "gold": 25, "xp": 30},
		"yellow_turban_elite_sergeant": {"hp": 420, "speed": 62.0, "armor": 8, "leak": 3, "gold": 25, "xp": 32},
		"yellow_turban_stealth_healer": {"hp": 240, "speed": 58.0, "armor": 2, "leak": 3, "gold": 25, "xp": 26},
		"yellow_turban_armor_aura_caster": {"hp": 260, "speed": 50.0, "armor": 6, "leak": 3, "gold": 25, "xp": 24},
	}
	for c132_id in c132_new_table:
		var c132_data := load("res://resources/enemies/yellow_turban/%s.tres" % c132_id) as EnemyData
		_check(c132_data != null, "0.8.13.2 新精英应可加载: %s" % c132_id)
		if c132_data == null:
			continue
		var c132_exp: Dictionary = c132_new_table[c132_id]
		_check(c132_data.max_hp == int(c132_exp["hp"])
			and is_equal_approx(c132_data.move_speed, float(c132_exp["speed"]))
			and c132_data.armor == int(c132_exp["armor"])
			and c132_data.damage_to_base == int(c132_exp["leak"])
			and c132_data.currency_reward == int(c132_exp["gold"])
			and c132_data.kill_xp == int(c132_exp["xp"]),
			"%s 数值应按 NUMBERS 10.17（HP 640/420/240/260 组）" % c132_id)
		if c132_id == "yellow_turban_stealth_healer":
			_check(c132_data.stealth and c132_data.special_behavior_id == &"healer_aura"
				and int(c132_data.special_params.get("amount", 0)) == 20
				and is_equal_approx(float(c132_data.special_params.get("radius", 0.0)), 140.0)
				and is_equal_approx(float(c132_data.special_params.get("interval", 0.0)), 2.5),
				"隐方士应以 special_params 覆盖 healer_aura（2.5s / 20 / 140px，B.3.2）")
		elif c132_id == "yellow_turban_elite_sergeant":
			_check(c132_data.special_behavior_id == &"armor_aura"
				and int(c132_data.special_params.get("armor_bonus", 0)) == 6
				and is_equal_approx(float(c132_data.special_params.get("radius", 0.0)), 140.0),
				"精锐伍长应配置军阵光环 armor_aura +6 / 140px")
		elif c132_id == "yellow_turban_armor_aura_caster":
			_check(c132_data.special_behavior_id == &"armor_aura"
				and int(c132_data.special_params.get("armor_bonus", 0)) == 6
				and is_equal_approx(float(c132_data.special_params.get("radius", 0.0)), 160.0),
				"符祭应配置 armor_aura +6 / 160px")

	# 甲光环口径（NUMBERS 10.17）：先加甲后算减伤 / 同源取最大 / 窗口过期恢复 / 半径内覆盖。
	var c132_aura_probe_data := EnemyData.new()
	c132_aura_probe_data.enemy_id = &"smoke_armor_aura_probe"
	c132_aura_probe_data.display_name = "甲光环算例桩"
	c132_aura_probe_data.max_hp = 100000
	c132_aura_probe_data.move_speed = 0.0
	c132_aura_probe_data.currency_reward = 0
	c132_aura_probe_data.armor = 8
	var c132_aura_probe := enemy_manager.spawn_enemy_from_data(c132_aura_probe_data) as Enemy
	if c132_aura_probe != null:
		c132_aura_probe.set_process(false)
		_check(c132_aura_probe.get_effective_armor() == 8, "无光环时有效甲应等于基础甲")
		c132_aura_probe.apply_armor_aura_bonus(6, 3.0)
		_check(c132_aura_probe.get_effective_armor() == 14 and c132_aura_probe.get_armor_aura_bonus() == 6,
			"光环生效时有效甲应为 8 + 6 = 14")
		var c132_aura_before := c132_aura_probe.current_hp
		c132_aura_probe.take_damage(1000)
		_check(c132_aura_before - c132_aura_probe.current_hp == 781,
			"加甲后物理减伤应按有效甲 14 计（×(1−14/64) = 781）")
		c132_aura_probe.apply_armor_aura_bonus(3, 3.0)
		_check(c132_aura_probe.get_armor_aura_bonus() == 6, "同源较弱光环不应覆盖（取最大）")
		c132_aura_probe.apply_armor_aura_bonus(8, 3.0)
		_check(c132_aura_probe.get_armor_aura_bonus() == 8, "同源更强光环应取最大值")
		# 窗口过期：另起短窗口桩（同源刷新取「更晚到期」，长窗口桩无法被缩短）。
		var c132_aura_expire := enemy_manager.spawn_enemy_from_data(c132_aura_probe_data) as Enemy
		if c132_aura_expire != null:
			c132_aura_expire.set_process(false)
			c132_aura_expire.apply_armor_aura_bonus(6, 0.05)
			_check(c132_aura_expire.get_effective_armor() == 14, "短窗口光环应先生效")
			await get_tree().create_timer(0.12).timeout
			_check(c132_aura_expire.get_armor_aura_bonus() == 0 and c132_aura_expire.get_effective_armor() == 8,
				"光环窗口过期应恢复基础甲（施法者阵亡 / 离开半径无需额外清理）")
			c132_aura_expire.queue_free()
		c132_aura_probe.queue_free()

	# 甲光环半径覆盖（EnemyManager._apply_armor_aura）：含自身、覆盖半径内友军、不打半径外。
	var c132_aura_source := enemy_manager.spawn_enemy_from_data(
		load("res://resources/enemies/yellow_turban/yellow_turban_elite_sergeant.tres") as EnemyData) as Enemy
	var c132_aura_near := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
	var c132_aura_far := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
	if c132_aura_source != null and c132_aura_near != null and c132_aura_far != null:
		for c132_aura_unit in [c132_aura_source, c132_aura_near, c132_aura_far]:
			c132_aura_unit.set_process(false)
		c132_aura_source.global_position = Vector2(240, 240)
		c132_aura_near.global_position = Vector2(340, 240)
		c132_aura_far.global_position = Vector2(640, 240)
		enemy_manager._apply_armor_aura(c132_aura_source)
		_check(c132_aura_source.get_armor_aura_bonus() == 6, "甲光环应覆盖施法者自身")
		_check(c132_aura_near.get_armor_aura_bonus() == 6, "甲光环应覆盖 140px 内友军")
		_check(c132_aura_far.get_armor_aura_bonus() == 0, "甲光环不应覆盖 140px 外敌人")
		c132_aura_source.queue_free()
		c132_aura_near.queue_free()
		c132_aura_far.queue_free()

	# 各关波次预算（NUMBERS 10.18 / STAGES §7）：新增波插在验收波之前、编号两位补位、验收波保持末位。
	var c132_wave_counts := {
		"ch01_s01": 6, "ch01_s02": 7, "ch01_s03": 8, "ch01_s04": 9,
		"ch01_s05": 9, "ch01_s06": 10, "ch01_s07": 10, "ch01_s08": 12,
	}
	var c132_stage_enemy_ids := {
		"ch01_s03": ["yellow_turban_elite_sergeant"],
		"ch01_s05": ["yellow_turban_heavy_berserker"],
		"ch01_s06": ["yellow_turban_stealth_assassin"],
		"ch01_s07": ["yellow_turban_armor_aura_caster", "yellow_turban_stealth_healer"],
		"ch01_s08": ["yellow_turban_heavy_berserker", "yellow_turban_elite_sergeant",
			"yellow_turban_stealth_assassin", "yellow_turban_armor_aura_caster", "yellow_turban_stealth_healer", "yellow_turban_heaven_general"],
	}
	for c132_stage_id in c132_wave_counts:
		var c132_stage := load("res://resources/stages/chapter_01/%s.tres" % c132_stage_id) as StageData
		_check(c132_stage != null, "0.8.13.2 关卡应可加载: %s" % c132_stage_id)
		if c132_stage == null:
			continue
		var c132_expected_waves := int(c132_wave_counts[c132_stage_id])
		_check(c132_stage.waves.size() == c132_expected_waves,
			"%s 应有 %d 波（NUMBERS 10.18）" % [c132_stage_id, c132_expected_waves])
		var c132_numbers_ok := true
		var c132_seen_enemy_ids := {}
		for c132_wave_index in range(c132_stage.waves.size()):
			var c132_wave: WaveData = c132_stage.waves[c132_wave_index]
			if c132_wave.wave_number != c132_wave_index + 1 \
					or str(c132_wave.wave_id) != "%s_w%02d" % [c132_stage_id, c132_wave_index + 1]:
				c132_numbers_ok = false
			for c132_group in c132_wave.spawn_groups:
				if c132_group != null and c132_group.enemy != null:
					c132_seen_enemy_ids[str(c132_group.enemy.enemy_id)] = true
		_check(c132_numbers_ok, "%s 波次应从 1 连续编号且 wave_id 两位补位" % c132_stage_id)
		_check(c132_stage.waves[c132_stage.waves.size() - 1].is_boss_wave,
			"%s 验收波应保持在末位（is_boss_wave）" % c132_stage_id)
		for c132_enemy_id in c132_stage_enemy_ids.get(c132_stage_id, []):
			_check(c132_seen_enemy_ids.has(c132_enemy_id), "%s 波次中应出现 %s" % [c132_stage_id, c132_enemy_id])
		# 波次完成奖口径（NUMBERS 5.3）：s01~s03 = 0，s04~s08 = 10——新增波不得引入新经济来源。
		var c132_stage_number := int(c132_stage_id.substr(6, 2))
		var c132_cc_expected := 10 if c132_stage_number >= 4 else 0
		var c132_cc_ok := true
		for c132_wave in c132_stage.waves:
			if c132_wave.completion_currency != c132_cc_expected:
				c132_cc_ok = false
		_check(c132_cc_ok, "%s 波次完成奖应统一为 %d（NUMBERS 5.3）" % [c132_stage_id, c132_cc_expected])

	# 0.8.13.3 s03 Boss 波（张梁复用不改）：新增 w07 前哨压力波，原 w07 验收编成顺延为 w08 Boss 验收波。
	# 口径见 NUMBERS 10.18·10.19 / STAGES §7 / ENEMIES 5.5.5；s03 未配岔路 → 召唤护卫走主路降级。
	var c133_s03 := load("res://resources/stages/chapter_01/ch01_s03.tres") as StageData
	_check(c133_s03 != null, "0.8.13.3 s03 关卡应可加载")
	if c133_s03 != null:
		_check(c133_s03.waves.size() == 8, "s03 应为 8 波（0.8.13.3 +1 Boss 波，NUMBERS 10.18）")
		var c133_last: WaveData = c133_s03.waves[c133_s03.waves.size() - 1]
		_check(str(c133_last.wave_id) == "ch01_s03_w08" and c133_last.wave_number == 8,
			"s03 末波应为 w08（wave_id 两位补位 / 编号连续）")
		_check(c133_last.is_boss_wave, "s03 末波应保持 Boss/验收波标记")
		var c133_general_groups := 0
		for c133_group in c133_last.spawn_groups:
			if c133_group != null and c133_group.enemy != null \
					and str(c133_group.enemy.enemy_id) == "yellow_turban_general":
				c133_general_groups += 1
		_check(c133_general_groups == 1, "s03 末波应含 1 组黄巾渠帅·张梁")
		# w07 前哨压力波：精锐伍长 ×2（军阵光环压力，衔接 w06 观察波）。
		var c133_w07: WaveData = c133_s03.waves[6]
		var c133_elite_total := 0
		for c133_group in c133_w07.spawn_groups:
			if c133_group != null and c133_group.enemy != null \
					and str(c133_group.enemy.enemy_id) == "yellow_turban_elite_sergeant":
				c133_elite_total += int(c133_group.count)
		_check(str(c133_w07.wave_id) == "ch01_s03_w07" and not c133_w07.is_boss_wave \
				and c133_elite_total == 2, "s03 w07 应为精锐伍长 ×2 前哨压力波")
		_check(c133_s03.fork_path_points.is_empty(), "s03 应沿用主路（岔路试点仅 s08）")
		# 张梁数值锚点（复用不改）：数值/行为与 ENEMIES 5.5.5 / NUMBERS 10.19 一致。
		var c133_general := load("res://resources/enemies/yellow_turban/yellow_turban_general.tres") as EnemyData
		_check(c133_general != null and c133_general.max_hp == 3000 and c133_general.armor == 20 \
				and c133_general.damage_to_base == 10 and c133_general.currency_reward == 100 \
				and c133_general.kill_xp == 150 and c133_general.tags.has(&"boss") \
				and c133_general.special_behavior_id == &"summon_guard",
			"张梁应保持复用不改（3000HP / 甲 20 / 漏 10 / 金 100 / 经验 150 / summon_guard / boss）")
		# 召唤护卫（无岔路降级）：护卫标记召唤物 + 自 Boss 身后 60px 沿主路入场。
		if c133_general != null:
			_check(enemy_manager.fork_path == null, "冒烟场景（s01）应无岔路（主路降级用例前置）")
			var c133_boss := enemy_manager.spawn_enemy_from_data(c133_general) as Enemy
			_check(c133_boss != null, "张梁应可在冒烟场景生成")
			if c133_boss != null:
				c133_boss.set_process(false)
				c133_boss.progress = 200.0
				var c133_before: Array[int] = []
				for c133_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
					c133_before.append(c133_node.get_instance_id())
				enemy_manager._summon_guards(c133_boss)
				var c133_guards: Array[Enemy] = []
				for c133_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
					if not c133_before.has(c133_node.get_instance_id()):
						c133_guards.append(c133_node as Enemy)
				var c133_summon_count := int(GameBalance.get_balance().summon_count)
				_check(c133_guards.size() == c133_summon_count,
					"张梁应召唤 %d 名护卫（BalanceData.summon_count）" % c133_summon_count)
				var c133_guards_ok := not c133_guards.is_empty()
				for c133_guard in c133_guards:
					if c133_guard == null or not c133_guard.is_summon \
							or not is_equal_approx(c133_guard.progress, 140.0):
						c133_guards_ok = false
				_check(c133_guards_ok, "无岔路时护卫应标记召唤物并出现在 Boss 身后 60px（主路）")
				for c133_guard in c133_guards:
					if c133_guard != null:
						c133_guard.queue_free()
				c133_boss.queue_free()

	# 0.8.13.4 中 Boss 张宝与 s06/s07 Boss 波（NUMBERS 10.20 / STAGES §7 / ENEMIES 5.5.5）。
	# 波次：s06/s07 各 10 波；s06 w10 = 张宝 + 原验收（Boss 波）；s07 w09 双源压力波、w10 验收顺延。
	var c134_s06 := load("res://resources/stages/chapter_01/ch01_s06.tres") as StageData
	_check(c134_s06 != null and c134_s06.waves.size() == 10, "s06 应为 10 波（0.8.13.4 +1，NUMBERS 10.18）")
	if c134_s06 != null:
		var c134_s06_last: WaveData = c134_s06.waves[9]
		_check(str(c134_s06_last.wave_id) == "ch01_s06_w10" and c134_s06_last.wave_number == 10 \
				and c134_s06_last.is_boss_wave,
			"s06 末波应为 w10 Boss 验收（wave_id 两位补位 / is_boss_wave 保留）")
		var c134_zb_groups := 0
		for c134_group in c134_s06_last.spawn_groups:
			if c134_group != null and c134_group.enemy != null \
					and str(c134_group.enemy.enemy_id) == "yellow_turban_rebel_general":
				c134_zb_groups += 1
		_check(c134_zb_groups == 1, "s06 末波应含 1 组黄巾地公将军·张宝")
		if not c134_s06_last.spawn_groups.is_empty():
			var c134_first_group: EnemySpawnData = c134_s06_last.spawn_groups[0]
			_check(c134_first_group != null and c134_first_group.enemy != null \
					and str(c134_first_group.enemy.enemy_id) == "yellow_turban_rebel_general",
				"张宝应为 s06 末波首发组（delay 0，塔优先索敌）")
		var c134_s06_w09: WaveData = c134_s06.waves[8]
		var c134_w09_stealth := 0
		for c134_group in c134_s06_w09.spawn_groups:
			if c134_group != null and c134_group.enemy != null and c134_group.enemy.stealth:
				c134_w09_stealth += int(c134_group.count)
		_check(str(c134_s06_w09.wave_id) == "ch01_s06_w09" and not c134_s06_w09.is_boss_wave \
				and c134_w09_stealth == 4,
			"s06 w09 应为夜行刺 ×4 隐匿压力波（实为 %d 隐匿）" % c134_w09_stealth)

	var c134_s07 := load("res://resources/stages/chapter_01/ch01_s07.tres") as StageData
	_check(c134_s07 != null and c134_s07.waves.size() == 10, "s07 应为 10 波（0.8.13.4 +1，NUMBERS 10.18）")
	if c134_s07 != null:
		var c134_s07_last: WaveData = c134_s07.waves[9]
		_check(str(c134_s07_last.wave_id) == "ch01_s07_w10" and c134_s07_last.wave_number == 10 \
				and c134_s07_last.is_boss_wave,
			"s07 末波应为 w10 验收顺延（is_boss_wave 保留、无 Boss）")
		var c134_s07_w09: WaveData = c134_s07.waves[8]
		var c134_s07_kinds := {}
		for c134_group in c134_s07_w09.spawn_groups:
			if c134_group != null and c134_group.enemy != null:
				c134_s07_kinds[str(c134_group.enemy.enemy_id)] = true
		_check(str(c134_s07_w09.wave_id) == "ch01_s07_w09" and not c134_s07_w09.is_boss_wave \
				and c134_s07_kinds.has("yellow_turban_armor_aura_caster") \
				and c134_s07_kinds.has("yellow_turban_stealth_healer") \
				and c134_s07_kinds.has("yellow_turban_stealth_assassin"),
			"s07 w09 应为符祭 / 隐方士 / 夜行刺双源压力波")

	# 张宝数值锚点（NUMBERS 10.20 / ENEMIES 5.5.5）：HP 4200 重标（草案 2200~2800 作废）。
	var c134_zhang_bao := load("res://resources/enemies/yellow_turban/yellow_turban_rebel_general.tres") as EnemyData
	_check(c134_zhang_bao != null and c134_zhang_bao.max_hp == 4200 and c134_zhang_bao.armor == 18 \
			and is_equal_approx(c134_zhang_bao.move_speed, 28.0) and c134_zhang_bao.damage_to_base == 8 \
			and c134_zhang_bao.currency_reward == 80 and c134_zhang_bao.kill_xp == 120 \
			and c134_zhang_bao.tags.has(&"boss") and c134_zhang_bao.special_behavior_id == &"summon_guard",
		"张宝数值应按 NUMBERS 10.20（4200HP / 速 28 / 甲 18 / 漏 8 / 金 80 / 经验 120 / boss）")
	if c134_zhang_bao != null:
		_check(c134_zhang_bao.extra_behavior_ids.has(&"healer_aura") \
				and c134_zhang_bao.extra_behavior_ids.has(&"seal_domain"),
			"张宝应为多行为（附加 healer_aura / seal_domain）")
		# 模板合并（B-062）：附加行为字段随模板合并安全读取（EnemyTemplateData 已补齐）。
		var c134_template := load("res://resources/enemy_templates/heavy_cavalry.tres") as EnemyTemplateData
		if c134_template != null:
			var c134_derived := EnemyData.new()
			c134_derived.template = c134_template
			c134_derived.extra_behavior_ids = [&"probe_multi_behavior"]
			var c134_resolved := c134_derived.resolved()
			_check(c134_resolved != null and c134_resolved.extra_behavior_ids.has(&"probe_multi_behavior"),
				"模板派生应保留派生资源的附加行为（B-062：resolved 不得因模板字段缺失中断）")
			var c134_plain := EnemyData.new()
			c134_plain.template = c134_template
			var c134_plain_resolved := c134_plain.resolved()
			_check(c134_plain_resolved != null and c134_plain_resolved.extra_behavior_ids.is_empty(),
				"模板派生未覆盖附加行为时应为空（B-062）")
		var c134_boss := enemy_manager.spawn_enemy_from_data(c134_zhang_bao) as Enemy
		_check(c134_boss != null, "张宝应可在冒烟场景生成")
		if c134_boss != null:
			c134_boss.set_process(false)
			# 多行为调度：主行为 + 附加行为 = 3 条独立冷却。
			var c134_ids: Array[StringName] = enemy_manager.get_behavior_ids_for(c134_boss)
			_check(c134_ids.size() == 3 and c134_ids.has(&"summon_guard") \
					and c134_ids.has(&"healer_aura") and c134_ids.has(&"seal_domain"),
				"张宝应调度 3 条独立行为（summon_guard + healer_aura + seal_domain）")
			_check(c134_boss.get_special_cooldown(&"healer_aura") > 0.0 \
					and c134_boss.get_special_cooldown(&"seal_domain") > 0.0 \
					and c134_boss.get_special_cooldown(&"healer_aura") == c134_boss.get_special_cooldown(&"seal_domain"),
				"多行为应各自独立初始化冷却")
			# P2 门控（summon_guard_min_hp_ratio = 0.5）：HP >50% 拦截、≤50% 解锁。
			c134_boss.current_hp = c134_boss.max_hp
			_check(not enemy_manager._behavior_phase_ready(c134_boss, &"summon_guard"),
				"张宝 HP >50% 时召唤行为应被阶段门控拦截")
			c134_boss.current_hp = int(c134_boss.max_hp * 0.5)
			_check(enemy_manager._behavior_phase_ready(c134_boss, &"summon_guard"),
				"张宝 HP ≤50% 时召唤行为应解锁（P2）")
			# 召唤参数化 + 上限：夜行刺 ×2 / 上限 4（无岔路时自身后 60px 沿主路出现）。
			c134_boss.progress = 200.0
			enemy_manager._summon_guards(c134_boss)
			var c134_summoned: Array[Enemy] = []
			for c134_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
				var c134_e := c134_node as Enemy
				if c134_e != null and c134_e.is_summon and c134_e.enemy_id == &"yellow_turban_stealth_assassin":
					c134_summoned.append(c134_e)
			_check(c134_summoned.size() == 2, "张宝首次召唤应为夜行刺 ×2（special_params.summon_enemy_id）")
			var c134_summons_ok := c134_summoned.size() == 2
			for c134_e in c134_summoned:
				if not c134_e.stealth or not is_equal_approx(c134_e.progress, 140.0):
					c134_summons_ok = false
			_check(c134_summons_ok, "夜行刺召唤物应隐匿并出现在张宝身后 60px（无岔路主路降级）")
			enemy_manager._summon_guards(c134_boss)
			enemy_manager._summon_guards(c134_boss)
			var c134_total := 0
			for c134_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
				var c134_e := c134_node as Enemy
				if c134_e != null and c134_e.is_summon and c134_e.enemy_id == &"yellow_turban_stealth_assassin":
					c134_total += 1
			_check(c134_total == 4 and c134_boss.summoned_count == 4,
				"张宝召唤应受 max_summons = 4 上限（实为 %d）" % c134_total)
			for c134_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
				var c134_e := c134_node as Enemy
				if c134_e != null and c134_e.is_summon:
					c134_e.queue_free()
			# 术法压制（seal_domain）：范围内塔攻速 ×0.75、同桶下限 -50%、窗口过期恢复。
			var c134_tower: Tower = tower_manager.build_tower(Vector2(64, 704), guan_yu, null, {"level": 1})
			_check(c134_tower != null, "术法压制用例应能建塔")
			if c134_tower != null:
				c134_tower.set_process(false)
				c134_boss.global_position = c134_tower.global_position + Vector2(80, 0)
				enemy_manager._apply_seal_domain(c134_boss)
				_check(is_equal_approx(c134_tower.attack_speed_buff, 0.75),
					"术法压制应使半径内塔攻速 ×0.75（实为 %.3f）" % c134_tower.attack_speed_buff)
				c134_tower.apply_attack_speed_debuff("probe_seal", 0.4, 5.0)
				_check(is_equal_approx(c134_tower.attack_speed_buff, 0.5),
					"多源减益总量应受 -50% 下限（TEAM_DEBUFF_SLOW_CAP）")
				c134_tower.apply_attack_speed_debuff("probe_seal", 0.9, 5.0)
				_check(is_equal_approx(c134_tower.attack_speed_buff, 0.5),
					"同源减益刷新应取更强方向（不因较弱刷新而回撤）")
				c134_tower.apply_attack_speed_buff("probe_buff", 1.6, 5.0)
				_check(is_equal_approx(c134_tower.attack_speed_buff, 0.75),
					"增益与减益应同桶求和（-85% 与 +60% → clamp -25%）")
				c134_tower._process(10.0)
				_check(is_equal_approx(c134_tower.attack_speed_buff, 1.0),
					"减益窗口过期后塔攻速应自动恢复 1.0")
				c134_tower.queue_free()
			c134_boss.queue_free()
	# 0.8.13.5 终 Boss 张角：s08 = 12 波（w11 张梁前置 Boss 波保留 + w12 张角终 Boss 验收波），
	# 三阶段召唤档案（步卒 → 轻骑 → 夜行刺）+ 阶段推进表现 / 输出窗口 + 难度机制旋钮（NUMBERS 10.21~10.23）。
	var c135_s08 := load("res://resources/stages/chapter_01/ch01_s08.tres") as StageData
	_check(c135_s08 != null and c135_s08.waves.size() == 12, "s08 应为 12 波（0.8.13.5 +1，NUMBERS 10.21）")
	if c135_s08 != null:
		var c135_w11: WaveData = c135_s08.waves[10]
		_check(str(c135_w11.wave_id) == "ch01_s08_w11" and c135_w11.is_boss_wave,
			"s08 w11 应保留张梁前置 Boss 波（is_boss_wave / 编成不变）")
		var c135_w11_general := 0
		for c135_group in c135_w11.spawn_groups:
			if (c135_group != null and c135_group.enemy != null
					and str(c135_group.enemy.enemy_id) == "yellow_turban_general"):
				c135_w11_general += 1
		_check(c135_w11_general == 1, "s08 w11 应含 1 组黄巾渠帅·张梁")
		var c135_w12: WaveData = c135_s08.waves[11]
		_check(str(c135_w12.wave_id) == "ch01_s08_w12" and c135_w12.wave_number == 12
				and c135_w12.is_boss_wave,
			"s08 末波应为 w12 终 Boss 验收波（wave_id 两位补位 / is_boss_wave）")
		var c135_w12_kinds := {}
		var c135_w12_total := 0
		for c135_group in c135_w12.spawn_groups:
			if c135_group != null and c135_group.enemy != null:
				c135_w12_kinds[str(c135_group.enemy.enemy_id)] = true
				c135_w12_total += int(c135_group.count)
		_check(c135_w12_total == 15 and c135_w12_kinds.has("yellow_turban_heaven_general")
				and c135_w12_kinds.has("yellow_turban_armor_aura_caster")
				and c135_w12_kinds.has("yellow_turban_stealth_assassin")
				and c135_w12_kinds.has("yellow_turban_soldier"),
			"s08 w12 应为 张角 ×1 + 符祭 ×2 + 夜行刺 ×2 + 步卒 ×10（共 15）")

	var c135_zhang_jiao := load("res://resources/enemies/yellow_turban/yellow_turban_heaven_general.tres") as EnemyData
	_check(c135_zhang_jiao != null and c135_zhang_jiao.max_hp == 8000
			and is_equal_approx(c135_zhang_jiao.move_speed, 26.0) and c135_zhang_jiao.armor == 30
			and c135_zhang_jiao.damage_to_base == 12 and c135_zhang_jiao.currency_reward == 120
			and c135_zhang_jiao.kill_xp == 200 and c135_zhang_jiao.tags.has(&"boss")
			and c135_zhang_jiao.special_behavior_id == &"summon_guard",
		"张角数值应按 NUMBERS 10.21（8000HP / 速 26 / 甲 30 / 漏 12 / 金 120 / 经验 200 / boss）")
	if c135_zhang_jiao != null:
		_check(c135_zhang_jiao.extra_behavior_ids.has(&"armor_aura")
				and c135_zhang_jiao.extra_behavior_ids.has(&"healer_aura")
				and c135_zhang_jiao.extra_behavior_ids.has(&"seal_domain"),
			"张角应为 4 条行为（summon_guard + armor_aura / healer_aura / seal_domain）")
		var c135_hero := enemy_manager.spawn_enemy_from_data(c135_zhang_jiao) as Enemy
		_check(c135_hero != null, "张角应可在冒烟场景生成")
		if c135_hero != null:
			c135_hero.set_process(false)
			# 三阶段档案：取「门控 ≥ 当前 HP 比例」中最紧一档（P1 1.0 / P2 0.66 / P3 0.33）。
			c135_hero.current_hp = c135_hero.max_hp
			_check(enemy_manager._active_summon_profile_index(c135_hero) == 0
					and str(enemy_manager._active_summon_profile(c135_hero).get("enemy_id", "")) == "yellow_turban_soldier",
				"张角满血应命中 P1 档案（步卒 ×2 / 9s / 上限 4）")
			c135_hero.current_hp = int(c135_hero.max_hp * 0.6)
			_check(enemy_manager._active_summon_profile_index(c135_hero) == 1
					and str(enemy_manager._active_summon_profile(c135_hero).get("enemy_id", "")) == "yellow_turban_cavalry",
				"张角 HP 60% 应命中 P2 档案（轻骑 ×2 / 8s）")
			c135_hero.current_hp = int(c135_hero.max_hp * 0.2)
			_check(enemy_manager._active_summon_profile_index(c135_hero) == 2
					and str(enemy_manager._active_summon_profile(c135_hero).get("enemy_id", "")) == "yellow_turban_stealth_assassin",
				"张角 HP 20% 应命中 P3 档案（夜行刺 ×2 / 7s）")
			# 首帧命中不播表现、不推进阶段（-1 → 0 为档案初始化）。
			c135_hero.current_hp = c135_hero.max_hp
			enemy_manager._maybe_advance_phase(c135_hero)
			_check(c135_hero.summon_profile_index == 0 and c135_hero.phase_index == 1
					and c135_hero.summoned_count == 0,
				"张角阶段初始化应命中 P1 且不推进阶段表现（summon_profile_index -1 → 0）")
			# P1 布阵：步卒 ×2 / 9.0s 冷却 / 阶段内上限 4（逐阶段独立配额）。
			c135_hero.progress = 200.0
			var c135_p1_ids: Array[int] = []
			for c135_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
				c135_p1_ids.append(c135_node.get_instance_id())
			enemy_manager._summon_guards(c135_hero)
			var c135_p1_new: Array[Enemy] = []
			for c135_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
				if not c135_p1_ids.has(c135_node.get_instance_id()):
					c135_p1_new.append(c135_node as Enemy)
			var c135_p1_ok := c135_p1_new.size() == 2
			for c135_e in c135_p1_new:
				if (c135_e == null or not c135_e.is_summon
						or c135_e.enemy_id != &"yellow_turban_soldier"
						or not is_equal_approx(c135_e.progress, 140.0)):
					c135_p1_ok = false
			_check(c135_p1_ok and c135_hero.summoned_count == 2
					and is_equal_approx(c135_hero.get_special_cooldown(&"summon_guard"), 9.0),
				"张角 P1 首次召唤应为步卒 ×2（档案 1 / 9.0s 冷却 / Boss 身后 60px）")
			enemy_manager._summon_guards(c135_hero)
			enemy_manager._summon_guards(c135_hero)
			_check(c135_hero.summoned_count == 4, "张角 P1 召唤应受档案上限 4 约束（逐阶段独立配额）")
			# P1 → P2：重置配额 + 阶段表现 + 下一发召唤压后 3.0s 输出窗口。
			c135_hero.set_special_cooldown(&"summon_guard", 0.0)
			c135_hero.current_hp = int(c135_hero.max_hp * 0.6)
			enemy_manager._maybe_advance_phase(c135_hero)
			_check(c135_hero.summon_profile_index == 1 and c135_hero.phase_index == 2
					and c135_hero.summoned_count == 0 and c135_hero._phase_flash_left > 0.0
					and is_equal_approx(c135_hero.get_special_cooldown(&"summon_guard"), 3.0),
				"张角 HP 跌破 66% 应推进 P2：重置配额 / 阶段表现 + 阶段点 / 下一发召唤压后 3.0s")
			var c135_p2_ids: Array[int] = []
			for c135_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
				c135_p2_ids.append(c135_node.get_instance_id())
			enemy_manager._summon_guards(c135_hero)
			var c135_p2_new: Array[Enemy] = []
			for c135_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
				if not c135_p2_ids.has(c135_node.get_instance_id()):
					c135_p2_new.append(c135_node as Enemy)
			var c135_p2_ok := c135_p2_new.size() == 2
			for c135_e in c135_p2_new:
				if c135_e == null or c135_e.enemy_id != &"yellow_turban_cavalry":
					c135_p2_ok = false
			_check(c135_p2_ok and is_equal_approx(c135_hero.get_special_cooldown(&"summon_guard"), 8.0),
				"张角 P2 召唤应为轻骑 ×2（档案 2 / 8.0s 冷却）")
			# P2 → P3：狂雷阶段（术法压制 + 隐匿亲卫）。
			c135_hero.set_special_cooldown(&"summon_guard", 0.0)
			c135_hero.current_hp = int(c135_hero.max_hp * 0.2)
			enemy_manager._maybe_advance_phase(c135_hero)
			_check(c135_hero.summon_profile_index == 2 and c135_hero.phase_index == 3
					and is_equal_approx(c135_hero.get_special_cooldown(&"summon_guard"), 3.0),
				"张角 HP 跌破 33% 应推进 P3（阶段点 3 / 重置配额 / 3.0s 输出窗口）")
			var c135_p3_ids: Array[int] = []
			for c135_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
				c135_p3_ids.append(c135_node.get_instance_id())
			enemy_manager._summon_guards(c135_hero)
			var c135_p3_new: Array[Enemy] = []
			for c135_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
				if not c135_p3_ids.has(c135_node.get_instance_id()):
					c135_p3_new.append(c135_node as Enemy)
			var c135_p3_ok := c135_p3_new.size() == 2
			for c135_e in c135_p3_new:
				if (c135_e == null or not c135_e.stealth
						or c135_e.enemy_id != &"yellow_turban_stealth_assassin"):
					c135_p3_ok = false
			_check(c135_p3_ok and is_equal_approx(c135_hero.get_special_cooldown(&"summon_guard"), 7.0),
				"张角 P3 召唤应为隐匿夜行刺 ×2（档案 3 / 7.0s 冷却）")
			for c135_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
				var c135_e := c135_node as Enemy
				if c135_e != null and c135_e.is_summon:
					c135_e.queue_free()
			c135_hero.queue_free()

	# 难度机制旋钮（NUMBERS 10.23）：标准 1.0/1.0，困难「间隔 ×0.85 / 效果 ×1.25」（含三阶段档案间隔）。
	_check(is_equal_approx(Difficulty.mechanic_interval_mult(Difficulty.NORMAL), 1.0)
			and is_equal_approx(Difficulty.mechanic_effect_mult(Difficulty.NORMAL), 1.0)
			and is_equal_approx(Difficulty.mechanic_interval_mult(Difficulty.HARD), 0.85)
			and is_equal_approx(Difficulty.mechanic_effect_mult(Difficulty.HARD), 1.25),
		"难度机制旋钮应按 NUMBERS 10.23 落库（标准 1.0/1.0 / 困难 0.85/1.25）")
	var c135_hard := enemy_manager.spawn_enemy_from_data(c135_zhang_jiao) as Enemy
	_check(c135_hard != null, "机制旋钮用例应能生成张角")
	if c135_hard != null:
		c135_hard.set_process(false)
		c135_hard.current_hp = c135_hard.max_hp
		enemy_manager._maybe_advance_phase(c135_hard)
		_check(is_equal_approx(enemy_manager._mechanic_interval_mult(), 1.0)
				and is_equal_approx(enemy_manager._mechanic_effect_mult(), 1.0),
			"标准难度机制旋钮应为 1.0 / 1.0（不缩放）")
		_check(is_equal_approx(enemy_manager._behavior_interval(c135_hard, &"seal_domain", "interval", 0.0), 2.0),
			"标准难度下术法压制间隔应保持档案值 2.0s")
		GameFlow.selected_difficulty = Difficulty.HARD
		_check(is_equal_approx(enemy_manager._mechanic_interval_mult(), 0.85)
				and is_equal_approx(enemy_manager._mechanic_effect_mult(), 1.25),
			"困难档机制旋钮应生效（间隔 ×0.85 / 效果 ×1.25）")
		_check(is_equal_approx(enemy_manager._behavior_interval(c135_hard, &"seal_domain", "interval", 0.0), 1.7),
			"困难档术法压制间隔应缩短为 1.7s（2.0 × 0.85）")
		enemy_manager._apply_armor_aura(c135_hard)
		_check(c135_hard.get_armor_aura_bonus() == 8, "困难档甲光环加成应为 +8（+6 × 1.25 取整）")
		enemy_manager._summon_guards(c135_hard)
		_check(is_equal_approx(c135_hard.get_special_cooldown(&"summon_guard"), 7.65),
			"困难档张角 P1 召唤冷却应为 9.0 × 0.85 = 7.65s")
		var c135_tower: Tower = tower_manager.build_tower(Vector2(128, 704), guan_yu, null, {"level": 1})
		_check(c135_tower != null, "机制旋钮用例应能建塔（术法压制幅度）")
		if c135_tower != null:
			c135_tower.set_process(false)
			c135_hard.global_position = c135_tower.global_position + Vector2(80, 0)
			enemy_manager._apply_seal_domain(c135_hard)
			_check(is_equal_approx(c135_tower.attack_speed_buff, 0.5625),
				"困难档术法压制幅度应为 ×0.5625（差额 ×1.25，实为 %.4f）" % c135_tower.attack_speed_buff)
			c135_tower.queue_free()
		GameFlow.selected_difficulty = Difficulty.NORMAL
		for c135_node in get_tree().get_nodes_in_group(Enemy.ENEMY_GROUP):
			var c135_e := c135_node as Enemy
			if c135_e != null and c135_e.is_summon:
				c135_e.queue_free()
		c135_hard.queue_free()

	# 全章数值基准（NUMBERS 10.22，0.8.13.5 断言化）：波数 / 出怪数 / 血池 / 物理等效血池（标准难度）。
	var c135_baseline := {
		"ch01_s01": [6, 62, 6470.0, 6549.0],
		"ch01_s02": [7, 80, 8250.0, 8333.0],
		"ch01_s03": [8, 93, 13220.0, 14687.0],
		"ch01_s04": [9, 95, 12870.0, 13713.0],
		"ch01_s05": [9, 91, 18220.0, 21433.0],
		"ch01_s06": [10, 126, 21740.0, 24234.0],
		"ch01_s07": [10, 120, 16610.0, 17478.0],
		"ch01_s08": [12, 146, 34350.0, 42988.0],
	}
	var c135_total_waves := 0
	var c135_total_spawns := 0
	var c135_total_raw := 0.0
	var c135_total_phys := 0.0
	for c135_stage_id in c135_baseline:
		var c135_stage := load("res://resources/stages/chapter_01/%s.tres" % c135_stage_id) as StageData
		var c135_expected: Array = c135_baseline[c135_stage_id]
		if c135_stage == null:
			_check(false, "全章基准关卡应可加载: %s" % c135_stage_id)
			continue
		var c135_spawns := 0
		var c135_raw := 0.0
		var c135_phys := 0.0
		for c135_wave in c135_stage.waves:
			for c135_group in c135_wave.spawn_groups:
				if c135_group == null or c135_group.enemy == null:
					continue
				var c135_data := c135_group.enemy.resolved()
				var c135_count := int(c135_group.count)
				var c135_hp := float(c135_data.max_hp) * float(c135_count)
				var c135_armor := float(c135_data.armor)
				c135_spawns += c135_count
				c135_raw += c135_hp
				c135_phys += c135_hp / (1.0 - c135_armor / (c135_armor + 50.0))
		c135_total_waves += c135_stage.waves.size()
		c135_total_spawns += c135_spawns
		c135_total_raw += c135_raw
		c135_total_phys += c135_phys
		_check(c135_stage.waves.size() == int(c135_expected[0])
				and c135_spawns == int(c135_expected[1])
				and is_equal_approx(c135_raw, float(c135_expected[2]))
				and absf(c135_phys - float(c135_expected[3])) <= 1.0,
			"%s 数值基准应匹配 NUMBERS 10.22（%d 波 / %d 怪 / 血池 %.0f / 物理等效 %.0f）" % [
				c135_stage_id, int(c135_expected[0]), int(c135_expected[1]),
				float(c135_expected[2]), float(c135_expected[3])])
	_check(c135_total_waves == 71 and c135_total_spawns == 813
			and is_equal_approx(c135_total_raw, 131730.0)
			and absf(c135_total_phys - 149416.0) <= 1.0,
		"全章合计应为 71 波 / 813 怪 / 血池 131730 / 物理等效 149416（NUMBERS 10.22）")

	# 击杀经验归属（GDD 4.4）：步卒 kill_xp=8，关羽最后一击应得 50%+均分 = 6，
	# 刘备参与伤害应得均分 = 2。
	var xp_session := BattleSession.new("smoke_xp_stage")
	GameManager.set_battle_session(xp_session)
	var xp_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
	_check(xp_enemy != null, "经验归属用例应能生成敌人")
	if xp_enemy:
		xp_enemy.take_damage(30, "liu_bei")
		xp_enemy.take_damage(9999, "guan_yu")
		var pending_xp: Dictionary = xp_session.get_pending_xp_by_character()
		_check(int(pending_xp.get("guan_yu", 0)) == 6, "最后一击武将应获得 6 点经验（4 + 均分 2）")
		_check(int(pending_xp.get("liu_bei", 0)) == 2, "参与伤害武将应获得均分 2 点经验")

	# 落后补正（GDD 4.4/10.6）：编队平均 3 级（关羽 5 / 刘备 1）时，1 级武将经验 ×1.4。
	var rb_profile := ProfileStore.get_profile()
	rb_profile.add_character_exp("guan_yu", LevelCurve.exp_total_for_level(5))
	var rb_session := BattleSession.new("smoke_rb_stage")
	GameManager.set_battle_session(rb_session)
	rb_session.deployed_character_ids.assign(["guan_yu", "liu_bei"])
	var rb_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
	if rb_enemy:
		rb_enemy.take_damage(9999, "liu_bei")
		_check(int(rb_session.get_pending_xp_by_character().get("liu_bei", 0)) == 10,
			"落后补正后 1 级武将两笔共得 10 点经验（名义 8 × 1.4，逐笔向下取整）")
		rb_enemy.queue_free()

	# 怒气系统（v0.11.2）：命中积怒（命中 4 + 伤害×0.1）→ 满 100 手动触发大招 → 清零。
	var rage_tower: Tower = tower_manager.build_tower(Vector2(60, 640), guan_yu, null, {"level": 1})
	_check(rage_tower != null, "应能建造怒气用例武将塔")
	if rage_tower != null:
		rage_tower.set_process(false)
		# 移除刘备塔以隔离仁德光环对伤害断言的影响
		for node in tower_manager.get_children():
			var t := node as Tower
			if t != null and t.character_id == "liu_bei":
				t.queue_free()
		await get_tree().process_frame
		# 武生特性：精英标签目标伤害 +25%（64 × 1.25 = 80）
		var rage_target := enemy_manager.spawn_enemy_from_data(load("res://resources/enemies/yellow_turban/yellow_turban_sergeant.tres") as EnemyData) as Enemy
		rage_target.set_process(false)
		rage_target.global_position = rage_tower.global_position + Vector2(120, 0)
		rage_tower.target = rage_target
		rage_tower.attack()
		_check(is_equal_approx(rage_tower.rage, 12.0), "命中积怒应为 4 + 面板伤害×0.1（武生 +25% → 80；怒气按打甲前口径，甲值不减怒）")
		rage_tower.rage = 100.0
		var ult_target := enemy_manager.spawn_enemy_from_data(load("res://resources/enemies/yellow_turban/yellow_turban_sergeant.tres") as EnemyData) as Enemy
		ult_target.set_process(false)
		ult_target.global_position = rage_tower.global_position + Vector2(120, 0)
		rage_tower.target = ult_target
		_check(rage_tower._try_cast_ultimate(), "满怒应能释放大招（突击斩杀）")
		_check(ult_target.current_hp == 300 - 240, "斩杀应造成 3×普攻并含武生特性（240）")
	# ===== v0.15.0 技能注册表与演出测试（GDD modules/BEHAVIORS.md B.3.5） =====
	# 职业技能显示名查询（注册表完整性由下方 v0.28.0 断言覆盖：每职业 1 技能共 6 个）。
	_check(SkillRegistry.get_skill_name(&"charge") == "蓄力" and SkillRegistry.get_skill_name(&"wisdom") == "奇谋",
		"技能显示名应可查询")
	# 档位系数：s = 1 + 0.1 × min(battle_rank/5, 4)。
	var tier_tower: Tower = tower_manager.build_tower(Vector2(240, 640), guan_yu, null, {"level": 1})
	_check(tier_tower != null, "应能建造档位系数用例塔")
	if tier_tower:
		tier_tower.set_process(false)
		tier_tower.battle_rank = 4
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_tower), 1.0), "4 级档位系数应为 1.0")
		tier_tower.battle_rank = 5
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_tower), 1.1), "5 级档位系数应为 1.1")
		tier_tower.battle_rank = 20
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_tower), 1.4), "20 级档位系数应封顶 1.4")
		tier_tower.queue_free()
	# 阶段 7（v0.19.0）：局内遗物伤害加成应进 finalize_damage 乘法区（狼牙符 +5%）。
	GameFlow.set_squad_relics(["wolf_tooth"])
	var relic_probe_tower: Tower = tower_manager.build_tower(Vector2(240, 640), guan_yu, null, {"level": 1})
	_check(relic_probe_tower != null, "应能建造遗物伤害探针塔")
	if relic_probe_tower != null:
		relic_probe_tower.set_process(false)
		var relic_probe_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		relic_probe_enemy.set_process(false)
		var expected_relic_damage := int(round(relic_probe_tower.damage * 1.05))
		_check(relic_probe_tower.finalize_damage(relic_probe_tower.damage, relic_probe_enemy) == expected_relic_damage,
			"狼牙符应使伤害 +5%")
		relic_probe_enemy.queue_free()
		relic_probe_tower.queue_free()
	GameFlow.clear_squad_relics()
	# charge（关羽·铁骑）：大招击杀返怒 50% × s。
	var charge_tower: Tower = tower_manager.build_tower(Vector2(240, 640), guan_yu, null, {"level": 10, "promotion": charger})
	_check(charge_tower != null and charge_tower.has_skill(&"charge"), "铁骑应持有 charge 技能")
	if charge_tower:
		charge_tower.set_process(false)
		_check(is_equal_approx(charge_tower.kill_rage_refund(), 50.0), "charge 基准返怒应为 50")
		charge_tower.battle_rank = 5
		_check(is_equal_approx(charge_tower.kill_rage_refund(), 55.0), "charge 5 级返怒应为 55")
		charge_tower.battle_rank = 20
		_check(is_equal_approx(charge_tower.kill_rage_refund(), 70.0), "charge 20 级返怒应封顶 70")
		charge_tower.battle_rank = 0
		var charge_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		charge_target.set_process(false)
		charge_target.global_position = charge_tower.global_position + Vector2(120, 0)
		charge_tower.target = charge_target
		charge_tower.rage = 100.0
		_check(charge_tower._try_cast_ultimate(), "满怒大招应能释放")
		_check(is_equal_approx(charge_tower.rage, 50.0), "大招击杀应返怒 50（先清怒再返还）")
		charge_tower.battle_rank = 5
		charge_tower.rage = 100.0
		var charge_target_2 := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		charge_target_2.set_process(false)
		charge_target_2.global_position = charge_tower.global_position + Vector2(120, 0)
		charge_tower.target = charge_target_2
		_check(charge_tower._try_cast_ultimate(), "5 级满怒大招应能释放")
		_check(is_equal_approx(charge_tower.rage, 55.0), "5 级 charge 击杀返怒应为 55")
		charge_tower.queue_free()
	# siege（皇甫嵩·霹雳车）：对精英/Boss 伤害 +10% × s。
	var siege_promo := load("res://resources/promotions/catapult_thunder.tres") as PromotionData
	var siege_tower: Tower = tower_manager.build_tower(Vector2(340, 640), huang_fu_song, null, {"level": 10, "promotion": siege_promo})
	var sergeant_data := load("res://resources/enemies/yellow_turban/yellow_turban_sergeant.tres") as EnemyData
	_check(siege_tower != null and siege_tower.has_skill(&"siege"), "霹雳车应持有破城技能")
	if siege_tower:
		siege_tower.set_process(false)
		var siege_elite := enemy_manager.spawn_enemy_from_data(sergeant_data) as Enemy
		var siege_soldier := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		siege_elite.set_process(false)
		siege_soldier.set_process(false)
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(siege_tower, siege_elite), 1.1),
			"破城对精英应 ×1.1")
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(siege_tower, siege_soldier), 1.0),
			"破城对普通目标应无加成")
		siege_tower.battle_rank = 5
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(siege_tower, siege_elite), 1.11),
			"破城 5 阶对精英应 ×1.11（档位按局内升阶）")
		siege_elite.queue_free()
		siege_soldier.queue_free()
		siege_tower.queue_free()
	# wisdom（诸葛亮·方士）：大招范围 +10% × s。
	var zhuge_liang := load("res://resources/characters/zhuge_liang.tres") as CharacterData
	var wisdom_promo := load("res://resources/promotions/strategist_mage.tres") as PromotionData
	var wisdom_tower: Tower = tower_manager.build_tower(Vector2(460, 640), zhuge_liang, null, {"level": 10, "promotion": wisdom_promo})
	_check(wisdom_tower != null and wisdom_tower.has_skill(&"wisdom"), "方士应持有奇谋技能")
	if wisdom_tower:
		wisdom_tower.set_process(false)
		_check(is_equal_approx(wisdom_tower.ultimate_aoe_radius(100.0), 110.0), "奇谋大招范围应 +10%")
		wisdom_tower.battle_rank = 5
		_check(is_equal_approx(wisdom_tower.ultimate_aoe_radius(100.0), 111.0), "奇谋 5 级大招范围应 +11%")
		wisdom_tower.battle_rank = 20
		_check(is_equal_approx(wisdom_tower.ultimate_aoe_radius(100.0), 114.0), "奇谋 20 级大招范围应封顶 +14%")
		wisdom_tower.queue_free()
	# 职业技能注册表（提交 7）：6 核心 + 6 二转新技能；龙突/凶威/斩获已移除。
	_check(SkillRegistry.KNOWN_SKILLS.size() == 12
		and SkillRegistry.KNOWN_SKILLS.has(&"charge") and SkillRegistry.KNOWN_SKILLS.has(&"command")
		and SkillRegistry.KNOWN_SKILLS.has(&"steady") and SkillRegistry.KNOWN_SKILLS.has(&"wisdom")
		and SkillRegistry.KNOWN_SKILLS.has(&"inspire") and SkillRegistry.KNOWN_SKILLS.has(&"siege")
		and SkillRegistry.KNOWN_SKILLS.has(&"assault") and SkillRegistry.KNOWN_SKILLS.has(&"guard")
		and SkillRegistry.KNOWN_SKILLS.has(&"chain_arrow") and SkillRegistry.KNOWN_SKILLS.has(&"mystic_gate")
		and SkillRegistry.KNOWN_SKILLS.has(&"echo") and SkillRegistry.KNOWN_SKILLS.has(&"tremor"),
		"职业技能应为 6 核心 + 6 二转新技能（提交 7）")
	_check(not SkillRegistry.KNOWN_SKILLS.has(&"dragon_rush")
		and not SkillRegistry.KNOWN_SKILLS.has(&"ferocity")
		and not SkillRegistry.KNOWN_SKILLS.has(&"bulwark"), "龙突/凶威/斩获应已移除")
	# 蓄力（赵云·铁骑）：大招击杀返怒 50%（基础，原龙突移除）。
	var zhao_yun := load("res://resources/characters/zhao_yun.tres") as CharacterData
	var dragon_promo := load("res://resources/promotions/cavalry_iron_rider.tres") as PromotionData
	var dragon_tower: Tower = tower_manager.build_tower(Vector2(560, 640), zhao_yun, null, {"level": 10, "promotion": dragon_promo})
	_check(dragon_tower != null and dragon_tower.has_skill(&"charge"), "铁骑应持有蓄力技能")
	if dragon_tower:
		dragon_tower.set_process(false)
		_check(is_equal_approx(dragon_tower.kill_rage_refund(), 50.0), "龙骧卫蓄力基础返怒应为 50%")
		_check(is_equal_approx(float(dragon_tower.get("_next_attack_bonus")), 0.0), "基础蓄力不应附带击杀下一击加成")
		dragon_tower.queue_free()
	# 蓄力+（关羽·玄甲）：二转强化线——大招击杀返怒 70%×s（SKILLS.md 4.1）。
	var heavy_promo := load("res://resources/promotions/cavalry_heavy_armor.tres") as PromotionData
	var heavy_tower: Tower = tower_manager.build_tower(Vector2(560, 640), guan_yu, null, {"level": 20, "promotion": heavy_promo})
	_check(heavy_tower != null and heavy_tower.has_skill(&"charge"), "玄甲应持有蓄力+技能")
	if heavy_tower:
		heavy_tower.set_process(false)
		_check(heavy_tower.get_skill_display_name(&"charge") == "蓄力+", "二转强化技能显示名应加 +")
		_check(is_equal_approx(heavy_tower.kill_rage_refund(), 70.0), "玄甲蓄力+基准返怒应为 70%")
		heavy_tower.battle_rank = 5
		_check(is_equal_approx(heavy_tower.kill_rage_refund(), 77.0), "玄甲 5 阶返怒应为 77%（档位按局内升阶）")
		heavy_tower.battle_rank = 20
		_check(is_equal_approx(heavy_tower.kill_rage_refund(), 98.0), "玄甲 20 阶返怒应封顶 98%")
		heavy_tower.queue_free()
	# 军旗（张飞·虎贲军）：常驻光环，周围 150px 友方伤害 +4%×s。
	var vanguard_promo := load("res://resources/promotions/tiger_guard_army.tres") as PromotionData
	var steady_promo := load("res://resources/promotions/archer_strong_bow.tres") as PromotionData
	var huang_zhong := load("res://resources/characters/huang_zhong.tres") as CharacterData
	var skill_tank := EnemyData.new()
	skill_tank.enemy_id = &"smoke_skill_tank"
	skill_tank.display_name = "技能木桩"
	skill_tank.max_hp = 10000
	skill_tank.move_speed = 0.0
	skill_tank.currency_reward = 0
	skill_tank.kill_xp = 0
	skill_tank.damage_to_base = 0
	skill_tank.body_color = Color.GRAY
	skill_tank.body_size = Vector2(40, 40)
	var vanguard_tower: Tower = tower_manager.build_tower(Vector2(660, 640), zhang_fei, null, {"level": 10, "promotion": vanguard_promo})
	_check(vanguard_tower != null and vanguard_tower.has_skill(&"command"), "虎贲军应持有军旗技能")
	if vanguard_tower:
		vanguard_tower.set_process(false)
		var banner_ally: Tower = tower_manager.build_tower(Vector2(700, 640), guan_yu, null, {"level": 1})
		var banner_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		banner_target.set_process(false)
		if banner_ally:
			banner_ally.set_process(false)
			banner_ally.refresh_aura_damage_bonus()
			_check(is_equal_approx(float(banner_ally.get("_aura_damage_bonus")), 0.04),
				"军旗应使射程内友方伤害 +4%（收敛进光环伤害桶）")
			banner_ally.queue_free()
		banner_target.queue_free()
		vanguard_tower.queue_free()
		# 等一帧释放军旗塔，避免其光环污染稳射的伤害断言。
		await get_tree().process_frame
	# 稳射（黄忠·劲弓）：保底触发——每 5 次攻击必追加 0.6× 普攻伤害。
	var steady_tower: Tower = tower_manager.build_tower(Vector2(660, 640), huang_zhong, null, {"level": 10, "promotion": steady_promo})
	_check(steady_tower != null and steady_tower.has_skill(&"steady"), "劲弓应持有稳射技能")
	if steady_tower:
		steady_tower.set_process(false)
		var steady_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		steady_target.set_process(false)
		var steady_before := steady_target.current_hp
		for _i in range(300):
			SkillRegistry.on_attack_hit(steady_tower, steady_target, steady_tower.damage)
		var steady_loss := steady_before - steady_target.current_hp
		_check(steady_loss == 60 * int(round(steady_tower.damage * 0.6)),
			"稳射 300 次攻击应恰好触发 60 次（每 5 次保底）")
		_check(steady_loss % int(round(steady_tower.damage * 0.6)) == 0,
			"稳射追加伤害应为 0.6× 普攻的整数倍")
		steady_target.queue_free()
		steady_tower.queue_free()

	# 命中事件拆分（v0.31.4 / 0.8.6.2）：远程普攻发射不积怒，弹道命中造成伤害后才积怒；
	# 目标飞行中死亡则整发作废（不积怒、不计数）。
	var event_char := load("res://resources/characters/huang_zhong.tres") as CharacterData
	var event_tower: Tower = tower_manager.build_tower(Vector2(80, 700), event_char, null, {"level": 1})
	_check(event_tower != null, "应能建造命中事件用例塔（黄忠·弓箭手）")
	if event_tower != null:
		event_tower.set_process(false)
		event_tower.rage = 0.0
		var hit_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		hit_enemy.set_process(false)
		hit_enemy.global_position = event_tower.global_position + Vector2(120, 0)
		event_tower.target = hit_enemy
		event_tower.attack()
		_check(is_equal_approx(event_tower.rage, 0.0), "远程普攻发射瞬间不应积怒（v0.31.4）")
		var arrow: Bullet = null
		for child in event_tower.get_tree().current_scene.get_children():
			if child is Bullet and not child.is_queued_for_deletion() and (child as Bullet).source_tower == event_tower:
				arrow = child
				break
		_check(arrow != null, "发射后应存在飞行中的子弹")
		if arrow != null and is_instance_valid(hit_enemy):
			var expected_rage := 4.0 + float(arrow.damage) * 0.1
			arrow.max_lifetime = 60.0
			arrow._physics_process(10.0)
			_check(is_equal_approx(event_tower.rage, expected_rage),
				"子弹命中造成伤害后才应积怒（4 + 伤害×0.1）")
		# 目标飞行中死亡：该发作废、不积怒。
		event_tower.rage = 0.0
		var lost_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		lost_enemy.set_process(false)
		lost_enemy.global_position = event_tower.global_position + Vector2(120, 0)
		event_tower.target = lost_enemy
		event_tower.attack()
		var dud_arrow: Bullet = null
		for child in event_tower.get_tree().current_scene.get_children():
			if child is Bullet and not child.is_queued_for_deletion() and (child as Bullet).source_tower == event_tower:
				dud_arrow = child
				break
		if dud_arrow != null:
			dud_arrow.max_lifetime = 60.0
			lost_enemy.take_damage(99999, "other_tower")
			dud_arrow._physics_process(10.0)
			_check(is_equal_approx(event_tower.rage, 0.0), "目标飞行中死亡，子弹作废不应积怒（v0.31.4）")
		event_tower.queue_free()
		if is_instance_valid(hit_enemy):
			hit_enemy.queue_free()
		if is_instance_valid(lost_enemy):
			lost_enemy.queue_free()

		# 大招模式（v0.15.0）：手动满怒待发，自动满怒即放；均触发专属视觉。
	var mode_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
	mode_tank.set_process(false)
	mode_tank.global_position = Vector2(180, 640)
	GameFlow.set_gameplay_flag("manual_ultimate", true)
	var manual_tower: Tower = tower_manager.build_tower(Vector2(60, 640), guan_yu, null, {"level": 1})
	_check(manual_tower != null and bool(manual_tower.get("_manual_ultimate_mode")), "手动开关应使新塔进入手动模式")
	if manual_tower:
		manual_tower.set_process(false)
		manual_tower.target = mode_tank
		manual_tower.rage = 100.0
		manual_tower._process(0.016)
		_check(manual_tower.is_ultimate_ready(), "手动模式满怒应待发")
		_check(is_equal_approx(manual_tower.rage, 100.0), "手动模式满怒不应自动释放")
		_check(manual_tower.cast_ultimate_manual(), "手动释放应成功")
		_check(is_equal_approx(manual_tower.rage, 0.0), "手动释放后怒气应清零")
		_check(float(manual_tower.get("_ult_visual_time")) > 0.0, "手动释放应触发大招视觉")
		manual_tower.queue_free()
	GameFlow.set_gameplay_flag("manual_ultimate", false)
	var auto_tower: Tower = tower_manager.build_tower(Vector2(140, 640), guan_yu, null, {"level": 1})
	_check(auto_tower != null and not bool(auto_tower.get("_manual_ultimate_mode")), "默认模式应满怒即放")
	if auto_tower:
		auto_tower.set_process(false)
		auto_tower.target = mode_tank
		auto_tower.rage = 100.0
		# 攻击在冷却中：_process 不会同帧普攻，避免大招清怒后再积怒。
		auto_tower.attack_timer.start(1.0)
		auto_tower._process(0.016)
		_check(is_equal_approx(auto_tower.rage, 0.0), "自动模式满怒应即放并清怒")
		_check(float(auto_tower.get("_ult_visual_time")) > 0.0, "自动释放应触发大招视觉")
		auto_tower.queue_free()
	mode_tank.queue_free()
	# command（刘备·虎贲军）：150px 内友方伤害 +4% × s。
	var commander_promo := load("res://resources/promotions/tiger_guard_army.tres") as PromotionData
	var commander_tower: Tower = tower_manager.build_tower(Vector2(760, 640), liu_bei, null, {"level": 10, "promotion": commander_promo})
	var command_ally_in: Tower = tower_manager.build_tower(Vector2(820, 640), guan_yu, null, {"level": 1})
	var command_ally_out: Tower = tower_manager.build_tower(Vector2(1040, 640), guan_yu, null, {"level": 1})
	_check(commander_tower != null and commander_tower.has_skill(&"command"), "虎贲军应持有军旗技能")
	if commander_tower and command_ally_in and command_ally_out:
		commander_tower.set_process(false)
		command_ally_in.set_process(false)
		command_ally_out.set_process(false)
		var command_target := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		command_target.set_process(false)
		# 刘备塔同时是仁德源（全图 +8%）与军旗源（150px +4%）：收敛为光环桶加法。
		command_ally_in.refresh_aura_damage_bonus()
		command_ally_out.refresh_aura_damage_bonus()
		_check(is_equal_approx(float(command_ally_in.get("_aura_damage_bonus")), 0.12),
			"军旗+仁德应同区加法收敛（档次 1：0.08 + 0.04 = 0.12，射程内）")
		_check(is_equal_approx(float(command_ally_out.get("_aura_damage_bonus")), 0.08),
			"军旗对射程外友方应无加成（仅剩仁德 0.08）")
		commander_tower.battle_rank = 5
		command_ally_in.refresh_aura_damage_bonus()
		_check(is_equal_approx(float(command_ally_in.get("_aura_damage_bonus")), 0.124),
			"军旗 5 阶应 +4.4%（档位按局内升阶 → 0.08 + 0.044 = 0.124）")
		command_target.queue_free()
	commander_tower.queue_free()
	command_ally_in.queue_free()
	command_ally_out.queue_free()
	# 等一帧释放刘备塔，避免其仁德光环污染后续角色技能伤害断言。
	# ===== 阶段 8 提交 7（v0.32.0 / 0.8.7.0）：职业技能双轨——继承/显示/新技能口径/光环桶 =====
	# 双轨数据：6 条二转新技能线 = 核心技能 + 新技能两个 id、enhanced 留空；
	# 6 条强化线 granted 与 enhanced 均配核心技能 id（显示带 + 由 enhanced 决定）。
	var c7_dual := [
		["res://resources/promotions/cavalry_swift_raider.tres", &"charge", &"assault"],
		["res://resources/promotions/tiger_guard_guard.tres", &"command", &"guard"],
		["res://resources/promotions/archer_crossbow.tres", &"steady", &"chain_arrow"],
		["res://resources/promotions/strategist_heavenly_master.tres", &"wisdom", &"mystic_gate"],
		["res://resources/promotions/dancer_echo.tres", &"inspire", &"echo"],
		["res://resources/promotions/catapult_earthquake.tres", &"siege", &"tremor"],
	]
	for c7_entry in c7_dual:
		var c7_promo := load(c7_entry[0]) as PromotionData
		_check(c7_promo != null and c7_promo.granted_skill_ids == [c7_entry[1], c7_entry[2]]
			and c7_promo.enhanced_skill_ids.is_empty(),
			"%s 应显式继承核心技能+新技能且强化标记留空（提交 7）" % c7_entry[0])
		_check(c7_promo != null and c7_promo.skill_params.has(c7_entry[1]) and c7_promo.skill_params.has(c7_entry[2]),
			"%s 双技能参数应为嵌套字典（核心+新技能各一份）" % c7_entry[0])
	var c7_enhanced := [
		["res://resources/promotions/cavalry_heavy_armor.tres", &"charge"],
		["res://resources/promotions/tiger_guard_vanguard.tres", &"command"],
		["res://resources/promotions/archer_piercing_cloud.tres", &"steady"],
		["res://resources/promotions/strategist_sage.tres", &"wisdom"],
		["res://resources/promotions/dancer_phoenix.tres", &"inspire"],
		["res://resources/promotions/catapult_city_breaker.tres", &"siege"],
	]
	for c7_entry in c7_enhanced:
		var c7_promo := load(c7_entry[0]) as PromotionData
		_check(c7_promo != null and c7_promo.granted_skill_ids == [c7_entry[1]]
			and c7_promo.enhanced_skill_ids == [c7_entry[1]],
			"%s 强化线应配核心技能 id（granted 与 enhanced 同源）" % c7_entry[0])
	# 突袭（骁骑）：击杀 +1 层 / 对精英每 4 次命中 +1 层（上限 3），普攻消耗 1 层该次 +25%×s。
	GameManager.gold = 9999
	var c7_raider_promo := load("res://resources/promotions/cavalry_swift_raider.tres") as PromotionData
	var c7_raider_tower: Tower = tower_manager.build_tower(Vector2(60, 100), guan_yu, null, {"level": 20, "promotion": c7_raider_promo})
	_check(c7_raider_tower != null and c7_raider_tower.has_skill(&"charge") and c7_raider_tower.has_skill(&"assault"),
		"骁骑应同时持有蓄力与突袭（双技能继承）")
	if c7_raider_tower:
		c7_raider_tower.set_process(false)
		_check(c7_raider_tower.get_skill_display_name(&"charge") == "蓄力", "骁骑保留的蓄力不应带 +")
		_check(c7_raider_tower.get_skill_display_name(&"assault") == "突袭", "新技能突袭不应带 +")
		var c7_elite := enemy_manager.spawn_enemy_from_data(sergeant_data) as Enemy
		c7_elite.set_process(false)
		for _i in range(4):
			SkillRegistry.on_attack_hit(c7_raider_tower, c7_elite, 10)
		_check(c7_raider_tower.assault_stacks == 1, "突袭对精英每 4 次命中应叠 1 层")
		for _i in range(4):
			SkillRegistry.on_attack_hit(c7_raider_tower, c7_elite, 10)
		_check(c7_raider_tower.assault_stacks == 2, "突袭精英命中叠层应累计")
		SkillRegistry.on_kill(c7_raider_tower, null)
		_check(c7_raider_tower.assault_stacks == 3, "突袭击杀应 +1 层")
		SkillRegistry.on_kill(c7_raider_tower, null)
		_check(c7_raider_tower.assault_stacks == 3, "突袭叠层应封顶 3 层")
		var c7_assault_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c7_assault_tank.set_process(false)
		SkillRegistry.try_consume_assault(c7_raider_tower)
		_check(c7_raider_tower.assault_stacks == 2 and is_equal_approx(float(c7_raider_tower.get("_next_attack_bonus")), 0.25),
			"普攻应消耗 1 层突袭并挂载 +25%")
		_check(c7_raider_tower.finalize_damage(100, c7_assault_tank) == 125, "突袭层消耗该次伤害应 +25%")
		_check(is_equal_approx(float(c7_raider_tower.get("_next_attack_bonus")), 0.0), "突袭加成应一次性消耗")
		c7_raider_tower.battle_rank = 5
		c7_raider_tower.assault_stacks = 1
		SkillRegistry.try_consume_assault(c7_raider_tower)
		_check(is_equal_approx(float(c7_raider_tower.get("_next_attack_bonus")), 0.275),
			"突袭加成应随档位放大（5 阶 = 0.25×1.1）")
		c7_raider_tower.queue_free()
		if is_instance_valid(c7_elite):
			c7_elite.queue_free()
		if is_instance_valid(c7_assault_tank):
			c7_assault_tank.queue_free()
	# 连矢（连弩）：概率追加——roll 中但目标已死则顺延至下一次存活命中，不吞触发。
	var c7_chain_promo := load("res://resources/promotions/archer_crossbow.tres") as PromotionData
	var c7_chain_tower: Tower = tower_manager.build_tower(Vector2(140, 100), huang_zhong, null, {"level": 20, "promotion": c7_chain_promo})
	_check(c7_chain_tower != null and c7_chain_tower.has_skill(&"steady") and c7_chain_tower.has_skill(&"chain_arrow"),
		"连弩应同时持有稳射与连矢")
	if c7_chain_tower:
		c7_chain_tower.set_process(false)
		_check(c7_chain_tower.get_skill_display_name(&"steady") == "稳射", "连弩保留的稳射不应带 +")
		_check(c7_chain_tower.get_skill_display_name(&"chain_arrow") == "连矢", "新技能连矢不应带 +")
		var c7_chain_dead := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c7_chain_dead.set_process(false)
		c7_chain_dead.die(false)
		c7_chain_tower.chain_arrow_pending = true
		SkillRegistry.on_attack_hit(c7_chain_tower, c7_chain_dead, 10)
		_check(c7_chain_tower.chain_arrow_pending, "连矢命中已死目标应顺延、不吞触发")
		var c7_chain_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c7_chain_tank.set_process(false)
		var c7_chain_before := c7_chain_tank.current_hp
		SkillRegistry.on_attack_hit(c7_chain_tower, c7_chain_tank, 10)
		var c7_chain_extra := int(round(c7_chain_tower.damage * 0.5))
		_check(not c7_chain_tower.chain_arrow_pending, "连矢顺延触发后应复位")
		_check(c7_chain_before - c7_chain_tank.current_hp == c7_chain_extra, "连矢应追加 0.5× 普攻伤害")
		c7_chain_tower.queue_free()
		if is_instance_valid(c7_chain_dead):
			c7_chain_dead.queue_free()
		if is_instance_valid(c7_chain_tank):
			c7_chain_tank.queue_free()
	# 奇门（天师）：大招落点易伤 +10%×s/4s——同类不叠加、时长刷新，所有来源伤害受益。
	var c7_mystic_promo := load("res://resources/promotions/strategist_heavenly_master.tres") as PromotionData
	var c7_mystic_tower: Tower = tower_manager.build_tower(Vector2(220, 100), zhuge_liang, null, {"level": 20, "promotion": c7_mystic_promo})
	_check(c7_mystic_tower != null and c7_mystic_tower.has_skill(&"wisdom") and c7_mystic_tower.has_skill(&"mystic_gate"),
		"天师应同时持有奇谋与奇门")
	if c7_mystic_tower:
		c7_mystic_tower.set_process(false)
		_check(c7_mystic_tower.get_skill_display_name(&"wisdom") == "奇谋", "天师保留的奇谋不应带 +")
		_check(c7_mystic_tower.get_skill_display_name(&"mystic_gate") == "奇门", "新技能奇门不应带 +")
		var c7_vuln_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c7_vuln_tank.set_process(false)
		SkillRegistry.apply_mystic_gate(c7_mystic_tower, c7_vuln_tank)
		_check(is_equal_approx(c7_vuln_tank.get_vulnerability_multiplier(), 1.1), "奇门应施加 +10% 易伤")
		var c7_vuln_before := c7_vuln_tank.current_hp
		c7_vuln_tank.take_damage(100)
		_check(c7_vuln_before - c7_vuln_tank.current_hp == 110, "易伤应使所有来源伤害 +10%")
		SkillRegistry.apply_mystic_gate(c7_mystic_tower, c7_vuln_tank)
		_check(is_equal_approx(c7_vuln_tank.get_vulnerability_multiplier(), 1.1), "同类易伤应不叠加")
		c7_vuln_tank.set("_vulnerability_time_left", 1.0)
		SkillRegistry.apply_mystic_gate(c7_mystic_tower, c7_vuln_tank)
		_check(is_equal_approx(float(c7_vuln_tank.get("_vulnerability_time_left")), 4.0), "同类易伤应刷新时长")
		c7_mystic_tower.battle_rank = 5
		SkillRegistry.apply_mystic_gate(c7_mystic_tower, c7_vuln_tank)
		_check(is_equal_approx(c7_vuln_tank.get_vulnerability_multiplier(), 1.11), "奇门易伤应随档位放大（5 阶 1.11）")
		c7_mystic_tower.queue_free()
		if is_instance_valid(c7_vuln_tank):
			c7_vuln_tank.queue_free()
	# 护卫（虎卫）：近战命中概率沿路径拖回 20px（内置冷却 2.5s 防钉死）。
	var c7_guard_promo := load("res://resources/promotions/tiger_guard_guard.tres") as PromotionData
	var c7_guard_tower: Tower = tower_manager.build_tower(Vector2(340, 100), zhang_fei, null, {"level": 20, "promotion": c7_guard_promo})
	_check(c7_guard_tower != null and c7_guard_tower.has_skill(&"command") and c7_guard_tower.has_skill(&"guard"),
		"虎卫应同时持有军旗与护卫")
	if c7_guard_tower:
		c7_guard_tower.set_process(false)
		c7_guard_tower.battle_rank = 20
		_check(c7_guard_tower.get_skill_display_name(&"command") == "军旗", "虎卫保留的军旗不应带 +")
		_check(c7_guard_tower.get_skill_display_name(&"guard") == "护卫", "新技能护卫不应带 +")
		var c7_guard_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c7_guard_target.set_process(false)
		c7_guard_target.progress = 300.0
		for _i in range(100):
			SkillRegistry.on_attack_hit(c7_guard_tower, c7_guard_target, 10)
			if c7_guard_target.progress < 300.0:
				break
		_check(is_equal_approx(c7_guard_target.progress, 280.0) and c7_guard_tower.guard_cooldown_left > 0.0,
			"护卫应命中拖回 20px 并进入内置冷却")
		for _i in range(20):
			SkillRegistry.on_attack_hit(c7_guard_tower, c7_guard_target, 10)
		_check(is_equal_approx(c7_guard_target.progress, 280.0), "护卫冷却期内不应反复拖回")
		c7_guard_tower.queue_free()
		if is_instance_valid(c7_guard_target):
			c7_guard_target.queue_free()
	# 余音（绕梁）：大招后全队伤害 +8%×s/5s（鼓舞线核心技能保留，走同一次大招钩子）。
	var c7_diao_chan := load("res://resources/characters/diao_chan.tres") as CharacterData
	var c7_echo_promo := load("res://resources/promotions/dancer_echo.tres") as PromotionData
	var c7_echo_tower: Tower = tower_manager.build_tower(Vector2(420, 100), c7_diao_chan, null, {"level": 20, "promotion": c7_echo_promo})
	var c7_echo_ally: Tower = tower_manager.build_tower(Vector2(480, 100), guan_yu, null, {"level": 1})
	_check(c7_echo_tower != null and c7_echo_tower.has_skill(&"inspire") and c7_echo_tower.has_skill(&"echo")
		and c7_echo_ally != null, "绕梁应同时持有鼓舞与余音")
	if c7_echo_tower and c7_echo_ally:
		c7_echo_tower.set_process(false)
		c7_echo_ally.set_process(false)
		_check(c7_echo_tower.get_skill_display_name(&"inspire") == "鼓舞", "绕梁保留的鼓舞不应带 +")
		_check(c7_echo_tower.get_skill_display_name(&"echo") == "余音", "新技能余音不应带 +")
		SkillRegistry.on_ultimate_cast(c7_echo_tower)
		_check(is_equal_approx(c7_echo_ally.damage_buff, 1.08), "余音应使全队伤害 +8%")
	if c7_echo_tower:
		c7_echo_tower.queue_free()
	if c7_echo_ally:
		c7_echo_ally.queue_free()
	# 震地（震山）：大招每发落点眩晕 0.5s×s（同目标内置冷却 2.5s 防 3 连发叠晕）。
	var c7_tremor_promo := load("res://resources/promotions/catapult_earthquake.tres") as PromotionData
	var c7_tremor_tower: Tower = tower_manager.build_tower(Vector2(540, 100), huang_fu_song, null, {"level": 20, "promotion": c7_tremor_promo})
	_check(c7_tremor_tower != null and c7_tremor_tower.has_skill(&"siege") and c7_tremor_tower.has_skill(&"tremor"),
		"震山应同时持有破城与震地")
	if c7_tremor_tower:
		c7_tremor_tower.set_process(false)
		_check(c7_tremor_tower.get_skill_display_name(&"siege") == "破城", "震山保留的破城不应带 +")
		_check(c7_tremor_tower.get_skill_display_name(&"tremor") == "震地", "新技能震地不应带 +")
		var c7_stun_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		c7_stun_enemy.set_process(false)
		c7_stun_enemy.progress = 300.0
		SkillRegistry.try_apply_tremor_stun(c7_tremor_tower, c7_stun_enemy)
		_check(is_equal_approx(float(c7_stun_enemy.get("_stun_time_left")), 0.5), "震地应眩晕 0.5s")
		c7_stun_enemy._process(0.1)
		_check(is_equal_approx(c7_stun_enemy.progress, 300.0), "眩晕期间敌人应停止移动")
		c7_stun_enemy.set("_stun_time_left", 0.05)
		SkillRegistry.try_apply_tremor_stun(c7_tremor_tower, c7_stun_enemy)
		_check(is_equal_approx(float(c7_stun_enemy.get("_stun_time_left")), 0.05), "同目标冷却 2.5s 内不应叠晕")
		c7_tremor_tower.tremor_stun_cooldowns.erase(c7_stun_enemy.get_instance_id())
		c7_tremor_tower.battle_rank = 5
		SkillRegistry.try_apply_tremor_stun(c7_tremor_tower, c7_stun_enemy)
		_check(is_equal_approx(float(c7_stun_enemy.get("_stun_time_left")), 0.55), "震地眩晕应随档位放大（5 阶 0.55s）")
		c7_stun_enemy._process(0.6)
		_check(is_equal_approx(float(c7_stun_enemy.get("_stun_time_left")), 0.0), "眩晕应到时解除")
		var c7_stun_progress_before := c7_stun_enemy.progress
		c7_stun_enemy._process(0.1)
		_check(c7_stun_enemy.progress > c7_stun_progress_before, "眩晕解除后敌人应恢复移动")
		c7_tremor_tower.queue_free()
		if is_instance_valid(c7_stun_enemy):
			c7_stun_enemy.queue_free()
	# 等一帧释放本组测试塔，避免护卫光环/余音增益污染后续光环桶与角色技能断言。
	await get_tree().process_frame
	# 常驻光环伤害桶（提交 7 验收）：军旗+（0.06×s）多源加法求和 + clamp(+50%)，最终只乘一次。
	var c7_aura_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
	c7_aura_tank.set_process(false)
	var c7_aura_probe: Tower = tower_manager.build_tower(Vector2(620, 100), guan_yu, null, {"level": 1})
	_check(c7_aura_probe != null, "应能建造光环桶探针塔")
	if c7_aura_probe:
		c7_aura_probe.set_process(false)
		var c7_aura_sources: Array[Tower] = []
		var c7_aura_offsets := [-160.0, -80.0, 40.0, 120.0, 160.0, -120.0]
		for c7_i in range(5):
			var c7_source: Tower = tower_manager.build_tower(
				Vector2(620.0 + c7_aura_offsets[c7_i], 100.0), zhang_fei, null,
				{"level": 20, "promotion": load("res://resources/promotions/tiger_guard_vanguard.tres")})
			if c7_source != null:
				c7_source.set_process(false)
				c7_source.battle_rank = 20
				c7_aura_sources.append(c7_source)
		c7_aura_probe.refresh_aura_damage_bonus()
		_check(is_equal_approx(float(c7_aura_probe.get("_aura_damage_bonus")), 0.42),
			"军旗+ 5 座应加法求和 +42%（0.06×1.4×5，多源互乘路径应消除）")
		_check(c7_aura_probe.finalize_damage(100, c7_aura_tank) == 142, "光环桶应只乘一次 (1+0.42)")
		var c7_sixth: Tower = tower_manager.build_tower(
			Vector2(620.0 + c7_aura_offsets[5], 100.0), zhang_fei, null,
			{"level": 20, "promotion": load("res://resources/promotions/tiger_guard_vanguard.tres")})
		if c7_sixth != null:
			c7_sixth.set_process(false)
			c7_sixth.battle_rank = 20
			c7_aura_sources.append(c7_sixth)
		c7_aura_probe.refresh_aura_damage_bonus()
		_check(is_equal_approx(float(c7_aura_probe.get("_aura_damage_bonus")), 0.5),
			"光环桶应封顶 +50%（0.504 → clamp 0.5）")
		_check(c7_aura_probe.finalize_damage(100, c7_aura_tank) == 150, "光环桶上限 1.5 应生效")
		for c7_source in c7_aura_sources:
			c7_source.queue_free()
		c7_aura_probe.queue_free()
	if is_instance_valid(c7_aura_tank):
		c7_aura_tank.queue_free()
	await get_tree().process_frame
	# 虎贲职业重构（v0.28.0）：profession_id/大招 ID/克制/升阶步进配置同步。
	var tiger_guard_prof := load("res://resources/professions/tiger_guard.tres") as ProfessionData
	_check(tiger_guard_prof != null and str(tiger_guard_prof.profession_id) == "tiger_guard"
		and tiger_guard_prof.display_name == "虎贲", "虎贲职业资源应更名完成")
	_check(tiger_guard_prof != null and str(tiger_guard_prof.ultimate_id) == "ultimate_tiger_guard_sweep",
		"虎贲大招 ID 应为 ultimate_tiger_guard_sweep")
	_check(tiger_guard_prof != null and is_equal_approx(tiger_guard_prof.battle_rank_damage_step, 0.15)
		and tiger_guard_prof.battle_rank_buff_duration_step > 0.0
		and tiger_guard_prof.battle_rank_buff_power_step > 0.0, "虎贲升阶应降低伤害步进并新增 buff 步进")
	# 破阵（虎贲大招）：1.5× 范围伤害 + 击退 40px + 附近 200px 友方攻速 +15%/5s。
	var sweep_tower: Tower = tower_manager.build_tower(Vector2(300, 100), zhang_fei, null, {"level": 1})
	var sweep_ally: Tower = tower_manager.build_tower(Vector2(420, 100), guan_yu, null, {"level": 1})
	var sweep_far: Tower = tower_manager.build_tower(Vector2(760, 100), huang_zhong, null, {"level": 1})
	_check(sweep_tower != null and sweep_ally != null and sweep_far != null, "破阵用例应能建造三座塔")
	if sweep_tower and sweep_ally and sweep_far:
		sweep_tower.set_process(false)
		sweep_ally.set_process(false)
		sweep_far.set_process(false)
		var sweep_enemy := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		sweep_enemy.set_process(false)
		sweep_enemy.progress = 300.0
		sweep_enemy.global_position = sweep_tower.global_position + Vector2(80, 0)
		sweep_tower.target = sweep_enemy
		_check(BehaviorRegistry.execute_ultimate(&"ultimate_tiger_guard_sweep", sweep_tower), "破阵应能释放")
		_check(is_equal_approx(sweep_enemy.progress, 260.0), "破阵应击退敌人 40px")
		_check(is_equal_approx(sweep_ally.attack_speed_buff, 1.15), "破阵激励段应使 200px 内友方攻速 +15%")
		_check(is_equal_approx(sweep_far.attack_speed_buff, 1.0), "破阵激励段对 200px 外友方应无效")
		sweep_enemy.die(false)
		sweep_tower.queue_free()
		sweep_ally.queue_free()
		sweep_far.queue_free()
	await get_tree().process_frame
	# ===== 阶段 8 提交 8（v0.33.0 / 0.8.8.0）：转职数值提升——18 节点对照 4.1 三张表 + 非链式 + 效果型大招倍率 =====
	# 4.1 表口径：[伤害, 射程, 攻速, 大招]；一转 ult=1.0。
	var c8_table := {
		&"cavalry_iron_rider": [1.2, 1.0, 0.9, 1.0],
		&"tiger_guard_army": [1.2, 1.0, 0.95, 1.0],
		&"archer_strong_bow": [1.15, 1.1, 0.95, 1.0],
		&"strategist_mage": [1.15, 1.1, 0.95, 1.0],
		&"dancer_master": [1.1, 1.0, 0.85, 1.0],
		&"catapult_thunder": [1.2, 1.1, 0.9, 1.0],
		&"cavalry_heavy_armor": [1.35, 1.0, 0.85, 1.3],
		&"tiger_guard_vanguard": [1.35, 1.0, 0.9, 1.25],
		&"archer_piercing_cloud": [1.3, 1.15, 0.9, 1.25],
		&"strategist_sage": [1.3, 1.1, 0.9, 1.25],
		&"dancer_phoenix": [1.25, 1.0, 0.8, 1.2],
		&"catapult_city_breaker": [1.35, 1.1, 0.9, 1.3],
		&"cavalry_swift_raider": [1.3, 1.0, 0.9, 1.15],
		&"tiger_guard_guard": [1.25, 1.0, 0.9, 1.15],
		&"archer_crossbow": [1.25, 1.1, 0.9, 1.15],
		&"strategist_heavenly_master": [1.25, 1.1, 0.9, 1.15],
		&"dancer_echo": [1.2, 1.0, 0.85, 1.15],
		&"catapult_earthquake": [1.3, 1.1, 0.9, 1.15],
	}
	for c8_id in c8_table.keys():
		var c8_promo := load("res://resources/promotions/%s.tres" % c8_id) as PromotionData
		var c8_row: Array = c8_table[c8_id]
		_check(c8_promo != null
			and is_equal_approx(c8_promo.damage_multiplier, c8_row[0])
			and is_equal_approx(c8_promo.range_multiplier, c8_row[1])
			and is_equal_approx(c8_promo.attack_interval_multiplier, c8_row[2])
			and is_equal_approx(c8_promo.ultimate_multiplier, c8_row[3]),
			"%s 三围/大招倍率应与 SKILLS.md 4.1 表一致（提交 8）" % c8_id)
	# 非链式相乘：铁骑→玄甲路径末位直接以未转职为基准（攻速 0.85，而非 0.9×0.85）。
	var c8_guan_yu := load("res://resources/characters/guan_yu.tres") as CharacterData
	if c8_guan_yu != null:
		var c8_xuanjia := load("res://resources/promotions/cavalry_heavy_armor.tres") as PromotionData
		var c8_stats := c8_guan_yu.compute_stats_at(20, c8_xuanjia)
		_check(is_equal_approx(float(c8_stats["attack_interval"]), c8_guan_yu.attack_interval * 0.85),
			"二转攻速应只应用末位倍率（×0.85，不与一转 0.9 链式相乘）")
	# 效果型大招乘转职大招倍率（NUMBERS 10.5）：凤仪鼓舞 = 1+0.3×1.2 = 1.36。
	var c8_diao_chan := load("res://resources/characters/diao_chan.tres") as CharacterData
	var c8_fengyi := load("res://resources/promotions/dancer_phoenix.tres") as PromotionData
	var c8_dancer: Tower = tower_manager.build_tower(Vector2(60, 300), c8_diao_chan, null, {"level": 20, "promotion": c8_fengyi})
	var c8_dance_ally: Tower = tower_manager.build_tower(Vector2(140, 300), guan_yu, null, {"level": 1})
	_check(c8_dancer != null and c8_dance_ally != null, "鼓舞倍率用例应能建造两座塔")
	if c8_dancer and c8_dance_ally:
		c8_dancer.set_process(false)
		c8_dance_ally.set_process(false)
		_check(BehaviorRegistry.execute_ultimate(&"ultimate_dancer_encourage", c8_dancer), "凤仪鼓舞应能释放")
		_check(is_equal_approx(c8_dance_ally.attack_speed_buff, 1.36),
			"凤仪鼓舞攻速应乘转职大招倍率（1+0.3×1.2=1.36）")
		c8_dancer.queue_free()
		c8_dance_ally.queue_free()
	# 陷阵激励段 = 1+0.15×1.25 = 1.1875（提交 8 起 effect 型大招接入 ultimate_multiplier）。
	var c8_xianzhen := load("res://resources/promotions/tiger_guard_vanguard.tres") as PromotionData
	var c8_tiger: Tower = tower_manager.build_tower(Vector2(300, 300), zhang_fei, null, {"level": 20, "promotion": c8_xianzhen})
	var c8_tiger_ally: Tower = tower_manager.build_tower(Vector2(380, 300), guan_yu, null, {"level": 1})
	_check(c8_tiger != null and c8_tiger_ally != null, "陷阵激励段用例应能建造两座塔")
	if c8_tiger and c8_tiger_ally:
		c8_tiger.set_process(false)
		c8_tiger_ally.set_process(false)
		var c8_sweep_enemy := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		c8_sweep_enemy.set_process(false)
		c8_sweep_enemy.progress = 300.0
		c8_sweep_enemy.global_position = c8_tiger.global_position + Vector2(80, 0)
		c8_tiger.target = c8_sweep_enemy
		_check(BehaviorRegistry.execute_ultimate(&"ultimate_tiger_guard_sweep", c8_tiger), "陷阵破阵应能释放")
		_check(is_equal_approx(c8_tiger_ally.attack_speed_buff, 1.1875),
			"陷阵激励段应乘转职大招倍率（1+0.15×1.25=1.1875）")
		c8_sweep_enemy.die(false)
		c8_tiger.queue_free()
		c8_tiger_ally.queue_free()
	await get_tree().process_frame
	# 角色技能（v0.28.0）：9 名武将全部配置 character_skill_id。
	var char_skill_ids := {
		"guan_yu": &"char_green_dragon", "zhang_fei": &"char_dangyang_roar",
		"liu_bei": &"char_carry_people", "huang_zhong": &"char_dingjun",
		"diao_chan": &"char_moon_dance", "huang_fu_song": &"char_burn_camp",
		"zhao_yun": &"char_seven_charges", "zhou_wei": &"char_death_fight",
		"zhuge_liang": &"char_borrow_wind",
	}
	for raw_id in char_skill_ids.keys():
		var char_data := GameFlow.load_character_data(raw_id) as CharacterData
		_check(char_data != null and char_data.character_skill_id == char_skill_ids[raw_id],
			"%s 应配置角色技能 %s" % [raw_id, char_skill_ids[raw_id]])
	# 关羽·青龙偃月（A/CD18）：2.5× 单体；击杀冷却 -6s。
	var green_tower: Tower = tower_manager.build_tower(Vector2(320, 640), guan_yu, null, {"level": 10})
	_check(green_tower != null and SkillRegistry.has_character_skill(green_tower), "关羽塔应持有角色技能")
	if green_tower:
		green_tower.set_process(false)
		var green_kill := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		green_kill.set_process(false)
		green_kill.global_position = green_tower.global_position + Vector2(60, 0)
		green_kill.current_hp = green_kill.max_hp
		green_tower.target = green_kill
		_check(green_tower.cast_character_skill(), "青龙偃月应能释放")
		_check(is_equal_approx(green_tower.get_character_skill_cooldown_left(), 13.0),
			"青龙偃月击杀应返 5s 冷却（18-5=13）")
		var green_tank := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		green_tank.set_process(false)
		green_tank.global_position = green_tower.global_position + Vector2(60, 0)
		green_tower.target = green_tank
		green_tower.refund_character_skill_cooldown(999.0)
		var green_before := green_tank.current_hp
		_check(green_tower.cast_character_skill(), "青龙偃月应能再次释放")
		_check(green_before - green_tank.current_hp == int(round(green_tower.damage * 2.0)) * 3,
			"青龙偃月应造成 3 段 × 2.0× 真实伤害（不分摊）")
		green_tank.queue_free()
		green_tower.queue_free()
	# 张飞·当阳桥（A/CD22）：范围内敌人恐惧 1s（反向行军、移速不变）→ 结束后
	# 减速 60% 2s（v0.35.2 / 0.8.10.1 两段顺序控制）。
	var roar_tower: Tower = tower_manager.build_tower(Vector2(360, 640), zhang_fei, null, {"level": 10})
	if roar_tower:
		roar_tower.set_process(false)
		var roar_dummy := EnemyData.new()
		roar_dummy.enemy_id = &"smoke_roar_dummy"
		roar_dummy.display_name = "恐惧木桩"
		roar_dummy.max_hp = 10000
		roar_dummy.move_speed = 100.0
		roar_dummy.currency_reward = 0
		roar_dummy.kill_xp = 0
		roar_dummy.damage_to_base = 0
		roar_dummy.body_color = Color.GRAY
		roar_dummy.body_size = Vector2(40, 40)
		var roar_enemy := enemy_manager.spawn_enemy_from_data(roar_dummy) as Enemy
		roar_enemy.set_process(false)
		roar_enemy.progress = 300.0
		roar_enemy.global_position = roar_tower.global_position + Vector2(60, 0)
		roar_tower.target = roar_enemy
		_check(roar_tower.cast_character_skill(), "当阳桥应能释放")
		_check(is_equal_approx(roar_enemy._fear_time_left, 1.0), "当阳桥应施加恐惧 1s")
		_check(is_equal_approx(roar_enemy.slow_factor, 1.0), "恐惧施加瞬间不应提前减速")
		_check(is_equal_approx(roar_enemy.progress, 300.0), "恐惧施加瞬间不应位移")
		# 手动驱动 _process 模拟帧推进（set_process(false) 下引擎不调用）。
		roar_enemy._process(0.4)
		_check(is_equal_approx(roar_enemy._fear_time_left, 0.6), "恐惧时长应按帧衰减")
		_check(is_equal_approx(roar_enemy.progress, 260.0), "恐惧期间应反向行军（基础移速 100、不受减速）")
		_check(is_equal_approx(roar_enemy.slow_factor, 1.0), "恐惧结束前不应提前减速")
		roar_enemy._process(0.6)
		_check(roar_enemy._fear_time_left <= 0.0, "恐惧应在 1s 后结束")
		_check(is_equal_approx(roar_enemy.slow_factor, 0.4), "恐惧结束应施加减速 60%")
		_check(is_equal_approx(roar_enemy._slow_time_left, 2.0), "随附减速应持续 2s")
		roar_enemy.die(false)
		roar_tower.queue_free()
	# 刘备·携民渡江（B·每波首次漏怪）：全队攻速 +15% 5s。
	var carry_tower: Tower = tower_manager.build_tower(Vector2(400, 640), liu_bei, null, {"level": 10})
	_check(carry_tower != null, "刘备塔应能建造")
	if carry_tower:
		carry_tower.set_process(false)
		GameManager.reset(9999, 20, 5)
		_check(GameManager.start_wave(), "漏怪用例应能开波")
		GameManager.enemy_reached_base(1)
		_check(is_equal_approx(carry_tower.attack_speed_buff, 1.15), "携民渡江应使全队攻速 +15%")
		GameManager.enemy_reached_base(1)
		_check(is_equal_approx(carry_tower.attack_speed_buff, 1.15), "同波第二次漏怪不应重复触发（每波一次）")
		carry_tower.queue_free()
		# 等一帧释放刘备塔，避免其 B 被动在后续漏怪事件中二次触发全队攻速。
		await get_tree().process_frame
	# 黄忠·定军山（A/CD18）：2.5× 单体；未击杀则标记易伤 +15%。
	var dingjun_tower: Tower = tower_manager.build_tower(Vector2(440, 640), huang_zhong, null, {"level": 10})
	if dingjun_tower:
		dingjun_tower.set_process(false)
		var dingjun_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		dingjun_target.set_process(false)
		dingjun_target.global_position = dingjun_tower.global_position + Vector2(120, 0)
		dingjun_tower.target = dingjun_target
		_check(dingjun_tower.cast_character_skill(), "定军山应能释放")
		_check(dingjun_target.has_mark("huang_zhong"), "定军山未击杀应施加定军标记")
		_check(is_equal_approx(SkillRegistry.passive_damage_multiplier(dingjun_tower, dingjun_target), 1.15),
			"定军标记应使该塔普攻伤害 +15%")
		dingjun_target.die(false)
		dingjun_tower.queue_free()
	# 貂蝉·月下舞（A/CD25）：全队怒气 +10（自身 +15，月幕自增 1.2 → 18）。
	var dance_char_data := load("res://resources/characters/diao_chan.tres") as CharacterData
	var dance_tower: Tower = tower_manager.build_tower(Vector2(480, 640), dance_char_data, null, {"level": 10})
	var dance_ally: Tower = tower_manager.build_tower(Vector2(520, 640), guan_yu, null, {"level": 1})
	if dance_tower and dance_ally:
		dance_tower.set_process(false)
		dance_ally.set_process(false)
		_check(dance_tower.cast_character_skill(), "月下舞应能释放")
		_check(is_equal_approx(dance_tower.rage, 18.0), "月下舞自身应 +15 怒气（月幕 ×1.2）")
		_check(is_equal_approx(dance_ally.rage, 11.0), "月下舞友方应 +10 怒气（月幕 ×1.1）")
		dance_tower.queue_free()
		dance_ally.queue_free()
	# 皇甫嵩·焚营（A/CD20）：目标区域范围伤害 + 灼烧。
	var burn_tower: Tower = tower_manager.build_tower(Vector2(560, 640), huang_fu_song, null, {"level": 10})
	if burn_tower:
		burn_tower.set_process(false)
		var burn_char_target := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		burn_char_target.set_process(false)
		burn_char_target.global_position = burn_tower.global_position + Vector2(300, 0)
		burn_tower.target = burn_char_target
		_check(burn_tower.cast_character_skill(), "焚营应能释放")
		_check(burn_char_target.burn_dps > 0, "焚营应施加灼烧")
		burn_char_target.die(false)
		burn_tower.queue_free()
	# 赵云·七进七出（B·每波首次漏怪）：射程内范围伤害 + 自身攻速 +30% 3s。
	var seven_tower: Tower = tower_manager.build_tower(Vector2(600, 640), zhao_yun, null, {"level": 10})
	if seven_tower:
		seven_tower.set_process(false)
		var seven_enemy := enemy_manager.spawn_enemy_from_data(skill_tank) as Enemy
		seven_enemy.set_process(false)
		seven_enemy.global_position = seven_tower.global_position + Vector2(60, 0)
		GameManager.reset(9999, 20, 5)
		GameManager.start_wave()
		var seven_before := seven_enemy.current_hp
		GameManager.enemy_reached_base(1)
		_check(seven_enemy.current_hp < seven_before, "七进七出应对射程内敌人造成范围伤害")
		_check(is_equal_approx(seven_tower.attack_speed_buff, 1.3), "七进七出应使自身攻速 +30%")
		seven_enemy.die(false)
		seven_tower.queue_free()
	# 周仓·死战（B·基地 ≤50%）：攻速 +30% 常驻。
	var death_char_data := load("res://resources/characters/zhou_wei.tres") as CharacterData
	var death_tower: Tower = tower_manager.build_tower(Vector2(640, 640), death_char_data, null, {"level": 10})
	if death_tower:
		death_tower.set_process(false)
		GameManager.reset(9999, 20, 5)
		GameManager.start_wave()
		death_tower._process(0.016)
		_check(is_equal_approx(float(death_tower.get("_char_skill_speed_bonus")), 0.0), "基地满血不应触发死战")
		GameManager.enemy_reached_base(10)
		death_tower._process(0.016)
		_check(is_equal_approx(float(death_tower.get("_char_skill_speed_bonus")), 0.3), "基地 ≤50% 应触发死战攻速 +30%")
		death_tower._process(0.016)
		_check(is_equal_approx(float(death_tower.get("_char_skill_speed_bonus")), 0.3), "死战应仅触发一次")
		death_tower.queue_free()
	# 诸葛亮·借东风（A/CD30）：全图友方攻速 +20%、弹道速度 +50% 8s。
	var wind_tower: Tower = tower_manager.build_tower(Vector2(680, 640), zhuge_liang, null, {"level": 10})
	var wind_ally: Tower = tower_manager.build_tower(Vector2(720, 640), guan_yu, null, {"level": 1})
	if wind_tower and wind_ally:
		wind_tower.set_process(false)
		wind_ally.set_process(false)
		_check(wind_tower.cast_character_skill(), "借东风应能释放")
		_check(is_equal_approx(wind_ally.attack_speed_buff, 1.2), "借东风应使友方攻速 +20%")
		_check(is_equal_approx(wind_ally.get_bullet_speed_multiplier(), 1.5), "借东风应使弹道速度 +50%")
		_check(is_equal_approx(wind_tower.get_character_skill_cooldown_left(), 30.0), "借东风冷却应为 30s")
		wind_tower.queue_free()
		wind_ally.queue_free()
	# 职业技能档位口径（v0.27.4）：仅职业技能按局内升阶 battle_rank，角色技能不参与。
	var tier_check_tower: Tower = tower_manager.build_tower(Vector2(760, 640), guan_yu, null, {"level": 1})
	if tier_check_tower:
		tier_check_tower.set_process(false)
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_check_tower), 1.0), "0 阶档位系数应为 1")
		tier_check_tower.battle_rank = 5
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_check_tower), 1.1), "5 阶档位系数应为 1.1")
		tier_check_tower.battle_rank = 20
		_check(is_equal_approx(SkillRegistry.tier_multiplier(tier_check_tower), 1.4), "20 阶档位系数应封顶 1.4")
		tier_check_tower.queue_free()	# 舞娘光环（v0.11.2）：脉冲增益友方攻速、辅助积怒与贡献经验。
	var diao_chan := load("res://resources/characters/diao_chan.tres") as CharacterData
	_check(diao_chan != null, "貂蝉数据应可加载")
	if diao_chan != null:
		var support_session := BattleSession.new("smoke_support")
		GameManager.set_battle_session(support_session)
		var dancer_tower: Tower = tower_manager.build_tower(Vector2(60, 100), diao_chan, null, {"level": 1})
		var ally_tower: Tower = tower_manager.build_tower(Vector2(140, 100), guan_yu, null, {"level": 1})
		_check(dancer_tower != null and ally_tower != null, "应能建造舞娘与友方塔")
		if dancer_tower != null and ally_tower != null:
			dancer_tower.set_process(false)
			dancer_tower.attack()
			_check(is_equal_approx(ally_tower.attack_speed_buff, 1.2), "光环脉冲应使友方攻速 buff +20%")
			# 射程内 2 名友方（出战塔 + 编队用例塔）：积怒 = (触发 6 + 覆盖 2×2) × 月幕自增 1.2 = 12
			_check(is_equal_approx(dancer_tower.rage, 12.0), "辅助积怒应含触发/覆盖并受月幕 +20%")
			var pending: Dictionary = support_session.get_pending_xp_by_character()
			_check(int(pending.get("diao_chan", 0)) == 8, "辅助贡献经验应为 4 + 覆盖 2×2 = 8（10.6）")
		if dancer_tower:
			dancer_tower.queue_free()
		if ally_tower:
			ally_tower.queue_free()

	# 阶段 8 提交 2（P0 3.2/3.4）：攻速 buff 按来源加法叠加、总上限 +100%、间隔下限 0.55。
	var speed_tower: Tower = tower_manager.build_tower(Vector2(320, 100), guan_yu, null, {"level": 1})
	if speed_tower != null:
		speed_tower.apply_attack_speed_buff("test_a", 1.5, 5.0)
		speed_tower.apply_attack_speed_buff("test_b", 1.5, 5.0)
		_check(is_equal_approx(speed_tower.attack_speed_buff, 2.0), "多来源攻速 buff 应加法叠加并封顶 +100%")
		speed_tower.apply_attack_speed_buff("test_c", 3.0, 5.0)
		_check(is_equal_approx(speed_tower.attack_speed_buff, 2.0), "攻速 buff 总上限应为 2.0（+100%）")
		speed_tower.attack_cooldown = 1.0
		speed_tower.kill_stacks = 0
		speed_tower.attack_speed_buff = 2.0
		speed_tower._rebuild_attack_timer()
		_check(is_equal_approx(speed_tower.attack_timer.wait_time, 0.55), "攻速间隔下限应为基础间隔×0.55")
		speed_tower.queue_free()

	# 阶段 8 提交 2（P0 3.3）：结算转盘——≥150 金抽 1 次、结果入档（隔离存档）；
	# ✅ 0.8.14（v0.37.41）：碎片条目随信物重构删除（奖池 6 → 4 条）。
	_check(SettlementWheel.MIN_REMAINING_GOLD == 150, "转盘门槛应为剩余金币 ≥150（仅一次）")
	_check(SettlementWheel.POOL.size() == 4, "转盘奖池应为 4 件（碎片条目已随 0.8.14 删除）")
	var wheel_kinds_ok := true
	for wheel_entry in SettlementWheel.POOL:
		if str(wheel_entry.get("kind", "")) == "shards":
			wheel_kinds_ok = false
	_check(wheel_kinds_ok, "转盘奖池不应残留碎片条目")
	var wheel_profile := ProfileStore.get_profile()
	var wheel_roll := SettlementWheel.roll(wheel_profile)
	_check(not wheel_roll.is_empty(), "转盘应能抽取奖励")
	var wheel_kind := str(wheel_roll.get("kind", ""))
	_check(["item", "tech_points"].has(wheel_kind), "转盘奖励类型应合法（碎片类型已删除）")
	_check(not wheel_roll.has("character_id"), "转盘结果不应再携带碎片武将字段")
	var wheel_amount_before := 0
	if wheel_kind == "item":
		wheel_amount_before = int(wheel_profile.items.get(str(wheel_roll.get("item_id", "")), 0))
	else:
		wheel_amount_before = wheel_profile.tech_points
	_check(ProfileStore.commit_settlement_reward(wheel_roll), "转盘结果应能入账（隔离存档）")
	if wheel_kind == "item":
		_check(int(wheel_profile.items.get(str(wheel_roll.get("item_id", "")), 0))
			== wheel_amount_before + int(wheel_roll.get("amount", 0)), "道具入账数量应正确")
	else:
		_check(wheel_profile.tech_points == wheel_amount_before + int(wheel_roll.get("amount", 0)), "科技点入账数量应正确")

	# ===== 0.8.14 信物重构（v0.37.41 / GDD 4.8 · NUMBERS 10.13 · SAVE_DATA 8）=====
	_check(PlayerProfile.CURRENT_SCHEMA_VERSION == 6, "存档 schema 应为 v6（0.8.16 军功 + 军需；v5 = 经验池 / 练兵令清理，v4 = 碎片清理 + 双槽迁移）")
	# ① 信物目录：3 件专属槽占位（不删除）+ 2 件可选槽（Boss 签名信物 = 通用件）
	var c14_exclusive_count := 0
	var c14_optional: Array[RelicData] = []
	for c14_relic_path in _collect_resource_paths("res://resources/relics"):
		var c14_relic := load(c14_relic_path) as RelicData
		_check(c14_relic != null and c14_relic.is_valid(), "信物资源应有效: %s" % c14_relic_path)
		if c14_relic == null:
			continue
		if c14_relic.is_optional_slot():
			c14_optional.append(c14_relic)
		else:
			c14_exclusive_count += 1
			_check(not c14_relic.character_id.is_empty(), "专属槽信物应绑定武将: %s" % c14_relic_path)
	_check(c14_exclusive_count == 3, "旧 3 件专属信物应保留为专属槽占位数据（不删除）")
	_check(c14_optional.size() == 2, "可选槽应有 2 件 Boss 签名信物")
	var c14_tiangong := GameFlow.load_relic_data("relic_tiangong_leizhao")
	var c14_taiping := GameFlow.load_relic_data("relic_taiping_yaoshu")
	_check(c14_tiangong != null and is_equal_approx(c14_tiangong.magic_damage_bonus, 0.12)
			and is_zero_approx(c14_tiangong.damage_bonus) and c14_tiangong.character_id.is_empty(),
			"天公雷诏应为通用件·术法伤害 +12%（不叠全伤害）")
	_check(c14_taiping != null and c14_taiping.level_bonus == 5 and c14_taiping.character_id.is_empty(),
			"太平要术·残卷应为通用件·+5 等级成长等效")
	_check(GameFlow.get_optional_relics().size() == 2, "可选槽信物目录应可枚举 2 件")
	# ② s08 首通信物按难度分派（标准 → 天公雷诏；困难 → 残卷；各 1 件、每件仅 1 次）
	var c14_s08 := load("res://resources/stages/chapter_01/ch01_s08.tres") as StageData
	_check(c14_s08 != null and c14_s08.first_clear_relic != null
			and str(c14_s08.first_clear_relic.relic_id) == "relic_tiangong_leizhao",
			"s08 标准难度首通应掉落天公雷诏（替换原关羽信物）")
	_check(c14_s08 != null and c14_s08.first_clear_relic_hard != null
			and str(c14_s08.first_clear_relic_hard.relic_id) == "relic_taiping_yaoshu",
			"s08 困难难度首通应掉落太平要术·残卷")
	# ③ 残卷 = 等级 +5 成长等效（compute_stats_at 同源，突破 30 级上限）
	var c14_guan_yu := GameFlow.load_character_data("guan_yu")
	_check(c14_guan_yu != null, "应能读取关羽数据")
	if c14_guan_yu != null and c14_taiping != null:
		var c14_lv10 := c14_guan_yu.compute_stats_at(10, null, 0, null)
		var c14_lv15 := c14_guan_yu.compute_stats_at(15, null, 0, null)
		var c14_carry := c14_guan_yu.compute_stats_at(10, null, 0, c14_taiping)
		_check(int(c14_carry.damage) == int(c14_lv15.damage) and int(c14_carry.damage) > int(c14_lv10.damage),
			"太平要术·残卷应等效 +5 级成长（伤害）")
		var c14_lv30 := c14_guan_yu.compute_stats_at(30, null, 0, null)
		var c14_lv35 := c14_guan_yu.compute_stats_at(30, null, 0, c14_taiping)
		_check(int(c14_lv35.damage) > int(c14_lv30.damage)
				and int(c14_lv35.damage) == int(c14_guan_yu.compute_stats_at(35, null, 0, null).damage),
			"残卷应突破 30 级上限（等效上限 35）")
	# ④ 天公雷诏仅魔法类型生效（STATS_PIPELINE v0.6 §1.3 类型条件增伤）
	var c14_tower: Tower = tower_manager.build_tower(Vector2(300, 640), guan_yu, null,
		{"level": 1, "relic": c14_tiangong})
	_check(c14_tower != null, "应能建造天公雷诏探针塔")
	if c14_tower != null:
		c14_tower.set_process(false)
		var c14_enemy := enemy_manager.spawn_enemy_from_data(soldier) as Enemy
		if c14_enemy != null:
			c14_enemy.set_process(false)
			var c14_base := c14_tower.damage
			var c14_phys_damage := c14_tower.finalize_damage(c14_base, c14_enemy)
			var c14_magic_damage := c14_tower.finalize_damage(c14_base, c14_enemy, DamageTypes.MAGIC)
			_check(c14_magic_damage == int(round(c14_phys_damage * 1.12)),
				"天公雷诏应在魔法类型伤害上 +12%")
			_check(c14_tower.finalize_damage(c14_base, c14_enemy, DamageTypes.TRUE) == c14_phys_damage,
				"天公雷诏不应作用于真实 / 物理类型（缺省 = 本塔普攻类型）")
			c14_enemy.queue_free()
		c14_tower.queue_free()
	# ⑤ 双槽装配：可选槽 = 生效位；专属槽 = 锁定占位（不参与计算）
	var c14_profile := PlayerProfile.new()
	c14_profile.ensure_character("guan_yu")
	c14_profile.add_relic("relic_guanyu_blade")
	c14_profile.add_relic("relic_tiangong_leizhao")
	_check(not c14_profile.get_character("guan_yu").has("shards"), "武将条目不应再含碎片字段（schema v4）")
	_check(c14_profile.get_character_relic_id("guan_yu", "optional").is_empty(), "新档可选槽默认为空")
	_check(c14_profile.set_character_relic("guan_yu", "relic_tiangong_leizhao"), "可选槽应可装配已持有信物")
	_check(c14_profile.get_character_relic_id("guan_yu", "optional") == "relic_tiangong_leizhao",
			"可选槽应记录装配信物（relic_optional）")
	_check(c14_profile.set_character_exclusive_relic("guan_yu", "relic_guanyu_blade"), "专属槽应可写入占位数据")
	_check(c14_profile.get_character_relic_id("guan_yu", "exclusive") == "relic_guanyu_blade",
			"专属槽应记录占位信物（relic_exclusive）")
	_check(not c14_profile.set_character_relic("guan_yu", "relic_taiping_yaoshu"), "未持有信物不应可装配")
	var c14_loadout := GameFlow.get_battle_loadout(c14_profile, "guan_yu")
	var c14_loadout_relic: RelicData = c14_loadout.get("relic", null)
	_check(c14_loadout_relic != null and str(c14_loadout_relic.relic_id) == "relic_tiangong_leizhao",
			"战斗 loadout 信物应取可选槽（专属槽占位不生效）")
	# ⑥ 碎片残留防线：Debug 发放 / 存档 API / 转盘奖池均不应残留碎片
	var c14_debug_source := FileAccess.get_file_as_string("res://scripts/DebugPanel.gd")
	_check(not c14_debug_source.contains("碎片"), "Debug 面板不应残留碎片发放入口")
	var c14_profile_source := FileAccess.get_file_as_string("res://scripts/data/PlayerProfile.gd")
	_check(not c14_profile_source.contains("add_character_shards")
			and not c14_profile_source.contains("spend_shards"), "存档层不应残留碎片 API")

	# 阶段 8 提交 3：地图校验器——第一章 8 关布局全部通过（道路/禁建不重叠、通路完整、覆盖区与职业位达标）。
	var map_issues: Array[String] = []
	for stage_path in _collect_resource_paths("res://resources/stages"):
		var map_stage := load(stage_path) as StageData
		if map_stage != null and not MapValidator.validate_stage(map_stage, map_issues):
			_check(false, "地图校验失败: %s: %s" % [stage_path, "；".join(map_issues)])
			map_issues.clear()
	_check(map_issues.is_empty(), "地图校验器不应有遗留问题")

	# 0.8.13.1：s06 新增观察波（教学节奏，STAGES §7）——第 2 波 = 步卒观察 + 夜行刺演示；
	# 0.8.13.2：再 +1 隐匿混编波（9 波，验收波顺延末位）。
	var c13_s06 := load("res://resources/stages/chapter_01/ch01_s06.tres") as StageData
	_check(c13_s06 != null and c13_s06.waves.size() == 10, "s06 应有 10 波（观察波 + 隐匿混编 + 张宝 Boss 验收）")
	if c13_s06 != null and c13_s06.waves.size() >= 2:
		var c13_wave_numbers_ok := true
		for c13_wave_index in range(c13_s06.waves.size()):
			if c13_s06.waves[c13_wave_index].wave_number != c13_wave_index + 1:
				c13_wave_numbers_ok = false
		_check(c13_wave_numbers_ok, "s06 波次编号应从 1 连续到 10")
		var c13_obs := c13_s06.waves[1]
		_check(str(c13_obs.wave_id) == "ch01_s06_w02" and c13_obs.wave_number == 2,
			"观察波应位于第 2 位（wave_id = ch01_s06_w02）")
		var c13_obs_soldiers := 0
		var c13_obs_stealth := 0
		for c13_group in c13_obs.spawn_groups:
			if c13_group == null or c13_group.enemy == null:
				continue
			if c13_group.enemy.stealth:
				c13_obs_stealth += c13_group.count
			elif str(c13_group.enemy.enemy_id) == "yellow_turban_soldier":
				c13_obs_soldiers += c13_group.count
		_check(c13_obs_soldiers == 4 and c13_obs_stealth == 2,
			"观察波应为 4 步卒 + 2 夜行刺（实为 %d 步卒 + %d 隐匿）" % [c13_obs_soldiers, c13_obs_stealth])


	# 阶段 8 提交 8 延伸·修复 7（v0.33.7 / 0.8.8.7，BUGS B-022）：角色图鉴数据完整性——
	# 初始武将获取方式（unlock_stage_id 空 =「初始解锁」）、9 名武将特性数据齐全、观星射程实算。
	_check(GameFlow.get_acquisition_text("guan_yu") == "初始解锁"
		and GameFlow.get_acquisition_text("liu_bei") == "初始解锁",
		"刘备/关羽应显示「初始解锁」（unlock_stage_id 已清空，B-022）")
	_check(GameFlow.get_acquisition_text("zhang_fei") == "通关「长社火攻」首通解锁",
		"张飞获取方式应为首通 s02 解锁")
	var c887_char_ids := ["liu_bei", "guan_yu", "zhang_fei", "huang_fu_song", "huang_zhong",
		"diao_chan", "zhou_wei", "zhao_yun", "zhuge_liang"]
	var c887_all_traits := true
	for character_id in c887_char_ids:
		var c887_data := load("res://resources/characters/%s.tres" % character_id) as CharacterData
		if c887_data == null or c887_data.trait_id.is_empty():
			c887_all_traits = false
	_check(c887_all_traits, "9 名武将应全部配置 trait_id（B-022 补齐赵云/周仓/诸葛亮）")
	var star_char := load("res://resources/characters/zhuge_liang.tres") as CharacterData
	var saved_squad_relics := GameFlow.squad_relic_ids.duplicate()
	GameFlow.squad_relic_ids = []
	var star_tower: Tower = tower_manager.build_tower(Vector2(60, 640), star_char, null, {"level": 1})
	GameFlow.squad_relic_ids = saved_squad_relics
	if star_char != null and star_tower != null:
		star_tower.set_process(false)
		_check(is_equal_approx(star_tower.range_radius, 190.0 * 1.12),
			"诸葛亮观星射程 +12% 应生效（trait_id 先于属性计算就位，B-022）")
		star_tower.queue_free()

	_finish()


func _finish() -> void:
	get_tree().paused = false
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = _profile_file + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for warning in warnings:
		print("SMOKE_TEST_WARN: %s" % warning)
	if failures.is_empty():
		print("SMOKE_TEST_OK")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST_FAILED: %d" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		get_tree().quit(1)


## 资源完整性扫描（GDD 阶段 3 验收项"无配置缺失报错"）：全量加载
## resources/ 下 .tres 并校验跨资源引用。指向尚未创建内容的前向引用
## （如角色解锁关卡未建）只记警告；引用到任何位置都不存在的 ID 记为失败。
func _check_resource_integrity() -> void:
	var characters: Dictionary = {}
	var promotions: Dictionary = {}
	var stages: Dictionary = {}
	var items: Dictionary = {}
	for path in _collect_resource_paths("res://resources"):
		var duplicate_key := _duplicate_resource_key(path)
		if not duplicate_key.is_empty():
			_check(false, "资源存在重复键（后者静默胜出，BUGS B-059）: %s -> %s" % [path, duplicate_key])
		var resource := load(path) as Resource
		if resource == null:
			_check(false, "资源加载失败: %s" % path)
			continue
		if resource is CharacterData:
			var character := resource as CharacterData
			_check(character.is_valid(), "CharacterData 无效: %s" % path)
			_check(character.profession != null, "角色缺少职业引用: %s" % path)
			characters[str(character.character_id)] = character
		elif resource is EnemyData:
			_check((resource as EnemyData).is_valid(), "EnemyData 无效: %s" % path)
		elif resource is BattleSupplyData:
			_check((resource as BattleSupplyData).is_valid(), "BattleSupplyData 无效: %s" % path)
		elif resource is StageData:
			var stage := resource as StageData
			_check(stage.is_valid(), "StageData 无效: %s" % path)
			stages[str(stage.stage_id)] = stage
		elif resource is PromotionData:
			var promotion := resource as PromotionData
			_check(promotion.is_valid(), "PromotionData 无效: %s" % path)
			_check(promotion.target_profession != null, "转职缺少目标职业: %s" % path)
			promotions[str(promotion.promotion_id)] = promotion
		elif resource is ProfessionData:
			var profession := resource as ProfessionData
			_check(profession.is_valid(), "ProfessionData 无效: %s" % path)
			_check(not profession.behavior_id.is_empty(), "职业缺少 behavior_id: %s" % path)
		elif resource is ItemData:
			var item := resource as ItemData
			_check(item.is_valid(), "ItemData 无效: %s" % path)
			items[str(item.item_id)] = item
		elif resource is ItemAmountData:
			_check((resource as ItemAmountData).is_valid(), "ItemAmountData 缺少道具引用: %s" % path)
		elif resource is WaveData:
			_check((resource as WaveData).is_valid(), "WaveData 无效: %s" % path)
		elif resource is ChapterData:
			_check((resource as ChapterData).is_valid(), "ChapterData 无效: %s" % path)
		elif resource is BondData:
			_check((resource as BondData).is_valid(), "BondData 无效: %s" % path)

	for promotion_id in promotions:
		var promotion: PromotionData = promotions[promotion_id]
		for next_id in promotion.next_promotion_ids:
			_check(promotions.has(str(next_id)),
				"转职 %s 引用了不存在的下一转职 %s" % [promotion_id, next_id])

	for character_id in characters:
		var character: CharacterData = characters[character_id]
		for promotion_id in character.promotion_ids:
			_check(promotions.has(str(promotion_id)),
				"角色 %s 引用了不存在的转职 %s" % [character_id, promotion_id])
		if not character.unlock_stage_id.is_empty() and not stages.has(str(character.unlock_stage_id)):
			warnings.append("角色 %s 的解锁关卡 %s 尚未创建" % [character_id, character.unlock_stage_id])
	for stage_id in stages:
		var stage: StageData = stages[stage_id]
		for prereq in stage.prerequisite_stage_ids:
			_check(stages.has(str(prereq)),
				"关卡 %s 引用了不存在的前置关卡 %s" % [stage_id, prereq])
		for unlock_id in stage.first_clear_unlock_character_ids:
			_check(characters.has(str(unlock_id)),
				"关卡 %s 首通解锁了不存在的角色 %s" % [stage_id, unlock_id])
		for reward in stage.first_clear_rewards + stage.repeat_clear_rewards:
			if reward != null and reward.item != null and not items.has(str(reward.item.item_id)):
				_check(false, "关卡 %s 掉落了未注册道具 %s" % [stage_id, reward.item.item_id])
	for promotion_id in promotions:
		var promotion: PromotionData = promotions[promotion_id]
		for next_id in promotion.next_promotion_ids:
			_check(promotions.has(str(next_id)),
				"转职 %s 引用了不存在的后续转职 %s" % [promotion_id, next_id])



## B-059 回归护栏：`.tres` 的 `[resource]` 主段落不得出现重复键（Godot 静默取
## 后者胜出——黄巾力士 armor = 10 后跟旧 armor = 0 即被回退为 0）。返回首个重复键名。
func _duplicate_resource_key(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var keys: Array[String] = []
	var in_resource_section := false
	while not file.eof_reached():
		var trimmed := file.get_line().strip_edges()
		if trimmed.begins_with("["):
			in_resource_section = trimmed == "[resource]"
			continue
		if not in_resource_section or not trimmed.contains("="):
			continue
		var key := trimmed.split("=", true, 1)[0].strip_edges()
		if keys.has(key):
			file.close()
			return key
		keys.append(key)
	file.close()
	return ""


func _collect_resource_paths(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_check(false, "无法打开资源目录: %s" % dir_path)
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var full_path := dir_path + "/" + entry
		if dir.current_is_dir():
			if not entry.begins_with("."):
				result.append_array(_collect_resource_paths(full_path))
		elif entry.ends_with(".tres"):
			result.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return result
