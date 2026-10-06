extends RefCounted
## How a person moves, from who they are (Pass 3, L3). Pure and keyed: the same person always moves the same way, and
## nothing here is saved. It knows people, not villages: any place with people (a village, a road, a camp) describes
## them in the same small dictionary.
##
##   var m := Persona.motion({"key": id, "age": 34, "bold": 60, "temper": 40, "sociable": 70, "alert": 50, "scale": 1.0})
##   m.pace     m/s of their ordinary walk           m.horizon  seconds ahead they look (the shy give way early)
##   m.space    metres of room they like to keep     m.accel    m/s2: how briskly they change speed
##   m.radius   their body (a child is smaller)      m.turn     rad/s at most they turn
##   Persona.speed(m, style) -> m/s for a style      Persona.delay(m, k) -> seconds before setting off on trip k
##
## The styles keep clear of the gap between the rig's walk and jog (the walk plays well to about 1.75 m/s, the jog from
## about 2.9): stroll 0.8-1.2, walk 0.8-1.62 (the old 0.8-1.0), hurry 1.6-1.75, jog 3.0-3.4, run 4.6 and up.
## A stand-in for what comes later: mood and urgency (PA-4) will lean on these numbers through the same calls.

const HURRY_TOP := 1.75       # m/s: the fastest walk the rig plays without its feet sliding
const JOG_LOW := 3.0          # m/s: the slowest jog it plays the same way


## A person's way of moving. Fields read (all optional): key (int, keys the small differences), age (years), bold,
## temper, sociable, alert (0-100), scale (body size, 1 for a grown person).
static func motion(who: Dictionary) -> Dictionary:
	var key := int(who.get("key", 0))
	var age := float(who.get("age", 30))
	var bold := float(who.get("bold", 50)) / 100.0
	var temper := float(who.get("temper", 50)) / 100.0
	var alert := float(who.get("alert", 50)) / 100.0
	var scale := float(who.get("scale", 1.0))
	var n1 := _noise(key, 1)
	var n2 := _noise(key, 2)
	var pace: float
	var accel: float
	var turn: float
	if age < 14.0:
		pace = 1.25 + 0.3 * n1                    # children dart about
		accel = 2.6
		turn = 4.5
	elif age < 60.0:
		# people differ: walking speeds spread about 15% either way of the mean (pedestrian studies), some of it
		# temperament (the bold and the quick-tempered stride out), most of it just who they are
		pace = 1.28 + 0.2 * (bold + temper - 1.0) + 0.5 * (n1 - 0.5) - clampf((age - 40.0) / 100.0, 0.0, 0.2)
		accel = 1.9 + 0.5 * bold
		turn = 3.6 + 0.6 * alert
	else:
		pace = 0.82 + 0.16 * n1 + 0.05 * bold     # the old amble
		accel = 1.3
		turn = 2.6
	return {
		"key": key,
		"pace": clampf(pace, 0.8, 1.62),
		"accel": accel,
		"turn": turn,
		"horizon": 1.4 + 2.0 * (1.0 - bold) + 0.3 * n2,
		"space": (0.15 if age < 14.0 else 0.25) + 0.3 * (1.0 - bold),
		"radius": 0.25 * scale,
		"alert": alert,
	}


## Metres a second for a style: stroll, walk, hurry, jog, run.
static func speed(m: Dictionary, style: String) -> float:
	var pace: float = m.pace
	match style:
		"stroll":
			return maxf(0.8, pace * 0.75)
		"hurry":
			return clampf(pace * 1.25, 1.6, HURRY_TOP)
		"jog":
			return JOG_LOW + 0.4 * _noise(int(m.key), 3)
		"run":
			return 4.6 + 0.6 * _noise(int(m.key), 4)
	return pace


## The style a walk needs to cover `metres` in `seconds` (INF: no hurry), never in the walk-to-jog gap: a little late
## at a hurry is better than a jog for a few metres.
static func style_for(m: Dictionary, metres: float, seconds: float) -> String:
	if seconds == INF or seconds <= 0.0:
		return "walk" if seconds == INF else "jog"
	var need := metres / seconds
	if need <= m.pace * 1.05:
		return "walk"
	if need <= HURRY_TOP * 1.3:
		return "hurry"
	return "jog"


## Seconds before setting off on trip `k`: each person at their own moment, the alert sooner (0.4 to about 4 s).
static func delay(m: Dictionary, k: int) -> float:
	return 0.4 + 3.6 * _noise(int(m.key) * 31 + k, 5) * (1.1 - 0.4 * float(m.get("alert", 0.5)))


## A keyed number in [0, 1).
static func _noise(key: int, salt: int) -> float:
	var h := hash(key * 7919 + salt * 104729)
	return float(posmod(h, 100000)) / 100000.0
