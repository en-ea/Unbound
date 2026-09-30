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
		"mood": mood(v, id), "activity": activity(v, id), "toward_player": toward_player(v, id),
		"protected": false,   # authored story characters (Pass 2, L5) will say true
	}


## One word for how they are, most pressing first.
static func mood(v: S.Village, id: int) -> String:
	var p := v.people[id]
	if p.locked:
		return "afraid"
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
	var account: Dictionary = v.runtime.get("players", {}).get(PLAYER, {})
	if account.get("enemies", []).has(id) and not memories.has("angered"):
		memories.append("angered"); feeling -= 40
	var memory: Dictionary = v.runtime.get("residents", {}).get(str(id), {})
	if memory.get("rescued_by", "") == PLAYER and not memories.has("freed_by_you"):
		memories.append("freed_by_you"); feeling += 60
	return {"met": acquaintance.has("met") or memories.size() > 0, "feeling": clampi(feeling, -100, 100), "memories": memories}
