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
	var paths := stage.get_paths()
	var all_road := _to_set(GridBackground.derive_stage_road_cells(stage))
	var forbidden := _to_set(stage.forbidden_cells)
	var primary := GridBackground.trace_road_cells(stage.path_points)
	var base: Vector2i = primary.back() if not primary.is_empty() else Vector2i(-1,-1)
	for id in stage.alternate_paths:
		if id.is_empty() or id in [&"main", &"fork", &"auto"]:
			issues.append("支路ID为空或使用保留ID: " + str(id))
	for id in stage.get_normal_path_ids():
		if not paths.has(id): issues.append("普通出怪引用未知路线: " + str(id))
	for wave in stage.waves:
		if wave == null: continue
		for group in wave.spawn_groups:
			if group != null and group.path_id != &"auto" and not paths.has(group.path_id):
				issues.append("波次引用未知路线: " + str(group.path_id))
	for cell in forbidden:
		if all_road.has(cell): issues.append("禁建格 %s 与道路重叠" % cell)
	for id in paths:
		var points: Array[Vector2] = []
		points.assign(paths[id])
		if points.size() < 2:
			issues.append("路线 %s 少于两个路径点" % id)
			continue
		for i in range(points.size()):
			var at := points[i]
			if not is_equal_approx(fposmod(at.x-40,80),0) or not is_equal_approx(fposmod(at.y-40,80),0):
				issues.append("路线 %s 路径点未对齐80px格中心" % id)
			if i > 0:
				var delta := at-points[i-1]
				if delta == Vector2.ZERO or (not is_zero_approx(delta.x) and not is_zero_approx(delta.y)):
					issues.append("路线 %s 包含零长或斜向路段" % id)
		var cells := GridBackground.trace_road_cells(points)
		if cells.is_empty():
			issues.append("路线 %s 无图内通路" % id)
			continue
		if cells.back() != base: issues.append("路线 %s 未汇入同一基地" % id)
		for i in range(1,cells.size()):
			var step := cells[i]-cells[i-1]
			if absi(step.x)+absi(step.y) != 1:
				issues.append("路线 %s 图内路段不连续" % id)
		var road := _to_set(cells)
		var buildable: Array[Vector2i] = []
		for cell in _buildable_cells(road,forbidden):
			if not all_road.has(cell): buildable.append(cell)
		if buildable.size() < 4:
			issues.append("路线 %s 贴路可建格不足4格" % id)
		elif _road_adjacent_groups(road,buildable) < 2:
			issues.append("路线 %s 有效覆盖区不足2组" % id)
	return issues.is_empty()


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
