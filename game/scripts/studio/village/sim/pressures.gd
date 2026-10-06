extends RefCounted
## The village's pressures (plan VILLAGE-LIFE-AND-NEWS section 5, #3): what weighs on the whole village, read from
## the rules' own numbers - hunger, inequality, fear, grief and strife - each a reading 0..1000 and a level (calm,
## uneasy, high) that moves with hysteresis, so it does not flicker at a line. A level crossed is an event the news
## reads ("pressure"); hunger, inequality or fear going high calls a town meeting (sim/town_meeting.gd). Live path only
## (Runtime.advance, at the day's phases), keyed and saved in v.runtime.pressures: the chronicle never runs it.
##
##   Pressures.read(v) -> {hunger, inequality, fear, grief, strife}   the readings now
##   Pressures.update(v) -> Array        the levels moved (each [name, was, now]); crossings logged; a meeting called
##   Pressures.level(v, name) -> int     0 calm, 1 uneasy, 2 high
##
##   hunger      households short of food (under SHORT a mouth) and people going hungry, and the rules' hardship
##   inequality  the spread of food a mouth between the fullest and the emptiest households (past SPREAD_FROM), more
##               when the emptiest is short
##   fear        the rules' own fear (crime, omens, storms, famine)
##   grief       deaths in the last GRIEF_DAYS days, the violent ones more, fading day by day
##   strife      quarrels, blows and feuds in the last STRIFE_DAYS days, and pairs keeping clear of each other
const S := preload("res://scripts/studio/village/sim/state.gd")
const R := preload("res://scripts/studio/village/sim/rng.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const TownMeeting := preload("res://scripts/studio/village/sim/town_meeting.gd")

const NAMES := ["hunger", "inequality", "fear", "grief", "strife"]
const UP := [400, 650]             # a reading at or past these goes uneasy, then high ...
const DOWN := [300, 520]           # ... and back below these it falls a level (the gap is the hysteresis)
const CALLS_MEETING := ["hunger", "inequality", "fear"]
const SHORT := 5                   # food a mouth under which a household is short (days of bread, about)
const SPREAD_FROM := 10            # food a mouth between the fullest and the emptiest before it is felt (a full
                                   # house holds 25 a mouth: rules' village.gd food)
const GRIEF_DAYS := 3
const STRIFE_DAYS := 2
const STRIFE := {"quarrel": 110, "rivalry": 70, "feud": 260, "parted": 40, "mob": 300, "crowd_turned": 200}
const STRIFE_ASSAULT := 200        # a crime of blows (assault, brawl)
const STRIFE_NOTHING := 220        # a town meeting that broke up in anger
## What a crossing is called: [rising to uneasy, rising to high, falling back], and what someone sees of it
const WORDS := {
	"hunger": ["Bread is short in the village", "Hunger: the stores are empty", "The hunger eases", "thin soup and empty sacks"],
	"inequality": ["Grumbling: some houses full, some empty", "Bad feeling against the full houses", "Less talk of full houses",
		"full barns beside empty bowls"],
	"fear": ["The village is uneasy", "Fear in the village: doors barred at night", "The fear passes", "doors barred before dark"],
	"grief": ["The village mourns", "Grief hangs over the village", "The mourning ends", "black cloth at the doors"],
	"strife": ["Tempers are short in the village", "Strife: neighbours at each other's throats", "Tempers cool",
		"raised voices behind shutters"],
}


static func runtime_ready(v: S.Village) -> void:
	if not v.runtime.has("pressures"):
		v.runtime.pressures = {"levels": {}, "readings": {}, "episodes": {}, "last_meeting": -1000000}


static func level(v: S.Village, name: String) -> int:
	return int(v.runtime.get("pressures", {}).get("levels", {}).get(name, 0))


static func read(v: S.Village) -> Dictionary:
	return {"hunger": _hunger(v), "inequality": _inequality(v), "fear": clampi(v.fear, 0, 1000), "grief": _grief(v),
		"strife": _strife(v)}


## At the day's phases (Runtime.advance): the readings, the levels with their hysteresis, a crossing logged, and a high
## hunger, inequality or fear calling a town meeting. The first time (an older save, a new village) the levels are
## only set: what is already so is not news.
static func update(v: S.Village) -> Array:
	runtime_ready(v)
	var pr: Dictionary = v.runtime.pressures
	var readings := read(v)
	var first: bool = (pr.levels as Dictionary).is_empty()
	var moved: Array = []
	for name: String in NAMES:
		var r := int(readings[name])
		var was := int(pr.levels.get(name, 0))
		var now := _level_for(r, was)
		if first:
			now = _level_for(r, 0)
		pr.readings[name] = r
		if now == was or first:
			pr.levels[name] = now
			continue
		pr.levels[name] = now
		moved.append([name, was, now])
		_crossed(v, name, was, now, r)
	return moved


static func _level_for(reading: int, was: int) -> int:
	var lvl := was
	while lvl < 2 and reading >= int(UP[lvl]):
		lvl += 1
	while lvl > 0 and reading < int(DOWN[lvl - 1]):
		lvl -= 1
	return lvl


static func _crossed(v: S.Village, name: String, was: int, now: int, reading: int) -> void:
	var pr: Dictionary = v.runtime.pressures
	if was == 0:
		pr.episodes[name] = int(pr.episodes.get(name, 0)) + 1      # a new spell of it: a new story
	var words: Array = WORDS[name]
	var headline: String = words[2] if now < was else words[now - 1]
	var story := "pressure:%s:%d" % [name, int(pr.episodes.get(name, 1))]
	var ev := E.log_event(v, "pressure", -1, -1, {"pressure": name, "level": now, "was": was, "reading": reading,
		"story": story, "headline": headline}, PackedInt32Array(), str(words[3]))
	if now >= 2 and was < 2 and name in CALLS_MEETING:
		TownMeeting.call_for(v, name, ev)


# ---------- the readings ----------

static func _hunger(v: S.Village) -> int:
	var houses := 0
	var short := 0
	for h in v.households:
		var mouths := _mouths(v, h)
		if mouths == 0:
			continue
		houses += 1
		if R.idiv(h.food, mouths) < SHORT:
			short += 1
	var people := 0
	var hungry := 0
	for p in v.people:
		if not p.alive or not p.present or p.authored != "":
			continue
		people += 1
		if p.hunger >= 300:
			hungry += 1
	if houses == 0 or people == 0:
		return 0
	return clampi(R.idiv(short * 550, houses) + R.idiv(hungry * 650, people) + R.idiv(v.hardship, 4), 0, 1000)


static func _inequality(v: S.Village) -> int:
	var most := -1000000
	var least := 1000000
	for h in v.households:
		var mouths := _mouths(v, h)
		if mouths == 0:
			continue
		var each := R.idiv(h.food, mouths)
		most = maxi(most, each)
		least = mini(least, each)
	if most < least:
		return 0
	return clampi((most - least - SPREAD_FROM) * 25 + clampi(SHORT - least, 0, 25) * 14, 0, 1000)


static func _grief(v: S.Village) -> int:
	var total := 0
	for i in range(v.events.size() - 1, -1, -1):
		var e := v.events[i]
		var ago := v.day - e.day
		if ago >= GRIEF_DAYS:
			break
		if e.type != "death" and e.type != "violent_death":
			continue
		if e.who < 0 or e.who >= v.people.size() or v.people[e.who].authored != "":
			continue
		total += R.idiv((300 if e.type == "death" else 450) * (GRIEF_DAYS - ago), GRIEF_DAYS)
	return clampi(total, 0, 1000)


static func _strife(v: S.Village) -> int:
	var total := 0
	for i in range(v.events.size() - 1, -1, -1):
		var e := v.events[i]
		var ago := v.day - e.day
		if ago >= STRIFE_DAYS:
			break
		var w := int(STRIFE.get(e.type, 0))
		if e.type == "crime" and str(e.data.get("act", "")) in ["assault", "brawl"]:
			w = STRIFE_ASSAULT
		elif e.type == "meeting" and str(e.data.get("outcome", "")) == "nothing":
			w = STRIFE_NOTHING
		total += R.idiv(w * (STRIFE_DAYS - ago), STRIFE_DAYS)
	total += (v.runtime.get("stances", {}) as Dictionary).size() * 10   # pairs keeping clear today (two a pair)
	return clampi(total, 0, 1000)


## The village's own mouths in a house (Enea's characters are fed by their story, not the harvest: not counted).
static func _mouths(v: S.Village, h: S.Household) -> int:
	var n := 0
	for id in h.members:
		var p := v.people[id]
		if p.alive and p.present and p.authored == "":
			n += 1
	return n
