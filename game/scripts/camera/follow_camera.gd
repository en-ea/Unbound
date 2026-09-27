extends Node3D
## Tunic-style camera: a fixed angle that follows the player and never rotates.

@export var target: Node3D
@export var pitch_degrees := -42.0
@export var distance := 19.0
@export var fov := 30.0
@export var follow_speed := 6.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.fov = fov
	camera.far = 220.0
	camera.near = 0.5
	camera.position = Basis(Vector3.RIGHT, deg_to_rad(pitch_degrees)) * Vector3(0, 0, distance)
	camera.rotation = Vector3(deg_to_rad(pitch_degrees), 0, 0)
	snap()


func snap() -> void:
	if target:
		global_position = _focus()


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(_focus(), clampf(follow_speed * delta, 0.0, 1.0))


func _focus() -> Vector3:
	return target.global_position + Vector3(0, 1.0, 0)
