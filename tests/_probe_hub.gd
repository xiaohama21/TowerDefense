extends Node

var _hub
var _frames := 0

func _ready() -> void:
	_hub = (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(_hub)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 45:
		return
	var map_panel = _hub.get_node("HubPanel/Columns/Content/MapPanel")
	map_panel._show_panel(&"develop")
	var develop = _hub.get_node("HubPanel/Columns/Content/DevelopPanel")
	develop._open_promotion_overlay()
	var overlay = develop._promotion_overlay
	var panel = overlay.get_node("OverlayPanel")
	var box = panel.get_child(0)
	print("PROBE box_children=", box.get_children().size())
	for c in box.get_children():
		print("PROBE child=", c.get_class(), " name=", c.name, " size=", c.size, " pos=", c.position, " vis=", c.visible)
	var header = box.get_child(0)
	print("PROBE header_style=", header.get_theme_stylebox("panel") if header is Panel else "n/a")
	set_process(false)
	get_tree().quit(0)
