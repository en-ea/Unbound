class_name UIStyle
extends RefCounted
## Shared look for menus: dark translucent panels, rounded buttons, round colour swatches.

const PANEL_BG := Color(0.06, 0.08, 0.13, 0.84)
const BUTTON_BG := Color(0.05, 0.07, 0.12, 0.55)
const BUTTON_PRESSED := Color(0.16, 0.2, 0.3, 0.85)
const TEXT := Color(1, 0.97, 0.9)
const TEXT_DIM := Color(1, 0.97, 0.9, 0.6)


static func panel(radius := 22) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.set_corner_radius_all(radius)
	box.border_color = Color(1, 1, 1, 0.12)
	box.set_border_width_all(1)
	box.set_content_margin_all(20)
	return box


static func button(parent: Node, text: String, min_size := Vector2(130, 52), font_size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = BUTTON_PRESSED if state == "pressed" else BUTTON_BG
		box.set_corner_radius_all(16)
		box.border_color = Color(1, 1, 1, 0.25)
		box.set_border_width_all(1)
		b.add_theme_stylebox_override(state, box)
	parent.add_child(b)
	return b


static func label(parent: Node, text: String, font_size := 20, dim := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", TEXT_DIM if dim else TEXT)
	parent.add_child(l)
	return l


static func swatch(parent: Node, color: Color, selected: bool, size := 38.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(int(size / 2.0))
		box.border_color = Color(1, 1, 1, 0.95) if selected else Color(0, 0, 0, 0.35)
		box.set_border_width_all(3 if selected else 1)
		b.add_theme_stylebox_override(state, box)
	parent.add_child(b)
	return b
