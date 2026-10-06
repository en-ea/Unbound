extends RefCounted
## The village's goings-on (plan LIVELY-VILLAGE 2.3, step 4): every kind of thing that happens in the village beyond the
## rules' own acts and the argument - someone in want going door to door, a knot muttering about a neighbour, a
## wedding's feast in the square, a funeral's procession, the market, the service, a hue and cry - one file a kind in
## village/goings_on/, found like the reactions (reaction_registry.gd). Live path only: the chronicle never runs it, so
## the reference's golden hashes do not move.
##
## The rules side here: every quarter hour of the day (07:00-21:00) each kind, in name order, is offered the minute; a
## kind decides, keyed, whether it happens, who is in it, how it goes and what it changes - once - and returns its
## record (sim/happenings.gd's form, with a `cast` of roles). The bodies play it (people/going_on_runner.gd, from the
## kind's `plays`); the news reads its events and its phases' headlines.
##
##   GoingsOn.next_due(v) -> int       the next quarter hour it runs (game minute; -1 none: not live)
##   GoingsOn.run_due(v)               offer the minute to every kind (runtime.gd advance)
##   GoingsOn.module(kind) -> Script   the kind's file (null: not a going-on)
##   GoingsOn.free(v, id, now) -> bool        free to be cast: alive, here, not locked, in nothing going on
##   GoingsOn.last(v, kind) -> int             the game minute this kind last began (-1 never)
##
## A kind (village/goings_on/<kind>.gd, extends going_on.gd):
##   const KIND, TIER ("small", "caused", "calendar"), NEWS {event type: [news kind, severity, travel]}
##   static func offer(v, now, k) -> Dictionary     the record, or {} (it decides and applies everything at once)
##   static func plays(h, role, me) -> Array        each cast member's steps (people/performer.gd)
##   static func headline(v, h, phase) -> String    the news line as a phase begins ("" none)
const S := preload("res://scripts/studio/village/sim/state.gd")
const R := preload("res://scripts/studio/village/sim/rng.gd")
const Happenings := preload("res://scripts/studio/village/sim/happenings.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Registry := preload("res://scripts/studio/village/reaction_registry.gd")

const FOLDER := "res://scripts/studio/village/goings_on/"
const P_GOINGS := 0x60f1a9   # the goings-on's key
const EVERY := 15            # game minutes between offers
const DAY_FROM := 420        # 07:00
const DAY_TO := 1260         # 21:00

static var _registry: Registry
static var _by_kind := {}


static func runtime_ready(v: S.Village) -> void:
	if not v.runtime.has("goings"):
		v.runtime.goings = {"last": int(v.runtime.now), "began": {}}
	Happenings.runtime_ready(v)


static func next_due(v: S.Village) -> int:
	if v.runtime.is_empty() or _modules().modules.is_empty():
		return -1
	runtime_ready(v)
	var t := (int(v.runtime.goings.last) / EVERY + 1) * EVERY
	var m := t % 1440
	if m < DAY_FROM:
		t += DAY_FROM - m
	elif m >= DAY_TO:
		t += 1440 - m + DAY_FROM
	return t


static func run_due(v: S.Village) -> void:
	runtime_ready(v)
	var now := int(v.runtime.now)
	v.runtime.goings.last = now
	var i := 0
	for m: Script in _modules().modules:
		i += 1
		var k := R.key(R.key(R.key(v.base, P_GOINGS), now), i)
		var h: Dictionary = m.call("offer", v, now, k)
		if h.is_empty():
			continue
		_complete(v, m, h)
		Happenings.add(v, h)
		v.runtime.goings.began[str(h.kind)] = int(h.phases[0][1]) if not (h.phases as Array).is_empty() else now


static func module(kind: String) -> Script:
	if _by_kind.is_empty():
		for m: Script in _modules().modules:
			_by_kind[str(Registry.constant(m, "KIND", ""))] = m
	return _by_kind.get(kind)


static func free(v: S.Village, id: int, now: int) -> bool:
	if id < 0 or id >= v.people.size():
		return false
	var p := v.people[id]
	if not p.alive or not p.present or p.locked or p.authored != "":
		return false
	for h: Dictionary in v.runtime.get("happenings", []):
		if int(h.ends) > now and (h.get("cast", {}) as Dictionary).values().has(id):
			return false
		if int(h.ends) > now and (int(h.get("a", -1)) == id or int(h.get("b", -1)) == id):
			return false
	return true


static func last(v: S.Village, kind: String) -> int:
	return int(v.runtime.get("goings", {}).get("began", {}).get(kind, -1))


## The fields every record has (sim/happenings.gd's form), filled where the kind left them out.
static func _complete(v: S.Village, m: Script, h: Dictionary) -> void:
	h.kind = str(h.get("kind", Registry.constant(m, "KIND", "")))
	var cast: Dictionary = h.get_or_add("cast", {})
	var defaults := {"source": "goings", "place": v.pl_square, "at": [], "a": int(cast.get("a", -1)), "b": int(cast.get("b", -1)),
		"path": [], "phases": [], "peacemaker": -1, "crime": -1, "events": [], "near": [], "step_in": -1, "outcome": ""}
	for key: String in defaults:
		if not h.has(key):
			h[key] = defaults[key]
	if (h.path as Array).is_empty():
		h.path = (h.phases as Array).map(func(ph: Array) -> String: return str(ph[0]))
	if not h.has("minute"):
		h.minute = int(h.phases[0][1]) if not (h.phases as Array).is_empty() else int(v.runtime.now)
	if not h.has("ends"):
		h.ends = int(h.phases[h.phases.size() - 1][2]) if not (h.phases as Array).is_empty() else int(v.runtime.now)


static func _modules() -> Registry:
	if _registry == null:
		_registry = Registry.new(FOLDER)
	return _registry
