extends Node
## People answering what they have just seen or heard (plan LIVELY-VILLAGE 3.1): a scene's end, someone leaving a
## circle, an enemy in the village, his kill. Generic: ids, movers, bodies, a registry of reaction modules
## (village/reaction_registry.gd) and what the director answers, not villages.
##
##   reacting.cue(cue, ids)       everyone in `ids` the cue reaches: held at once (an owners claim, in the same call as
##                                whatever let go of them, so no frame leaves them to their day), each turning to it at
##                                their own moment; then a reaction each, chosen 8 a frame, begun at its own delay,
##                                played by people/performer.gd, and back to their day when done
##   reacting.reacting(id) -> String   the module they are playing ("" none)
##   reacting.topic(id) -> Dictionary  what is on their mind after it ({kind, subject, until} seconds), for talk
##
##   cue ─► HOLD (claim "reaction" 2; the rules' cast "cast" 4, kept under a talk) ─► CHOOSE (facts, weights, a keyed
##          pick among the strong) ─► WAIT (their own delay; a turn to it meanwhile) ─► PERFORM ─► their day
##
##   director  {"mover": (id) -> Mover, "body": (id) -> Node3D,
##              "claim": (id, by, priority, keep) -> bool, "holds": (id, by) -> bool, "release": (id, by) -> void,
##              "facts": (id, cue) -> Dictionary      reaction_facts.gd's `me`
##              "cast": (cue) -> Dictionary           id -> module name the rules gave them (sim/aftermath.gd)
##              "at": (target, id, cue) -> Vector2    a target's ground point (performer.gd targets; INF: gone)
##              "route": (a, b) -> PackedVector2Array, "standable": (Vector2) -> bool
##              "say": (id, text) -> void, "murmur": (id, group, seconds) -> void, "clock": () -> float (seconds)
##              optional: "suspended": (id, by) -> bool (kept under a higher claim), "frozen": () -> bool (time stands),
##              "do": (id, what, cue) -> void (a step that does something to the world: performer.gd "do")}
const Performer := preload("res://scripts/studio/people/performer.gd")
const Registry := preload("res://scripts/studio/village/reaction_registry.gd")

const HOLD := 2              # owners priority of a reaction's hold
const CAST := 4              # ... and of the rules' cast (held under a talk, never poached by a happening)
const CHOOSE_PER_FRAME := 8
const TURN_LEAST := 0.2      # seconds before someone held turns to it, at least ...
const TURN_SPREAD := 1.3     # ... and up to this much more, each their own
const KNOT_MOST := 4
const KNOT_REACH := 6.0      # metres: a knot member joins one this near
const KNOT_R := 0.8          # metres from a knot's middle to its people
const TOPIC_S := 300.0       # seconds what they saw stays on their mind
const NOTICE_MOST := 5.0    # seconds the least alert may take to take in a scene's end (before their reaction's delay)

var registry: Registry
var director: Dictionary
var _people := {}            # id -> Entry
var _choose: Array[int] = [] # ids waiting for their choice
var _knots: Array = []       # [{module, centre, members: [ids], group, cue_key}]
var _topics := {}            # id -> {kind, subject, until}
var _next_group := 700000
var trace: Array = []        # [seconds, id, module] the latest choices (a measure, the proof's)
var picked := {}             # module -> times chosen, all run long (a measure)


class Entry:
	var id := -1
	var cue: Dictionary
	var by := "reaction"
	var module: Script
	var name := ""
	var me := {}
	var t := 0.0
	var turn_in := 0.0
	var start_in := INF
	var lasts := 90.0
	var perf: Performer


func _init(the_registry: Registry, the_director: Dictionary) -> void:
	registry = the_registry
	director = the_director


func cue(c: Dictionary, ids: Array) -> void:
	if not c.has("key"):
		c.key = hash([c.get("kind", ""), c.get("event", -1), int(float(director.clock.call()) * 10.0)])
	c.heard = float(director.clock.call())
	var cast: Dictionary = director.cast.call(c) if director.has("cast") else {}
	for id: int in ids:
		var e: Entry = _people.get(id)
		if e != null:
			if not _urgent(c):
				continue                          # already answering something: a new end does not interrupt them
			_end(e, false)
		var by := "cast" if cast.has(id) else "reaction"
		if not director.claim.call(id, by, CAST if by == "cast" else HOLD, by == "cast"):
			continue                              # something higher has them (a talk, a scene)
		e = Entry.new()
		e.id = id
		e.cue = c
		e.by = by
		e.turn_in = TURN_LEAST + TURN_SPREAD * float(absi(hash([c.key, id, 3])) % 1000) / 1000.0
		e.me = {"cast": str(cast.get(id, ""))}
		_people[id] = e
		_choose.append(id)
		var m = director.mover.call(id)
		m.hold(m.pos, Vector2.INF)                # they stop where they are (their day does not replan them)


## An enemy, an alarm: it takes people from what they were answering, and nobody is slow to take it in.
static func _urgent(c: Dictionary) -> bool:
	var kind := str(c.get("kind", ""))
	return kind.begins_with("enemy") or kind.begins_with("alarm")


func reacting(id: int) -> String:
	var e: Entry = _people.get(id)
	return e.name if e != null else ""


func topic(id: int) -> Dictionary:
	var t: Dictionary = _topics.get(id, {})
	if not t.is_empty() and float(t.until) < float(director.clock.call()):
		_topics.erase(id)
		return {}
	return t


func _process(dt: float) -> void:
	if director.has("frozen") and director.frozen.call():
		dt = 0.0                                      # (the talk screen open, the game in the background: time stands)
	var budget := CHOOSE_PER_FRAME
	while budget > 0 and not _choose.is_empty():
		var id: int = _choose.pop_front()
		budget -= 1
		var e: Entry = _people.get(id)
		if e != null and e.module == null:
			_pick(e)
	for id: int in _people.keys():
		var e: Entry = _people[id]
		if not director.holds.call(id, e.by):
			if e.by == "cast" and director.has("suspended") and director.suspended.call(id, e.by):
				continue                          # a talk has them for now: theirs again after
			_end(e, false)                        # something higher took them for good
			continue
		e.t += dt
		if e.perf == null:
			if e.turn_in >= 0.0 and e.t >= e.turn_in:
				e.turn_in = -1.0
				var at: Vector2 = director.at.call("subject", id, e.cue)
				if at == Vector2.INF:
					at = director.at.call("place", id, e.cue)
				if at != Vector2.INF:
					var m = director.mover.call(id)
					m.face(at)
			if e.module != null and e.t >= e.start_in:
				e.perf = Performer.new(id, director.mover.call(id), director.body.call(id), e.module.call("steps", e.cue, e.me),
					_world_for(e))
			continue
		if e.perf.update(dt) or e.perf.age >= e.lasts:
			_end(e, true)


func _pick(e: Entry) -> void:
	e.me = director.facts.call(e.id, e.cue).merged(e.me, true)
	var options: Array = registry.answering(str(e.cue.kind))
	var chosen: Script = null
	if str(e.me.cast) != "":
		chosen = registry.by_name(str(e.me.cast))
	if chosen == null:
		var best := 0.0
		var ws: Array = []
		for m: Script in options:
			var w := float(m.call("weight", e.cue, e.me))
			ws.append(w)
			best = maxf(best, w)
		if best <= 0.0:
			_end(e, true)                         # nothing they would do: their day again
			return
		var total := 0.0
		for i in ws.size():
			ws[i] = float(ws[i]) * float(ws[i]) if float(ws[i]) >= best * 0.25 else 0.0   # the strong ones, the strongest likelier
			total += float(ws[i])
		var r := float(absi(hash([e.cue.key, e.id, 11])) % 100003) / 100003.0 * total
		for i in ws.size():
			r -= float(ws[i])
			if r <= 0.0 and float(ws[i]) > 0.0:
				chosen = options[i]
				break
		if chosen == null:
			chosen = options[ws.find(ws.max())]
	e.module = chosen
	e.name = registry.name_of(chosen)
	var prio := int(Registry.constant(chosen, "PRIORITY", HOLD))
	if e.by == "reaction" and prio != HOLD:
		director.claim.call(e.id, e.by, prio, false)   # (a module's own hold: going to their kin outranks a happening)
	var lag := 0.0                                    # taking it in: the less alert later (never for an urgent cue)
	if not _urgent(e.cue) and e.me.has("traits"):
		var alert := clampf(float(e.me.traits.get("alert", 50)) / 100.0, 0.0, 1.0)
		lag = NOTICE_MOST * (1.0 - alert) * float(absi(hash([e.cue.key, e.id, 5])) % 1000) / 1000.0
	e.start_in = maxf(float(chosen.call("delay", e.cue, e.me)) + lag, e.t + 0.1)
	if str(e.me.cast) != "":
		e.start_in = minf(e.start_in, 1.5)
	e.lasts = float(chosen.call("lasts", e.cue, e.me))
	trace.append([float(director.clock.call()), e.id, e.name])
	picked[e.name] = int(picked.get(e.name, 0)) + 1
	if trace.size() > 400:
		trace = trace.slice(200)


func _end(e: Entry, finished: bool) -> void:
	_people.erase(e.id)
	_choose.erase(e.id)
	if e.perf != null:
		e.perf.stop()
	for k: Dictionary in _knots:
		(k.members as Array).erase(e.id)
	_knots = _knots.filter(func(k: Dictionary) -> bool: return not (k.members as Array).is_empty())
	if e.module != null:
		_topics[e.id] = {"kind": str(e.cue.kind), "subject": int(e.cue.get("subject", -1)), "module": e.name,
			"until": float(director.clock.call()) + TOPIC_S}
	if finished or director.holds.call(e.id, e.by):
		director.release.call(e.id, e.by)


func _world_for(e: Entry) -> Dictionary:
	return {
		"at": func(target: Variant, id: int) -> Vector2: return director.at.call(target, id, e.cue),
		"route": director.route,
		"say": director.say,
		"murmur": director.murmur,
		"knot": func(id: int) -> Dictionary: return _knot_of(id, e),
		"do": func(id: int, what: String) -> void:
			if director.has("do"):
				director.do.call(id, what, e.cue),
	}


## The knot `id` talks it over in: one of theirs near with room, else a new one where they stand, a step towards the
## place; its people round it, each on their own side.
func _knot_of(id: int, e: Entry) -> Dictionary:
	var m = director.mover.call(id)
	for k: Dictionary in _knots:
		if (k.members as Array).has(id):
			return _spot(k, id)
	for k: Dictionary in _knots:
		if k.module == e.name and int(k.cue_key) == int(e.cue.key) and (k.members as Array).size() < KNOT_MOST \
				and (k.centre as Vector2).distance_to(m.pos) < KNOT_REACH:
			(k.members as Array).append(id)
			return _spot(k, id)
	var place: Vector2 = e.cue.get("place", m.pos)
	var toward: Vector2 = (place - m.pos)
	var centre: Vector2 = m.pos + (toward.normalized() * minf(1.0, toward.length() * 0.3) if toward.length() > 0.1 else Vector2.ZERO)
	if director.has("standable") and not director.standable.call(centre):
		centre = m.pos
	_next_group += 1
	var k := {"module": e.name, "centre": centre, "members": [id], "group": _next_group, "cue_key": int(e.cue.key)}
	_knots.append(k)
	return _spot(k, id)


func _spot(k: Dictionary, id: int) -> Dictionary:
	var members: Array = k.members
	var i := members.find(id)
	var a := TAU * float(i) / float(maxi(members.size(), 3)) + float(absi(int(k.group)) % 7) * 0.4
	return {"centre": k.centre, "spot": (k.centre as Vector2) + Vector2(cos(a), sin(a)) * KNOT_R, "group": k.group}
