class_name PromoTreeRail
extends VBoxContainer
## 转职树左侧竖轨（概念图 .ptree border-left：#bfe2f4 3px 贯穿整树）。
## 行内容统一先空 26px 竖轨区（含状态点），卡片从轨道右侧排布。

const RAIL_WIDTH := 3.0
const LANE_WIDTH := 26.0


func _draw() -> void:
	if size.y < 2.0:
		return
	draw_rect(Rect2(0.0, 0.0, RAIL_WIDTH, size.y), Color("#bfe2f4"))
