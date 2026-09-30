extends RefCounted
## Port of tools-src/studio/village-reference/events.mjs.
## The village's memory: every notable thing that happens is an event with its causes (earlier event ids)
## and a cue (what someone standing there would see or hear). The cause links are what the tests check
## ("every notable act has a reason") and what the tales follow; the cues are "show, don't read".

const R := preload("res://scripts/studio/village/sim/rng.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")

# Types that must carry a cause chain and a cue (the invariants check these).
const NOTABLE := {
	"crime": true, "accusation": true, "trial": true, "verdict": true, "public_act": true, "mob": true, "exile": true,
	"exoneration": true, "veneration": true, "omen": true, "storm": true, "violent_death": true, "confession": true,
	"crowd_turned": true, "feud": true, "return": true, "rite": true,
}

# A stable numeric code per type (for hashing; append only).
const TYPE_LIST := ["birth", "death", "marriage", "crime", "sighting", "rumour", "accusation", "trial", "confession",
	"ordeal", "verdict", "public_act", "crowd_turned", "mob", "exile", "return", "exoneration", "veneration",
	"festival", "omen", "famine", "feud", "storm", "epithet", "violent_death", "funeral", "rite", "wedding",
	"arrival", "discovery", "harvest", "rivalry", "quarrel", "kindness", "report"]


static func log_event(V: S.Village, type: String, who: int, other: int, data: Dictionary, causes: PackedInt32Array, cue: String) -> int:
	var e := S.Event.new()
	e.id = V.events.size()
	e.day = V.day
	e.type = type
	e.who = who
	e.other = other
	e.data = data
	e.causes = causes
	e.cue = cue
	V.events.append(e)
	var code := TYPE_LIST.find(type)
	var h := V.ev_hash
	h = R.key(h, e.day); h = R.key(h, e.id); h = R.key(h, code if code >= 0 else 99); h = R.key(h, who); h = R.key(h, other)
	for c in causes:
		h = R.key(h, c)
	V.ev_hash = h
	return e.id


# Walks the cause links back from an event (breadth first, oldest last); used by tests and tales.
static func cause_chain(V: S.Village, id: int, limit: int = 40) -> PackedInt32Array:
	var seen := {id: true}
	var out := PackedInt32Array()
	var queue: Array[int] = [id]
	while queue.size() > 0 and out.size() < limit:
		var cur: int = queue.pop_front()
		out.append(cur)
		for c in V.events[cur].causes:
			if not seen.has(c):
				seen[c] = true
				queue.append(c)
	return out


# A person's name with their epithets (the latest earned), and their lineage.
static func full_name(V: S.Village, id: int) -> String:
	if id < 0 or id >= V.people.size():
		return "someone"
	var p := V.people[id]
	var ep := " " + p.epithets[p.epithets.size() - 1] if p.epithets.size() > 0 else ""
	return p.name + ep


static func name_of(V: S.Village, id: int) -> String:
	if id == -2:
		return "a stranger"  # the player, as the village sees them
	return V.people[id].name if id >= 0 and id < V.people.size() else "someone"
