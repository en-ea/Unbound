extends Node3D
## Follow camera: a low view behind you that shows some sky and the land ahead. It turns when you
## drag the screen (arrow keys or a right-mouse drag on the PC), and nudges round to keep a nearby
## enemy in view. Stick movement is relative to where it looks (see Controls.cam_yaw).
## Indoors it goes back to a steep fixed view.

@export var target: Node3D
@export var pitch_degrees := -20.0
@export var distance := 11.0
@export var fov := 45.0
@export var follow_speed := 5.0
@export var look_ahead := 0.35     # seconds of movement to look ahead, so you see where you're going
@export var max_look_ahead := 2.5

## Indoors: a closer, steeper view that stays mostly on the room and follows you a little.
const ROOM_DISTANCE := 15.0
const ROOM_PITCH := -52.0
const ROOM_PULL := 0.3
## The lens for close views (title, look picker, knocked out) and indoors.
const CLOSE_FOV := 32.0
const KEY_TURN := 2.2              # radians a second with the arrow keys
const HELP_TURN := 1.1             # radians a second when turning to show an enemy behind you
const HELP_RANGE := 9.0            # enemies this close get turned into view
const HELP_WAIT := 2.0             # seconds after you turn it yourself before it helps again
const GROUND_CLEAR := 0.9          # keep the lens and the line of sight this far above the ground

@onready var camera: Camera3D = $Camera3D

var _offset := Vector3.ZERO          # shifts the view (the look picker puts you left of centre)
var _default_view := Vector2.ZERO    # (distance, pitch) to return to
var _shake := 0.0
var _view_tween: Tween
var _base_distance := 11.0
var _outdoor_pitch := -20.0
var _room := Vector3.INF             # indoors: the room's centre
var _yaw := 0.0
var _outdoor_yaw := 0.0
var _since_turn := HELP_WAIT
var _shape := WorldShape.new()


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


## Smoothly moves to a closer or different view (e.g. for the look picker). Views with an offset
## (title, picker) face the camera north again, as they are framed for that.
func set_view(d: float, pitch: float, offset: Vector3, time := 0.6, lens := CLOSE_FOV) -> void:
	if _view_tween:
		_view_tween.kill()          # a new view replaces any move still in progress
	_view_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_view_tween.tween_method(_apply_view, Vector2(distance, pitch_degrees), Vector2(d, pitch), time)
	_view_tween.tween_property(self, "_offset", offset, time)
	_view_tween.tween_property(camera, "fov", lens, time)
	if offset != Vector3.ZERO:
		_view_tween.tween_method(_set_yaw, _yaw, 0.0, time)


## Turns the camera (radians; positive turns the view left). Only outdoors.
func turn(amount: float) -> void:
	if _room != Vector3.INF:
		return
	_set_yaw(_yaw + amount)
	_since_turn = 0.0


func _set_yaw(y: float) -> void:
	_yaw = wrapf(y, -PI, PI)
	rotation.y = _yaw
	Controls.cam_yaw = _yaw


## The camera zoom setting changed: move to the new distance (only in normal play).
func _on_settings_changed() -> void:
	var d := (_base_distance if _room == Vector3.INF else ROOM_DISTANCE) * Settings.zoom
	if is_equal_approx(d, _default_view.x):
		return
	var in_play := _offset == Vector3.ZERO and is_equal_approx(distance, _default_view.x)
	_default_view.x = d
	if in_play:
		reset_view(0.4)


## Going indoors: the room view, centred on `center` (the room's middle), facing north.
func enter_room(center: Vector3) -> void:
	_room = center
	_outdoor_yaw = _yaw
	_set_yaw(0.0)
	_jump_to(Vector2(ROOM_DISTANCE * Settings.zoom, ROOM_PITCH))


func leave_room() -> void:
	_room = Vector3.INF
	_set_yaw(_outdoor_yaw)
	_jump_to(Vector2(_base_distance * Settings.zoom, _outdoor_pitch))


func _jump_to(view: Vector2) -> void:
	if _view_tween:
		_view_tween.kill()
	_default_view = view
	_offset = Vector3.ZERO
	camera.fov = _play_fov()
	_apply_view(view)
	snap()


func reset_view(time := 0.6) -> void:
	set_view(_default_view.x, _default_view.y, Vector3.ZERO, time, _play_fov())


func _play_fov() -> float:
	return fov if _room == Vector3.INF else CLOSE_FOV


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
	_since_turn += delta
	if _room == Vector3.INF and _offset == Vector3.ZERO and not Controls.locked:
		var keys := float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))
		if keys != 0.0:
			turn(keys * KEY_TURN * delta)
		elif _since_turn > HELP_WAIT:
			_show_enemy(delta)
	if target:
		global_position = global_position.lerp(_focus(), clampf(follow_speed * delta, 0.0, 1.0))
	if _room == Vector3.INF:
		_clear_ground()


## An enemy close behind you (off the bottom of the screen): turn slowly until it is in view.
func _show_enemy(delta: float) -> void:
	var fighter := target.get_node_or_null("Fighter")
	if fighter == null:
		return
	var e: Node3D = fighter.nearest_enemy(HELP_RANGE)
	if e == null:
		return
	var to := e.global_position - target.global_position
	if Vector2(to.x, to.z).length() < 1.0:
		return
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var off := forward.signed_angle_to(Vector3(to.x, 0.0, to.z), Vector3.UP)
	var limit := deg_to_rad(75.0)
	if absf(off) > limit:
		_set_yaw(_yaw + signf(off) * minf(absf(off) - limit, HELP_TURN * delta))


## Rises over hills: keeps the lens, and the line from it to you, above the ground.
func _clear_ground() -> void:
	set_distance(distance)            # the plain spot, before lifting
	var eye := camera.global_position
	var focus := global_position
	var lift := 0.0
	for t: float in [0.0, 0.35, 0.7]:
		var p := eye.lerp(focus, t)
		var need := _shape.height_at(p.x, p.z) + GROUND_CLEAR - p.y
		lift = maxf(lift, need / (1.0 - t))
	if lift > 0.0:
		camera.position.y += lift
		camera.look_at(focus)


func _focus() -> Vector3:
	if _room != Vector3.INF and _offset == Vector3.ZERO:
		return _room.lerp(target.global_position, ROOM_PULL) + Vector3(0, 0.6, 0)
	var ahead := Vector3.ZERO
	if target is CharacterBody3D:
		var v: Vector3 = (target as CharacterBody3D).velocity
		ahead = Vector3(v.x, 0.0, v.z) * look_ahead
		ahead = ahead.limit_length(max_look_ahead)
	return target.global_position + Vector3(0, 1.0, 0) + ahead + _offset.rotated(Vector3.UP, _yaw)
