extends Button

var data: CityEntryData
var palette := "dusk"
var _art: TextureRect
var _action: Label
var _locked := false
var _new := false

func _ready() -> void:
	size = Vector2(200,199)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = data.display_name + "：" + data.description
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	_art = TextureRect.new()
	_art.texture = load("res://assets/city/%s/%s.svg" % [palette,data.entry_id])
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.size = Vector2(200,175)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_action = Label.new()
	_action.position = Vector2(18,168)
	_action.size = Vector2(164,28)
	_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action.add_theme_font_size_override("font_size",20)
	_action.add_theme_color_override("font_color",Color("#fff0c8"))
	_action.add_theme_color_override("font_shadow_color",Color("#122b26"))
	_action.add_theme_constant_override("shadow_offset_y",2)
	add_child(_action)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func refresh(profile: PlayerProfile) -> void:
	_locked = not CityRegistry.is_open(profile,data.entry_id)
	_new = CityRegistry.is_new(profile,data.entry_id)
	_art.modulate = Color(.64,.67,.66,.58) if _locked else Color.WHITE
	_action.text = ("查看条件" if data.implemented else "未开放") if _locked else data.action
	queue_redraw()

func _draw() -> void:
	if _locked or is_hovered() or has_focus():
		var color := Color("#d9c08b") if not _locked else Color("#799285")
		for i in range(24):
			var a := TAU*i/24
			draw_arc(Vector2(100,107),83,a,a+TAU/35,5,color,2,true)
	if _new:
		draw_circle(Vector2(171,58),6,Color("#ce7958"))
		draw_arc(Vector2(171,58),7,0,TAU,20,Color("#ffe5ac"),1.5,true)
