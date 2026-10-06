extends "res://scripts/studio/village/going_on.gd"
## Want: a household short of food sends someone door to door. They knock at a neighbour's who has more; whoever is in
## comes out and gives, or does not, by their heart, their purse and what they think of the asker (retires the
## director's kindness as the only giving there is). Food moves; opinions move; a refusal is remembered.
const KIND := "want"
const TIER := "small"
const NEWS := {"want_given": ["kindness", 0, "near"], "want_refused": ["feud", 1, "near"]}
const SHORT := 2.5           # food a mouth under which a household goes asking
const ODDS := 25000          # parts per million a quarter hour, while one is short (about one a day)
const SPACING := 180         # game minutes between two in the village
const GIVE := 4              # food a gift
const LEAD := 4


static func offer(v: S.Village, now: int, k: int) -> Dictionary:
	var m := now % 1440
	if m < 540 or m > 1110:
		return {}
	var GoingsOn = load("res://scripts/studio/village/sim/goings_on.gd")
	if GoingsOn.last(v, KIND) >= 0 and now - GoingsOn.last(v, KIND) < SPACING or not chance(R.key(k, 1), ODDS):
		return {}
	var short := -1
	for hh: S.Household in v.households:
		if food_each(v, hh.id) < SHORT and (short < 0 or food_each(v, hh.id) < food_each(v, short)):
			var asker := _asker(v, hh.id, now)
			if asker >= 0:
				short = hh.id
	if short < 0:
		return {}
	var a := _asker(v, short, now)
	var b := -1
	var giver_house := -1
	for house: int in _neighbours(v, short):
		if food_each(v, house) < food_each(v, short) * 2.0 + 2.0:
			continue
		b = at_home(v, house, now)
		if b >= 0:
			giver_house = house
			break
	if b < 0:
		return {}
	var heart := trait_of(v, b, C.COMPASSION) * 0.6 - trait_of(v, b, C.GREED) * 0.4 + Village.opinion(v, b, a) * 0.5
	heart += (food_each(v, giver_house) - food_each(v, short)) * 2.0 + float(R.pick(R.key(k, 2), 40)) - 20.0
	var given := heart >= 12.0
	if given:
		var amount := mini(GIVE, int(v.households[giver_house].food) - 1)
		v.households[giver_house].food -= amount
		v.households[short].food += amount
		Village.set_opinion(v, a, b, Village.opinion(v, a, b) + 10)
		Village.set_opinion(v, b, a, Village.opinion(v, b, a) + 2)
	else:
		Village.set_opinion(v, a, b, Village.opinion(v, a, b) - 8)
		v.people[a].stress = clampi(v.people[a].stress + 20, 0, 400)
	var start := now + LEAD
	var outcome := "given" if given else "refused"
	var home := home_of(v, b)
	var h := {"kind": KIND, "place": home, "at": spot_of(v, home), "cast": {"a": a, "b": b}, "outcome": outcome, "lead": LEAD,
		"phases": phases_from(start, [["ask", 8], [outcome, 8]]), "needs": ["a", "b"]}
	h.events = [E.log_event(v, "want_" + outcome, b, a, {"place": v.place_names[home], "happening": -1},
		PackedInt32Array(), ("%s gave %s bread at the door" if given else "%s turned %s away from the door") % [E.name_of(v, b), E.name_of(v, a)])]
	return h


static func plays(h: Dictionary, role: String, me: Dictionary) -> Array:
	var given := str(h.outcome) == "given"
	if role == "a":
		var out: Array = [["go", "door:b", "walk", 1.3], ["face", "door:b"], ["clip", "Interact"], ["wait", 1.5],
			["until", "b", 2.6, 12.0], ["say", line(h, me, ASK)], ["wait", 3.0 + 1.5 * roll(h, me, 2)]]
		if given:
			out.append_array([["nod"], ["say", line(h, me, THANKS, 17)], ["clip", "Interact"], ["wait", 1.0], ["home", "walk"]])
		else:
			out.append_array([["clip", "Idle_No"], ["wait", 1.2], ["go", "away", "walk", 0.0]])
		return out
	if role == "b":
		var out: Array = [["until", "a", 3.0, 60.0], ["do", "out"], ["face", "a"], ["wait", 1.2]]
		out.append_array([["wait", 2.5], ["say", line(h, me, YES if given else NO)],
			["clip", "Interact" if given else "Idle_No"], ["wait", 2.0], ["home", "walk"]])
		return out
	return []


static func headline(v: S.Village, h: Dictionary, phase: String) -> String:
	var a := E.name_of(v, int(h.cast.a))
	var b := E.name_of(v, int(h.cast.b))
	match phase:
		"given": return "%s gave %s food at the door" % [b, a]
		"refused": return "%s turned %s away from the door" % [b, a]
	return ""


## Someone grown from a short household, free now (the eldest first).
static func _asker(v: S.Village, house: int, now: int) -> int:
	var GoingsOn = load("res://scripts/studio/village/sim/goings_on.gd")
	var best := -1
	for id: int in v.households[house].members:
		var p := v.people[id]
		if Village.age_of(v, p) >= 14 and GoingsOn.free(v, id, now) and (best < 0 or p.born < v.people[best].born):
			best = id
	return best


## Other households, nearest home first.
static func _neighbours(v: S.Village, house: int) -> Array:
	var from := Vector2(v.place_x[int(v.households[house].home_place)], v.place_z[int(v.households[house].home_place)])
	var out: Array = []
	for hh: S.Household in v.households:
		if hh.id != house and hh.home_place >= 0:
			out.append([from.distance_to(Vector2(v.place_x[hh.home_place], v.place_z[hh.home_place])), hh.id])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	return out.map(func(x: Array) -> int: return int(x[1]))


const ASK := ["Could you spare a little bread? Just till the harvest.", "I hate to ask... we've nothing for the children.",
	"Anything you can spare. We'll pay it back.", "Is there any flour to spare? Even a cup."]
const THANKS := ["Bless you. Bless you.", "I won't forget this.", "Thank you. Truly.", "You're a good neighbour."]
const YES := ["Here. Take this.", "Of course. Wait there.", "It's not much, but take it.", "Come here, take these."]
const NO := ["We've barely enough ourselves.", "Not today. Try the next door.", "I'm sorry. I can't.", "Ask someone else."]
