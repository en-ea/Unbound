class_name Wolf
extends CharacterBody3D
## The wolf: roams with its pack. When it spots the player it growls, then circles at a distance,
## spreading out from the others and working round behind you; the wolves beside or behind you strike
## first. It stops and crouches glowing red-hot (the warning, sometimes held), locks its aim with a
## glint and a "ting" (always the same beat before it goes), darts in for a bite, and backs off. Some
## crouches are feints (a hop and a snap at the air, no glint), sometimes a second wolf strikes right
## after the first, a circling wolf may hop away from your swing, and a swing at nothing (or a flurry on
## one wolf) opens you up to the pack. A missed lunge leaves it stumbling: your opening.
## Drops a pelt and sometimes a fang. Numbers: Balance.WOLF and Balance.FIGHT.

const WALK_SPEED := 1.6
const CIRCLE_SPEED := 3.0
const LUNGE_SPEED := 10.0
const CIRCLE_RADIUS := 3.8
const SIGHT := 10.0
const HOME_RADIUS := 8.0
const LEASH := 22.0
const MAX_HEALTH := 6          # the real value comes from Balance (set in _ready)

const GRAVITY := 20.0
const WINDUP := 0.5            # seconds of warning before a lunge (plus a random hold)
const QUICK_WINDUP := 0.35     # taking an opening, or the real strike after a feint
const SPREAD := 2.6            # wolves keep about this far apart while circling
const AIM_LOCK := 0.5          # after this part of the wind-up it stops turning (and glints)
const SOUNDS := {
	"growl": preload("res://assets/sounds/wolf_growl.wav"),
	"yelp": preload("res://assets/sounds/wolf_yelp.wav"),
	"snap": preload("res://assets/sounds/wolf_snap.wav"),
	"thud": preload("res://assets/sounds/tree_thud.wav"),
}
const DROP := preload("res://scripts/world/drop.gd")
const TOOL_DROP := preload("res://scripts/world/tool_drop.gd")
const CARCASS := preload("res://scripts/world/carcass.gd")

enum State { WANDER, ALERT, CIRCLE, WINDUP, LUNGE, FEINT, STUMBLE, RETREAT, DODGE, HURT, DEAD }

static var _lunge_free_at := 0.0     # pack rule: one lunge at a time (a pincer lets the next one go early)
static var _opening_until := 0.0     # the player just swung at nothing: the pack pounces

var player: Node3D
var home := Vector3.ZERO
var shadow := false                 # a shadow wolf: bigger, darker, tougher, rarer loot (set before adding)
var duskmaw := false                # the Duskmaw: what three bodies at night call up (hunt_director.gd)
var _meal: Node3D = null            # a body it smelled and is off to eat (carcass.gd)
var _meal_tick := 0.0
var max_health := MAX_HEALTH
var _damage := 1
var health := MAX_HEALTH
var state := State.WANDER

var _t := 0.0
var _goal := Vector3.ZERO
var _idle := 0.0
var _circle_time := 0.0
var _side := 1.0                    # circling direction
var _lunge_dir := Vector3.FORWARD
var _bit := false
var _tried := false          # this lunge has reached you (hit, blocked, dodged or parried)
var _stumble_for := 0.6      # how long this stumble lasts
var _hurt_time := 0.3         # longer after a heavy blow
var _windup := WINDUP         # this wind-up's length (with its hold)
var _feint := false
var _poise := 0.0             # recent light hits; too many and it leaps away
var _player_visual: Node3D
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
	var stats: Dictionary = _stats()
	var tough: Dictionary = Balance.REGION_TOUGHNESS.get(Region.current, {"hp": 1.0, "damage": 0})
	max_health = roundi(stats["hp"] * tough["hp"])
	health = max_health
	_damage = stats["damage"] + tough["damage"]
	if shadow or duskmaw:
		visual.scale = Vector3.ONE * _size()
		for m in visual._materials:          # dusky violet fur (the Duskmaw: nearly black)
			m.set_shader_parameter("albedo", Color(0.2, 0.17, 0.26) if duskmaw else Color(0.42, 0.38, 0.62))
	if duskmaw:
		add_to_group("boss")
		for c in get_children():             # a bigger body to hit and be hit by
			if c is CollisionShape3D:
				c.scale = Vector3.ONE * _size()


## True while it has noticed you and is fighting (the music switches to the fight tune).
func is_engaged() -> bool:
	return state != State.WANDER and state != State.DEAD


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
	var lost: bool = player.is_down() or _home_distance() > LEASH
	match state:
		State.WANDER:
			if _t > 4.0:
				health = max_health       # calm again: healed
			var to_goal := _goal - global_position
			to_goal.y = 0.0
			_meal_tick -= delta
			if _meal_tick <= 0.0:
				_meal_tick = 1.5
				_meal = preload("res://scripts/studio/creatures/steer_around.gd").reachable(self, _find_meal())   # studio: a meal it cannot reach is given up within 6 s (note 233349)
			var eating: bool = is_instance_valid(_meal) and not _meal.dragged and not _meal.is_queued_for_deletion()
			if dist < SIGHT and absf(player.global_position.y - global_position.y) < 6.0 and player.can_be_targeted() and (_home_distance() < LEASH or eating or duskmaw):
				_enter(State.ALERT)
			elif eating:                  # off to a body, then tearing at it (it rots faster)
				var to_meal := _meal.global_position - global_position
				to_meal.y = 0.0
				if to_meal.length() > 1.3 * _size():
					want = to_meal.normalized() * WALK_SPEED * 1.8
					visual.mode = "walk"
				else:
					_meal.nibble(delta * 2.0)
					face = to_meal
					visual.mode = "eat"
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
			# Lope around the player (facing where it runs), drifting in or out to hold the distance, keeping
			# apart from the pack, and circling the way that brings it round behind the player.
			var in_view := _in_view(toward)
			if in_view > 0.5:
				_side = _flank_side(toward)
			var around := toward.cross(Vector3.UP) * _side
			want = (around + toward * clampf((dist - CIRCLE_RADIUS) * 0.6, -1.0, 1.0) + _spread() * 0.9).normalized() * CIRCLE_SPEED
			var free := _now() >= _lunge_free_at and dist < CIRCLE_RADIUS + 2.5
			if lost:
				_give_up()
			elif free and _now() < _opening_until:     # you swung at nothing: pounce
				_start_windup(QUICK_WINDUP, false)
			elif free and _t > _circle_time and (in_view < 0.3 or _t > _circle_time + 2.0):
				_start_windup(WINDUP + (randf_range(0.1, Balance.FIGHT["hold_max"]) if randf() < 0.5 else 0.0),
					randf() < Balance.FIGHT["wolf_feint"])
			elif is_on_wall():
				_side = -_side
		State.WINDUP:
			var lock := _windup - WINDUP * (1.0 - AIM_LOCK)
			if _t < lock:                   # stops dead and crouches: the tell
				face = toward
				_lunge_dir = toward
				if _t + delta >= lock:
					rotation.y = atan2(toward.x, toward.z)     # square on to you as the aim locks
				if _t + delta >= lock and not _feint:
					visual.glint()          # a feint never glints
			visual.tell = clampf(_t / _windup, 0.0, 1.0)
			if lost:
				_give_up()
			elif _t > _windup:
				_bit = false
				_tried = false
				_stumble_for = Balance.FIGHT["wolf_stumble"]
				if _feint:
					_play("snap", randf_range(1.1, 1.25))
					_enter(State.FEINT)
				else:
					if randf() < Balance.FIGHT["wolf_pincer"]:
						_lunge_free_at = _now()      # a packmate may strike right behind this one
					_enter(State.LUNGE)
		State.FEINT:
			# A hop that stops short and a snap at the air; then often the real strike, quickly.
			if _t < 0.18 and dist > 2.2:
				want = _lunge_dir * 5.5
			face = toward
			if _t > 0.4:
				if randf() < 0.5:
					_start_windup(QUICK_WINDUP, false)
				else:
					_enter(State.CIRCLE)
		State.LUNGE:
			want = _lunge_dir * LUNGE_SPEED
			if not _tried and dist < 1.1:
				_tried = true
				_play("snap", randf_range(0.95, 1.1))
				var result: String = player.receive_attack(self, _damage, _lunge_dir * 5.0)
				_bit = result == "hit" or result == "block"
				if _bit:
					get_tree().call_group("camera_rig", "shake", 0.08)
			if state == State.LUNGE and (_t > 0.4 or (_t > 0.1 and is_on_wall())):
				_enter(State.RETREAT if _bit else State.STUMBLE)       # dodged or missed: it stumbles, open
		State.STUMBLE:
			if _t > _stumble_for:     # missed: it skids and stumbles, open to a counter
				_enter(State.RETREAT)
		State.DODGE:
			face = toward
			want = -toward * 5.0
			if _t > 0.4:
				_enter(State.CIRCLE)
		State.RETREAT:
			face = toward
			want = -toward * 3.5
			if _t > 0.8:
				_side = -_side if randf() < 0.4 else _side
				_enter(State.CIRCLE)
		State.HURT:
			if _t > _hurt_time:
				_enter(State.RETREAT)
		State.DEAD:
			pass
	_poise = maxf(_poise - delta / Balance.FIGHT["poise_decay"], 0.0)
	want = preload("res://scripts/studio/creatures/steer_around.gd").steer(self, want, delta, state in [State.LUNGE, State.FEINT])   # studio: round structures, never in a strike (note 233349)
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
func take_hit(from: Vector3, damage := 1, push := 1.0) -> void:
	if state == State.DEAD:
		return
	health -= damage
	visual.flash()
	visual.show_health(float(health) / max_health, max_health / 2)
	var away := global_position - from
	away.y = 0.0
	_push = away.normalized() * 5.0 * push
	_hurt_time = 0.3 if push <= 1.0 else 1.0
	_play("yelp", randf_range(0.95, 1.12))
	if health <= 0:
		_die()
		return
	_poise = 0.0 if push > 1.0 else _poise + 1.0
	if _poise >= Balance.FIGHT["wolf_poise"]:      # a flurry on one wolf: it leaps clear, the pack pounces
		_poise = 0.0
		_dodge()
	else:
		_enter(State.HURT)


## The player starts a swing at this wolf: while it is only circling, it may hop out of reach.
func sense_swing() -> void:
	if state in [State.CIRCLE, State.ALERT, State.RETREAT] and randf() < Balance.FIGHT["wolf_dodge"]:
		_dodge()


## True while it is hopping clear (a swing started at it misses).
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


## A parry sent it sprawling: it stumbles, open (double damage), for a while.
func parried(seconds: float) -> void:
	_stumble_for = seconds
	_push = -_lunge_dir * 4.0
	_play("yelp", 1.2)
	_enter(State.STUMBLE)


func is_open() -> bool:
	return state == State.STUMBLE


func is_evading() -> bool:
	return state == State.DODGE


## The player swung at nothing: circling wolves get a moment to pounce.
static func open_up() -> void:
	_opening_until = Time.get_ticks_msec() / 1000.0 + 0.6


func _dodge() -> void:
	var away := global_position - player.global_position
	away.y = 0.0
	_push = away.normalized() * 9.0
	_enter(State.DODGE)
	open_up()


func _die() -> void:
	_enter(State.DEAD)
	Bounties.killed("duskmaw" if duskmaw else ("shadow_wolf" if shadow else "wolf"), self)
	var stats: Dictionary = _stats()
	Skills.add("combat", stats["xp"])
	if randf() < stats["tool"]:                       # now and then it was carrying a tool
		var found := Gear.roll_found("elite" if shadow else "enemy")
		TOOL_DROP.spawn(get_parent(), found[0], found[1], global_position, player)
	collision_layer = 0
	get_tree().create_timer(0.35).timeout.connect(func() -> void: _play("thud", 1.5))
	visible = false                                   # the body stays (world/carcass.gd)
	CARCASS.spawn(get_parent(), "duskmaw" if duskmaw else ("shadow_wolf" if shadow else "wolf"), global_position, rotation.y, player)
	if duskmaw:
		_duskmaw_dies()
		return
	get_tree().create_timer(stats["respawn"]).timeout.connect(_respawn)


## The Duskmaw's end: a rare find, and its huge body (only the ox cart can take it). It doesn't come back.
func _duskmaw_dies() -> void:
	var found := Gear.roll_found("elite")
	TOOL_DROP.spawn(get_parent(), found[0], found[1], global_position, player)
	get_tree().call_group("hud", "hint", "The Duskmaw is dead. Its body is too big to drag: fetch the ox cart.")
	get_tree().create_timer(3.0).timeout.connect(queue_free)


func is_awake() -> bool:
	return duskmaw and state != State.DEAD


func _stats() -> Dictionary:
	if duskmaw:
		return {"hp": Balance.DUSKMAW["hp"], "damage": Balance.DUSKMAW["damage"], "xp": Balance.DUSKMAW["xp"], "tool": 1.0, "respawn": 0.0}
	return Balance.SHADOW_WOLF if shadow else Balance.WOLF


## The nearest body it can smell: left long enough (the Duskmaw doesn't wait), not being dragged.
func _find_meal() -> Node3D:
	var best: Node3D = null
	var best_d: float = Balance.HUNT["wolf_smell"]
	for c in get_tree().get_nodes_in_group("carcass"):
		var d := (c as Node3D).global_position.distance_to(global_position)
		if not c.dragged and (duskmaw or c.age > Balance.HUNT["wolves_after"]) and d < best_d:
			best_d = d
			best = c
	return best


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
	return Balance.DUSKMAW["size"] if duskmaw else (1.3 if shadow else 1.0)


func _start_windup(length: float, feint: bool) -> void:
	_windup = length
	_feint = feint
	_lunge_free_at = _now() + 1.1
	_enter(State.WINDUP)


## How much the wolf is in front of the player (1 = right in front of them, -1 = right behind).
func _in_view(toward: Vector3) -> float:
	if _player_visual == null:
		_player_visual = player.get_node_or_null("Visual")
	if _player_visual == null:
		return 0.0
	var facing := Vector3(sin(_player_visual.rotation.y), 0, cos(_player_visual.rotation.y))
	return facing.dot(-toward)


## Which way to circle to get round behind the player.
func _flank_side(toward: Vector3) -> float:
	var facing := Vector3(sin(_player_visual.rotation.y), 0, cos(_player_visual.rotation.y))
	var around := toward.cross(Vector3.UP)
	var d := around.dot(-facing)
	return _side if absf(d) < 0.15 else signf(d)


## A nudge away from packmates that are too close.
func _spread() -> Vector3:
	var push := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not (e is Wolf) or not e.is_alive():
			continue
		var off: Vector3 = global_position - (e as Node3D).global_position
		off.y = 0.0
		var d := off.length()
		if d < SPREAD and d > 0.01:
			push += off / d * (SPREAD - d) / SPREAD
	return push


func _give_up() -> void:
	_goal = home
	_enter(State.WANDER)


func _enter(new_state: State) -> void:
	state = new_state
	_t = 0.0
	if new_state != State.WINDUP:
		visual.tell = 0.0
	visual.crouch = new_state == State.WINDUP
	if new_state == State.CIRCLE:
		_circle_time = randf_range(0.8, 1.8)
	visual.mode = {State.ALERT: "alert", State.CIRCLE: "stalk", State.WINDUP: "alert", State.LUNGE: "charge",
		State.FEINT: "charge", State.STUMBLE: "hurt", State.DODGE: "stalk", State.HURT: "hurt", State.DEAD: "dead"}.get(new_state, "walk")
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
