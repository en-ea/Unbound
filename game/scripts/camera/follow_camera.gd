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

var _offset := Vector3.ZERO          # shifts the view (the look picker puts you left of centre)
var _default_view := Vector2.ZERO    # (distance, pitch) to return to


func _ready() -> void:
	camera.fov = fov
	camera.far = 220.0
	camera.near = 0.3
	_default_view = Vector2(distance, pitch_degrees)
	set_distance(distance)
	snap()


## Smoothly moves to a closer or different view (e.g. for the look picker).
func set_view(d: float, pitch: float, offset: Vector3, time := 0.6) -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_apply_view, Vector2(distance, pitch_degrees), Vector2(d, pitch), time)
	tween.tween_property(self, "_offset", offset, time)


func reset_view(time := 0.6) -> void:
	set_view(_default_view.x, _default_view.y, Vector3.ZERO, time)


func _apply_view(v: Vector2) -> void:
	pitch_degrees = v.y
	set_distance(v.x)


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
	return target.global_position + Vector3(0, 1.0, 0) + ahead + _offset
