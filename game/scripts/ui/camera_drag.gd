extends Control
## Turns the camera: drag a finger on the right half of the screen, anywhere but on a button
## (a right-mouse drag on the PC). The left half is the joystick's.

const TURN_PER_PIXEL := 0.006     # radians per UI pixel of drag
const MAX_JUMP := 200.0           # ignore drag jumps bigger than this (touch glitches)

var camera_rig: Node3D

var _finger := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and touch.index == _finger:
			_finger = -1
			camera_rig.held = false
		elif touch.pressed and _finger == -1 and _can_turn() \
				and touch.position.x >= get_viewport().get_visible_rect().size.x * 0.5 \
				and not _on_button(touch.position):
			_finger = touch.index
			camera_rig.held = true
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger and drag.relative.length() <= MAX_JUMP and _can_turn():
			camera_rig.turn(-drag.relative.x * TURN_PER_PIXEL)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT and _can_turn():
			camera_rig.turn(-motion.relative.x * TURN_PER_PIXEL)


func _can_turn() -> bool:
	return visible and not Controls.locked


## True over any visible button of the HUD (Attack, Roll, Heavy, the menu buttons...).
func _on_button(pos: Vector2) -> bool:
	for n in get_parent().find_children("*", "Control", true, false):
		var c := n as Control
		if c.has_method("covers"):
			if c.covers(pos):
				return true
		elif c is BaseButton and c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_finger = -1
		if camera_rig:
			camera_rig.held = false
