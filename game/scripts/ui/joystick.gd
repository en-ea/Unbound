extends Control
## Virtual joystick: touch anywhere on the left half of the screen and drag.

const RADIUS := 80.0
const MAX_JUMP := 200.0      # ignore drag jumps bigger than this (touch glitches)

var _finger := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _rim_age := 0.0 # studio: deliberate sustained rim starts sprint, releasing the stick cancels it
var _studio_feet := preload("res://scripts/studio/player/stick_gesture.gd").new() # studio: proposal - B3 slice 3, a quick flick dodges, a tap crouches


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or Controls.locked or VillageSession.background: # studio: inactive pointers cannot restart movement
		_release()
		# Hidden behind a screen (Bag, menu): still notice the finger lifting, or the stick sticks.
		if event is InputEventScreenTouch and not event.pressed and event.index == _finger:
			_release()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1 and touch.position.x < get_viewport().get_visible_rect().size.x * 0.5 \
				and not preload("res://scripts/studio/news/board.gd").blocks_stick(get_tree(), touch.position):   # studio: proposal - a tap on the news board or the tracker is not the stick
			_finger = touch.index
			_origin = touch.position
			_knob = Vector2.ZERO
			_studio_feet.begin(touch.index, touch.position, get_viewport().get_visible_rect().size) # studio: proposal - same finger, same origin
			queue_redraw()
		elif not touch.pressed and touch.index == _finger:
			Controls.stick_act = _studio_feet.release(touch.index) # studio: proposal - only a real lift asks; a lock or focus loss does not
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _finger or drag.relative.length() > MAX_JUMP:
			return
		_studio_feet.drag(drag.index, drag.position) # studio: proposal - before the base follows the finger
		var offset := drag.position - _origin
		if offset.length() > RADIUS:
			# The base follows the finger, so you never "run out" of joystick.
			_origin += offset - offset.normalized() * RADIUS
			offset = offset.normalized() * RADIUS
		_knob = offset
		Controls.joystick = offset / RADIUS
		queue_redraw()


# studio: one movement finger, active-time rim dwell; no neighbour changes the gesture.
func _process(dt: float) -> void:
	if not is_visible_in_tree() or Controls.locked or VillageSession.background: # studio: background holds cannot arm sprint
		_release()
		return
	if _finger>=0: _studio_feet.tick(dt) # studio: proposal - active time only, as the rim dwell
	if _finger>=0 and Controls.joystick.length()>=0.88:
		_rim_age+=dt
		Controls.stick_sprint=_rim_age>=0.4
	elif Controls.joystick.length()<0.72:
		_rim_age=0.0
		Controls.stick_sprint=false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_release()


func _release() -> void:
	_rim_age=0.0 # studio: focus/menu/release clears sprint with movement
	_studio_feet.cancel() # studio: proposal - a cancelled finger asks for nothing
	Controls.stick_sprint=false
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
