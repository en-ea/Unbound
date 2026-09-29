extends Node3D
## Tunic-style camera: a fixed angle that follows the player and never rotates.

@export var target: Node3D
@export var pitch_degrees := -45.0
@export var distance := 18.0
@export var fov := 32.0
@export var follow_speed := 5.0
@export var look_ahead := 0.35     # seconds of movement to look ahead, so you see where you're going
@export var max_look_ahead := 2.5

## Indoors: a closer, steeper view that stays mostly on the room and follows you a little.
const ROOM_DISTANCE := 15.0
const ROOM_PITCH := -52.0
const ROOM_PULL := 0.3

@onready var camera: Camera3D = $Camera3D

var _offset := Vector3.ZERO          # shifts the view (the look picker puts you left of centre)
var _default_view := Vector2.ZERO    # (distance, pitch) to return to
var _shake := 0.0
var _view_tween: Tween
var _base_distance := 18.0
var _outdoor_pitch := -45.0
var _room := Vector3.INF             # indoors: the room's centre


func _ready() -> void:
	add_to_group("camera_rig")
	camera.fov = fov
	camera.far = 220.0
	camera.near = 0.3
	_base_distance = distance
	_outdoor_pitch = pitch_degrees
	_default_view = Vector2(distance * Settings.zoom, pitch_degrees)
	set_distance(_default_view.x)
	Settings.changed.connect(_on_settings_changed)
	snap()


## Smoothly moves to a closer or different view (e.g. for the look picker).
func set_view(d: float, pitch: float, offset: Vector3, time := 0.6) -> void:
	if _view_tween:
		_view_tween.kill()          # a new view replaces any move still in progress
	_view_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_view_tween.tween_method(_apply_view, Vector2(distance, pitch_degrees), Vector2(d, pitch), time)
	_view_tween.tween_property(self, "_offset", offset, time)


## The camera zoom setting changed: move to the new distance (only in normal play).
func _on_settings_changed() -> void:
	var d := (_base_distance if _room == Vector3.INF else ROOM_DISTANCE) * Settings.zoom
	if is_equal_approx(d, _default_view.x):
		return
	var in_play := _offset == Vector3.ZERO and is_equal_approx(distance, _default_view.x)
	_default_view.x = d
	if in_play:
		reset_view(0.4)


## Going indoors: the room view, centred on `center` (the room's middle).
func enter_room(center: Vector3) -> void:
	_room = center
	_jump_to(Vector2(ROOM_DISTANCE * Settings.zoom, ROOM_PITCH))


func leave_room() -> void:
	_room = Vector3.INF
	_jump_to(Vector2(_base_distance * Settings.zoom, _outdoor_pitch))


func _jump_to(view: Vector2) -> void:
	if _view_tween:
		_view_tween.kill()
	_default_view = view
	_offset = Vector3.ZERO
	_apply_view(view)
	snap()


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


## A short jolt (hits, impacts). Strength is in metres of camera offset.
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 0.5, 0.0)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake
		camera.v_offset = randf_range(-1.0, 1.0) * _shake
	if target:
		global_position = global_position.lerp(_focus(), clampf(follow_speed * delta, 0.0, 1.0))


func _focus() -> Vector3:
	if _room != Vector3.INF and _offset == Vector3.ZERO:
		return _room.lerp(target.global_position, ROOM_PULL) + Vector3(0, 0.6, 0)
	var ahead := Vector3.ZERO
	if target is CharacterBody3D:
		var v: Vector3 = (target as CharacterBody3D).velocity
		ahead = Vector3(v.x, 0.0, v.z) * look_ahead
		ahead = ahead.limit_length(max_look_ahead)
		# Show a bit more of what is above you on screen (the camera looks north).
		ahead.z *= 1.3
	return target.global_position + Vector3(0, 1.0, 0) + ahead + _offset
