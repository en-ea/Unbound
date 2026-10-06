extends RefCounted
## Unbound's side of the news (plan VILLAGE-LIFE-AND-NEWS section 5, #9): what each of the village's events is as a
## story item - its kind, how grave, which story it belongs to, its headline - and how the player could know of it.
## The only part of the news that knows Unbound; it reads the rules through sim/view.gd (presentation never reads the
## rules' internals). news/stories.gd threads and paces whatever this gives it.
##
##   UnboundNews.items(v, from) -> [item, ...]          the events logged since index `from`, as items (how: "")
##   UnboundNews.phase_items(v, h, now) -> [item, ...]  a happening's phases begun by `now` (sim/happenings.gd records)
##   UnboundNews.how(item, eye, minute) -> String       seen / heard / announced / "" from where the player stands
##   UnboundNews.word_after(item) -> int                game minutes until word of it reaches the player (-1: never)
##   UnboundNews.mood(v) -> String                      the village's mood in a word or two (the board's header)
const View := preload("res://scripts/studio/village/sim/view.gd")

const SIGHT := 35.0            # metres: seen happen
const ITEM_BASE := 1 << 40     # ids of items made from a happening's phases (never an event's id)
## What each event is to the news: [kind, severity 0..4, how it travels]. "announced": the bell or the crier (public);
## "word": talk carries it (grave or curious); "near": only seen or heard. Kinds not here are not news.
const TYPES := {
	"crime": ["crime", 2, "near"], "discovery": ["crime", 2, "word"], "rumour": ["crime", 1, "word"],
	"accusation": ["crime", 3, "word"], "trial": ["crime", 3, "announced"], "confession": ["crime", 3, "word"],
	"ordeal": ["crime", 3, "announced"], "verdict": ["crime", 3, "announced"], "public_act": ["crime", 4, "announced"],
	"crowd_turned": ["crime", 4, "word"], "mob": ["crime", 4, "word"], "exile": ["crime", 3, "word"],
	"exoneration": ["crime", 3, "word"], "veneration": ["crime", 2, "word"], "return": ["return", 2, "word"],
	"violent_death": ["death", 4, "word"], "death": ["death", 2, "word"], "funeral": ["death", 2, "announced"],
	"birth": ["birth", 1, "word"], "wedding": ["feast", 2, "announced"], "festival": ["feast", 2, "announced"],
	"omen": ["omen", 2, "word"], "famine": ["hunger", 3, "word"], "feud": ["feud", 3, "word"], "arrival": ["arrival", 1, "word"],
	"rivalry": ["feud", 1, "near"], "quarrel": ["argument", 1, "near"], "parted": ["argument", 1, "near"],
	"kindness": ["kindness", 0, "near"], "epithet": ["name", 1, "word"], "storm": ["storm", 3, "word"], "rite": ["rite", 3, "announced"],
	"meeting": ["meeting", 3, "announced"], "pressure": ["mood", 2, "word"],
}
## Minutes for word to reach the player, by severity (talk is slow for small things, quick for grave ones)
const WORD_MINUTES := [-1, 360, 180, 90, 40]
const HEARD := {"crime": 30.0, "violent_death": 60.0, "public_act": 80.0, "mob": 80.0, "quarrel": 25.0}


static func items(v, from: int) -> Array:
	var out: Array = []
	for e: Dictionary in View.events_since(v, from):
		var t: Array = TYPES.get(str(e.type), [])
		if t.is_empty():
			continue
		var item := {"id": int(e.id), "causes": e.causes, "kind": str(t[0]), "severity": int(t[1]), "travel": str(t[2]),
			"phase": str(e.type), "minute": int(e.minute), "people": [], "type": str(e.type), "how": "", "until": -1,
			"key": _key(v, e), "at": View.place_point(v, _place_of(v, e))}
		for who in [int(e.who), int(e.other)]:
			if who >= 0:
				item.people.append(who)
		if str(e.type) == "crime":
			item.severity = clampi(1 + int(View.act_severity(str(e.data.get("act", "")))) / 2, 1, 4)
			item.kind = "death" if e.data.get("act", "") == "murder" else "crime"
		elif str(e.type) == "pressure":           # a pressure rising is graver the higher it goes; falling, small news
			var lvl := int(e.data.get("level", 0))
			item.severity = 1 if lvl < int(e.data.get("was", 0)) else lvl + 1
			item.kind = "hunger" if str(e.data.get("pressure", "")) == "hunger" else "mood"
		if str(e.type) == "meeting":
			item.causes = []                      # a town meeting is its own story, not a line in the pressure's that called it
		var h := _happening(v, int(e.data.get("happening", -1)))
		if not h.is_empty():
			item.until = int(h.ends)              # going on (or coming: a meeting called): the board says where
		item.headline = headline(v, e, item)
		if item.headline.is_empty():
			continue
		item.line = str(e.cue)               # what someone there saw or heard: the detail when the story is opened
		out.append(item)
	return out


## A happening's phases begun by `now` that are news in their own right: an argument heating up, coming to blows,
## parted, cooling. (Its start and its blows are events already: the quarrel, the crime.)
static func phase_items(v, h: Dictionary, now: int) -> Array:
	var out: Array = []
	for i in (h.phases as Array).size():
		var ph: Array = h.phases[i]
		if int(ph[1]) > now or str(ph[0]) in ["words", "blows", "parted"]:
			continue
		var a := View.name_of(v, int(h.a))
		var b := View.name_of(v, int(h.b))
		var place := View.place_name(v, int(h.place))
		var line := ""
		var travel := "near"
		var severity := 1
		match str(h.kind) + ":" + str(ph[0]):
			"argument:heated": line = "%s and %s shouting at the %s" % [a, b, place]
			"argument:cooled": line = "%s and %s went their ways, still cross" % [a, b]
			"meeting:gather":
				line = "The bell: the village gathers at the %s" % place
				travel = "announced"
				severity = 2
		if line.is_empty():
			continue
		out.append({"id": ITEM_BASE + int(h.id) * 16 + i, "causes": h.events, "kind": str(h.kind), "severity": severity, "travel": travel,
			"phase": str(ph[0]), "minute": int(ph[1]), "people": [int(h.a), int(h.b)], "type": "happening", "how": "",
			"until": int(h.ends), "key": "happening:%d" % int(h.id), "at": _happening_at(v, h), "headline": line})
	return out


## How the player knows of it, from where they stand as it happens: seen within sight, heard within its loudness,
## announced (the bell) if it is public; else "" (word may still reach them later).
static func how(item: Dictionary, eye: Vector2, present: bool) -> String:
	if not present:
		return ""
	var at: Vector2 = item.get("at", Vector2.INF)
	if at != Vector2.INF and at.distance_to(eye) <= SIGHT:
		return "seen"
	if at != Vector2.INF and at.distance_to(eye) <= float(HEARD.get(str(item.type), 0.0)):
		return "heard"
	if str(item.travel) == "announced":
		return "announced"
	return ""


static func word_after(item: Dictionary) -> int:
	if str(item.travel) == "near":
		return -1
	return int(WORD_MINUTES[clampi(int(item.severity), 0, 4)])


## The village's mood: the strongest of its pressures (sim/pressures.gd, once it is there), in a word.
static func mood(v) -> String:
	return View.mood_word(v)


# ---------- headlines: short, plain, in the village's voice ----------

static func headline(v, e: Dictionary, item: Dictionary) -> String:
	var who := View.name_of(v, int(e.who))
	var other := View.name_of(v, int(e.other))
	var d: Dictionary = e.data
	match str(e.type):
		"crime":
			var act := str(d.get("act", ""))
			match act:
				"murder": return "Murder at the %s" % str(d.get("place", "village"))
				"assault": return "%s struck %s at the %s" % [who, other, str(d.get("place", "village"))]
				"theft": return "Theft from the %s house" % View.home_of(v, int(d.get("household", -1)))
			return "%s at the %s" % [View.act_noun(act).capitalize(), str(d.get("place", "village"))]
		"discovery":
			var act := str(d.get("act", ""))
			if act == "murder":
				return "%s found dead" % View.name_of(v, View.crime_victim(v, int(d.get("crime", -1))))
			return "%s found: %s" % [View.act_noun(act).capitalize(), str(e.cue)]
		"rumour":
			var said := View.said_culprit(v, int(d.get("crime", -1)))
			return "They say %s did it" % View.name_of(v, said) if said >= 0 else ""
		"accusation": return "%s accused of %s" % [other, View.act_noun(str(d.get("act", "")))]
		"trial": return "%s's hearing at the square" % other
		"confession": return "%s confessed" % who
		"ordeal": return "%s put to the ordeal" % who
		"verdict":
			var verdict := str(d.get("verdict", ""))
			return "%s walks free" % other if verdict in ["acquitted", "free", ""] else "%s found guilty: %s" % [other, verdict]
		"public_act":
			var outcome := str(d.get("outcome", ""))
			if outcome == "rescued":
				return "%s saved from the %s" % [who, str(d.get("kind", "crowd"))]
			return "%s at the %s, before the village" % [who, str(d.get("kind", "pillory"))]
		"crowd_turned": return "The crowd turned on %s" % other
		"mob": return "A mob in the village"
		"exile": return "%s fled into the woods" % who if d.get("fled", false) else "%s exiled" % who
		"exoneration": return "%s's name cleared" % who
		"veneration": return "Flowers at %s's grave" % who
		"return": return "%s came home" % who
		"violent_death": return "%s killed" % who
		"death": return "%s has died" % who
		"funeral": return "%s's funeral at the shrine" % who
		"birth": return "A child born to %s" % other
		"wedding": return "%s and %s wed" % [who, other]
		"festival": return "Festival: %s" % str(d.get("name", "a feast day"))
		"omen": return "An ill omen in the village"
		"famine": return "Famine: the harvest is failing"
		"feud":
			var lineages: Array = d.get("lineages", [])
			return "Feud between the %s and the %s" % [View.lineage_name(v, int(lineages[0])), View.lineage_name(v, int(lineages[1]))] \
				if lineages.size() == 2 else "A feud between two families"
		"arrival": return "Strangers came to the village"
		"rivalry": return "Bad blood between %s and %s" % [who, other]
		"quarrel": return "An argument at the %s: %s and %s" % [str(d.get("place", "village")), who, other]
		"parted":
			var place := str(d.get("place", "village"))
			if int(e.who) == -2:
				return "You parted %s and %s" % [other, View.name_of(v, int(d.get("other", -1)))]
			return "%s parted %s and %s" % [who, other, View.name_of(v, int(d.get("other", -1)))] if not place.is_empty() else ""
		"kindness": return "%s brought bread to the %s house" % [who, View.home_of(v, int(d.get("household", -1)))]
		"epithet": return "%s is called %s now" % [who, str(d.get("epithet", ""))]
		"storm": return "A storm took the %s house" % View.home_of(v, int(d.get("household", -1))) if d.get("phase", "") == "strikes" else "The storm passed"
		"rite": return "A rite at the shrine: %s" % str(e.cue)
		"meeting": return str(d.get("headline", "A town meeting"))
		"pressure": return str(d.get("headline", ""))
	return ""


## The story an event belongs to whatever its causes: a crime and everything about it; a death; a happening.
static func _key(v, e: Dictionary) -> String:
	var d: Dictionary = e.data
	if d.has("happening"):
		return "happening:%d" % int(d.happening)
	var h := View.happening_of_event(v, int(e.id))
	if h >= 0:
		return "happening:%d" % h
	if d.has("crime"):
		return "crime:%d" % int(d.crime)
	if d.has("case"):
		var c := View.crime_of_case(v, int(d.case))
		if c >= 0:
			return "crime:%d" % c
	match str(e.type):
		"death", "violent_death", "funeral": return "death:%d" % int(e.who)
		"famine": return "famine:%d" % int(d.get("year", 0))
		"meeting", "pressure": return str(d.get("story", ""))
	return ""


static func _happening(v, id: int) -> Dictionary:
	if id < 0:
		return {}
	for h: Dictionary in View.happenings(v):
		if int(h.id) == id:
			return h
	return {}


static func _place_of(v, e: Dictionary) -> String:
	var d: Dictionary = e.data
	if d.has("place"):
		return str(d.place)
	match str(e.type):
		"trial", "verdict", "public_act", "crowd_turned", "mob", "ordeal", "meeting": return "square"
		"funeral", "rite", "veneration": return "shrine"
	return ""


static func _happening_at(v, h: Dictionary) -> Vector2:
	var at: Array = h.get("at", [])
	if at.size() == 2:
		return Vector2(float(at[0]), float(at[1])) / 10.0
	return View.place_point(v, View.place_name(v, int(h.place)))
