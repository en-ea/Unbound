extends RefCounted
## A kind of going-on (plan LIVELY-VILLAGE 2.3, step 4): one file a kind in village/goings_on/, extending this; the
## rules (sim/goings_on.gd) offer it every quarter hour of the day, the bodies play it (people/going_on_runner.gd), the
## news reads it. Adding a kind is one new file: no list, no edit anywhere else.
##
##   const KIND := "want"                         the record's kind (also the news story's)
##   const TIER := "small"                        "small", "caused" (village-scale, by a cause) or "calendar"
##   const NEWS := {"want": ["kindness", 0, "near"]}   its event types for the news (unbound_news.gd TYPES' form)
##   const DRAW := {}                             (optional) who it draws besides its cast: {"most", "loud" metres,
##                                                "come" ("bold" | "all"), "role"}: they play `plays(h, role, me)`
##   const LEAD := 10                             (optional) game minutes before its first phase the cast set off
##   static func offer(v, now, k) -> Dictionary   (rules) the record, or {}: decides and applies everything, once
##   static func plays(h, role, me) -> Array      (bodies) a cast member's steps (people/performer.gd), by role
##   static func headline(v, h, phase) -> String  (news) the line as a phase begins ("" none)
##
## A record: {kind, place, at: [x_dm, z_dm], cast: {role: id}, phases: [[name, from, to], ...] (game minutes), events,
## outcome, ...} - sim/goings_on.gd fills the rest (sim/happenings.gd's form).
##
## Targets in plays (people/going_on_runner.gd resolves them): a role ("a", "host"...: where they are), "place" (the
## record's spot), "door:<role>" (their home door), "spot:<i>:<n>:<metres>" (the i-th of n places round the spot),
## "home", "away", a point.
const S := preload("res://scripts/studio/village/sim/state.gd")
const R := preload("res://scripts/studio/village/sim/rng.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")


static func offer(_v: S.Village, _now: int, _k: int) -> Dictionary:
	return {}


static func plays(_h: Dictionary, _role: String, _me: Dictionary) -> Array:
	return []


static func headline(_v: S.Village, _h: Dictionary, _phase: String) -> String:
	return ""


# ---------- helpers for the rules side ----------

## A keyed chance in parts per million.
static func chance(k: int, ppm: int) -> bool:
	return R.chance(k, ppm)


## One of `options`, keyed.
static func pick(k: int, options: Array) -> Variant:
	return options[R.pick(k, options.size())] if not options.is_empty() else null


## Phases one after another from `start`: [[name, minutes], ...] -> [[name, from, to], ...].
static func phases_from(start: int, parts: Array) -> Array:
	var out: Array = []
	var t := start
	for p: Array in parts:
		out.append([str(p[0]), t, t + int(p[1])])
		t += int(p[1])
	return out


## The game minute `minute_of_day` today (or tomorrow, if it has passed).
static func today_at(now: int, minute_of_day: int) -> int:
	var t := now - now % 1440 + minute_of_day
	return t if t >= now else t + 1440


## A place's spot in decimetres ([x, z]); a home's for a household's home name.
static func spot_of(v: S.Village, place: int) -> Array:
	return [int(v.place_x[place]), int(v.place_z[place])]


## Where someone's day has them at this game minute (a place id).
static func place_of(v: S.Village, id: int, now: int) -> int:
	return Village.place_at(v.people[id], now % 1440)


## The place id of someone's home.
static func home_of(v: S.Village, id: int) -> int:
	var h := int(v.people[id].household)
	return int(v.households[h].home_place) if h >= 0 and h < v.households.size() else v.pl_square


## Those whose day has them at `place` now, free to be cast (sim/goings_on.gd free), grown unless `children`.
static func at_place(v: S.Village, place: int, now: int, children := false) -> Array:
	var GoingsOn = load("res://scripts/studio/village/sim/goings_on.gd")
	var out: Array = []
	for p in v.people:
		if place_of(v, p.id, now) == place and GoingsOn.free(v, p.id, now) and (children or Village.age_of(v, p) >= 16):
			out.append(p.id)
	return out


## Food a mouth in a household (its food over its living members).
static func food_each(v: S.Village, house: int) -> float:
	var hh: S.Household = v.households[house]
	var mouths := 0
	for id: int in hh.members:
		if v.people[id].alive and v.people[id].present:
			mouths += 1
	return float(hh.food) / float(maxi(mouths, 1))


## A household's grown member at home now and free (-1 none), the eldest first.
static func at_home(v: S.Village, house: int, now: int) -> int:
	var GoingsOn = load("res://scripts/studio/village/sim/goings_on.gd")
	var best := -1
	for id: int in v.households[house].members:
		var p := v.people[id]
		if Village.age_of(v, p) >= 16 and place_of(v, id, now) == int(v.households[house].home_place) and GoingsOn.free(v, id, now):
			if best < 0 or p.born < v.people[best].born:
				best = id
	return best


static func trait_of(v: S.Village, id: int, t: int) -> int:
	return int(v.people[id].traits[t])


# ---------- helpers for the bodies side ----------

## A keyed number in [0, 1) for this record and person.
static func roll(h: Dictionary, me: Dictionary, salt: int) -> float:
	return float(absi(hash([int(h.get("id", 0)), int(me.get("id", 0)), salt])) % 10007) / 10007.0


static func line(h: Dictionary, me: Dictionary, options: Array, salt := 13) -> String:
	if options.is_empty():
		return ""
	return str(options[int(roll(h, me, salt) * options.size()) % options.size()])
