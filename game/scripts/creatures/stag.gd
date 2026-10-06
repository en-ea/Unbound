class_name Stag
extends CharacterBody3D
## The stag: prey. It grazes and wanders near its herd's home, and it sees and hears you coming: walk up
## and it lifts its head, listens, then the whole herd bolts. Sneak (slow and quiet) and you can get close.
## Hurt it up close and it may lower its antlers and charge (a glint first) before it runs. Dies into a
## body that stays (world/carcass.gd): carve it, or take it whole to the butcher. Numbers: Balance.STAG.

enum State { GRAZE, WALK, LISTEN, FLEE, WINDUP, CHARGE, HURT, DEAD }

const WALK_SPEED := 1.1
const CHARGE_SPEED := 9.0
const HOME_RADIUS := 11.0
const GRAVITY := 20.0
const WINDUP := 0.6
const LISTEN_FOR := 0.9        # head up this long before it decides
const FLEE_FOR := 5.0
const CARCASS := preload("res://scripts/world/carcass.gd")

var player: Node3D
var home := Vector3.ZERO
var visual: StagVisual
var max_health := 24
var health := 24
var state := State.GRAZE
var _t := 0.0
var _goal := Vector3.ZERO
var _graze_for := 4.0
var _flee_dir := Vector3.FORWARD
var _charge_dir := Vector3.FORWARD
var _charged := false
var _hit_done := false
var _push := Vector3.ZERO
var _sense := 0.0
## Taming (Highlands elk, while you have no elk): sneak up while it grazes (crouched, you're only seen moving
## close by); if it lifts its head to listen, freeze and it goes back to grazing. Close enough, Calm it,
## then hold still.
var verb := ""
var reach := 4.5
var _calming := 0.0
var _moved_while_listening := 0.0
const CALM_TIME := 2.6
const FREEZE_GRACE := 0.35      # a listening elk forgives this much moving (the moment you notice it)
static var _hinted := 0             # 1: told how to sneak up; 2: told about Calm
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("stag")
	add_to_group("interactable")
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.4, 1.5)
	shape.shape = box
	shape.position.y = 0.95
	add_child(shape)
	visual = StagVisual.new()
	add_child(visual)
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 8.0
	_audio.stream = preload("res://assets/sounds/boar_snort.wav")
	add_child(_audio)
	max_health = Balance.STAG["hp"]
	health = max_health
	_goal = global_position
	_graze_for = randf_range(2.0, 6.0)
	_enter(State.GRAZE)


func is_alive() -> bool:
	return state != State.DEAD


## Only a cornered, angry stag counts as a fight (the music).
func is_engaged() -> bool:
	return state == State.WINDUP or state == State.CHARGE


func is_open() -> bool:
	return state == State.HURT


func parried(seconds: float) -> void:
	_push = -Vector3(sin(rotation.y), 0, cos(rotation.y)) * 4.0
	_enter(State.HURT)
	_t = -seconds


## Scared off (by you, or by the herd bolting).
func spook(from: Vector3) -> void:
	if state in [State.DEAD, State.FLEE, State.WINDUP, State.CHARGE]:
		return
	var away := global_position - from
	away.y = 0.0
	if _home_distance() > 30.0:                  # far from home: run back towards it
		away = away.normalized() + (home - global_position).normalized()
	_flee_dir = away.normalized()
	_enter(State.FLEE)
	_audio.pitch_scale = randf_range(1.3, 1.5)
	_audio.play()
	for s in get_tree().get_nodes_in_group("stag"):   # the herd goes too
		if s != self and s.is_alive() and (s as Node3D).global_position.distance_to(global_position) < 16.0:
			s.call_deferred("spook", from)


func take_hit(from: Vector3, damage := 1, push := 1.0) -> void:
	if state == State.DEAD:
		return
	health -= damage
	visual.flash()
	visual.show_health(float(health) / max_health, max_health / 2)
	if health <= 0:
		_die()
		return
	var away := global_position - from
	away.y = 0.0
	_push = away.normalized() * 2.0 * push
	var dist := global_position.distance_to(player.global_position)
	if not _charged and dist < 6.0 and randf() < 0.5:     # turns on you: antlers down
		_charged = true
		_enter(State.WINDUP)
	elif state not in [State.WINDUP, State.CHARGE]:
		state = State.GRAZE                         # (so spook() runs)
		spook(player.global_position)


func take_burn(damage: int) -> void:
	if state == State.DEAD:
		return
	health -= damage
	visual.flash()
	FloatText.spawn(get_tree(), global_position + Vector3(0, 1.8, 0), str(damage), Color(1.0, 0.55, 0.2))
	if health <= 0:
		_die()
	elif state in [State.GRAZE, State.WALK, State.LISTEN]:
		spook(player.global_position)


func _physics_process(delta: float) -> void:
	_t += delta
	if _calming > 0.0:
		_calm(delta)
		return
	var tameable: bool = Region.current == "highlands" and Hunting.elk.is_empty()
	verb = "Calm" if tameable and player.get("sneaking") and state in [State.GRAZE, State.WALK, State.LISTEN] else ""
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if tameable:
		_taming_hints(dist)
	var want := Vector3.ZERO
	_sense -= delta
	var noticed := false
	if _sense <= 0.0 and state in [State.GRAZE, State.WALK, State.LISTEN]:
		_sense = 0.2
		noticed = _notices(dist)
	match state:
		State.GRAZE:
			if noticed:
				_enter(State.LISTEN)
			elif _t > _graze_for:
				var a := randf() * TAU
				_goal = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, HOME_RADIUS)
				_enter(State.WALK)
		State.WALK:
			var to_goal := _goal - global_position
			to_goal.y = 0.0
			if noticed:
				_enter(State.LISTEN)
			elif to_goal.length() > 0.8 and _t < 12.0:
				want = to_goal.normalized() * WALK_SPEED
			else:
				_graze_for = randf_range(3.0, 8.0)
				_enter(State.GRAZE)
		State.LISTEN:
			_face(to_player, delta * 3.0)
			if player.get("sneaking"):
				# Crouched: it's listening for you. Keep still and it settles; creep on and it bolts.
				if _t > FREEZE_GRACE and _player_moving():
					_moved_while_listening += delta
				if _moved_while_listening > 0.25 or dist < 1.4:
					spook(player.global_position)
				elif _t > LISTEN_FOR * 1.6:
					_graze_for = randf_range(2.0, 5.0)
					_enter(State.GRAZE)
			elif _t > LISTEN_FOR:
				if _notices(dist * 1.15):
					spook(player.global_position)
				else:
					_graze_for = randf_range(1.5, 4.0)
					_enter(State.GRAZE)          # nothing there after all
		State.FLEE:
			want = _flee_dir * Balance.STAG["flee_speed"]
			if is_on_wall():                           # a tree in the way: veer
				_flee_dir = _flee_dir.rotated(Vector3.UP, 0.9 * (1.0 if randf() < 0.5 else -1.0))
			if _t > FLEE_FOR and dist > 22.0:
				_goal = home
				_charged = false
				_enter(State.WALK)
		State.WINDUP:
			if _t < WINDUP * 0.6:
				_charge_dir = to_player.normalized()
				_face(to_player, delta * 8.0)
				if _t + delta >= WINDUP * 0.6:
					visual.glint()
			visual.tell = clampf(_t / WINDUP, 0.0, 1.0)
			if _t > WINDUP:
				_hit_done = false
				_enter(State.CHARGE)
		State.CHARGE:
			want = _charge_dir * CHARGE_SPEED
			if dist < 1.6 and not _hit_done:
				_hit_done = true
				var result: String = player.receive_attack(self, Balance.STAG["damage"], _charge_dir * 9.0)
				if result == "hit" or result == "block":
					get_tree().call_group("camera_rig", "shake", 0.12)
			if _t > 0.9 or is_on_wall():
				state = State.GRAZE
				spook(player.global_position)
		State.HURT:
			if _t > 0.6:
				state = State.GRAZE
				spook(player.global_position)
	want = preload("res://scripts/studio/creatures/steer_around.gd").steer(self, want, delta, state == State.CHARGE)   # studio: round structures, never in a charge (note 233349)
	var flat := Vector3(velocity.x, 0, velocity.z)
	var accel := 14.0 if state in [State.CHARGE, State.FLEE] else 5.0
	flat = flat.lerp(want, clampf(accel * delta, 0.0, 1.0)) + _push
	_push = _push.lerp(Vector3.ZERO, clampf(8.0 * delta, 0.0, 1.0))
	velocity = Vector3(flat.x, velocity.y - GRAVITY * delta if not is_on_floor() else 0.0, flat.z)
	if state != State.DEAD:
		move_and_slide()
	if want.length() > 0.1 and state != State.WINDUP:
		_face(want, delta * (10.0 if state in [State.CHARGE, State.FLEE] else 3.0))
	visual.speed = Vector2(velocity.x, velocity.z).length()


## Sees you (all round; sneaking, only when you move close by) or hears you (Player.noise()).
func _notices(dist: float) -> bool:
	if not player.can_be_targeted():
		return false
	var st: Dictionary = Balance.STAG
	if player.sneaking:
		return (dist < st["sight_sneak"] and _player_moving()) or dist < player.noise() * 0.8
	return dist < st["sight"] or dist < player.noise()


func _player_moving() -> bool:
	return Vector2(player.velocity.x, player.velocity.z).length() > 0.4


## The first time you're near a wild elk you could tame: how to do it.
func _taming_hints(dist: float) -> void:
	if _hinted == 0 and dist < 14.0:
		_hinted = 1
		get_tree().call_group("hud", "hint", "A wild elk. Sneak up while it grazes. If it looks up, freeze!")
	elif _hinted == 1 and verb == "Calm" and dist < reach:
		_hinted = 2
		get_tree().call_group("hud", "hint", "Close enough: press Calm, then hold still.")


func _die() -> void:
	_enter(State.DEAD)
	Bounties.killed("stag", self)
	Skills.add("combat", Balance.STAG["xp"])
	collision_layer = 0
	visible = false
	CARCASS.spawn(get_parent(), "stag", global_position, rotation.y, player)
	get_tree().create_timer(Balance.STAG["respawn"]).timeout.connect(_respawn)


func _respawn() -> void:
	global_position = home + Vector3(0, 0.5, 0)
	health = max_health
	collision_layer = 1
	_charged = false
	visual.reset()
	visible = true
	_enter(State.GRAZE)


func _home_distance() -> float:
	return Vector2(global_position.x - home.x, global_position.z - home.z).length()


func _enter(new_state: State) -> void:
	state = new_state
	_t = 0.0
	_moved_while_listening = 0.0
	if new_state != State.WINDUP:
		visual.tell = 0.0
	visual.mode = {State.GRAZE: "graze", State.LISTEN: "listen", State.FLEE: "flee", State.WINDUP: "windup",
		State.CHARGE: "charge", State.HURT: "hurt", State.DEAD: "dead"}.get(new_state, "walk")


func _face(dir: Vector3, weight: float) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(weight, 0.0, 1.0))


## The action (Calm): you hold out a hand. Stay crouched and still while it decides.
func interact() -> void:
	if verb != "Calm":
		return
	_calming = CALM_TIME
	_face(player.global_position - global_position, 1.0)
	visual.mode = "listen"
	get_tree().call_group("hud", "hint", "Easy now... hold still.")


func _calm(delta: float) -> void:
	var d := player.global_position.distance_to(global_position)
	if Controls.get_move().length() > 0.15 or not player.get("sneaking") or d > reach + 1.0 or player.is_down():
		_calming = 0.0
		get_tree().call_group("hud", "hint", "It bolted. Slower next time, and stay low.")
		spook(player.global_position)
		return
	_calming -= delta
	if _calming > 0.0:
		return
	Hunting.elk = {"region": Region.current, "at": Vector2(global_position.x, global_position.z), "yaw": rotation.y}
	var elk := CharacterBody3D.new()
	elk.set_script(preload("res://scripts/world/elk_mount.gd"))
	elk.player = player
	get_parent().get_parent().add_child(elk)
	elk.build(Carcass.shape, Hunting.elk["at"], rotation.y)
	Banner.show_now(get_tree().get_first_node_in_group("hud"), "ELK TAMED", "It's yours. Ride it, or it follows you.",
		Color(0.55, 0.85, 0.9), preload("res://assets/sounds/boar_snort.wav"), 2.4)
	queue_free()
