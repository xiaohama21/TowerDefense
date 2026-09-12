extends RefCounted
class_name CursorIcons
## Kenney Cursor Pack 光标目录与注册出口（UI_LAYOUT §15 光标规范，程序 0.8.12.0）。
##
## 素材 = docs/ui_concept/src/kenney_cursor_pack/PNG/Outline/{Default,Double} 经
## tools/prep_cursors.py 按定稿配色 B 重着色（芯 #cdeffb / 描边 #14538a）后写入
## assets/ui/cursors/（32px 基准 + _2x 64px 高 DPI 套）。
##
## 热点为逐枚实测值（脚本按几何规则标定极值实心像素簇质心并校验 alpha≥200，
## 与 UI_LAYOUT §15 热点表同源）；64px 套非 32px 等比放大，故两套热点独立标定。
##
## **禁止在业务代码里散点调用 Input.set_custom_mouse_cursor**：游戏内走
## CursorService autoload（启动注册 + 新控件 hover 手型），地图编辑器插件走本静态出口。

const DIR := "res://assets/ui/cursors/"

## 语义图标（UI_LAYOUT §15 映射表）
const ICON_DEFAULT := "pointer_toon_a"    # 全局默认指针（Q 版指针；备选 pointer_a）
const ICON_HOVER := "hand_point"          # 按钮 / 卡片 / 页签 / 可点项 hover
const ICON_DRAG := "hand_closed"          # 拖拽（建造卡拖出）
const ICON_CANVAS := "cross_large"        # 战场 / 画布
const ICON_BLOCKED := "cursor_disabled"   # 禁建

## 32px 基准热点（实测表，见 UI_LAYOUT §15）
const HOTSPOT_32 := {
	"pointer_toon_a": Vector2(3, 4),
	"pointer_a": Vector2(9, 8),
	"hand_point": Vector2(9, 4),
	"hand_closed": Vector2(16, 16),
	"cross_large": Vector2(16, 16),
	"drawing_pen": Vector2(5, 5),
	"drawing_brush": Vector2(24, 25),
	"drawing_eraser": Vector2(16, 16),
	"cursor_disabled": Vector2(2, 3),
}

## 64px（_2x）热点（实测表，见 UI_LAYOUT §15）
const HOTSPOT_64 := {
	"pointer_toon_a": Vector2(7, 7),
	"pointer_a": Vector2(17, 14),
	"hand_point": Vector2(19, 5),
	"hand_closed": Vector2(32, 32),
	"cross_large": Vector2(32, 32),
	"drawing_pen": Vector2(9, 10),
	"drawing_brush": Vector2(50, 51),
	"drawing_eraser": Vector2(32, 32),
	"cursor_disabled": Vector2(3, 4),
}

## 高 DPI 切换阈值（Windows 缩放 ≥150% 用 _2x 套，避免光标相对 UI 过小）
const HI_DPI_SCALE := 1.4

## 地图编辑器笔刷专用槽：随笔刷重注册图像（Godot 无「自定义光标槽」，借用闲置形状槽）。
## 注：Input / Control 各有一套同值 CursorShape 枚举——此处取 Control 版供控件属性用，
## 注册时按 int 传入 Input.set_custom_mouse_cursor（两枚举数值一致）。
const BRUSH_SHAPE := Control.CURSOR_HELP

## 编辑器笔刷语义 → 图标（建造位同为笔类铺设，与路径同款）
const BRUSH_ICONS := {
	"path": "drawing_pen",
	"decor": "drawing_brush",
	"slot": "drawing_pen",
	"erase": "drawing_eraser",
	"forbidden": "cursor_disabled",
}


## 游戏运行时注册（CursorService autoload 启动调用）：全局默认指针 / hover / 拖拽 / 画布 / 禁建。
static func register_game_cursors() -> void:
	_apply_cursor(Input.CURSOR_ARROW, ICON_DEFAULT)
	_apply_cursor(Input.CURSOR_POINTING_HAND, ICON_HOVER)
	_apply_cursor(Input.CURSOR_DRAG, ICON_DRAG)
	_apply_cursor(Input.CURSOR_CROSS, ICON_CANVAS)
	_apply_cursor(Input.CURSOR_FORBIDDEN, ICON_BLOCKED)


## 退出前释放自定义光标（否则纹理在渲染服务销毁后才回收，退出日志出现纹理泄漏告警）。
static func release_cursors() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_DRAG,
			Input.CURSOR_CROSS, Input.CURSOR_FORBIDDEN, BRUSH_SHAPE]:
		Input.set_custom_mouse_cursor(null, shape)


## 编辑器笔刷光标（地图编辑器插件调用；插件运行在 Godot 编辑器进程，无 autoload，
## 故只注册笔刷专用槽，不动编辑器自身的箭头 / 手型）。
static func register_brush(brush_key: String) -> void:
	_apply_cursor(BRUSH_SHAPE, BRUSH_ICONS.get(brush_key, ICON_CANVAS))


## 可点控件 hover 手型（UITheme 封装与 CursorService 统一出口共用）。
static func apply_hover(control: Control) -> void:
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func _apply_cursor(shape: int, icon: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var use_2x := DisplayServer.screen_get_scale() > HI_DPI_SCALE
	var path := "%s%s%s.png" % [DIR, icon, "_2x" if use_2x else ""]
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("CursorIcons: 缺少光标素材 %s" % path)
		return
	var hotspot: Vector2 = (HOTSPOT_64 if use_2x else HOTSPOT_32).get(icon, Vector2.ZERO)
	Input.set_custom_mouse_cursor(texture, shape, hotspot)