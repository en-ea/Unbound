extends Control
## The big round action button (bottom right). It reads touches directly, by finger, so it
## works while the other thumb holds the joystick. Shows the current verb (Chop / Mine / Pick).

signal pressed
signal released

var radius := 68.0
var margin := Vector2(150, 150)      # centre, measured from the bottom-right corner
var font_size := 28
var _safe := Rect2()                 # where the whole button must stay (clear of notches and the home bar)

var verb := ""
var sub := ""                # small second line under the verb (a hint like "hold: sprint")
var meter := 1.0             # 0..1: a thin arc round the rim while below 1 (stamina)
var meter_color := Color(0.62, 0.9, 0.38)
var lit := false             # glows while its hold action is on (sprinting)
var dim := false             # can't be used right now
var _held := -1
var _held_for := 0.0
var _pulse := 0.0
var _shake := 0.0


func is_held() -> bool:
	return _held != -1


func held_for() -> float:
	return _held_for if _held != -1 else 0.0


## A little shake: "not now" (e.g. out of stamina).
func refuse() -> void:
	_shake = 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_safe()
	get_viewport().size_changed.connect(_update_safe)


func set_verb(new_verb: String) -> void:
	verb = new_verb
	queue_redraw()


func _center() -> Vector2:
	var c := get_viewport().get_visible_rect().size - margin
	var r := Vector2(radius, radius) * 1.15
	return c.clamp(_safe.position + r, _safe.end - r)


func _update_safe() -> void:
	_safe = preload("res://scripts/ui/safe_area.gd").rect(get_viewport())
	queue_redraw()


func _input(event: InputEvent) -> void:
	# Own the complete gesture even when pressing opens a panel and hides this button.
	# Touch emulation sends a mouse press afterwards; it must not hit the new panel.
	if _held != -1 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed and touch.index == _held:
		released.emit()           # (held_for() still answers here)
		_held = -1
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif visible and touch.pressed and touch.position.distance_to(_center()) < radius * 1.25:
		_held = touch.index
		_held_for = 0.0
		_pulse = 1.0
		pressed.emit()
		get_viewport().set_input_as_handled()
		queue_redraw()


func _process(delta: float) -> void:
	if _held != -1:
		_held_for += delta
	if _pulse > 0.0 or _shake > 0.0 or meter < 1.0 or lit:
		_pulse = maxf(_pulse - delta * 4.0, 0.0)
		_shake = maxf(_shake - delta * 3.0, 0.0)
		queue_redraw()


func set_meter(value: float) -> void:
	if value != meter:
		meter = value
		queue_redraw()


func _draw() -> void:
	var c := _center() + Vector2(sin(_shake * 40.0) * 6.0 * _shake, 0)
	var active := verb != "" and not dim
	var r := radius * (1.0 - 0.08 * _pulse)
	var fill := Color(0.08, 0.1, 0.16, 0.62 if active else 0.3)
	if lit:
		fill = Color(0.2, 0.3, 0.16, 0.75)
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.2), true, -1.0, true)
	draw_circle(c, r, fill, true, -1.0, true)
	draw_arc(c, r, 0.0, TAU, 64, Color(1, 0.95, 0.8, 0.85 if active else 0.25), 3.0, true)
	if meter < 1.0:           # stamina: the rim empties anticlockwise from the top
		draw_arc(c, r, 0.0, TAU, 64, Color(0.05, 0.06, 0.1, 0.8), 5.0, true)
		if meter > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * meter, maxi(int(64 * meter), 2), meter_color, 5.0, true)
	var font := get_theme_default_font()
	var text := verb if verb != "" else "·"
	var size := font_size
	var up := size * 0.3 if sub != "" else 0.0
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	draw_string(font, c + Vector2(-w / 2.0, size * 0.35 - up), text, HORIZONTAL_ALIGNMENT_CENTER, -1, size,
		Color(1, 0.97, 0.9, 1.0 if active else 0.4))
	if sub != "":
		var s2 := int(size * 0.6)
		var w2 := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, s2).x
		draw_string(font, c + Vector2(-w2 / 2.0, size * 0.35 + s2 * 0.75), sub, HORIZONTAL_ALIGNMENT_CENTER, -1, s2,
			Color(1, 0.97, 0.9, 0.6 if active else 0.3))
