extends Node3D
## The stage (tier E of the living village): plays a staging (staging.gd) live in the meadow village.
## The simulation decides what happens; the stage only shows it. Each person comes out of their door
## when their first beat is due, and the beats run in time order on the stage's own clock:
##
##   stage.play(staging, people, 8.0)    # x8 fast-forward; set_speed() changes it, skip_to(minute) jumps
##
## Beats are when things are *asked for*. A body finishes its walk before it stands or throws, finishes a
## one-shot before it walks off, and stays locked until someone releases it, so a beat can start late but
## is never reordered (per person). Everything moves on stage time (real time x speed), so a run looks
## the same at any speed; props lying on the ground are the one exception (they linger PROP_LINGER real
## seconds, for the eye).
##
## What the stage adds to the beats, by place and kind (the staging names what happens, not how a body
## fits a prop):
##   devices (DEVICES: pillory, stake, gallows): the real prop (props.gd), the condemned walked up its
##     steps (way_in) to props.VICTIM in the pose the device needs, lifted by its floors, down again after;
##     a fall is brief and stylised (the crowd flinches; at the gallows the body drops through the trapdoor
##     and is gone, no rope ever on it; at the stake it slumps as the fire flares; elsewhere it falls; the
##     body is taken away FALLEN_HOLD later); fire and smoke at the stake.
##   crowds stand in a horseshoe facing the act, open to the camera (sites.arc), or for a festival in
##     small circles (sites.cluster); slots inside a house or the device are passed over.
##   trial: the elder's bench (a placeholder), the elder behind it and the accused before it; the verdict
##     is implied (a pronouncing gesture, then the accused's answer) when the staging has none.
##   exile: the condemned's last walk goes out along the road and does not come back.
##   anyone the staging never sends home (the elder, in the simulation's stagings) leaves with the crowd.
##   content line: a throw by a child is not shown (nor its hit), and noted (notes()).
## The player can step in during a phase whose rescue is true (rescue_open): free the locked victim with
## the game's action button (a "Free" interactable at the device), or stand in a thrower's line and take
## the throw (no damage). Either emits player_intervened; inject() adds beats while playing.
##
## Per frame: one pass over the people and the props in flight; no allocations, no node lookups.
## Bodies are VillagerBody (villager_body.gd: CharacterVisual's character as one skinned mesh, one draw
## call each), made one per frame after play(), in the order they are needed; one needed sooner is made
## at once. Every DETAIL_EVERY seconds the NEAR_FULL bodies nearest the camera get full detail (full-rate
## animation, shadows), the rest animate at ~10 Hz without shadows, and bodies well out of view are hidden.

signal finished
## The player stepped in (kind "free" or "shield"), for the simulation to learn of later.
signal player_intervened(kind: String, minute: int)

const Sites := preload("res://scripts/studio/village/sites.gd")
const Body := preload("res://scripts/studio/village/villager_body.gd")
const Staging := preload("res://scripts/studio/village/staging.gd")
const Houses := preload("res://scripts/world/village.gd")
## The workbench and its parasol (main.gd builds it at (-1, 7)), to walk round.
const WORKBENCH := Rect2(-2.3, 5.9, 2.6, 2.2)
const UseSpot := preload("res://scripts/world/use_spot.gd")
## Props come from the real set (props.gd); what it lacks (carried things, the bench, the fire) from the
## placeholders.
const Props := preload("res://scripts/studio/village/props.gd")
const Placeholders := preload("res://scripts/studio/village/stage_props.gd")

const SECONDS_PER_MINUTE := 0.5      # a game day is 12 real minutes (staging.gd)
## Gaits a walk can ask for: [pace in m/s, the pace the animation was made for] (the rig's Walk is 0.975).
const GAITS := {"Walk": [1.3, 0.975], "Walk_Formal": [1.05, 0.975], "Walk_Carry": [1.0, 0.975], "Jog_Fwd": [3.0, 4.2]}
const TURN_RATE := 7.0               # radians per stage second
const CLIMB_RATE := 1.6              # metres per stage second a body rises or drops onto a step
const BODY_RADIUS := 0.35            # how far bodies keep from walls
const CORNER_PAD := 0.3              # detours pass this far outside a wall's corner
const SKIP_STEP := 0.25              # stage seconds per step when skipping ahead
const MAX_FRAME := 0.1               # a longer frame (a hitch) plays as this long: the stage slows, it doesn't jump
const GROUND_EVERY := 0.25           # metres a walker goes between ground samples (WorldShape.height_at is ~10 us)
const NEAR_FULL := 12                # bodies nearest the camera at full detail (VillagerBody tier 0)
const DETAIL_EVERY := 0.25           # real seconds between detail passes
const VIEW_MARGIN := 0.2             # a body this far (in screen widths) outside the view still counts as in it
## What a beat plays when it names no animation.
const DEFAULT_ANIM := {"walk_to": "Walk", "leave": "Walk", "carry": "Walk_Carry", "stand": "Idle", "gesture": "Yes",
	"react": "Hit_Chest", "throw": "OverhandThrow", "lock": "Crouch_Idle", "release": "Interact", "fall": "Death01"}

## Places with a device the condemned is put in or on, in the device's own metres (+z its front: devices
## face south, DEVICE_FACING, towards the crowd's open side and the camera):
##   prop    the props.gd prop; props.VICTIM says where the body goes and VICTIM_POSE in what pose;
##   walls   the footprint bodies walk round;
##   floors  [x0, z0, x1, z1, height at z0, height at z1]: standing there lifts a body (platform, steps);
##   way_in  the points the condemned walks through from the ground to their place (and back down after);
##   fall    how they go down there (Death01 falls backwards, into the stake's post: a slump instead;
##           "drop": through the gallows' trapdoor, out of sight);
##   beside  how far to the side an official stands.
const DEVICES := {
	"pillory": {"prop": "pillory", "walls": Rect2(-0.8, -0.9, 1.6, 1.7), "beside": 1.4, "fall": "Death01",
		"floors": [[-0.75, -0.85, 0.75, 0.45, 0.3, 0.3], [-0.35, 0.45, 0.35, 0.8, 0.16, 0.16]],
		"way_in": [Vector2(0.0, 1.2), Vector2(0.0, 0.55)]},
	"stake": {"prop": "stake", "walls": Rect2(-1.0, -1.0, 2.0, 2.0), "beside": 1.8, "fall": "Crouch_Idle",
		"floors": [[-0.25, 0.02, 0.25, 0.38, 0.5, 0.5], [-0.3, 0.38, 0.3, 1.05, 0.5, 0.0]],
		"way_in": [Vector2(0.0, 1.45)]},
	"gallows": {"prop": "gallows", "walls": Rect2(-1.25, -1.05, 2.5, 3.0), "beside": 2.0, "fall": "drop",
		"floors": [[-1.2, -1.0, 1.2, 1.0, 1.2, 1.2], [-1.0, 1.0, -0.2, 1.9, 1.2, 0.18]],
		"way_in": [Vector2(-0.6, 2.4), Vector2(-0.6, 0.8)]},
}
const DEVICE_FACING := Vector2(0.0, 1.0)
const BESIDE := 1.4          # with no device, an official stands this far to the side of the place
## The trial: the elder's bench (Placeholders.bench, its front towards the accused), in metres from the
## place, the accused on the east, the elder behind the bench on the west: side-on to the camera.
const BENCH_AT := Vector2(-0.7, 0.0)
const JUDGE_AT := Vector2(-1.4, 0.0)
const ACCUSED_AT := Vector2(0.1, 0.0)   # close enough to reach the bench (paying a fine, Interact)
const BENCH_HALF := Vector2(0.31, 0.75)
const VERDICT := "Spell_Simple_Shoot"        # the elder pronounces (an open hand thrust forward)
const ANSWER := {"acquitted": "Yes", "confessed_spared": "Interact", "carried_out": "Interact", "commuted": "Yes"}
const EXILE_OUT := 14.0      # metres past the place's focus the exiled walk before they are gone
## A fall is brief: the crowd flinches (staggered up to FLINCH_SPREAD stage seconds) and the body is
## taken away FALLEN_HOLD stage seconds after the fall began.
const FLINCH := "Hit_Chest"
const FLINCH_SPREAD := 0.7
const FALLEN_HOLD := 3.5
const DROP_HOLD := 0.45      # a drop through the trapdoor: gone once half through (it has fallen ~1 m)
const GRAVITY := 9.8
## The fire at the stake: lit FIRE_AFTER_TORCH game minutes after the first torch is raised (or
## FIRE_BEFORE_FALL before the fall when nobody raises one), grown over FIRE_GROW stage seconds to
## FIRE_LOW (flames below the knees of the one on the board), flaring to full height at the fall.
const FIRE_AFTER_TORCH := 20.0
const FIRE_BEFORE_FALL := 30.0
const FIRE_GROW := 4.0
const FIRE_LOW := 0.55
## Errands (gestures that need a place to work): Fixing_Kneeling builds at the device, then back to the slot.
const WORK := ["Fixing_Kneeling"]
## Where a head is in its body's own space (+z is forward), measured on the hero rig: the Head bone plus
## ~0.1 m to the middle of the head. Thrown props aim here.
const HEAD_STANDING := Vector3(0.0, 1.64, 0.0)
const HEAD_IN_POSE := {"Crouch_Idle": Vector3(0.06, 0.96, 0.22), "Sitting_Idle": Vector3(0.0, 1.28, -0.14),
	"Idle_Rail": Vector3(-0.03, 1.46, 0.07)}
## OverhandThrow lets go 0.33 s in, the right hand above and ahead of the shoulder (measured on the rig).
const RELEASE_AT := 0.33
const RELEASE_FROM := Vector3(-0.2, 1.55, 0.3)
const THROW_SPEED := 9.0     # m/s along the arc
## How far each prop carries on after hitting (stones bounce away, mud drops where it hits).
const CARRY_ON := {"stone": 1.2, "mud": 0.2, "cabbage": 0.6, "turnip": 0.8}
const HIT_SPREAD := 0.12     # metres of aim error, so hits don't all land on one point
const PROP_LINGER := 20.0    # real seconds a thrown prop lies on the ground
const MAX_LYING := 48        # past this the oldest prop on the ground goes (keeps a long event's cost flat)
const PILLORY_WRIST := 0.36  # the pillory's wrist holes either side of the neck (props.gd), in its board 0.1 m forward
const JOLT := 0.09           # metres a locked victim is knocked by a hit
const JOLT_TIME := 0.25
## Held props: a torch in the right hand (as CharacterVisual holds tools), carried wood across the chest.
const HELD_IN_HAND := ["torch", "flower"]
const CARRIED_AT := Vector3(0.0, 1.0, 0.34)
## The player stepping in: the Free button shows within FREE_REACH of the locked victim; a throw whose
## line passes within SHIELD_REACH of the player (between thrower and victim) hits the player instead.
const FREE_REACH := 1.9
const SHIELD_REACH := 0.55
const PLAYER_CHEST := 1.3
const TURN_NO := 6           # the crowd nearest the victim who turn to Idle_No when the player frees them


## A person on the stage: their body and what it is doing.
class Actor:
	var id := 0
	var person := {}
	var body: Body                    # null until made (_embody)
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
	var busy := 0.0                   # stage seconds left of a one-shot (throw, gesture, hit)
	var locked := false
	var going_home := false
	var gone := false                 # walked out for good (exile): hidden on arrival, never back
	var inside := true                # at home: hidden and not processed
	var pending := PackedInt32Array() # beats (indices) asked for but not started yet
	var freeing: Actor                # the victim this official is releasing
	var free_in := 0.0
	var jolt := 0.0
	var jolt_dir := Vector3.ZERO
	var held: Node3D                  # a prop in the hand or carried
	var errand := ""                  # on arrival: "drop" the carried prop, or an animation to play once
	var back_to := Vector2.INF        # after an errand: back to this spot, facing back_face
	var back_face := Vector2.INF
	var flinch_in := -1.0             # stage seconds until a flinch at a fall (-1 none)
	var taken_in := -1.0              # a fallen victim: stage seconds until taken away
	var drop_v := -1.0                # dropping through a trapdoor: falling speed (m/s; -1 not dropping)
	var ground_at := Vector2.INF      # where the ground height was last sampled for a walk, and that height
	var ground_y := 0.0


## A thrown prop, from the hand to the head, then to the ground.
class Shot:
	var beat := -1
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
	var shielded := false             # the player stepped into its line: it hits them instead


var _shape := WorldShape.new()
var resident_registry: Node3D
var action_authority: Callable
var external_clock := false
var external_minute := 0.0
var _real := {}                       # the real props by name (props.gd all())
var _beats: Array = []                # the stage's own copy: the staging's beats, implied ones, injected ones
var _order := PackedInt32Array()      # beat indices in time order; _next is the next to hand out
var _staged := 0                      # beats that came with the staging (the rest were injected)
var _skip := {}                       # beat indices not to play (a child's throw and its hit; a freed victim's)
var _notes := PackedStringArray()     # what the stage left out or made up, and why
var _start := 0
var _speed := 1.0
var _clock := 0.0                     # stage seconds since the staging's start
var _next := 0
var _kind := ""
var _outcome := ""
var _phases: Array = []
var _actors: Array[Actor] = []
var _unmade: Array[Actor] = []        # bodies still to make, soonest needed first
var _by_id := {}                      # person id -> Actor
var _victim: Actor
var _authority: Actor
var _place := ""
var _centre := Vector2.ZERO           # the place (what the crowd faces)
var _focus := Vector2.ZERO            # the place's focus (sites.gd: where the road out points, for an exile)
var _info := {}                       # the place's DEVICES entry ({} if none)
var _device: Node3D
var _device_at := Vector2.ZERO
var _bench: Node3D
var _slots := PackedVector2Array()    # crowd slot -> ground position
var _slot_face := PackedVector2Array()  # crowd slot -> what its person faces
var _blocks: Array[Rect2] = []        # house footprints (and the device), grown by BODY_RADIUS
var _react_of := {}                   # throw beat index -> its react beat index (played on impact)
var _on_impact := {}                  # react beat indices played by a prop landing, not by the clock
var _shots: Array[Shot] = []          # in the hand or in the air
var _lying: Array[Shot] = []          # on the ground, oldest first
var _released := -1.0                 # stage clock when the victim was freed
var _locked_at := -1.0                # stage clock when the victim was locked in
var _fell_at := -1.0                  # stage clock when the victim's fall began
var _fire: Node3D
var _fire_at := -1.0                  # game minute the fire is lit (-1 no fire)
var _fire_t := 0.0                    # stage seconds since it was lit
var _flare := 0.0                     # 0..1 how far the fire has flared up (after the fall)
var _rescued := false
var _free_spot: Node3D                # the "Free" interactable, in the "interactable" group while it can be used
var _player: Node3D
var _done := false
var _throws := 0
## Costs and lateness, for the witness: stage _process time, and how late beats started.
var _cost_frames := 0
var _cost_sum := 0
var _cost_max := 0
var _cost_max_at := 0.0               # the game minute of the dearest frame
var _cost_last := 0                   # the last frame's
var _made := 0                        # bodies made, and the time it took (the body's cost, kept apart)
var _made_us := 0
var _made_max_us := 0
var _made_in_frame := 0
var _latest := 0.0
var _latest_beat := -1
var _routes := 0                      # walks planned (each a small search), for stats
var _detail_in := 0.0                 # real seconds until the next detail pass
var _by_near: Array[Actor] = []       # out-of-door actors, reused by the detail pass


func _ready() -> void:
	set_process(false)


## Plays a staging with its people (staging.gd formats). Needs the stage in the tree, at the origin.
func play(staging: Dictionary, people: Array, speed: float = 1.0) -> void:
	for problem in Staging.validate(staging, people):
		if external_clock and problem.begins_with("beat for unknown person"):
			continue # departed noncritical participants are intentionally absent from live presentation
		push_warning("stage: " + problem)
	clear()
	if _real.is_empty():
		_real = Props.all()
	_beats = (staging["beats"] as Array).duplicate(true)
	_staged = _beats.size()
	_start = int(staging["start"])
	_speed = speed
	_kind = staging.get("kind", "")
	_outcome = staging.get("outcome", "")
	_phases = staging.get("phases", [])
	_place = staging["place"]
	_centre = Sites.at(_place)
	_focus = Sites.PLACES[_place]["focus"] if Sites.PLACES.has(_place) else _centre
	_info = DEVICES.get(_place, {})
	if not _info.is_empty():
		_device_at = _centre
		_device = _make_prop(_info["prop"])
		add_child(_device)
		_device.position = Vector3(_device_at.x, _shape.height_at(_device_at.x, _device_at.y), _device_at.y)
		_device.rotation.y = atan2(DEVICE_FACING.x, DEVICE_FACING.y)
	if _kind == "trial":
		_bench = _make_prop("bench")
		add_child(_bench)
		var at := _centre + BENCH_AT
		_bench.position = Vector3(at.x, _shape.height_at(at.x, at.y), at.y)
		_bench.rotation.y = atan2(ACCUSED_AT.x - BENCH_AT.x, ACCUSED_AT.y - BENCH_AT.y)
	_build_blocks()
	for person: Dictionary in people:
		_add_person(person)
	_victim = _by_id.get(int(staging["roles"].get("victim", -1)))
	_authority = _by_id.get(int(staging["roles"].get("authority", -1)))
	_imply_beats()
	_order_beats()
	_build_slots()
	_pair_hits()
	if external_clock:
		# Predicted endings are suggestions only. Live outcomes arrive from the persisted authority.
		for i in _beats.size():
			var b: Dictionary = _beats[i]
			if _victim != null and ((b.who == _victim.id and b["do"] in ["fall", "leave"]) or (b["do"] == "release" and b.target == _victim.id)):
				_skip[i] = true
	_screen_throws()
	_plan_fire()
	_player = get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	_queue_bodies()
	set_process(true)


## Removes every body and prop; the stage can play again.
func clear() -> void:
	if is_instance_valid(resident_registry):
		for a in _actors:
			if is_instance_valid(a.body):
				resident_registry.release(a.id, a.body)
	for c in get_children():
		c.queue_free()
	_actors.clear()
	_unmade.clear()
	_by_id.clear()
	_shots.clear()
	_lying.clear()
	_react_of.clear()
	_on_impact.clear()
	_skip.clear()
	_notes.clear()
	_order.clear()
	_slots.clear()
	_slot_face.clear()
	_device = null
	_bench = null
	_fire = null
	_fire_at = -1.0
	_fire_t = 0.0
	_flare = 0.0
	_free_spot = null
	_victim = null
	_authority = null
	_info = {}
	_clock = 0.0
	_next = 0
	_released = -1.0
	_locked_at = -1.0
	_fell_at = -1.0
	_rescued = false
	_done = false
	_throws = 0
	_routes = 0
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
	return _centre


func is_finished() -> bool:
	return _done


func is_locked(id: int) -> bool:
	var a: Actor = _by_id.get(id)
	return a != null and a.locked


## The game minute the victim was freed (-1 until then).
func released_minute() -> float:
	return -1.0 if _released < 0.0 else _start + _released / SECONDS_PER_MINUTE


## The game minute the victim was locked in, and the one their fall began (-1 until then).
func locked_minute() -> float:
	return -1.0 if _locked_at < 0.0 else _start + _locked_at / SECONDS_PER_MINUTE


func fell_minute() -> float:
	return -1.0 if _fell_at < 0.0 else _start + _fell_at / SECONDS_PER_MINUTE


## How far along the furthest prop in flight at a head is (0..1), or -1 when none is.
func flying() -> float:
	var best := -1.0
	for s in _shots:
		if s.phase == 1:
			best = maxf(best, s.t / s.dur)
	return best


## The beats as the stage plays them: the staging's, then any it implied (marked "implied") or was given
## by inject() (marked "injected").
func beats() -> Array:
	return _beats


## What the stage left out or made up, and why (a child's throw not shown, a verdict implied...).
func notes() -> PackedStringArray:
	return _notes


## Whether the player can still step in: a phase whose rescue is true, with the victim out and neither
## freed nor fallen.
func rescue_open() -> bool:
	if _victim == null or _rescued or _fell_at >= 0.0 or _victim.inside:
		return false
	var now := minute()
	for p: Dictionary in _phases:
		if p["rescue"] and now >= float(p["from"]) and now < float(p["to"]):
			return true
	return false


## Where a player stands to free the victim: in front of the device (or of the victim), within reach.
func rescue_spot() -> Vector2:
	if _victim == null:
		return _centre
	var at := _device_at if _device != null else _victim.pos
	var reach := float((_info["walls"] as Rect2).end.y) + 0.45 if _device != null else 1.0
	return at + DEVICE_FACING * minf(reach, FREE_REACH - 0.2)


## Where a player stands to take a thrower's throws: on the line from the thrower to the victim, a third
## of the way from the victim.
func shield_spot(thrower: int) -> Vector2:
	var t: Actor = _by_id.get(thrower)
	if t == null or _victim == null:
		return _centre + DEVICE_FACING * 1.5
	var from := _spot(t, _slot_of(thrower))
	return _victim.pos.lerp(from, 0.38)


## Adds a beat while playing (staging.gd beat format; "at" may be now or later). The stage hands it out
## in time order with the rest; the simulation can use this to hear back what happened (see
## player_intervened).
func inject(beat: Dictionary) -> void:
	var b := beat.duplicate()
	for k: String in ["slot", "target"]:
		if not b.has(k):
			b[k] = -1
	for k: String in ["anim", "prop"]:
		if not b.has(k):
			b[k] = ""
	b["injected"] = true
	var i := _beats.size()
	_beats.append(b)
	var at := float(b["at"])
	var k := _next
	while k < _order.size() and float(_beats[_order[k]]["at"]) <= at:
		k += 1
	_order.insert(k, i)


## Where each body goes and what it did, for probes (programmatic checks instead of pixels): who is out,
## walking, locked; anyone standing inside a house or on top of someone else; props in the air and down.
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
		"flying": _shots.size(), "lying": _lying.size(), "thrown": _throws, "victim_locked": _victim != null and _victim.locked,
		"victim_at": (_victim.pos - _centre).snapped(Vector2.ONE * 0.1) if _victim != null else Vector2.INF,
		"victim_does": _victim.playing if _victim != null else "",
		"authority_at": (_authority.pos - _centre).snapped(Vector2.ONE * 0.1) if _authority != null else Vector2.INF,
		"authority_does": _authority.playing if _authority != null else "",
		"rescued": _rescued, "fire": snappedf((_fire.get_child(0) as Node3D).scale.y, 0.01) if _fire != null else 0.0}


## The stage's own cost per frame (microseconds of _process) and the latest any beat started.
func stats() -> Dictionary:
	return {"frames": _cost_frames, "mean_us": roundi(float(_cost_sum) / maxi(_cost_frames, 1)), "max_us": _cost_max,
		"max_at_minute": snappedf(_cost_max_at, 0.1),
		"bodies_made": _made, "make_mean_ms": snappedf(_made_us / 1000.0 / maxi(_made, 1), 0.1), "make_max_ms": snappedf(_made_max_us / 1000.0, 0.1),
		"latest_minutes": snappedf(_latest / SECONDS_PER_MINUTE, 0.1), "routes": _routes,
		"latest_beat": str(_beats[_latest_beat]) if _latest_beat >= 0 else ""}


## The last frame's stage _process time (microseconds, making bodies excluded).
func last_cost_us() -> int:
	return _cost_last


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_made_in_frame = 0
	if not _unmade.is_empty():
		_embody(_unmade[0])
	if external_clock:
		_step(maxf(0.0, (external_minute - minute()) * SECONDS_PER_MINUTE))
	else:
		_step(minf(delta, MAX_FRAME) * _speed)
	_age_lying(delta)
	_detail_in -= delta
	if _detail_in <= 0.0:
		_detail_in = DETAIL_EVERY
		_set_details()
	var used := Time.get_ticks_usec() - t0 # includes construction, including urgent bodies made by beats
	_cost_frames += 1
	_cost_last = used
	_cost_sum += used
	if used > _cost_max:
		_cost_max = used
		_cost_max_at = minute()


## Every body is made here (a VillagerBody: play_action / animation_length / flash as CharacterVisual,
## plus play_loop and set_detail). Its look comes from the person: the outfit, and hair and skin by id.
func _make_body(person: Dictionary) -> Body:
	var body := Body.new()
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


## A prop by name: the real set first, the placeholders for what it lacks.
func _make_prop(prop: String) -> Node3D:
	if _real.has(prop):
		return (_real[prop] as Callable).call() as Node3D
	var source: GDScript = Placeholders
	return source.call(prop) as Node3D


func _add_person(person: Dictionary) -> void:
	var a := Actor.new()
	a.id = int(person["id"])
	a.person = person
	a.door = Sites.DOORS.get(person.get("home", ""), _centre)
	a.pos = a.door
	a.y = _shape.height_at(a.pos.x, a.pos.y)
	_actors.append(a)
	_by_id[a.id] = a


## Beats the staging doesn't carry but the stage needs: a verdict for a trial, and a leave for anyone
## never sent home (they go with the crowd).
func _imply_beats() -> void:
	_imply_verdict()
	_imply_leaves()


## Anyone whose last beat isn't a leave goes home with the crowd (after their own last beat) - except a
## victim who falls or is exiled.
func _imply_leaves() -> void:
	var last := {}
	var crowd_leaves := INF
	for b: Dictionary in _beats:
		if not last.has(b["who"]) or float(b["at"]) >= float(last[b["who"]]["at"]):
			last[b["who"]] = b
		if b["do"] == "leave":
			crowd_leaves = minf(crowd_leaves, float(b["at"]))
	if crowd_leaves == INF:
		return
	for a in _actors:
		var b: Dictionary = last.get(a.id, {})
		if b.is_empty() or b["do"] == "leave" or b["do"] == "fall" or (_kind == "exile" and a == _victim):
			continue
		var at := int(maxf(float(b["at"]) + 5.0, crowd_leaves + 2.0))
		_beats.append({"at": at, "who": a.id, "do": "leave", "slot": -1, "target": -1, "anim": "Walk", "prop": "", "implied": true})
		_notes.append("staging: %s (%d) is never sent home; leaves with the crowd at minute %d" % [a.person.get("name", "?"), a.id, at])


## A trial with no gesture gets a verdict: the elder pronounces as the verdict phase opens (before anyone
## leaves), and the accused answers.
func _imply_verdict() -> void:
	if _outcome == "pending" or _kind != "trial" or _authority == null or _victim == null:
		return
	var first_leave := INF
	for b: Dictionary in _beats:
		if b["do"] == "gesture" and b["who"] == _authority.id:
			return
		if b["do"] == "leave":
			first_leave = minf(first_leave, float(b["at"]))
	var at := float(_phases[1]["from"]) if _phases.size() > 1 else float(_start + 60)
	at = maxf(minf(at, first_leave - 5.0), float(_start + 1))
	var answer: String = ANSWER.get(_outcome, "Yes")
	_beats.append({"at": int(at), "who": _authority.id, "do": "gesture", "slot": -1, "target": _victim.id, "anim": VERDICT,
		"prop": "", "implied": true})
	_beats.append({"at": int(at) + 2, "who": _victim.id, "do": "gesture", "slot": -1, "target": _authority.id,
		"anim": answer, "prop": "", "implied": true})
	_notes.append("trial: no verdict in the staging; implied at minute %d (%s, then the accused %s)" % [int(at), VERDICT, answer])
	if _phases.size() > 1 and int(_phases[1]["to"]) < int(_phases[1]["from"]):
		_notes.append("trial: phase '%s' ends (%d) before it starts (%d)" % [_phases[1]["name"], _phases[1]["to"], _phases[1]["from"]])


## The beats in time order (stable, so beats at the same minute keep the staging's order).
func _order_beats() -> void:
	var idx := range(_beats.size())
	idx.sort_custom(func(p: int, q: int) -> bool:
		var ap := float(_beats[p]["at"])
		var aq := float(_beats[q]["at"])
		return ap < aq or (ap == aq and p < q))
	_order = PackedInt32Array(idx)


## Crowd slots on the ground: the horseshoe facing the act (sites.arc), or circles for a festival
## (sites.cluster). A slot inside a house, the device or the bench is passed over for the next one out.
func _build_slots() -> void:
	var needed := 0
	for b: Dictionary in _beats:
		needed = maxi(needed, int(b["slot"]) + 1)
	var k := 0
	while _slots.size() < needed and k < needed * 4 + 40:
		var at: Vector2 = Sites.cluster(_place, k) if _kind == "festival" else Sites.arc(_place, k)
		var face: Vector2 = Sites.cluster_middle(_place, k) if _kind == "festival" else _centre
		k += 1
		if _blocked(at):
			continue
		_slots.append(at)
		_slot_face.append(face)
	while _slots.size() < needed:          # boxed in on every side: stand on the old rings
		_slots.append(Sites.slot(_place, _slots.size()))
		_slot_face.append(_centre)


func _blocked(p: Vector2) -> bool:
	for r in _blocks:
		if r.has_point(p):
			return true
	return false


## The content line: nobody who is a child throws. The simulation should never ask; if it does, the throw
## (and the hit it would cause) is not shown, and noted.
func _screen_throws() -> void:
	for i in _beats.size():
		var b: Dictionary = _beats[i]
		if b["do"] != "throw":
			continue
		var a: Actor = _by_id.get(b["who"])
		if a == null or String(a.person.get("role", "")) != "child":
			continue
		_skip[i] = true
		if _react_of.has(i):
			_skip[_react_of[i]] = true
		_notes.append("content: %s (%d, a child) throws %s at minute %d - not shown" % [a.person.get("name", "?"), a.id, b["prop"], b["at"]])


## The fire at the stake: lit a while after the first torch is raised, or a while before the fall.
func _plan_fire() -> void:
	if _info.get("prop", "") != "stake":
		return
	var torch := INF
	var fall := INF
	for b: Dictionary in _beats:
		if b["prop"] == "torch":
			torch = minf(torch, float(b["at"]))
		if b["do"] == "fall" and _victim != null and b["who"] == _victim.id:
			fall = minf(fall, float(b["at"]))
	if torch < INF:
		_fire_at = torch + FIRE_AFTER_TORCH
	elif fall < INF:
		_fire_at = fall - FIRE_BEFORE_FALL
	if fall < INF and _fire_at > fall:
		_fire_at = fall - 2.0


## Orders the bodies to make by when each person is first needed.
func _queue_bodies() -> void:
	var first := {}
	for i in _order:
		var b: Dictionary = _beats[i]
		if not first.has(b["who"]):
			first[b["who"]] = b["at"]
	_unmade = _actors.duplicate()
	_unmade.sort_custom(func(p: Actor, q: Actor) -> bool: return first.get(p.id, 1 << 30) < first.get(q.id, 1 << 30))


## Makes an actor's body (at home: hidden, at the door).
func _embody(a: Actor) -> void:
	var t0 := Time.get_ticks_usec()
	_unmade.erase(a)
	if is_instance_valid(resident_registry):
		a.body = resident_registry.acquire(a.person, self)
		a.pos = Vector2(a.body.position.x, a.body.position.z)
		a.y = a.body.position.y
		a.inside = false
		_made_in_frame += Time.get_ticks_usec() - t0
		return
	a.body = _make_body(a.person)
	add_child(a.body)
	a.body.position = Vector3(a.pos.x, a.y, a.pos.y)
	a.inside = true
	a.body.set_detail(1)
	a.body.visible = false
	a.body.process_mode = Node.PROCESS_MODE_DISABLED
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
	while _next < _order.size() and float(_beats[_order[_next]]["at"]) <= now:
		var i := _order[_next]
		_next += 1
		if _skip.has(i) or _on_impact.has(i):
			continue
		var who: Actor = _by_id.get(_beats[i]["who"])
		if who == null or who.gone or (_rescued and who == _victim and i < _staged):
			continue                   # a freed victim's own beats from the staging are over
		who.pending.append(i)
		if who.inside and _beats[i]["do"] != "leave":
			_hide(who, false)          # out of the door
	for a in _actors:
		if not a.inside:
			_update(a, dt)
	_fly(dt)
	if _fire_at >= 0.0:
		_burn(dt, now)
	_offer_free()
	if not _done and _next >= _order.size() and _shots.is_empty() and _all_still():
		_done = true
		finished.emit.call_deferred()     # listeners run outside the stage's frame (and its cost)


func _all_still() -> bool:
	for a in _actors:
		if not a.inside and (not a.pending.is_empty() or not a.path.is_empty() or a.busy > 0.0 or a.taken_in >= 0.0):
			return false
	return true


func _update(a: Actor, dt: float) -> void:
	if a.busy > 0.0:
		a.busy -= dt
		if a.busy <= 0.0 and a.path.is_empty():
			if a.back_to != Vector2.INF:
				_go_back(a)               # an errand done: back to the slot
			else:
				_rest(a)                  # back to the stand loop after a one-shot
	if a.flinch_in >= 0.0:
		a.flinch_in -= dt
		if a.flinch_in < 0.0 and a.busy <= 0.0 and a.path.is_empty():
			_once(a, FLINCH)
	if a.drop_v >= 0.0:
		a.drop_v += GRAVITY * dt
		a.y -= a.drop_v * dt
		a.body.position.y = a.y
	if a.taken_in >= 0.0:
		a.taken_in -= dt
		if a.taken_in < 0.0:
			a.locked = false
			a.gone = true
			a.pending.clear()
			_hide(a, true)                # taken away: the act is over, nobody lingers on it
			return
	if a.freeing != null:
		a.free_in -= dt
		if a.free_in <= 0.0:
			_unlock(a.freeing)
			a.freeing = null
	if not a.path.is_empty():
		_walk(a, dt)
		if a.inside:
			return
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
	if a.busy > 0.0 or a.back_to != Vector2.INF:
		return false                  # mid gesture, or on an errand
	match action:
		"walk_to", "carry":
			if a.locked:
				return false
			if action == "carry" and _device != null and b["prop"] != "":
				_carry(a, int(b["slot"]), b["prop"])
				return true
			if _kind == "exile" and a == _victim and int(b["slot"]) < 0 and a.path.is_empty() \
					and a.pos.distance_squared_to(_spot(a, -1)) < 0.25:
				_walk_out(a, anim)       # already at the gate: this walk is out along the road
				return true
			var slot := int(b["slot"])
			_go(a, _spot(a, slot), anim, _face_for(a, slot))
			return true
		"leave":
			if a.locked:
				return false
			_drop_held(a)
			a.going_home = true
			a.rest_anim = "Idle"
			_go(a, a.door, anim, Vector2.INF)
			return true
		"stand":
			var slot := int(b["slot"])
			if not _reach(a, _spot(a, slot), _face_for(a, slot)):
				return false
			a.rest_anim = anim
			if b["prop"] != "":
				_hold(a, b["prop"])
			a.playing = ""
			_rest(a)
			return true
		"gesture", "fall":
			if not a.path.is_empty():
				return false
			if action == "gesture" and anim in WORK and _device != null:
				_errand(a, _work_spot(a), anim)
				return true
			if action == "gesture" and int(b["target"]) >= 0 and _by_id.has(int(b["target"])):
				_face(a, (_by_id[int(b["target"])] as Actor).pos)
			if action == "fall":
				a.rest_anim = ""           # stays down: the last frame holds
				if a == _victim:
					if not _info.is_empty():
						anim = _info["fall"]
					_fell_at = _clock
					a.taken_in = FALLEN_HOLD
					_crowd_flinches()
					if anim == "drop":     # the trapdoor gives: down and out of sight, no pose to hold
						a.drop_v = 0.0
						a.taken_in = DROP_HOLD
						return true
			_once(a, anim)
			return true
		"throw":
			var victim: Actor = _by_id.get(b["target"])
			if victim == null or victim.inside or (victim == _victim and (_rescued or _fell_at >= 0.0)):
				return true                # nobody (left) to throw at: nothing to show
			var slot := int(b["slot"])
			if not _reach(a, _spot(a, slot), _face_for(a, slot)):
				return false
			_throw(a, victim, i, anim, b["prop"])
			return true
		"lock":
			if _device == null:
				return true                # nothing to lock into here
			var spot := _victim_spot()
			if a.pos.distance_squared_to(spot) >= 0.0004:
				if not a.path.is_empty():
					return false
				if a.pos.distance_squared_to(_approach()) < 0.04:
					_climb(a)              # up the steps to their place
				else:
					_go(a, _approach(), a.walk_anim, spot)
				return false
			a.locked = true
			if a == _victim:
				_locked_at = _clock
			a.rest_anim = Props.VICTIM_POSE.get(_info["prop"], anim)   # the device decides the pose: the body has to fit it
			a.y = _device.position.y + float(Props.VICTIM[_info["prop"]].y)
			a.body.position.y = a.y
			a.yaw = atan2(DEVICE_FACING.x, DEVICE_FACING.y)
			a.yaw_goal = a.yaw
			a.body.rotation.y = a.yaw
			a.playing = ""
			_rest(a)
			if _info["prop"] == "pillory":      # the wrists through the board's side holes
				var hole := Vector3(PILLORY_WRIST, Props.PILLORY_HOLES, 0.1) - Props.VICTIM["pillory"] + Vector3(0.0, 0.0, 0.03)
				a.body.hold_hands(hole, Vector3(-hole.x, hole.y, hole.z))
			return true
		"release":
			var victim: Actor = _by_id.get(b["target"])
			if victim == a:                # the player opened it (inject): free at once
				_unlock(a)
				return true
			if victim == null or not victim.locked or (victim == _victim and _rescued):
				return true                # nobody locked in: nothing to open
			var at := _device_at if _device != null else _centre
			if not _reach(a, _beside(a), at):
				return false
			_face(a, at)
			_once(a, anim)
			a.freeing = victim
			a.free_in = a.busy * 0.5     # the lock opens halfway through the gesture
			return true
	push_warning("stage: unknown action " + action)
	return true


## Where a beat's slot is: a crowd slot, or with -1 a spot at the place by role - the device's foot for
## the condemned (the lock takes them up), the bench for a trial, beside the device (or the place) for
## anyone else, so the elder doesn't stand inside the thief.
func _spot(a: Actor, slot: int) -> Vector2:
	if slot >= 0:
		return _slots[slot] if slot < _slots.size() else Sites.slot(_place, slot)
	if _kind == "trial":
		if a == _victim:
			return _centre + ACCUSED_AT
		if a == _authority:
			return _centre + JUDGE_AT
	if a == _victim:
		return _approach() if _device != null else _centre
	return _beside(a)


## What a slot's person faces: the act (the place), their circle's middle at a festival; at a trial the
## accused and the elder face each other.
func _face_for(a: Actor, slot: int) -> Vector2:
	if slot >= 0:
		return _slot_face[slot] if slot < _slot_face.size() else _centre
	if _kind == "trial":
		if a == _victim:
			return _centre + JUDGE_AT
		if a == _authority:
			return _centre + ACCUSED_AT
	if a == _victim and _device != null:
		return _victim_spot()
	return _centre


func _slot_of(id: int) -> int:
	for b: Dictionary in _beats:
		if b["who"] == id and int(b["slot"]) >= 0:
			return int(b["slot"])
	return -1


## Device-space point (x across, y along its facing) on the ground.
func _world(local: Vector2) -> Vector2:
	var side := Vector2(DEVICE_FACING.y, -DEVICE_FACING.x)
	return _device_at + side * local.x + DEVICE_FACING * local.y


func _local(p: Vector2) -> Vector2:
	var d := p - _device_at
	return Vector2(d.dot(Vector2(DEVICE_FACING.y, -DEVICE_FACING.x)), d.dot(DEVICE_FACING))


## The foot of the device's way in (on the ground, outside its walls), and where the condemned ends up.
func _approach() -> Vector2:
	return _world(_info["way_in"][0])


func _victim_spot() -> Vector2:
	var v: Vector3 = Props.VICTIM.get(_info["prop"], Vector3.ZERO)
	return _world(Vector2(v.x, v.z))


## Up the device's way in (steps, a platform) to the condemned's place.
func _climb(a: Actor) -> void:
	var path := PackedVector2Array()
	var way: Array = _info["way_in"]
	for k in range(1, way.size()):
		path.append(_world(way[k]))
	path.append(_victim_spot())
	a.path = path
	a.face = _victim_spot() + DEVICE_FACING
	_loop(a, a.walk_anim, a.pace / float(GAITS[a.walk_anim][1]))


## A spot to the side of the device (or the place), on the side the actor is already on, a little in front.
func _beside(a: Actor) -> Vector2:
	var side := Vector2(DEVICE_FACING.y, -DEVICE_FACING.x)
	if (a.pos - _centre).dot(side) < 0.0:
		side = -side
	return _centre + side * float(_info.get("beside", BESIDE)) + DEVICE_FACING * 0.3


## Where a worker kneels to build at the device: at the side nearer their slot, just outside its walls.
func _work_spot(a: Actor) -> Vector2:
	var walls: Rect2 = _info["walls"]
	var local := _local(a.pos)
	var x := walls.end.x + BODY_RADIUS + 0.15 if local.x >= 0.0 else walls.position.x - BODY_RADIUS - 0.15
	return _world(Vector2(x, clampf(local.y, walls.position.y + 0.3, walls.end.y - 0.3)))


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
	_loop(a, a.walk_anim, a.pace / float(gait[1]))


## An errand: go to `spot`, then do `what` there ("drop" the carried prop, or play an animation once),
## then back to where the actor stood.
func _errand(a: Actor, spot: Vector2, what: String, anim := "Walk") -> void:
	a.back_to = a.pos
	a.back_face = a.face if a.face != Vector2.INF else _centre
	a.errand = what
	_go(a, spot, anim, _centre)


func _go_back(a: Actor) -> void:
	var to := a.back_to
	a.back_to = Vector2.INF
	_go(a, to, "Walk", a.back_face)


## Carrying something to the device (wood to the stake): taken up at the slot, carried to the pile at the
## side facing the carrier, dropped there, and back.
func _carry(a: Actor, slot: int, prop: String) -> void:
	var from := _spot(a, slot) if a.pos.distance_squared_to(_spot(a, slot)) > 0.04 else a.pos
	_hold(a, prop)
	var towards := (from - _device_at).normalized()
	var walls: Rect2 = _info["walls"]
	var drop := _device_at + towards * (maxf(walls.size.x, walls.size.y) * 0.5 + BODY_RADIUS + 0.2)
	_errand(a, drop, "drop", "Walk_Carry")
	a.back_to = from
	a.back_face = _face_for(a, slot)


## Out along the road for good (an exile): past the place's focus, then gone.
func _walk_out(a: Actor, anim: String) -> void:
	var road := (_focus - _centre).normalized() if _focus != _centre else DEVICE_FACING
	_go(a, _focus + road * EXILE_OUT, anim, Vector2.INF)
	a.gone = true


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
	if a.pos.distance_squared_to(a.ground_at) > GROUND_EVERY * GROUND_EVERY:
		a.ground_at = a.pos
		a.ground_y = _ground(a.pos)
	a.y = move_toward(a.y, a.ground_y, CLIMB_RATE * dt)
	a.body.position = Vector3(a.pos.x, a.y, a.pos.y)
	if a.path.is_empty():
		_arrive(a)


func _arrive(a: Actor) -> void:
	a.ground_at = a.pos
	a.ground_y = _ground(a.pos)
	a.y = a.ground_y
	a.body.position.y = a.y
	if a.gone:
		_hide(a, true)                     # out of sight down the road
		return
	if a.going_home:
		a.going_home = false
		if a.pending.is_empty():
			_hide(a, true)                 # indoors (unless there is more to do)
			return
	if a.face != Vector2.INF:
		_face(a, a.face)
	if a.errand != "":
		var what := a.errand
		a.errand = ""
		if what == "drop":
			_drop_held(a, true)
			_go_back(a)
			return
		_once(a, what)                     # the work; back when it is done (_update)
		return
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
	if not hidden:
		a.body.set_detail(1)              # the next detail pass decides; a body hidden by it shows again
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


## Loops an animation at `rate` x the stage speed (VillagerBody.play_loop loops one-shots too), each
## body starting at its own point in the loop, so a crowd doesn't breathe in step.
func _loop(a: Actor, anim: String, rate: float) -> void:
	if a.playing == anim:
		return
	a.playing = anim
	a.body.play_loop(anim, 0.2, _speed * rate, a.id * 0.37)


## One pass of an animation; the actor is busy until it ends (stage seconds = its length).
func _once(a: Actor, anim: String) -> void:
	a.playing = ""
	a.body.play_action(anim, _speed)
	a.busy = a.body.animation_length(anim)


## A prop in the actor's hand (a torch) or carried in front (wood), until dropped or they go home.
func _hold(a: Actor, prop: String) -> void:
	_drop_held(a)
	var node := _make_prop(prop)
	if prop in HELD_IN_HAND:
		a.body.hand_attachment().add_child(node)
		node.rotation_degrees = CharacterVisual.TOOL_GRIP["sword"]
		node.position = CharacterVisual.TOOL_OFFSET + Vector3(0.0, 0.05, 0.0)
	else:
		a.body.add_child(node)
		node.position = CARRIED_AT
		node.rotation.y = PI / 2.0         # across the chest
	a.held = node


## Lets go of a held prop: onto the ground in front (the wood on the pile) or gone with them.
func _drop_held(a: Actor, on_ground := false) -> void:
	if a.held == null:
		return
	if on_ground:
		var at := a.held.global_position
		a.held.get_parent().remove_child(a.held)
		add_child(a.held)
		var ahead := Vector2(sin(a.yaw), cos(a.yaw)) * 0.45
		var p := Vector2(a.pos.x, a.pos.y) + ahead
		a.held.global_position = Vector3(p.x, _shape.height_at(p.x, p.y) + 0.06, p.y)
		a.held.rotation = Vector3(0.0, a.yaw + PI / 2.0 + sin(at.x * 7.0) * 0.5, 0.0)
	else:
		a.held.queue_free()
	a.held = null


func _unlock(v: Actor) -> void:
	if not v.locked:
		return
	v.body.release_hands()
	v.locked = false
	v.rest_anim = "Idle"
	_released = _clock
	if v.busy <= 0.0:
		v.playing = ""
		_rest(v)


## The fall: everyone watching flinches, one after another.
func _crowd_flinches() -> void:
	for a in _actors:
		if a != _victim and not a.inside and a.path.is_empty():
			a.flinch_in = fposmod(a.id * 0.37, 1.0) * FLINCH_SPREAD


func _throw(a: Actor, victim: Actor, beat: int, anim: String, prop: String) -> void:
	_face(a, victim.pos)
	a.yaw = a.yaw_goal                     # square up at once, so the prop leaves from the throwing hand
	a.body.rotation.y = a.yaw
	_once(a, anim)
	var s := Shot.new()
	s.beat = beat
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
## animations are made standing and would pop them up out of the device).
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
	if _shields(a, s.victim):
		s.shielded = true
		s.to = _player.global_position + Vector3(0.0, PLAYER_CHEST, 0.0)
	var dist := s.from.distance_to(s.to)
	s.dur = maxf(dist / THROW_SPEED, 0.18)
	s.arc = 0.25 + dist * 0.1
	s.spin = Vector3(7.0, 3.0, 5.0)
	s.node = _make_prop(s.prop)
	add_child(s.node)
	if s.node is GeometryInstance3D:
		(s.node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.node.position = s.from
	s.phase = 1
	s.t = 0.0


## Whether the player stands in the throw's line, between the thrower and the victim, while a rescue
## is open.
func _shields(thrower: Actor, victim: Actor) -> bool:
	if _player == null or not is_instance_valid(_player) or victim != _victim or not rescue_open():
		return false
	if external_clock and not _player.can_be_targeted():
		return false
	var p := Vector2(_player.global_position.x, _player.global_position.z)
	var line := victim.pos - thrower.pos
	var u := (p - thrower.pos).dot(line) / maxf(line.length_squared(), 0.0001)
	if u < 0.12 or u > 0.92:
		return false
	return p.distance_to(thrower.pos + line * u) < SHIELD_REACH


func _land_on_head(s: Shot) -> void:
	if s.shielded:
		var contact := is_instance_valid(_player) and (_player.global_position + Vector3(0, PLAYER_CHEST, 0)).distance_to(s.to) < 0.8
		if contact and action_authority.is_valid() and _player.can_be_targeted():
			var result: Dictionary = action_authority.call("shield", {"beat": s.beat, "intercepted": true})
			if result.get("accepted", false):
				_player.visual.flash()
		elif contact and not external_clock:
			_player.visual.flash()
			player_intervened.emit("shield", int(minute()))
	else:
		_hit(s.victim, s.react, s.thrower)
	# Then it carries on in the throw's direction and drops to the ground.
	var ahead := Vector2(s.to.x - s.from.x, s.to.z - s.from.z).normalized()
	var k := float(_throws + s.thrower.id)
	var carry := float(CARRY_ON.get(s.prop, 0.6)) * (0.3 if s.shielded else 1.0)
	var ground := Vector2(s.to.x, s.to.z) + ahead * carry + Vector2(-ahead.y, ahead.x) * sin(k) * 0.35
	s.from = s.to
	s.to = Vector3(ground.x, _ground(ground) + _lift(s.node), ground.y)   # the ground, or the device's platform
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
		s.node.position.y = _ground(Vector2(s.node.position.x, s.node.position.z)) + 0.02
	else:
		s.node.rotation.x = 0.0             # lies the right way up, still turned where it rolled
		s.node.rotation.z = 0.0
	_lying.append(s)
	if _lying.size() > MAX_LYING:
		_lying[0].node.queue_free()
		_lying.remove_at(0)


## How high a prop's origin sits above its lowest point, so it rests on the ground rather than in it.
func _lift(node: Node3D) -> float:
	var mi := node as MeshInstance3D
	if mi == null:
		for c in node.get_children():
			if c is MeshInstance3D:
				mi = c as MeshInstance3D
				break
	if mi == null:
		return 0.0
	var own := mi.position.y if mi != node else 0.0
	return maxf(-mi.get_aabb().position.y * mi.scale.y - own, 0.0)


func _age_lying(delta: float) -> void:
	while not _lying.is_empty() and _lying[0].life <= delta:
		_lying[0].node.queue_free()
		_lying.remove_at(0)
	for s in _lying:
		s.life -= delta


## The fire: lit at its minute, grows to FIRE_LOW, flares to full once the fall has begun; the flames
## flicker (two sines), the smoke rises.
func _burn(dt: float, now: float) -> void:
	if _fire == null:
		if now < _fire_at:
			return
		_fire = _make_prop("fire")
		add_child(_fire)
		_fire.position = _device.position
		(_fire.get_node("Smoke") as CPUParticles3D).emitting = true
		_fire_t = 0.0
	_fire_t += dt
	if _fell_at >= 0.0:
		_flare = minf(_flare + dt / 1.5, 1.0)
	var t := _fire_t
	var height := minf(t / FIRE_GROW, 1.0) * lerpf(FIRE_LOW, 1.0, _flare)
	var flicker := 1.0 + 0.08 * sin(t * 13.0) + 0.05 * sin(t * 23.7)
	var flames := _fire.get_node("Flames") as Node3D
	flames.scale = Vector3(1.0 + 0.06 * sin(t * 9.1), maxf(height * flicker, 0.01), 1.0 + 0.06 * cos(t * 8.3))
	flames.rotation.y = t * 0.4


## The "Free" button at the locked victim: offered (in the "interactable" group the player looks in)
## while a rescue is open.
func _offer_free() -> void:
	var can := _victim != null and _victim.locked and _player != null and rescue_open()
	if _free_spot == null:
		if not can:
			return
		_free_spot = UseSpot.new()
		add_child(_free_spot)
		var at := _victim.pos
		_free_spot.setup(Vector3(at.x, _victim.y, at.y), "Free", _player_frees, FREE_REACH)
		_free_spot.set_meta("village_action", true)
	var offered := _free_spot.is_in_group("interactable")
	if can and not offered:
		_free_spot.add_to_group("interactable")
	elif not can and offered:
		_free_spot.remove_from_group("interactable")


## The player freed the victim: the lock opens (a release the stage injects), they get down and go home,
## and the crowd nearest turns on the player with a shake of the head.
func _player_frees() -> void:
	if not rescue_open() or not _victim.locked:
		return
	if action_authority.is_valid():
		var result: Dictionary = action_authority.call("free", {})
		if not result.get("accepted", false):
			return
	show_rescue()


func show_rescue() -> void:
	if _rescued or _victim == null:
		return
	var now := int(ceil(minute()))
	_rescued = true
	if external_clock:
		_victim.door = Vector2(-70.0, -40.0) # same refuge as authoritative resident memory
		for shot in _shots:
			if is_instance_valid(shot.node):
				shot.node.queue_free()
		_shots.clear()
		_fire_at = -1.0
		if is_instance_valid(_fire):
			_fire.queue_free()
			_fire = null
	_victim.pending.clear()
	if _victim.body != null:
		_unlock(_victim) # accepted restraint change is visible immediately, before a gesture finishes
	inject({"at": now, "who": _victim.id, "do": "release", "target": _victim.id, "anim": "Interact"})
	inject({"at": now + 1, "who": _victim.id, "do": "leave", "anim": "Jog_Fwd"})
	_by_near.clear()
	for a in _actors:
		if a != _victim and not a.inside and a.path.is_empty() and a != _authority:
			_by_near.append(a)
	var from := _victim.pos
	_by_near.sort_custom(func(p: Actor, q: Actor) -> bool: return p.pos.distance_squared_to(from) < q.pos.distance_squared_to(from))
	for k in mini(TURN_NO, _by_near.size()):
		var a := _by_near[k]
		a.rest_anim = "Idle_No"
		a.playing = ""
		if a.busy <= 0.0:
			_rest(a)
	_notes.append("rescue: the player freed %s at minute %d" % [_victim.person.get("name", "?"), now])
	player_intervened.emit("free", now)


func show_outcome(outcome: String, alive: bool, present: bool) -> void:
	if _victim == null:
		return
	_outcome = outcome
	_rescued = true # suppress remaining predicted victim beats and incoming throws
	_victim.pending.clear()
	_victim.path.clear()
	_victim.busy = 0.0
	_victim.back_to = Vector2.INF
	for a in _actors:
		a.freeing = null
	for shot in _shots:
		if is_instance_valid(shot.node):
			shot.node.queue_free()
	_shots.clear()
	if alive:
		_fire_at = -1.0
		if is_instance_valid(_fire):
			_fire.queue_free()
			_fire = null
		_unlock(_victim)
		if not present:
			_victim.door = Vector2(-70.0, -40.0)
		_go(_victim, _victim.door, "Walk", Vector2.INF)
		_victim.going_home = true
	else:
		inject({"at": int(ceil(minute())), "who": _victim.id, "do": "fall", "anim": "Death01"})
		_begin(_victim, _beats.size() - 1) # visible fall begins with the committed consequence


func show_verdict(outcome: String) -> void:
	if _authority == null or _victim == null:
		return
	_outcome = outcome
	var now := int(ceil(minute()))
	inject({"at": now, "who": _authority.id, "do": "gesture", "target": _victim.id, "anim": "Idle_No" if outcome == "acquitted" else "Yes"})
	if outcome == "fell":
		inject({"at": now, "who": _victim.id, "do": "fall", "anim": "Death01"})
	else:
		inject({"at": now + 2, "who": _victim.id, "do": "leave", "anim": "Walk"})


## Where a body stands at p: the ground, or a device's floor (platform, steps) when it is on one.
func _ground(p: Vector2) -> float:
	if _device != null:
		var l := _local(p)
		var best := -1.0
		for f: Array in _info["floors"]:
			if l.x >= f[0] and l.x <= f[2] and l.y >= f[1] and l.y <= f[3]:
				var h := lerpf(f[4], f[5], (l.y - f[1]) / maxf(f[3] - f[1], 0.001))
				best = maxf(best, h)
		if best >= 0.0:
			return _device.position.y + best
	return _shape.height_at(p.x, p.y)


## Detail by distance to the camera: the NEAR_FULL nearest bodies in view at full detail, the rest in
## view stepped at ~10 Hz without shadows, bodies well out of view hidden (tier 2). No camera: all full.
func _set_details() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	_by_near.clear()
	for a in _actors:
		if a.body != null and not a.inside:
			_by_near.append(a)
	if camera == null:
		for a in _by_near:
			a.body.set_detail(0)
		return
	var eye := camera.global_position
	var view := get_viewport().get_visible_rect().size
	var margin := view.x * VIEW_MARGIN
	var shown := 0
	_by_near.sort_custom(func(p: Actor, q: Actor) -> bool:
		return eye.distance_squared_to(p.body.position) < eye.distance_squared_to(q.body.position))
	for a in _by_near:
		var chest := a.body.position + Vector3(0.0, 1.0, 0.0)
		var at := camera.unproject_position(chest)
		var in_view := not camera.is_position_behind(chest) and at.x > -margin and at.x < view.x + margin \
			and at.y > -margin and at.y < view.y + margin
		if not in_view:
			a.body.set_detail(2)
		else:
			a.body.set_detail(0 if shown < NEAR_FULL else 1)
			shown += 1


## The walls bodies walk round: every house footprint (world/village.gd), the merchant's stall, the
## workbench, the device and the bench, each grown by a body's radius.
func _build_blocks() -> void:
	_blocks.clear()
	for h: Dictionary in Houses.HOUSES:
		var size := Vector2(h["size"].x, h["size"].z)
		_blocks.append(Rect2(h["at"] - size * 0.5, size).grow(BODY_RADIUS))
	_blocks.append(Rect2(Houses.MERCHANT_AT - Vector2(0.6, 0.6), Vector2(1.2, 1.2)).grow(BODY_RADIUS))
	_blocks.append(WORKBENCH.grow(BODY_RADIUS))
	if _device != null:
		var w: Rect2 = _info["walls"]
		var a := _world(w.position)
		var b := _world(w.end)
		_blocks.append(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()).grow(BODY_RADIUS))
	if _bench != null:
		_blocks.append(Rect2(_centre + BENCH_AT - BENCH_HALF, BENCH_HALF * 2.0).grow(BODY_RADIUS))


## A walk from `from` to `to` that goes round the blocks: the shortest way through the corners of the
## blocks near the line (a small visibility graph, made once per walk, not per frame). Ends that stand
## inside a block (a doorstep against its own wall) step out and in; the condemned, up on the device,
## first come down its way in.
func _route(from: Vector2, to: Vector2) -> PackedVector2Array:
	_routes += 1
	var path := PackedVector2Array()
	if _device != null and (_info["walls"] as Rect2).has_point(_local(from)):
		var way: Array = _info["way_in"]
		for k in range(way.size() - 1, -1, -1):
			path.append(_world(way[k]))
		from = path[path.size() - 1]
	var start := _outside(from)
	var end := _outside(to)
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
