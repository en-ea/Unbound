extends CharacterBody3D
## Moves the player from Controls input. The model and animations live in CharacterVisual.

const WALK_SPEED := 1.6
const RUN_SPEED := 5.4
const RUN_THRESHOLD := 0.75
const ACCEL := 12.0
const TURN_SPEED := 12.0
const GRAVITY := 22.0

@onready var visual: CharacterVisual = $Visual


func _physics_process(delta: float) -> void:
	var move := Controls.get_move()
	var strength := move.length()
	var target_speed := 0.0
	if strength > 0.1:
		target_speed = RUN_SPEED if strength >= RUN_THRESHOLD else WALK_SPEED * remap(strength, 0.1, RUN_THRESHOLD, 0.6, 1.0)
	# The camera never rotates, so screen up is world -Z.
	var dir := Vector3(move.x, 0.0, move.y).normalized()
	var flat := Vector3(velocity.x, 0.0, velocity.z).lerp(dir * target_speed, clampf(ACCEL * delta, 0.0, 1.0))
	velocity.x = flat.x
	velocity.z = flat.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	var speed := Vector2(velocity.x, velocity.z).length()
	if strength > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	visual.play_motion(speed)
