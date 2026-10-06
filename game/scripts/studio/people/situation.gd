extends RefCounted
## Any interaction between people, played on their bodies (Pass 3, stage 3). It takes the movers of the people in it,
## brings them into shape, plays the beats, and lets them go: an encounter from the catalogue (encounters.gd) is one,
## and anything else that puts people together for a while can be. Generic: movers and bodies (play_loop), a way round
## the walls and a test for standable ground from the director; not villages.
##
##   var s := Situation.new(name, entry, movers, bodies, seconds, key, world)
##       world: {"route": (from, to) -> PackedVector2Array, "standable": (Vector2) -> bool}
##   s.update(dt) -> true once it is over (the director then hands them back to their day; a late one hurries)
##   s.cleanup()      (over early: an act or a talk took one of them)
##   s.join(mover, body, id, voice) / s.leave(id)    a circle takes someone in or lets them go: it forms again
##   s.centre         a circle's middle (the director's choice of a good place; INF: where they are)
##   s.speaker()      the role talking now (-1: nobody)
##
##   meet  ── into shape:  circle  n round a middle, each to the slot nearest them round it (Formation.assign:
##    │                            nobody crosses another), all facing in (Kendon's F-formation)
##    │                    pair    both stop and face each other, a conversation apart (Formation.circle)
##    │                    crouch  as a pair, the grown one crouched down to the child
##    │                    beside  the second walks on beside the first, the first at the slower one's pace
##    │                    berth   the first steps wide round the second, off their way
##    │                    chase   the second runs off, the first runs after
##    │                    apart   each stops where they are and turns to the other
##    │                    glance  nobody stops: a look and a nod in passing (the heads: the director's look)
##   beats ── "turns": one talks, the others listen (arms folded, a nod, a shake of the head); the next to talk is
##    │        anyone but the last, the talkative likelier (`voices`); or the
##    │        entry's own gestures, [role, clip, seconds] in order
##   part  ── a last gesture each (a nod), and they go
##
## A clip named "@nod" or "@wave" is the body's own gesture (VillagerBody.nod, wave: over whatever it plays, walking
## too), not an animation.

const Formation := preload("res://scripts/studio/people/formation.gd")
const Mover := preload("res://scripts/studio/people/mover.gd")

const MEET_FOR := 4.0         # seconds at most to get into shape (someone held up: they make do where they are)
const TURN := Vector2(1.8, 3.2)   # seconds a turn at talking lasts, least and most
const LISTEN := ["Idle_FoldArms", "Yes", "Idle_FoldArms", "Idle", "Idle_No", "Yes"]
const PART_FOR := 1.3
const CHASE_EVERY := 0.3      # seconds between a chaser's looks at where the chased one has got to
const BERTH := 1.9            # metres off their way to keep clear of someone
const RING_NEAR := 0.45       # metres from a circle's middle: a fair place in it, at least ...
const RING_FAR := 0.9         # ... and at most
const SPACE_IN := 0.45        # metres: a conversation's middle kept clear reaches this far short of its ring ...
const SPACE_LEAST := 0.2       # ... and is never smaller than this
const TIDY_EVERY := 2.0       # seconds, about, between looks at whether the group has kept its shape ...
const TIDY_OFF := 0.25        # ... anyone nudged further than this off their place in it steps back to it
const RING_TIDY := 0.2        # metres: in a circle, anyone further than this off their place in the ring evened out
                              # round its middle (Formation.fit) steps to it, if it is free
const RING_APART := 0.8       # metres between two in a circle, at least

var name := ""
var who: Array = []           # the director's ids for the roles (a, b, ...)
var entry: Dictionary
var movers: Array             # Mover per role (a, b, ...)
var bodies: Array             # the bodies (VillagerBody) per role
var seconds := 0.0            # how long the beats last
var key := 0
var world: Dictionary
var phase := "meet"
var t := 0.0
var _beat := -1
var _beat_left := 0.0
var _speaker := 0
var _again := 0.0
var _playing: Array = []      # the clip each body was last given
var centre := Vector2.INF     # a circle's middle
var voices: Array = []        # per role, how readily they talk (0..1)
var _tidy := TIDY_EVERY


func _init(the_name: String, the_entry: Dictionary, the_movers: Array, the_bodies: Array, length: float, k: int,
		the_world := {}) -> void:
	name = the_name
	entry = the_entry
	movers = the_movers
	bodies = the_bodies
	seconds = length
	key = k
	world = the_world
	for b in bodies:
		_playing.append("")
		voices.append(0.5)
	for m: Mover in movers:
		m.group = _group()
		m.lead = null                     # (walking beside someone of theirs is over: they are here now)
		m.pace_cap = INF
	_meet()


## -> true when it is over.
func update(dt: float) -> bool:
	t += dt
	match phase:
		"meet":
			_keep_shape(dt)
			if _in_shape() or t > MEET_FOR:
				phase = "beats"
				t = 0.0
				_face_each_other()
		"beats":
			_keep_shape(dt)
			_play_beats(dt)
			if shape() == "beside" and (not movers[0].walking() or not movers[1].walking()):
				t = seconds                    # walking together ends where either stops (each to their own spot)
			if t >= seconds:
				phase = "part"
				t = 0.0
				var end := str(entry.get("end", ""))
				for i in bodies.size():
					_loop(i, end if end != "" else "Idle")
		"part":
			if t >= (PART_FOR if str(entry.get("end", "")) != "" else 0.2):
				cleanup()
				return true
	return false


## Over (early or not): nothing of the situation stays on the movers.
func cleanup() -> void:
	for m: Mover in movers:
		m.lead = null
		m.pace_cap = INF
		m.backing = false
		if m.group == _group():
			m.group = 0
	phase = "done"


func shape() -> String:
	return str(entry.get("shape", "pair"))


func _meet() -> void:
	var a: Mover = movers[0]
	var b: Mover = movers[1]
	match shape():
		"circle":
			_form()
		"pair", "crouch":
			var middle := (a.pos + b.pos) * 0.5 if centre == Vector2.INF else centre if centre == Vector2.INF else centre
			var across := b.pos - a.pos
			var slots := Formation.circle(middle, 2, atan2(-across.y, -across.x))   # a's slot on a's side
			a.go(_way(a.pos, slots[0]), INF, "walk")
			b.go(_way(b.pos, slots[1]), INF, "walk")
			a.face_at = b.pos
			b.face_at = a.pos
		"beside":
			b.lead = a
			b.lead_side = 1 if (b.pos - a.pos).cross(a.vel) > 0.0 else 2
			a.pace_cap = minf(float(a.m.pace), float(b.m.pace))
		"berth":
			var ahead := b.pos - a.pos
			var side := Vector2(-a.vel.y, a.vel.x).normalized()
			if side.dot(ahead) > 0.0:
				side = -side                   # round them on the side away from them
			var off := b.pos + side * BERTH
			if _standable(off) and a.walking():
				var rest := a.path.duplicate()
				rest.insert(0, off)
				var enters := a.enters
				a.go(rest, a.seconds, a.style)
				a.enters = enters
		"chase":
			_run_off()
		"apart":
			a.hold(a.pos, b.pos)
			b.hold(b.pos, a.pos)
		"glance":
			pass                             # (they keep walking: the heads turn, then a nod)


## Keeps the shape while it lasts (a chase re-aims; a pair keeps facing).
func _keep_shape(dt: float) -> void:
	match shape():
		"chase":
			var a: Mover = movers[0]
			var b: Mover = movers[1]
			_again -= dt
			if not b.walking():
				_run_off()
			if _again <= 0.0:
				_again = CHASE_EVERY
				if a.pos.distance_to(b.pos) > 1.0:
					a.go(_way(a.pos, b.pos), INF, "jog")
				else:
					a.hold(a.pos, b.pos)
		"pair", "crouch", "apart", "circle":
			if phase == "beats":
				_face_each_other()
				_tidy -= dt
				if _tidy <= 0.0:
					_tidy = TIDY_EVERY * (0.7 + 0.6 * _noise(key + int(t * 10.0), 3))
					if shape() == "circle" and centre != Vector2.INF:
						_even_out()
						return
					for m: Mover in movers:
						if m.at_rest() and m.hold_at != Vector2.INF and m.pos.distance_to(m.hold_at) > TIDY_OFF \
								and not m.stepped_aside():   # (out of someone's way: they step back by themselves)
							var spot := m.hold_at
							m.go(PackedVector2Array([spot]), INF, "walk")   # back into their place in it (a group keeps
							m.face_at = centre if shape() == "circle" else m.face_at   # its shape: people shift to keep it)


## A circle keeps its shape: the ring round its middle evened out to fit them as they stand (Formation.fit); anyone a
## step off their place in it, at rest and not out of someone's way, steps to it if nobody stands there and it is
## ground to stand on. A place someone settled a step short of (held up) is taken up once it is free.
func _even_out() -> void:
	var at: Array = []
	for m: Mover in movers:
		at.append(m.pos)
	var ring := Formation.fit(centre, at)
	for i in movers.size():
		var m: Mover = movers[i]
		var place := ring[i]
		if not m.at_rest() or m.stepped_aside() or m.pos.distance_to(place) <= RING_TIDY or not _standable(place):
			continue
		var free := true
		for other: Mover in movers:
			if other != m and other.pos.distance_to(place) < RING_APART * 0.5:
				free = false
		if free:
			m.go(PackedVector2Array([place]), INF, "walk")
			m.face_at = centre


func _in_shape() -> bool:
	match shape():
		"pair", "crouch", "apart", "circle":
			for m: Mover in movers:
				if not m.at_rest():
					return false
			return true
	return true


func _face_each_other() -> void:
	if shape() in ["beside", "berth", "chase", "glance"]:
		return
	if shape() == "circle":
		for m: Mover in movers:
			m.face_at = centre                 # all facing in; the head turns to the speaker (look.gd)
		return
	var a: Mover = movers[0]
	var b: Mover = movers[1]
	a.face_at = b.pos                        # (facing only: the spot each holds stays theirs, so a shove or a step
	b.face_at = a.pos                        # aside for a passer-by is walked back)


## The beats: turns at talking, or the entry's own gestures in order.
func _play_beats(dt: float) -> void:
	var beats = entry.get("beats", [])
	if shape() == "crouch":
		_loop(0, "Crouch_Idle")
	if shape() == "beside":
		_walk_talk(dt)                     # (walking: the walk is the beat; they talk on the way)
		return
	if shape() in ["berth", "chase"]:
		return                             # (walking: the walk is the beat)
	if beats is String and beats == "turns":
		_turns(dt)
		return
	_beat_left -= dt
	if _beat_left > 0.0:
		return
	_beat += 1
	if _beat >= (beats as Array).size():
		_turns(dt)                         # their own gestures done: they talk on until the end
		return
	var beat: Array = beats[_beat]
	_beat_left = float(beat[2])
	if str(beat[1]) == "turns":
		_beat_left = seconds
		return
	for i in bodies.size():
		var role := "a" if i == 0 else "b"
		if beat[0] == "both" or beat[0] == role:
			if not (shape() == "crouch" and i == 0) or str(beat[1]).begins_with("@"):
				_loop(i, str(beat[1]))
		elif not (shape() == "crouch" and i == 0):
			_loop(i, LISTEN[(key + _beat + i) % LISTEN.size()])


func _turns(dt: float) -> void:
	_beat_left -= dt
	if _beat_left > 0.0:
		return
	_speaker = _next_speaker()
	_beat += 1
	_beat_left = lerpf(TURN.x, TURN.y, _noise(key + _beat, 4))
	for i in bodies.size():
		if shape() == "crouch" and i == 0:
			continue
		_loop(i, "Idle_Talking" if i == _speaker else LISTEN[(key + _beat * 3 + i) % LISTEN.size()])


## Walking together, they talk: turns as at a standstill, the one listening nodding now and then (no clip: they walk).
func _walk_talk(dt: float) -> void:
	_beat_left -= dt
	if _beat_left > 0.0:
		return
	_speaker = _next_speaker()
	_beat += 1
	_beat_left = lerpf(TURN.x, TURN.y, _noise(key + _beat, 4)) * 1.4
	for i in bodies.size():
		if i != _speaker and _noise(key + _beat * 5 + i, 9) < 0.45:
			_loop(i, "@nod")


## Anyone but the one who spoke last, the talkative likelier.
func _next_speaker() -> int:
	var n := bodies.size()
	if n <= 2:
		return (_speaker + 1) % n
	var total := 0.0
	for i in n:
		if i != _speaker:
			total += 0.25 + float(voices[i])
	var at := _noise(key + _beat * 13, 8) * total
	for i in n:
		if i == _speaker:
			continue
		at -= 0.25 + float(voices[i])
		if at <= 0.0:
			return i
	return (_speaker + 1) % n


## The room in its middle that others walk round (crowd.gd spaces, Steer.SPACE): [centre, radius], or [] when it has
## none (walking together, not yet met, parting).
func space() -> Array:
	if not shape() in ["circle", "pair", "crouch"] or not phase in ["meet", "beats"]:
		return []
	var c := centre
	if c == Vector2.INF:
		c = Vector2.ZERO
		for m: Mover in movers:
			c += m.hold_at if m.hold_at != Vector2.INF else m.pos
		c /= float(movers.size())
	return [c, maxf(Formation.radius_for(movers.size()) - SPACE_IN, SPACE_LEAST)]


## The number its people share in the crowd (they keep no room from each other): never 0.
func _group() -> int:
	return (absi(key) % 1000000) + 1


## The role talking now (-1: nobody: they are getting into shape, or parting).
func speaker() -> int:
	return _speaker if phase == "beats" and _speaker < bodies.size() and shape() in ["circle", "pair", "crouch", "beside"] else -1


## Who role i is looking to (-1: nobody in particular): in a pair or a passing glance, the other; in a conversation,
## the one talking (the look director glances round the rest).
func looks_to(i: int) -> int:
	match shape():
		"pair", "crouch", "apart", "glance", "berth":
			return 1 - i if bodies.size() == 2 else -1
		"circle", "beside":
			var s := speaker()
			return s if s != i else -1
		"chase":
			return 1 - i
	return -1


## A circle: into a ring round `centre`, each to the slot nearest where they stand round it (nobody crosses another).
## Already standing in a fair ring (someone left), they stay where they are and turn to its new middle: people close a
## gap by turning, not by all shuffling round.
func _form() -> void:
	if _fair_ring():
		return
	var n := movers.size()
	if n == 0:
		return
	var at: Array = []
	var middle := Vector2.ZERO
	for m: Mover in movers:
		at.append(m.pos)
		middle += m.pos
	middle /= float(n)
	if centre == Vector2.INF:
		centre = middle
	var first: Vector2 = at[0] - centre
	var slots := Formation.circle(centre, n, atan2(first.y, first.x) if first.length_squared() > 0.0001 else 0.0)
	var order := Formation.assign(centre, slots, at)
	for i in n:
		var m: Mover = movers[i]
		var slot := slots[order[i]]
		m.face_at = centre
		if m.pos.distance_to(slot) > 0.2:
			m.go(_way(m.pos, slot), INF, "walk")
			m.face_at = centre
		else:
			m.hold(m.pos, centre)
	phase = "meet"
	t = 0.0


## Whether those in a circle already stand in a fair ring round their middle (each RING_NEAR-RING_FAR from it, none
## on top of another, none walking): if so the middle moves there and they turn to it.
func _fair_ring() -> bool:
	var n := movers.size()
	if n < 2 or phase == "meet":
		return false
	var middle := Vector2.ZERO
	for m: Mover in movers:
		if m.walking():
			return false
		middle += m.pos
	middle /= float(n)
	for i in n:
		var d: float = (movers[i] as Mover).pos.distance_to(middle)
		if d < RING_NEAR or d > RING_FAR:
			return false
		for j in range(i + 1, n):
			if (movers[i] as Mover).pos.distance_to((movers[j] as Mover).pos) < RING_APART:
				return false
	centre = middle
	for m: Mover in movers:
		m.hold(m.pos, centre)
	return true


## Someone joins a circle: it forms again round them all.
func join(mover: Mover, body, id: int, voice := 0.5) -> void:
	mover.group = _group()
	mover.lead = null
	mover.pace_cap = INF
	movers.append(mover)
	bodies.append(body)
	who.append(id)
	_playing.append("")
	voices.append(voice)
	_form()


## Someone leaves a circle: the others close up.
func leave(id: int) -> void:
	var i := who.find(id)
	if i < 0:
		return
	var m: Mover = movers[i]
	m.lead = null
	m.pace_cap = INF
	m.backing = false
	if m.group == _group():
		m.group = 0
	movers.remove_at(i)
	bodies.remove_at(i)
	who.remove_at(i)
	_playing.remove_at(i)
	voices.remove_at(i)
	if _speaker >= i:
		_speaker = maxi(_speaker - 1, 0)
	if movers.size() >= 2:
		_form()


## The chased one runs off somewhere open, a few metres away.
func _run_off() -> void:
	var b: Mover = movers[1]
	for k in 6:
		var a := TAU * _noise(key + int(t * 10.0) + k, 6)
		var to := b.pos + Vector2(cos(a), sin(a)) * lerpf(5.0, 8.0, _noise(key + k, 7))
		if _standable(to):
			b.go(_way(b.pos, to), INF, "jog")
			return
	b.hold(b.pos, movers[0].pos)


func _loop(i: int, clip: String) -> void:
	var body = bodies[i]
	if clip.begins_with("@"):              # the body's own gesture, over whatever it plays
		if is_instance_valid(body) and body.has_method(clip.substr(1)):
			body.call(clip.substr(1))
		return
	if shape() == "glance":
		return                             # (walking on: no pose)
	if _playing[i] == clip:
		return
	_playing[i] = clip
	if is_instance_valid(body) and body.has_method("play_loop"):
		body.play_loop(clip, 0.25, 1.0, 0.0)


func _way(from: Vector2, to: Vector2) -> PackedVector2Array:
	var route: Callable = world.get("route", Callable())
	return route.call(from, to) if route.is_valid() else PackedVector2Array([to])


func _standable(p: Vector2) -> bool:
	var test: Callable = world.get("standable", Callable())
	return test.call(p) if test.is_valid() else true


static func _noise(k: int, salt: int) -> float:
	return float(posmod(hash(k * 7919 + salt * 104729), 100000)) / 100000.0
