extends RefCounted
## Plays a going-on on the bodies (plan LIVELY-VILLAGE step 4): each of its cast, by role, plays the steps its kind
## gives (people/performer.gd), from a little before its first phase; those it draws come at their own moment and play
## theirs; each goes back to their day as their own steps end, and whoever is left when it is over breaks up as people
## do (the director's end). Generic: a record with a cast of roles, a `plays` callable, movers and what the director
## answers, not villages. The same face as happening_runner.gd (life_watch.gd and residents.gd read both).
##
##   var run := GoingOnRunner.new(record, director, plays, draw)
##       record    {id, kind, cast: {role: id}, phases: [[name, from, to], ...], ends, ...}
##       plays     (record, role, me) -> Array   the steps for a role (the kind's)
##       draw      {"most", "loud", "come", "role"} or {}: who it draws besides its cast
##       director  {"mover", "body", "claim": (id, keep) -> bool, "holds": (id) -> bool, "release": (id) -> void,
##                  "clock": () -> float (game minutes), "at": Vector2 (its spot), "facts": (id, record) -> Dictionary,
##                  "target": (target, id, record) -> Vector2, "route", "say_text": (id, text) -> void,
##                  "murmur": (id, group, seconds) -> void, "watchers": as happening_runner.gd's, "out": (id) -> void,
##                  "end": (record, ids, at) -> void (optional)}
##   run.update(dt) -> bool   true once it is over and everyone is released
##   run.stop(why)            over early: everyone released (and their end cue)
##   run.drop(id) / run.has(id) / run.resume(id)   someone higher took them / is in it / is back
const Performer := preload("res://scripts/studio/people/performer.gd")

const LEAD := 10.0           # game minutes before the first phase that the cast set off, unless the record says
const COME_LEAST := 0.4      # seconds before one it draws sets off, at least ...
const COME_PER_M := 0.08     # ... and this many more a metre away ...
const COME_SPREAD := 2.5     # ... and up to this much more, each their own
const KNOT_R := 1.0          # metres from a knot's middle to its people

var record: Dictionary
var phase := "coming"
var watching: Array[int] = []
var people_seen := 0
var ended := ""
var _d: Dictionary
var _plays: Callable
var _draw: Dictionary
var _cast: Array[int] = []
var _role := {}              # id -> role
var _perf := {}              # id -> Performer
var _coming := {}            # id -> seconds before they set off (those drawn)
var _drawn := false
var _done := {}              # id -> true: played their part and let go


func _init(the_record: Dictionary, director: Dictionary, plays: Callable, draw := {}) -> void:
	record = the_record
	_d = director
	_plays = plays
	_draw = draw
	var cast: Dictionary = record.get("cast", {})
	for role: String in cast:
		var id := int(cast[role])
		if id < 0 or _cast.has(id):
			continue
		if _d.claim.call(id, false):
			_cast.append(id)
			_role[id] = role
		elif role in record.get("needs", ["a"]):
			stop("could not take the %s" % role)
			return


func update(dt: float) -> bool:
	if phase == "done":
		return true
	var now: float = _d.clock.call()
	var first := float(record.phases[0][1]) if not (record.phases as Array).is_empty() else now
	if now >= float(record.ends):
		stop("over")
		return true
	if now < first - float(record.get("lead", LEAD)):
		return false
	phase = _phase_at(now)
	for id: int in _cast.duplicate():
		if _done.has(id):
			continue
		if not _d.holds.call(id):
			continue                              # lent to something higher for now
		if not _perf.has(id):
			_start(id)
		var p: Performer = _perf[id]
		if p.update(dt):
			_let_go(id)
	if not _drawn and not _draw.is_empty() and now >= first:
		_drawn = true
		_call(int(_draw.get("most", 8)), float(_draw.get("loud", 30.0)), str(_draw.get("come", "bold")))
	for id: int in _coming.keys():
		_coming[id] = float(_coming[id]) - dt
		if float(_coming[id]) <= 0.0:
			_coming.erase(id)
			if _d.claim.call(id, false):
				_cast.append(id)
				_role[id] = str(_draw.get("role", "guest"))
				watching.append(id)
				if _d.has("out"):
					_d.out.call(id)
	people_seen = maxi(people_seen, _cast.size() - _done.size())
	return false


func drop(id: int) -> void:
	if _perf.has(id):
		(_perf[id] as Performer).stop()
	_perf.erase(id)
	_cast.erase(id)
	watching.erase(id)
	_coming.erase(id)


func has(id: int) -> bool:
	return _cast.has(id) or _coming.has(id)


func resume(id: int) -> void:
	_perf.erase(id)                               # (their part again, from where they are)


func stop(why := "stopped") -> void:
	if ended.is_empty():
		ended = why
	var let_go: Array[int] = []
	for id: int in _cast:
		if _done.has(id):
			continue
		if _perf.has(id):
			(_perf[id] as Performer).stop()
		var had: bool = _d.holds.call(id)
		_d.release.call(id)
		if had:
			let_go.append(id)
	_cast.clear()
	_perf.clear()
	_coming.clear()
	phase = "done"
	if _d.has("end") and not let_go.is_empty():
		_d.end.call(record, let_go, _d.at)


func _start(id: int) -> void:
	var me: Dictionary = _d.facts.call(id, record) if _d.has("facts") else {"id": id}
	var steps: Array = _plays.call(record, str(_role[id]), me)
	_perf[id] = Performer.new(id, _d.mover.call(id), _d.body.call(id), steps, _world())


func _let_go(id: int) -> void:
	_done[id] = true
	_perf.erase(id)
	_d.release.call(id)


func _call(most: int, loud: float, come: String) -> void:
	if not _d.has("watchers"):
		return
	for w: Array in _d.watchers.call(_d.at, loud, most, _cast, come):
		var id := int(w[0])
		if not _cast.has(id) and not _coming.has(id):
			_coming[id] = COME_LEAST + COME_PER_M * float(w[1]) + COME_SPREAD * _noise(int(record.id) * 31 + id, 3)


func _phase_at(now: float) -> String:
	var last := "coming"
	for ph: Array in record.phases:
		if now >= float(ph[1]):
			last = str(ph[0])
	return last


func _world() -> Dictionary:
	return {
		"at": func(target: Variant, id: int) -> Vector2: return _d.target.call(target, id, record),
		"route": _d.route,
		"say": _d.say_text,
		"murmur": _d.murmur,
		"knot": func(id: int) -> Dictionary: return _knot(id),
		"do": func(id: int, what: String) -> void:
			if _d.has("do"):
				_d.do.call(id, what, record),
	}


## The going-on's own knot: round its spot, each in their place by their order in the cast.
func _knot(id: int) -> Dictionary:
	var i := maxi(_cast.find(id), 0)
	var n := maxi(_cast.size(), 3)
	var a := TAU * float(i) / float(n) + float(int(record.id) % 7) * 0.4
	var centre: Vector2 = _d.at
	return {"centre": centre, "spot": centre + Vector2(cos(a), sin(a)) * KNOT_R * (1.0 + 0.15 * float(n - 3)),
		"group": 800000 + int(record.id)}


static func _noise(k: int, salt: int) -> float:
	return float(posmod(hash(k * 7919 + salt * 104729), 100000)) / 100000.0
