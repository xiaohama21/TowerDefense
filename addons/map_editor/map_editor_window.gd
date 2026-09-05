@tool
extends Window

## 地图编辑器主窗口（M1 骨架）：章节关卡选择 → 载入 StageData →
## 实例化 GridBackground 预览（与运行时一致）+ 编辑态覆盖层 + 数据面板。
## M2/M3 将在此骨架上加笔刷编辑与 .tres/底图导出。

const OVERLAY_SCRIPT := preload("res://addons/map_editor/map_editor_overlay.gd")
const STAGES_ROOT := "res://resources/stages"
const MAP_W := 1280
const MAP_H := 720

var _stage: StageData
var _stage_paths: Array[String] = []
var _grid: GridBackground
var _overlay
var _viewport: SubViewport

var _stage_option: OptionButton
var _theme_option: OptionButton
var _load_button: Button
var _data_label: Label
var _status_label: Label


func _ready() -> void:
	title = "地图编辑器（M1 · 布局预览）"
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	min_size = Vector2i(1180, 760)
	size = Vector2i(1340, 860)
	# B-029：Godot 4 Window 点右上角 X 只发 close_requested 不自动关闭。
	close_requested.connect(_on_close_requested)
	_build_ui()
	_scan_stages()
	if _stage_paths.is_empty():
		_set_status("未找到任何关卡资源（%s）" % STAGES_ROOT, true)
	else:
		_load_stage(_stage_paths[_stage_option.selected])


## 关闭窗口仅隐藏（实例与已载入状态保留，工具菜单重开时复用原实例）。
func _on_close_requested() -> void:
	hide()


func _build_ui() -> void:
	var font := load("res://assets/fonts/ZCOOL-Kuaile.ttf") as Font
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	if font != null:
		var theme := Theme.new()
		theme.default_font = font
		theme.default_font_size = 16
		margin.theme = theme
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)

	# 顶栏
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	root_box.add_child(top_bar)

	var title_label := Label.new()
	title_label.text = "地图编辑器"
	title_label.add_theme_font_size_override("font_size", 22)
	top_bar.add_child(title_label)
	top_bar.add_child(_spacer())

	var stage_caption := Label.new()
	stage_caption.text = "关卡"
	top_bar.add_child(stage_caption)

	_stage_option = OptionButton.new()
	_stage_option.custom_minimum_size = Vector2(260, 0)
	_stage_option.item_selected.connect(_on_stage_selected)
	top_bar.add_child(_stage_option)

	_load_button = Button.new()
	_load_button.text = "载入"
	_load_button.pressed.connect(_on_load_pressed)
	top_bar.add_child(_load_button)

	var theme_caption := Label.new()
	theme_caption.text = "主题预览"
	top_bar.add_child(theme_caption)

	_theme_option = OptionButton.new()
	for theme_name in ["grass", "fire", "night"]:
		_theme_option.add_item(theme_name)
	_theme_option.item_selected.connect(_on_theme_selected)
	top_bar.add_child(_theme_option)

	# 中部：画布 + 数据面板
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 8)
	root_box.add_child(middle)

	# B-030：画布恒按 1280×720 逻辑分辨率布局（size_2d_override + stretch），
	# 外层 AspectRatioContainer 16:9 等比缩放居中——窗口缩放不裁切、不变形，
	# 网格数量与运行时 16×9 恒一致。
	var canvas_fit := AspectRatioContainer.new()
	canvas_fit.ratio = float(MAP_W) / float(MAP_H)
	canvas_fit.stretch_mode = AspectRatioContainer.STRETCH_FIT
	canvas_fit.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	canvas_fit.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	canvas_fit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_fit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(canvas_fit)

	var canvas_container := SubViewportContainer.new()
	canvas_container.stretch = true
	canvas_fit.add_child(canvas_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(MAP_W, MAP_H)
	_viewport.size_2d_override = Vector2i(MAP_W, MAP_H)
	_viewport.size_2d_override_stretch = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas_container.add_child(_viewport)

	_grid = GridBackground.new()
	_viewport.add_child(_grid)
	_overlay = OVERLAY_SCRIPT.new()
	_viewport.add_child(_overlay)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	middle.add_child(side)

	var data_panel := PanelContainer.new()
	data_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.14, 0.92)
	sb.set_corner_radius_all(10)
	data_panel.add_theme_stylebox_override("panel", sb)
	side.add_child(data_panel)

	_data_label = Label.new()
	_data_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_data_label.add_theme_font_size_override("font_size", 15)
	_data_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	data_panel.add_child(_data_label)

	var hint_panel := PanelContainer.new()
	var hint_sb := StyleBoxFlat.new()
	hint_sb.bg_color = Color(0.16, 0.2, 0.26, 0.95)
	hint_sb.set_corner_radius_all(10)
	hint_panel.add_theme_stylebox_override("panel", hint_sb)
	side.add_child(hint_panel)

	var hint_label := Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.text = "M1：布局只读预览（复用 GridBackground，编辑器所见 = 游戏所得）。\nM2：笔刷编辑（路径/装饰/禁建/建造位）+ 实时校验。\nM3：导出 .tres / 底图 PNG。"
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_panel.add_child(hint_label)

	# 底部状态
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 15)
	root_box.add_child(_status_label)


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _scan_stages() -> void:
	_stage_paths.clear()
	_stage_option.clear()
	var root_dir := DirAccess.open(STAGES_ROOT)
	if root_dir == null:
		return
	var chapters: Array[String] = []
	root_dir.list_dir_begin()
	var entry := root_dir.get_next()
	while not entry.is_empty():
		if root_dir.current_is_dir() and not entry.begins_with("."):
			chapters.append(entry)
		entry = root_dir.get_next()
	root_dir.list_dir_end()
	chapters.sort()

	var all_paths: Array[String] = []
	var default_index := 0
	for chapter in chapters:
		var chapter_dir := DirAccess.open("%s/%s" % [STAGES_ROOT, chapter])
		if chapter_dir == null:
			continue
		var stage_names: Array[String] = []
		chapter_dir.list_dir_begin()
		var file := chapter_dir.get_next()
		while not file.is_empty():
			if not chapter_dir.current_is_dir() and file.ends_with(".tres"):
				stage_names.append(file)
			file = chapter_dir.get_next()
		chapter_dir.list_dir_end()
		stage_names.sort()
		for stage_name in stage_names:
			var path := "%s/%s/%s" % [STAGES_ROOT, chapter, stage_name]
			all_paths.append(path)
			if path.ends_with("ch01_s01.tres"):
				default_index = all_paths.size() - 1
	for path in all_paths:
		_stage_paths.append(path)
		_stage_option.add_item(path.trim_prefix("res://resources/stages/"))
	if not _stage_paths.is_empty():
		_stage_option.select(default_index)


func _on_stage_selected(index: int) -> void:
	if index >= 0 and index < _stage_paths.size():
		_load_stage(_stage_paths[index])


func _on_load_pressed() -> void:
	var index := _stage_option.get_selected_id()
	if index >= 0 and index < _stage_paths.size():
		_load_stage(_stage_paths[index])


func _on_theme_selected(index: int) -> void:
	if _stage == null or index < 0:
		return
	_render_stage(_theme_option.get_item_text(index))


func _load_stage(path: String) -> void:
	var stage := load(path) as StageData
	if stage == null:
		_set_status("载入失败：%s（非 StageData 资源）" % path, true)
		return
	_stage = stage
	var theme_index := 0
	for i in range(_theme_option.item_count):
		if _theme_option.get_item_text(i) == String(stage.theme):
			theme_index = i
			break
	_theme_option.select(theme_index)
	_render_stage(String(stage.theme))
	_set_status("已载入 %s" % path.trim_prefix("res://resources/stages/"), false)


func _render_stage(theme_name: String) -> void:
	if _stage == null or _grid == null:
		return
	var road_cells := GridBackground.derive_road_cells(_stage.path_points)
	var entry_cell := Vector2i(-1, -1)
	var base_cell := Vector2i(-1, -1)
	if not road_cells.is_empty():
		entry_cell = road_cells[0]
		base_cell = road_cells[road_cells.size() - 1]
	_grid.configure(road_cells, _stage.decor_cells, entry_cell, base_cell, StringName(theme_name), _stage.forbidden_cells)
	_overlay.stage = _stage
	_overlay.entry_cell = entry_cell
	_overlay.base_cell = base_cell
	_overlay.queue_redraw()
	_update_data_panel(road_cells, entry_cell, base_cell)


func _update_data_panel(road_cells: Array, entry_cell: Vector2i, base_cell: Vector2i) -> void:
	if _stage == null:
		return
	var lines: Array[String] = []
	lines.append("stage_id：%s" % _stage.stage_id)
	if not String(_stage.display_name).is_empty():
		lines.append("关卡：%s" % _stage.display_name)
	lines.append("主题：%s" % _stage.theme)
	lines.append("网格：%d×%d（%dpx/格 · %d×%d）" % [
		GridBackground.COLS, GridBackground.ROWS, GridBackground.GRID_SIZE,
		GridBackground.COLS * GridBackground.GRID_SIZE,
		GridBackground.ROWS * GridBackground.GRID_SIZE,
	])
	lines.append("")
	lines.append("路格：%d" % road_cells.size())
	lines.append("入口：(%d,%d)　基地：(%d,%d)" % [entry_cell.x, entry_cell.y, base_cell.x, base_cell.y])
	lines.append("装饰格：%d　禁建格：%d" % [_stage.decor_cells.size(), _stage.forbidden_cells.size()])
	lines.append("建造位：%d（软引导推荐位）" % _overlay._slot_positions().size())
	lines.append("")
	lines.append("校验：")
	var issues: Array[String] = []
	if MapValidator.validate_stage(_stage, issues):
		lines.append("✅ MapValidator 通过")
	else:
		for issue in issues:
			lines.append("⚠ " + issue)
	_data_label.text = "\n".join(lines)


func _set_status(text: String, is_error: bool) -> void:
	_status_label.text = ("[错误] " if is_error else "") + text
	if is_error:
		_status_label.add_theme_color_override("font_color", Color(1, 0.6, 0.55))
	else:
		_status_label.remove_theme_color_override("font_color")
