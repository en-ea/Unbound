extends RefCounted
## The town meeting (plan VILLAGE-LIFE-AND-NEWS section 6): when hunger, inequality or fear goes high
## (sim/pressures.gd), the elder calls the village to the square some hours ahead. There the aggrieved speaks, then the
## one they speak against (the full house, the accused), then the elder gives the village's word, from the elder's and
## the village's own values: share grain (food from the fullest houses to the emptiest), set a night watch (theft
## harder, fear down), or nothing (they part angrier). Decided and applied here, once, keyed and saved; a happening
## record (sim/happenings.gd) the bodies play (people/happening_kinds.gd "meeting") and the news reads.
## Live path only (Runtime.advance): the chronicle never runs it.
##
##   TownMeeting.call_for(v, cause, ev) -> record | {}   a pressure gone high (ev: its event): a meeting at the square,
##                                                       announced; at most one in EVERY_DAYS game days
##   TownMeeting.next_due(v) -> int      the minute a meeting is next decided (-1: none waiting)
##   TownMeeting.run_due(v)              the decisions due by now
##   TownMeeting.watched(v) -> bool      a night watch is set
const S := preload("res://scripts/studio/village/sim/state.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const R := preload("res://scripts/studio/village/sim/rng.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Happenings := preload("res://scripts/studio/village/sim/happenings.gd")

const P_MEET := 0x3e771c           # the meetings' key
const PATH := ["gather", "speak", "decide", "disperse"]
const PHASE_MINUTES := {"gather": 40, "speak": 60, "decide": 16, "disperse": 10}   # (half a real second each)
const EVERY_DAYS := 3              # a meeting at most once in this many game days
const SLOTS := [720, 1020]         # noon, or five in the afternoon ...
const AHEAD := 90                  # ... at least this many game minutes after the call (word goes round the doors)
const SHARE_FROM := 85             # the pull to share grain must reach this (mercy, need, less the full house's greed)
const WATCH_FROM := 90             # the pull to set a watch (law, fear)
const WATCH_DAYS := 3
const WATCH_FEAR := 150            # fear a watch takes away
const SHARE_PART := 40             # percent of a full house's surplus (over the village's mean a mouth) given
const CAUSE_WORDS := {"hunger": "the empty stores", "inequality": "the full houses and the empty", "fear": "the fear in the village"}
const OUTCOMES := {
	"share": ["The village agreed to share grain", "sacks carried from the %s house to the %s house"],
	"watch": ["A night watch is set", "torches at the crossroads after dark"],
	"nothing": ["The meeting broke up in anger", "shouting as the crowd broke up"],
}


static func runtime_ready(v: S.Village) -> void:
	if not v.runtime.has("town"):
		v.runtime.town = {"last_day": -1000000, "watch_until": -1}


static func watched(v: S.Village) -> bool:
	return int(v.runtime.get("town", {}).get("watch_until", -1)) > int(v.runtime.get("now", 0))


static func call_for(v: S.Village, cause: String, ev: int) -> Dictionary:
	runtime_ready(v)
	Happenings.runtime_ready(v)
	var now := int(v.runtime.now)
	if now / 1440 - int(v.runtime.town.last_day) < EVERY_DAYS:
		return {}
	for h: Dictionary in v.runtime.happenings:
		if str(h.kind) == "meeting" and int(h.ends) > now:
			return {}
	var elder := _elder(v)
	if elder < 0:
		return {}
	var houses := _by_food(v)
	var a := -1
	for house: int in houses:                  # the emptiest house with someone to speak for it ...
		a = _head(v, house, [elder])
		if a >= 0:
			break
	var b := -1
	for i in range(houses.size() - 1, -1, -1):  # ... and the fullest
		b = _head(v, houses[i], [elder, a])
		if b >= 0:
			break
	if cause == "fear":
		var crime := _latest_crime(v)
		if crime != null:
			if _can_speak(v, crime.victim) and crime.victim != elder:
				a = crime.victim
			var said := _said(v, crime)
			if _can_speak(v, said) and said != elder and said != a:
				b = said
	if a < 0 or b < 0 or a == b:
		return {}
	var m := now % 1440
	var start := now - m + 1440 + int(SLOTS[0])
	for slot: int in SLOTS:
		if slot - m >= AHEAD:
			start = now - m + slot
			break
	var phases: Array = []
	var t := start
	var decide_at := -1
	for ph: String in PATH:
		if ph == "decide":
			decide_at = t
		phases.append([ph, t, t + int(PHASE_MINUTES[ph])])
		t += int(PHASE_MINUTES[ph])
	var place: int = v.pl_square
	var h := Happenings.add(v, {"kind": "meeting", "source": "pressure", "cause": cause, "place": place, "at": [],
		"minute": start, "called": now, "a": a, "b": b, "elder": elder, "speakers": [a, b, elder], "path": PATH.duplicate(),
		"phases": phases, "peacemaker": -1, "crime": -1, "events": [], "ends": t, "near": [], "step_in": -1, "outcome": "",
		"decide_at": decide_at})
	var when := "at noon" if start - (now - m) == 720 else ("this afternoon" if start < now - m + 1440 else "tomorrow at noon")
	h.events.append(E.log_event(v, "meeting", elder, a, {"happening": int(h.id), "phase": "called", "cause": cause,
		"place": v.place_names[place], "minute": start, "headline": "Town meeting at the square %s: %s" % [when, CAUSE_WORDS.get(cause, "")]},
		PackedInt32Array([ev]) if ev >= 0 else PackedInt32Array(), "the elder sending word round the doors"))
	v.runtime.town.last_day = now / 1440
	return h


static func next_due(v: S.Village) -> int:
	var best := -1
	for h: Dictionary in v.runtime.get("happenings", []):
		if str(h.kind) == "meeting" and str(h.get("outcome", "")).is_empty():
			var at := int(h.decide_at)
			if best < 0 or at < best:
				best = at
	return best


static func run_due(v: S.Village) -> void:
	var now := int(v.runtime.now)
	for h: Dictionary in v.runtime.get("happenings", []):
		if str(h.kind) == "meeting" and str(h.get("outcome", "")).is_empty() and int(h.decide_at) <= now:
			_decide(v, h)


# ---------- the decision ----------

static func _decide(v: S.Village, h: Dictionary) -> void:
	runtime_ready(v)
	var k := R.key(R.key(v.base, P_MEET), int(h.id))
	var elder := int(h.elder)
	var a := int(h.a)
	var b := int(h.b)
	var mercy := 0
	var law := 0
	var n := 0
	for p in v.people:
		if p.alive and p.present and p.authored == "" and Village.age_of(v, p) >= 16:
			mercy += p.values[C.V_MERCY]
			law += p.values[C.V_LAW]
			n += 1
	mercy = R.idiv(mercy, maxi(n, 1))
	law = R.idiv(law, maxi(n, 1))
	if _can_speak(v, elder):
		mercy = R.idiv(mercy + v.people[elder].values[C.V_MERCY], 2)
		law = R.idiv(law + v.people[elder].values[C.V_LAW], 2)
	var outcome := "nothing"
	if str(h.cause) == "fear":
		if law + R.idiv(v.fear, 20) + R.pick(R.key(k, 2), 50) >= WATCH_FROM:
			outcome = "watch"
	else:
		var greed: int = v.people[b].traits[C.GREED] if b >= 0 and b < v.people.size() else 50
		if mercy + 40 - R.idiv(greed, 3) + R.pick(R.key(k, 1), 50) >= SHARE_FROM:
			outcome = "share"
	var data := {"happening": int(h.id), "phase": "decided", "outcome": outcome, "cause": str(h.cause),
		"place": v.place_names[int(h.place)], "headline": OUTCOMES[outcome][0]}
	var cue: String = OUTCOMES[outcome][1]
	match outcome:
		"share":
			var moved := _share(v)
			data.moved = int(moved[0])
			cue = cue % [_home(v, int(moved[1])), _home(v, int(moved[2]))]
			if _can_speak(v, a) and _can_speak(v, b):
				Village.set_opinion(v, a, b, Village.opinion(v, a, b) + 6)
				if v.people[b].traits[C.GREED] >= 60 and _can_speak(v, elder):
					Village.set_opinion(v, b, elder, Village.opinion(v, b, elder) - 4)   # made to give
		"watch":
			v.runtime.town.watch_until = int(v.runtime.now) + WATCH_DAYS * 1440
			v.fear = clampi(v.fear - WATCH_FEAR, 0, 1000)
		"nothing":
			if _can_speak(v, a) and _can_speak(v, b):
				Village.set_opinion(v, a, b, Village.opinion(v, a, b) - 8)
				Village.set_opinion(v, b, a, Village.opinion(v, b, a) - 8)
				var day_end := (int(v.runtime.now) / 1440 + 1) * 1440
				v.runtime.stances["%d>%d" % [a, b]] = day_end
				v.runtime.stances["%d>%d" % [b, a]] = day_end
	h.outcome = outcome
	var causes := PackedInt32Array([int(h.events[0])]) if not (h.events as Array).is_empty() else PackedInt32Array()
	h.events.append(E.log_event(v, "meeting", elder, b, data, causes, cue))


## Grain shared: each house over the village's mean a mouth gives SHARE_PART percent of what it has over it; the
## houses under it get the pool by how far under they are (what is left over, the emptiest). -> [moved, the fullest
## house, the emptiest house]
static func _share(v: S.Village) -> Array:
	var total := 0
	var mouths_all := 0
	for hh in v.households:
		var mouths := _mouths(v, hh)
		if mouths > 0:
			total += hh.food
			mouths_all += mouths
	if mouths_all == 0:
		return [0, -1, -1]
	var mean := R.idiv(total, mouths_all)
	var houses := _by_food(v)
	var pool := 0
	for id: int in houses:
		var hh := v.households[id]
		var over := hh.food - mean * _mouths(v, hh)
		if over > 0:
			var give := R.idiv(over * SHARE_PART, 100)
			hh.food -= give
			pool += give
	var moved := pool
	var short_by := {}
	var total_short := 0
	for id: int in houses:
		var under := mean * _mouths(v, v.households[id]) - v.households[id].food
		if under > 0:
			short_by[id] = under
			total_short += under
	for id: int in short_by:
		var get := mini(int(short_by[id]), R.idiv(moved * int(short_by[id]), maxi(total_short, 1)))
		v.households[id].food += get
		pool -= get
	if pool > 0:
		v.households[houses[0]].food += pool       # what is left goes to the emptiest
	return [moved, houses[houses.size() - 1], houses[0]]


# ---------- who ----------

static func _elder(v: S.Village) -> int:
	for id: int in [v.authority, v.priest]:
		if _can_speak(v, id):
			return id
	return -1


## Households with mouths, emptiest first (food a mouth; ties by id).
static func _by_food(v: S.Village) -> Array:
	var rows: Array = []
	for hh in v.households:
		var mouths := _mouths(v, hh)
		if mouths > 0:
			rows.append([R.idiv(hh.food, mouths), hh.id])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	return rows.map(func(r: Array) -> int: return int(r[1]))


## Who speaks for a house: its eldest grown one who can (not those given).
static func _head(v: S.Village, house: int, not_these: Array) -> int:
	var best := -1
	for id in v.households[house].members:
		if not_these.has(int(id)) or not _can_speak(v, int(id)):
			continue
		if best < 0 or Village.age_of(v, v.people[id]) > Village.age_of(v, v.people[best]):
			best = int(id)
	return best


static func _can_speak(v: S.Village, id: int) -> bool:
	if id < 0 or id >= v.people.size():
		return false
	var p := v.people[id]
	return p.alive and p.present and not p.locked and p.authored == "" and Village.age_of(v, p) >= 16


static func _latest_crime(v: S.Village) -> S.Crime:
	for i in range(v.crimes.size() - 1, -1, -1):
		var c := v.crimes[i]
		if v.day - c.day > 5:
			break
		if c.victim >= 0:
			return c
	return null


## Who the village says did it (the strongest belief anyone holds), else -1.
static func _said(v: S.Village, c: S.Crime) -> int:
	var best := -1
	var best_strength := 0
	for p in v.people:
		if not p.alive:
			continue
		for b in p.beliefs:
			if int(b.crime) == c.id and int(b.strength) > best_strength:
				best_strength = int(b.strength)
				best = int(b.culprit)
	return best


static func _home(v: S.Village, house: int) -> String:
	return v.households[house].home.capitalize() if house >= 0 and house < v.households.size() else "next"


## The village's own mouths in a house (Enea's characters are fed by their story: not counted, as in pressures.gd).
static func _mouths(v: S.Village, hh: S.Household) -> int:
	var n := 0
	for id in hh.members:
		var p := v.people[id]
		if p.alive and p.present and p.authored == "":
			n += 1
	return n
