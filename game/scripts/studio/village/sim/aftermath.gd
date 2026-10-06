extends RefCounted
## What lasts from the way a scene ended (plan LIVELY-VILLAGE 3.1, rules side): each reaction module with a `decide`
## (village/reactions/) is asked once, at the minute the event resolves, who does it for certain (the cast) and what
## that changes (opinions, stress). Applied once, keyed by the event, saved in v.runtime.aftermath; on the live path
## only (the chronicle has no runtime and never comes here). The bodies read the cast (cast_of) and play it.
##
##   Aftermath.settle(v, e)          at an event's resolve (runtime.gd): once per event
##   Aftermath.cast_of(v, cue) -> {id: module name}     the cast for a cue whose `event` is settled
##   Aftermath.cue_of(v, e) -> Dictionary               the rules' view of the end: kind, subject, other, who, outcome
##
## Effects: ["opinion", a, b, amount] (a's feeling for b), ["stress", id, -1, amount].
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Registry := preload("res://scripts/studio/village/reaction_registry.gd")

const KEEP_DAYS := 3
const STRESS_MOST := 1000

static var _registry: Registry


static func settle(v: S.Village, e: Dictionary) -> void:
	if v.runtime.is_empty() or e.get("type", "") == "incident":
		return
	var all: Dictionary = v.runtime.get_or_add("aftermath", {})
	var key := str(e.id)
	if all.has(key):
		return
	var cue := cue_of(v, e)
	var cast := {}
	var taken := {}
	for m: Script in _modules().modules:
		if not m.get_script_method_list().any(func(f: Dictionary) -> bool: return f.name == "decide"):
			continue
		if not Registry.answering_static(m, str(cue.kind)):
			continue
		var d: Dictionary = m.call("decide", v, cue, hash([int(e.id), _modules().name_of(m)]))
		for id: int in d.get("cast", []):
			if not taken.has(id):                             # one part each: the first module (by name) to cast them
				taken[id] = true
				cast[str(id)] = _modules().name_of(m)
		for fx: Array in d.get("effects", []):
			_apply(v, fx)
	all[key] = {"cast": cast, "day": v.day}
	for k: String in all.keys():
		if int(all[k].day) < v.day - KEEP_DAYS:
			all.erase(k)


static func cast_of(v: S.Village, cue: Dictionary) -> Dictionary:
	var out := {}
	if v == null or v.runtime.is_empty():
		return out
	var settled: Dictionary = v.runtime.get("aftermath", {}).get(str(cue.get("event", -1)), {})
	for k: String in settled.get("cast", {}):
		out[int(k)] = str(settled.cast[k])
	return out


## The end as the rules see it: "end:<type>:<kind>:<outcome>", the one it was done to, who presided, who was there.
static func cue_of(v: S.Village, e: Dictionary) -> Dictionary:
	var st := {}
	for s in v.stagings:
		if int(s.id) == int(e.id):
			st = s
	var who: Array = []
	var victim := int(e.get("victim", -1))
	for person: Dictionary in st.get("people", []):
		var id := int(person.id)
		if id != victim and id >= 0 and id < v.people.size() and v.people[id].alive and v.people[id].present:
			who.append(id)
	var subject_name := v.people[victim].name if victim >= 0 and victim < v.people.size() else ""
	return {"kind": "end:%s:%s:%s" % [str(e.type), str(st.get("kind", "")), str(e.get("outcome", ""))], "event": int(e.id),
		"subject": victim, "subject_name": subject_name, "other": int(st.get("roles", {}).get("authority", -1)),
		"outcome": str(e.get("outcome", "")), "alive": victim >= 0 and v.people[victim].alive, "who": who}


static func _apply(v: S.Village, fx: Array) -> void:
	match str(fx[0]):
		"opinion":
			var a := int(fx[1])
			var b := int(fx[2])
			if a >= 0 and b >= 0 and a != b and v.people[a].alive:
				Village.set_opinion(v, a, b, Village.opinion(v, a, b) + int(fx[3]))
		"stress":
			var p := v.people[int(fx[1])]
			p.stress = clampi(p.stress + int(fx[3]), 0, STRESS_MOST)


static func _modules() -> Registry:
	if _registry == null:
		_registry = Registry.new(Registry.REACTIONS)
	return _registry
