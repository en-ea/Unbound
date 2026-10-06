extends RefCounted
## What presentation may know about a resident: a read-only view over the village's state. Nothing here
## changes the village. Talk lines, animations, greetings and marks are chosen from these answers, so the
## presentation never reads the rules' internals (and the rules can change behind this contract).
##
##   describe(v, id)  -> who they are, how they are, what they are doing, what they think of the player
##   activity(v, id)  -> what they are doing now: {verb, place, moving, since, until}
##   toward_player(v, id) -> {met, feeling (-100..100), memories: [token]}
##
## Memory tokens (append-only list; presentation maps them to words): "met", "freed_by_you", "you_shielded",
## "you_testified", "you_offered_coins", "saw_you_plant", "angered". More arrive with Pass 2 stage 2
## ("hit_by_you", "saw_you_hit", "told_about_you", "helped_by_you").
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Affect := preload("res://scripts/studio/people/affect.gd")

const PLAYER := "player:local"


static func describe(v: S.Village, id: int) -> Dictionary:
	var p := v.people[id]
	var age := Village.age_of(v, p)
	return {
		"id": id, "name": p.name, "sex": p.sex, "age": age,
		"age_group": "child" if age < 14 else "elder" if age >= 60 else "adult",
		"role": p.role, "lineage": v.lineages[p.lineage].name if p.lineage >= 0 else "",
		"home": v.households[p.household].home if p.household >= 0 else "",
		"alive": p.alive, "present": p.present, "held": p.locked,
		"authority": id == v.authority, "priest": id == v.priest,
		"forebear": p.ancestor >= 0, "outsider": p.outsider,
		"marks": p.marks.keys(), "epithet": p.epithets[p.epithets.size() - 1] if p.epithets.size() > 0 else "",
		"mood": mood(v, id), "activity": activity(v, id), "toward_player": toward_player(v, id), "episodes": episodes(v,id),
		"protected": p.authored != "", "authored": p.authored,   # Enea's own characters (authored.gd)
		"look": {"outfit": int(Justice.person_entry(v, id).get("outfit", 0))},   # the outfit index residents.gd dresses
	}


## One word for how they are, most pressing first.
static func mood(v: S.Village, id: int) -> String:
	var p := v.people[id]
	if p.locked:
		return "afraid"
	var affect := Affect.project(p.mind,People.tick(v))
	if int(affect.pain)>300:return "hurting"
	if int(affect.fear)>400:return "afraid"
	if int(affect.anger)>400:return "angry"
	if p.stress > 200:
		return "grieving"
	if p.hunger > 400:
		return "hungry"
	if v.fear > 600:
		return "afraid"
	if p.guilt > 150:
		return "uneasy"
	var feeling: int = toward_player(v, id).feeling
	if feeling <= -40:
		return "hostile"
	if feeling <= -15:
		return "wary"
	return "calm"


## What they are doing at this minute, from their day plan (the same trip the resident body walks).
static func activity(v: S.Village, id: int) -> Dictionary:
	var p := v.people[id]
	var now := int(v.runtime.now) if not v.runtime.is_empty() else v.day * 1440
	if not p.alive or not p.present:
		return {"verb": "away", "place": "", "moving": false, "since": now, "until": now}
	if p.locked:
		return {"verb": "held", "place": v.place_names[p.locked_at] if p.locked_at >= 0 else "", "moving": false, "since": now, "until": now}
	var trip := Runtime.routine(v, id) if not v.runtime.is_empty() else {"from": "", "place": "", "start": now, "end": now}
	var place: String = trip.place
	var moving: bool = int(trip.end) > now and trip.from != trip.place
	var minute := now % 1440
	var verb := "walking" if moving else _verb_at(v, p, place, minute)
	return {"verb": verb, "place": place, "moving": moving, "since": int(trip.start), "until": int(trip.end)}


static func _verb_at(v: S.Village, p: S.Person, place: String, minute: int) -> String:
	if place == "far_woods" and int(v.runtime.get("residents", {}).get(str(p.id), {}).get("refuge_until", 0)) > int(v.runtime.get("now", 0)):
		return "hiding"
	if place in v.homes:
		if minute < 360 or minute >= 1320:
			return "sleeping"
		if minute >= 720 and minute < 780:
			return "eating"
		return "at_home" if place == v.households[p.household].home else "visiting"
	match place:
		"field": return "farming"
		"pasture": return "herding"
		"woods", "far_woods": return "woodcutting" if p.role == "woodcutter" else "hunting" if p.role == "hunter" else "gathering"
		"mill": return "milling"
		"forge": return "smithing"
		"shrine": return "praying"
		"well": return "fetching_water" if minute < 1080 else "chatting"
		"square": return "trading" if p.role == "merchant" else "chatting" if minute >= 1080 else "loitering"
		"road": return "travelling"
	return "idle"


## What this resident thinks of the player: runtime.acquaintance (world_actions.gd remember). Saves made before
## Pass 2 kept it elsewhere (the player account's enemies, the rescue memory); those are read too.
static func toward_player(v: S.Village, id: int) -> Dictionary:
	var memories: Array[String] = []
	var feeling := 0
	if v.runtime.is_empty():
		return {"met": false, "feeling": 0, "memories": memories}
	var acquaintance: Dictionary = v.runtime.get("acquaintance", {}).get(str(id), {})
	for m in acquaintance.get("memories", []):
		memories.append(str(m))
	feeling += int(acquaintance.get("feeling", 0))
	# The new ledger owns migrated feelings/memories; the talk view derives, never mirrors them.
	var m = v.people[id].mind
	var stance: Dictionary = People.stance_view(m,People.tick(v),[PLAYER]).get(PLAYER,{})
	feeling += int(stance.get("feeling",0))/10
	for key: String in m.known:
		var a: Dictionary = m.known[key]
		var inferred := str(a.get("claim",{}).get("identity",{}).get("key","unknown"))==PLAYER
		if str(a.identity.key)!=PLAYER and not inferred:continue
		var act := str(a.evidence.get("act",""))
		var token := "suspects_you" if inferred else "told_about_you" if str(a.via)=="told" else "gift_from_you" if act=="gift" else "hit_by_you" if str(a.via)=="felt" and act in ["strike","shove","burn"] else "saw_you_hit" if str(a.via)=="seen" and act in ["strike","shove","burn"] else "noticed_you"
		if not memories.has(token):
			memories.append(token)
	var account: Dictionary = v.runtime.get("players", {}).get(PLAYER, {})
	if account.get("enemies", []).has(id) and not memories.has("angered"):
		memories.append("angered"); feeling -= 40
	var memory: Dictionary = v.runtime.get("residents", {}).get(str(id), {})
	if memory.get("rescued_by", "") == PLAYER and not memories.has("freed_by_you"):
		memories.append("freed_by_you"); feeling += 60
	return {"met": acquaintance.has("met") or memories.size() > 0, "feeling": clampi(feeling, -100, 100), "memories": memories}


## S3 named recent detail; how-learned/qualified claim survives. Event reference is opaque.
## The recent view is bounded16; known/appraised retry and replacement keys are not.
static func episodes(v: S.Village, id: int) -> Array:
	var out := []
	var m: S.Mind=v.people[id].mind
	for episode: S.Episode in m.episodes:
		var a: Dictionary=People.episode_account(m,episode)
		out.append({"key":episode.key,"name":str(episode.meaning.get("name","noticed something")),"tick":episode.tick,
			"act":str(episode.meaning.get("act","")),"meaning":episode.meaning.duplicate(true),
			"place":episode.place,"severity":episode.severity,"event_ref":episode.event_ref,
			"actor":a.get("identity",{}).duplicate(true),"subject":a.get("subject",{}).duplicate(true),
			"how":str(a.get("via","unknown")),"claim":a.get("claim",{}).duplicate(true),
			"facets":a.get("facets",{}).duplicate(true),"reported_claim":a.get("reported_claim",{}).duplicate(true),
			"speaker":str(a.get("speaker","")),"origin_via":str(a.get("origin_via",a.get("via","unknown")))})
	return out


# ---------- the news (news/unbound_news.gd): the village's log and what it is about, read-only ----------

## The events logged from index `from` on, as plain records: {id, type, who, other, data, causes: Array, cue, minute}.
## An event knows only its day; one of today's is given the minute now (the news reads them as they come).
static func events_since(v: S.Village, from: int) -> Array:
	var out: Array = []
	var now := int(v.runtime.get("now", v.day * 1440))
	for i in range(maxi(0, from), v.events.size()):
		var e := v.events[i]
		out.append({"id": e.id, "type": e.type, "who": e.who, "other": e.other, "data": e.data, "causes": Array(e.causes),
			"cue": e.cue, "minute": e.minute if e.minute >= 0 else (now if e.day == now / 1440 else e.day * 1440)})
	return out


static func event_count(v: S.Village) -> int:
	return v.events.size()


static func name_of(v: S.Village, id: int) -> String:
	if id == -2:
		return "a stranger"
	return v.people[id].name if id >= 0 and id < v.people.size() else "someone"


static func home_of(v: S.Village, household: int) -> String:
	return v.households[household].home.capitalize() if household >= 0 and household < v.households.size() else "a"


static func lineage_name(v: S.Village, lineage: int) -> String:
	return v.lineages[lineage].name if lineage >= 0 and lineage < v.lineages.size() else "others"


static func place_name(v: S.Village, place: int) -> String:
	return v.place_names[place] if place >= 0 and place < v.place_names.size() else "village"


## Where a place is, in metres (Vector2.INF: not a place with a position).
static func place_point(v: S.Village, name: String) -> Vector2:
	var i: int = v.place_ids.get(name, -1)
	if i < 0 or not v.place_has_pos[i]:
		return Vector2.INF
	return Vector2(v.place_x[i], v.place_z[i]) / 10.0


static func act_noun(act: String) -> String:
	return str(C.ACTS.get(act, {}).get("noun", act))


static func act_severity(act: String) -> int:
	return int(C.ACTS.get(act, {}).get("severity", 1))


static func crime_victim(v: S.Village, crime: int) -> int:
	return v.crimes[crime].victim if crime >= 0 and crime < v.crimes.size() else -1


static func crime_of_case(v: S.Village, case: int) -> int:
	return v.cases[case].crime if case >= 0 and case < v.cases.size() else -1


## What people are saying about a crime: the culprit the village's beliefs weigh most (it can be the wrong one).
static func said_culprit(v: S.Village, crime: int) -> int:
	var weight := {}
	for p in v.people:
		if not p.alive:
			continue
		for b in p.beliefs:
			if b.crime == crime:
				weight[b.culprit] = int(weight.get(b.culprit, 0)) + b.strength
	var best := -1
	for c: int in weight:
		if best < 0 or int(weight[c]) > int(weight[best]) or (int(weight[c]) == int(weight[best]) and c < best):
			best = c
	return best


## The happening an event belongs to (sim/happenings.gd records list their events), or -1.
static func happening_of_event(v: S.Village, event: int) -> int:
	for h: Dictionary in v.runtime.get("happenings", []):
		for e in h.get("events", []):
			if int(e) == event:
				return int(h.id)
	return -1


static func happenings(v: S.Village) -> Array:
	return v.runtime.get("happenings", [])


## The village's mood in a word or two, from its pressures (sim/pressures.gd keeps their levels in the runtime), else
## from fear and hardship as they stand.
static func mood_word(v: S.Village) -> String:
	var levels: Dictionary = v.runtime.get("pressures", {}).get("levels", {})
	var worst := ""
	var worst_level := 0
	for name: String in ["fear", "hunger", "inequality", "grief", "strife"]:
		var level := int(levels.get(name, 0))
		if level > worst_level:
			worst_level = level
			worst = name
	if worst_level > 0:
		return {"fear": "afraid", "hunger": "hungry", "inequality": "resentful", "grief": "in mourning", "strife": "quarrelsome"}[worst] \
			if worst_level >= 2 else "uneasy"
	if v.fear > 600:
		return "afraid"
	if v.hardship > 500:
		return "hungry"
	return "calm"
