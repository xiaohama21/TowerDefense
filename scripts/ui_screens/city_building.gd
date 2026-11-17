extends Button

var data: CityEntryData
var palette := "dusk"
var _art: TextureRect
var _action: Label
var _plate: Panel
var _locked := false
var _new := false

func _ready() -> void:
	size = Vector2(200,199)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = data.display_name + "：" + data.description
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	add_theme_stylebox_override("focus",focus_style)
	_art = TextureRect.new()
	_art.texture = load("res://assets/city/%s/%s.svg" % [palette,data.entry_id])
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.size = Vector2(200,175)
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_plate = Panel.new()
	_plate.position = Vector2(20,168)
	_plate.size = Vector2(160,27)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_action = Label.new()
	_action.position = Vector2(18,167)
	_action.size = Vector2(164,28)
	_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action.add_theme_font_size_override("font_size",18)
	_action.add_theme_color_override("font_color",Color("#f7e4b7"))
	_action.add_theme_color_override("font_shadow_color",Color("#122b26"))
	_action.add_theme_constant_override("shadow_offset_y",1)
	add_child(_action)
	for event in [mouse_entered,mouse_exited,focus_entered,focus_exited]:
		event.connect(_refresh_art)

func refresh(profile: PlayerProfile) -> void:
	_locked = not CityRegistry.is_open(profile,data.entry_id)
	_new = CityRegistry.is_new(profile,data.entry_id)
	_action.text = ("查看条件" if data.implemented else "未开放") if _locked else data.action
	_refresh_art()

func _refresh_art() -> void:
	var selected := is_hovered() or has_focus()
	_art.modulate = Color(.8,.84,.8,1) if _locked else (Color(1.08,1.05,1,1) if selected else Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#273d32ee") if _locked else Color("#283e31f5")
	style.border_color = Color("#eac682") if selected else (Color("#687560") if _locked else Color("#a78c58"))
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.04,0.09,0.06,.45)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0,2)
	_plate.add_theme_stylebox_override("panel",style)
	_action.add_theme_color_override("font_color",Color("#c4cbb0") if _locked else Color("#f7e4b7"))
	queue_redraw()

func _draw() -> void:
	if is_hovered() or has_focus():
		var points := PackedVector2Array()
		for i in range(49):
			var angle := TAU*i/48
			points.append(Vector2(100+91*cos(angle),151+15*sin(angle)))
		draw_colored_polygon(points,Color(.91,.74,.39,.1))
		draw_polyline(points,Color("#e5bb75"),1.5,true)
	if _new:
		draw_circle(Vector2(171,58),6,Color("#ce7958"))
		draw_arc(Vector2(171,58),7,0,TAU,20,Color("#ffe5ac"),1.5,true)
