extends Node
## Steps everyone on foot together (Pass 3, L1, L2): every mover's wish, one steering step for the whole crowd, then each
## body drawn where the step put it. It avoids everything else on foot too: the player, Enea's animals and characters,
## and anyone a scene or a reaction is moving. Generic: it knows bodies and movers, not villages.
##
##   crowd.add(mover) / crowd.remove(mover)
##   crowd.blocks = [Rect2, ...]       walls nobody ends a step inside (houses, stalls)
##   crowd.others = func() -> Array    anything else on foot this frame: [[Node3D, radius], ...]
##   crowd.spaces = func() -> Array    the middles of conversations: [[Vector2, radius, group], ...] (walked round by
##                                     all but their own people: Steer.SPACE)
##   crowd.focus = Node3D              where the eye is (the player): avoidance is worked out within NEAR of it; further
##                                     away people only follow their way (the first cut in the plan's L11 budget)
##   crowd.paused = true               everyone holds still (the village clock has stopped): their bodies at rest, their
##                                     way and speed kept, so they carry on as they were when time goes on
##   crowd.cost_usec                   this frame's work
##
##   movers' want() â”€â”€> Agents (near ones + others) â”€â”€steer.stepâ”€â”€> movers' settle()
##                     far ones: their want, eased by their acceleration, no avoidance
##                     indoors ones: their wait counts down; they step out once the doorstep is clear

const Steer := preload("res://scripts/studio/people/steer.gd")
const Prof := preload("res://scripts/studio/people/prof.gd")
const Mover := preload("res://scripts/studio/people/mover.gd")
const Persona := preload("res://scripts/studio/people/persona.gd")
const Nearby := preload("res://scripts/studio/people/nearby.gd")
var nearby := Nearby.new() # P4: the same snapshot used by steering, senses and offer reach.

const NEAR := 35.0            # metres from the focus: avoidance is worked out
const JUDGE_HZ := 20.0        # times a second each person re-judges their neighbours
const DOORSTEP := 0.8         # metres: someone this close to a door keeps the next one inside a moment longer
const DOOR_WAIT := 0.35       # seconds, about: how long they wait before looking again
const DOOR_NEAR := 1.5        # metres from a door they go in at: its wall is not turned from (it is where they go)
const ROOM_OFF_WALL := 0.2    # metres off a wall a body can stand (stepping out of someone's way)
const SETTLE_PASSES := 6      # hard passes for bodies just put somewhere (in the same frame: never seen sliding apart)

var blocks: Array[Rect2] = []
var others := Callable()
var spaces := Callable()
var focus: Node3D
var paused := false
var drawn_only := true        # step only bodies drawn in the scene (false: bare bodies, as people_test.gd steps them)
var cost_usec := 0
var undone := 0               # overlaps the last hard pass had to undo (a measure: a good crowd needs few)

var _movers: Array = []
var _last := {}               # instance id -> last position of an other (its velocity is worked out from it)
var _ag := Steer.Agents.new()
var _steps := 0


func _ready() -> void:
	process_priority = 10     # after whoever directs the movers this frame, before anything that watches them


func add(mover: Mover) -> void:
	if not _movers.has(mover):
		_movers.append(mover)
		mover.clear = func(p: Vector2) -> bool: return Steer._wall(p, blocks).z >= ROOM_OFF_WALL   # (room to step to)
		mover.sight = func(a: Vector2, b: Vector2) -> bool: return Steer.sees(a, b, blocks, Steer.WALL_NEAR)


func remove(mover: Mover) -> void:
	_movers.erase(mover)


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	if paused or delta <= 0.0:
		for mv: Mover in _movers:
			if mv.active and is_instance_valid(mv.body) and mv.body.has_method("play_motion"):
				mv.body.play_motion(0.0)     # at rest while time stands still (the mover keeps its speed)
		cost_usec = Time.get_ticks_usec() - t0
		return
	var dt := minf(delta, 0.1)          # a long frame is not a long stride
	var eye := Vector2.INF
	if is_instance_valid(focus):
		eye = Vector2(focus.global_position.x, focus.global_position.z)
	var ag := _ag
	_clear(ag)
	var near: Array = []
	var metadata: Array = []
	var extra: Array = []
	var inside: Array = []
	var placed := false
	for mv: Mover in _movers:
		if is_instance_valid(mv.body) and (not mv.active or mv.indoors or (drawn_only and not mv.body.is_visible_in_tree())):
			extra.append(mv)
		if mv.active and mv.indoors:
			if mv.walking():
				inside.append(mv)        # waiting to step out
			continue                     # (or in, at home: nothing to step)
		if not mv.active or not is_instance_valid(mv.body) or (drawn_only and not mv.body.is_visible_in_tree()):
			continue
		placed = placed or mv.placed
		mv.placed = false
		if not mv.can_move():
			mv.pos=Vector2(mv.body.position.x,mv.body.position.z)
		var wish := mv.want(dt)
		if eye != Vector2.INF and mv.pos.distance_squared_to(eye) > NEAR * NEAR:
			_alone(mv, wish, dt)        # far: follows its way, eased, no avoidance
			extra.append(mv)
			continue
		var accel := mv.accel_now()
		var brake := mv.vel.length() - accel * dt      # the top falls no faster than they can brake
		var i := ag.add(mv.pos, float(mv.m.radius), float(mv.m.space), float(mv.m.horizon), accel,
			maxf(maxf(wish.length() * 1.15, brake), 0.6), mv.kind(), mv.relax_now())
		ag.vel[i] = mv.vel
		ag.want[i] = wish
		ag.group[i] = mv.group
		ag.door[i] = 1 if mv.enters and mv._left() < DOOR_NEAR else 0
		ag.avoid[i] = mv.avoid
		near.append(mv)
		metadata.append({"key": mv.actor_key if mv.actor_key != "" else "body:%d" % mv.body.get_instance_id(), "mover": mv, "body": mv.body, "velocity":mv.vel,"radius":float(mv.m.radius),"fixed":not mv.can_move()})
	var tq := Prof.add("crowd.wants", t0)
	var seen := {}
	if others.is_valid():
		for pair: Array in others.call():
			if not is_instance_valid(pair[0]):
				continue                     # freed since it was listed (a creature cleared, a body gone)
			var node: Node3D = pair[0]
			var at := node.global_position if node.is_inside_tree() else node.position
			var p := Vector2(at.x, at.z)
			if eye != Vector2.INF and p.distance_squared_to(eye) > (NEAR + 5.0) * (NEAR + 5.0):
				continue
			var key := node.get_instance_id()
			seen[key] = p
			var before: Vector2 = _last.get(key, p)
			var i := ag.add(p, float(pair[1]), 0.0, 0.0, 0.0, 0.0, Steer.OTHER)
			ag.vel[i] = (p - before) / dt if before.distance_to(p) < 3.0 else Vector2.ZERO
			metadata.append({"key": str(node.get_meta("people_actor","player:local" if node.is_in_group("player") else "body:%d" % node.get_instance_id())), "body": node})
	_last = seen
	if spaces.is_valid():
		for s: Array in spaces.call():
			var c: Vector2 = s[0]
			if eye != Vector2.INF and c.distance_squared_to(eye) > NEAR * NEAR:
				continue
			var i := ag.add(c, float(s[1]), 0.0, 0.0, 0.0, 0.0, Steer.SPACE)
			ag.group[i] = int(s[2])
			metadata.append({"key": "space:%d" % i})
	for mv: Mover in extra:
		var actual := mv.body.global_position
		ag.add(Vector2(actual.x,actual.z), 0.0, 0.0, 0.0, 0.0, 0.0, Steer.SPACE)
		metadata.append({"key": mv.actor_key if mv.actor_key != "" else "body:%d" % mv.body.get_instance_id(), "mover": mv, "body": mv.body, "sensing_only": true,
			"velocity":Vector2.ZERO,"radius":float(mv.m.radius),"fixed":true})
	tq = Prof.add("crowd.others", tq)
	nearby.snapshot(ag.pos, metadata)
	tq = Prof.add("crowd.snapshot", tq)
	# S5 preferred room is asymmetric and measured by Residents. Bind actual bodies to this same grid,
	# omitting duplicate sensing-only rows. This only changes avoidance, never a mover's path/owner.
	var physical := {}
	for i in metadata.size():
		var node: Node3D=metadata[i].get("body")
		if is_instance_valid(node) and not metadata[i].get("sensing_only",false) and not physical.has(node.get_instance_id()):
			physical[node.get_instance_id()]=i
	for i in near.size():
		var mv: Mover=near[i]
		for instance: int in mv.regard:
			if physical.has(instance) and int(physical[instance])!=i:
				ag.regard[i][physical[instance]]=clampf(float(mv.regard[instance]),0.6,4.0)
	tq = Prof.add("crowd.regard", tq)
	_steps += 1
	ag.steps = _steps
	var every := maxi(1, roundi(1.0 / (dt * JUDGE_HZ)))
	undone = Steer.step(ag, dt, [], every, blocks, nearby.cells)
	tq = Prof.add("crowd.steer", tq)
	var before := ag.pos.duplicate()             # (what the walls do is told apart from what people do)
	if not blocks.is_empty():
		Steer._out_of(ag, blocks)
	if placed:
		var grid := Steer.grid_of(ag)
		for k in SETTLE_PASSES:
			if Steer._separate(ag, grid) == 0:
				break
		if not blocks.is_empty():
			Steer._out_of(ag, blocks)
	_doors(inside, ag, eye, dt)
	tq = Prof.add("crowd.walls_doors", tq)
	for i in near.size():
		var mv: Mover = near[i]
		if not mv.can_move():
			mv.vel=Vector2.ZERO
			ag.pos[i]=mv.pos
			mv.settle(dt)
			continue
		if mv.exact:                     # a scripted move keeps to its own line; the others gave way to it
			_alone(mv, ag.want[i], dt)
			continue
		if (ag.pos[i] - mv.pos - ag.vel[i] * dt).length() > 0.01:
			mv.shoved = 0.0
			mv.shoved_by = "wall" if ag.pos[i].distance_squared_to(before[i]) > 0.000001 else "person"
		else:
			mv.shoved += dt
		mv.pos = ag.pos[i]
		mv.vel = ag.vel[i]
		mv.avoid = ag.avoid[i]
		mv.threat = ag.threat[i]
		mv.settle(dt)
	tq = Prof.add("crowd.settle", tq)
	# Publish actual current geometry through the SAME P4 grid after integration.
	for i in metadata.size():
		var node: Node3D=metadata[i].get("body")
		if is_instance_valid(node):
			var actual := node.global_position
			ag.pos[i]=Vector2(actual.x,actual.z)
	nearby.snapshot(ag.pos,metadata)
	Prof.add("crowd.snapshot2", tq)
	cost_usec = Time.get_ticks_usec() - t0


## Those waiting behind a door: when their moment comes, they step out if nobody is on the doorstep (anyone near, or
## someone who stepped out of the same door this frame), else wait a moment more. Far from the eye, no queue.
func _doors(inside: Array, ag: Steer.Agents, eye: Vector2, dt: float) -> void:
	var out: Array[Vector2] = []
	for mv: Mover in inside:
		mv.seconds -= dt
		mv.wait -= dt
		if mv.wait > 0.0:
			continue
		var clear := true
		if eye == Vector2.INF or mv.pos.distance_squared_to(eye) <= NEAR * NEAR:
			for i in ag.size:
				if ag.kind[i] != Steer.SPACE and ag.pos[i].distance_squared_to(mv.pos) < DOORSTEP * DOORSTEP:
					clear = false
					break
			for p in out:
				if p.distance_squared_to(mv.pos) < DOORSTEP * DOORSTEP:
					clear = false
		if clear:
			mv.indoors = false
			mv.wait = 0.0
			out.append(mv.pos)
		else:
			mv.wait = DOOR_WAIT * (0.7 + 0.6 * Persona._noise(int(mv.m.key), _steps % 97))


## A mover nobody needs to steer round: its wish, eased by its acceleration.
func _alone(mv: Mover, wish: Vector2, dt: float) -> void:
	if not mv.can_move():
		mv.vel=Vector2.ZERO
		mv.settle(dt)
		return
	var dv := wish - mv.vel
	var most := mv.accel_now() * dt
	mv.vel += dv.limit_length(most) if not mv.exact else dv
	mv.pos += mv.vel * dt
	mv.settle(dt)


## Whether a point is inside a wall.
func in_wall(p: Vector2) -> bool:
	for r in blocks:
		if r.has_point(p):
			return true
	return false


static func _clear(ag: Steer.Agents) -> void:
	ag.pos.clear()
	ag.vel.clear()
	ag.want.clear()
	ag.avoid.clear()
	ag.body.clear()
	ag.space.clear()
	ag.horizon.clear()
	ag.accel.clear()
	ag.top.clear()
	ag.relax.clear()
	ag.kind.clear()
	ag.group.clear()
	ag.threat.clear()
	ag.regard.clear()
	ag.door.clear()
	ag.size = 0
