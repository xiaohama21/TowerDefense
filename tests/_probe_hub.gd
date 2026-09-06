extends Node

var _hub
var _frames := 0
var _stage := 0

func _ready() -> void:
	_hub = (load("res://scenes/GameHub.tscn") as PackedScene).instantiate()
	add_child(_hub)

func _process(_delta: float) -> void:
	_frames += 1
	match _stage:
		0:
			if _frames >= 40:
				_hub._show_panel(&"develop")
				var develop = _hub.get_node("HubPanel/Columns/Content/DevelopPanel")
				develop._tab_container.current_tab = 1
				develop._open_promotion_overlay()
				_stage = 1
				_frames = 0
		1:
			if _frames >= 60:
				var img: Image = get_viewport().get_texture().get_image()
				print("PROBE save=", error_string(img.save_png(ProjectSettings.globalize_path("res://_probe_promo.png"))))
				get_tree().quit(0)
