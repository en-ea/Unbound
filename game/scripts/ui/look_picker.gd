extends Control
## The character screen. Tabs for Face, Hair, Body, Outfit, Gear and Colours; each part is a row of
## choices you tap (the picked one glows gold). The camera moves in on the
## face for Face and Hair and pulls back to the whole body for the rest. Drag anywhere left of the
## panel to turn your character; a soft ring of light sits under them. Every change shows at once
## and is saved when you close.

signal closed

const TABS := ["face", "hair", "body", "outfit", "gear", "colours"]
const TAB_NAMES := {"face": "Face", "hair": "Hair", "body": "Body", "outfit": "Outfit", "gear": "Gear", "colours": "Colours"}
const SLOTS := {"face": ["marks", "eyes", "brows", "mouth", "cheeks", "extra"], "hair": ["hair", "beard"],
	"outfit": ["top", "waist", "feet"], "gear": ["head", "back", "shoulders", "chest"]}
const SWATCHES := {"hair": ["Hair"], "face": ["Marks"], "body": ["Skin"], "outfit": ["Main", "Second"], "gear": ["Accent", "Leather"],
	"colours": ["Main", "Second", "Cloth", "Accent", "Leather"]}
const CHIP_GOLD := Color(0.95, 0.76, 0.38)
const CLOSE_VIEW := [2.4, -6.0, Vector3(0.6, 0.6, 0.0)]      # distance, pitch, offset
const FULL_VIEW := [5.2, -14.0, Vector3(1.7, 0.2, 0.0)]
const PANEL_W := 540.0
const GLOW := preload("res://shaders/loot_glow.gdshader")

var _visual: CharacterVisual
var _camera_rig: Node3D
var _rows: VBoxContainer
var _tab := "face"
var _tab_buttons := {}
var _rng := RandomNumberGenerator.new()
var _ring: MeshInstance3D
var _flash_slot := ""
var _pitch := 0.0            # extra camera tilt from dragging up/down
var _zoomed := true          # the Zoom button toggles close-up / whole body on any tab


func open(visual: CharacterVisual, camera_rig: Node3D) -> void:
	_visual = visual
	_camera_rig = camera_rig
	Controls.locked = true
	_visual.wear_gear = false        # show the outfit being edited, not the armour over it
	_visual.apply_hero_look()
	var turn := create_tween().set_trans(Tween.TRANS_SINE)
	turn.tween_method(func(a: float) -> void: _visual.rotation.y = a, _visual.rotation.y, 0.0, 0.5)
	_add_ring()
	_build()
	_frame_camera()


func _build() -> void:
	# Under a CanvasLayer, anchors alone leave this at size 0, so set the offsets too.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_W - 40.0
	panel.offset_right = -40.0
	panel.offset_top = 12.0
	panel.offset_bottom = -12.0
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	column.add_child(titles)
	UIStyle.label(titles, "Your look", 28)
	UIStyle.label(titles, "Drag on the left to turn and tilt", 15, true)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	for tab: String in TABS:
		var b := UIStyle.button(tabs, TAB_NAMES[tab], Vector2(78, 44), 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_show_tab.bind(tab))
		_tab_buttons[tab] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_rows)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	UIStyle.button(footer, "Zoom", Vector2(120, 50)).pressed.connect(func() -> void:
		_zoomed = not _zoomed
		_frame_camera())
	UIStyle.button(footer, "Shuffle", Vector2(140, 50)).pressed.connect(_randomize)
	UIStyle.button(footer, "Done", Vector2(140, 50)).pressed.connect(_close)
	_refresh()


func _show_tab(tab: String) -> void:
	_tab = tab
	_zoomed = tab in ["face", "hair"]
	_flash_slot = ""
	_refresh()
	_frame_camera()


## Close on the face for Face and Hair; the whole body otherwise.
func _frame_camera() -> void:
	var v: Array = CLOSE_VIEW if _zoomed else FULL_VIEW
	var offset: Vector3 = v[2]
	offset.y *= _visual.hero_look.height
	_camera_rig.set_view(v[0], v[1] + _pitch, offset, 0.7)


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	for tab: String in _tab_buttons:
		_tab_buttons[tab].modulate = Color(1.0, 0.9, 0.66) if tab == _tab else Color(1, 1, 1, 0.55)
	var look := _visual.hero_look
	if _tab == "outfit":
		_chips("Ready-made outfits", CharacterLook.OUTFITS.keys(), look.outfit, func(o: String) -> void:
			look.set_outfit(o)
			_flash_slot = "outfit"
			_changed(), "outfit")
		_hint("Pick one, then change any part here or in Gear.")
	if _tab == "body":
		_slider_row("Height", look.height, CharacterLook.HEIGHT_RANGE, func(v: float) -> void:
			look.height = v
			_visual.apply_hero_look())
		_slider_row("Build", look.build, CharacterLook.BUILD_RANGE, func(v: float) -> void:
			look.build = v
			_visual.apply_hero_look())
	for slot: String in SLOTS.get(_tab, []):
		_chips(CharacterLook.PART_LABELS[slot], CharacterLook.PARTS[slot], look.parts[slot], func(c: String) -> void:
			look.set_part(slot, c)
			_flash_slot = slot
			_changed(), slot)
	for slot: String in SWATCHES.get(_tab, []):
		_swatch_row(slot)


func _hint(text: String) -> void:
	var l := UIStyle.label(_rows, text, 15, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## A heading and a flow of choices to tap; the picked one is gold (and pops when it just changed).
func _chips(title: String, choices: Array, current: String, on_pick: Callable, slot: String) -> void:
	var head := UIStyle.label(_rows, title, 18, true)
	head.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 0.85))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	_rows.add_child(flow)
	for choice: String in choices:
		var label := choice if slot == "outfit" else CharacterLook.choice_name(choice)
		var b := UIStyle.button(flow, label, Vector2(0, 44), 17)
		b.custom_minimum_size.x = maxf(86.0, b.get_theme_font("font").get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 30.0)
		if choice == current:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(CHIP_GOLD, 0.92)
			box.set_corner_radius_all(16)
			box.border_color = Color(1, 0.95, 0.8)
			box.set_border_width_all(2)
			for state in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(state, box)
			for c in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.add_theme_color_override(c, Color(0.16, 0.11, 0.06))
			if slot == _flash_slot:
				b.pivot_offset = b.custom_minimum_size / 2.0
				b.scale = Vector2.ONE * 1.12
				b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		b.pressed.connect(on_pick.bind(choice))
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	_rows.add_child(gap)


func _slider_row(label: String, value: float, range_v: Vector2, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_rows.add_child(row)
	var name_label := UIStyle.label(row, label, 19, true)
	name_label.custom_minimum_size = Vector2(118, 52)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var slider := HSlider.new()
	slider.min_value = range_v.x
	slider.max_value = range_v.y
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 40
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1.0, 0.85, 0.5)
	grab.set_corner_radius_all(4)
	slider.add_theme_stylebox_override("grabber_area", grab)
	slider.add_theme_stylebox_override("grabber_area_highlight", grab)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.15)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	row.add_child(slider)
	var pct := UIStyle.label(row, "%d%%" % roundi(value * 100), 18)
	pct.custom_minimum_size.x = 64
	slider.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % roundi(v * 100)
		on_change.call(v))


func _swatch_row(slot: String) -> void:
	var look := _visual.hero_look
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_rows.add_child(row)
	var name_label := UIStyle.label(row, CharacterLook.COLOR_LABELS[slot], 17, true)
	name_label.custom_minimum_size = Vector2(118, 50)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(flow)
	var palette: Array = CharacterLook.PALETTES[slot]
	for i in palette.size():
		UIStyle.swatch(flow, palette[i], look.colors.get(slot, 0) == i, 38.0).pressed.connect(_pick_color.bind(slot, i))


func _pick_color(slot: String, index: int) -> void:
	_visual.hero_look.set_color(slot, index)
	_flash_slot = ""
	_changed()


## A new random look, with a quick spin.
func _randomize() -> void:
	_rng.randomize()
	var spin := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var from := _visual.rotation.y
	spin.tween_method(func(a: float) -> void: _visual.rotation.y = a, from, from + TAU, 0.6)
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		_visual.hero_look.randomize_look(_rng)
		_flash_slot = ""
		_changed())


func _changed() -> void:
	_visual.apply_hero_look()
	_refresh()


## Drag on the open part of the screen to turn the character.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.position.x < get_viewport().get_visible_rect().size.x - PANEL_W - 40.0:
			_visual.rotation.y += drag.relative.x * 0.012
			if absf(drag.relative.y) > absf(drag.relative.x) * 0.6:      # mostly up/down: tilt the view
				_pitch = clampf(_pitch - drag.relative.y * 0.15, -30.0, 25.0)
				var v: Array = CLOSE_VIEW if _zoomed else FULL_VIEW
				var offset: Vector3 = v[2]
				offset.y *= _visual.hero_look.height
				_camera_rig.set_view(v[0], v[1] + _pitch, offset, 0.05)


## A soft ring of light under the character while the screen is open.
func _add_ring() -> void:
	_ring = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.6
	quad.orientation = PlaneMesh.FACE_Y
	var mat := ShaderMaterial.new()
	mat.shader = GLOW
	mat.set_shader_parameter("color", Color(1.0, 0.82, 0.5))
	mat.set_shader_parameter("disc", true)
	mat.set_shader_parameter("strength", 0.8)
	quad.material = mat
	_ring.mesh = quad
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.get_parent().add_child(_ring)
	_ring.position = Vector3(0, 0.04, 0)


func _close() -> void:
	_visual.hero_look.save()
	_visual.wear_gear = true
	_visual.apply_hero_look()
	if is_instance_valid(_ring):
		_ring.queue_free()
	Controls.locked = false
	_camera_rig.reset_view()
	closed.emit()
	queue_free()
