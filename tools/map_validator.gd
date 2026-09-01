extends SceneTree

class_name MapValidator

## 地图校验器（v0.23.0 拍板，阶段 8 提交 3）：自由建造配套布局校验。
## 独立运行：godot --headless --path . -s tools/map_validator.gd
## 同时作为 class_name 供冒烟/流程测试调用（validate_stage）。

const CHAPTER_DIR := "res://resources/stages/chapter_01"


func _initialize() -> void:
	var failures: Array[String] = []
	var dir := DirAccess.open(CHAPTER_DIR)
	if dir == null:
		push_error("无法打开章节关卡目录: " + CHAPTER_DIR)
		quit(1)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var stage := load("%s/%s" % [CHAPTER_DIR, entry]) as StageData
			if stage != null:
				var stage_issues: Array[String] = []
				var ok := validate_stage(stage, stage_issues)
				if not ok:
					failures.append("%s: %s" % [entry, "；".join(stage_issues)])
		entry = dir.get_next()
	dir.list_dir_end()
	if failures.is_empty():
		print("MAP_VALIDATOR_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("MAP_VALIDATOR: " + failure)
		print("MAP_VALIDATOR_FAILED: %d" % failures.size())
		quit(1)

## 校验单关布局，问题写入 issues。返回是否全部通过。
static func validate_stage(stage: StageData, issues: Array[String] = []) -> bool:
	if stage == null:
		issues.append("关卡数据为空")
		return false
	var ok := true
	var road := _to_set(GridBackground.derive_road_cells(stage.path_points))
	var fork_road := _to_set(GridBackground.derive_road_cells(stage.fork_path_points))
	var forbidden := _to_set(stage.forbidden_cells)
	var entry_cell := _first_road_cell(stage.path_points, road)
	var base_cell := _last_road_cell(stage.path_points, road)

	# 1. 禁建地形不与道路/入口/基地重叠。
	for cell in forbidden.keys():
		if road.has(cell) or fork_road.has(cell):
			issues.append("禁建格 %s 与道路重叠" % cell)
			ok = false
	if forbidden.has(entry_cell) or forbidden.has(base_cell):
		issues.append("入口/基地格被禁建地形覆盖")
		ok = false

	# 2. 每条路线存在完整通路（入口 → 基地，4 连通）。
	var all_road := road.duplicate()
	for cell in fork_road.keys():
		all_road[cell] = true
	if entry_cell == Vector2i(-1, -1) or base_cell == Vector2i(-1, -1):
		issues.append("入口/基地不在图内道路上")
		ok = false
	elif not _is_connected(entry_cell, base_cell, all_road):
		issues.append("主路径不通（入口 %s → 基地 %s）" % [entry_cell, base_cell])
		ok = false
	if not fork_road.is_empty():
		var fork_entry := _first_road_cell(stage.fork_path_points, fork_road)
		var fork_join := _nearest_road_cell(fork_entry, road)
		if fork_join == Vector2i(-1, -1):
			issues.append("分叉路径未汇入主路径")
			ok = false

	# 3. 每条路线至少 2 个有效覆盖区（贴路可建格 ≥2 组/总数 ≥4）。
	var buildable := _buildable_cells(road, forbidden)
	if buildable.size() < 4:
		issues.append("贴路可建格不足（%d < 4）" % buildable.size())
		ok = false
	elif _road_adjacent_groups(road, buildable) < 2:
		issues.append("有效覆盖区不足 2 组")
		ok = false

	# 4. 每种职业至少 1 个可用位置：近战贴路位 + 中/远程 2 格内位。
	var melee_found := false
	var ranged_found := false
	for cell in buildable:
		if _distance_to_road(cell, road) == 1:
			melee_found = true
		if _distance_to_road(cell, road) <= 2:
			ranged_found = true
	if not melee_found:
		issues.append("缺少贴路位（近战职业无可用位置）")
		ok = false
	if not ranged_found:
		issues.append("缺少中/远程位（远程职业无可用位置）")
		ok = false
	return ok


static func _to_set(cells: Array[Vector2i]) -> Dictionary:
	var set: Dictionary = {}
	for cell in cells:
		set[cell] = true
	return set


static func _first_road_cell(path_points: Array[Vector2], road: Dictionary) -> Vector2i:
	for cell in GridBackground.derive_road_cells(path_points):
		if road.has(cell):
			return cell
	return Vector2i(-1, -1)


static func _last_road_cell(path_points: Array[Vector2], road: Dictionary) -> Vector2i:
	var cells := GridBackground.derive_road_cells(path_points)
	for index in range(cells.size() - 1, -1, -1):
		if road.has(cells[index]):
			return cells[index]
	return Vector2i(-1, -1)


static func _is_connected(from: Vector2i, to: Vector2i, road: Dictionary) -> bool:
	if from == to:
		return true
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [from]
	visited[from] = true
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in directions:
			var next: Vector2i = current + direction
			if next == to:
				return true
			if road.has(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return false


static func _buildable_cells(road: Dictionary, forbidden: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in road.keys():
		var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for offset in offsets:
			var neighbor: Vector2i = cell + offset
			if neighbor.x < 0 or neighbor.x >= GridBackground.COLS \
					or neighbor.y < 0 or neighbor.y >= GridBackground.ROWS:
				continue
			if road.has(neighbor) or forbidden.has(neighbor):
				continue
			if not result.has(neighbor):
				result.append(neighbor)
	return result


static func _road_adjacent_groups(road: Dictionary, buildable: Array[Vector2i]) -> int:
	var grouped: Dictionary = {}
	for cell in buildable:
		var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for offset in offsets:
			if road.has(cell + offset):
				grouped[cell] = true
				break
	# 统计连通簇（4 连通）数量。
	var visited: Dictionary = {}
	var clusters := 0
	for cell in grouped.keys():
		if visited.has(cell):
			continue
		clusters += 1
		var queue: Array[Vector2i] = [cell]
		visited[cell] = true
		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			for offset in offsets:
				var next: Vector2i = current + offset
				if grouped.has(next) and not visited.has(next):
					visited[next] = true
					queue.append(next)
	return clusters


static func _distance_to_road(cell: Vector2i, road: Dictionary) -> int:
	var best := 999
	for road_cell in road.keys():
		var distance := absi(road_cell.x - cell.x) + absi(road_cell.y - cell.y)
		if distance < best:
			best = distance
		if best <= 1:
			break
	return best


static func _nearest_road_cell(from: Vector2i, road: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := 999
	for cell in road.keys():
		var distance := absi(cell.x - from.x) + absi(cell.y - from.y)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best
