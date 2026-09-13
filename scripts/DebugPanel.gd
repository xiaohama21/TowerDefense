extends PanelContainer

## 仅调试构建可见的测试辅助面板：加金币、跳转波次、清空敌人。
## 用于测试后期波次，不改变正式数值、存档与结算逻辑。

signal wave_jump_requested(wave_index: int)
signal clear_enemies_requested

const DEBUG_GOLD_AMOUNT: int = 500

var _wave_spin_box: SpinBox


func _ready() -> void:
	add_theme_stylebox_override("panel", _make_style())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	row.add_child(_make_label("调试"))
	row.add_child(_make_button("金币+%d" % DEBUG_GOLD_AMOUNT, _on_gold_pressed))

	row.add_child(_make_label("开始第"))
	_wave_spin_box = SpinBox.new()
	_wave_spin_box.min_value = 1
	_wave_spin_box.max_value = 99
	_wave_spin_box.value = 1
	_wave_spin_box.custom_minimum_size = Vector2(72, 0)
	row.add_child(_wave_spin_box)
	row.add_child(_make_button("波", _on_jump_pressed))

	row.add_child(_make_button("清空敌人", _on_clear_pressed))


func _make_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.55)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	return label


func _make_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(handler)
	return button


func _on_gold_pressed() -> void:
	GameManager.gold += DEBUG_GOLD_AMOUNT


func _on_jump_pressed() -> void:
	wave_jump_requested.emit(int(_wave_spin_box.value) - 1)


func _on_clear_pressed() -> void:
	clear_enemies_requested.emit()
