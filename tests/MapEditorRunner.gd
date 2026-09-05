extends Node

## 地图编辑器 M1 headless 回归（程序 0.8.10.5，BUGS B-029 / B-030）：
## 项目运行模式直接实例化编辑器窗口脚本（无需打开 Godot 编辑器），
## 断言画布等比结构（B-030）、窗口关闭行为（B-029）与 s01 数据一致性（M1 验收）。

const WINDOW_SCRIPT := preload("res://addons/map_editor/map_editor_window.gd")

var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MAP_EDITOR_TEST: %s" % message)


## 找一个非道路 / 非装饰 / 非禁建 / 非建造位的格（M2 笔刷用例）。
func _find_free_cell(editor) -> Vector2i:
	var road := {}
	for cell in editor._path_cells:
		road[cell] = true
	for col in range(GridBackground.COLS):
		for row in range(GridBackground.ROWS):
			var cell := Vector2i(col, row)
			if road.has(cell):
				continue
			if editor._stage.decor_cells.has(cell):
				continue
			if editor._stage.forbidden_cells.has(cell):
				continue
			var center := Vector2(cell * GridBackground.GRID_SIZE) + Vector2(40, 40)
			if editor._stage.build_slot_positions.has(center):
				continue
			return cell
	return Vector2i(-1, -1)


func _run() -> void:
	var editor = WINDOW_SCRIPT.new()
	add_child(editor)

	# ===== B-031：根容器全矩形锚点（Window 不自动拉伸直接 Control 子节点，
	# 缺锚点时整个 UI 按最小尺寸挤在窗口左上角、画布只占一角） =====
	var margin := editor.get_child(0) as MarginContainer
	_check(margin != null, "根 MarginContainer 存在")
	if margin != null:
		_check(
			margin.anchor_right == 1.0 and margin.anchor_bottom == 1.0,
			"根容器应全矩形锚点（anchor_right/bottom=1），实测 (%s, %s)" % [margin.anchor_right, margin.anchor_bottom]
		)

	# ===== B-030：画布恒按 1280×720 逻辑分辨率布局 + 16:9 等比容器 =====
	var viewport: SubViewport = editor._viewport
	_check(viewport != null, "SubViewport 未创建")
	if viewport != null:
		_check(
			viewport.size_2d_override == Vector2i(1280, 720),
			"画布逻辑分辨率应为 1280×720（size_2d_override），实测 %s" % str(viewport.size_2d_override)
		)
		_check(
			viewport.size_2d_override_stretch,
			"size_2d_override_stretch 应为 true（逻辑分辨率缩放铺满视口，防裁切）"
		)
		var canvas_container := viewport.get_parent() as SubViewportContainer
		_check(canvas_container != null, "SubViewport 应挂在 SubViewportContainer 下")
		if canvas_container != null:
			_check(canvas_container.stretch, "SubViewportContainer.stretch 应为 true（视口尺寸随容器）")
			_check(
				canvas_container.get_parent() is AspectRatioContainer,
				"SubViewportContainer 外应包 AspectRatioContainer（16:9 等比居中，防变形）"
			)

	# ===== M1 验收：默认载入 ch01_s01 且与运行时同口径 =====
	_check(not editor._stage_paths.is_empty(), "未扫描到任何关卡资源")
	if not editor._stage_paths.is_empty():
		var default_path: String = editor._stage_paths[editor._stage_option.selected]
		_check(
			default_path.ends_with("ch01_s01.tres"),
			"默认选中应为 ch01_s01，实测 %s" % default_path
		)
	_check(editor._stage != null, "默认关卡未载入")
	var panel_text := editor._data_label.text as String
	_check(panel_text.contains("网格：16×9（80px/格 · 1280×720）"), "数据面板应含网格规格行 16×9（80px/格）")
	_check(panel_text.contains("路格：21"), "s01 路格数应为 21，实测面板：%s" % panel_text)
	_check(panel_text.contains("入口：(0,3)"), "s01 入口格应为 (0,3)（图内首格，与运行时一致）")
	_check(panel_text.contains("基地：(15,4)"), "s01 基地格应为 (15,4)（图内末格，与运行时一致）")
	_check(panel_text.contains("装饰格：12　禁建格：4"), "s01 装饰 12 / 禁建 4")
	_check(panel_text.contains("建造位：10"), "s01 建造位应为 10")
	_check(panel_text.contains("MapValidator 通过"), "s01 应通过 MapValidator 校验")

	# ===== B-029：右上角 X（close_requested）可关闭窗口 =====
	_check(
		editor.get_signal_connection_list("close_requested").size() >= 1,
		"close_requested 应有连接处理（点 X 无响应 bug 回归）"
	)
	_check(editor.visible, "窗口实例化后应可见")
	editor.close_requested.emit()
	_check(not editor.visible, "close_requested 后窗口应隐藏（X 关闭）")

	# ===== M2：笔刷编辑（路径链 / 装饰 / 禁建 / 建造位 / 主题 / 反转 / 撤销） =====
	_check(editor._path_cells.size() == 21, "s01 路径链应 21 格，实测 %d" % editor._path_cells.size())
	_check(editor._green_history.size() >= 1, "载入校验通过后应有绿色快照")

	# 主题切换写入 stage.theme
	var fire_index := -1
	for i in range(editor._theme_option.item_count):
		if editor._theme_option.get_item_text(i) == "fire":
			fire_index = i
	editor._on_theme_selected(fire_index)
	_check(String(editor._stage.theme) == "fire", "主题切换应写入 stage.theme")
	_check((editor._data_label.text as String).contains("主题：fire"), "数据面板主题应刷新")
	editor._on_theme_selected(0)
	_check(String(editor._stage.theme) == "grass", "主题切回 grass")

	# 装饰刷点涂 / 再点擦除
	var free_cell := _find_free_cell(editor)
	_check(free_cell.x >= 0, "应存在非路非装饰空格")
	editor._brush = editor.Brush.DECOR
	editor._apply_brush_at(free_cell)
	_check(editor._stage.decor_cells.has(free_cell), "装饰刷点涂应写入 decor_cells")
	_check((editor._data_label.text as String).contains("装饰格：13"), "面板装饰计数应刷新为 13")
	editor._apply_brush_at(free_cell)
	_check(not editor._stage.decor_cells.has(free_cell), "装饰刷再点同格应擦除")
	_check((editor._data_label.text as String).contains("装饰格：12"), "面板装饰计数应回到 12")

	# 建造位刷：空格添加 / 再点擦除；画上道路格记编辑器错误
	var slot_cell := _find_free_cell(editor)
	editor._brush = editor.Brush.SLOT
	editor._apply_brush_at(slot_cell)
	_check(editor._stage.build_slot_positions.size() == 11, "建造位刷应 +1（11），实测 %d" % editor._stage.build_slot_positions.size())
	editor._apply_brush_at(slot_cell)
	_check(editor._stage.build_slot_positions.size() == 10, "建造位刷再点应擦除（10）")
	var road_cell: Vector2i = editor._path_cells[0]
	editor._apply_brush_at(road_cell)
	_check(not editor._editor_errors().is_empty(), "建造位与道路重叠应记编辑器错误")
	_check((editor._data_label.text as String).contains("✖"), "面板应显示编辑器错误 ✖")
	var errors_before_undo: int = editor._green_history.size()
	editor._on_undo_pressed()
	_check(editor._editor_errors().is_empty(), "撤销应回到上次校验通过态（错误消除）")
	_check(editor._green_history.size() == errors_before_undo - 1, "撤销应弹出绿色快照")

	# 路径刷：基地端 4 邻延伸 / 点击新端点退格；path_points 自动生成含图外延长段
	var tail: Vector2i = editor._path_cells[editor._path_cells.size() - 1]
	var extend_cell := Vector2i(-1, -1)
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var candidate: Vector2i = tail + offset
		if candidate.x >= 0 and candidate.x < GridBackground.COLS \
				and candidate.y >= 0 and candidate.y < GridBackground.ROWS \
				and not editor._path_cells.has(candidate):
			extend_cell = candidate
			break
	_check(extend_cell.x >= 0, "基地端应存在可延伸邻格")
	editor._brush = editor.Brush.PATH
	var points_before: int = editor._stage.path_points.size()
	editor._apply_brush_at(extend_cell)
	_check(editor._path_cells.size() == 22, "路径延伸后链长应 22，实测 %d" % editor._path_cells.size())
	_check((editor._data_label.text as String).contains("路格：22"), "面板路格数应刷新为 22")
	_check(editor._stage.path_points.size() == points_before + 1, "延伸应新增 path_points 点（含延长段）")
	var expected_tail_center: Vector2 = Vector2(extend_cell * GridBackground.GRID_SIZE) + Vector2(40, 40)
	_check(editor._stage.path_points.back().distance_to(expected_tail_center) <= 80.01,
		"末点应在新端点中心 ±80px 外延段，实测 %s" % str(editor._stage.path_points.back()))
	editor._apply_brush_at(extend_cell)
	_check(editor._path_cells.size() == 21, "点击新端点应退格回 21")
	_check((editor._data_label.text as String).contains("路格：21"), "退格后面板路格数应回 21")

	# 出入口端反转
	var entry_before: Vector2i = editor._overlay.entry_cell
	var base_before: Vector2i = editor._overlay.base_cell
	editor._on_reverse_pressed()
	_check(editor._overlay.entry_cell == base_before and editor._overlay.base_cell == entry_before,
		"反转后入口/基地应对调")
	editor._on_reverse_pressed()
	_check(editor._overlay.entry_cell == entry_before, "再次反转应复原")

	# 撤销语义：绿编辑 → 红编辑 → 撤销恢复绿态
	editor._brush = editor.Brush.DECOR
	editor._apply_brush_at(free_cell)
	_check(editor._stage.decor_cells.has(free_cell), "撤销语义前置：装饰已点涂")
	editor._brush = editor.Brush.FORBIDDEN
	editor._apply_brush_at(road_cell)
	_check(not editor._editor_errors().is_empty() or not (editor._data_label.text as String).contains("MapValidator 通过"),
		"禁建画上道路应进入不通过态（不记录绿色快照）")
	editor._on_undo_pressed()
	_check(editor._stage.decor_cells.has(free_cell), "撤销应恢复最近绿态（装饰保留）")
	editor._on_undo_pressed()
	_check(not editor._stage.decor_cells.has(free_cell), "再次撤销应回上一绿态（装饰移除）")
	_check((editor._data_label.text as String).contains("装饰格：12"), "撤销后面板装饰计数回 12")

	# 注：画布铺满与鼠标映射的实际行为已在真实渲染下截图核验（headless dummy
	# 显示服务不布局 Window 子控件，无法在此断言容器尺寸）。

	if failures.is_empty():
		print("MAP_EDITOR_TEST_OK")
		get_tree().quit(0)
	else:
		print("MAP_EDITOR_TEST_FAILED: %d" % failures.size())
		get_tree().quit(1)
