@tool
extends Window

## 地图编辑器主窗口（M2 · 布局编辑）：M1 骨架（载入/预览/数据面板）之上叠加
## 笔刷编辑——路径链延伸/退格（自动生成 path_points）、装饰/禁建/建造位点涂与
## 擦除、出入口端反转、主题切换写档、实时校验（MapValidator + 编辑器级检查），
## 撤销回退到上次校验通过态。M3 将在此骨架上加 .tres / 底图 PNG 导出。

const OVERLAY_SCRIPT := preload("res://addons/map_editor/map_editor_overlay.gd")
const SWATCH_SCRIPT := preload("res://addons/map_editor/terrain_swatch.gd")
const STAGES_ROOT := "res://resources/stages"
const MAP_W := 1280
const MAP_H := 720
const GREEN_HISTORY_MAX := 100

enum Brush { PATH, DECOR, FORBIDDEN, SLOT, ERASE }

## 装饰类型键（与 GridBackground.DECOR_TYPES 一致）。
const DECOR_TYPE_KEYS: Array[StringName] = [&"tree", &"rock", &"banner", &"torch"]

## 笔刷页签对应的地形样块定义（v0.8 地形栏：样块带图片/同源预览）。
const BRUSH_TERRAINS := {
	Brush.PATH: [{"id": &"road", "name": "道路"}],
	Brush.DECOR: [
		{"id": &"tree", "name": "树"}, {"id": &"rock", "name": "石"},
		{"id": &"banner", "name": "旗"}, {"id": &"torch", "name": "火把"},
	],
	Brush.FORBIDDEN: [{"id": &"mountain", "name": "禁建山"}],
	Brush.SLOT: [{"id": &"slot", "name": "建造位"}],
	Brush.ERASE: [{"id": &"erase", "name": "擦除"}],
}

var _stage: StageData
var _stage_paths: Array[String] = []
## 当前编辑资源对应的 .tres 路径（新建关卡在建档对话框时预设）。
var _stage_path := ""
## 脏标记：上次保存/载入/新建后有布局改动（新建/载入前据此弹确认）。
var _dirty := false
var _grid: GridBackground
var _overlay
var _viewport: SubViewport
var _canvas_container: SubViewportContainer

## 主路径格链（编辑态事实源）：[0] = 入口端，末位 = 基地端；据此生成 path_points。
var _path_cells: Array[Vector2i] = []
## 校验通过态快照栈（撤销目标）；编辑后通过才入栈。
var _green_history: Array[Dictionary] = []
var _brush: int = Brush.PATH
## 装饰刷当前选中的地形类型（地形栏样块点选，v0.8 替代文字下拉）。
var _selected_decor_type: StringName = &"tree"
var _hover_cell := Vector2i(-1, -1)

var _stage_option: OptionButton
var _theme_option: OptionButton
var _load_button: Button
var _undo_button: Button
var _force_save: CheckButton
var _palette_swatches: HBoxContainer
var _data_label: Label
var _status_label: Label


func _ready() -> void:
	title = "地图编辑器（v1 · 布局编辑与导出）"
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	# 默认尺寸 = 1280×720 画布（1:1 零留白）+ 右侧 300px 数据面板 + 顶栏/状态条；
	# 编辑器内 popup_centered_ratio 会按主窗口 92% 重设，画布 16:9 等比缩放跟随。
	min_size = Vector2i(1024, 640)
	size = Vector2i(1604, 822)
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
	# B-031：Window 不会自动拉伸直接 Control 子节点，必须显式全矩形锚点，
	# 否则根容器按最小尺寸挤在左上角、画布只占窗口一角。
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	var new_button := Button.new()
	new_button.text = "新建"
	new_button.pressed.connect(_on_new_pressed)
	top_bar.add_child(new_button)

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

	var save_button := Button.new()
	save_button.text = "保存"
	save_button.pressed.connect(_on_save_pressed)
	top_bar.add_child(save_button)

	var export_png_button := Button.new()
	export_png_button.text = "导出底图"
	export_png_button.pressed.connect(_on_export_png_pressed)
	top_bar.add_child(export_png_button)

	_undo_button = Button.new()
	_undo_button.text = "撤销"
	_undo_button.pressed.connect(_on_undo_pressed)
	top_bar.add_child(_undo_button)

	var theme_caption := Label.new()
	theme_caption.text = "主题"
	top_bar.add_child(theme_caption)

	_theme_option = OptionButton.new()
	for theme_name in ["grass", "fire", "night"]:
		_theme_option.add_item(theme_name)
	_theme_option.item_selected.connect(_on_theme_selected)
	top_bar.add_child(_theme_option)

	_force_save = CheckButton.new()
	_force_save.text = "强制保存"
	_force_save.tooltip_text = "校验有错误（✖）时默认阻止保存；确认无误可勾选强制"
	top_bar.add_child(_force_save)

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

	_canvas_container = SubViewportContainer.new()
	_canvas_container.stretch = true
	_canvas_container.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_canvas_container.gui_input.connect(_on_canvas_gui_input)
	_canvas_container.mouse_exited.connect(_on_canvas_mouse_exited)
	canvas_fit.add_child(_canvas_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(MAP_W, MAP_H)
	_viewport.size_2d_override = Vector2i(MAP_W, MAP_H)
	_viewport.size_2d_override_stretch = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_canvas_container.add_child(_viewport)

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
	hint_label.text = "笔刷：路径（端点 4 邻延伸 / 端点退格）· 装饰（选类型）/ 禁建 / 建造位点涂再点擦除 · 擦除清空格。\n新建=空白画布；保存=覆盖 .tres（校验 ✖ 默认阻止，可强制）；导出底图=纯 GridBackground PNG。\n撤销仅回退到上次校验通过态；未保存改动在新建/载入前会弹确认。"
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_panel.add_child(hint_label)

	# 笔刷条（页签）
	var brush_bar := HBoxContainer.new()
	brush_bar.add_theme_constant_override("separation", 6)
	root_box.add_child(brush_bar)

	var brush_caption := Label.new()
	brush_caption.text = "笔刷"
	brush_caption.add_theme_font_size_override("font_size", 15)
	brush_bar.add_child(brush_caption)

	var brush_group := ButtonGroup.new()
	var brush_defs := [
		["路径", Brush.PATH], ["装饰", Brush.DECOR], ["禁建", Brush.FORBIDDEN],
		["建造位", Brush.SLOT], ["擦除", Brush.ERASE],
	]
	for def in brush_defs:
		var brush_button := Button.new()
		brush_button.text = def[0]
		brush_button.toggle_mode = true
		brush_button.button_group = brush_group
		brush_button.pressed.connect(_on_brush_pressed.bind(def[1]))
		brush_bar.add_child(brush_button)
		if def[1] == Brush.PATH:
			brush_button.button_pressed = true
	brush_bar.add_child(_spacer())

	var reverse_button := Button.new()
	reverse_button.text = "出入口端反转"
	reverse_button.pressed.connect(_on_reverse_pressed)
	brush_bar.add_child(reverse_button)

	# 地形栏（v0.8）：随笔刷页签切换的图形样块（素材图/同源预览，选中金框）
	var palette_bar := HBoxContainer.new()
	palette_bar.add_theme_constant_override("separation", 6)
	root_box.add_child(palette_bar)

	var terrain_caption := Label.new()
	terrain_caption.text = "地形"
	terrain_caption.add_theme_font_size_override("font_size", 15)
	palette_bar.add_child(terrain_caption)

	_palette_swatches = HBoxContainer.new()
	_palette_swatches.add_theme_constant_override("separation", 6)
	palette_bar.add_child(_palette_swatches)
	palette_bar.add_child(_spacer())
	_rebuild_terrain_palette()

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
		_confirm_discard_then(_load_stage.bind(_stage_paths[index]))


func _on_load_pressed() -> void:
	var index := _stage_option.get_selected_id()
	if index >= 0 and index < _stage_paths.size():
		_confirm_discard_then(_load_stage.bind(_stage_paths[index]))


## 有未保存改动时先弹确认，确认后才执行 action（防误丢改动）。
func _confirm_discard_then(action: Callable) -> void:
	if not _dirty:
		action.call()
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "当前关卡有未保存的改动，继续将丢弃这些改动，确定？"
	dialog.ok_button_text = "丢弃并继续"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(func() -> void:
		action.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


## 新建画布：弹窗输入文件名与显示名，创建空白 StageData 进入编辑。
func _on_new_pressed() -> void:
	_confirm_discard_then(_open_new_stage_dialog)


func _open_new_stage_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "新建关卡"
	dialog.ok_button_text = "创建"
	dialog.cancel_button_text = "取消"
	var box := VBoxContainer.new()
	var chapter_hint := Label.new()
	chapter_hint.text = "章节固定 chapter_01，文件名形如 ch01_s09（不含 .tres）"
	box.add_child(chapter_hint)
	var name_field := LineEdit.new()
	name_field.placeholder_text = "ch01_s09"
	name_field.custom_minimum_size = Vector2(320, 0)
	box.add_child(name_field)
	var display_field := LineEdit.new()
	display_field.placeholder_text = "显示名（选填，默认同文件名）"
	display_field.custom_minimum_size = Vector2(320, 0)
	box.add_child(display_field)
	dialog.add_child(box)
	dialog.confirmed.connect(func() -> void:
		_create_new_stage(name_field.text, display_field.text)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


## 创建空白关卡（布局全空、规则字段取默认值）：编辑布局后用「保存」落盘，
## 波次/剧情/经济骨架与 STAGES.md 登记仍按现有规范补齐（保存提示输出 checklist）。
func _create_new_stage(file_name: String, display_name: String) -> void:
	var clean := file_name.strip_edges()
	if clean.is_empty() or clean.contains(" ") or clean.contains("..") or clean.ends_with(".tres"):
		_set_status("新建失败：文件名不合法（形如 ch01_s09，不含 .tres）", true)
		return
	if not clean.contains("/"):
		clean = "chapter_01/" + clean
	var path := "%s/%s.tres" % [STAGES_ROOT, clean]
	if FileAccess.file_exists(path):
		_set_status("新建失败：%s 已存在，请直接载入修改" % path.trim_prefix("res://"), true)
		return
	var stage := StageData.new()
	var file_part := clean.get_file()
	stage.stage_id = StringName(file_part)
	stage.chapter_id = StringName(clean.get_base_dir().get_file())
	stage.display_name = display_name.strip_edges() if not display_name.strip_edges().is_empty() else file_part
	stage.theme = &"grass"
	_stage = stage
	_stage_path = path
	_path_cells.clear()
	_green_history.clear()
	_hover_cell = Vector2i(-1, -1)
	_dirty = false
	_theme_option.select(0)
	_refresh_from_stage()
	_set_status("已新建空白关卡 %s：先用路径刷画主路径，再摆装饰/禁建/建造位；校验通过后「保存」落盘" % file_part, false)


func _on_theme_selected(index: int) -> void:
	if _stage == null or index < 0:
		return
	_stage.theme = StringName(_theme_option.get_item_text(index))
	_after_edit()


func _load_stage(path: String) -> void:
	var stage := load(path) as StageData
	if stage == null:
		_set_status("载入失败：%s（非 StageData 资源）" % path, true)
		return
	_stage = stage
	_stage_path = path
	_path_cells = GridBackground.derive_road_cells(_stage.path_points)
	_hover_cell = Vector2i(-1, -1)
	_green_history.clear()
	_dirty = false
	var theme_index := 0
	for i in range(_theme_option.item_count):
		if _theme_option.get_item_text(i) == String(_stage.theme):
			theme_index = i
			break
	_theme_option.select(theme_index)
	_refresh_from_stage()
	_record_green_snapshot()
	_set_status("已载入 %s" % path.trim_prefix("res://resources/stages/"), false)


# ============ M3 保存与导出 ============

## 保存结果码：0 = 成功，1 = 被校验阻止，2 = 写盘失败。
func _on_save_pressed() -> void:
	if _stage == null:
		return
	if _stage_path.is_empty():
		_set_status("无保存目标：新建关卡需在「新建」对话框指定文件名", true)
		return
	_save_stage(_stage_path)


func _save_stage(path: String) -> int:
	if _stage == null or path.is_empty():
		return 2
	var validator_issues: Array[String] = []
	var validator_ok := MapValidator.validate_stage(_stage, validator_issues)
	var editor_errors := _editor_errors()
	var issue_count := validator_issues.size() + editor_errors.size()
	var is_new_file := not FileAccess.file_exists(path)
	if not validator_ok or not editor_errors.is_empty():
		if not _force_save.button_pressed:
			_set_status("保存被阻止：校验存在 %d 项问题（见数据面板），确认无误可勾选「强制保存」" % issue_count, true)
			return 1
	var err := ResourceSaver.save(_stage, path)
	if err != OK:
		_set_status("保存失败（错误码 %d）：%s" % [err, path], true)
		return 2
	_dirty = false
	var status_text := "已保存 %s" % path.trim_prefix("res://")
	if is_new_file:
		status_text += "\n新增关卡 checklist：补齐波次/剧情/经济等骨架字段，并在 STAGES.md 第一章规划登记（编辑器不自动改文档）"
	_set_status(status_text, false)
	return 0


## 导出底图 PNG（剔除编辑态覆盖层，纯 GridBackground 渲染）；
## 默认存 assets/map/themes/<theme>/layout_<stage_id>.png，path 非空时用指定路径。
func _on_export_png_pressed() -> void:
	if _stage == null:
		return
	_export_base_map("")


func _export_base_map(path: String) -> int:
	if _stage == null or _viewport == null:
		return 2
	if path.is_empty():
		var dir := "res://assets/map/themes/%s" % String(_stage.theme)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		path = "%s/layout_%s.png" % [dir, _stage.stage_id]
	_overlay.visible = false
	await RenderingServer.frame_post_draw
	var img: Image = _viewport.get_texture().get_image()
	_overlay.visible = true
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		_set_status("底图导出失败（错误码 %d）" % err, true)
		return err
	_set_status("已导出底图 %s（纯底图，供美术手绘重绘打底）" % path.trim_prefix("res://"), false)
	return OK


# ============ M2 笔刷编辑 ============

func _on_brush_pressed(brush: int) -> void:
	_brush = brush
	_rebuild_terrain_palette()
	_refresh_from_stage()
	_set_status(_brush_hint(brush), false)


## 重建地形栏样块（v0.8）：按当前笔刷页签显示对应地形，装饰保留已选类型，
## 单形态笔刷默认选中唯一样块。
func _rebuild_terrain_palette() -> void:
	if _palette_swatches == null:
		return
	for child in _palette_swatches.get_children():
		_palette_swatches.remove_child(child)
		child.queue_free()
	var swatch_group := ButtonGroup.new()
	var default_id := _selected_decor_type if _brush == Brush.DECOR else &""
	for def: Dictionary in BRUSH_TERRAINS.get(_brush, []):
		var swatch := SWATCH_SCRIPT.new()
		swatch.terrain_id = def["id"]
		swatch.display_name = def["name"]
		swatch.button_group = swatch_group
		swatch.pressed.connect(_on_terrain_selected.bind(def["id"]))
		_palette_swatches.add_child(swatch)
		if def["id"] == default_id or (default_id == &"" and swatch.get_index() == 0):
			swatch.button_pressed = true


func _on_terrain_selected(terrain_id: StringName) -> void:
	if _brush == Brush.DECOR and DECOR_TYPE_KEYS.has(terrain_id):
		_selected_decor_type = terrain_id


func _brush_hint(brush: int) -> String:
	match brush:
		Brush.PATH:
			return "路径刷：点击端点 4 邻空格延伸链；点击端点格退格（至少保留 2 格）。链首=入口、链尾=基地。"
		Brush.DECOR:
			return "装饰刷：在地形栏点选 树/石/旗/火把 样块（图片预览）后点涂，再点同格擦除。"
		Brush.FORBIDDEN:
			return "禁建刷：点击空格点涂禁建山，再点同格擦除（与道路重叠会被校验拦截）。"
		Brush.SLOT:
			return "建造位刷：点击空格点涂软引导推荐位，再点同格擦除（与道路/禁建重叠记错误）。"
		Brush.ERASE:
			return "擦除：点击格清除该格装饰（含类型）/ 禁建 / 建造位（道路用路径刷退格）。"
	return ""


func _on_reverse_pressed() -> void:
	if _stage == null or _path_cells.size() < 2:
		return
	_path_cells.reverse()
	_regenerate_path_points()
	_after_edit()
	_set_status("出入口端已反转：入口 %s → 基地 %s" % [_path_cells[0], _path_cells[_path_cells.size() - 1]], false)


func _on_undo_pressed() -> void:
	if _green_history.is_empty():
		_set_status("没有可撤销的编辑（撤销仅回退到上次校验通过态）", false)
		return
	_restore_snapshot(_green_history.pop_back())
	_set_status("已撤销到上次校验通过态", false)


## 画布点击 → 网格坐标（容器局部坐标 × 逻辑分辨率/容器尺寸 的逆映射）。
func _on_canvas_gui_input(event: InputEvent) -> void:
	if _stage == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_from_local(event.position)
		if cell.x >= 0:
			_apply_brush_at(cell)
	elif event is InputEventMouseMotion:
		var cell := _cell_from_local(event.position)
		if cell != _hover_cell:
			_hover_cell = cell
			_overlay.hover_cell = cell
			_overlay.queue_redraw()


func _on_canvas_mouse_exited() -> void:
	_hover_cell = Vector2i(-1, -1)
	_overlay.hover_cell = _hover_cell
	_overlay.queue_redraw()


## 容器局部坐标 → 画布逻辑坐标 → 网格；出界返回 (-1,-1)。
func _cell_from_local(local: Vector2) -> Vector2i:
	var container_size := _canvas_container.size
	if container_size.x <= 0.0 or container_size.y <= 0.0:
		return Vector2i(-1, -1)
	var content := local * (Vector2(MAP_W, MAP_H) / container_size)
	var cell := Vector2i(
		floori(content.x / GridBackground.GRID_SIZE),
		floori(content.y / GridBackground.GRID_SIZE)
	)
	if cell.x < 0 or cell.x >= GridBackground.COLS or cell.y < 0 or cell.y >= GridBackground.ROWS:
		return Vector2i(-1, -1)
	return cell


func _apply_brush_at(cell: Vector2i) -> void:
	if _stage == null:
		return
	match _brush:
		Brush.PATH:
			_path_edit_at(cell)
		Brush.DECOR:
			_toggle_decor_at(cell)
		Brush.FORBIDDEN:
			_toggle_in_cell_array(_stage.forbidden_cells, cell)
		Brush.SLOT:
			_toggle_slot_at(cell)
		Brush.ERASE:
			_erase_cell(cell)
	_after_edit()


## 装饰刷（v0.7 按类型 / v0.8 地形栏选型）：点涂写入 decor_cells + decor_types
## （地形栏选中的类型），再点同格擦除并同步清理类型映射。
func _toggle_decor_at(cell: Vector2i) -> void:
	if _stage.decor_cells.has(cell):
		_stage.decor_cells.erase(cell)
		_stage.decor_types.erase(cell)
	else:
		_stage.decor_cells.append(cell)
		_stage.decor_types[cell] = _selected_decor_type


## 路径刷：空链时点击任意格落首格；点击链端点的 4 邻空格 → 延伸；点击端点格 → 退格（链至少保留 2 格）。
func _path_edit_at(cell: Vector2i) -> void:
	if _path_cells.is_empty():
		_path_cells.append(cell)
		_regenerate_path_points()
		return
	if _path_cells.has(cell):
		if _path_cells.size() <= 2:
			_set_status("路径链至少保留 2 格（入口 + 基地）", true)
			return
		if cell == _path_cells[0]:
			_path_cells.pop_front()
		elif cell == _path_cells[_path_cells.size() - 1]:
			_path_cells.pop_back()
		else:
			_set_status("路径刷只能退格端点（链首/链尾），中间格不可删除", true)
			return
	else:
		var head := _path_cells[0]
		var tail := _path_cells[_path_cells.size() - 1]
		if _is_adjacent(cell, tail):
			_path_cells.append(cell)
		elif _is_adjacent(cell, head):
			_path_cells.push_front(cell)
		else:
			_set_status("路径刷只能从链端点（%s / %s）的 4 邻空格延伸" % [head, tail], true)
			return
	_regenerate_path_points()


func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _toggle_in_cell_array(cells: Array[Vector2i], cell: Vector2i) -> void:
	var index := cells.find(cell)
	if index >= 0:
		cells.remove_at(index)
	else:
		cells.append(cell)


func _toggle_slot_at(cell: Vector2i) -> void:
	var center := Vector2(cell * GridBackground.GRID_SIZE) + Vector2(GridBackground.GRID_SIZE, GridBackground.GRID_SIZE) * 0.5
	var index := _stage.build_slot_positions.find(center)
	if index >= 0:
		_stage.build_slot_positions.remove_at(index)
	else:
		_stage.build_slot_positions.append(center)


func _erase_cell(cell: Vector2i) -> void:
	_stage.decor_cells.erase(cell)
	_stage.decor_types.erase(cell)
	_stage.forbidden_cells.erase(cell)
	var center := Vector2(cell * GridBackground.GRID_SIZE) + Vector2(GridBackground.GRID_SIZE, GridBackground.GRID_SIZE) * 0.5
	var slots: Array[Vector2] = []
	for pos in _stage.build_slot_positions:
		if Vector2i(floori(pos.x / GridBackground.GRID_SIZE), floori(pos.y / GridBackground.GRID_SIZE)) != cell:
			slots.append(pos)
	_stage.build_slot_positions = slots


## 由格链生成 path_points：端点 + 转折格中心，首/末沿行进方向外延 80px 至图外。
func _regenerate_path_points() -> void:
	var pts: Array[Vector2] = []
	var n := _path_cells.size()
	if n == 0:
		_stage.path_points = pts
		return
	for i in range(n):
		if i == 0 or i == n - 1:
			pts.append(_cell_center(_path_cells[i]))
		else:
			var dir_in: Vector2i = _path_cells[i] - _path_cells[i - 1]
			var dir_out: Vector2i = _path_cells[i + 1] - _path_cells[i]
			if dir_in != dir_out:
				pts.append(_cell_center(_path_cells[i]))
	if n >= 2:
		var head_dir := Vector2(_path_cells[0] - _path_cells[1])
		var tail_dir := Vector2(_path_cells[n - 1] - _path_cells[n - 2])
		pts.insert(0, _cell_center(_path_cells[0]) + head_dir * GridBackground.GRID_SIZE)
		pts.append(_cell_center(_path_cells[n - 1]) + tail_dir * GridBackground.GRID_SIZE)
	_stage.path_points = pts


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * GridBackground.GRID_SIZE) + Vector2(GridBackground.GRID_SIZE, GridBackground.GRID_SIZE) * 0.5


## 每次编辑后：刷新预览与面板（含实时校验）；校验全绿则记录快照供撤销。
func _after_edit() -> void:
	_dirty = true
	_refresh_from_stage()
	var validator_issues: Array[String] = []
	if MapValidator.validate_stage(_stage, validator_issues) and _editor_errors().is_empty():
		_record_green_snapshot()


func _record_green_snapshot() -> void:
	var snap := _snapshot()
	if not _green_history.is_empty() and _green_history.back() == snap:
		return
	_green_history.append(snap)
	if _green_history.size() > GREEN_HISTORY_MAX:
		_green_history.pop_front()


func _snapshot() -> Dictionary:
	return {
		"path": _path_cells.duplicate(),
		"decor": _stage.decor_cells.duplicate(),
		"decor_types": _stage.decor_types.duplicate(),
		"forbidden": _stage.forbidden_cells.duplicate(),
		"slots": _stage.build_slot_positions.duplicate(),
		"theme": String(_stage.theme),
	}


func _restore_snapshot(snap: Dictionary) -> void:
	var path_cells: Array[Vector2i] = []
	path_cells.assign(snap["path"])
	_path_cells = path_cells
	var decor: Array[Vector2i] = []
	decor.assign(snap["decor"])
	_stage.decor_cells = decor
	_stage.decor_types = snap["decor_types"].duplicate()
	var forbidden: Array[Vector2i] = []
	forbidden.assign(snap["forbidden"])
	_stage.forbidden_cells = forbidden
	var slots: Array[Vector2] = []
	slots.assign(snap["slots"])
	_stage.build_slot_positions = slots
	_stage.theme = StringName(snap["theme"])
	for i in range(_theme_option.item_count):
		if _theme_option.get_item_text(i) == String(_stage.theme):
			_theme_option.select(i)
			break
	_refresh_from_stage()


# ============ 编辑器级检查（MAP_EDITOR §3.3） ============

## 错误（M3 导出默认阻断）：建造位与道路 / 禁建重叠。
func _editor_errors() -> Array[String]:
	var errors: Array[String] = []
	if _stage == null:
		return errors
	var road := {}
	for cell in _path_cells:
		road[cell] = true
	for pos in _stage.build_slot_positions:
		var cell := Vector2i(floori(pos.x / GridBackground.GRID_SIZE), floori(pos.y / GridBackground.GRID_SIZE))
		if road.has(cell):
			errors.append("建造位 (%d,%d) 与道路重叠" % [cell.x, cell.y])
		elif _stage.forbidden_cells.has(cell):
			errors.append("建造位 (%d,%d) 与禁建地形重叠" % [cell.x, cell.y])
	return errors


## 警告（不阻塞）：装饰与道路重叠（s01 现数据即含，兼容保留）；装饰/禁建与建造位重叠。
func _editor_warnings() -> Array[String]:
	var warnings: Array[String] = []
	if _stage == null:
		return warnings
	var road := {}
	for cell in _path_cells:
		road[cell] = true
	for cell in _stage.decor_cells:
		if road.has(cell):
			warnings.append("装饰格 (%d,%d) 与道路重叠（s01 兼容，不阻塞）" % [cell.x, cell.y])
	return warnings


# ============ 预览与数据面板 ============

func _refresh_from_stage() -> void:
	if _stage == null or _grid == null:
		return
	var road_cells: Array[Vector2i] = []
	road_cells.assign(_path_cells)
	var entry_cell := Vector2i(-1, -1)
	var base_cell := Vector2i(-1, -1)
	if not _path_cells.is_empty():
		entry_cell = _path_cells[0]
		base_cell = _path_cells[_path_cells.size() - 1]
	_grid.configure(road_cells, _stage.decor_cells, entry_cell, base_cell, String(_stage.theme), _stage.forbidden_cells, _stage.decor_types)
	_overlay.stage = _stage
	_overlay.entry_cell = entry_cell
	_overlay.base_cell = base_cell
	_overlay.hover_cell = _hover_cell
	_overlay.show_endpoints = _brush == Brush.PATH
	_overlay.queue_redraw()
	_update_data_panel(road_cells, entry_cell, base_cell)


func _update_data_panel(road_cells: Array[Vector2i], entry_cell: Vector2i, base_cell: Vector2i) -> void:
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
	lines.append("波次：%d · 剧情：%s" % [
		_stage.waves.size(),
		"有" if _stage.dialogue != null and not _stage.dialogue.lines.is_empty() else "无",
	])
	if not _stage.fork_path_points.is_empty():
		lines.append("分叉路径：%d 点（v2 只读）" % _stage.fork_path_points.size())
	lines.append("")
	lines.append("校验：")
	var issues: Array[String] = []
	if MapValidator.validate_stage(_stage, issues):
		lines.append("✅ MapValidator 通过")
	else:
		for issue in issues:
			lines.append("⚠ " + issue)
	var editor_errors := _editor_errors()
	for error in editor_errors:
		lines.append("✖ " + error)
	if editor_errors.is_empty():
		for warning in _editor_warnings():
			lines.append("⚠ " + warning)
	_data_label.text = "\n".join(lines)


func _set_status(text: String, is_error: bool) -> void:
	_status_label.text = ("[错误] " if is_error else "") + text
	if is_error:
		_status_label.add_theme_color_override("font_color", Color(1, 0.6, 0.55))
	else:
		_status_label.remove_theme_color_override("font_color")
