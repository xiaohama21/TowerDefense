extends Node
## 全局光标服务（autoload）：启动注册 Kenney 光标素材 + 新控件 hover 手型统一出口。
##
## 目录与热点见 scripts/services/CursorIcons.gd（UI_LAYOUT §15 光标规范）；
## 业务代码只需设置 Control.mouse_default_cursor_shape 或走 UITheme 封装，
## 不直接调用 Input.set_custom_mouse_cursor。


func _ready() -> void:
	CursorIcons.register_game_cursors()
	get_tree().node_added.connect(_on_node_added)
	_polish(get_tree().root)


## 运行期新建的按钮 / 页签（弹窗、动态卡片等）也自动带 hover 手型。
func _on_node_added(node: Node) -> void:
	_polish(node)


func _polish(node: Node) -> void:
	if node is BaseButton or node is TabBar:
		CursorIcons.apply_hover(node as Control)


func _exit_tree() -> void:
	CursorIcons.release_cursors()
