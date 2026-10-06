extends RefCounted
## C4: Dictionary steps {op,...} discover people/steps/*.gd. world {port,current()->saved phase,phase(next)}
## requests checked semantic progress before starting the next primitive. id is an opaque actor ref.
## Transient paths/elapsed time rebuild from the actual body. The Array steps below serve unmigrated content.
## Plays one person's reaction (plan LIVELY-VILLAGE 3.1): a list of steps on their mover and body, one after another,
## at their own pace. Generic: a mover, a body and what the director answers (`world`), not villages.
##
##   var p := Performer.new(id, mover, body, steps, world)
##   p.update(dt) -> bool       true once the steps are done (or a target is gone and nothing is left to do)
##
## Steps (each an Array, its name first):
##   ["face", at]                   turn to a target and stand
##   ["clip", name, (speed)]        a one-shot animation, waited out (at most CLIP_MOST)
##   ["loop", name, seconds]        an animation looped standing, this long
##   ["nod"] / ["wave"]             a nod, a wave of the hand (a pose layer: walking or standing)
##   ["say", text]                  a line aloud ("" says nothing)
##   ["wait", seconds]              stand as they are
##   ["go", at, pace, (short)]      walk there (pace: stroll, walk, hurry, jog, run); there when `short` metres off
##   ["near", at, metres, pace]     to within metres of a target that may be moving (aimed again every REAIM)
##   ["follow", at, seconds]        a step beside and behind a moving target, this long
##   ["back", at, metres]           backing off from a target, facing it
##   ["knot", seconds]              stand in their knot (the director's: others who chose to talk it over), facing
##                                  its middle, talking now and then, this long
##   ["home", pace]                 to their own door and in
##   ["do", what]                   something done to the world at this moment (the director's: "take" a thing)
## Targets: "subject", "place", "player", "home", "away" (a few metres on from the place, the way they stand), "knot",
## "node" (a thing in the cue: an enemy, a carcass), a person's id (int) or a point (Vector2). The director resolves
## them (world.at): Vector2.INF when gone.
##
##   world  {"at": (target, id) -> Vector2, "route": (a, b) -> PackedVector2Array, "say": (id, text) -> void,
##           "knot": (id) -> Dictionary {centre: Vector2, spot: Vector2, group: int}, "murmur": (id, group, s) -> void,
##           "do": (id, what) -> void (optional)}
const CLIP_MOST := 3.0       # seconds a one-shot is waited out, at most
const REAIM := 0.7           # seconds between aims at a moving target
const BESIDE := 1.1          # metres to the side of someone walked beside
const TALK_EVERY := 4.0      # seconds, about, between a knot member's words or murmurs
const FIXED := ["place", "home", "away"]   # targets that stay put: resolved once a step ("away" asks for a route)

var id: Variant = -1
const Modules := preload("res://scripts/studio/people/modules.gd")
var _primitives := {}
var _primitive_state := {}
var _semantic_started := -1
var _semantic_done := false
var mover                    # people/mover.gd (or any with its pos, go, hold, face, arrived...)
var body                     # a VillagerBody (or any with play_action, play_loop, nod, wave, animation_length)
var steps: Array = []
var world: Dictionary
var step := -1               # the step playing now
var age := 0.0               # seconds since the reaction began
var _t := 0.0                # seconds into the step
var _aim := 0.0              # seconds to the next aim
var _talk := 0.0
var _goal := Vector2.INF     # a walk's goal, as resolved when it began


func _init(the_id: Variant, the_mover: Object, the_body: Object, the_steps: Array, the_world: Dictionary) -> void:
	id = the_id
	mover = the_mover
	body = the_body
	steps = the_steps
	world = the_world
	if not steps.is_empty() and steps[0] is Dictionary:
		_primitives = Modules.discover("res://scripts/studio/people/steps/")


func update(dt: float) -> bool:
	if not _primitives.is_empty():
		return _semantic(dt)
	age += dt
	if step < 0 or _done_with(dt):
		step += 1
		while step < steps.size() and not _begin(steps[step]):
			step += 1                        # (a step with nothing to do: a gone target, an empty line)
		_t = 0.0
		if step >= steps.size():
			return true
	return false

## C4 saved semantic phases are checked by the owner before this runner starts the next primitive.
## Transient elapsed time stays here; restore re-aims travel from the actual position.
func _semantic(dt: float) -> bool:
	var phase := int(world.current.call())
	if phase >= steps.size():
		return true
	if phase != _semantic_started:
		var key := str(steps[phase].op)
		if not _primitives.has(key):
			push_error("unknown behaviour primitive: " + key)
			return false
		_primitive_state = _primitives[key].new().begin(world.port,steps[phase])
		_semantic_started = phase
		_semantic_done = false
	if not _semantic_done:
		_semantic_done = _primitives[str(steps[phase].op)].new().update(world.port,steps[phase],_primitive_state,dt)
	if _semantic_done:
		world.phase.call(phase+1)
	return false


## Starts a step; false: nothing to do (skip it).
func _begin(s: Array) -> bool:
	_aim = 0.0
	match str(s[0]):
		"face":
			var at: Vector2 = world.at.call(s[1], id)
			if at == Vector2.INF:
				return false
			mover.hold(mover.pos, at)
		"clip":
			if not mover.arrived:
				mover.hold(mover.pos, mover.face_at)
			body.play_action(str(s[1]), float(s[2]) if s.size() > 2 else 1.0)
		"loop":
			mover.hold(mover.pos, mover.face_at)
			body.play_loop(str(s[1]), 0.25, 1.0, float(id % 7) * 0.13)
		"nod":
			body.nod()
		"wave":
			body.wave()
		"say":
			if str(s[1]) == "":
				return false
			world.say.call(id, str(s[1]))
		"wait":
			pass
		"do":
			if not world.has("do"):
				return false
			world.do.call(id, str(s[1]))
		"go", "home":
			var at: Vector2 = world.at.call(s[1] if str(s[0]) == "go" else "home", id)
			if at == Vector2.INF:
				return false
			var pace := str(s[2]) if str(s[0]) == "go" else str(s[1]) if s.size() > 1 else "walk"
			_goal = at
			mover.go(world.route.call(mover.pos, at), INF, pace)
			if str(s[0]) == "home":
				mover.enters = true
		"near", "follow":
			if world.at.call(s[1], id) == Vector2.INF:
				return false
		"back":
			var at: Vector2 = world.at.call(s[1], id)
			if at == Vector2.INF:
				return false
			var away: Vector2 = mover.pos - at
			away = away.normalized() if away.length() > 0.01 else Vector2(0.0, 1.0)
			mover.go(PackedVector2Array([mover.pos + away * float(s[2])]), INF, "walk")
			mover.backing = true
			mover.face_at = at
		"knot":
			var k: Dictionary = world.knot.call(id)
			if k.is_empty():
				return false
			mover.go(world.route.call(mover.pos, k.spot), INF, "walk")
			mover.face_at = k.centre
			_talk = float(id % 5) * 0.8
		_:
			return false
	return true


## The step playing now is over.
func _done_with(dt: float) -> bool:
	_t += dt
	var s: Array = steps[step]
	match str(s[0]):
		"face":
			return _t >= 0.6
		"clip":
			return _t >= minf(body.animation_length(str(s[1])) / (float(s[2]) if s.size() > 2 else 1.0), CLIP_MOST)
		"loop", "wait":
			return _t >= float(s[2] if str(s[0]) == "loop" else s[1])
		"nod", "wave", "say", "do":
			return true
		"go":
			var short := float(s[3]) if s.size() > 3 else 0.0
			var at: Vector2 = _goal if s[1] is Vector2 or str(s[1]) in FIXED else world.at.call(s[1], id)
			return mover.arrived or at == Vector2.INF or (short > 0.0 and mover.pos.distance_to(at) <= short)
		"home":
			return mover.indoors or (mover.arrived and _t > 0.5)
		"near":
			var at: Vector2 = world.at.call(s[1], id)
			if at == Vector2.INF or mover.pos.distance_to(at) <= float(s[2]):
				mover.hold(mover.pos, at)
				return true
			_aim -= dt
			if _aim <= 0.0:
				_aim = REAIM
				mover.go(world.route.call(mover.pos, at), INF, str(s[3]))
			return _t > 40.0
		"follow":
			var at: Vector2 = world.at.call(s[1], id)
			if at == Vector2.INF or _t >= float(s[2]):
				return true
			_aim -= dt
			if _aim <= 0.0:
				_aim = REAIM
				var way: Vector2 = at - mover.pos
				if way.length() > BESIDE * 1.6:
					var side := way.normalized().orthogonal() * (BESIDE if id % 2 == 0 else -BESIDE)
					mover.go(world.route.call(mover.pos, at + side - way.normalized() * 0.4), INF, "hurry" if way.length() > 4.0 else "walk")
				else:
					mover.hold(mover.pos, at)
			return false
		"back":
			if mover.arrived:
				mover.backing = false
				return true
			return _t > 4.0
		"knot":
			var k: Dictionary = world.knot.call(id)
			if k.is_empty() or _t >= float(s[1]):
				return true
			if mover.arrived:
				mover.face(k.centre)
				_talk -= dt
				if _talk <= 0.0:
					_talk = TALK_EVERY * (0.7 + 0.6 * float((id * 37 + int(_t)) % 10) / 10.0)
					world.murmur.call(id, int(k.group), 2.0)
					if int(_t) % 3 == id % 3:
						body.play_action("Idle_Talking" if (id + int(_t)) % 4 != 0 else "Yes", 1.0)
			return false
	return true


## Lets go of the body as it is (the reaction is over or taken): standing, nothing held.
func stop() -> void:
	mover.backing = false
	if not mover.indoors and mover.walking():
		mover.hold(mover.pos, Vector2.INF)
