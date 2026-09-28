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


## A round button with a white icon (Kenney game icons, CC0).
static func icon_button(parent: Node, icon_name: String, size := 60.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	b.icon = load("res://assets/ui/icons/%s.png" % icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(size * 0.55))
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = BUTTON_PRESSED if state == "pressed" else BUTTON_BG
		box.set_corner_radius_all(int(size / 2.0))
		box.border_color = Color(1, 1, 1, 0.25)
		box.set_border_width_all(1)
		box.set_content_margin_all(size * 0.22)
		b.add_theme_stylebox_override(state, box)
	parent.add_child(b)
	return b


## A wide menu button (title screen, pause menu).
static func menu_button(parent: Node, text: String, primary := false) -> Button:
	var b := button(parent, text, Vector2(300, 62), 26)
	if primary:
		for state in ["normal", "hover", "pressed"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(0.93, 0.8, 0.52, 0.95) if state != "pressed" else Color(0.8, 0.66, 0.4)
			box.set_corner_radius_all(18)
			b.add_theme_stylebox_override(state, box)
		b.add_theme_color_override("font_color", Color(0.14, 0.12, 0.1))
		b.add_theme_color_override("font_pressed_color", Color(0.14, 0.12, 0.1))
		b.add_theme_color_override("font_hover_color", Color(0.14, 0.12, 0.1))
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


## A small gold coin, for prices.
static func coin(parent: Node, size := 18.0) -> Control:
	var c := Panel.new()
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.8, 0.3)
	box.border_color = Color(0.8, 0.55, 0.15)
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(size))
	c.add_theme_stylebox_override("panel", box)
	parent.add_child(c)
	return c


## "(coin) 120" in gold.
static func price(parent: Node, amount: int, font_size := 20, ok := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	coin(row, font_size * 0.85)
	var l := label(row, str(amount), font_size)
	l.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4) if ok else Color(1.0, 0.58, 0.52))
	return row
