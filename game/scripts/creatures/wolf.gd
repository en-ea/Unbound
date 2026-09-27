class_name Wolf
extends CharacterBody3D
## The wolf: roams with its pack. When it spots the player it growls, then circles at a distance;
## it stops for a moment (the tell), darts in for a bite, and backs off to circle again. Only one
## wolf lunges at a time. Quick but fragile: three hits. Drops a pelt and sometimes a fang.

const WALK_SPEED := 1.6
const CIRCLE_SPEED := 3.0
const LUNGE_SPEED := 10.0
const CIRCLE_RADIUS := 3.8
const SIGHT := 10.0
const HOME_RADIUS := 8.0
const LEASH := 22.0
const MAX_HEALTH := 6          # sword damage is 2 (Worn) to 5 (Iron)
const RESPAWN_TIME := 50.0
const GRAVITY := 20.0
const SOUNDS := {
	"growl": preload("res://assets/sounds/wolf_growl.wav"),
	"yelp": preload("res://assets/sounds/wolf_yelp.wav"),
	"snap": preload("res://assets/sounds/wolf_snap.wav"),
	"thud": preload("res://assets/sounds/tree_thud.wav"),
}
const DROP := preload("res://scripts/world/drop.gd")
const TOOL_DROP := preload("res://scripts/world/tool_drop.gd")

enum State { WANDER, ALERT, CIRCLE, WINDUP, LUNGE, RETREAT, HURT, DEAD }

static var _lunge_free_at := 0.0     # pack rule: one lunge at a time

var player: Node3D
var home := Vector3.ZERO
var shadow := false                 # a shadow wolf: bigger, darker, tougher, rarer loot (set before adding)
var max_health := MAX_HEALTH
var health := MAX_HEALTH
var state := State.WANDER

var _t := 0.0
var _goal := Vector3.ZERO
var _idle := 0.0
var _circle_time := 0.0
var _side := 1.0                    # circling direction
var _lunge_dir := Vector3.FORWARD
var _bit := false
var _push := Vector3.ZERO
var _audio: AudioStreamPlayer3D
@onready var visual: WolfVisual = $Visual


func _ready() -> void:
	add_to_group("enemy")
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 8.0
	add_child(_audio)
	_goal = global_position
	_side = 1.0 if randf() < 0.5 else -1.0
	if shadow:
		max_health = 16
		health = max_health
		visual.scale = Vector3.ONE * _size()
		for m in visual._materials:          # dusky violet fur
			m.set_shader_parameter("albedo", Color(0.42, 0.38, 0.62))


func is_alive() -> bool:
	return state != State.DEAD


func _physics_process(delta: float) -> void:
	_t += delta
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var toward := to_player / maxf(dist, 0.01)
	var want := Vector3.ZERO
	var face := Vector3.ZERO
	var lost: bool = not player.can_be_targeted() or _home_distance() > LEASH
	match state:
		State.WANDER:
			if _t > 4.0:
				health = max_health       # calm again: healed
			var to_goal := _goal - global_position
			to_goal.y = 0.0
			if dist < SIGHT and player.can_be_targeted() and _home_distance() < LEASH:
				_enter(State.ALERT)
			elif to_goal.length() > 0.6 and _t < 8.0:
				want = to_goal.normalized() * WALK_SPEED
			else:
				_idle -= delta
				if _idle <= 0.0:
					var a := randf() * TAU
					_goal = home + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, HOME_RADIUS)
					_idle = randf_range(2.0, 5.0)
					_t = 0.0
		State.ALERT:
			face = toward
			if lost:
				_give_up()
			elif _t > 0.7:
				_enter(State.CIRCLE)
		State.CIRCLE:
			# Lope around the player (facing where it runs), drifting in or out to hold the distance.
			var around := toward.cross(Vector3.UP) * _side
			want = (around + toward * clampf((dist - CIRCLE_RADIUS) * 0.6, -1.0, 1.0)).normalized() * CIRCLE_SPEED
			if lost:
				_give_up()
			elif _t > _circle_time and dist < CIRCLE_RADIUS + 2.0 and _now() >= _lunge_free_at:
				_lunge_free_at = _now() + 1.6
				_enter(State.WINDUP)
			elif is_on_wall():
				_side = -_side
		State.WINDUP:
			face = toward            # stops dead and crouches: the tell
			if _t > 0.45:
				_lunge_dir = toward
				_bit = false
				_enter(State.LUNGE)
		State.LUNGE:
			want = _lunge_dir * LUNGE_SPEED
			if not _bit and dist < 1.1 and not player.is_rolling():
				_bit = true
				_play("snap", randf_range(0.95, 1.1))
				player.knockback(_lunge_dir * 5.0)
				player.take_damage(2 if shadow else 1)
				get_tree().call_group("camera_rig", "shake", 0.08)
			if _t > 0.4 or (_t > 0.1 and is_on_wall()):
				_enter(State.RETREAT)
		State.RETREAT:
			face = toward
			want = -toward * 3.5
			if _t > 0.8:
				_side = -_side if randf() < 0.4 else _side
				_enter(State.CIRCLE)
		State.HURT:
			if _t > 0.3:
				_enter(State.RETREAT)
		State.DEAD:
			pass
	var flat := Vector3(velocity.x, 0, velocity.z)
	var accel := 22.0 if state == State.LUNGE else 8.0
	flat = flat.lerp(want, clampf(accel * delta, 0.0, 1.0)) + _push
	_push = _push.lerp(Vector3.ZERO, clampf(8.0 * delta, 0.0, 1.0))
	velocity = Vector3(flat.x, velocity.y - GRAVITY * delta if not is_on_floor() else 0.0, flat.z)
	if state != State.DEAD:
		move_and_slide()
	if face != Vector3.ZERO:
		_face(face, delta * 8.0)
	elif want.length() > 0.1:
		_face(want, delta * (12.0 if state == State.LUNGE else 5.0))
	visual.speed = Vector2(velocity.x, velocity.z).length()


## The action: the player hits the wolf.
func take_hit(from: Vector3, damage := 1) -> void:
	if state == State.DEAD:
		return
	health -= damage
	visual.flash()
	visual.show_health(float(health) / max_health, max_health / 2)
	var away := global_position - from
	away.y = 0.0
	_push = away.normalized() * 5.0
	_play("yelp", randf_range(0.95, 1.12))
	if health <= 0:
		_die()
	else:
		_enter(State.HURT)


func _die() -> void:
	_enter(State.DEAD)
	Skills.add("combat", 30 if shadow else 10)
	if randf() < (0.25 if shadow else 0.08):                       # now and then it was carrying a tool
		var found := Gear.roll_found()
		TOOL_DROP.spawn(get_parent(), found[0], found[1], global_position, player)
	collision_layer = 0
	get_tree().create_timer(0.35).timeout.connect(func() -> void: _play("thud", 1.5))
	var items: Array[String] = ["shadow_pelt"] if shadow else ["pelt"]
	if randf() < (0.6 if shadow else 0.3):
		items.append("fang")
	for item in items:
		var drop := Node3D.new()
		drop.set_script(DROP)
		get_parent().add_child(drop)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(1.0, 2.0)
		drop.launch(item, global_position + Vector3(0, 0.7, 0), dir + Vector3(0, randf_range(3.5, 5.0), 0), global_position.y, player)
	var gone := create_tween()
	gone.tween_interval(2.5)
	gone.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.5)
	gone.tween_callback(func() -> void: visible = false)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_respawn)


func _respawn() -> void:
	global_position = home + Vector3(0, 0.5, 0)
	health = max_health
	collision_layer = 1
	visual.reset()
	visible = true
	visual.scale = Vector3.ONE * 0.01
	create_tween().tween_property(visual, "scale", Vector3.ONE * _size(), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_enter(State.WANDER)


func _size() -> float:
	return 1.3 if shadow else 1.0


func _give_up() -> void:
	_goal = home
	_enter(State.WANDER)


func _enter(new_state: State) -> void:
	state = new_state
	_t = 0.0
	visual.crouch = new_state == State.WINDUP
	if new_state == State.CIRCLE:
		_circle_time = randf_range(1.2, 2.6)
	visual.mode = {State.ALERT: "alert", State.CIRCLE: "stalk", State.WINDUP: "alert", State.LUNGE: "charge",
		State.HURT: "hurt", State.DEAD: "dead"}.get(new_state, "walk")
	if new_state == State.ALERT:
		_play("growl", randf_range(0.9, 1.1))


func _home_distance() -> float:
	return Vector2(global_position.x - home.x, global_position.z - home.z).length()


func _face(dir: Vector3, weight: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(weight, 0.0, 1.0))


func _play(sound: String, pitch: float) -> void:
	_audio.stream = SOUNDS[sound]
	_audio.pitch_scale = pitch
	_audio.play()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
