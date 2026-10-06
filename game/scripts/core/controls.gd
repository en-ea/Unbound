extends Node
## Player input, merged from the on-screen joystick and the keyboard (for PC testing).
## Kept apart from the player so other input sources (a network peer, later) can plug in.

## Set by the joystick: x = right, y = down the screen, length 0..1.
var joystick := Vector2.ZERO
## True while a menu (like the look picker) has the player's attention.
var locked := false
## True while the Roll button is held (roll, then keep holding to sprint).
var stick_sprint := false # studio: sustained outer-stick intent, independent of preserved Roll adapter
var sprint_button := false
var stick_act := {} # studio: proposal - B3 slice 3, the stick's lift asks for a dodge or a crouch; Body's Hands reads it once
## The camera's turn (radians, set by the camera): movement is relative to where it looks.
var cam_yaw := 0.0
## True while the Attack button (attack_touch, set by the HUD) or the left mouse button / E (attack_key, set
## by the player) is held: the bow draws while it's held and looses on letting go.
var attack_touch := false
var attack_key := false


func is_attack_held() -> bool:
	return not locked and (attack_touch or attack_key)


func is_sprint_held() -> bool:
	return not locked and (stick_sprint or sprint_button or Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_SHIFT)) # studio: merge - his Shift sprint kept beside the stick-rim sprint


## Returns the wanted movement on the ground plane (x = world x, y = world z), length 0..1.
## Stick up means "away from the camera". Joystick past ~75% means run; the keyboard always runs (Shift sprints).
func get_move() -> Vector2:
	return _screen_move().rotated(-cam_yaw)


func _screen_move() -> Vector2:
	if locked:
		return Vector2.ZERO
	if joystick != Vector2.ZERO:
		return joystick.limit_length(1.0)
	var k := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if k == Vector2.ZERO:
		return k
	return k.normalized()
