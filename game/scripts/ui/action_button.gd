extends Control
## The big round action button (bottom right). It reads touches directly, by finger, so it
## works while the other thumb holds the joystick. Shows the current verb (Chop / Mine / Pick).

signal pressed
signal released

var radius := 68.0
var margin := Vector2(150, 150)      # centre, measured from the bottom-right corner
var font_size := 28

var verb := ""
var _held := -1
var _pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_verb(new_verb: String) -> void:
	verb = new_verb
	queue_redraw()


func _center() -> Vector2:
	return get_viewport().get_visible_rect().size - margin


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed and touch.position.distance_to(_center()) < radius * 1.25:
		_held = touch.index
		_pulse = 1.0
		pressed.emit()
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif not touch.pressed and touch.index == _held:
		_held = -1
		released.emit()
		queue_redraw()


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta * 4.0, 0.0)
		queue_redraw()


func _draw() -> void:
	var c := _center()
	var active := verb != ""
	var r := radius * (1.0 - 0.08 * _pulse)
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.2), true, -1.0, true)
	draw_circle(c, r, Color(0.08, 0.1, 0.16, 0.62 if active else 0.3), true, -1.0, true)
	draw_arc(c, r, 0.0, TAU, 64, Color(1, 0.95, 0.8, 0.85 if active else 0.25), 3.0, true)
	var font := get_theme_default_font()
	var text := verb if active else "·"
	var size := font_size
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	draw_string(font, c + Vector2(-w / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, -1, size,
		Color(1, 0.97, 0.9, 1.0 if active else 0.4))
