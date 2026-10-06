extends RefCounted
## One body's way of getting about (Pass 3, L1-L4). Whoever directs the body - the day's timetable, a reaction, a scene -
## says where to go, by when and how; the mover gets there itself, at the person's own pace, through the crowd
## (crowd.gd steps every mover together). Presentation only: the rules never read where a body is.
##
##   mover.go(path, seconds, style, delay)   walk a path (waypoints; the last is the goal). seconds: the time it should
##                                           take (INF: no hurry); style: "" picks one from the time (persona.gd)
##   mover.hold(at, face)                    stand at a spot, facing a point (Vector2.INF: as they are)
##   mover.face(at)                          turn to a point (standing)
##   mover.place(at, yaw)                    be somewhere at once (out of a door, after the clock jumped)
##   mover.backing = true                    walk backwards, facing `face_at` (backing off from someone)
##   mover.indoors = true                    (after go) behind a door until it sets off: not drawn, not in anyone's way;
##                                           it steps out when its wait is over and the doorstep is clear (crowd.gd), so
##                                           a household leaves one at a time, never a heap on the step
##   mover.enters = true                     (after go) the goal is a door they go in at: within ENTER of it they are
##                                           in (indoors, arrived), and the step is free for the next one home
##   mover.gate = func() -> bool             (after go) may they set off now (their way out of a crowd is clear)? asked
##                                           when the wait is over; no: they wait a moment more (GATE_GIVE_UP at most)
##   mover.lead = other; lead_side = 1       walk beside `other` while they walk (side 1 their left, 2 their right);
##                                           their own way again once `other` stops or lead is cleared
##   mover.pace_cap = 1.1                    never faster than this (keeping to a slower companion's pace)
##   mover.sight = func(a, b) -> bool        a straight walk a-b is clear of the walls (the crowd's); a bend is only
##                                           cut once the next leg is in sight, and someone pushed off their way
##   mover.reroute = func(a, b) -> path      (a crowd, a step aside, walking beside someone) so that the walls stand
##                                           between them and where they were heading finds a way round (the
##                                           director's router), looked at every LOOK_AGAIN seconds
##   mover.walking() / mover.arrived         under way / reached the last goal
##
## Standing, someone coming straight through (a walker with no way round, the player) presses on them: past ASIDE_PUSH
## they step ASIDE out of the way, wait for it to clear, and step back to their spot.
##
## What the body shows follows from the motion: it turns before setting off and while walking at no more than the
## person's turn rate, eases in and out of a walk, and its clip plays at the speed it actually moves. Nobody creeps:
## standing, a nudge is let be and a shove is walked back; walking, held up by the crowd, they stop and go again.

const Steer := preload("res://scripts/studio/people/steer.gd")
const Persona := preload("res://scripts/studio/people/persona.gd")
const Formation := preload("res://scripts/studio/people/formation.gd")

const PASS_WAYPOINT := 0.45   # metres: a bend counts as reached this close (the next leg begins) ...
const CORNER_PASS := 0.2      # ... a sharp corner only this close, or once past it (cutting it is cutting the wall)
const SHARP := 0.5            # radians of turn that make a corner sharp
const CORNER_R := 1.5         # metres: the turn people make round a right-angled corner (they slow to make it)
const JOG_LEAST := 5.0        # metres: a shorter way is hurried, not jogged
const JOG_FLOOR := 2.1        # m/s: a jogger round a corner stays in a jog (the jog clip plays down to about this)
const ARRIVE := 0.12          # metres from the goal: there ...
const NEAR_ENOUGH := 0.4      # ... or this close and held up by someone in the way (people settle a step short of a
                              # spot rather than shuffle round it)
const ENTER := 0.45           # metres from a door they go in at: in
const SET_OFF_ANGLE := 1.0    # radians: turned this close to the way, they set off
const STILL := 0.25           # m/s: slower than this, the facing is the body's own choice, not the walk's
const REST_SPEED := 0.2       # m/s: slower than this, a body plays a pose, not its walk (VillagerBody.play_motion)
const SETTLE := 0.4           # metres: nudged off their spot by less, they stand where they are; by more, they walk back
const PLACE_STILL := 0.05     # metres: placed further than this from where they are, they are put there (and stopped)
const YIELD_SPEED := 0.6      # m/s: held below this by the crowd while wanting to walk (slower than anyone walks) ...
const YIELD_AFTER := 0.2      # ... for this long, they stop and let it clear (stop and go, never an inching crawl)
const YIELD_FROM := 0.5       # seconds under way before being held counts (a start is slow on purpose)
const BRISK_BELOW := 0.7      # m/s: below this, setting off or stopping on purpose (the first and the last step) ...
const BRISK := 1.8            # ... speed changes this much more briskly (people are up to speed within a step or two,
const BRISK_TOP := 3.2        # and the walk clip looks wrong at a crawl), never past this (4 m/s2 reads as a snap; the
                              # margin is for a frame's jitter)
const BRISK_RELAX := 0.15     # seconds to settle onto the wanted speed then (Steer.RELAX otherwise)
const ASIDE_PUSH := 1.0       # m/s2 of the crowd's pressure on someone standing (a meeting under a third of a second
                              # off) before they step out of the way ...
const ASIDE := 0.6            # ... this far ...
const ASIDE_BACK := 2.0       # ... and step back after this long, once the pressure is off
const GATE_WAIT := 0.4        # seconds, about, before asking the gate again
const BEHIND := 0.9           # metres behind a companion they walk with, where a wall leaves no room beside them
const FACE_ROOM := 0.5        # metres of room in front of someone standing with nothing to face (else they turn)
const LOOK_AGAIN := 0.5       # seconds between looks at whether the way ahead is still in sight (mover.sight)
const GATE_GIVE_UP := 3.0     # seconds held at a gate before they go anyway (two in each other's way)

var body: Node3D
var m: Dictionary             # persona.gd motion
var active := true            # false: someone else moves the body (a scene, a reaction); the crowd only avoids it
var ground := Callable()      # (Vector2) -> float: the ground height (none: the body keeps its height)

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var avoid := Vector2.ZERO     # the crowd's push from neighbours, kept between steps
var yaw := 0.0
var path := PackedVector2Array()
var seconds := INF            # left until it should be there
var style := "walk"
var wait := 0.0               # seconds before setting off
var hold_at := Vector2.INF    # the spot held while standing
var face_at := Vector2.INF    # what a standing (or backing) body faces
var backing := false
var arrived := true
var exact := false            # a scripted move (onto a device): kept to the path, others give way, no avoidance
var indoors := false          # behind a door: waiting to step out (walking) or in (arrived); the director hides the body
var enters := false           # the goal is a door they go in at
var gate := Callable()        # () -> bool: may they set off now
var lead: RefCounted          # a Mover they walk beside (null: their own way)
var lead_side := 1
var pace_cap := INF
## B6/B8 physical constraints compose by intersection, regardless of locomotion owner. Each entry is
## {move: bool=true, postures: Array=[]}; empty postures allows all. No paths/poses are saved.
var constraints := {}
var actor_key := ""
## S5 current visible apparent matches: body instance ID -> preferred centre distance, metres.
## Presentation only. Residents refreshes from the shared P4 grid; no actor/cause lookup or new goal.
var regard := {}
var _stagger := {}
## Constraints compose: pace metres/second; indoors=false prevents entering a door.
func speed_cap() -> float:
	var cap := pace_cap
	for c: Dictionary in constraints.values():
		cap=minf(cap,maxf(0.0,float(c.get("pace",INF))))
	return cap
func can_enter() -> bool:
	for c: Dictionary in constraints.values():
		if not bool(c.get("indoors",true)):
			return false
	return true
## B6 planted step through this mover, never a second owner. away is world x/z direction.
## Active seconds, distance metres. Exact stage tracks and constraints refuse displacement.
func stagger(away: Vector2, distance: float, delay := 0.18, duration := 0.55) -> bool:
	if not active or exact or indoors or not can_move() or away.length_squared()<0.0001:
		return false
	if not _stagger.is_empty() and float(_stagger.get("fresh",0.0))>0.0:
		# One touch, two cues (the walk's stumble, then its accepted shove's impact): the step already under way keeps
		# its way (aside, off his line) and goes the further of the two. Turned straight back, a crowd pushed through
		# jams against those behind and holds him up.
		_stagger.speed=maxf(float(_stagger.speed),clampf(distance,0.0,1.6)/maxf(0.1,duration))
		return true
	_stagger={"fresh":delay+0.3,"away":away.normalized(),"left":maxf(0.1,duration),"delay":maxf(0.0,delay),
		"speed":clampf(distance,0.0,1.6)/maxf(0.1,duration),"backing":backing,"face":face_at}
	vel=Vector2.ZERO
	avoid=Vector2.ZERO
	_aside_from=Vector2.INF
	face_at=pos-away.normalized()*3.0
	backing=true
	return true
func _end_stagger() -> void:
	if _stagger.is_empty():
		return
	backing=bool(_stagger.backing)
	face_at=_stagger.face
	_stagger.clear()
	vel=Vector2.ZERO
	if arrived:
		hold_at=pos
	elif not path.is_empty() and reroute.is_valid():
		path=reroute.call(pos,path[path.size()-1])


func can_move() -> bool:
	for c: Dictionary in constraints.values():
		if not bool(c.get("move", true)):
			return false
	return true

func can_posture(posture: String) -> bool:
	for c: Dictionary in constraints.values():
		var allowed: Array = c.get("postures", [])
		if not allowed.is_empty() and not allowed.has(posture):
			return false
	return true
var group := 0                # people together (a conversation, companions): the same number keeps no room from each
                              # other in the crowd (steer.gd), only clear of touching
var _gated := 0.0             # seconds held at the gate so far
var placed := false           # put somewhere this frame: the crowd sets it clear of others before it is drawn
var _under_way := 0.0         # seconds walking since setting off (a start is slow on purpose, not held up)
var _held := 0.0              # seconds held up by the crowd
var _yields := 0
var _brisk := false           # setting off or stopping on purpose (not slowed by the crowd)
var asides := 0               # times they stepped out of someone's way (a measure)
var clear := Callable()       # (Vector2) -> bool: room to stand there (the crowd's: off the walls)
var sight := Callable()       # (Vector2, Vector2) -> bool: a straight walk between is clear of the walls (the crowd's)
var reroute := Callable()     # (Vector2, Vector2) -> PackedVector2Array: a way round the walls (the director's)
var _look_t := 0.0            # seconds to the next look at the way ahead
var _open_face := false       # face_at is a way with room, turned to from a wall (_room_ahead)
var threat := Vector2.ZERO    # standing: the velocity of whoever presses on them most (the crowd's)
var _aside_from := Vector2.INF   # the spot they stepped off, to step back to
var _aside_t := 0.0
var _stepping_aside := false  # (the step aside's own arrival: not a new spot)
var _stood := 0.0             # seconds standing (the crowd's pressure is a standing one only after a judging or two)
var shoved := INF             # seconds since the crowd's hard pass or a wall last moved it (a measure: rarely small)
var shoved_by := ""           # what did: "wall" or "person"
var why := ""                 # what the last wish was (a measure: the branch of want() it came from)
var wished := 0.0             # m/s: the speed last wished (a measure)


func _init(the_body: Node3D, motion: Dictionary) -> void:
	body = the_body
	m = motion
	pos = Vector2(body.position.x, body.position.z)
	yaw = body.rotation.y
	hold_at = pos


func go(way: PackedVector2Array, in_seconds := INF, how := "", delay := 0.0) -> void:
	_aside_from = Vector2.INF                # somewhere new to be: a spot they stepped off is no longer theirs to go back to
	path = way.duplicate()
	while path.size() > 1 and path[0].distance_to(pos) < 0.05:
		path.remove_at(0)
	if path.is_empty() or (path.size() == 1 and path[0].distance_to(pos) < ARRIVE):
		hold(path[0] if not path.is_empty() else pos, face_at)
		return
	seconds = in_seconds
	style = how if how != "" else Persona.style_for(m, _left(), in_seconds)
	if how == "" and style in ["jog", "run"] and _left() < JOG_LEAST:
		style = "hurry"                      # a few steps: nobody late breaks into a run (it would be all speeding up and
		                                     # slowing down, through the gap between a walk and a jog); a run asked
		                                     # for (a chase, a child's dash) is a run
	wait = delay
	arrived = false
	hold_at = Vector2.INF
	enters = false
	gate = Callable()
	_gated = 0.0
	_under_way = 0.0
	_held = 0.0


func hold(at: Vector2, face := Vector2.INF) -> void:
	path.clear()
	if not _stepping_aside:
		_aside_from = Vector2.INF
	hold_at = at
	_open_face = false
	face_at = _room_ahead(at, face)
	arrived = true
	wait = 0.0
	indoors = false


func face(at: Vector2) -> void:
	if at == Vector2.INF and _open_face:
		return                                # (turned from a wall already)
	_open_face = false
	face_at = _room_ahead(hold_at, at) if arrived and hold_at != Vector2.INF else at


## Standing with nothing to face: if a wall is right in front of them, a way to face with room (nobody stands nose to a
## wall); else `face` as it is.
func _room_ahead(at: Vector2, face: Vector2) -> Vector2:
	if face != Vector2.INF or not clear.is_valid():
		return face
	var ahead := Vector2(sin(yaw), cos(yaw))
	if clear.call(at + ahead * FACE_ROOM):
		return face
	for turn: float in [0.8, -0.8, 1.6, -1.6, 2.4, -2.4, PI]:
		var dir := ahead.rotated(turn)
		if clear.call(at + dir * FACE_ROOM) and clear.call(at + dir * FACE_ROOM * 2.0):
			_open_face = true
			return at + dir * 3.0
	return face


func place(at: Vector2, facing := INF) -> void:
	if at.distance_to(pos) > PLACE_STILL:  # put somewhere else: there at once, still
		vel = Vector2.ZERO
		avoid = Vector2.ZERO
		placed = true
	pos = at                               # (put where they already are, as when a scene takes someone walking by:
	                                       # they keep their pace and slow as people do, never stopped dead)
	if facing != INF:
		yaw = facing
	if arrived:
		hold_at = at


func walking() -> bool:
	return not arrived


## Out of someone's way, to step back to their spot (on the way there, or standing aside).
func stepped_aside() -> bool:
	return _aside_from != Vector2.INF


## Placed partway along their way (the clock jumped, or they came into being there), after go: already walking it, at
## their pace and facing the way. Not standing to set off: a street of people all starting in one frame looks wound up.
func under_way_already() -> void:
	if arrived or path.is_empty() or wait > 0.0:
		return
	var dir := path[0] - pos
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	vel = dir * minf(Persona.speed(m, style), speed_cap())
	yaw = atan2(dir.x, dir.y)
	body.rotation.y = yaw
	_under_way = 1.0


## Arrived and stopped: a pose played now holds (a body still slowing plays its walk out, and the walk would end it).
func at_rest() -> bool:
	return arrived and vel.length() < REST_SPEED


## m/s2 the speed can change by now: briskly in the first and the last step, and through the gap between a walk and a
## jog (no clip plays well there: people break into a run, or out of one, in a stride).
func accel_now() -> float:
	var a := float(m.accel)
	return minf(a * BRISK, maxf(a, BRISK_TOP)) if _quick() else a


## Seconds to settle onto the wanted speed now: short in the first and the last step (a firm stop, never an
## asymptotic creep) and through the walk-to-jog gap, the crowd's own otherwise.
func relax_now() -> float:
	return BRISK_RELAX if _quick() else Steer.RELAX


func _quick() -> bool:
	var v := vel.length()
	return (_brisk and v < BRISK_BELOW) or (v > Persona.HURRY_TOP + 0.05 and v < Persona.JOG_LOW)


## The crowd's view of this body: a walker steers, someone standing holds a spot, an exact move is avoided by others.
func kind() -> int:
	if not can_move():
		return Steer.OTHER
	if exact:
		return Steer.OTHER
	return Steer.WALKER if not arrived and wait <= 0.0 else Steer.STANDING


## The velocity wanted this step.
func want(dt: float) -> Vector2:
	if not can_move():
		_end_stagger()
		vel = Vector2.ZERO
		return Vector2.ZERO
	if not _stagger.is_empty():
		why="stagger"
		_stagger.fresh=float(_stagger.get("fresh",0.0))-dt
		if float(_stagger.delay)>0:
			_stagger.delay-=dt
			return Vector2.ZERO
		_stagger.left-=dt
		if float(_stagger.left)>0:
			return (_stagger.away as Vector2)*minf(float(_stagger.speed),speed_cap())
		_end_stagger()
	_brisk = true
	_stood = _stood + dt if arrived else 0.0
	if arrived and not exact and _stood > 0.25:
		if _aside_from != Vector2.INF:
			_aside_t -= dt
			if _aside_t <= 0.0 and avoid.length() < ASIDE_PUSH * 0.3:
				var back := _aside_from
				var facing := face_at
				_aside_from = Vector2.INF
				go(PackedVector2Array([back]), INF, "walk")    # back to their spot
				face_at = facing
				why = "back"
				return Vector2.ZERO
		elif avoid.length() > ASIDE_PUSH and hold_at != Vector2.INF and lead == null:
			var from := hold_at
			var facing := face_at
			go(PackedVector2Array([_aside_to()]), INF, "walk")   # out of the way
			face_at = facing
			_aside_from = from
			_aside_t = ASIDE_BACK
			asides += 1
			why = "aside"
			return Vector2.ZERO
	if arrived:
		if hold_at.distance_to(pos) <= SETTLE:
			why = "nudge"
			return Vector2.ZERO              # a nudge: they stand where they are (no creeping back to the exact spot)
		var stepped_from := _aside_from
		go(PackedVector2Array([hold_at]))    # pushed well off: they walk back, as a walk
		_aside_from = stepped_from           # (back to the same spot: a step aside is still to be stepped back)
		if arrived:
			why = "walk back"
			return Vector2.ZERO
	seconds -= dt
	if wait > 0.0 and not gate.is_valid() and _under_way == 0.0 and _yields > 0 and avoid.length() > ASIDE_PUSH \
			and threat.length() > 0.3 and not path.is_empty():
		path.insert(0, _aside_to())          # held up and waiting, and someone comes straight at them: out of their way
		wait = 0.0                           # first, then on (never shoved where they stand)
		asides += 1
		why = "aside on the way"
		return Vector2.ZERO
	if wait > 0.0:
		wait -= dt
		if wait <= 0.0 and gate.is_valid():
			if gate.call() or _gated >= GATE_GIVE_UP:
				gate = Callable()
			else:
				var more := GATE_WAIT * (0.7 + 0.6 * Persona._noise(int(m.key) * 17 + int(_gated * 10.0), 7))
				_gated += more
				wait = more
		why = "wait"
		return Vector2.ZERO
	if lead != null and lead.walking() and lead.wait <= 0.0:
		why = "beside"
		return _beside(lead)
	while path.size() > 1:
		var at := path[0]
		var d := pos.distance_to(at)
		var onward := path[1] - at
		var sharp := d > 0.01 and absf((at - pos).angle_to(onward)) > SHARP
		var early := d < (CORNER_PASS if sharp else PASS_WAYPOINT) or (d < 1.0 and onward.dot(pos - at) > 0.0)
		if d < CORNER_PASS or (early and (not sight.is_valid() or sight.call(pos, path[1]))):
			path.remove_at(0)                # reached, or already round it with the next leg in sight
		else:
			break
	_look_t -= dt
	if _look_t <= 0.0 and sight.is_valid() and reroute.is_valid():
		_look_t = LOOK_AGAIN
		if not sight.call(pos, path[0]) and (not clear.is_valid() or clear.call(path[0])):
			var round: PackedVector2Array = reroute.call(pos, path[0])     # pushed off their way: round the wall
			if round.size() > 1:
				round.remove_at(round.size() - 1)
				path = round + path
	var to := path[0] - pos
	var dist := to.length()
	if path.size() == 1 and (dist < ARRIVE or (enters and dist < ENTER)):
		var going_in := enters
		_stepping_aside = _aside_from != Vector2.INF
		hold(path[0], face_at)
		_stepping_aside = false
		indoors = going_in and can_enter()               # in at the door: gone from the step at once
		why = "there"
		return Vector2.ZERO
	var dir := to / maxf(dist, 0.0001)
	var facing := Vector2(sin(yaw), cos(yaw))
	if backing:
		facing = -facing
	if vel.length() < STILL and absf(facing.angle_to(dir)) > SET_OFF_ANGLE:
		why = "turn first"
		return Vector2.ZERO                  # turn towards the way first (settle turns the body)
	var speed := minf(Persona.speed(m, style), speed_cap())
	if seconds != INF and style != "jog" and style != "run" and speed_cap() == INF:
		var need := _left() / maxf(seconds, 0.5)
		if need > speed:                   # late: hurry, but never into the gap between walk and jog
			speed = minf(need, Persona.HURRY_TOP)
	if backing:
		speed = minf(speed, 1.2)
	if path.size() == 1:                 # ease to a stop at the goal (all but stopped as they reach it: no braking
		speed = minf(speed, sqrt(2.0 * float(m.accel) * 0.7 * maxf(dist - ARRIVE, 0.0)) + 0.08)   # once there)
	else:                                # slow for a sharp corner (a jogger stays in a jog)
		var turn := absf(dir.angle_to(path[1] - path[0]))
		if turn > SHARP:
			var floor := JOG_FLOOR if style == "jog" or style == "run" else 0.0
			var round := maxf(sqrt(float(m.accel) * CORNER_R / clampf(turn / (PI * 0.5), 0.2, 2.0)), floor)
			speed = minf(speed, sqrt(round * round + 2.0 * float(m.accel) * 0.7 * dist))
	_brisk = _under_way < 0.8 or (path.size() == 1 and dist < 0.6)
	_under_way += dt
	if path.size() == 1 and dist < NEAR_ENOUGH and _under_way > (1.0 if _aside_from == Vector2.INF else 0.4) \
			and vel.length() < YIELD_SPEED and not enters:
		_stepping_aside = _aside_from != Vector2.INF
		hold(pos, face_at)               # a step short, held there: here will do
		_stepping_aside = false
		why = "near enough"
		return Vector2.ZERO
	if _under_way > YIELD_FROM and speed > YIELD_SPEED + 0.25 and vel.length() < YIELD_SPEED:
		_held += dt
		if _held > YIELD_AFTER:          # held up: stop, let it clear, go again (each their own moment)
			_held = 0.0
			_under_way = 0.0
			_yields += 1
			wait = 0.5 + 0.9 * Persona._noise(int(m.key) * 13 + _yields, 6)
			why = "held up"
			return Vector2.ZERO
	else:
		_held = 0.0
	why = "walk"
	wished = speed
	return dir * speed


## Walking beside someone: their place at the other's side, a step ahead of where the other is now, at the other's
## speed and a little more or less to keep it (never past a hurry). Where a wall takes that side, they fall in behind.
func _beside(other: RefCounted) -> Vector2:
	var heading: Vector2 = other.vel
	if heading.length() < 0.2:
		return other.vel
	var slot: Vector2 = Formation.side_by_side(other.pos, heading.normalized(), lead_side) + heading * 0.25
	if clear.is_valid() and not clear.call(slot):
		slot = other.pos - heading.normalized() * BEHIND + heading * 0.25
	return (heading + (slot - pos) * 1.5).limit_length(Persona.HURRY_TOP)


## Where the crowd's step put this body: its facing follows, and the body is drawn there.
func settle(dt: float) -> void:
	if not can_move():
		pos=Vector2(body.position.x,body.position.z)
		vel = Vector2.ZERO
		return
	var speed := vel.length()
	var target := yaw
	if not arrived and wait > 0.0 and not path.is_empty():
		var first := path[0] - pos
		if first.length_squared() > 0.0001:
			target = atan2(first.x, first.y) + (PI if backing else 0.0)
	elif not arrived and speed < STILL and not path.is_empty():
		var next := path[0] - pos
		if next.length_squared() > 0.0001:
			target = atan2(next.x, next.y) + (PI if backing else 0.0)
	elif backing and face_at != Vector2.INF:
		var to := face_at - pos
		if to.length_squared() > 0.0001:
			target = atan2(to.x, to.y)
	elif speed >= STILL:
		target = atan2(vel.x, vel.y)
	elif face_at != Vector2.INF:
		var to := face_at - pos
		if to.length_squared() > 0.04:
			target = atan2(to.x, to.y)
	var diff := angle_difference(yaw, target)
	var rate := minf(float(m.turn), 3.0 * absf(diff) + 0.4)      # eases into the end of a turn
	yaw += clampf(diff, -rate * dt, rate * dt)
	var y := body.position.y
	if ground.is_valid():
		y = ground.call(pos)
	body.position = Vector3(pos.x, y, pos.y)
	body.rotation.y = yaw
	if body.has_method("play_motion"):
		body.set("walk_backward", backing and speed > 0.2)
		body.play_motion(speed)


## Where to step out of the way: out of the line of whoever comes (square to their way, on the side the crowd presses
## them to; straight at them, the side with room), as far as there is room (the crowd's `clear`: off the walls).
func _aside_to() -> Vector2:
	var away := avoid.normalized()
	var out := away
	if threat.length() > 0.3:
		out = Vector2(-threat.y, threat.x).normalized()        # square to their way ...
		if out.dot(away) < 0.0:
			out = -out                                         # ... on the side they press them to
	var side := Vector2(-out.y, out.x)
	for step: float in [ASIDE, ASIDE * 0.6, ASIDE * 0.35]:
		for dir: Vector2 in [out, -out if absf(out.dot(away)) < 0.3 else out, (out + side * 0.5).normalized(), (out - side * 0.5).normalized()]:
			var to := pos + dir * step
			if not clear.is_valid() or clear.call(to):
				return to
	return pos


## Metres of path left.
func _left() -> float:
	var total := 0.0
	var at := pos
	for p in path:
		total += at.distance_to(p)
		at = p
	return total
