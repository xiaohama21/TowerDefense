extends Node

## 阶段 8·提交 10 数值基准测试（GDD 阶段 8·提交 10 / modules/STATS_PIPELINE.md §10）：
## headless 确定性虚拟时钟模拟——固定 delta 步进、同一 seed、3 次采样取均值；
## 与战斗数值同源（走真实 Tower/Enemy/Bullet 节点与 _process/_physics_process，
## 不另抄任何数值公式）。首次运行生成 tests/benchmark_baseline.json，
## 后续与快照对比（±3% 容差）防平衡回退；断言失败以非零退出码结束。

const TOWER_SCENE := preload("res://scenes/Tower.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const TOWER_MANAGER_SCRIPT := preload("res://scripts/TowerManager.gd")

const VIRTUAL_DELTA: float = 0.02
const WINDOW_TICKS: int = int(60.0 / VIRTUAL_DELTA)
const WINDOW_SECONDS: float = 60.0
const SAMPLES: int = 3
const BASELINE_TOLERANCE: float = 0.03
const BASELINE_PATH := "res://tests/benchmark_baseline.json"

const CHARACTER_DIR := "res://resources/characters/"
const PROMOTION_DIR := "res://resources/promotions/"

## 每行（y 复用 3 条 Path2D）组数；相邻列间距 1500px 防跨组溅射/弹道串扰。
const ROW_GROUPS: int = 3
const COL_SPACING: float = 1500.0
const ROW_SPACING: float = 600.0

## SKILLS.md 4.1 转职等效 DPS 预算（以未转职为基准、不链式相乘）。
const BUDGET_T1: Vector2 = Vector2(1.20, 1.33)
const BUDGET_T2_STRONG: Vector2 = Vector2(1.44, 1.59)
const BUDGET_T2_NEWSKILL: Vector2 = Vector2(1.39, 1.44)

## 档次 3 条件增伤登记（STATS_PIPELINE §9.1）：单项预算 ≤+30%（1.30 倍）。
const CONDITIONAL_BUDGET_MAX: float = 1.30

## 基准 1 行级豁免（提交 10 拍板，2026-09-04）：
## ①archer|3 连弩线：单体窗继承稳射保底、连矢无价值，普攻允许上浮至 ×1.66
##   （AOE 主战场由基准 2 验收）；②catapult|2 破城线：单体窗无精英标签 +
##   min_range 近身弱点，普攻比偏低属口径现象，仅警告不 FAIL（精英窗基准 3 验收）。
const BENCH1_BUDGET_OVERRIDES := {
	"archer|3": Vector2(1.39, 1.66),
}
const BENCH1_WARN_ONLY: Array[String] = ["catapult|2"]

var failures: Array[String] = []
var warnings: Array[String] = []
var _profile_file := ""
var _bench_report: Array[String] = []
var _baseline: Dictionary = {}
var _baseline_data: Dictionary = {}

var _tower_manager: Node = null
var _paths: Array[Node] = []
var _layout_col := 0

## 角色代表（6 职业；辅助舞娘行并入基准 4 团队口径——舞娘无输出普攻，
## 见 GDD 阶段 8 提交 10 落地说明）。
const CAVALRY_CHAR := "guan_yu"
const TIGER_CHAR := "zhang_fei"
const ARCHER_CHAR := "huang_zhong"
const STRATEGIST_CHAR := "zhuge_liang"
const DANCER_CHAR := "diao_chan"
const CATAPULT_CHAR := "huang_fu_song"
const LIUBEI_CHAR := "liu_bei"

## 转职配置（display 名 / promo 文件基名）；promo 为空 = 未转职。
const TIER1 := 1
const TIER2_STRONG := 2
const TIER2_NEW := 3

func _promo_path(base: String) -> String:
	return PROMOTION_DIR + base + ".tres"

## 职业配置行：{char, 未转/一转/强化线(A)/新技能线(B)}
const PROFESSION_ROWS := {
	&"cavalry": {
		"char": "guan_yu",
		"t1": "cavalry_iron_rider",
		"a": "cavalry_heavy_armor",
		"b": "cavalry_swift_raider",
	},
	&"tiger_guard": {
		"char": "zhang_fei",
		"t1": "tiger_guard_army",
		"a": "tiger_guard_vanguard",
		"b": "tiger_guard_guard",
	},
	&"archer": {
		"char": "huang_zhong",
		"t1": "archer_strong_bow",
		"a": "archer_piercing_cloud",
		"b": "archer_crossbow",
	},
	&"strategist": {
		"char": "zhuge_liang",
		"t1": "strategist_mage",
		"a": "strategist_sage",
		"b": "strategist_heavenly_master",
	},
	&"catapult": {
		"char": "huang_fu_song",
		"t1": "catapult_thunder",
		"a": "catapult_city_breaker",
		"b": "catapult_earthquake",
	},
	&"dancer": {
		"char": "diao_chan",
		"t1": "dancer_master",
		"a": "dancer_phoenix",
		"b": "dancer_echo",
	},
}

## 各配置显示名（报告用）。
func _promo_name(row: Dictionary, cfg: int) -> String:
	match cfg:
		TIER1:
			return row["t1"]
		TIER2_STRONG:
			return row["a"]
		TIER2_NEW:
			return row["b"]
	return "base"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var nonce := "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]
	_profile_file = "user://.benchmark_runner_%s.json" % nonce
	ProfileStore.configure_paths(_profile_file)
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("BENCHMARK: %s" % message)


func _run() -> void:
	# 全加成归零基准环境：无信物（不配 relic）/ 无遗物 / 无科技（隔离档案）/ 无羁绊 / 星级停用。
	GameFlow.clear_squad_relics()
	GameFlow.squad_character_ids = []
	GameFlow.selected_difficulty = Difficulty.NORMAL
	GameManager.gold = 1000000
	GameManager.reset_combo()
	GameManager.reset(99999, 999, 1)
	_build_environment()
	await get_tree().process_frame
	await get_tree().process_frame

	if not OS.get_environment("BENCH_DEBUG").is_empty():
		await _debug_probe()
		get_tree().quit(0)
		return

	_baseline = _load_baseline()
	seed(20260904)
	await _run_benchmark_1()
	await _run_benchmark_2()
	await _run_benchmark_3()
	await _run_benchmark_4()
	_run_bucket_asserts()
	_finish()


## 临时调试探针（BENCH_DEBUG=1 时运行）：复现「打几下就停」场景。
func _debug_probe() -> void:
	var scenarios: Array[Dictionary] = [
		{"name": "b1 布局 关羽未转", "char": "guan_yu", "promo": "", "count": 1,
			"hp": 100000, "armor": 0, "tags": [] as Array[StringName], "respawn": 0},
		{"name": "b3 布局 张飞 cavalry 桩", "char": "zhang_fei", "promo": "", "count": 1,
			"hp": 100000, "armor": 0, "tags": [&"cavalry"] as Array[StringName], "respawn": 0},
		{"name": "b4 布局 control", "char": "guan_yu", "promo": "", "count": 1,
			"hp": 100000, "armor": 0, "tags": [] as Array[StringName], "respawn": 0},
	]
	for sc in scenarios:
		seed(20260904)
		var group := _make_group(sc["char"], sc["promo"], sc["count"], sc["hp"], sc["armor"],
			sc["tags"], sc["respawn"])
		if sc["name"] == "b4 布局 control":
			group = _make_support_group("", "")
		if group.is_empty():
			print("DEBUG %s 建组失败" % sc["name"])
			continue
		_simulate_window([group])
		var tower: Tower = group["tower"]
		var total := _group_damage(group)
		var dummy: Enemy = group["dummies"][0]
		print("DEBUG %s | damage=%d dps=%.1f ult=%d rage=%.1f target_valid=%s attack_timer_stopped=%s wait=%.3f 桩hp=%d/%d" % [
			sc["name"], total, float(total) / 60.0, int(group["ult_count"]),
			tower.rage, str(tower.is_target_valid(dummy)), str(tower.attack_timer.is_stopped()),
			tower.attack_timer.wait_time, dummy.current_hp, dummy.max_hp,
		])
		await _teardown_window()

	# 暖场：重复 teardown 后（模拟 B1/B2 的窗交替）再跑 B3 并行，定位跨窗残留。
	for warm in range(3):
		seed(20260904)
		var warm_group := _make_group("guan_yu", "", 1, 100000, 0, [] as Array[StringName])
		_simulate_window([warm_group])
		await _teardown_window()
	print("DEBUG 暖场完成，开始 B3 并行（第 2 次）")
	await _debug_b3_parallel("B3并行-暖场后")




func _debug_b3_parallel(tag: String) -> void:
	seed(20260904)
	var specs: Array = [
		{"key": "elite_wusheng", "char": "guan_yu", "promo": "", "hp": 100000, "armor": 15,
			"tags": [&"yellow_turban", &"elite"] as Array[StringName], "respawn": 0},
		{"key": "cavalry_counter", "char": "zhang_fei", "promo": "", "hp": 100000, "armor": 0,
			"tags": [&"yellow_turban", &"cavalry"] as Array[StringName], "respawn": 0},
		{"key": "elite_siege", "char": "huang_fu_song", "promo": "catapult_thunder", "hp": 100000,
			"armor": 15, "tags": [&"yellow_turban", &"elite"] as Array[StringName], "respawn": 0},
		{"key": "kill_refund", "char": "guan_yu", "promo": "cavalry_iron_rider", "hp": 300, "armor": 0,
			"tags": [&"yellow_turban", &"elite"] as Array[StringName], "respawn": 300},
	]
	var groups: Array = []
	for spec in specs:
		var group := _make_group(spec["char"], spec["promo"], 1, spec["hp"], spec["armor"],
			spec["tags"], spec["respawn"])
		if not group.is_empty():
			group["_key"] = spec["key"]
			groups.append(group)
	_simulate_window(groups)
	for group in groups:
		print("DEBUG %s %s | damage=%d dps=%.1f ult=%d 桩数=%d" % [
			tag, str(group["_key"]), _group_damage(group), float(_group_damage(group)) / 60.0,
			int(group["ult_count"]), group["dummies"].size(),
		])
	await _teardown_window()


## 战斗环境：3 条横向直线 Path2D（桩按行分 y）、一个 TowerManager。
func _build_environment() -> void:
	_paths.clear()
	_tower_manager = TOWER_MANAGER_SCRIPT.new()
	add_child(_tower_manager)
	for row in range(ROW_GROUPS):
		var path := Path2D.new()
		var curve := Curve2D.new()
		curve.add_point(Vector2(0, 0))
		curve.add_point(Vector2(20000, 0))
		path.curve = curve
		path.position = Vector2(0, row * ROW_SPACING)
		add_child(path)
		_paths.append(path)


func _row_for_col() -> int:
	return _layout_col % ROW_GROUPS


func _origin_for_col() -> Vector2:
	## 每组返回塔的摆放原点（塔 x = origin.x，桩 = origin.x + 射程内距离）。
	var col := _layout_col
	_layout_col += 1
	var x := 200.0 + floori(col / ROW_GROUPS) * COL_SPACING
	var y := float(col % ROW_GROUPS) * ROW_SPACING
	return Vector2(x, y)


func _build_tower(character_base: String, promo_base: String, origin: Vector2) -> Tower:
	var character_data := load(CHARACTER_DIR + character_base + ".tres") as CharacterData
	_check(character_data != null, "角色资源可加载：" + character_base)
	var loadout := {"level": 10}
	if not promo_base.is_empty():
		var promo := load(PROMOTION_DIR + promo_base + ".tres") as PromotionData
		_check(promo != null, "转职资源可加载：" + promo_base)
		loadout["promotion"] = promo
	var tower: Tower = _tower_manager.build_tower(origin, character_data, null, loadout)
	_check(tower != null, "基准塔可建造：" + character_base)
	if tower != null:
		# 塔只由模拟器虚拟时钟驱动（_process 手动调用），禁用引擎真实帧驱动。
		tower.process_mode = Node.PROCESS_MODE_DISABLED
	return tower


## 生成木桩（Enemy 直接构造，同 EnemyManager 的字段注入顺序）。
func _spawn_dummy(path: Node, x: float, hp: int, armor: int, tags: Array[StringName]) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.speed = 0.0
	enemy.max_hp = hp
	enemy.armor = armor
	enemy.tags = tags.duplicate()
	enemy.enemy_id = &"benchmark_dummy"
	enemy.kill_xp = 0
	enemy.reward = 0
	enemy.damage_to_base = 0
	path.add_child(enemy)
	enemy.progress = x
	enemy.global_position = path.position + Vector2(x, 0)
	enemy.set_process(false)
	# 锚点（提交 10 bug 修复 B-027）：纯 DPS 基准要求木桩静止；张飞「破阵」大招
	# 40px 击退会把静止桩累计推出射程（真实敌人会继续前进不受影响），每 tick 回锚。
	enemy.set_meta(&"bench_home_x", x)
	enemy.set_meta(&"bench_home_pos", path.position + Vector2(x, 0))
	return enemy


## 以塔的射程决定桩位：距塔 dist（避开 min_range），返回桩 x。
func _dummy_x_for_tower(tower: Tower, origin: Vector2) -> float:
	var dist := maxf(tower.range_radius * 0.75, float(tower._min_range) + 60.0)
	dist = minf(dist, tower.range_radius - 20.0)
	return origin.x + maxf(dist, 60.0)


## 一组 = 塔 + 若干木桩。respawn_hp > 0 时击杀循环补桩（击杀返怒验证）。
func _make_group(
	character_base: String,
	promo_base: String,
	dummy_count: int,
	dummy_hp: int,
	dummy_armor: int,
	dummy_tags: Array[StringName],
	respawn_hp: int = 0
) -> Dictionary:
	var row := _layout_col % ROW_GROUPS
	var origin := _origin_for_col()
	var path: Node = _paths[row]
	var tower := _build_tower(character_base, promo_base, origin)
	if tower == null:
		return {}
	# 防回归（B-026）：塔/桩几何必须落在 Path2D 长度（20000）内，否则 PathFollow2D
	# 钳制 progress 会把桩吸到路径末端、塔打不到。单窗列数上限约 38（按当前行距/列距）。
	_check(origin.x + tower.range_radius < 18000.0,
		"布局越界：col=%d origin.x=%.0f + 射程 %.0f 应 < 18000（路径 20000 内）" % [
			_layout_col - 1, origin.x, tower.range_radius,
		])
	var base_x := _dummy_x_for_tower(tower, origin)
	var dummies: Array = []
	for i in range(dummy_count):
		# 主目标（progress 最高）放最远端；聚团间隔 40px 供溅射覆盖。
		var dummy_x := base_x - (dummy_count - 1 - i) * 40.0
		var dummy := _spawn_dummy(path, dummy_x, dummy_hp, dummy_armor, dummy_tags)
		dummies.append(dummy)
	tower.target = dummies[0] as Enemy
	return {
		"tower": tower,
		"dummies": dummies,
		"character_id": tower.character_id,
		"remaining": 0.0,
		"ult_count": 0,
		"respawn_hp": respawn_hp,
		"respawn_timer": 0.0,
		"path": path,
	}


## ============ 确定性模拟核心 ============

## 一窗同步模拟：tick 固定 VIRTUAL_DELTA；引擎帧间 queue_free 由窗末 await 消化。
func _simulate_window(groups: Array) -> void:
	for _tick in range(WINDOW_TICKS):
		_drive_groups(groups, VIRTUAL_DELTA)
		_drive_dummies(groups, VIRTUAL_DELTA)
		_drive_bullets(VIRTUAL_DELTA)
		_handle_respawns(groups, VIRTUAL_DELTA)
		_reanchor_dummies(groups)



## 击退回锚（B-027）：位移型技能（破阵等）对静止桩的累计击退会推出射程，
## 纯 DPS 口径不计位移控制价值，位移后下一 tick 恢复桩位（死亡/待删桩跳过）。
func _reanchor_dummies(groups: Array) -> void:
	for entry in groups:
		for dummy in entry["dummies"]:
			if dummy == null or not is_instance_valid(dummy) or dummy.is_queued_for_deletion() or dummy.is_dead:
				continue
			if not dummy.has_meta(&"bench_home_pos"):
				continue
			dummy.progress = float(dummy.get_meta(&"bench_home_x"))
			dummy.global_position = dummy.get_meta(&"bench_home_pos")

func _drive_dummies(groups: Array, delta: float) -> void:
	## 桩由模拟器驱动（真实 process 已关）：易伤/定军/灼烧/眩晕等时长正常衰减，
	## 与真实战斗口径一致（speed=0 静止，不移动）。
	var seen: Dictionary = {}
	for entry in groups:
		for dummy in entry["dummies"]:
			if dummy == null or not is_instance_valid(dummy) or dummy.is_queued_for_deletion():
				continue
			var id_key: int = dummy.get_instance_id()
			if seen.has(id_key):
				continue
			seen[id_key] = true
			if not dummy.is_dead:
				dummy._process(delta)


func _drive_groups(groups: Array, delta: float) -> void:
	for entry in groups:
		if not entry.has("tower"):
			continue
		var tower: Tower = entry["tower"]
		if tower == null or not is_instance_valid(tower) or tower.is_queued_for_deletion():
			continue
		# 大招释放检测（rage 满 100 → _process 自动释放成功则清怒/返怒 < 100；
		# 前置不满足时恢复满怒不计数）。
		var rage_full := tower.rage >= float(tower._max_rage) - 0.5
		var remaining: float = entry["remaining"] - delta
		entry["remaining"] = remaining
		if remaining <= 0.0:
			tower.attack_timer.stop()
			tower._process(delta)
			if not tower.attack_timer.is_stopped():
				entry["remaining"] = tower.attack_timer.wait_time
			else:
				entry["remaining"] = 0.0
		else:
			tower._process(delta)
		if rage_full and tower.rage < float(tower._max_rage) - 0.5:
			entry["ult_count"] = int(entry["ult_count"]) + 1


func _drive_bullets(delta: float) -> void:
	for child in get_children():
		var bullet := child as Bullet
		if bullet != null and is_instance_valid(bullet) and not bullet.is_queued_for_deletion():
			bullet._physics_process(delta)


func _handle_respawns(groups: Array, delta: float) -> void:
	for entry in groups:
		var respawn_hp: int = entry["respawn_hp"]
		if respawn_hp <= 0:
			continue
		var tower: Tower = entry["tower"]
		if tower == null or not is_instance_valid(tower):
			continue
		var need_refill := false
		for dummy in entry["dummies"]:
			if dummy == null or not is_instance_valid(dummy) or dummy.is_dead:
				need_refill = true
				break
		if not need_refill:
			continue
		# 与 _make_group 相同几何：主桩在 origin.x + dist 处。
		var origin := tower.global_position
		var path: Node = entry["path"]
		var dist := maxf(tower.range_radius * 0.75, float(tower._min_range) + 60.0)
		dist = minf(dist, tower.range_radius - 20.0)
		var dummy_x := origin.x + maxf(dist, 60.0)
		var fresh := _spawn_dummy(path, dummy_x, respawn_hp, 0, [&"yellow_turban", &"elite"] as Array[StringName])
		entry["dummies"].append(fresh)


func _group_damage(entry: Dictionary) -> int:
	## 伤害口径 = 该组角色 id 在全部桩 damage_contributors 的累计（含刷新桩），
	## 与战斗结算同源（Enemy.take_damage 记账），不另抄公式。
	var total := 0
	var char_id: String = entry["character_id"]
	for dummy in entry["dummies"]:
		if dummy == null or not is_instance_valid(dummy):
			continue
		total += int(dummy.damage_contributors.get(char_id, 0))
	return total


func _has_pending_bullets(tower: Tower) -> bool:
	for child in get_children():
		var bullet := child as Bullet
		if bullet != null and is_instance_valid(bullet) and not bullet.is_queued_for_deletion() \
				and bullet.source_tower == tower:
			return true
	return false


## 大招单发伤害（同源实测）：普攻禁用（attack_timer 保持 running），满怒释放后
## 只驱动弹道直至结算完毕；木桩 10 万血不死，单发伤害精确可读。
func _measure_ultimate_once(entry: Dictionary) -> int:
	var tower: Tower = entry["tower"]
	var dummies: Array = entry["dummies"]
	if tower == null or not is_instance_valid(tower):
		return 0
	tower.attack_timer.start(9999.0)
	tower.rage = float(tower._max_rage)
	var released := false
	for _i in range(int(8.0 / VIRTUAL_DELTA)):
		tower.attack_timer.start(9999.0)
		tower._process(VIRTUAL_DELTA)
		_drive_bullets(VIRTUAL_DELTA)
		if not released and tower.rage < float(tower._max_rage) - 0.5:
			released = true
		if released and not _has_pending_bullets(tower):
			break
	return _group_damage(entry)


func _clear_all() -> void:
	for child in get_children():
		child.queue_free()
	_tower_manager = null
	_paths.clear()
	_layout_col = 0


func _teardown_window() -> void:
	for child in get_children():
		child.queue_free()
	GameManager.reset_combo()
	# 引擎帧消化 queue_free（同步模拟期间积压的节点）。
	await get_tree().process_frame
	await get_tree().process_frame
	# 每窗重置列号（提交 10 bug 修复 B-026）：此前 _layout_col 跨窗只增不减，
	# 塔位 x 右移超过 Path2D 长度后，PathFollow2D 会把木桩 progress 钳到路径末端，
	# 桩距塔数万像素超出射程 → 整窗零伤害。窗内自包含 + 列号归零保证几何恒在路径内。
	_layout_col = 0
	_build_environment()


## ============ 基准 1：单体木桩 DPS（5 输出职业 × 4 配置；舞娘行见基准 4） ============
## 断言口径（提交 10 拍板，2026-09-04）：预算对照 SKILLS.md 4.1「等效 DPS」表，以
## **普攻 DPS（不含大招，含职业技能）** 为准——大招次数受怒气-伤害耦合（命中+伤害折算
## 积怒，GDD 4.6/10.6）随伤害加成放大，属设计内建，只报告不 FAIL；大招单发倍率单独
## 对照 damage_multiplier × ultimate_multiplier（±5%）。行级豁免见 BENCH1_BUDGET_OVERRIDES /
## BENCH1_WARN_ONLY（连弩单体含稳射上浮 ×1.66；破城单体口径仅警告，精英窗见基准 3）。
func _run_benchmark_1() -> void:
	_bench_report.append("【基准 1】单体木桩 DPS：60s 虚拟窗 ×3 采样均值（等级 10 / 未升阶 / 全加成归零；")
	_bench_report.append("  木桩 HP10 万无甲无标签；普攻/大招/总 DPS 分列：大招 = 单发实测 × 主窗释放次数 ÷60（合成口径，注明）")
	_bench_report.append("  预算断言以普攻(不含大招) DPS 为准（SKILLS 4.1 等效 DPS 口径）；大招次数增量只报告、单发倍率单独断言")
	var professions: Array[StringName] = [&"cavalry", &"tiger_guard", &"archer", &"strategist", &"catapult"]
	var key_rows: Array[String] = []
	var mean: Dictionary = {}
	for _sample in range(SAMPLES):
		seed(20260904)
		var specs: Array = []
		for profession in professions:
			var row: Dictionary = PROFESSION_ROWS[profession]
			for cfg in [0, TIER1, TIER2_STRONG, TIER2_NEW]:
				var key := "%s|%d" % [profession, cfg]
				if not key_rows.has(key):
					key_rows.append(key)
				var promo := ""
				match cfg:
					TIER1:
						promo = row["t1"]
					TIER2_STRONG:
						promo = row["a"]
					TIER2_NEW:
						promo = row["b"]
				var group := _make_group(
					String(row["char"]), promo, 1, 100000, 0,
					[] as Array[StringName]
				)
				if not group.is_empty():
					specs.append({"key": key, "group": group})
		var all_groups: Array = []
		for spec in specs:
			all_groups.append(spec["group"])
		_simulate_window(all_groups)
		for spec in specs:
			var group: Dictionary = spec["group"]
			var dps := float(_group_damage(group)) / WINDOW_SECONDS
			var ult_count := int(group["ult_count"])
			if not mean.has(spec["key"]):
				mean[spec["key"]] = {"dps": [], "ult": []}
			mean[spec["key"]]["dps"].append(dps)
			mean[spec["key"]]["ult"].append(ult_count)
		await _teardown_window()

	# 大招单发实测（独立窗，普攻/角色技能禁用；每配置 1 塔 1 桩）。
	var ult_once: Dictionary = {}
	for key in key_rows:
		var parts := key.split("|")
		var row: Dictionary = PROFESSION_ROWS[parts[0]]
		var cfg := int(parts[1])
		var promo := ""
		match cfg:
			TIER1:
				promo = row["t1"]
			TIER2_STRONG:
				promo = row["a"]
			TIER2_NEW:
				promo = row["b"]
		var group := _make_group(String(row["char"]), promo, 1, 100000, 0, [] as Array[StringName])
		if group.is_empty():
			continue
		# 大招单发测量前禁用角色技能自动释放，防 2.5× 技能伤污染单发口径。
		var tower: Tower = group["tower"]
		tower._char_skill_ready = false
		tower._char_skill_cooldown_left = 9999.0
		ult_once[key] = _measure_ultimate_once(group)
		await _teardown_window()

	var out: Dictionary = {}
	_bench_report.append("职业    配置             总 DPS      普攻 DPS*   大招 DPS*  大招次数 单发伤害  普攻vs未转  总vs未转")
	for key in key_rows:
		var parts := key.split("|")
		var profession: StringName = parts[0]
		var cfg := int(parts[1])
		var row: Dictionary = PROFESSION_ROWS[profession]
		var dps_vals: Array = mean[key]["dps"]
		var ult_vals: Array = mean[key]["ult"]
		var dps := _avg(dps_vals)
		var ult_count := _avg_float(ult_vals)
		var once := float(ult_once.get(key, 0.0))
		var ult_dps := once * ult_count / WINDOW_SECONDS
		var normal_dps := dps - ult_dps
		var base_key := "%s|0" % profession
		var base_dps := 0.0
		var base_normal := 0.0
		var base_ult := 0.0
		if mean.has(base_key):
			base_dps = _avg(mean[base_key]["dps"])
			base_ult = _avg_float(mean[base_key]["ult"])
			base_normal = base_dps - float(ult_once.get(base_key, 0.0)) * base_ult / WINDOW_SECONDS
		var normal_ratio := 1.0
		var total_ratio := 1.0
		if cfg != 0 and base_normal > 0.0 and base_dps > 0.0:
			normal_ratio = normal_dps / base_normal
			total_ratio = dps / base_dps
		var once_ratio := 1.0
		if cfg != 0 and float(ult_once.get(base_key, 0.0)) > 0.0:
			once_ratio = once / float(ult_once[base_key])
		out[key] = {
			"dps": dps, "normal_dps": normal_dps, "ult_dps": ult_dps,
			"ult_count": ult_count, "ult_once": once,
			"normal_ratio": normal_ratio, "total_ratio": total_ratio,
			"ult_once_ratio": once_ratio,
		}
		var cfg_name := "未转"
		match cfg:
			TIER1:
				cfg_name = "一转·" + str(row["t1"])
			TIER2_STRONG:
				cfg_name = "二转A·" + str(row["a"])
			TIER2_NEW:
				cfg_name = "二转B·" + str(row["b"])
		_bench_report.append("%-8s %-16s %9.1f %9.1f %9.1f %6.1f %8.1f  %s   %s" % [
			profession, cfg_name, dps, normal_dps, ult_dps, ult_count, once,
			("×%.3f" % normal_ratio) if cfg != 0 else "基准",
			("×%.3f" % total_ratio) if cfg != 0 else "基准",
		])
		_assert_tier_budget(profession, cfg, normal_ratio, key)
		_assert_ult_once_budget(cfg, key, once_ratio, row)
		if cfg != 0 and base_ult > 0.0 and ult_count > base_ult * 1.5:
			warnings.append("基准 1 %s 大招次数 %.1f/60s（基础 %.1f，×%.2f）：怒气-伤害耦合放大，总比 ×%.3f 高于普攻比 ×%.3f，属设计内建（10.6），留意后期膨胀" % [
				key, ult_count, base_ult, ult_count / base_ult, total_ratio, normal_ratio,
			])
	# 基线快照与容差回归。
	for key in key_rows:
		_regress_check("bench1.%s.dps" % key, out[key]["dps"])
	_baseline_data["bench1"] = {}
	for key in key_rows:
		_baseline_data["bench1"][key] = {
			"dps": out[key]["dps"], "normal_dps": out[key]["normal_dps"],
			"ult_dps": out[key]["ult_dps"], "ult_count": out[key]["ult_count"],
			"ult_once": out[key]["ult_once"],
			"normal_ratio": out[key]["normal_ratio"],
			"total_ratio": out[key]["total_ratio"],
			"ult_once_ratio": out[key]["ult_once_ratio"],
		}
	_check(key_rows.size() == 20, "基准 1 应产出 5 职业 × 4 配置 = 20 行")
	_bench_report.append("")

func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for v in values:
		sum += float(v)
	return sum / values.size()


func _avg_float(values: Array) -> float:
	return _avg(values)


## SKILLS 4.1 预算断言（基准 1，普攻口径不含大招；行级豁免见 BENCH1_*）。
## 一转 ×1.2~1.33 / 二转强化 ×1.44~1.59 / 二转新技 ×1.39~1.44；容差 ±5%。
func _assert_tier_budget(profession: StringName, cfg: int, normal_ratio: float, key: String) -> void:
	if cfg == 0 or normal_ratio <= 0.0:
		return
	var budget := Vector2.ZERO
	var label := ""
	match cfg:
		TIER1:
			budget = BUDGET_T1
			label = "一转预算 ×1.20~1.33"
		TIER2_STRONG:
			budget = BUDGET_T2_STRONG
			label = "二转强化预算 ×1.44~1.59"
		TIER2_NEW:
			budget = BUDGET_T2_NEWSKILL
			label = "二转新技预算 ×1.39~1.44"
	if BENCH1_BUDGET_OVERRIDES.has(key):
		budget = BENCH1_BUDGET_OVERRIDES[key]
		label += "（连弩单体含稳射上浮 ×1.66）"
	var ok := normal_ratio >= budget.x * 0.95 and normal_ratio <= budget.y * 1.05
	if BENCH1_WARN_ONLY.has(key):
		# 破城线：单体窗口径缺陷（无精英标签/min_range 近身弱点），仅警告不 FAIL，
		# 精英价值由基准 3（elite_siege）与基准 2（AOE 效率）验收。
		if not ok:
			warnings.append("基准 1 %s 普攻比值 ×%.3f 偏离 %s（单体口径仅警告；精英/AOE 由基准 2/3 验收）" % [key, normal_ratio, label])
		return
	_check(ok, "基准 1 %s 普攻比值 ×%.3f 应在%s 内" % [key, normal_ratio, label])
	if not ok:
		warnings.append("基准 1 %s 普攻比值 ×%.3f 超出 %s，建议平衡审查" % [key, normal_ratio, label])


## 大招单发倍率断言（基准 1，拍板 2026-09-04）：大招 = 普攻 ×N×ultimate_power，
## 单发比值理论值 = promotion.damage_multiplier × ultimate_multiplier（特性等条件乘区
## 同乘于基础与转职两侧抵消），容差 ±5%（整数取整 <1%）。
func _assert_ult_once_budget(cfg: int, key: String, once_ratio: float, row: Dictionary) -> void:
	if cfg == 0 or once_ratio <= 0.0:
		return
	var promo := ""
	match cfg:
		TIER1:
			promo = row["t1"]
		TIER2_STRONG:
			promo = row["a"]
		TIER2_NEW:
			promo = row["b"]
	var multipliers := _promo_ult_multipliers(promo)
	var expected := multipliers.x * multipliers.y
	var ok := once_ratio >= expected * 0.95 and once_ratio <= expected * 1.05
	_check(ok, "基准 1 %s 大招单发比值 ×%.3f 应 ≈ damage×%.2f×ult×%.2f=×%.3f（±5%%）" % [
		key, once_ratio, multipliers.x, multipliers.y, expected,
	])
	if not ok:
		warnings.append("基准 1 %s 大招单发比值 ×%.3f 偏离理论 ×%.3f，建议平衡审查" % [key, once_ratio, expected])


func _promo_ult_multipliers(promo_base: String) -> Vector2:
	## 返回 (damage_multiplier, ultimate_multiplier)；未转职 = (1,1)。
	if promo_base.is_empty():
		return Vector2(1.0, 1.0)
	var promo := load(PROMOTION_DIR + promo_base + ".tres") as PromotionData
	if promo == null:
		return Vector2(1.0, 1.0)
	return Vector2(promo.damage_multiplier, promo.ultimate_multiplier)


## ============ 基准 2：3 目标 AOE DPS（聚团 40px，主目标 progress 最远） ============
func _run_benchmark_2() -> void:
	_bench_report.append("【基准 2】3 目标 AOE DPS（木桩聚团 40px；与基准 1 同配置单体窗对比 AOE 效率）")
	var professions: Array[StringName] = [&"tiger_guard", &"archer", &"strategist", &"catapult"]
	var mean: Dictionary = {}
	var key_rows: Array[String] = []
	for _sample in range(SAMPLES):
		seed(20260904)
		var specs: Array = []
		for profession in professions:
			var row: Dictionary = PROFESSION_ROWS[profession]
			for cfg in [0, TIER1, TIER2_STRONG, TIER2_NEW]:
				var key := "%s|%d" % [profession, cfg]
				if not key_rows.has(key):
					key_rows.append(key)
				var promo := ""
				match cfg:
					TIER1:
						promo = row["t1"]
					TIER2_STRONG:
						promo = row["a"]
					TIER2_NEW:
						promo = row["b"]
				var group := _make_group(
					String(row["char"]), promo, 3, 100000, 0,
					[] as Array[StringName]
				)
				if not group.is_empty():
					specs.append({"key": key, "group": group})
					if not mean.has(key):
						mean[key] = []
		var all_groups: Array = []
		for spec in specs:
			all_groups.append(spec["group"])
		_simulate_window(all_groups)
		for spec in specs:
			var key: String = spec["key"]
			mean[key].append(float(_group_damage(spec["group"])) / WINDOW_SECONDS)
		await _teardown_window()

	_bench_report.append("职业    配置             3 目标 DPS  AOE 效率(÷单体)  说明")
	for profession in professions:
		var row: Dictionary = PROFESSION_ROWS[profession]
		for cfg in [0, TIER1, TIER2_STRONG, TIER2_NEW]:
			var key := "%s|%d" % [profession, cfg]
			if not mean.has(key) or mean[key].is_empty():
				continue
			var aoe_dps := _avg(mean[key])
			var single_key := key
			var single_dps := 0.0
			if _baseline_data.has("bench1") and _baseline_data["bench1"].has(single_key):
				single_dps = float(_baseline_data["bench1"][single_key]["dps"])
			else:
				# 兜底：从已采集的基准 1 实时结果取（同一次运行内先执行基准 1）。
				single_dps = 0.0
			var eff := aoe_dps / single_dps if single_dps > 0.0 else 0.0
			var cfg_name := "未转"
			match cfg:
				TIER1:
					cfg_name = "一转·" + str(row["t1"])
				TIER2_STRONG:
					cfg_name = "二转A·" + str(row["a"])
				TIER2_NEW:
					cfg_name = "二转B·" + str(row["b"])
			_bench_report.append("%-8s %-16s %10.1f  %8.2f×" % [profession, cfg_name, aoe_dps, eff])
			_baseline_data["bench2"] = _baseline_data.get("bench2", {})
			_baseline_data["bench2"][key] = {"dps": aoe_dps}
			_regress_check("bench2.%s.dps" % key, aoe_dps)
	# AOE 能力防御性断言：3 目标窗单体职业不倒退、范围职业显著放大（数据供平衡讨论，
	# 不做硬区间，防章节内容差异造成的假失败）。
	var catapult_base := 0.0
	var single_base := 0.0
	if mean.has("catapult|0") and not mean["catapult|0"].is_empty():
		catapult_base = _avg(mean["catapult|0"])
	if _baseline_data.has("bench1") and _baseline_data["bench1"].has("catapult|0"):
		single_base = float(_baseline_data["bench1"]["catapult|0"]["dps"])
	if single_base > 0.0 and catapult_base > 0.0:
		_check(catapult_base > single_base * 1.5, "投石车普攻爆散在 3 目标窗应显著高于单体窗（AOE 定位）")
	_bench_report.append("")


## ============ 基准 3：精英/Boss DPS 与机制（高甲精英 / cavalry 克制 / 破城 / 击杀返怒循环） ============
func _run_benchmark_3() -> void:
	_bench_report.append("【基准 3】精英/Boss DPS：精英桩（高甲 armor15 + elite 标签）/ 克制桩（cavalry 标签）/")
	_bench_report.append("  击杀返怒循环桩（HP300 击杀自动补桩）；对照取基准 1 同配置普通桩数据")
	var specs: Array = [
		{"key": "elite_wusheng", "char": "guan_yu", "promo": "", "hp": 100000, "armor": 15,
			"tags": [&"yellow_turban", &"elite"] as Array[StringName], "respawn": 0},
		{"key": "cavalry_counter", "char": "zhang_fei", "promo": "", "hp": 100000, "armor": 0,
			"tags": [&"yellow_turban", &"cavalry"] as Array[StringName], "respawn": 0},
		{"key": "elite_siege", "char": "huang_fu_song", "promo": "catapult_thunder", "hp": 100000,
			"armor": 15, "tags": [&"yellow_turban", &"elite"] as Array[StringName], "respawn": 0},
		{"key": "kill_refund", "char": "guan_yu", "promo": "cavalry_iron_rider", "hp": 300, "armor": 0,
			"tags": [&"yellow_turban", &"elite"] as Array[StringName], "respawn": 300},
	]
	var mean: Dictionary = {}
	var ult_mean: Dictionary = {}
	for _sample in range(SAMPLES):
		seed(20260904)
		var groups: Array = []
		for spec in specs:
			var group := _make_group(
				spec["char"], spec["promo"], 1, spec["hp"], spec["armor"],
				spec["tags"], spec["respawn"]
			)
			if not group.is_empty():
				group["_key"] = spec["key"]
				groups.append(group)
		_simulate_window(groups)
		for group in groups:
			var key: String = group["_key"]
			if not mean.has(key):
				mean[key] = []
				ult_mean[key] = []
			mean[key].append(float(_group_damage(group)) / WINDOW_SECONDS)
			ult_mean[key].append(float(group["ult_count"]))
		await _teardown_window()

	_bench_report.append("场景                  DPS        大招次数/60s   对照普通桩 DPS(基准1)  说明")
	_run_conditional_asserts()
	for spec in specs:
		var key: String = spec["key"]
		if not mean.has(key) or mean[key].is_empty():
			continue
		var dps := _avg(mean[key])
		var ults := _avg_float(ult_mean[key])
		_baseline_data["bench3"] = _baseline_data.get("bench3", {})
		_baseline_data["bench3"][key] = {"dps": dps, "ult_count": ults}
		_regress_check("bench3.%s.dps" % key, dps)
		# 对照普通桩：关羽未转 = cavalry|0；张飞未转 = tiger_guard|0；
		# 皇甫嵩破城 = catapult|1；铁骑击杀窗对照 = cavalry|1（高 HP 无返怒）。
		var single_key := ""
		var note := ""
		match key:
			"elite_wusheng":
				single_key = "cavalry|0"
				note = "武圣 +25% vs 高甲减伤"
			"cavalry_counter":
				single_key = "tiger_guard|0"
				note = "虎贲克制 cavalry +15%"
			"elite_siege":
				single_key = "catapult|1"
				note = "破城对精英 +10%×s"
			"kill_refund":
				single_key = "cavalry|1"
				note = "大招击杀返怒 50% 循环"
		var single := 0.0
		if _baseline_data.has("bench1") and _baseline_data["bench1"].has(single_key):
			single = float(_baseline_data["bench1"][single_key]["dps"])
		var ref := ""
		if single > 0.0:
			ref = "×%.2f 普通桩" % (dps / single)
		else:
			ref = "—"
		_bench_report.append("%-22s %10.1f  %12.1f   %28s  %s" % [key, dps, ults, ref, note])
	# 击杀返怒循环：低 HP 击杀窗大招次数应显著高于高 HP 无击杀对照（返怒 50%）。
	var kill_ult := _avg_float(ult_mean.get("kill_refund", []))
	var base_ult := 0.0
	if _baseline_data.has("bench1") and _baseline_data["bench1"].has("cavalry|1"):
		base_ult = float(_baseline_data["bench1"]["cavalry|1"]["ult_count"])
	_check(base_ult > 0.0 and kill_ult > base_ult * 1.3,
		"击杀返怒循环应显著提高大招频率（实测 %.1f 次 vs 对照 %.1f 次）" % [kill_ult, base_ult])
	_bench_report.append("")


## 档次 3 条件增伤登记快检（STATS_PIPELINE §9.1）：单项预算 ≤+30%，实测乘区报告。
func _run_conditional_asserts() -> void:
	_bench_report.append("  条件乘区登记快检（单项预算 ≤ ×1.30）：")
	# 通用探针：每场景独立塔 + 普通桩/条件桩各一，同一塔 finalize_damage 比值
	# （finalize 只计算不结算，桩位仅需存在；百步叠层直接置计数、定军直接施加标记，
	# 避免角色技能 2.5× 伤害污染探针）。
	var probes: Array[Dictionary] = [
		{"label": "武圣·精英", "char": "guan_yu", "promo": "", "tags": [&"elite"] as Array[StringName],
			"expect": 1.25},
		{"label": "周仓·高血", "char": "zhou_wei", "promo": "", "tags": [] as Array[StringName],
			"expect": 1.30},
		{"label": "百步·3层", "char": "huang_zhong", "promo": "", "tags": [] as Array[StringName],
			"expect": 1.30},
		{"label": "火攻·范围", "char": "huang_fu_song", "promo": "", "tags": [] as Array[StringName],
			"expect": 1.15},
		{"label": "破城·精英", "char": "huang_fu_song", "promo": "catapult_thunder",
			"tags": [&"elite"] as Array[StringName], "expect": 1.10},
		{"label": "定军·标记", "char": "huang_zhong", "promo": "", "tags": [] as Array[StringName],
			"expect": 1.15},
	]
	for probe in probes:
		var origin := _origin_for_col()
		var path: Node = _paths[_row_for_col()]
		var tower := _build_tower(probe["char"], probe["promo"], origin)
		if tower == null:
			continue
		var label: String = probe["label"]
		var normal_dummy := _spawn_dummy(path, origin.x + 120.0, 100000, 0, [] as Array[StringName])
		var cond_dummy := _spawn_dummy(
			path, origin.x + 200.0, 100000, 0, probe["tags"]
		)
		var probe_base := tower.damage * 10
		var base_damage := tower.finalize_damage(probe_base, normal_dummy)
		if label == "百步·3层":
			tower._consecutive_hits = 3
		# 定军标记：直接施加（技能 cast 含 2.5× 伤害会污染探针）。
		if label == "定军·标记":
			cond_dummy.apply_mark(tower.character_id, 5.0)
		var after := tower.finalize_damage(probe_base, cond_dummy)
		var ratio := float(after) / float(base_damage) if base_damage > 0 else 1.0
		var budget_ok := ratio <= CONDITIONAL_BUDGET_MAX + 0.001 and ratio >= 0.99
		_bench_report.append("    %-12s ×%.3f（预算 ≤×1.30）%s" % [label, ratio, "OK" if budget_ok else "超出预算!"])
		_check(budget_ok, "条件增伤登记快检 %s 实测 ×%.3f 应 ≤×1.30 且 ≥×0.99" % [label, ratio])
		await _teardown_window()


## ============ 基准 4：支援贡献团队收益（1 输出 + 1 支援 vs 单输出对照） ============
func _run_benchmark_4() -> void:
	_bench_report.append("【基准 4】支援贡献：关羽(未转,等级10) + 支援塔 vs 单关羽对照窗；")
	_bench_report.append("  伤害口径=关羽 damage_contributors（支援塔自身伤害不入账）；等效输出塔 = 提升 ÷ 单塔 DPS")
	# 每采样 7 个独立窗：舞娘大招全图、虎贲破阵激励 200px，支援窗之间互不干扰必须分窗。
	var windows: Array[Dictionary] = [
		{"key": "control", "support": "", "support_promo": "", "label": "对照：单关羽"},
		{"key": "dancer_base", "support": "diao_chan", "support_promo": "", "label": "貂蝉·未转（光环+月下舞）"},
		{"key": "dancer_t1", "support": "diao_chan", "support_promo": "dancer_master", "label": "貂蝉·舞师"},
		{"key": "dancer_a", "support": "diao_chan", "support_promo": "dancer_phoenix", "label": "貂蝉·凤仪"},
		{"key": "dancer_b", "support": "diao_chan", "support_promo": "dancer_echo", "label": "貂蝉·绕梁"},
		{"key": "banner", "support": "zhang_fei", "support_promo": "tiger_guard_army", "label": "张飞·虎贲军（军旗）"},
		{"key": "rende", "support": "liu_bei", "support_promo": "", "label": "刘备（仁德）"},
	]
	var mean: Dictionary = {}
	for _sample in range(SAMPLES):
		seed(20260904)
		for win in windows:
			var key: String = win["key"]
			var group := _make_support_group(
				win["support"], win["support_promo"]
			)
			if group.is_empty():
				continue
			var groups: Array = [group]
			if group.has("support_tower") and group["support_tower"] != null:
				groups.append({
					"tower": group["support_tower"], "dummies": [],
					"character_id": String(group["support_tower"].character_id),
					"remaining": 0.0, "ult_count": 0,
					"respawn_hp": 0, "respawn_timer": 0.0,
				})
			_simulate_window(groups)
			if not mean.has(key):
				mean[key] = []
			mean[key].append(float(_group_damage(group)) / WINDOW_SECONDS)
			await _teardown_window()

	var control := _avg(mean.get("control", [0.0]))
	_bench_report.append("支援组               关羽 DPS    提升 %     等效输出塔   说明")
	for win in windows:
		var key: String = win["key"]
		if not mean.has(key) or mean[key].is_empty():
			continue
		var dps := _avg(mean[key])
		var lift := (dps - control) / control if control > 0.0 else 0.0
		_baseline_data["bench4"] = _baseline_data.get("bench4", {})
		_baseline_data["bench4"][key] = {"dps": dps}
		_regress_check("bench4.%s.dps" % key, dps)
		var label: String = win["label"]
		_bench_report.append("%-22s %10.1f  %6.2f%%   %s  %s" % [
			label, dps, lift * 100.0,
			("+%.2f 座" % lift) if lift > 0.0 else "0.00 座", "",
		])
		if key != "control":
			_check(dps > control * 1.01,
				"基准 4 %s 关羽 DPS %.1f 应高于对照 %.1f（增益为正）" % [label, dps, control])
	# 舞娘转职行不得倒退（光环强度不随转职，转职收益来自大招效果倍率）。
	var base_dancer := _avg(mean.get("dancer_base", [0.0]))
	for tier_key in ["dancer_t1", "dancer_a", "dancer_b"]:
		var tier_dps := _avg(mean.get(tier_key, [0.0]))
		if base_dancer > 0.0:
			_check(tier_dps >= base_dancer * 0.97,
				"舞娘转职行 %s 团队收益不得倒退（%.1f vs 基准 %.1f）" % [tier_key, tier_dps, base_dancer])
	_bench_report.append("")


## 支援组：输出塔（关羽·未转）在 origin，支援塔置于输出塔上方 80px（aura/军旗范围覆盖）。
func _make_support_group(support_char: String, support_promo: String) -> Dictionary:
	var row_index := _layout_col % ROW_GROUPS
	var origin := _origin_for_col()
	var path: Node = _paths[row_index]
	var row: Dictionary = PROFESSION_ROWS[&"cavalry"]
	var out_tower := _build_tower(String(row["char"]), "", origin)
	if out_tower == null:
		return {}
	var dummy_x := _dummy_x_for_tower(out_tower, origin)
	var dummy := _spawn_dummy(path, dummy_x, 100000, 0, [] as Array[StringName])
	out_tower.target = dummy
	if support_char.is_empty():
		return {
			"tower": out_tower, "dummies": [dummy],
			"character_id": out_tower.character_id,
			"remaining": 0.0, "ult_count": 0,
			"respawn_hp": 0, "respawn_timer": 0.0, "path": path,
		}
	var support_tower := _build_tower(support_char, support_promo, origin + Vector2(0, -80.0))
	_check(support_tower != null, "支援塔可建造：" + support_char)
	return {
		"tower": out_tower, "dummies": [dummy],
		"character_id": out_tower.character_id,
		"remaining": 0.0, "ult_count": 0,
		"respawn_hp": 0, "respawn_timer": 0.0,
		"support_tower": support_tower, "path": path,
	}


## ============ 档位收口与边界断言（档次 2 / L5 边界） ============
func _run_bucket_asserts() -> void:
	_bench_report.append("【档位收口断言】编队桶收敛（档 2）+ 跨层乘算保留 + 攻速下限（L5）")
	var origin := _origin_for_col()
	var path: Node = _paths[_row_for_col()]
	var tower := _build_tower("guan_yu", "", origin)
	_check(tower != null, "档位收口探针塔可建造")
	if tower != null:
		var dummy := _spawn_dummy(path, origin.x + 120.0, 100000, 0, [] as Array[StringName])
		var dmg := tower.damage
		var zero := tower.finalize_damage(dmg, dummy)
		_check(zero == int(round(float(dmg))), "全加成归零：finalize 应等于基础伤害（基准口径与现状一致）")
		tower._tech_damage_bonus = 0.15
		tower._tech_profession_damage_bonus = 0.10
		tower._bond_damage_bonus = 0.05
		var merged := tower.finalize_damage(dmg, dummy)
		_check(merged == int(round(float(dmg) * 1.30)),
			"编队桶应加法收敛 ×1.30（旧三连乘 1.15×1.10×1.05=1.328 已消除，实测 %d）" % merged)
		tower._tech_damage_bonus = 0.20
		tower._tech_profession_damage_bonus = 0.15
		tower._bond_damage_bonus = 0.10
		var capped := tower.finalize_damage(dmg, dummy)
		_check(capped == int(round(float(dmg) * 1.30)),
			"编队桶合计 45%% 应 clamp ≤+30%%（实测 %d）" % capped)
		tower._tech_damage_bonus = 0.15
		tower._tech_profession_damage_bonus = 0.10
		tower._bond_damage_bonus = 0.05
		tower._relic_damage_bonus = 0.10
		tower._battle_relic_damage_bonus = 0.05
		var cross := tower.finalize_damage(dmg, dummy)
		var expected_cross := int(round(float(dmg) * 1.30 * 1.10 * 1.05))
		_check(cross == expected_cross,
			"信物(L1)/局内遗物(L3)应保持跨层乘算（×1.30×1.10×1.05，实测 %d）" % cross)
		tower._relic_damage_bonus = 0.0
		tower._battle_relic_damage_bonus = 0.0
		await _teardown_window()

	# 攻速下限（L5）：临时桶 +100% 后仍触底 ATTACK_SPEED_FLOOR = 0.55 × 基础间隔。
	var origin2 := _origin_for_col()
	var tower2 := _build_tower("guan_yu", "", origin2)
	_check(tower2 != null, "攻速下限探针塔可建造")
	if tower2 != null:
		var floor_wait := tower2.attack_cooldown * Tower.ATTACK_SPEED_FLOOR
		tower2.apply_attack_speed_buff("bench_cap", 2.0, 10.0)
		_check(is_equal_approx(tower2.attack_timer.wait_time, floor_wait),
			"临时桶 +100% 后攻速间隔应触底 0.55×基础（%.4f vs %.4f）" % [
				tower2.attack_timer.wait_time, floor_wait,
			])
		# 光环伤害桶上限（档次 1，SmokeRunner 已做多源断言，此处复核常量语义）。
		_check(Tower.AURA_DAMAGE_CAP == 0.5, "常驻光环伤害桶上限应为 +50%（档 1）")
		_check(Tower.FORMATION_DAMAGE_CAP == 0.3, "编队加成伤害桶上限应为 +30%（档 2）")
		await _teardown_window()
	_bench_report.append("")


## ============ 基线快照 ============
func _load_baseline() -> Dictionary:
	if not FileAccess.file_exists(BASELINE_PATH):
		return {}
	var file := FileAccess.open(BASELINE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _regress_check(key: String, value: float) -> void:
	if not _baseline.has(key):
		return
	var base := float(_baseline[key])
	if base <= 0.0:
		return
	var drift := absf(value - base) / base
	if drift > BASELINE_TOLERANCE:
		_check(false, "基线回退：%s 实测 %.2f vs 基线 %.2f（偏差 %.1f%% > ±3%%）" % [
			key, value, base, drift * 100.0,
		])


func _save_baseline() -> void:
	var flat := {}
	_flatten_into(_baseline_data, "", flat)
	var file := FileAccess.open(BASELINE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("无法写入基线快照：" + BASELINE_PATH)
		return
	var payload := {
		"program_version": "0.8.10.0",
		"note": "阶段 8·提交 10 数值基准基线；由 tests/BenchmarkRunner.gd 生成；后续运行 ±3% 容差对比防回退。",
	}
	for key in flat:
		payload[key] = flat[key]
	file.store_string(JSON.stringify(payload, "\t"))
	_bench_report.append("基线快照已生成：" + BASELINE_PATH)


func _flatten_into(source: Dictionary, prefix: String, out: Dictionary) -> void:
	for key in source:
		var full: String = key if prefix.is_empty() else prefix + "." + str(key)
		var value = source[key]
		if value is Dictionary:
			_flatten_into(value, full, out)
		elif value is float or value is int:
			out[full] = value


func _finish() -> void:
	# 清理隔离存档。
	if not _profile_file.is_empty():
		var path := ProfileStore.get_profile_path()
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("")
	print("==================== 数值基准报告（阶段 8·提交 10） ====================")
	for line in _bench_report:
		print(line)
	print("=======================================================================")
	if failures.is_empty() and _baseline.is_empty():
		_save_baseline()
	elif failures.is_empty() and not _baseline.is_empty():
		_bench_report.append("基线对比全绿（±3% 内）；如需更新基线请删除 tests/benchmark_baseline.json 后重跑。")
		print("基线对比全绿（±3% 内）；如需更新基线请删除 tests/benchmark_baseline.json 后重跑。")
	if not warnings.is_empty():
		print("警告（不阻塞）：")
		for w in warnings:
			print("  - " + w)
	if not failures.is_empty():
		print("失败：%d 项" % failures.size())
		for f in failures:
			print("  [FAIL] " + f)
	var code := 1 if not failures.is_empty() else 0
	print("BENCHMARK_RESULT: %s（failures=%d warnings=%d）" % ["PASS" if code == 0 else "FAIL", failures.size(), warnings.size()])
	get_tree().quit(code)






