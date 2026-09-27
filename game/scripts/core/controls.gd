extends Node
## Player input, merged from the on-screen joystick and the keyboard (for PC testing).
## Kept apart from the player so other input sources (a network peer, later) can plug in.

## Set by the joystick: x = right, y = down the screen, length 0..1.
var joystick := Vector2.ZERO


## Returns the wanted movement on the ground plane, length 0..1.
## Joystick past ~75% means run; the keyboard runs unless Shift is held.
func get_move() -> Vector2:
	if joystick != Vector2.ZERO:
		return joystick.limit_length(1.0)
	var k := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if k == Vector2.ZERO:
		return k
	return k.normalized() * (0.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
