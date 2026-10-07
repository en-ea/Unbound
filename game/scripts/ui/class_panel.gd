extends Control
## The class screen: four paths as cards. The Pyromancer and the Delver are open (emblem, what it's about,
## its trait and abilities); the other two are sealed until later in the story. From the shrine (`from_shrine`)
## it asks you to choose; from the Menu it shows your class. Choosing calls Classes.choose().

signal closed
signal chosen(id: String)

const DISPLAY_FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")
const TITLE_FONT := preload("res://assets/fonts/Almendra-Bold.ttf")

var from_shrine := false
var _time := 0.0
var _emblems: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var title := _label(column, "THE SHRINE OFFERS YOU A PATH" if from_shrine and Classes.current == "" else "YOUR PATH", 28, Color(1.0, 0.86, 0.6), DISPLAY_FONT)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.14, 0.05))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(cards)
	for id: String in Classes.CLASSES:
		cards.add_child(_card(id))
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(foot)
	UIStyle.button(foot, "Later" if from_shrine and Classes.current == "" else "Close", Vector2(160, 50)).pressed.connect(_close)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func _card(id: String) -> Control:
	var def: Dictionary = Classes.CLASSES[id]
	var sealed: bool = def.get("sealed", false)
	var tint: Color = Color(0.45, 0.45, 0.5) if sealed else def["color"]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320 if not sealed else 190, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.06, 0.06, 0.96) if not sealed else Color(0.05, 0.05, 0.07, 0.9)
	box.set_corner_radius_all(20)
	box.border_color = Color(tint, 0.9 if not sealed else 0.35)
	box.set_border_width_all(3 if not sealed else 2)
	if not sealed:
		box.shadow_color = Color(tint, 0.35)
		box.shadow_size = 20
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	card.add_child(col)
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2(0, 84)
	emblem.draw.connect(_draw_emblem.bind(emblem, sealed, tint, id))
	col.add_child(emblem)
	_emblems.append(emblem)
	if sealed:
		_label(col, "SEALED", 26, Color(0.7, 0.7, 0.76), DISPLAY_FONT)
		var l := _label(col, "This path sleeps. It wakes later in the story.", 17, Color(0.7, 0.7, 0.76, 0.8), TITLE_FONT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return card
	_label(col, String(def["name"]).to_upper(), 28, tint, DISPLAY_FONT)
	var blurb := _label(col, def["blurb"], 16, Color(1, 0.95, 0.88, 0.9), TITLE_FONT)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if def.has("trait"):
		var trait_line := _label(col, def["trait"], 13, Color(tint.lightened(0.3), 0.85), null)
		trait_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		trait_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for a: String in def["abilities"]:
		var ab: Dictionary = Classes.ABILITIES[a]
		var name := _label(col, "%s  ·  %ss" % [ab["name"], str(snappedf(Classes.cooldown_of(a), 0.1))], 19, Color(1.0, 0.8, 0.5), TITLE_FONT)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var desc := _label(col, ab["desc"], 14, Color(1, 0.95, 0.88, 0.75), null)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(gap)
	if Classes.current == id:
		_label(col, "Your path", 20, tint, DISPLAY_FONT)
		var free := Classes.points_free()
		var talents := UIStyle.button(col, "Talents" + ("  (%d to spend)" % free if free > 0 else ""), Vector2(0, 48), 20)
		talents.pressed.connect(func() -> void:
			var panel := Control.new()
			panel.set_script(preload("res://scripts/ui/talent_panel.gd"))
			add_child(panel)
			FitToScreen.watch(panel)
			panel.closed.connect(func() -> void:
				talents.text = "Talents" + ("  (%d to spend)" % Classes.points_free() if Classes.points_free() > 0 else "")))
	else:
		var take := UIStyle.button(col, def.get("take", "Take the flame"), Vector2(0, 48), 20)
		take.pressed.connect(func() -> void:
			Classes.choose(id)
			chosen.emit(id)
			_close())
	return card


## A flame (the Pyromancer), three claw marks over cracked earth (the Delver) or a lock (sealed) in a ring.
func _draw_emblem(c: Control, sealed: bool, tint: Color, id: String) -> void:
	var center := Vector2(c.size.x / 2.0, 46)
	c.draw_arc(center, 42, 0, TAU, 48, Color(tint, 0.6), 2.5, true)
	c.draw_arc(center, 35, 0, TAU, 48, Color(tint, 0.25), 1.5, true)
	if sealed:
		c.draw_arc(center + Vector2(0, -8), 12, PI, TAU, 16, Color(tint, 0.8), 4.0, true)
		c.draw_rect(Rect2(center + Vector2(-16, -6), Vector2(32, 26)), Color(tint, 0.8))
		return
	if id == "tidecaller": WaterFX.emblem(c, center, tint, _time); return # studio: water class (a drop over a wave)
	if id == "delver":
		var pulse := 0.75 + sin(_time * 3.0) * 0.25
		c.draw_polyline(PackedVector2Array([center + Vector2(-30, 24), center + Vector2(-12, 18), center + Vector2(-4, 26),
			center + Vector2(10, 18), center + Vector2(30, 24)]), Color(tint, 0.5 * pulse), 3.0, true)
		for k in 3:                                   # three claw slashes, curved
			var x := (k - 1) * 14.0
			var pts := PackedVector2Array()
			for j in 7:
				var f := j / 6.0
				pts.append(center + Vector2(x + 10.0 - f * 20.0 + sin(f * PI) * 5.0, -30.0 + f * 52.0))
			c.draw_polyline(pts, Color(0.92, 0.95, 0.94), 6.0 - absf(k - 1) * 1.0, true)
			c.draw_polyline(pts, Color(tint, pulse), 2.0, true)
		return
	var flick := sin(_time * 7.0) * 3.0
	var outer := PackedVector2Array([center + Vector2(0, -36 + flick), center + Vector2(15, -10), center + Vector2(20, 12),
		center + Vector2(0, 28), center + Vector2(-20, 12), center + Vector2(-13, -12), center + Vector2(-6, -2)])
	c.draw_colored_polygon(outer, Color(1.0, 0.42, 0.1))
	var inner := PackedVector2Array([center + Vector2(0, -14 - flick), center + Vector2(9, 6), center + Vector2(0, 22), center + Vector2(-9, 6)])
	c.draw_colored_polygon(inner, Color(1.0, 0.85, 0.4))


func _process(delta: float) -> void:
	_time += delta
	for e in _emblems:
		e.queue_redraw()


func _label(parent: Node, text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _close() -> void:
	closed.emit()
	queue_free()
