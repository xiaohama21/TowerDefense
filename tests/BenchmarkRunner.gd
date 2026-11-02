extends Node

## 阶段 9·提交 1 品阶数值基准（modules/STATS_PIPELINE.md）：
## headless 确定性虚拟时钟模拟——固定 delta 步进、同一 seed、3 次采样取均值；
## 与战斗数值同源（走真实 Tower/Enemy/Bullet 节点与 _process/_physics_process，
## 不另抄任何数值公式）。首次运行生成 tests/benchmark_rank_baseline.json，
## 后续与快照对比（±3% 容差）防平衡回退；断言失败以非零退出码结束。

const TOWER_SCENE := preload("res://scenes/Tower.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const TOWER_MANAGER_SCRIPT := preload("res://scripts/TowerManager.gd")

const VIRTUAL_DELTA: float = 0.02
const WINDOW_TICKS: int = int(60.0 / VIRTUAL_DELTA)
const WINDOW_SECONDS: float = 60.0
const SAMPLES: int = 3
const BASELINE_TOLERANCE: float = 0.03
const BASELINE_PATH := "res://tests/benchmark_rank_baseline.json"

const CHARACTER_DIR := "res://resources/characters/"

## 每行（y 复用 3 条 Path2D）组数；相邻列间距 1500px 防跨组溅射/弹道串扰。
const ROW_GROUPS: int = 3
const COL_SPACING: float = 1500.0
const ROW_SPACING: float = 600.0

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

	_baseline = _load_baseline()
	seed(20260904)
	await _run_rank_benchmarks()
	await _run_support_benchmarks()
	_run_bucket_asserts()
	_finish()


## 临时调试探针（BENCH_DEBUG=1 时运行）：复现「打几下就停」场景。
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


func _build_tower(character_base: String, rank: int, origin: Vector2) -> Tower:
	var character_data := load(CHARACTER_DIR + character_base + ".tres") as CharacterData
	_check(character_data != null, "角色资源可加载：" + character_base)
	var loadout := {"level": CharacterRank.LEVELS[clampi(rank, 0, 5)], "rank": rank}
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
	rank: int,
	dummy_count: int,
	dummy_hp: int,
	dummy_armor: int,
	dummy_tags: Array[StringName],
	respawn_hp: int = 0
) -> Dictionary:
	var row := _layout_col % ROW_GROUPS
	var origin := _origin_for_col()
	var path: Node = _paths[row]
	var tower := _build_tower(character_base, rank, origin)
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
		# 0.8.16.6 命中帧结算：近战大招不再即时落地，须等延迟队列排空（否则单发实测读 0）。
		if released and not _has_pending_bullets(tower) and not tower.has_pending_combat_steps():
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


## 六阶品阶、单体与三目标输出，各 60s × 3 次固定随机种子。
func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for v in values:
		sum += float(v)
	return sum / values.size()


func _avg_float(values: Array) -> float:
	return _avg(values)


## 支援贡献使用真实增益与伤害链路。
func _make_support_group(support_char: String, support_rank: int) -> Dictionary:
	var row_index := _layout_col % ROW_GROUPS
	var origin := _origin_for_col()
	var path: Node = _paths[row_index]
	var out_tower := _build_tower("guan_yu", 0, origin)
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
	var support_tower := _build_tower(support_char, support_rank, origin + Vector2(0, -80.0))
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
	var tower := _build_tower("guan_yu", 0, origin)
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
	var tower2 := _build_tower("guan_yu", 0, origin2)
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
		"program_version": "0.9.1.0",
		"note": "阶段 9·提交 1（六阶品阶、百分比成长与暴击）数值基准基线；由 tests/BenchmarkRunner.gd 生成；后续运行 ±3% 容差对比防回退。",
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
	print("==================== 数值基准报告（阶段 9·提交 1 / 0.9.1.0） ====================")
	for line in _bench_report:
		print(line)
	print("=======================================================================")
	if failures.is_empty() and _baseline.is_empty():
		_save_baseline()
	elif failures.is_empty() and not _baseline.is_empty():
		_bench_report.append("基线对比全绿（±3% 内）；如需更新基线请删除 tests/benchmark_rank_baseline.json 后重跑。")
		print("基线对比全绿（±3% 内）；如需更新基线请删除 tests/benchmark_rank_baseline.json 后重跑。")
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







## Real Tower/Enemy/Bullet simulation: every rank and attack pattern, single and AoE.
func _run_rank_benchmarks() -> void:
	for count in [1, 3]:
		for character_id in ["guan_yu", "zhang_fei", "huang_zhong", "huang_fu_song", "zhuge_liang", "zhao_yun", "zhou_wei"]:
			var prior := 0.0
			for rank in range(6):
				var samples: Array = []
				for sample in range(SAMPLES):
					seed(20261030 + sample)
					var group := _make_group(character_id, rank, count, 1000000, 20, [] as Array[StringName])
					_simulate_window([group])
					samples.append(float(_group_damage(group)) / WINDOW_SECONDS)
					await _teardown_window()
				var dps := _avg(samples)
				var key := "%s.%d.%d" % [character_id, rank, count]
				_baseline_data[key] = dps
				_regress_check(key, dps)
				_check(dps > 0.0 and dps >= prior * 0.99, "品阶 DPS 递进：%s %.2f vs %.2f" % [key, dps, prior])
				prior = dps
				_bench_report.append("%s DPS %.2f" % [key, dps])

func _run_support_benchmarks() -> void:
	var control := 0.0
	for support in ["", "liu_bei", "diao_chan"]:
		var group := _make_support_group(support, 0)
		var groups: Array = [group]
		if group.has("support_tower"):
			groups.append({"tower": group["support_tower"], "dummies": [], "character_id": support, "remaining": 0.0, "ult_count": 0, "respawn_hp": 0, "respawn_timer": 0.0})
		seed(20261030)
		_simulate_window(groups)
		var dps := float(_group_damage(group)) / WINDOW_SECONDS
		if support.is_empty():
			control = dps
		else:
			_check(dps > control, "支援应提高团队输出：" + support)
		var key: String = "support." + ("control" if support.is_empty() else support)
		_baseline_data[key] = dps
		_regress_check(key, dps)
		_bench_report.append("%s DPS %.2f" % [key, dps])
		await _teardown_window()
