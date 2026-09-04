extends EditorPlugin

## 地图编辑器插件入口（M1 骨架）：项目菜单 → 工具 → 地图编辑器。
## 编辑器专用：不参与游戏运行时逻辑。

const TOOL_MENU_NAME := "地图编辑器"
const WINDOW_SCRIPT := preload("res://addons/map_editor/map_editor_window.gd")

var _window: Window


func _enter_tree() -> void:
	add_tool_menu_item(TOOL_MENU_NAME, Callable(self, "_open_editor"))


func _exit_tree() -> void:
	remove_tool_menu_item(TOOL_MENU_NAME)
	if _window != null and is_instance_valid(_window):
		_window.queue_free()
	_window = null


func _open_editor() -> void:
	if _window == null or not is_instance_valid(_window):
		_window = WINDOW_SCRIPT.new()
		get_editor_interface().get_base_control().add_child(_window)
	_window.popup_centered_ratio(0.92)
