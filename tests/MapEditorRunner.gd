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

	# 注：画布铺满的实际布局已在真实渲染下人工/截图核验（headless dummy 显示
	# 服务不布局 Window 子控件，无法在此断言容器尺寸）。

	if failures.is_empty():
		print("MAP_EDITOR_TEST_OK")
		get_tree().quit(0)
	else:
		print("MAP_EDITOR_TEST_FAILED: %d" % failures.size())
		get_tree().quit(1)
