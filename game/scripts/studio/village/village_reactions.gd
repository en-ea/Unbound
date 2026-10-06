extends Node
## The village's side of people answering what they see (plan LIVELY-VILLAGE 3.1, 3.4): the residents' bodies, the
## rules' facts and cast, and where things are, handed to people/reacting.gd; the cue sources (village/cues/) scanned
## twice a second. Made by residents.gd, which owns the bodies; nothing here is a reaction - those are the modules.
##
##   cues in:  a stage's end (live.gd -> end_of)    "end:<type>:<kind>:<outcome>", the crowd let go to it
##             someone leaving a circle (parting)    "parting", the leaver; those staying nod
##             village/cues/*.gd scan(self)          an enemy in the village, his kill brought in, ...
##
##   targets (performer.gd): "subject" "other" (people in the cue), "place", "player", "home", "enemy" or "node" (the
##   cue's node), "away" (towards what their day wants next, a few metres), a person's id, a point.
##   do (performer.gd): "take" the cue's carcass.
const Reacting := preload("res://scripts/studio/people/reacting.gd")
const Registry := preload("res://scripts/studio/village/reaction_registry.gd")
const Facts := preload("res://scripts/studio/village/reaction_facts.gd")
const Aftermath := preload("res://scripts/studio/village/sim/aftermath.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Speech := preload("res://scripts/studio/people/speech.gd")

const SCAN_EVERY := 0.5      # seconds between the cue sources' looks
const AWAY_LEAST := 6.0      # metres "away" takes them on towards their day, at least ...
const AWAY_SPREAD := 6.0     # ... and up to this much more

var res: Node                # residents.gd
var reacting: Reacting
var sources: Array = []      # the cue sources (village/cues/), one each
var cued: Array = []         # [seconds, kind, how many] the latest cues given (a measure)
var counts := {}             # "<kind>:<first word>" -> [cues, people reached], all run long (a measure)
var _scan_in := SCAN_EVERY


func _init(the_residents: Node, proofs := false) -> void:
	res = the_residents
	name = "VillageReactions"
	reacting = Reacting.new(Registry.new(Registry.REACTIONS, proofs), _director())
	reacting.name = "Reacting"
	add_child(reacting)
	for m: Script in Registry.new(Registry.CUES, proofs).modules:
		sources.append(m.new())


func _process(dt: float) -> void:
	_scan_in -= dt
	if _scan_in > 0.0 or VillageSession.village == null:
		return
	_scan_in = SCAN_EVERY
	for s in sources:
		for found: Array in s.scan(self):
			cue(found[0], found[1])


## A cue to everyone in `ids` it reaches.
func cue(c: Dictionary, ids: Array) -> void:
	if not preload("res://scripts/studio/village/legacy_route.gd").handles(str(c.get("kind",""))):
		return
	if ids.is_empty():
		return
	reacting.cue(c, ids)
	cued.append([res._age, str(c.get("kind", "")), ids.size()])
	var kind := str(c.get("kind", ""))
	var n: Array = counts.get_or_add(kind.get_slice(":", 0) + (":" + kind.get_slice(":", 1) if kind.contains(":") else ""), [0, 0])
	n[0] += 1
	n[1] += ids.size()
	if cued.size() > 400:
		cued = cued.slice(200)


## A scene is over: its crowd, just let go by the stage, breaks up - each their own way (live.gd's stage end). The
## one it was done to ("subject"), let go once off the device, has a cue of their own: "freed:..." (walk_free.gd).
func end_of(event_id: int, ids: Array, at: Vector2, role := "crowd") -> void:
	var v = VillageSession.village
	var e := Runtime.event_by_id(v, event_id)
	if e.is_empty():
		return
	var c := Aftermath.cue_of(v, e)
	c.place = at
	c.key = hash(["end", event_id])       # (those let go later - the elder after the verdict - share the crowd's knots)
	if role == "subject":
		c.kind = "freed:" + str(c.kind).trim_prefix("end:")
	cue(c, ids)


## `id` leaves a circle for their day: a word and a wave (goodbye.gd); those staying nod after them.
func parting(id: int, centre: Vector2, staying: Array) -> void:
	var c := {"kind": "parting", "subject": id, "place": centre if centre != Vector2.INF else res._movers[id].pos,
		"who": staying}
	cue(c, [id])
	var left: Array = staying.filter(func(o: int) -> bool: return o != id and res.bodies.has(o))
	if left.size() == 1 and not res.society.in_sit.has(left[0]):
		cue({"kind": "seeoff", "subject": id, "place": c.place, "who": [id]}, left)   # (a talk of two is over: the one
		return                                                                        # left watches them go: see_off.gd)
	for other: int in left:
		res.bodies[other].nod()


## People free to be cued near a point: drawn, out of doors, nobody higher holding them (free_only: nobody at all, not
## even a conversation). -> [[id, metres], ...] nearest first (the cue sources' helper).
func near(at: Vector2, metres: float, most := 24, free_only := false) -> Array:
	var v = VillageSession.village
	var out: Array = []
	for id: int in res.bodies:
		if res._skip.has(id) or not res.owners.can_claim(id, Reacting.HOLD) or (free_only and not res.owners.is_free(id)):
			continue
		var p = v.people[id]
		if not p.alive or not p.present or p.locked:
			continue
		var m = res._movers[id]
		if m.indoors or not (res.bodies[id] as Node3D).visible:
			continue
		var d: float = m.pos.distance_to(at)
		if d <= metres:
			out.append([id, d])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[1] < y[1] or (x[1] == y[1] and x[0] < y[0]))
	return out.slice(0, most)


func _director() -> Dictionary:
	return {
		"mover": func(id: int) -> RefCounted: return res._movers[id],
		"body": func(id: int) -> Node3D: return res.bodies[id],
		"claim": _claim,
		"holds": func(id: int, by: String) -> bool: return res.owners.held(id, by),
		"suspended": func(id: int, by: String) -> bool: return res.owners.suspended(id, by),
		"release": func(id: int, by: String) -> void: res.release_to_day(id, by),
		"facts": func(id: int, c: Dictionary) -> Dictionary:
			return Facts.of(VillageSession.village, id, c, res._movers[id].pos),
		"cast": func(c: Dictionary) -> Dictionary: return Aftermath.cast_of(VillageSession.village, c),
		"at": _at,
		"route": func(a: Vector2, b: Vector2) -> PackedVector2Array: return res._router._route(a, b),
		"standable": func(p: Vector2) -> bool: return res._standable(p),
		"say": func(id: int, text: String) -> void:
			res.speech.say(res.bodies[id], text, Speech.SCENE, 7100000 + id, res.voice_of(id), 2.6),
		"murmur": func(id: int, group: int, seconds: float) -> void:
			res.speech.murmur(res.bodies[id], group, res.voice_of(id), seconds),
		"clock": func() -> float: return res._age,
		"frozen": func() -> bool: return Controls.locked or VillageSession.background,
		"do": _do,
	}


## A step that does something to the world (performer.gd "do"): "take" the cue's thing (a carcass left lying is
## carried off by someone you can see, not made to vanish behind a hint).
func _do(_id: int, what: String, c: Dictionary) -> void:
	var n: Variant = c.get("node")
	if what == "take" and n != null and is_instance_valid(n) and (n as Node).has_method("vanish") \
			and (n as Node).is_in_group("carcass"):
		get_tree().call_group("hud", "hint", "Someone from the village is taking the %s you left lying there."
			% str(c.get("thing", "kill")))
		n.vanish()


func _claim(id: int, by: String, priority: int, keep: bool) -> bool:
	if not res.bodies.has(id) or res._skip.has(id):
		return false
	var p = VillageSession.village.people[id]
	if not p.alive or not p.present or p.locked:
		return false
	if not res.owners.claim(id, by, priority, Callable(), keep):
		return false
	if keep:
		res.owners.resumed[by] = func(back: int) -> void: res._applied.erase(back)
	res._applied.erase(id)
	return true


func _at(target: Variant, id: int, c: Dictionary) -> Vector2:
	if target is Vector2:
		return target
	if target is int:
		return _person_at(target)
	match str(target):
		"subject":
			return _person_at(int(c.get("subject", -1)))
		"other":
			return _person_at(int(c.get("other", -1)))
		"place":
			return c.get("place", Vector2.INF)
		"player":
			return res.player_xz() if res._player != null else Vector2.INF
		"home":
			return res.door_of(id)
		"enemy", "node":
			var n: Variant = c.get("node")
			if n == null or not is_instance_valid(n) or (n.has_method("is_alive") and not n.is_alive()):
				return Vector2.INF
			return Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z)
		"away":
			return _away(id, c)
	return Vector2.INF


## Where someone is: their body (a stage may be walking it; the mover is theirs only off the stage). INF: not to be seen.
func _person_at(who: int) -> Vector2:
	if who < 0 or not res.bodies.has(who):
		return Vector2.INF
	var body: Node3D = res.bodies[who]
	if not is_instance_valid(body) or not body.is_visible_in_tree():
		return Vector2.INF
	return Vector2(body.global_position.x, body.global_position.z)


## A few metres on towards what their day wants next (their own errand: so a crowd breaks up each their own way);
## with nowhere to be, on from the place the way they already stand.
func _away(id: int, c: Dictionary) -> Vector2:
	var from: Vector2 = res._movers[id].pos
	var k := float(absi(hash([c.get("key", 0), id, 17])) % 1000) / 1000.0
	var reach := AWAY_LEAST + AWAY_SPREAD * k
	var trip: Dictionary = Runtime.routine(VillageSession.village, id)
	var to := Vector2.INF
	if not trip.is_empty() and str(trip.get("place", "")) != "":
		to = res.place(str(trip.place))
	if to == Vector2.INF or to.distance_to(from) < 0.5:
		var place: Vector2 = c.get("place", from)
		var way := from - place
		if way.length() < 0.1:
			way = Vector2(cos(k * TAU), sin(k * TAU))
		to = from + way.normalized() * reach
	elif to.distance_to(from) > reach:
		var path: PackedVector2Array = res._router._route(from, to)
		to = _along(from, path, reach)
	if not res._standable(to):
		return from
	return to


## The point `metres` along a walk from `from` through `path`.
static func _along(from: Vector2, path: PackedVector2Array, metres: float) -> Vector2:
	var at := from
	var left := metres
	for p: Vector2 in path:
		var d := at.distance_to(p)
		if d >= left:
			return at + (p - at) * (left / d)
		left -= d
		at = p
	return at
