class_name Boar
extends CharacterBody3D
## The boar: wanders near its home; when the player comes close it snorts, paws the ground and
## charges. A charge that connects knocks the player back (it can't kill for now). Five hits
## kill it: it squeals, falls over, drops hide (and sometimes a tusk), and comes back later.

const WALK_SPEED := 1.3
const CHARGE_SPEED := 7.5
const SIGHT := 8.5
const HOME_RADIUS := 9.0
const MAX_HEALTH := 5
const RESPAWN_TIME := 40.0
const GRAVITY := 20.0
const SOUNDS := {
	"snort": preload("res://assets/sounds/boar_snort.wav"),
	"squeal": preload("res://assets/sounds/boar_squeal.wav"),
	"thud": preload("res://assets/sounds/tree_thud.wav"),
}
const DROP := preload("res://scripts/world/drop.gd")

enum State { WANDER, ALERT, CHARGE, RECOVER, HURT, DEAD }

var player: Node3D
var home := Vector3.ZERO
var health := MAX_HEALTH
var state := State.WANDER

var _t := 0.0                 # time in the current state
var _goal := Vector3.ZERO
var _idle := 0.0
var _charge_dir := Vector3.FORWARD
var _push := Vector3.ZERO
var _audio: AudioStreamPlayer3D
@onready var visual: BoarVisual = $Visual


func _ready() -> void:
	add_to_group("enemy")
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 8.0
	add_child(_audio)
	_goal = global_position


func is_alive() -> bool:
	return state != State.DEAD


func _physics_process(delta: float) -> void:
	_t += delta
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var want := Vector3.ZERO
	match state:
		State.WANDER:
			var to_goal := _goal - global_position
			to_goal.y = 0.0
			if dist < SIGHT and not player.is_rolling():
				_enter(State.ALERT)
			elif to_goal.length() > 0.6 and _t < 8.0:
				want = to_goal.normalized() * WALK_SPEED
			else:
				_idle -= delta             # graze a moment, then wander somewhere else
				if _idle <= 0.0:
					var a := randf() * TAU
					_goal = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, HOME_RADIUS)
					_idle = randf_range(1.5, 4.0)
					_t = 0.0
		State.ALERT:
			_face(to_player, delta * 6.0)
			if _t > 0.9:
				_charge_dir = to_player.normalized()
				_enter(State.CHARGE)
		State.CHARGE:
			want = _charge_dir * CHARGE_SPEED
			if dist < 1.3 and not player.is_rolling():
				player.knockback(_charge_dir * 9.0)
				player.take_damage(1)
				get_tree().call_group("camera_rig", "shake", 0.12)
				_enter(State.RECOVER)
			elif _t > 1.5 or (_t > 0.2 and is_on_wall()):
				_enter(State.RECOVER)
		State.RECOVER:
			if _t > 1.4:
				_enter(State.ALERT if dist < SIGHT else State.WANDER)
		State.HURT:
			if _t > 0.35:
				_enter(State.ALERT)
		State.DEAD:
			pass
	var flat := Vector3(velocity.x, 0, velocity.z)
	var accel := 20.0 if state == State.CHARGE else 6.0
	flat = flat.lerp(want, clampf(accel * delta, 0.0, 1.0)) + _push
	_push = _push.lerp(Vector3.ZERO, clampf(8.0 * delta, 0.0, 1.0))
	velocity = Vector3(flat.x, velocity.y - GRAVITY * delta if not is_on_floor() else 0.0, flat.z)
	if state != State.DEAD:
		move_and_slide()
	if want.length() > 0.1 and state != State.ALERT:
		_face(want, delta * (10.0 if state == State.CHARGE else 4.0))
	visual.speed = Vector2(velocity.x, velocity.z).length()


## The action: the player hits the boar.
func take_hit(from: Vector3, damage := 1) -> void:
	if state == State.DEAD:
		return
	health -= damage
	visual.flash()
	var away := global_position - from
	away.y = 0.0
	_push = away.normalized() * 4.0
	_play("squeal", randf_range(0.95, 1.15))
	if health <= 0:
		_die()
	else:
		_enter(State.HURT)


func _die() -> void:
	_enter(State.DEAD)
	collision_layer = 0
	get_tree().create_timer(0.35).timeout.connect(func() -> void: _play("thud", 1.2))
	for item in _loot():
		var drop := Node3D.new()
		drop.set_script(DROP)
		get_parent().add_child(drop)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(1.0, 2.0)
		drop.launch(item, global_position + Vector3(0, 0.8, 0), dir + Vector3(0, randf_range(3.5, 5.0), 0), global_position.y, player)
	var gone := create_tween()
	gone.tween_interval(2.5)
	gone.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.5)
	gone.tween_callback(func() -> void: visible = false)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_respawn)


func _loot() -> Array[String]:
	var items: Array[String] = ["hide"]
	if randf() < 0.5:
		items.append("hide")
	if randf() < 0.3:
		items.append("tusk")
	return items


func _respawn() -> void:
	global_position = home + Vector3(0, 0.5, 0)
	health = MAX_HEALTH
	collision_layer = 1
	visual.reset()
	visible = true
	visual.scale = Vector3.ONE * 0.01
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_enter(State.WANDER)


func _enter(new_state: State) -> void:
	state = new_state
	_t = 0.0
	visual.mode = {State.ALERT: "alert", State.CHARGE: "charge", State.HURT: "hurt", State.DEAD: "dead"}.get(new_state, "walk")
	if new_state == State.ALERT:
		_play("snort", randf_range(0.9, 1.1))


func _face(dir: Vector3, weight: float) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(weight, 0.0, 1.0))


func _play(sound: String, pitch: float) -> void:
	_audio.stream = SOUNDS[sound]
	_audio.pitch_scale = pitch
	_audio.play()
