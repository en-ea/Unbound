extends Node3D
## Tunic-style camera: a fixed angle that follows the player and never rotates.

@export var target: Node3D
@export var pitch_degrees := -45.0
@export var distance := 18.0
@export var fov := 32.0
@export var follow_speed := 5.0
@export var look_ahead := 0.35     # seconds of movement to look ahead, so you see where you're going
@export var max_look_ahead := 2.5

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.fov = fov
	camera.far = 220.0
	camera.near = 0.5
	set_distance(distance)
	snap()


func set_distance(d: float) -> void:
	distance = d
	camera.position = Basis(Vector3.RIGHT, deg_to_rad(pitch_degrees)) * Vector3(0, 0, distance)
	camera.rotation = Vector3(deg_to_rad(pitch_degrees), 0, 0)


func snap() -> void:
	if target:
		global_position = _focus()


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(_focus(), clampf(follow_speed * delta, 0.0, 1.0))


func _focus() -> Vector3:
	var ahead := Vector3.ZERO
	if target is CharacterBody3D:
		var v: Vector3 = (target as CharacterBody3D).velocity
		ahead = Vector3(v.x, 0.0, v.z) * look_ahead
		ahead = ahead.limit_length(max_look_ahead)
		# Show a bit more of what is above you on screen (the camera looks north).
		ahead.z *= 1.3
	return target.global_position + Vector3(0, 1.0, 0) + ahead
