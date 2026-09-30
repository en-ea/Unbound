extends Control
## The talent tree (Class screen > Talents): one column per branch, three talents each, learned top to
## bottom with talent points (Classes.learn). Reset gives every point back for free.

signal closed

const DISPLAY_FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")
const TITLE_FONT := preload("res://assets/fonts/Almendra-Bold.ttf")

var _body: HBoxContainer
var _points: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	column.add_child(head)
	var title := _label(head, "TALENTS", 28, Color(1.0, 0.86, 0.6), DISPLAY_FONT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_points = _label(head, "", 20, Classes.color(), TITLE_FONT)
	UIStyle.button(head, "Reset", Vector2(110, 46), 18).pressed.connect(func() -> void:
		Classes.reset_talents()
		_refresh())
	UIStyle.button(head, "Close", Vector2(110, 46), 18).pressed.connect(_close)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	column.add_child(_body)
	var hint := _label(column, "One point from the shrine, one more for every combat level. Reset is free, so try things out.", 15, Color(1, 0.95, 0.88, 0.6), null)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh()


func _refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	var free := Classes.points_free()
	_points.text = "%d point%s to spend" % [free, "" if free == 1 else "s"]
	for branch: Dictionary in Classes.tree():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		_body.add_child(col)
		_label(col, String(branch["name"]).to_upper(), 18, Color(1.0, 0.8, 0.5), DISPLAY_FONT)
		var list: Array = branch["talents"]
		for i in list.size():
			if i > 0:                          # the little link between talents
				var link := ColorRect.new()
				link.custom_minimum_size = Vector2(4, 12)
				link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				link.color = Color(Classes.color(), 0.9) if Classes.has_talent(list[i]) else Color(1, 1, 1, 0.15)
				col.add_child(link)
			col.add_child(_node(list[i]))


## One talent: a card that is lit (learned), outlined (you can learn it: tap) or dim (not yet).
func _node(id: String) -> Control:
	var def: Dictionary = Classes.TALENTS[id]
	var learned := Classes.has_talent(id)
	var open := Classes.can_learn(id)
	var tint := Classes.color()
	var card := Button.new()
	card.custom_minimum_size = Vector2(250, 118)
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = not open
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(14)
		box.bg_color = Color(tint.darkened(0.6), 0.95) if learned else Color(0.07, 0.06, 0.06, 0.95)
		box.border_color = Color(tint, 1.0 if learned or open else 0.2)
		box.set_border_width_all(3 if open else 2)
		if state == "hover" and open:
			box.bg_color = Color(0.14, 0.1, 0.07, 0.95)
		card.add_theme_stylebox_override(state, box)
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 2)
	card.add_child(inner)
	var name := _label(inner, def["name"], 19, Color(1.0, 0.9, 0.7) if learned or open else Color(1, 1, 1, 0.45), TITLE_FONT)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var desc := _label(inner, def["desc"], 13, Color(1, 0.95, 0.88, 0.8 if learned or open else 0.35), null)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 226
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if learned:
		_label(inner, "Learned", 13, tint, null).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	elif open:
		_label(inner, "Tap to learn", 13, Color(1, 0.9, 0.6), null).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.pressed.connect(func() -> void:
		Classes.learn(id)
		_refresh())
	return card


func _label(parent: Node, text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
