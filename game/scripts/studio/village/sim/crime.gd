extends RefCounted
## Port of tools-src/studio/village-reference/crime.mjs.
## Crime and knowledge. A crime needs a motive (hunger, greed, a grudge, fear), an opportunity (the target
## unwatched, read from the day plans) and inhibitions too weak to stop it (honesty, the law in one's
## values, how the age rates the act). It leaves traces and sightings; knowledge then travels only where
## plans put people together, weighted by trust and bent by dislike (Talk of the Town), and a case opens
## only when an accuser holds two independent sources (a complex contagion, Centola and Macy).

const R := preload("res://scripts/studio/village/sim/rng.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")
const Director := preload("res://scripts/studio/village/sim/director.gd")
const WorldActions := preload("res://scripts/studio/village/sim/world_actions.gd")
const Ported := preload("res://scripts/studio/village/sim/ported.gd")   # held(): his named characters are never a culprit

const TRACE_ORIGIN := 1000000  # origins at or above this are traces (feathers, bones), not people
const MAX_BELIEFS := 8
const PREJUDICE_ORIGIN := 2000000  # + household: a family's shared suspicion counts once
const NORM_WEIGHT := [0, 0, 5, 15, 25, 110]


static func inhibition(V: S.Village, p: S.Person, act: String) -> int:
	var rating: int = C.ACTS[act]["norms"][p.era]
	return p.traits[C.HONESTY] + R.idiv(p.values[C.V_LAW], 2) + int(NORM_WEIGHT[rating]) + (60 if V.authority == p.id else 0)


static func crimes_today(V: S.Village) -> void:
	var dk := R.key(R.key(V.base, Village.P_CRIME), V.day)
	for p in V.people:
		if not p.alive or not p.present or p.locked or Village.age_of(V, p) < 14 or Ported.held(V, p):
			continue
		var k := R.key(dk, p.id)
		try_theft(V, p, k)
		try_brawl(V, p, R.key(k, 7))
		try_murder(V, p, R.key(k, 11))
		try_famine_rite(V, p, R.key(k, 13))
		try_poaching(V, p, R.key(k, 17))
	witch_fear(V, dk)
	hoarding_anger(V, dk)


# ---------- poaching: game from the woods that belong to the village (the elder's to grant) ----------
static func try_poaching(V: S.Village, p: S.Person, k: int) -> void:
	if not (p.role == "woodcutter" or p.role == "hunter" or p.role == "herder" or p.role == "farmer"):
		return
	var motive := R.idiv(p.hunger, 6) + p.traits[C.BOLD] + R.idiv(p.traits[C.GREED], 2)
	var inhib := inhibition(V, p, "poaching") + R.idiv(p.values[C.V_TRADITION], 2)
	if motive <= inhib or not R.chance(k, (motive - inhib) * 700):
		return
	if V.planning:
		V.intents.append({"kind": "poaching", "actor": p.id, "minute": 300, "k": k, "place": V.pl_woods})
		return
	commit_poaching(V, p, k)


static func commit_poaching(V: S.Village, p: S.Person, k: int) -> void:
	V.households[p.household].food += 6
	var crime := add_crime(V, "poaching", p.id, -1, -1, 300, V.pl_woods, "a deer", PackedInt32Array(), "a snare in the elder's woods, blood on the moss", {"motive": "hunger" if p.hunger >= 300 else "boldness"})
	sightings(V, crime, k)
	crime.discovered = true
	crime.discovery_event = crime.event


# ---------- hoarding: in hard times the hungry turn on whoever still eats well ----------
static func hoarding_anger(V: S.Village, dk: int) -> void:
	if V.hardship < 350:
		return
	var rich := -1
	for h in V.households:
		if _some_living(V, h) and (rich < 0 or h.food > V.households[rich].food):
			rich = h.id
	if rich < 0 or V.households[rich].food < 20:
		return
	var head := -1
	for m in V.households[rich].members:
		var pm := V.people[m]
		if pm.alive and pm.present and Village.age_of(V, pm) >= 18:
			head = m
			break
	if head < 0:
		return
	var open: S.Crime = null
	for c in V.crimes:
		if c.act == "hoarding" and c.culprit == head and not c.closed:
			open = c
			break
	for q in V.people:
		if not q.alive or not q.present or q.hunger < 400 or Village.is_kin(V, q.id, head) or Village.age_of(V, q) < 16:
			continue
		if not R.chance(R.key(dk, 90000 + q.id), (20000 + q.traits[C.TEMPER] * 400) * V.pace):
			continue
		if open == null:
			open = add_crime(V, "hoarding", head, -1, -1, 720, V.households[rich].home_place, "grain", famine_cause(V, q),
				"full sacks glimpsed through a barn door in a hungry year", {"motive": "hunger", "falseAccusation": false})
		open.discovered = true
		give_belief(V, q.id, open.id, head, 500 + R.idiv(q.hunger, 4), q.id, 0, -1)


static func _some_living(V: S.Village, h: S.Household) -> bool:
	for m in h.members:
		if V.people[m].alive and V.people[m].present:
			return true
	return false


# ---------- theft ----------
static func try_theft(V: S.Village, p: S.Person, k: int) -> void:
	# envy: a household watching its neighbours eat better than it does
	var mine := V.households[p.household].food
	var richest := mine
	for h in V.households:
		if h.food > richest:
			for m in h.members:
				if V.people[m].alive:
					richest = h.food
					break
	var motive := R.idiv(p.hunger, 7) + p.traits[C.GREED] + clampi(R.idiv(richest - mine, 3), 0, 70)
	var inhib := inhibition(V, p, "theft")
	if int(V.runtime.get("town", {}).get("watch_until", -1)) > int(V.runtime.get("now", 0)):
		inhib += 40   # a night watch the town meeting set (sim/town_meeting.gd; the live village only)
	if motive <= inhib:
		return
	if not R.chance(k, (motive - inhib) * 900 * V.pace):
		return
	# the target: a household with something worth taking, preferring those the thief dislikes
	var target := -1
	var best := -1000
	for h in V.households:
		if h.id == p.household or h.lineage == p.lineage:
			continue
		if not _some_living(V, h):
			continue
		var worth := h.food + h.geese * 15
		if worth < 12:
			continue
		var head := -1
		for m in h.members:
			if V.people[m].alive:
				head = m
				break
		var s := worth - (Village.opinion(V, p.id, head) if head >= 0 else 0) + R.pick(R.key(k, 100 + h.id), 10)
		if s > best:
			best = s; target = h.id
	if target < 0:
		return
	var h := V.households[target]
	var place := Village.place_id(V, "pen_" + h.home)
	if not V.place_has_pos[place]:
		return
	# the opportunity: the minute (work hours) with the fewest eyes on the pen
	var when := -1
	var fewest := 99
	var eyes_at := Village.eyes_by_minute(V, place, 420, 60, 11, p.id)   # witnesses_at(V, place, m, p.id).size() for each m
	for i in 11:
		var m := 420 + i * 60
		var eyes := eyes_at[i]
		if eyes < fewest or (eyes == fewest and (R.key(k, m) & 3) == 0):
			fewest = eyes; when = m
	if fewest > (3 if p.hunger > 800 else 1):
		return  # too many eyes; not today
	if V.planning:
		V.intents.append({"kind": "theft", "actor": p.id, "minute": when, "k": k, "target": target, "place": place,
			"allow": 3 if p.hunger > 800 else 1, "tries": 0})
		return
	commit_theft(V, p, k, target, place, when)


static func commit_theft(V: S.Village, p: S.Person, k: int, target: int, place: int, when: int) -> S.Crime:
	var h := V.households[target]
	var item := "goose" if h.geese > 0 else "grain"
	if item == "goose":
		h.geese -= 1
	else:
		h.food -= 10
	V.households[p.household].food += 10
	var causes := famine_cause(V, p)
	var crime := add_crime(V, "theft", p.id, target, -1, when, place, item, causes,
		"feathers by %s's door" % E.name_of(V, p.id) if item == "goose" else "a torn grain sack", {"motive": "hunger" if p.hunger >= 300 else "greed"})
	sightings(V, crime, k)
	# the trace: goose feathers blow about the thief's door, or spilled grain leads to it
	crime.trace_at = V.households[p.household].home_place
	return crime


# ---------- brawls (assault): grudges meeting in the evening ----------
static func try_brawl(V: S.Village, p: S.Person, k: int) -> void:
	if p.traits[C.TEMPER] < 60:
		return
	var evening := Village.place_at(p, 1150)
	if evening < 0 or V.place_pen[evening]:
		return
	for i in p.rel_k.size():
		var o := p.rel_k[i]
		var v := p.rel_v[i]
		if v > -40:
			continue
		var q := V.people[o]
		if not q.alive or not q.present or Village.place_at(q, 1150) != evening or Village.age_of(V, q) < 14 or q.authored != "":
			continue
		var inhib := inhibition(V, p, "assault")
		var motive := -v + p.traits[C.TEMPER]
		if motive <= inhib or not R.chance(R.key(k, o), (motive - inhib) * 800 * V.pace):
			continue
		if V.planning:
			V.intents.append({"kind": "brawl", "actor": p.id, "other": o, "minute": 1150, "k": k, "place": evening})
			return
		commit_brawl(V, p, q, k, evening)
		return


static func commit_brawl(V: S.Village, p: S.Person, q: S.Person, k: int, evening: int, minute: int = 1150) -> S.Crime:
	var o := q.id
	var ev_name := V.place_names[evening]
	var v := Village.opinion(V, p.id, o)
	var gi := p.grudge_k.find(o)
	var why := p.grudge_v[gi] if gi >= 0 else -1
	var why_causes := PackedInt32Array([why]) if gi >= 0 else PackedInt32Array()
	# a brawl between deep enemies can end in a death (the blow that went too far), in the director's on-cycles
	var cold := p.traits[C.TEMPER] + p.traits[C.BOLD] - p.traits[C.HONESTY] - R.idiv(p.traits[C.COMPASSION], 2)
	var strong: bool = C.ROLES[p.role]["strong"] if C.ROLES.has(p.role) else false
	if v <= -80 and cold >= 40 and V.director.on and R.chance(R.key(k, 9000 + o), 180000 + (100000 if strong else 0)):
		var crime := add_crime(V, "murder", p.id, q.household, o, minute, evening, "", why_causes, "a brawl at the %s that ended with someone not getting up" % ev_name, {"motive": "revenge" if gi >= 0 else "rage"})
		crime.death_event = Village.die(V, o, "murder", PackedInt32Array([crime.event]), "blood on the ground at the %s, and a crowd gone silent" % ev_name)
		sightings(V, crime, k, true)
		crime.discovered = true
		return crime
	var crime := add_crime(V, "assault", p.id, q.household, o, minute, evening, "", why_causes, "a scuffle at the %s" % ev_name, {"motive": "grudge"})
	q.stress = clampi(q.stress + 60, 0, 400)
	Village.set_opinion(V, o, p.id, Village.opinion(V, o, p.id) - 30)
	# the victim saw who did it; so did everyone there
	give_belief(V, o, crime.id, p.id, 900, o, 0, -1)
	sightings(V, crime, k, true)
	crime.discovered = true
	return crime
	return null


# ---------- murder: rare, and only when everything lines up ----------
const MURDER_MINUTES := [390, 900, 920, 1290]


static func try_murder(V: S.Village, p: S.Person, k: int) -> void:
	# a cold heart: temper and boldness against honesty and compassion
	var cold := p.traits[C.TEMPER] + p.traits[C.BOLD] - p.traits[C.HONESTY] - R.idiv(p.traits[C.COMPASSION], 2)
	if cold < 30:
		return
	if not V.director.on:
		return  # the director keeps murder for its on-cycles
	for i in p.rel_k.size():
		var o := p.rel_k[i]
		var v := p.rel_v[i]
		if v > -70:
			continue
		var q := V.people[o]
		if not q.alive or not q.present or Village.age_of(V, q) < 16 or q.authored != "":
			continue  # never a child, in any tier (nor one of the story's own)
		if not R.chance(R.key(k, o), (cold + (-v - 70) * 3) * 300 * V.pace):
			continue
		# alone somewhere: at dawn, at work, or walking home at dusk, with no one near
		# Houses in the layout are never murder sites.
		var place := -1
		var minute := -1
		for mm: int in MURDER_MINUTES:
			var at := Village.place_at(q, mm)
			if at < 0 or at == V.pl_square or at == V.pl_shrine or V.homes.has(V.place_names[at]) or V.place_pen[at]:
				continue
			var near := 0
			for w in Village.witnesses_at(V, at, mm, p.id):
				if w != o:
					near += 1
			if near > 1:
				continue  # one pair of eyes may be missed
			place = at; minute = mm
			break
		if minute < 0:
			continue
		if V.planning:
			V.intents.append({"kind": "murder", "actor": p.id, "other": o, "minute": minute, "k": k, "place": place, "tries": 0})
			return
		commit_murder(V, p, q, k, place, minute)
		return


static func commit_murder(V: S.Village, p: S.Person, q: S.Person, k: int, place: int, minute: int) -> S.Crime:
	var o := q.id
	var gi := p.grudge_k.find(o)
	var why_causes := PackedInt32Array([p.grudge_v[gi]]) if gi >= 0 else PackedInt32Array()
	var pname := V.place_names[place]
	var crime := add_crime(V, "murder", p.id, q.household, o, minute, place, "", why_causes, "a body at the %s" % pname, {"motive": "revenge" if gi >= 0 else "grudge"})
	crime.death_event = Village.die(V, o, "murder", PackedInt32Array([crime.event]), "crows over the %s" % pname)
	sightings(V, crime, k)
	return crime


# ---------- famine and the unspeakable ----------
static func try_famine_rite(V: S.Village, p: S.Person, k: int) -> void:
	if V.tier == "store":
		return
	var h := V.households[p.household]
	if h.food > -15 or p.traits[C.PIETY] > 40 or p.hunger < 950:
		return
	var dead: S.Person = null
	for q in V.people:
		if not q.alive and q.household == p.household and V.day - q.died <= 4 and q.death_cause == "hunger" and not q.eaten:
			dead = q
			break
	if dead == null:
		return
	var inhib := inhibition(V, p, "cannibal_famine")
	if not R.chance(k, maxi(0, 1100 - inhib * 4)):
		return
	if V.planning:
		V.intents.append({"kind": "famine_rite", "actor": p.id, "other": dead.id, "minute": 60, "k": k, "place": Village.place_id(V, "pen_" + h.home)})
		return
	commit_famine_rite(V, p, dead, k)


static func commit_famine_rite(V: S.Village, p: S.Person, dead: S.Person, k: int) -> void:
	var h := V.households[p.household]
	dead.eaten = true
	h.food += 12
	var crime := add_crime(V, "cannibal_famine", p.id, p.household, dead.id, 60, Village.place_id(V, "pen_" + h.home), "the dead", famine_cause(V, p),
		"bones in the ash behind the house", {"motive": "hunger"})
	crime.trace_at = h.home_place
	sightings(V, crime, k)


# ---------- fear, omens and the witch: people 'remember' things about the village's outsiders ----------
static func witch_fear(V: S.Village, dk: int) -> void:
	if V.fear < 420:
		return
	# the most 'other' person: outsiders, loners, the marked, midwives and old women first (the trial record)
	var target := -1
	var best := -1
	for q in V.people:
		if not q.alive or not q.present or Village.age_of(V, q) < 16 or q.id == V.authority or q.authored != "":
			continue
		var other := 100 - q.traits[C.SOCIABLE]
		if q.outsider:
			other += 60
		if q.era != V.age:
			other += 120  # storm people: the natural out-group
		if q.role == "midwife":
			other += 40
		if q.sex == 1 and Village.age_of(V, q) >= 50:
			other += 40
		if q.marks.get("branded", 0):
			other += 50
		if q.cleared_day >= 0 and V.day - q.cleared_day < 3 * Village.YEAR:
			other -= 200
		if other > best or (other == best and q.id < target):
			best = other; target = q.id
	if target < 0:
		return
	# the fearful and unkind form the belief themselves (confabulation: each is its own origin)
	var open: S.Crime = null
	for c in V.crimes:
		if c.act == "sorcery" and c.culprit == target and not c.closed:
			open = c
			break
	for q in V.people:
		if not q.alive or not q.present or q.id == target or Village.age_of(V, q) < 16 or Village.is_kin(V, q.id, target):
			continue
		var pull := R.idiv(V.fear, 8) + (100 - q.traits[C.COMPASSION]) + q.traits[C.PIETY] - Village.opinion(V, q.id, target) - 150
		if pull <= 0 or not R.chance(R.key(dk, 70000 + q.id), pull * 1500 * V.pace):
			continue
		if open == null:
			open = add_crime(V, "sorcery", target, -1, -1, 1200, V.households[V.people[target].household].home_place, "",
				PackedInt32Array([V.omen_event]) if V.omen_event >= 0 else PackedInt32Array(),
				"charms of twisted straw found by a doorway", {"motive": "fear", "falseAccusation": true})
		give_belief(V, q.id, open.id, target, 450 + R.idiv(V.fear, 4), q.id, 3, -1)
		open.discovered = true


# ---------- the phased day (the live village): deeds done at their minute ----------
const PLAYER_ORIGIN := 5000000   # + crime: what the player saw with their own eyes (a clue they can testify with)


## Does the player see this place now? The live village writes the player's position (runtime.player, in dm).
static func player_sees(V: S.Village, place: int, minute: int) -> bool:
	if V.runtime.is_empty() or place < 0 or not V.place_has_pos[place]:
		return false
	var pl: Dictionary = V.runtime.get("player", {})
	if not pl.get("present", false):
		return false
	var r := C.SEE_NIGHT if minute < 360 or minute >= 1260 else C.SEE_DAY
	var dx := V.place_x[place] - int(pl.x)
	var dz := V.place_z[place] - int(pl.z)
	return dx * dx + dz * dz <= r * r


## The player saw it done: a clue of their own, kept with what they have learned (runtime.gd testify uses it).
static func player_witness(V: S.Village, crime: S.Crime) -> void:
	if crime == null:
		return
	var account: Dictionary = V.runtime.players.get_or_add("player:local", {"knowledge": [], "standing": 0, "enemies": []})
	var knowledge: Array = account.knowledge
	knowledge.append({"crime": crime.id, "culprit": crime.culprit, "origin": PLAYER_ORIGIN + crime.id, "strength": 1000,
		"via": "seen", "speaker": -1})
	if knowledge.size() > 32:
		account.knowledge = knowledge.slice(-32)


## A planned deed at its minute. The moment is checked again as it is now (who is where, and whether the player is
## watching): done, put off (the caller queues it again at it.minute), or dropped.
## -> {done, crime (S.Crime or absent), postponed, abandoned, watched, blows}
static func run_intent(V: S.Village, it: Dictionary) -> Dictionary:
	var p := V.people[int(it.actor)]
	if not p.alive or not p.present or p.locked:
		return {"abandoned": true}
	var minute: int = it.minute
	var k: int = it.k
	var seen := player_sees(V, int(it.place), minute)
	match it.kind:
		"theft":
			var h := V.households[int(it.target)]
			if h.geese <= 0 and h.food < 10:
				return {"abandoned": true, "watched": seen}
			# a stranger watching counts as two pairs of eyes
			var eyes := Village.witnesses_at(V, int(it.place), minute, p.id).size() + (2 if seen else 0)
			if eyes > int(it.allow):
				if int(it.tries) < 2 and minute + 60 <= 1020:
					it.tries = int(it.tries) + 1
					it.minute = minute + 60
					return {"postponed": true, "watched": seen}
				return {"abandoned": true, "watched": seen}
			var theft := commit_theft(V, p, k, int(it.target), int(it.place), minute)
			if seen:
				player_witness(V, theft)
			return {"done": true, "crime": theft, "watched": seen}
		"brawl", "quarrel":
			var q := V.people[int(it.other)]
			if not q.alive or not q.present or q.locked:
				return {"abandoned": true}
			if it.kind == "quarrel":
				return quarrel(V, p, q, k, int(it.place), minute, seen)
			if Village.place_at(p, minute) != int(it.place) or Village.place_at(q, minute) != int(it.place):
				return {"abandoned": true}
			var fight := commit_brawl(V, p, q, k, int(it.place), minute)
			if seen:
				player_witness(V, fight)
			return {"done": fight != null, "crime": fight, "watched": seen}
		"murder":
			var q := V.people[int(it.other)]
			if not q.alive or not q.present:
				return {"abandoned": true}
			var near := 0
			for w in Village.witnesses_at(V, int(it.place), minute, p.id):
				if w != q.id:
					near += 1
			if seen or near > 1:
				# a killer waits for a lonelier moment later today, or lets the day pass
				for mm: int in MURDER_MINUTES:
					var at := Village.place_at(q, mm)
					if mm > minute and at >= 0 and at != V.pl_square and at != V.pl_shrine and not V.homes.has(V.place_names[at]) and not V.place_pen[at] and int(it.tries) < 3:
						it.tries = int(it.tries) + 1
						it.minute = mm
						it.place = at
						return {"postponed": true, "watched": seen}
				return {"abandoned": true, "watched": seen}
			return {"done": true, "crime": commit_murder(V, p, q, k, int(it.place), minute), "watched": false}
		"famine_rite":
			var dead := V.people[int(it.other)]
			if dead.eaten or seen:
				return {"abandoned": true, "watched": seen}
			commit_famine_rite(V, p, dead, k)
			return {"done": true}
		"poaching":
			if seen:
				return {"abandoned": true, "watched": true}
			commit_poaching(V, p, k)
			return {"done": true}
		"kindness":
			return kindness(V, p, int(it.target), seen)
		"chat", "help":
			var q := V.people[int(it.other)]
			if not q.alive or not q.present or q.locked:
				return {"abandoned": true}
			Village.set_opinion(V, p.id, q.id, Village.opinion(V, p.id, q.id) + (3 if it.kind == "chat" else 2))
			Village.set_opinion(V, q.id, p.id, Village.opinion(V, q.id, p.id) + (3 if it.kind == "chat" else 6))
			return {"done": true, "watched": seen}
		"play":
			return {"done": true, "watched": seen}
		"report":
			# someone who saw the player strike a villager tells the village's authority
			var elder := V.people[int(it.other)]
			if not elder.alive or not elder.present:
				return {"abandoned": true}
			WorldActions.remember(V, elder.id, "told_about_you", -15)
			E.log_event(V, "report", p.id, elder.id, {"about": int(it.about), "motive": "duty"}, PackedInt32Array(),
				"%s speaking low to %s, pointing towards the stranger" % [E.name_of(V, p.id), E.name_of(V, elder.id)])
			return {"done": true}
	return {"abandoned": true}


## Words between two who dislike each other (the director brings these near the player). Hard words deepen the
## dislike; between a hot temper and a deep enemy they come to blows (an assault, a crime like any other).
static func quarrel(V: S.Village, p: S.Person, q: S.Person, k: int, place: int, minute: int, seen: bool) -> Dictionary:
	var worst := mini(Village.opinion(V, p.id, q.id), Village.opinion(V, q.id, p.id))
	if worst <= -60 and p.traits[C.TEMPER] >= 60 and R.chance(R.key(k, 31), 400000):
		var fight := commit_brawl(V, p, q, k, place, minute)
		if seen:
			player_witness(V, fight)
		return {"done": true, "crime": fight, "blows": true, "watched": seen}
	Village.set_opinion(V, p.id, q.id, Village.opinion(V, p.id, q.id) - 8)
	Village.set_opinion(V, q.id, p.id, Village.opinion(V, q.id, p.id) - 8)
	p.stress = clampi(p.stress + 15, 0, 400)
	q.stress = clampi(q.stress + 15, 0, 400)
	E.log_event(V, "quarrel", p.id, q.id, {"place": V.place_names[place], "motive": "grudge"}, PackedInt32Array(),
		"%s and %s shouting at the %s" % [E.name_of(V, p.id), E.name_of(V, q.id), V.place_names[place]])
	return {"done": true, "watched": seen}


## A neighbour brings food to a hungry house: food moves, and the house remembers who came.
static func kindness(V: S.Village, p: S.Person, target: int, seen: bool) -> Dictionary:
	var mine := V.households[p.household]
	var theirs := V.households[target]
	if mine.food < 16 or target == p.household:
		return {"abandoned": true}
	mine.food -= 6
	theirs.food += 6
	for m in theirs.members:
		var q := V.people[m]
		if q.alive and q.present:
			Village.set_opinion(V, m, p.id, Village.opinion(V, m, p.id) + 10)
	E.log_event(V, "kindness", p.id, -1, {"household": target, "motive": "compassion"}, PackedInt32Array(),
		"%s at the %s door with bread" % [E.name_of(V, p.id), theirs.home])
	return {"done": true, "watched": seen}

static func famine_cause(V: S.Village, p: S.Person) -> PackedInt32Array:
	if p.hunger < 300:
		return PackedInt32Array()
	var i := V.events.size() - 1
	while i >= 0 and i > V.events.size() - 400:
		if V.events[i].type == "famine":
			return PackedInt32Array([i])
		i -= 1
	return PackedInt32Array()


static func add_crime(V: S.Village, act: String, culprit: int, household: int, victim: int, minute: int, place: int, item: String, causes: PackedInt32Array, cue: String, data: Dictionary) -> S.Crime:
	var crime := S.Crime.new()
	crime.id = V.crimes.size(); crime.act = act; crime.culprit = culprit; crime.household = household; crime.victim = victim
	crime.day = V.day; crime.minute = minute; crime.place = place; crime.item = item
	crime.false_accusation = data.get("falseAccusation", false)
	V.crimes.append(crime)
	V.stats["crimes"] += 1
	crime.event = E.log_event(V, "crime", culprit, victim, {"crime": crime.id, "act": act, "item": item, "motive": data.get("motive", ""), "place": V.place_names[place], "household": household}, causes, cue)
	if not crime.false_accusation:
		V.people[culprit].secret.append(crime.id)
	return crime


# Who saw it: anyone whose plan puts them within sight, with a keyed chance by alertness (less by night).
static func sightings(V: S.Village, crime: S.Crime, k: int, public_act: bool = false) -> void:
	var eyes := Village.witnesses_at(V, crime.place, crime.minute, crime.culprit)
	var night := crime.minute < 360 or crime.minute >= 1260
	for w in eyes:
		var q := V.people[w]
		var odds := 900000 if public_act else (2500 if night else 7000) * q.traits[C.ALERT]
		if not R.chance(R.key(k, 5000 + w), odds):
			continue
		crime.witnesses.append(w)
		give_belief(V, w, crime.id, crime.culprit, 500 + q.traits[C.ALERT] * 4, w, 0, -1)


# ---------- discovery: the loss is noticed; traces are seen ----------
static func discover_crimes(V: S.Village) -> void:
	for c in V.crimes:
		if c.closed:
			continue
		if not c.discovered and V.day > c.day:
			c.discovered = true
			var owners: Array[int] = []
			if c.household >= 0:
				for m in V.households[c.household].members:
					if V.people[m].alive and V.people[m].present:
						owners.append(m)
			var cue := "an empty goose pen, a squawk remembered" if c.item == "goose" else ("the grain sacks lighter than yesterday" if c.item == "grain" else ("crows over a still shape" if c.act == "murder" else "something wrong at the house"))
			c.discovery_event = E.log_event(V, "discovery", owners[0] if owners.size() > 0 else -1, -1, {"crime": c.id, "act": c.act}, PackedInt32Array([c.event]), cue)
			if c.act == "murder":
				V.fear = clampi(V.fear + 250, 0, 1000)
			# prejudice: the wronged suspect someone they already dislike, or who is known for it (each such
			# suspicion is its own origin; with one real rumour it makes an accusation, right or wrong)
			for o in owners:
				suspect(V, o, c)
			# a killing: the elder asks who hated the dead (everyone saw the quarrels)
			if c.act == "murder" and V.authority >= 0 and not owners.has(V.authority):
				suspect(V, V.authority, c)
			# honest witnesses come to the door the next day (Dwarf Fortress: a case exists through its witnesses)
			var told := -1
			for o in owners:
				if Village.age_of(V, V.people[o]) >= 14:
					told = o
					break
			if told >= 0:
				for w in c.witnesses:
					var q := V.people[w]
					if w == told or not q.alive or not q.present or Village.is_kin(V, w, c.culprit) or q.traits[C.HONESTY] < 45 or Village.opinion(V, w, c.culprit) > 30:
						continue
					var seen: S.Belief = null
					for b in q.beliefs:
						if b.crime == c.id and b.origin == w:
							seen = b
							break
					if seen == null:
						continue
					var nb := give_belief(V, told, c.id, seen.culprit, seen.strength, w, 1, w)
					nb.event = E.log_event(V, "rumour", w, told, {"crime": c.id, "culprit": seen.culprit, "via": 1},
						PackedInt32Array([c.discovery_event if c.discovery_event >= 0 else c.event]), "%s at %s's door with news" % [E.name_of(V, w), E.name_of(V, told)])
		# traces: neighbours of the thief's home who pass by may notice (feathers, bones)
		if c.trace_at >= 0 and V.day - c.day <= 3:
			var eyes := Village.witnesses_at(V, c.trace_at, 1100, c.culprit)
			for w in eyes:
				if Village.is_kin(V, w, c.culprit):
					continue
				if R.chance(R.key(R.key(R.key(V.base, Village.P_SIGHT), V.day), c.id * 131 + w), V.people[w].traits[C.ALERT] * 3000):
					give_belief(V, w, c.id, c.culprit, 380, TRACE_ORIGIN + c.id, 0, -1)


static func suspect(V: S.Village, pid: int, c: S.Crime) -> void:
	var p := V.people[pid]
	if Village.age_of(V, p) < 16:
		return
	var who := -1
	var best := 30
	for q in V.people:
		if not q.alive or not q.present or q.id == pid or Village.is_kin(V, pid, q.id) or Village.age_of(V, q) < 14 or Ported.held(V, q):
			continue
		var s := -Village.opinion(V, pid, q.id) + q.offences * 40 + (25 if q.outsider else 0) + (40 if q.marks.get("branded", 0) else 0) + R.idiv(q.hunger, 25)
		if q.cleared_day >= 0 and V.day - q.cleared_day < 3 * Village.YEAR:
			s -= 120  # wrongly punished once: the village is ashamed
		if c.victim >= 0 and Village.opinion(V, q.id, c.victim) <= -50:
			s += 90  # known to hate the dead
		s += R.key(R.key(V.base, c.id * 7 + pid), q.id) % 15
		if s > best:
			best = s; who = q.id
	# a household's prejudice is one source, however many of them share it (it is not independent evidence)
	if who >= 0:
		give_belief(V, pid, c.id, who, 250 + best * 3, PREJUDICE_ORIGIN + p.household, 3, -1)


static func give_belief(V: S.Village, pid: int, crime: int, culprit: int, strength: int, origin: int, via: int, from: int) -> S.Belief:
	var p := V.people[pid]
	for have in p.beliefs:
		if have.crime == crime and have.culprit == culprit and have.origin == origin:
			have.strength = clampi(maxi(have.strength, strength), 0, 1000)
			return have
	var b := S.Belief.new()
	b.crime = crime; b.culprit = culprit; b.strength = clampi(strength, 0, 1000); b.origin = origin; b.via = via; b.from = from; b.day = V.day
	p.beliefs.append(b)
	if p.beliefs.size() > MAX_BELIEFS:
		var w := 0
		for i in range(1, p.beliefs.size()):
			if p.beliefs[i].strength < p.beliefs[w].strength:
				w = i
		p.beliefs.remove_at(w)
	return b


# ---------- gossip: knowledge travels where people are together ----------
const SOCIAL := [[720, 780], [1080, 1260], [540, 660]]  # meals, evenings, the holy-day service


@warning_ignore("integer_division")
static func gossip(V: S.Village) -> void:
	for window: Array in SOCIAL:
		gossip_window(V, window)


## One gathering window (a meal, the evening, the holy-day service): who is together talks.
@warning_ignore("integer_division")
static func gossip_window(V: S.Village, window: Array) -> void:
	var gk := R.key(R.key(V.base, Village.P_GOSSIP), V.day)
	var people := V.people
	var pace := V.pace
	var lang := V.lang
	var min_born := V.day - 12 * Village.YEAR   # (port) age_of(p) >= 12 is p.born <= V.day - 720
	var from: int = window[0]
	var to: int = window[1]
	# who is together: one group per place, in people order; the places are taken in string order of their
	# names (the reference sorts the group keys), so the groups are kept by the place's name rank
	var groups := []
	groups.resize(V.n_places)
	for p in people:
		if not p.alive or not p.present or p.locked or p.born > min_born:
			continue
		# place_at(p, from + 10) and place_at(p, to - 10), inlined
		var pl := p.plan
		var at := -1
		var at2 := -1
		var pi := 0
		while pi < pl.size():
			if from + 10 >= pl[pi] and from + 10 < pl[pi + 1]:
				at = pl[pi + 2]
			if to - 10 >= pl[pi] and to - 10 < pl[pi + 1]:
				at2 = pl[pi + 2]
			pi += 3
		if at < 0 or at2 != at:
			continue
		var r := V.place_rank[at]
		if groups[r] == null:
			var fresh: Array[int] = []
			groups[r] = fresh
		(groups[r] as Array[int]).append(p.id)
	for group: Variant in groups:
		if group == null:
			continue
		var ids: Array[int] = group
		var n := ids.size()
		for i in n:
			var a := ids[i]
			var sp := people[a]
			var t := sp.traits
			var ka := a * 4099 + from
			# mingle's terms that depend on the speaker only
			var slight0 := t[C.TEMPER] * 60 - t[C.COMPASSION] * 20
			var warm := (20000 + t[C.SOCIABLE] * 300) * pace
			var lang_row := sp.era * 3
			var rk := sp.rel_k   # (a's feelings do not change while a speaks: only listeners' do)
			var rv := sp.rel_v
			# tell() has nothing to say unless the speaker holds a belief about an open, unsettled crime (a pure
			# check on the speaker's beliefs, which do not change while they speak): skip it otherwise
			var tellable := false
			for bf in sp.beliefs:
				var cr := V.crimes[bf.crime]
				if not cr.closed and (cr.case_open or V.day - cr.day <= 30):
					tellable = true
					break
			for j in n:
				if i == j:
					continue
				var b := ids[j]
				# k = key(gk, ids[i] * 4099 + ids[j] + from), and key(k, 77) for mingle (rng.gd key, inlined: this
				# loop runs for every pair in every group three times a day)
				var k := (gk ^ (ka + b)) & R.M32
				k = ((k ^ (k >> 16)) * 0x7feb352d) & R.M32
				k ^= k >> 15
				k = (k * 0x046ca68b + ((k & 1) << 31)) & R.M32
				k ^= k >> 16
				if tellable:
					tell(V, a, b, k)
				# mingle(V, a, b, key(k, 77)), inlined
				var k2 := k ^ 77
				k2 = ((k2 ^ (k2 >> 16)) * 0x7feb352d) & R.M32
				k2 ^= k2 >> 15
				k2 = (k2 * 0x046ca68b + ((k2 & 1) << 31)) & R.M32
				k2 ^= k2 >> 16
				var ls := people[b]
				var op := 0   # opinion(V, a, b)
				var ri := rk.find(b)
				if ri >= 0:
					op = rv[ri]
				elif sp.household == ls.household or sp.lineage == ls.lineage or sp.spouse == b or sp.father == b or sp.mother == b or ls.father == a or ls.mother == a:
					op = 50
				var slight := slight0 + maxi(0, -op) * 450 + lang[lang_row + ls.era] * 60
				if slight > 0 and ((k2 * 1000000) >> 32) < slight * pace:
					Village.set_opinion(V, b, a, Village.opinion(V, b, a) - 4 - ls.traits[C.TEMPER] / 12)   # (temper >= 0: idiv is /)
					continue
				var k3 := k2 ^ 1
				k3 = ((k3 ^ (k3 >> 16)) * 0x7feb352d) & R.M32
				k3 ^= k3 >> 15
				k3 = (k3 * 0x046ca68b + ((k3 & 1) << 31)) & R.M32
				k3 ^= k3 >> 16
				if ((k3 * 1000000) >> 32) < warm:
					Village.set_opinion(V, b, a, Village.opinion(V, b, a) + 2)


# Everyday friction and warmth (RimWorld's chitchat and slights): the hot-tempered give offence, the
# sociable make friends. Each is small; over years they add up to friendships and enmities, and an old
# dislike makes the next slight likelier (so enmities deepen unless time heals them).
# (not called: gossip inlines it for speed. Kept as the readable twin of the reference's mingle so the port
# diffs line by line; a change here must be made in gossip too.)
@warning_ignore("integer_division")
static func mingle(V: S.Village, a: int, b: int, k: int) -> void:
	var sp := V.people[a]
	var ls := V.people[b]
	var t := sp.traits
	var slight := t[C.TEMPER] * 60 + maxi(0, -Village.opinion(V, a, b)) * 450 - t[C.COMPASSION] * 20 + V.lang[sp.era * 3 + ls.era] * 60
	if slight > 0 and ((k * 1000000) >> 32) < slight * V.pace:   # chance(k, slight * pace)
		Village.set_opinion(V, b, a, Village.opinion(V, b, a) - 4 - ls.traits[C.TEMPER] / 12)   # (temper >= 0: idiv is /)
		return
	if R.chance(R.key(k, 1), (20000 + t[C.SOCIABLE] * 300) * V.pace):
		Village.set_opinion(V, b, a, Village.opinion(V, b, a) + 2)


@warning_ignore("integer_division")
static func tell(V: S.Village, a: int, b: int, k: int) -> void:
	var sp := V.people[a]
	var ls := V.people[b]
	if sp.beliefs.size() == 0:
		return
	# across the ages speech barely carries (a storm's forebears and the villagers): language distance
	var lang := 100 - V.lang[sp.era * 3 + ls.era]
	if ((k * 1000000) >> 32) >= (250000 + sp.traits[C.SOCIABLE] * 5000) * lang / 100:   # chance(k, idiv(...)); all terms >= 0
		return
	# the speaker's strongest belief the listener has not heard (old news about settled cases is not told)
	var heard_list := ls.beliefs
	var best: S.Belief = null
	for bf in sp.beliefs:
		var cr := V.crimes[bf.crime]
		if bf.culprit == b or cr.closed or (not cr.case_open and V.day - cr.day > 30):
			continue  # cold or settled: not told
		if best != null and bf.strength <= best.strength:
			continue  # (port: could not become the best; the heard check below has no side effects)
		var heard := false
		for x in heard_list:
			if x.crime == bf.crime and x.culprit == bf.culprit and x.origin == bf.origin:
				heard = true
				break
		if heard:
			continue
		best = bf
	if best == null:
		return
	var trust := clampi(500 + Village.opinion(V, b, a) * 4, 100, 900)
	var heard_before := false
	for x in heard_list:
		if x.crime == best.crime:
			heard_before = true
			break
	var culprit := best.culprit
	var origin := best.origin
	var via := 1
	# bent by dislike: sometimes the listener hears what they already wanted to believe
	# (port: the reference finds the enemy first; it is pure, so it is found only when the other terms allow it)
	var crime := V.crimes[best.crime]
	if crime.act != "sorcery" and not heard_before and R.chance(R.key(k, 3), 45000):
		var enemy := -1
		var worst := -40
		var rk := ls.rel_k
		var rv := ls.rel_v
		for i in rk.size():
			var o := rk[i]
			var v := rv[i]
			if v < worst and V.people[o].alive and V.people[o].present and o != a and o != b and not Ported.held(V, V.people[o]):
				worst = v; enemy = o
		if enemy >= 0:
			culprit = enemy; origin = b; via = 3
	var nb := give_belief(V, b, best.crime, culprit, best.strength * trust / 1000, origin, via, a)
	best.strength = clampi(best.strength + 15, 0, 1000)  # retelling strengthens the teller's own belief
	# only what reaches the wronged household or the elder is kept in the chronicle (the tales follow it)
	var wronged := crime.household >= 0 and ls.household == crime.household
	if (wronged or b == V.authority) and not heard_before:
		nb.event = E.log_event(V, "rumour", a, b, {"crime": best.crime, "culprit": culprit, "via": via},
			PackedInt32Array([best.event if best.event >= 0 else crime.event]), "%s whispering to %s" % [E.name_of(V, a), E.name_of(V, b)])


# ---------- cases: two independent sources make an accusation ----------
static func check_cases(V: S.Village) -> void:
	for c in V.crimes:
		if c.closed or not c.discovered or c.case_open:
			continue
		# a cold case: two months with no one able to name anyone, and it is let go
		if V.day - (c.reopen_day if c.reopen_day >= 0 else c.day) > 60:
			c.closed = true
			continue
		# who may accuse: the wronged household (and the elder); for witchcraft, anyone
		var accusers: Array[int] = []
		if c.household >= 0 and c.act != "sorcery":
			for m in V.households[c.household].members:
				var pm := V.people[m]
				if pm.alive and pm.present and Village.age_of(V, pm) >= 14 and m >= 0:
					accusers.append(m)
			if V.authority >= 0:
				accusers.append(V.authority)
		else:
			for q in V.people:
				if q.alive and q.present and Village.age_of(V, q) >= 16:
					accusers.append(q.id)
		var pick_acc := -1
		var pick_cul := -1
		var pick_str := 0
		var pick_ev := PackedInt32Array()
		for acc in accusers:
			# (port) a case needs two of this accuser's beliefs naming someone else for this crime: skip the rest early
			var naming := 0
			for bf in V.people[acc].beliefs:
				if bf.crime == c.id and bf.culprit != acc:
					naming += 1
			if naming < 2:
				continue
			# by: culprit -> (origin -> strongest), both insertion ordered
			var by := {}
			for bf in V.people[acc].beliefs:
				if bf.crime != c.id or bf.culprit == acc:
					continue
				if not by.has(bf.culprit):
					by[bf.culprit] = {}
				var m: Dictionary = by[bf.culprit]
				m[bf.origin] = maxi(m.get(bf.origin, 0), bf.strength)
			for cul: int in by:
				var origins: Dictionary = by[cul]
				if origins.size() < 2:
					continue
				var total := 0
				for v: int in origins.values():
					total += v
				if total < 600:
					continue
				if total > pick_str or (total == pick_str and cul < pick_cul):
					pick_str = total; pick_acc = acc; pick_cul = cul
					pick_ev = PackedInt32Array()
					for bf in V.people[acc].beliefs:
						if bf.crime == c.id and bf.culprit == cul and bf.event >= 0:
							pick_ev.append(bf.event)
		if pick_acc < 0 or not V.people[pick_cul].alive or not V.people[pick_cul].present or Ported.held(V, V.people[pick_cul]):
			continue
		c.case_open = true
		V.stats["cases"] += 1
		var causes := PackedInt32Array([c.discovery_event if c.discovery_event >= 0 else c.event])
		causes.append_array(pick_ev.slice(0, 4))
		var ev := E.log_event(V, "accusation", pick_acc, pick_cul, {"crime": c.id, "act": c.act, "evidence": pick_str, "wrongful": pick_cul != c.culprit or c.false_accusation},
			causes, "%s pointing at %s in the square" % [E.name_of(V, pick_acc), E.name_of(V, pick_cul)])
		var cs := S.Case.new()
		cs.id = V.cases.size(); cs.crime = c.id; cs.accuser = pick_acc; cs.accused = pick_cul; cs.evidence = pick_str; cs.event = ev; cs.day = V.day
		V.cases.append(cs)
		# the elder tries it, unless the village no longer listens to the elder and the crowd is hot
		var anger := R.idiv(V.fear, 2) + R.idiv(V.hardship, 3) + int(C.ACTS[c.act]["severity"]) * 90
		var cap := Justice.authority_capacity(V)
		if Director.lethal_allowed(V) and cap < 420 and anger > cap + 250:
			V.director.lethal += 1  # (the mob takes the cycle's one death now)
			Justice.schedule_mob(V, cs)
		else:
			Justice.schedule_trial(V, cs)
