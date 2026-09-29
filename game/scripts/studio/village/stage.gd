extends Node3D
## The stage (tier E of the living village): plays a staging (staging.gd) live in the meadow village.
## The simulation decides what happens; the stage only shows it. Each person comes out of their door
## when their first beat is due, and the beats run in time order on the stage's own clock:
##
##   stage.play(staging, people, 8.0)    # x8 fast-forward; set_speed() changes it, skip_to(minute) jumps
##
## Beats are when things are *asked for*. A body finishes its walk before it stands or throws, finishes a
## one-shot before it walks off, and stays locked until someone releases it, so a beat can start late but
## is never dropped or reordered (per person). Everything moves on stage time (real time x speed), so a
## run looks the same at any speed; props lying on the ground are the one exception (they linger
## PROP_LINGER real seconds, for the eye).
## Per frame: one pass over the people and the props in flight; no allocations, no node lookups.
## Bodies are made one per frame after play(), in the order they are needed (a CharacterVisual takes
## ~90 ms to make on a PC: twelve at once froze the game for a second); one needed sooner is made at once.

signal finished

const Sites := preload("res://scripts/studio/village/sites.gd")
const Staging := preload("res://scripts/studio/village/staging.gd")
const Houses := preload("res://scripts/world/village.gd")
## Where props come from: the one line to change when the real props (props.gd) arrive. A prop the real
## set lacks still comes from the placeholders.
const Props := preload("res://scripts/studio/village/stage_props.gd")
const Placeholders := preload("res://scripts/studio/village/stage_props.gd")

const SECONDS_PER_MINUTE := 0.5      # a game day is 12 real minutes (staging.gd)
## Gaits a walk can ask for: [pace in m/s, the pace the animation was made for] (the rig's Walk is 0.975).
const GAITS := {"Walk": [1.3, 0.975], "Walk_Formal": [1.05, 0.975], "Walk_Carry": [1.0, 0.975], "Jog_Fwd": [3.0, 4.2]}
const TURN_RATE := 7.0               # radians per stage second
const BODY_RADIUS := 0.35            # how far bodies keep from walls
const CORNER_PAD := 0.3              # detours pass this far outside a wall's corner
const SKIP_STEP := 0.25              # stage seconds per step when skipping ahead
## What a beat plays when it names no animation.
const DEFAULT_ANIM := {"walk_to": "Walk", "leave": "Walk", "carry": "Walk_Carry", "stand": "Idle", "gesture": "Yes",
	"react": "Hit_Chest", "throw": "OverhandThrow", "lock": "Crouch_Idle", "release": "Interact", "fall": "Death01"}

## Places with a device a victim is locked into, and the prop that shows it. Devices face south (+z),
## towards the road and the way the village is usually seen.
const DEVICES := {"pillory": "pillory"}
const DEVICE_FACING := Vector2(0.0, 1.0)
const DEVICE_HALF := Vector2(0.85, 0.12)     # half width across, half depth along the facing (walls to walk round)
const LOCK_BACK := 0.25      # the body kneels this far behind the head hole (Crouch_Idle's head leads its feet by 0.2 m)
const BESIDE := 1.4          # an official (the elder releasing) stands this far to the side of the device
## Where a head is in its body's own space (+z is forward), measured on the hero rig: the Head bone plus
## ~0.12 m to the middle of the head. Thrown props aim here.
const HEAD_STANDING := Vector3(0.0, 1.64, 0.0)
const HEAD_IN_POSE := {"Crouch_Idle": Vector3(0.06, 0.96, 0.22), "Sitting_Idle": Vector3(0.0, 1.1, 0.1)}
## OverhandThrow lets go 0.33 s in, the right hand above and ahead of the shoulder (measured on the rig).
const RELEASE_AT := 0.33
const RELEASE_FROM := Vector3(-0.2, 1.55, 0.3)
const THROW_SPEED := 9.0     # m/s along the arc
## How far each prop carries on after hitting (stones bounce away, mud drops where it hits).
const CARRY_ON := {"stone": 1.2, "mud": 0.2, "cabbage": 0.6, "turnip": 0.8}
const HIT_SPREAD := 0.12     # metres of aim error, so hits don't all land on one point
const PROP_LINGER := 20.0    # real seconds a thrown prop lies on the ground
const MAX_LYING := 48        # past this the oldest prop on the ground goes (keeps a long event's cost flat)
const JOLT := 0.09           # metres a locked victim is knocked by a hit
const JOLT_TIME := 0.25


## A person on the stage: their body and what it is doing.
class Actor:
	var id := 0
	var person := {}
	var body: Node3D                  # null until made (_embody)
	var door := Vector2.ZERO
	var pos := Vector2.ZERO           # on the ground (x, z)
	var y := 0.0
	var yaw := 0.0
	var yaw_goal := 0.0
	var path := PackedVector2Array()  # waypoints still to walk
	var pace := 1.3
	var walk_anim := "Walk"
	var face := Vector2.INF           # what to turn to on arrival
	var rest_anim := "Idle"           # looped when not walking or busy ("" holds the last pose: a fall)
	var playing := ""                 # the loop the body was last told to play, so it isn't restarted
	var loop_left := INF              # stage seconds until a non-looping rest animation replays
	var busy := 0.0                   # stage seconds left of a one-shot (throw, gesture, hit)
	var locked := false
	var going_home := false
	var inside := true                # at home: hidden and not processed
	var pending := PackedInt32Array() # beats (indices) asked for but not started yet
	var freeing: Actor                # the victim this official is releasing
	var free_in := 0.0
	var jolt := 0.0
	var jolt_dir := Vector3.ZERO
	var native_loop := false          # the body loops animations itself (play_loop)


## A thrown prop, from the hand to the head, then to the ground.
class Shot:
	var node: Node3D
	var prop := ""
	var thrower: Actor
	var victim: Actor
	var react := ""                   # the hit animation the victim plays on impact ("" none)
	var wait := 0.0                   # stage seconds until the hand lets go
	var phase := 0                    # 0 in the hand, 1 flying at the head, 2 falling to the ground, 3 lying
	var t := 0.0
	var dur := 1.0
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var arc := 0.0
	var spin := Vector3.ZERO
	var life := 0.0                   # real seconds left on the ground


var _shape := WorldShape.new()
var _beats: Array = []
var _start := 0
var _speed := 1.0
var _clock := 0.0                     # stage seconds since the staging's start
var _next := 0                        # the next beat to hand out
var _actors: Array[Actor] = []
var _unmade: Array[Actor] = []        # bodies still to make, soonest needed first
var _by_id := {}                      # person id -> Actor
var _victim: Actor
var _place := ""
var _focus := Vector2.ZERO
var _device: Node3D
var _device_at := Vector2.ZERO
var _blocks: Array[Rect2] = []        # house footprints (and the device), grown by BODY_RADIUS
var _react_of := {}                   # throw beat index -> its react beat index (played on impact)
var _on_impact := {}                  # react beat indices played by a prop landing, not by the clock
var _shots: Array[Shot] = []          # in the hand or in the air
var _lying: Array[Shot] = []          # on the ground, oldest first
var _anims: AnimationPlayer           # the rig's player, to ask which animations loop by themselves
var _looping := {}
var _released := -1.0                 # stage clock when the victim was freed
var _done := false
var _throws := 0
## Costs and lateness, for the witness: stage _process time, and how late beats started.
var _cost_frames := 0
var _cost_sum := 0
var _cost_max := 0
var _cost_max_at := 0.0               # the game minute of the dearest frame
var _made := 0                        # bodies made, and the time it took (the body's cost, kept apart)
var _made_us := 0
var _made_max_us := 0
var _made_in_frame := 0
var _latest := 0.0
var _latest_beat := -1


func _ready() -> void:
	set_process(false)


## Plays a staging with its people (staging.gd formats). Needs the stage in the tree, at the origin.
func play(staging: Dictionary, people: Array, speed: float = 1.0) -> void:
	for problem in Staging.validate(staging, people):
		push_warning("stage: " + problem)
	clear()
	_beats = staging["beats"]
	_start = int(staging["start"])
	_speed = speed
	_place = staging["place"]
	_focus = Sites.PLACES[_place]["focus"] if Sites.PLACES.has(_place) else Sites.at(_place)
	_build_blocks()
	if DEVICES.has(_place):
		_device_at = Sites.at(_place)
		_device = _make_prop(DEVICES[_place])
		add_child(_device)
		_device.position = Vector3(_device_at.x, _shape.height_at(_device_at.x, _device_at.y), _device_at.y)
		_device.rotation.y = atan2(DEVICE_FACING.x, DEVICE_FACING.y)
	for person: Dictionary in people:
		_add_person(person)
	var victim_id: int = staging["roles"].get("victim", -1)
	_victim = _by_id.get(victim_id)
	_pair_hits()
	_queue_bodies()
	set_process(true)


## Removes every body and prop; the stage can play again.
func clear() -> void:
	for c in get_children():
		c.queue_free()
	_actors.clear()
	_unmade.clear()
	_by_id.clear()
	_shots.clear()
	_lying.clear()
	_react_of.clear()
	_on_impact.clear()
	_device = null
	_victim = null
	_clock = 0.0
	_next = 0
	_released = -1.0
	_done = false
	_throws = 0
	_made = 0
	_made_us = 0
	_made_max_us = 0
	_cost_frames = 0
	_cost_sum = 0
	_cost_max = 0
	_latest = 0.0
	_latest_beat = -1
	set_process(false)


func set_speed(speed: float) -> void:
	_speed = speed
	for a in _actors:
		a.playing = ""               # loops restart at the new rate
		if not a.inside and a.busy <= 0.0:
			if a.path.is_empty():
				_rest(a)
			else:
				_loop(a, a.walk_anim, a.pace / float(GAITS.get(a.walk_anim, GAITS["Walk"])[1]))


## Jumps ahead to a game minute (for tests): the same steps as playing, in big strides, no waiting.
func skip_to(minute: float) -> void:
	var target := (minute - _start) * SECONDS_PER_MINUTE
	while _clock < target:
		_step(minf(SKIP_STEP, target - _clock))


func minute() -> float:
	return _start + _clock / SECONDS_PER_MINUTE


## Where the staging happens, on the ground (x, z).
func place_at() -> Vector2:
	return Sites.at(_place)


func is_finished() -> bool:
	return _done


func is_locked(id: int) -> bool:
	var a: Actor = _by_id.get(id)
	return a != null and a.locked


## The game minute the victim was freed (-1 until then).
func released_minute() -> float:
	return -1.0 if _released < 0.0 else _start + _released / SECONDS_PER_MINUTE


## How far along the furthest prop in flight at a head is (0..1), or -1 when none is.
func flying() -> float:
	var best := -1.0
	for s in _shots:
		if s.phase == 1:
			best = maxf(best, s.t / s.dur)
	return best


## State for probes (programmatic checks instead of pixels): who is out, walking, locked; anyone
## standing inside a house or on top of someone else; props in the air and on the ground.
func probe() -> Dictionary:
	var out := 0
	var walking := 0
	var in_house := PackedStringArray()
	var crowded := PackedStringArray()
	for a in _actors:
		if a.inside:
			continue
		out += 1
		if not a.path.is_empty():
			walking += 1
		for h: Dictionary in Houses.HOUSES:
			var half := Vector2(h["size"].x, h["size"].z) * 0.5
			if Rect2(h["at"] - half, half * 2.0).has_point(a.pos):
				in_house.append(str(a.id))
		for b in _actors:
			if b.id > a.id and not b.inside and a.path.is_empty() and b.path.is_empty() and a.pos.distance_to(b.pos) < 0.5:
				crowded.append("%d+%d" % [a.id, b.id])
	return {"minute": snappedf(minute(), 0.1), "out": out, "walking": walking, "in_house": in_house, "crowded": crowded,
		"flying": _shots.size(), "lying": _lying.size(), "thrown": _throws, "victim_locked": _victim != null and _victim.locked}


## The stage's own cost per frame (microseconds of _process) and the latest any beat started.
func stats() -> Dictionary:
	return {"frames": _cost_frames, "mean_us": roundi(float(_cost_sum) / maxi(_cost_frames, 1)), "max_us": _cost_max,
		"max_at_minute": snappedf(_cost_max_at, 0.1),
		"bodies_made": _made, "make_mean_ms": snappedf(_made_us / 1000.0 / maxi(_made, 1), 0.1), "make_max_ms": snappedf(_made_max_us / 1000.0, 0.1),
		"latest_minutes": snappedf(_latest / SECONDS_PER_MINUTE, 0.1),
		"latest_beat": str(_beats[_latest_beat]) if _latest_beat >= 0 else ""}


func _process(delta: float) -> void:
	_made_in_frame = 0
	if not _unmade.is_empty():
		_embody(_unmade[0])
	var t0 := Time.get_ticks_usec()
	_made_in_frame = 0
	_step(delta * _speed)
	_age_lying(delta)
	var used := Time.get_ticks_usec() - t0 - _made_in_frame   # making a body is the body's cost, not the stage's
	_cost_frames += 1
	_cost_sum += used
	if used > _cost_max:
		_cost_max = used
		_cost_max_at = minute()


## Every body is made here, so a cheaper body can replace CharacterVisual by changing this one function
## (it needs CharacterVisual's play_action / animation_length / flash; play_loop is used when present).
func _make_body(person: Dictionary) -> Node3D:
	var body := CharacterVisual.new()
	var look := CharacterLook.new()
	var outfits: Array = CharacterLook.OUTFITS.keys()
	look.set_outfit(outfits[posmod(int(person.get("outfit", 0)), outfits.size())])
	# Hair and skin vary by person, so neighbours in the same outfit still read as different people.
	var id := int(person.get("id", 0))
	look.set_color("Hair", (id * 3) % CharacterLook.PALETTES["Hair"].size())
	look.set_color("Skin", (id * 2 + 1) % CharacterLook.PALETTES["Skin"].size())
	body.hero_look = look
	body.is_player_look = false
	return body


func _make_prop(prop: String) -> Node3D:
	var source: GDScript = Props
	if not source.has_method(prop):
		source = Placeholders
	return source.call(prop) as Node3D


func _add_person(person: Dictionary) -> void:
	var a := Actor.new()
	a.id = int(person["id"])
	a.person = person
	a.door = Sites.DOORS.get(person.get("home", ""), _focus)
	a.pos = a.door
	a.y = _shape.height_at(a.pos.x, a.pos.y)
	_actors.append(a)
	_by_id[a.id] = a


## Orders the bodies to make by when each person is first needed.
func _queue_bodies() -> void:
	var first := {}
	for b: Dictionary in _beats:
		if not first.has(b["who"]):
			first[b["who"]] = b["at"]
	_unmade = _actors.duplicate()
	_unmade.sort_custom(func(p: Actor, q: Actor) -> bool: return first.get(p.id, 1 << 30) < first.get(q.id, 1 << 30))


## Makes an actor's body (at home: hidden, at the door).
func _embody(a: Actor) -> void:
	var t0 := Time.get_ticks_usec()
	_unmade.erase(a)
	a.body = _make_body(a.person)
	add_child(a.body)
	a.body.position = Vector3(a.pos.x, a.y, a.pos.y)
	a.native_loop = a.body.has_method("play_loop")
	a.inside = true
	a.body.visible = false
	a.body.process_mode = Node.PROCESS_MODE_DISABLED
	if _anims == null and not a.native_loop:
		var players := a.body.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			_anims = players[0]
	var took := Time.get_ticks_usec() - t0
	_made += 1
	_made_us += took
	_made_max_us = maxi(_made_max_us, took)
	_made_in_frame += took


## Pairs each throw with the victim's react beat that answers it, so the hit plays when the prop lands
## rather than on the clock (at x8 a clock minute is shorter than the throw itself).
func _pair_hits() -> void:
	for i in _beats.size():
		var b: Dictionary = _beats[i]
		if b["do"] != "throw":
			continue
		for j in range(i + 1, _beats.size()):
			var r: Dictionary = _beats[j]
			if r["do"] == "react" and r["who"] == b["target"] and r["target"] == b["who"] and not _on_impact.has(j):
				_react_of[i] = j
				_on_impact[j] = true
				break


func _step(dt: float) -> void:
	if dt <= 0.0:
		return
	_clock += dt
	var now := minute()
	while _next < _beats.size() and float(_beats[_next]["at"]) <= now:
		var who: Actor = _by_id.get(_beats[_next]["who"])
		if who != null and not _on_impact.has(_next):
			who.pending.append(_next)
			if who.inside and _beats[_next]["do"] != "leave":
				_hide(who, false)          # out of the door
		_next += 1
	for a in _actors:
		if not a.inside:
			_update(a, dt)
	_fly(dt)
	if not _done and _next >= _beats.size() and _shots.is_empty() and _all_still():
		_done = true
		finished.emit()


func _all_still() -> bool:
	for a in _actors:
		if not a.inside and (not a.pending.is_empty() or not a.path.is_empty() or a.busy > 0.0):
			return false
	return true


func _update(a: Actor, dt: float) -> void:
	if a.busy > 0.0:
		a.busy -= dt
		if a.busy <= 0.0 and a.path.is_empty():
			_rest(a)                      # back to the stand loop after a one-shot
	if a.freeing != null:
		a.free_in -= dt
		if a.free_in <= 0.0:
			_unlock(a.freeing)
			a.freeing = null
	if not a.path.is_empty():
		_walk(a, dt)
	elif a.loop_left != INF and a.busy <= 0.0:
		a.loop_left -= dt
		if a.loop_left <= 0.0:
			a.playing = ""
			_rest(a)
	if a.yaw != a.yaw_goal:
		var diff := angle_difference(a.yaw, a.yaw_goal)
		var turn := TURN_RATE * dt
		a.yaw = a.yaw_goal if absf(diff) <= turn else a.yaw + signf(diff) * turn
		a.body.rotation.y = a.yaw
	if a.jolt > 0.0:
		a.jolt = maxf(a.jolt - dt, 0.0)
		var k := a.jolt / JOLT_TIME
		a.body.position = Vector3(a.pos.x, a.y, a.pos.y) + a.jolt_dir * (k * k)
	while not a.pending.is_empty() and _begin(a, a.pending[0]):
		var late := _clock - (float(_beats[a.pending[0]]["at"]) - _start) * SECONDS_PER_MINUTE
		if late > _latest:
			_latest = late
			_latest_beat = a.pending[0]
		a.pending.remove_at(0)
		if a.inside:
			break


## Starts beat i for an actor; false means "not yet" (still walking, busy, locked) and it is tried again.
func _begin(a: Actor, i: int) -> bool:
	var b: Dictionary = _beats[i]
	var action: String = b["do"]
	var anim: String = b["anim"] if b["anim"] != "" else DEFAULT_ANIM.get(action, "")
	if action == "react":             # a hit lands whatever the body is doing
		_hit(a, anim, _by_id.get(b["target"]))
		return true
	if a.busy > 0.0:
		return false
	match action:
		"walk_to", "carry":
			if a.locked:
				return false
			_go(a, _spot(a, int(b["slot"])), anim, _focus)
			return true
		"leave":
			if a.locked:
				return false
			a.going_home = true
			a.rest_anim = "Idle"
			_go(a, a.door, anim, Vector2.INF)
			return true
		"stand":
			if not _reach(a, _spot(a, int(b["slot"])), _focus):
				return false
			a.rest_anim = anim
			_rest(a)
			return true
		"gesture", "fall":
			if not a.path.is_empty():
				return false
			if action == "fall":
				a.rest_anim = ""           # stays down: the last frame holds
			_once(a, anim)
			return true
		"throw":
			var victim: Actor = _by_id.get(b["target"])
			if victim == null:
				return true                # nobody to throw at: nothing to show
			if not _reach(a, _spot(a, int(b["slot"])), _focus):
				return false
			_throw(a, victim, i, anim, b["prop"])
			return true
		"lock":
			var spot := _device_spot()
			if not _reach(a, spot, spot + DEVICE_FACING):
				return false
			a.locked = true
			a.rest_anim = anim
			a.yaw = atan2(DEVICE_FACING.x, DEVICE_FACING.y)
			a.yaw_goal = a.yaw
			a.body.rotation.y = a.yaw
			_rest(a)
			return true
		"release":
			var victim: Actor = _by_id.get(b["target"])
			var at := _device_at if _device != null else _focus
			if not _reach(a, _beside(a), at):
				return false
			_face(a, at)
			_once(a, anim)
			if victim != null:
				a.freeing = victim
				a.free_in = a.busy * 0.5     # the lock opens halfway through the gesture
			return true
	push_warning("stage: unknown action " + action)
	return true


## Where a beat's slot is: a crowd slot, or with -1 the place itself - the device for the victim, beside
## it for anyone else (so the elder doesn't stand inside the thief), the middle when there is no device.
func _spot(a: Actor, slot: int) -> Vector2:
	if slot >= 0:
		return Sites.slot(_place, slot)
	if _device == null:
		return Sites.at(_place)
	return _device_spot() if a == _victim else _beside(a)


func _device_spot() -> Vector2:
	return _device_at - DEVICE_FACING * LOCK_BACK if _device != null else Sites.at(_place)


## A spot to the side of the device, on the side the actor is already on, a little in front of it.
func _beside(a: Actor) -> Vector2:
	var side := Vector2(DEVICE_FACING.y, -DEVICE_FACING.x)
	if (a.pos - _device_at).dot(side) < 0.0:
		side = -side
	return _device_at + side * BESIDE + DEVICE_FACING * 0.3


## True when the actor stands at `spot`; otherwise it finishes its walk, then sets off there.
func _reach(a: Actor, spot: Vector2, face: Vector2) -> bool:
	if not a.path.is_empty():
		return false
	if a.pos.distance_squared_to(spot) < 0.04:
		return true
	if a.locked:
		return false
	_go(a, spot, a.walk_anim, face)
	return false


func _go(a: Actor, to: Vector2, anim: String, face: Vector2) -> void:
	a.path = _route(a.pos, to)
	a.face = face
	a.walk_anim = anim if GAITS.has(anim) else "Walk"
	var gait: Array = GAITS[a.walk_anim]
	a.pace = gait[0]
	a.loop_left = INF
	_loop(a, a.walk_anim, a.pace / float(gait[1]))


func _walk(a: Actor, dt: float) -> void:
	var step := a.pace * dt
	while step > 0.0 and not a.path.is_empty():
		var to := a.path[0]
		var d := a.pos.distance_to(to)
		if d > 0.001:
			a.yaw_goal = atan2(to.x - a.pos.x, to.y - a.pos.y)
		if d <= step:
			a.pos = to
			step -= d
			a.path.remove_at(0)
		else:
			a.pos += (to - a.pos) * (step / d)
			step = 0.0
	a.y = _shape.height_at(a.pos.x, a.pos.y)
	a.body.position = Vector3(a.pos.x, a.y, a.pos.y)
	if a.path.is_empty():
		_arrive(a)


func _arrive(a: Actor) -> void:
	if a.going_home:
		a.going_home = false
		if a.pending.is_empty():
			_hide(a, true)                 # indoors (unless there is more to do)
			return
	if a.face != Vector2.INF:
		_face(a, a.face)
	if a.busy <= 0.0:
		_rest(a)


func _face(a: Actor, at: Vector2) -> void:
	var d := at - a.pos
	if d.length_squared() > 0.0001:
		a.yaw_goal = atan2(d.x, d.y)


func _hide(a: Actor, hidden: bool) -> void:
	if a.body == null:
		if hidden:
			return
		_embody(a)                        # needed before its turn in the queue
	a.inside = hidden
	a.body.visible = not hidden
	# A body at home costs nothing: its animation and scripts stop too.
	a.body.process_mode = Node.PROCESS_MODE_DISABLED if hidden else Node.PROCESS_MODE_INHERIT
	if not hidden:
		a.playing = ""
		_rest(a)


## Loops the actor's rest animation (a crowd member's stance, the victim's pose), unless already playing.
func _rest(a: Actor) -> void:
	if a.rest_anim != "":
		_loop(a, a.rest_anim, 1.0)


func _loop(a: Actor, anim: String, rate: float) -> void:
	if a.playing == anim:
		return
	a.playing = anim
	if a.native_loop:
		a.body.call("play_loop", anim)
		a.loop_left = INF
		return
	# Start each body at its own point in the loop, so a crowd doesn't breathe in step.
	var length: float = a.body.animation_length(anim)
	var start := fposmod(a.id * 0.37, length)
	a.body.play_action(anim, _speed * rate, start)
	a.loop_left = INF if _loops(anim) else length - start


## One pass of an animation; the actor is busy until it ends (stage seconds = its length).
func _once(a: Actor, anim: String) -> void:
	a.playing = ""
	a.body.play_action(anim, _speed)
	a.busy = a.body.animation_length(anim)


func _loops(anim: String) -> bool:
	if not _looping.has(anim):
		_looping[anim] = _anims == null or _anims.get_animation(anim).loop_mode != Animation.LOOP_NONE
	return _looping[anim]


func _unlock(v: Actor) -> void:
	v.locked = false
	v.rest_anim = "Idle"
	_released = _clock
	if v.busy <= 0.0:
		_rest(v)


func _throw(a: Actor, victim: Actor, beat: int, anim: String, prop: String) -> void:
	_face(a, victim.pos)
	a.yaw = a.yaw_goal                     # square up at once, so the prop leaves from the throwing hand
	a.body.rotation.y = a.yaw
	_once(a, anim)
	var s := Shot.new()
	s.prop = prop if prop != "" else "stone"
	s.thrower = a
	s.victim = victim
	s.wait = RELEASE_AT
	if _react_of.has(beat):
		var r: Dictionary = _beats[_react_of[beat]]
		s.react = r["anim"] if r["anim"] != "" else DEFAULT_ANIM["react"]
	_shots.append(s)
	_throws += 1


## A victim is hit: a flash, and the hit animation (a locked victim is only knocked, since the hit
## animations are made standing and would pop them up out of the pillory).
func _hit(v: Actor, anim: String, by: Actor) -> void:
	if v.inside:
		return
	v.body.flash()
	if v.locked:
		var from := by.pos if by != null else v.pos + DEVICE_FACING
		var push := v.pos - from
		v.jolt_dir = Vector3(push.x, 0.0, push.y).normalized() * JOLT
		v.jolt = JOLT_TIME
	elif anim != "" and v.path.is_empty():
		_once(v, anim)


func _head(v: Actor) -> Vector3:
	var local: Vector3 = HEAD_IN_POSE.get(v.playing, HEAD_STANDING)
	return Vector3(v.pos.x, v.y, v.pos.y) + Basis(Vector3.UP, v.yaw) * local


## Props in flight: out of the hand, an arc to the head, a hit, a short fall to the ground.
func _fly(dt: float) -> void:
	var i := _shots.size() - 1
	while i >= 0:
		var s := _shots[i]
		if s.phase == 0:
			s.wait -= dt
			if s.wait <= 0.0:
				_launch(s)
		else:
			s.t += dt
			var u := minf(s.t / s.dur, 1.0)
			s.node.position = s.from.lerp(s.to, u) + Vector3(0.0, s.arc * 4.0 * u * (1.0 - u), 0.0)
			s.node.rotation += s.spin * dt
			if u >= 1.0:
				if s.phase == 1:
					_land_on_head(s)
				else:
					_land(s)
					_shots.remove_at(i)
		i -= 1


func _launch(s: Shot) -> void:
	var a := s.thrower
	s.from = Vector3(a.pos.x, a.y, a.pos.y) + Basis(Vector3.UP, a.yaw) * RELEASE_FROM
	# Aim error from the throw count: deterministic, so the same staging always lands the same way.
	var k := float(_throws * 7 + a.id * 3)
	s.to = _head(s.victim) + Vector3(sin(k) * HIT_SPREAD, cos(k * 1.3) * HIT_SPREAD * 0.5, cos(k) * HIT_SPREAD)
	var dist := s.from.distance_to(s.to)
	s.dur = maxf(dist / THROW_SPEED, 0.18)
	s.arc = 0.25 + dist * 0.1
	s.spin = Vector3(7.0, 3.0, 5.0)
	s.node = _make_prop(s.prop)
	add_child(s.node)
	s.node.position = s.from
	s.phase = 1
	s.t = 0.0


func _land_on_head(s: Shot) -> void:
	_hit(s.victim, s.react, s.thrower)
	# Then it carries on in the throw's direction and drops to the ground.
	var ahead := Vector2(s.to.x - s.from.x, s.to.z - s.from.z).normalized()
	var k := float(_throws + s.thrower.id)
	var ground := Vector2(s.to.x, s.to.z) + ahead * float(CARRY_ON.get(s.prop, 0.6)) + Vector2(-ahead.y, ahead.x) * sin(k) * 0.35
	s.from = s.to
	s.to = Vector3(ground.x, _shape.height_at(ground.x, ground.y) + _lift(s.node), ground.y)
	s.dur = 0.35
	s.arc = 0.3 if s.prop == "stone" else 0.12
	s.phase = 2
	s.t = 0.0


func _land(s: Shot) -> void:
	s.phase = 3
	s.life = PROP_LINGER
	if s.prop == "mud":                     # a splat, not a ball
		s.node.scale = Vector3(1.6, 0.3, 1.6)
		s.node.rotation = Vector3.ZERO
		s.node.position.y = _shape.height_at(s.node.position.x, s.node.position.z) + 0.02
	else:
		s.node.rotation.x = 0.0             # lies the right way up, still turned where it rolled
		s.node.rotation.z = 0.0
	_lying.append(s)
	if _lying.size() > MAX_LYING:
		_lying[0].node.queue_free()
		_lying.remove_at(0)


## How high a prop's origin sits above its lowest point, so it rests on the ground rather than in it.
func _lift(node: Node3D) -> float:
	for c in node.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			return maxf(-mi.get_aabb().position.y * mi.scale.y - mi.position.y, 0.0)
	return 0.0


func _age_lying(delta: float) -> void:
	while not _lying.is_empty() and _lying[0].life <= delta:
		_lying[0].node.queue_free()
		_lying.remove_at(0)
	for s in _lying:
		s.life -= delta


## The walls bodies walk round: every house footprint (world/village.gd), the merchant's stall, and the
## device, each grown by a body's radius.
func _build_blocks() -> void:
	_blocks.clear()
	for h: Dictionary in Houses.HOUSES:
		var size := Vector2(h["size"].x, h["size"].z)
		_blocks.append(Rect2(h["at"] - size * 0.5, size).grow(BODY_RADIUS))
	_blocks.append(Rect2(Houses.MERCHANT_AT - Vector2(0.6, 0.6), Vector2(1.2, 1.2)).grow(BODY_RADIUS))
	if DEVICES.has(_place):
		var f := DEVICE_FACING
		var half := Vector2(absf(f.y) * DEVICE_HALF.x + absf(f.x) * DEVICE_HALF.y, absf(f.x) * DEVICE_HALF.x + absf(f.y) * DEVICE_HALF.y)
		_blocks.append(Rect2(Sites.at(_place) - half, half * 2.0).grow(BODY_RADIUS))


## A walk from `from` to `to` that goes round the blocks: the shortest way through the corners of the
## blocks near the line (a small visibility graph, made once per walk, not per frame). Ends that stand
## inside a block (a doorstep against its own wall, the victim's spot at the device) step out and in.
func _route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _outside(from)
	var end := _outside(to)
	var path := PackedVector2Array()
	if start != from:
		path.append(start)
	if _clear(start, end):                 # most walks: nothing in the way
		path.append(end)
		if end != to:
			path.append(to)
		return path
	var nodes := PackedVector2Array([start, end])
	var near := Rect2(start, Vector2.ZERO).expand(end).grow(6.0)
	for r in _blocks:
		if r.intersects(near):
			var c := r.grow(CORNER_PAD)
			nodes.append(c.position)
			nodes.append(Vector2(c.end.x, c.position.y))
			nodes.append(c.end)
			nodes.append(Vector2(c.position.x, c.end.y))
	var n := nodes.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	dist[0] = 0.0
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var done := PackedByteArray()
	done.resize(n)
	while true:
		var u := -1
		var best := INF
		for j in n:
			if done[j] == 0 and dist[j] < best:
				best = dist[j]
				u = j
		if u == -1 or u == 1:
			break
		done[u] = 1
		for v in n:
			if done[v] == 0:
				var w := dist[u] + nodes[u].distance_to(nodes[v])
				if w < dist[v] and _clear(nodes[u], nodes[v]):
					dist[v] = w
					prev[v] = u
	if prev[1] == -1:
		path.append(end)                   # boxed in: walk straight rather than stand still
	else:
		var back := PackedVector2Array()
		var k := 1
		while k != 0:
			back.append(nodes[k])
			k = prev[k]
		back.reverse()
		path.append_array(back)
	if end != to:
		path.append(to)
	return path


func _clear(a: Vector2, b: Vector2) -> bool:
	for r in _blocks:
		if _crosses(a, b, r.grow(-0.02)):
			return false
	return true


## Whether the segment a-b passes through the inside of r (slab test).
static func _crosses(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		var p := a[axis]
		var v := d[axis]
		var lo := r.position[axis]
		var hi := r.end[axis]
		if absf(v) < 0.000001:
			if p <= lo or p >= hi:
				return false
		else:
			var ta := (lo - p) / v
			var tb := (hi - p) / v
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 >= t1:
				return false
	return true


## The nearest point just outside any block that holds p.
func _outside(p: Vector2) -> Vector2:
	for r in _blocks:
		if r.has_point(p):
			var left := p.x - r.position.x
			var right := r.end.x - p.x
			var top := p.y - r.position.y
			var bottom := r.end.y - p.y
			var m := minf(minf(left, right), minf(top, bottom))
			if m == left:
				p.x = r.position.x - 0.05
			elif m == right:
				p.x = r.end.x + 0.05
			elif m == top:
				p.y = r.position.y - 0.05
			else:
				p.y = r.end.y + 0.05
	return p
