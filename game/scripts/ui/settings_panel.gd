extends Control
## Settings: frame rate, the stats overlay and sound. Changes save straight away.

signal closed

var _rows: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	UIStyle.label(column, "Settings", 28)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	column.add_child(_rows)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	UIStyle.button(footer, "Done", Vector2(140, 50)).pressed.connect(_close)
	_refresh()


func _refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_row("Frame rate", "%d FPS" % Settings.fps_cap, Settings.next_fps_cap)
	_row("Performance stats", "On" if Settings.show_stats else "Off", func() -> void: Settings.set_show_stats(not Settings.show_stats))
	_row("Camera", Settings.ZOOMS.get(Settings.zoom, "Normal"), Settings.next_zoom)
	_row("Sound", "On" if Settings.sound_on else "Off", func() -> void: Settings.set_sound_on(not Settings.sound_on))


func _row(label: String, value: String, action: Callable) -> void:
	var row := HBoxContainer.new()
	_rows.add_child(row)
	var l := UIStyle.label(row, label, 22)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.button(row, value, Vector2(160, 50)).pressed.connect(func() -> void:
		action.call()
		_refresh())


func _close() -> void:
	closed.emit()
	queue_free()
