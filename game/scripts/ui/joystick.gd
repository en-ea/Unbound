extends Control
## Virtual joystick: touch anywhere on the left half of the screen and drag.

const RADIUS := 80.0
const MAX_JUMP := 200.0      # ignore drag jumps bigger than this (touch glitches)

var _finger := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not visible:
		# Hidden behind a screen (Bag, menu): still notice the finger lifting, or the stick sticks.
		if event is InputEventScreenTouch and not event.pressed and event.index == _finger:
			_release()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1 and touch.position.x < get_viewport().get_visible_rect().size.x * 0.5:
			_finger = touch.index
			_origin = touch.position
			_knob = Vector2.ZERO
			queue_redraw()
		elif not touch.pressed and touch.index == _finger:
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _finger or drag.relative.length() > MAX_JUMP:
			return
		var offset := drag.position - _origin
		if offset.length() > RADIUS:
			# The base follows the finger, so you never "run out" of joystick.
			_origin += offset - offset.normalized() * RADIUS
			offset = offset.normalized() * RADIUS
		_knob = offset
		Controls.joystick = offset / RADIUS
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_release()


func _release() -> void:
	_finger = -1
	_knob = Vector2.ZERO
	Controls.joystick = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if _finger == -1:
		# A faint hint of where to put your thumb.
		var hint := Vector2(220.0, get_viewport().get_visible_rect().size.y - 190.0)
		draw_arc(hint, RADIUS * 0.8, 0.0, TAU, 64, Color(1, 1, 1, 0.12), 3.0, true)
		draw_circle(hint, 20.0, Color(1, 1, 1, 0.1), true, -1.0, true)
		return
	draw_circle(_origin, RADIUS + 6.0, Color(0.05, 0.07, 0.12, 0.18), true, -1.0, true)
	draw_arc(_origin, RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.4), 3.0, true)
	var knob := _origin + _knob
	draw_circle(knob + Vector2(0, 3), 30.0, Color(0, 0, 0, 0.18), true, -1.0, true)
	draw_circle(knob, 30.0, Color(1, 1, 1, 0.55), true, -1.0, true)
	draw_arc(knob, 30.0, 0.0, TAU, 48, Color(1, 1, 1, 0.85), 2.0, true)
