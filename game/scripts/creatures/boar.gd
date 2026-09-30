class_name Boar
extends CharacterBody3D
## The boar: wanders near its home; when the player comes close it snorts, then lowers its head and
## paws the ground glowing red-hot (the warning), sometimes holding it a while, locks its aim with a
## bright glint and a "ting" (always the same beat before it goes), and charges. Up close it tosses its
## tusks instead (a short tell). It can't be knocked out of a wind-up or charge (only a heavy blow
## staggers it); a charge that misses leaves it skidding, one into a tree or wall leaves it dazed (the
## openings). Wounded, it may charge again straight away. Hit it too many times in a row and it braces
## and counters. Dies with a squeal into a body you carve or haul (carcass.gd), and comes back later.
## Numbers: Balance.BOAR and Balance.FIGHT.

const WALK_SPEED := 1.3
const CHARGE_SPEED := 7.5
const SIGHT := 10.0
const HOME_RADIUS := 9.0
const MAX_HEALTH := 10         # the real value comes from Balance.BOAR (set in _ready)

const GRAVITY := 20.0
const LEASH := 20.0            # chases no further than this from home, then gives up
const REGEN_EVERY := 3.0       # heals 1 while calm
const WINDUP := 0.65           # seconds of warning before a charge (plus a random hold)
const AIM_LOCK := 0.55         # after this part of the wind-up it stops turning (and glints): sidestep now
const QUICK_WINDUP := 0.45     # the second charge of a wounded boar
const SWIPE_TELL := 0.42       # the tusk toss: warning, then the strike
const COUNTER_TELL := 0.32     # ... when it braces against a flurry of hits
const SWIPE_STRIKE := 0.22     # how long the toss itself lasts
const SOUNDS := {
	"snort": preload("res://assets/sounds/boar_snort.wav"),
	"squeal": preload("res://assets/sounds/boar_squeal.wav"),
	"thud": preload("res://assets/sounds/tree_thud.wav"),
}
const DROP := preload("res://scripts/world/drop.gd")
const TOOL_DROP := preload("res://scripts/world/tool_drop.gd")
const CARCASS := preload("res://scripts/world/carcass.gd")

enum State { WANDER, ALERT, WINDUP, CHARGE, RECOVER, SWIPE, DAZED, HURT, DEAD }

var player: Node3D
var home := Vector3.ZERO
var max_health := MAX_HEALTH
var _damage := 1
var health := MAX_HEALTH
var state := State.WANDER

var _t := 0.0                 # time in the current state
var _goal := Vector3.ZERO
var _idle := 0.0
var _charge_dir := Vector3.FORWARD
var _push := Vector3.ZERO
var _regen := 0.0
var _hurt_time := 0.35        # longer after a heavy blow
var _windup := WINDUP         # this wind-up's length (with its hold)
var _swipe_tell := SWIPE_TELL
var _swiped := false
var _recharged := false       # a wounded boar charges again once, then rests
var _poise := 0.0             # recent light hits; too many and it braces
var _recover := 1.0
var _daze_for := 0.0          # how long this daze lasts
var _audio: AudioStreamPlayer3D
@onready var visual: BoarVisual = $Visual


func _ready() -> void:
	add_to_group("enemy")
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 8.0
	add_child(_audio)
	_goal = global_position
	var tough: Dictionary = Balance.REGION_TOUGHNESS.get(Region.current, {"hp": 1.0, "damage": 0})
	max_health = roundi(Balance.BOAR["hp"] * tough["hp"])
	health = max_health
	_damage = Balance.BOAR["damage"] + tough["damage"]


## True while it has noticed you and is fighting (the music switches to the fight tune).
func is_engaged() -> bool:
	return state != State.WANDER and state != State.DEAD


## Fire damage (a Pyromancer's flames): no stagger, just health.
func take_burn(damage: int) -> void:
	if state == State.DEAD:
		return
	health -= damage
	visual.flash()
	visual.show_health(float(health) / max_health, max_health / 2)
	FloatText.spawn(get_tree(), global_position + Vector3(0, 1.2, 0), str(damage), Color(1.0, 0.55, 0.2))
	if health <= 0:
		_die()


## A parry knocked it off balance: dazed and open (double damage) for a while.
func parried(seconds: float) -> void:
	_daze_for = seconds
	_push = -Vector3(sin(rotation.y), 0, cos(rotation.y)) * 4.0
	_play("thud", 1.3)
	_enter(State.DAZED)


func is_open() -> bool:
	return state == State.DAZED


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
			if health < max_health:
				_regen += delta
				if _regen >= REGEN_EVERY:
					_regen = 0.0
					health += 1
			var home_dist := Vector2(global_position.x - home.x, global_position.z - home.z).length()
			if dist < SIGHT and absf(player.global_position.y - global_position.y) < 6.0 and player.can_be_targeted() and home_dist < LEASH:
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
			if player.is_down() or _home_distance() > LEASH:
				_goal = home
				_enter(State.WANDER)
			elif _t > 0.35:
				if dist < Balance.FIGHT["swipe_reach"] and _in_front(to_player):
					_start_swipe(SWIPE_TELL)
				else:
					_start_windup(WINDUP + (randf_range(0.1, Balance.FIGHT["hold_max"]) if randf() < 0.6 else 0.0))
		State.WINDUP:
			# It aims until the glint, then holds its line: the glint always comes the same beat before the charge.
			var lock := _windup - WINDUP * (1.0 - AIM_LOCK)
			if _t < lock:
				_face(to_player, delta * 5.0)
				_charge_dir = to_player.normalized()
				if _t + delta >= lock:
					rotation.y = atan2(_charge_dir.x, _charge_dir.z)     # square on to you as the aim locks
					visual.glint()
			visual.tell = clampf(_t / _windup, 0.0, 1.0)
			if player.is_down() or _home_distance() > LEASH:
				_goal = home
				_enter(State.WANDER)
			elif _t > _windup:
				_enter(State.CHARGE)
		State.CHARGE:
			want = _charge_dir * CHARGE_SPEED
			var result := ""
			if dist < 1.3 and not _swiped:          # one try per charge; a dodged charge thunders on past
				_swiped = true
				result = player.receive_attack(self, _damage, _charge_dir * 9.0)
			if result == "parry":
				pass
			elif result == "hit" or result == "block":
				get_tree().call_group("camera_rig", "shake", 0.12)
				_recover = 1.1
				_enter(State.RECOVER)
			elif _t > 0.2 and is_on_wall():            # ran into a tree or a wall: dazed, a long opening
				_play("thud", 0.8)
				get_tree().call_group("camera_rig", "shake", 0.06)
				_daze_for = Balance.FIGHT["boar_daze"]
				_enter(State.DAZED)
			elif _t > 1.5:
				if health * 2 < max_health and not _recharged and randf() < Balance.FIGHT["boar_recharge"]:
					_recharged = true              # wounded and furious: skids round and goes again
					_start_windup(QUICK_WINDUP)
				else:
					_recover = 1.0
					_enter(State.RECOVER)
		State.RECOVER:
			if _t > _recover:
				_enter(State.ALERT if dist < SIGHT else State.WANDER)
		State.SWIPE:
			# A short tell (it tracks you until the glint), then a toss of the tusks at whatever is in front.
			if _t < _swipe_tell * AIM_LOCK:
				_face(to_player, delta * 8.0)
				if _t + delta >= _swipe_tell * AIM_LOCK:
					visual.glint()
			if _t < _swipe_tell:
				visual.tell = clampf(_t / _swipe_tell, 0.0, 1.0)
			else:
				if visual.mode != "swipe":
					visual.tell = 0.0
					visual.mode = "swipe"
					_push = Vector3(sin(rotation.y), 0, cos(rotation.y)) * 3.0     # a lurch forward
					_play("snort", 1.3)
				if not _swiped and dist < Balance.FIGHT["swipe_reach"] + 0.3 and _in_front(to_player):
					_swiped = true
					var result: String = player.receive_attack(self, maxi(1, _damage - 1), to_player.normalized() * 6.0)
					if result == "hit" or result == "block":
						get_tree().call_group("camera_rig", "shake", 0.08)
				if state == State.SWIPE and _t > _swipe_tell + SWIPE_STRIKE:
					_recover = 0.8
					_enter(State.RECOVER)
		State.DAZED:
			if _t > _daze_for:
				_enter(State.ALERT if dist < SIGHT else State.WANDER)
		State.HURT:
			if _t > _hurt_time:
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
	_poise = maxf(_poise - delta / Balance.FIGHT["poise_decay"], 0.0)
	if want.length() > 0.1 and state != State.ALERT and state != State.WINDUP and state != State.SWIPE:
		_face(want, delta * (10.0 if state == State.CHARGE else 4.0))
	visual.speed = Vector2(velocity.x, velocity.z).length()


## The action: the player hits the boar.
func take_hit(from: Vector3, damage := 1, push := 1.0) -> void:
	if state == State.DEAD:
		return
	health -= damage
	visual.flash()
	visual.show_health(float(health) / max_health, max_health / 2)
	var away := global_position - from
	away.y = 0.0
	_play("squeal", randf_range(0.95, 1.15))
	if health <= 0:
		_die()
		return
	if push > 1.0:                                 # a heavy blow always staggers it and calms the flurry
		_poise = 0.0
		_push = away.normalized() * 4.0 * push
		_hurt_time = 1.2
		_enter(State.HURT)
		return
	_poise += 1.0
	if state in [State.WINDUP, State.CHARGE, State.SWIPE, State.DAZED]:
		return                                     # committed (it shrugs the hit off), or dazed (free hits)
	_push = away.normalized() * 2.5
	if _poise >= Balance.FIGHT["boar_poise"]:      # too many hits in a row: it braces and counters
		_poise = 0.0
		get_tree().call_group("hud", "hint", "It braced! Back off")
		_start_swipe(COUNTER_TELL)
	else:
		_hurt_time = 0.35
		_enter(State.HURT)


func _die() -> void:
	_enter(State.DEAD)
	Skills.add("combat", Balance.BOAR["xp"])
	if randf() < Balance.BOAR["tool"]:                       # now and then it was carrying a tool
		var found := Gear.roll_found("enemy")
		TOOL_DROP.spawn(get_parent(), found[0], found[1], global_position, player)
	collision_layer = 0
	get_tree().create_timer(0.35).timeout.connect(func() -> void: _play("thud", 1.2))
	# The body stays (world/carcass.gd): carve it or take it whole. The living boar hides until it respawns.
	visible = false
	CARCASS.spawn(get_parent(), "boar", global_position, rotation.y, player)
	get_tree().create_timer(Balance.BOAR["respawn"]).timeout.connect(_respawn)


func _start_windup(length: float) -> void:
	_windup = length
	_enter(State.WINDUP)


func _start_swipe(tell: float) -> void:
	_swipe_tell = tell
	_swiped = false
	_enter(State.SWIPE)


func _in_front(to_player: Vector3) -> bool:
	return Vector3(sin(rotation.y), 0, cos(rotation.y)).dot(to_player.normalized()) > 0.35


func _home_distance() -> float:
	return Vector2(global_position.x - home.x, global_position.z - home.z).length()


func _respawn() -> void:
	global_position = home + Vector3(0, 0.5, 0)
	health = max_health
	collision_layer = 1
	visual.reset()
	visible = true
	visual.scale = Vector3.ONE * 0.01
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_enter(State.WANDER)


func _enter(new_state: State) -> void:
	state = new_state
	_t = 0.0
	if new_state != State.WINDUP:
		visual.tell = 0.0
	visual.mode = {State.ALERT: "alert", State.WINDUP: "windup", State.CHARGE: "charge", State.SWIPE: "windup",
		State.DAZED: "dazed", State.HURT: "hurt", State.DEAD: "dead"}.get(new_state, "walk")
	if new_state == State.ALERT:
		_play("snort", randf_range(0.9, 1.1))
	if new_state == State.WANDER:
		_recharged = false
	if new_state == State.CHARGE:
		_swiped = false


func _face(dir: Vector3, weight: float) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(weight, 0.0, 1.0))


func _play(sound: String, pitch: float) -> void:
	_audio.stream = SOUNDS[sound]
	_audio.pitch_scale = pitch
	_audio.play()
