extends Control
## Virtual joystick: touch anywhere on the left half of the screen and drag.

const RADIUS := 80.0
const MAX_JUMP := 200.0      # ignore drag jumps bigger than this (touch glitches)

var _finger := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1 and touch.position.x < size.x * 0.5:
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release()


func _release() -> void:
	_finger = -1
	_knob = Vector2.ZERO
	Controls.joystick = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if _finger == -1:
		return
	draw_circle(_origin, RADIUS, Color(1, 1, 1, 0.08))
	draw_arc(_origin, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
	draw_circle(_origin + _knob, 30.0, Color(1, 1, 1, 0.45))
