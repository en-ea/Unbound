extends RefCounted
## Happenings, decided by the rules (plan VILLAGE-LIFE-AND-NEWS section 4: the rules decide, the body plays, the news
## reads). A happening is a compact piece of village life: a cast, a path through its phases, and consequences that
## last. The first is the argument: words, then heated or cooled; heated, then parted by someone kind, or blows, or
## cooled. Decided here, keyed, applied once and saved (v.runtime.happenings); played on the bodies by
## people/happening_runner.gd from people/happening_kinds.gd; the news reads the events every happening logs.
## Live path only - the director's attention, a deed the day planned, a request (world_actions.gd) - so the chronicle
## (step_day) never runs it and the reference's golden hashes do not move.
##
##   Happenings.from_deed(v, it, result) -> record   a quarrel or brawl the rules just ran (Incidents.show calls it
##                                                   for the player's village): its outcome is already decided and
##                                                   applied (crime.gd quarrel, commit_brawl); this adds the rest
##   Happenings.argue(v, a, b, at_dm, near) -> record   two who dislike each other met near the player (a request):
##                                                   the rules decide whether it is an argument at all and how it goes
##   Happenings.step_in(v, id) -> record             the player steps between them: parted, by the player
##   Happenings.wary(v, a, b) -> bool                a keeps clear of b for the rest of the day (after an argument)
##   Happenings.argued_today(v, a, b) -> bool        one argument a pair a day
##   Happenings.going_on(v, now) -> Array            the records not yet over
##   Happenings.add(v, h) -> h                       a record of another kind (sim/town_meeting.gd): its id, kept
##
## A record (JSON-safe; saved): {id, kind, place, at: [x_dm, z_dm], minute, a, b, path: [phase, ...],
##   phases: [[phase, from, to], ...] (game minutes), peacemaker: id | PLAYER | -1, crime: id | -1, events: [ids],
##   ends, step_in: the minute the player may step in until (-1: not), source: "deed" | "meeting"}
const S := preload("res://scripts/studio/village/sim/state.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const R := preload("res://scripts/studio/village/sim/rng.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Crime := preload("res://scripts/studio/village/sim/crime.gd")

const PLAYER := -2                 # the player, as the village's records name them (events.gd name_of)
const P_HAPPEN := 0x4a7713         # the happenings' key
## How long each phase lasts, game minutes (half a real second each): long enough to read from across the square
const PHASE_MINUTES := {"words": 14, "heated": 18, "parted": 10, "blows": 10, "cooled": 6}
const KEEP := 40                   # records kept (the news reads the log; these are for the bodies and the step-in)
const PEACE_LEAST := 60            # a peacemaker's pull (mercy, kin, boldness) must reach this to step in
const HEAT_FROM := 30              # temper and dislike past this make an argument heat up, likelier as they grow
const NEAR_DM := 400               # decimetres: a happening this near the player is something shown (director.gd NEAR_DM)


static func runtime_ready(v: S.Village) -> void:
	for key: String in ["happenings", "argued", "stances"]:
		if not v.runtime.has(key):
			v.runtime[key] = [] if key == "happenings" else {}
	if not v.runtime.has("happening_next"):
		v.runtime.happening_next = 1


## A quarrel or brawl the rules have just run near the player: blows are the rules' own draw (crime.gd); whether words
## heat up, and whether someone kind parts them, is decided here, from who the day puts at the place.
static func from_deed(v: S.Village, it: Dictionary, result: Dictionary) -> Dictionary:
	if not result.get("done", false):
		return {}
	var a := int(it.actor)
	var b := int(it.other)
	var place := int(it.place)
	var minute := int(v.runtime.now) / 1440 * 1440 + int(it.minute) % 1440   # (an intent's minute is the day's: the game's)
	var k := R.key(R.key(R.key(v.base, P_HAPPEN), int(v.runtime.now)), a * 1000 + b)
	var near: Array = Array(Village.witnesses_at(v, place, minute % 1440, a)).filter(func(q: int) -> bool: return q != b)
	var blows: bool = result.get("crime") != null
	var crime_id: int = (result.crime as S.Crime).id if blows else -1
	var ev := _last_event(v, ["quarrel", "crime"], a)
	return _record(v, "deed", a, b, place, [], minute, k, near, blows, crime_id, ev)


## Two who dislike each other met near the player. The rules decide: not twice a day, not if either keeps clear of the
## other (wary), not unless the dislike is real; then the quarrel itself (crime.gd: words, or blows between deep
## enemies), applied once. `at` the meeting's point in decimetres; `near` the residents near it (the body's context).
static func argue(v: S.Village, a: int, b: int, at: Array, near: Array) -> Dictionary:
	runtime_ready(v)
	if a == b or a < 0 or b < 0 or a >= v.people.size() or b >= v.people.size():
		return {"refused": "no one there"}
	var p := v.people[a]
	var q := v.people[b]
	if not p.alive or not p.present or not q.alive or not q.present or p.authored != "" or q.authored != "":
		return {"refused": "no one there"}
	if argued_today(v, a, b):
		return {"refused": "argued today"}
	if wary(v, a, b) or wary(v, b, a):
		return {"refused": "keeping clear"}
	if mini(Village.opinion(v, a, b), Village.opinion(v, b, a)) > -30:
		return {"refused": "no quarrel"}
	var place := _nearest_place(v, int(at[0]), int(at[1]))
	var minute := int(v.runtime.now)
	var k := R.key(R.key(R.key(v.base, P_HAPPEN), minute), a * 1000 + b)
	var result := Crime.quarrel(v, p, q, k, place, minute % 1440, Crime.player_sees(v, place, minute % 1440))
	var blows: bool = result.get("crime") != null
	var crime_id: int = (result.crime as S.Crime).id if blows else -1
	var ev := _last_event(v, ["quarrel", "crime"], a)
	var cast: Array = near.filter(func(id: int) -> bool: return id != a and id != b and id >= 0 and id < v.people.size())
	return _record(v, "meeting", a, b, place, at, minute, k, cast, blows, crime_id, ev)


## The player steps between two arguing: parted, by them. Only while words or heat last and no blow is coming (the
## rules drew blows at the start; a step in does not undo a deed). -> the record, or {"refused": why}
static func step_in(v: S.Village, id: int) -> Dictionary:
	runtime_ready(v)
	var now := int(v.runtime.now)
	for h: Dictionary in v.runtime.happenings:
		if int(h.id) != id:
			continue
		if h.kind != "argument" or now > int(h.get("step_in", -1)):
			return {"refused": "too late"}
		if "blows" in h.path:
			return {"refused": "they will not hear it"}
		var start := maxi(now, int(h.minute))
		var path: Array = []
		var phases: Array = []
		for ph: Array in h.phases:
			if int(ph[1]) < start:
				path.append(ph[0])
				phases.append([ph[0], int(ph[1]), mini(int(ph[2]), start)])
		path.append("parted")
		phases.append(["parted", start, start + int(PHASE_MINUTES.parted)])
		h.path = path
		h.phases = phases
		h.peacemaker = PLAYER
		h.ends = start + int(PHASE_MINUTES.parted)
		h.step_in = -1
		for who: int in [int(h.a), int(h.b)]:
			_remember(v, who, "parted_by_you", 6)
		var causes := PackedInt32Array(h.events) if not h.events.is_empty() else PackedInt32Array()
		h.events.append(E.log_event(v, "parted", PLAYER, int(h.a), {"other": int(h.b), "place": v.place_names[int(h.place)],
			"happening": int(h.id)}, causes, "a stranger stepping between %s and %s" % [E.name_of(v, int(h.a)), E.name_of(v, int(h.b))]))
		return h
	return {"refused": "nothing going on"}


static func argued_today(v: S.Village, a: int, b: int) -> bool:
	return int(v.runtime.get("argued", {}).get(_pair(a, b), -1)) == int(v.runtime.now) / 1440


static func wary(v: S.Village, a: int, b: int) -> bool:
	return int(v.runtime.get("stances", {}).get("%d>%d" % [a, b], -1)) > int(v.runtime.now)


static func going_on(v: S.Village, now: int) -> Array:
	return v.runtime.get("happenings", []).filter(func(h: Dictionary) -> bool: return int(h.ends) > now)


# ---------- inside ----------

static func _record(v: S.Village, source: String, a: int, b: int, place: int, at: Array, minute: int, k: int, near: Array,
		blows: bool, crime_id: int, ev: int) -> Dictionary:
	runtime_ready(v)
	var r := v.runtime
	var p := v.people[a]
	var q := v.people[b]
	var path: Array = ["words"]
	var peacemaker := -1
	if blows:
		path.append_array(["heated", "blows"])
	else:
		var worst := mini(Village.opinion(v, a, b), Village.opinion(v, b, a))
		var heat := R.idiv(p.traits[C.TEMPER] + q.traits[C.TEMPER], 2) - R.idiv(worst, 2)
		if R.chance(R.key(k, 1), clampi((heat - HEAT_FROM) * 12000, 0, 900000)):
			path.append("heated")
			peacemaker = _peacemaker(v, a, b, near, R.key(k, 2))
			path.append("parted" if peacemaker >= 0 else "cooled")
		else:
			path.append("cooled")
	var phases: Array = []
	var t := minute
	for ph: String in path:
		phases.append([ph, t, t + int(PHASE_MINUTES[ph])])
		t += int(PHASE_MINUTES[ph])
	var h := add(v, {"kind": "argument", "source": source, "place": place, "at": at, "minute": minute,
		"a": a, "b": b, "path": path, "phases": phases, "peacemaker": peacemaker, "crime": crime_id,
		"events": [ev] if ev >= 0 else [], "ends": t, "near": near.slice(0, 8),
		"step_in": -1 if blows else int(phases[mini(1, phases.size() - 1)][2])})
	if peacemaker >= 0:
		Village.set_opinion(v, a, peacemaker, Village.opinion(v, a, peacemaker) + 4)
		Village.set_opinion(v, b, peacemaker, Village.opinion(v, b, peacemaker) + 4)
		var causes := PackedInt32Array([ev]) if ev >= 0 else PackedInt32Array()
		h.events.append(E.log_event(v, "parted", peacemaker, a, {"other": b, "place": v.place_names[place], "happening": int(h.id)},
			causes, "%s stepping between %s and %s" % [E.name_of(v, peacemaker), E.name_of(v, a), E.name_of(v, b)]))
	r.argued[_pair(a, b)] = minute / 1440
	var day_end := (minute / 1440 + 1) * 1440
	r.stances["%d>%d" % [a, b]] = day_end
	r.stances["%d>%d" % [b, a]] = day_end
	_tidy(v)
	return h


static func add(v: S.Village, h: Dictionary) -> Dictionary:
	runtime_ready(v)
	var r := v.runtime
	h.id = int(r.happening_next)
	r.happening_next = int(r.happening_next) + 1
	r.happenings.append(h)
	while r.happenings.size() > KEEP:
		r.happenings.pop_front()
	_shown(v, h)
	return h


## A happening begun near the player is something shown: the director's quiet counts from it (plan LIVELY-VILLAGE 5.1).
static func _shown(v: S.Village, h: Dictionary) -> void:
	var pl: Dictionary = v.runtime.get("player", {})
	if not pl.get("present", false):
		return
	var x := 0
	var z := 0
	var at: Array = h.get("at", [])
	if at.size() == 2:
		x = int(at[0])
		z = int(at[1])
	else:
		var place: Variant = h.get("place", -1)
		var i: int = int(v.place_ids.get(place, -1)) if place is String else int(place)
		if i < 0 or i >= v.place_names.size() or not v.place_has_pos[i]:
			return
		x = v.place_x[i]
		z = v.place_z[i]
	if (x - int(pl.x)) * (x - int(pl.x)) + (z - int(pl.z)) * (z - int(pl.z)) <= NEAR_DM * NEAR_DM:
		_quiet_from(v, int(v.runtime.now))


static func _quiet_from(v: S.Village, minute: int) -> void:
	v.runtime.quiet_since = maxi(int(v.runtime.get("quiet_since", minute)), minute)


## Who parts them: a grown one the day puts there, with mercy, kin to either, or bold enough - and not their enemy.
static func _peacemaker(v: S.Village, a: int, b: int, near: Array, k: int) -> int:
	var best := -1
	var best_pull := PEACE_LEAST - 1
	for id: int in near:
		if id == a or id == b or id < 0 or id >= v.people.size():
			continue
		var w := v.people[id]
		if not w.alive or not w.present or w.authored != "" or Village.age_of(v, w) < 16:
			continue
		if mini(Village.opinion(v, id, a), Village.opinion(v, id, b)) < -20:
			continue
		var pull: int = R.idiv(w.values[C.V_MERCY], 2) + R.idiv(w.traits[C.BOLD], 3) + (35 if Village.is_kin(v, id, a) or Village.is_kin(v, id, b) else 0) \
			+ R.pick(R.key(k, id), 20)
		if pull > best_pull:
			best_pull = pull
			best = id
	return best


static func _remember(v: S.Village, id: int, token: String, feeling: int) -> void:
	var known: Dictionary = v.runtime.acquaintance.get_or_add(str(id), {})
	var memories: Array = known.get_or_add("memories", [])
	memories.append(token)
	while memories.size() > 12:
		memories.pop_front()
	known.feeling = clampi(int(known.get("feeling", 0)) + feeling, -100, 100)


static func _last_event(v: S.Village, types: Array, who: int) -> int:
	for i in range(v.events.size() - 1, maxi(-1, v.events.size() - 6), -1):
		if v.events[i].type in types and v.events[i].who == who:
			return v.events[i].id
	return -1


static func _nearest_place(v: S.Village, x: int, z: int) -> int:
	var best := 0
	var best_d := 9223372036854775807
	for i in v.place_names.size():
		if not v.place_has_pos[i]:
			continue
		var d := (v.place_x[i] - x) * (v.place_x[i] - x) + (v.place_z[i] - z) * (v.place_z[i] - z)
		if d < best_d:
			best_d = d
			best = i
	return best


static func _pair(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


## Old caps and stances go: only today's matter.
static func _tidy(v: S.Village) -> void:
	var today := int(v.runtime.now) / 1440
	var argued: Dictionary = v.runtime.argued
	for key: String in argued.keys():
		if int(argued[key]) < today:
			argued.erase(key)
	var stances: Dictionary = v.runtime.stances
	for key: String in stances.keys():
		if int(stances[key]) <= int(v.runtime.now):
			stances.erase(key)
