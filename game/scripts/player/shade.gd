class_name Shade
extends Node
## The Shade's abilities (Classes holds the cooldowns; abilities.gd calls these):
## - Shadow Dance: melt into shadow and flash from foe to foe, a cut from a new side each time; the last
##   cut is the hardest. Untouchable while it lasts.
## - Mirage: a double of you, made of shadow, steps out where you stand while you slip back. Enemies near
##   it go for it; it fights them; when it's hit enough or its time runs out it bursts in shadow.
## - Switch: trade places with your double, shadow bursting at both ends. With no double out, you burst
##   and vanish instead: enemies lose you for a moment.
## Passive (Unseen): hits from behind land harder, you move quieter, and your roll is a slip through shadow.

const DANCE_REACH := 9.0
const DANCE_CUTS := 4
const DANCE_GAP := 0.17
const DANCE_POWER := 1.3
const DANCE_SWINGS := ["Sword_Regular_A", "Sword_Regular_B"]
const BEHIND_MULT := 1.5
const DOUBLE_SECS := 8.0
const DOUBLE_HITS := 3
const FOOL_RADIUS := 7.0
const SWITCH_RADIUS := 2.8
const SWITCH_POWER := 1.5
const VANISH_SECS := 1.5
const SOUNDS := {"step": preload("res://assets/sounds/perfect_dodge.wav"), "burst": preload("res://assets/sounds/sneak_kill.wav"),
	"swish": preload("res://assets/sounds/swing.wav")}

@onready var player: CharacterBody3D = get_parent().get_parent()

var _pool: Array[ShadowDouble] = []
var dancing := false
var _hidden_until := 0.0
var _audio: AudioStreamPlayer


func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	add_child(_audio)


## Doubles are built ahead of time while you're a Shade (building one mid-fight would stutter).
func _process(_delta: float) -> void:
	if Classes.current == "shade" and _pool.size() < 2 and player.is_inside_tree() and player.get_parent().is_node_ready():
		var d := ShadowDouble.new()
		d.real = player
		player.get_parent().add_child(d)
		_pool.append(d)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func fool_radius() -> float:
	return FOOL_RADIUS * (2.0 if Classes.has_talent("perfect_likeness") else 1.0)


## Enemies can't find you right after a Switch with no double out.
func hidden() -> bool:
	return _now() < _hidden_until


# --- Shadow Dance ----------------------------------------------------------------------------------

## The enemies the dance will cut, nearest first (empty: nobody in reach, and the button does nothing).
func dance_targets() -> Array[Node3D]:
	var reach := DANCE_REACH * (1.5 if Classes.has_talent("deep_step") else 1.0)
	var foes: Array[Node3D] = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_alive() and (e as Node3D).global_position.distance_to(player.global_position) < reach:
			foes.append(e)
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	return foes


## You melt into shadow and flash from foe to foe, cutting each from a new side (one foe alone gets
## every cut), untouchable the whole time, then step out behind the last.
func shadow_dance() -> void:
	var foes := dance_targets()
	var cuts := DANCE_CUTS + (1 if Classes.has_talent("deep_step") else 0)
	dancing = true
	player.hold_still(cuts * DANCE_GAP + 0.25)
	player.visual.set_shadow(true)
	ShadowFX.puff(player.get_parent(), player.global_position + Vector3(0, 0.9, 0), 1.0)
	_play("step", 0.6, -4.0)
	var spin := randf() * TAU
	for k in cuts:
		foes = foes.filter(func(e: Node3D) -> bool: return is_instance_valid(e) and e.is_alive())
		if foes.is_empty():
			break
		var foe: Node3D = foes[k % foes.size()]
		var from := player.global_position
		var a := spin + k * 2.4                              # a new side each cut
		var dest := foe.global_position + Vector3(cos(a), 0, sin(a)) * 1.4
		dest = ground_at(_clear(foe.global_position, dest))
		ShadowFX.streak(player.get_parent(), from + Vector3(0, 1.0, 0), dest + Vector3(0, 1.0, 0))
		player.global_position = dest
		player.velocity = Vector3.ZERO
		var to := foe.global_position - dest
		player.visual.rotation.y = atan2(to.x, to.z)
		player.visual.play_action(DANCE_SWINGS[k % 2], 2.2)
		var last := k == cuts - 1
		var power := DANCE_POWER * ((3.0 if Classes.has_talent("assassin") else 1.8) if last else 1.0)
		var dmg: int = Gear.hit_damage(power)[0]
		foe.take_hit(dest, dmg, 1.6 if last else 0.6)
		FloatText.spawn(get_tree(), foe.global_position + Vector3(0, 2.0, 0), str(dmg), Color(0.88, 0.8, 1.0), last)
		ShadowFX.puff(player.get_parent(), foe.global_position + Vector3(0, 1.0, 0), 0.45)
		_play("swish", 1.1 + k * 0.08, -3.0)
		get_tree().call_group("camera_rig", "shake", 0.06 if not last else 0.14)
		await get_tree().create_timer(DANCE_GAP).timeout
	player.visual.set_shadow(false)
	ShadowFX.puff(player.get_parent(), player.global_position + Vector3(0, 0.9, 0), 0.8)
	_play("burst", 1.0, -6.0)
	dancing = false


## The Shade's roll: you dissolve into shadow and slip along, not tumble (player.gd's roll).
func shadow_roll(time: float) -> void:
	player.visual.set_shadow(true)
	ShadowFX.puff(player.get_parent(), player.global_position + Vector3(0, 0.9, 0), 0.6)
	ShadowFX.trail(player, Vector3(0, 0.9, 0), time)
	_play("step", 0.75, -8.0)
	await get_tree().create_timer(time).timeout
	player.visual.set_shadow(false)
	ShadowFX.puff(player.get_parent(), player.global_position + Vector3(0, 0.9, 0), 0.5)


## The ground under a spot (so a blink never leaves you inside a slope, or on someone's head).
func ground_at(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 2.0, 0), at - Vector3(0, 4.0, 0))
	var skip: Array[RID] = [player.get_rid()]
	q.collision_mask = 1
	for _try in 4:
		q.exclude = skip
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			break
		if hit["collider"] is CharacterBody3D:        # an enemy, the double: look past it
			skip.append(hit["rid"])
			continue
		return (hit["position"] as Vector3) + Vector3(0, 0.05, 0)
	return at + Vector3(0, 0.15, 0)


## Stops short of walls: the blink can't put you inside rock.
func _clear(from: Vector3, to: Vector3) -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 1.0, 0), to + Vector3(0, 1.0, 0))
	q.exclude = [player.get_rid()]
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return to
	var back: Vector3 = (to - from).normalized() * 0.5
	return Vector3(hit["position"].x, to.y, hit["position"].z) - back


static func _facing(n: Node3D) -> Vector3:
	return Vector3(sin(n.rotation.y), 0, cos(n.rotation.y))


## Your blow's damage, Shade-style: more from behind (the passive).
## `hit` is [damage, critical].
static func strike(enemy: Node, hit: Array, from: Node3D) -> Array:
	if Classes.current != "shade":
		return hit
	if _behind(enemy, from):
		var mult := 1.75 if Classes.has_talent("knife_work") else BEHIND_MULT
		return [maxi(1, roundi(hit[0] * mult)), hit[1]]
	return hit


static func _behind(enemy: Node, from: Node3D) -> bool:
	var v: Variant = enemy.get("visual")
	var body: Node3D = v if v is Node3D else enemy as Node3D
	var to_you := from.global_position - (enemy as Node3D).global_position
	to_you.y = 0.0
	return to_you.length() > 0.1 and _facing(body).dot(to_you.normalized()) < -0.3


# --- Mirage ----------------------------------------------------------------------------------------

func mirage() -> void:
	var count := 2 if Classes.has_talent("twin_mirage") else 1
	var face := _facing(player.visual)
	var side := face.cross(Vector3.UP)
	var secs := DOUBLE_SECS * (1.5 if Classes.has_talent("lingering") else 1.0)
	var hits := DOUBLE_HITS + (2 if Classes.has_talent("lingering") else 0)
	var perfect := Classes.has_talent("perfect_likeness")
	var placed := 0
	for d in _pool:
		if placed >= count:
			break
		if d.active:
			d.end()
		var at := player.global_position + (side * (1.4 if placed == 0 else -1.4) if count == 2 else Vector3.ZERO)
		d.appear(at, player.visual.rotation.y, secs, hits, perfect)
		d.taunt(fool_radius())
		placed += 1
	if placed == 0:
		get_tree().call_group("hud", "hint", "Your shadow is still gathering…")
		return
	player.dash(-face, 9.0, 0.22)                       # you slip back out of it
	_play("swish", 0.7, -2.0)


# --- Switch ----------------------------------------------------------------------------------------

func switch() -> void:
	var radius := SWITCH_RADIUS * (1.35 if Classes.has_talent("wide_burst") else 1.0)
	var double: ShadowDouble = null
	var best := INF
	for d in _pool:
		var dist: float = d.global_position.distance_to(player.global_position)
		if d.active and dist < best:
			best = dist
			double = d
	var here := player.global_position
	if double == null:                                  # no double: burst and vanish
		_burst(here, radius)
		_hidden_until = _now() + VANISH_SECS
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.get("player") == player and e.has_method("lose_target"):
				e.lose_target()
		return
	var there := ground_at(double.global_position)
	player.global_position = there
	player.velocity = Vector3.ZERO
	double.global_position = here
	_burst(here, radius)
	_burst(there, radius)
	get_tree().call_group("camera_rig", "snap")


func _burst(at: Vector3, radius: float) -> void:
	ShadowFX.burst(player.get_parent(), at, radius)
	var power := SWITCH_POWER * (2.0 if Classes.has_talent("nightfall") else 1.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_alive() and (e as Node3D).global_position.distance_to(at) < radius:
			e.take_hit(at, Gear.hit_damage(power)[0], 1.8)
	_play("burst", 0.8, -3.0)
	get_tree().call_group("camera_rig", "shake", 0.1)


func _play(id: String, pitch: float, db: float) -> void:
	_audio.stream = SOUNDS[id]
	_audio.pitch_scale = pitch
	_audio.volume_db = db
	_audio.play()
