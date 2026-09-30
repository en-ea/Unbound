extends Control
## The big round action button (bottom right). It reads touches directly, by finger, so it
## works while the other thumb holds the joystick. Shows the current verb (Chop / Mine / Pick).

signal pressed
signal released
signal swiped(dir: String)       # "up", "down", "left" or "right": a flick that starts on the button

var swipes := {}             # dir -> label; with any set, a tap acts on release and a flick acts instead

var radius := 68.0
var margin := Vector2(150, 150)      # centre, measured from the bottom-right corner
var font_size := 28

var verb := ""
var sub := ""                # small second line under the verb (a hint like "hold: sprint")
var meter := 1.0             # 0..1: a thin arc round the rim while below 1 (stamina)
var meter_color := Color(0.62, 0.9, 0.38)
var lit := false             # glows while its hold action is on (sprinting)
var lit_fill := Color(0.2, 0.3, 0.16, 0.75)     # its colour then (abilities: the class's colour)
var dim := false             # can't be used right now
var _held := -1
var _held_for := 0.0
var _pulse := 0.0
var _shake := 0.0
var _start := Vector2.ZERO
var _swiped := false
const SWIPE := 36.0          # pixels a finger must travel for a flick


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


func set_verb(new_verb: String) -> void:
	verb = new_verb
	queue_redraw()


func _center() -> Vector2:
	return get_viewport().get_visible_rect().size - margin


## True if a touch here would press this button (the camera drag leaves those alone).
func covers(pos: Vector2) -> bool:
	return is_visible_in_tree() and pos.distance_to(_center()) < radius * 1.25


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenDrag and event.index == _held and not swipes.is_empty() and not _swiped:
		var moved: Vector2 = event.position - _start
		if moved.length() > SWIPE:
			var dir := ("left" if moved.x < 0.0 else "right") if absf(moved.x) > absf(moved.y) else ("up" if moved.y < 0.0 else "down")
			if swipes.has(dir):
				_swiped = true
				_pulse = 1.0
				swiped.emit(dir)
				queue_redraw()
		return
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed and touch.position.distance_to(_center()) < radius * 1.25:
		_held = touch.index
		_held_for = 0.0
		_start = touch.position
		_swiped = false
		if swipes.is_empty():
			_pulse = 1.0
			pressed.emit()
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif not touch.pressed and touch.index == _held:
		if not swipes.is_empty() and not _swiped:
			_pulse = 1.0
			pressed.emit()        # a plain tap, now that it wasn't a flick
		released.emit()           # (held_for() still answers here)
		_held = -1
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
		fill = lit_fill
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
	for dir: String in swipes:           # the flicks, named just outside the rim
		var at: Vector2 = {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}[dir]
		var label: String = swipes[dir]
		var ls := 14
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, ls).x
		var p := c + at * (r + 14.0) + Vector2(-lw / 2.0 if at.x == 0.0 else (-lw if at.x < 0.0 else 0.0), ls * 0.35)
		draw_string(font, p + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, Color(0, 0, 0, 0.5))
		draw_string(font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, Color(1, 0.95, 0.8, 0.8))
	if sub != "":
		var s2 := int(size * 0.6)
		var w2 := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, s2).x
		draw_string(font, c + Vector2(-w2 / 2.0, size * 0.35 + s2 * 0.75), sub, HORIZONTAL_ALIGNMENT_CENTER, -1, s2,
			Color(1, 0.97, 0.9, 0.6 if active else 0.3))
