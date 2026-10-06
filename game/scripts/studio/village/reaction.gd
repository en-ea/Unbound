extends RefCounted
## A reaction: how one person answers a cue (plan LIVELY-VILLAGE 3.1). One file a reaction in village/reactions/,
## extending this; the registry (reaction_registry.gd) finds it, the director (people/reacting.gd) offers it the cues it
## answers, asks each person there how strongly they would do it, picks one per person (keyed, never always the best),
## starts each at their own moment, and the performer (people/performer.gd) plays its steps. Adding a reaction is one
## new file: no list, no edit anywhere else.
##
##   const ANSWERS := ["end:"]           the cues it takes up, by prefix ("end:" every end of a scene, "end:public:" a
##                                       public act's, "parting", "enemy", "kill", "alarm", "rescue")
##   const PRIORITY := 2                 the owners priority it holds a body at (people/owners.gd)
##   static func weight(cue, me) -> float     how strongly this person takes it up (0: never)
##   static func steps(cue, me) -> Array      what they do (people/performer.gd steps)
##   static func delay(cue, me) -> float      seconds before they start: their own moment (default below)
##   static func lasts(cue, me) -> float      a time limit; past it they go back to their day
##   static func decide(v, cue, k) -> Dictionary   (rules; optional) who does it for certain and what that changes:
##                                       {"cast": [ids], "effects": [[kind, a, b, amount]]} (sim/aftermath.gd applies it
##                                       once, keyed, on the live path)
##
## cue {kind, place (Vector2), subject (id, -1 none), subject_name, other (an accuser, the elder, -1), outcome, alive,
##      who (ids there), key (int), event (rules id, -1), heard (seconds)}
## me  {id, name, age_group, role, sex, traits {bold, piety, greed, compassion, honesty, temper, alert, sociable},
##      values {law, mercy, faith}, kin (of the subject), feeling (toward the subject, -100..100), feeling_other,
##      mood, busy (their day has work waiting), late (0..1: how near their day's end), distance (to the place),
##      parent_there (a parent's id, -1), children_there [ids], friends_there [ids], kin_there [ids: their own kin there],
##      household, cast (the module the rules gave them, "")}
## Everything here is presentation: weight, steps, delay and lasts never touch the village; only decide does.
## (ANSWERS and PRIORITY are each module's own constants: GDScript lets no subclass redeclare a base's, so their
## defaults - none, and 2 - are the registry's.)


static func weight(_cue: Dictionary, _me: Dictionary) -> float:
	return 0.0


static func steps(_cue: Dictionary, _me: Dictionary) -> Array:
	return []


## Their own moment to stir (a look, a word, a gesture): soon - nobody stands frozen - but each their own; the busy and
## the far edge first, the sociable later. When they leave is the steps' business (stand_on).
static func delay(cue: Dictionary, me: Dictionary) -> float:
	var r := roll(cue, me, 1)
	var base := 0.5 + 5.5 * pow(r, 1.3)                       # median under 3 s, nine in ten within about 5
	if me.get("busy", false):
		base *= 0.7
	base *= 0.8 + 0.4 * float(me.traits.sociable) / 100.0
	base *= 1.2 - minf(float(me.get("distance", 0.0)) / 25.0, 0.4)
	return base


## Seconds they stand on before they go: their household's own (a household talks it over and leaves together,
## each within 2 s of the rest), log-normal about `median` (the spread of real departures: plan 2.1, 3.2), less what
## the steps before took (`spent`).
static func stand_on(cue: Dictionary, me: Dictionary, median: float, sigma: float, spent := 0.0) -> float:
	var house := int(me.get("household", -1))
	var z := normal(cue, {"id": 900000 + house} if house >= 0 else me, 31)
	return maxf(0.3, median * exp(sigma * z) + 2.0 * roll(cue, me, 32) - spent)


## A keyed standard normal for this person (or household) and cue.
static func normal(cue: Dictionary, me: Dictionary, salt: int) -> float:
	var u1 := maxf(roll(cue, me, salt), 0.0001)
	return sqrt(-2.0 * log(u1)) * cos(TAU * roll(cue, me, salt + 101))


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 90.0


## A keyed number in [0, 1) for this person and cue (salt: another roll for the same pair).
static func roll(cue: Dictionary, me: Dictionary, salt: int) -> float:
	var h := hash([int(cue.get("key", 0)), int(me.id), salt])
	return float(absi(h) % 10007) / 10007.0


## One of `options`, keyed for this person and cue.
static func pick(cue: Dictionary, me: Dictionary, options: Array, salt := 7) -> Variant:
	if options.is_empty():
		return ""
	return options[int(roll(cue, me, salt) * options.size()) % options.size()]


## A trait 0..1 above (or below) the middle: 0 in the silent band 40-60, up to 1 at the extreme.
static func high(me: Dictionary, name: String) -> float:
	return clampf((float(me.traits[name]) - 55.0) / 40.0, 0.0, 1.0)


static func low(me: Dictionary, name: String) -> float:
	return clampf((45.0 - float(me.traits[name])) / 40.0, 0.0, 1.0)


## A line for this person and cue: one of `options`, keyed, with %s the subject's first name.
static func line(cue: Dictionary, me: Dictionary, options: Array, salt := 13) -> String:
	var s := str(pick(cue, me, options, salt))
	return s % them(cue) if s.contains("%s") else s


## Whether the cue's kind says this (a word between its colons: "died", "pillory", "rescued").
static func has(cue: Dictionary, word: String) -> bool:
	return (":%s:" % str(cue.get("kind", ""))).contains(":%s:" % word)


## The first name of the subject (or "them").
static func them(cue: Dictionary) -> String:
	var n := str(cue.get("subject_name", ""))
	return n.split(" ")[0] if n != "" else "them"


## The end of a scene and how it went: "released", "exiled", "died", "rescued", "acquitted", "guilty" ...
static func outcome(cue: Dictionary) -> String:
	return str(cue.get("outcome", ""))
