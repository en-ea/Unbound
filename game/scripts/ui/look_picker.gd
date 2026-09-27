extends Control
## Look picker: choose the hero's parts and colours, with the camera close up on the character.

signal closed

var _visual: CharacterVisual
var _camera_rig: Node3D
var _rows: VBoxContainer
var _rng := RandomNumberGenerator.new()


func open(visual: CharacterVisual, camera_rig: Node3D) -> void:
	_visual = visual
	_camera_rig = camera_rig
	if _visual.look != "hero":
		_visual.set_look("hero")
	Controls.locked = true
	_camera_rig.set_view(5.2, -16.0, Vector3(1.7, 0.15, 0.0))
	var turn := create_tween().set_trans(Tween.TRANS_SINE)
	turn.tween_method(func(a: float) -> void: _visual.rotation.y = a, _visual.rotation.y, 0.0, 0.5)
	_build()


func _build() -> void:
	# Under a CanvasLayer, anchors alone leave this at size 0, so set the offsets too.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -560.0
	panel.offset_right = -48.0
	panel.offset_top = 20.0
	panel.offset_bottom = -20.0
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	UIStyle.label(column, "Your look", 28)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_rows)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	UIStyle.button(footer, "Random").pressed.connect(_randomize)
	UIStyle.button(footer, "Done").pressed.connect(_close)
	_refresh()


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var look := _visual.hero_look
	for slot: String in CharacterLook.PARTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_rows.add_child(row)
		UIStyle.label(row, CharacterLook.PART_LABELS[slot]).custom_minimum_size.x = 150
		UIStyle.button(row, "<", Vector2(48, 42)).pressed.connect(_cycle.bind(slot, -1))
		var value := UIStyle.label(row, String(look.parts[slot]).capitalize())
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIStyle.button(row, ">", Vector2(48, 42)).pressed.connect(_cycle.bind(slot, 1))
	for slot: String in CharacterLook.PALETTES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_rows.add_child(row)
		UIStyle.label(row, CharacterLook.COLOR_LABELS[slot], 18, true).custom_minimum_size.x = 150
		var palette: Array = CharacterLook.PALETTES[slot]
		for i in palette.size():
			UIStyle.swatch(row, palette[i], look.colors[slot] == i).pressed.connect(_pick_color.bind(slot, i))


func _cycle(slot: String, step: int) -> void:
	_visual.hero_look.cycle_part(slot, step)
	_changed()


func _pick_color(slot: String, index: int) -> void:
	_visual.hero_look.set_color(slot, index)
	_changed()


func _randomize() -> void:
	_rng.randomize()
	_visual.hero_look.randomize_look(_rng)
	_changed()


func _changed() -> void:
	_visual.apply_hero_look()
	_refresh()


func _close() -> void:
	_visual.hero_look.save()
	Controls.locked = false
	_camera_rig.reset_view()
	closed.emit()
	queue_free()
