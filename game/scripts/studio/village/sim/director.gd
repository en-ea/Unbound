extends RefCounted
## Port of tools-src/studio/village-reference/director.mjs.
## The pacing director (RimWorld's storyteller): the village alternates quiet and eventful cycles of keyed
## length. Blood is rationed (at most one lethal public act per eventful cycle, and a cooldown after any
## killing); quiet cycles carry festivals; omens arrive rarely, likelier in hard times, and raise the fear
## that finds scapegoats. The director never forces an act: it only permits, withholds and paces.

const R := preload("res://scripts/studio/village/sim/rng.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")

const FEASTS := {22: "Midsummer", 44: "Harvest Home", 57: "Midwinter"}


static func director_day(V: S.Village) -> void:
	var d := V.director
	var k := R.key(R.key(V.base, Village.P_CYCLE), V.day)
	if V.day >= d.until:
		d.on = not d.on
		# (the village the player is in rests less between its eventful stretches)
		d.until = V.day + (12 + R.pick(k, 10) if d.on else (6 + R.pick(R.key(k, 1), 6) if V.focus else 25 + R.pick(R.key(k, 1), 20)))
		d.lethal = 0
		d.cycles += 1
	if V.focus:
		focus_day(V, k)
	var doy := V.day % Village.YEAR
	if FEASTS.has(doy):
		var s := S.Sched.new()
		s.day = V.day; s.kind = "festival"; s.name = FEASTS[doy]; s.who = -1; s.other = -1
		V.schedule.append(s)
	# omens: rare; hardship makes them likelier (a hungry village reads signs everywhere)
	if R.chance(R.key(k, 2), (900 + R.idiv(V.hardship, 2) * 8) * V.pace):
		var omen: String = C.OMENS[R.pick(R.key(k, 3), C.OMENS.size())]
		V.fear = clampi(V.fear + 460, 0, 1000)
		V.stats["omens"] += 1
		V.omen_event = E.log_event(V, "omen", -1, -1, {"omen": omen}, PackedInt32Array(), omen)


# The player's village, paced by play time (a game day is 12 real minutes: an hour is 5 days). When nothing
# public has happened for longer than the target, pressure builds and the director sends an incident: a real
# event with consequences the tales can cite, never an act forced on anyone. People still decide.
const FOCUS_GAP := 5  # game days without a public act before pressure builds (about an hour of play)


static func focus_day(V: S.Village, k: int) -> void:
	var d := V.director
	if V.day - d.last_act <= FOCUS_GAP:
		d.pressure = 0
		return
	d.pressure += 1
	if not R.chance(R.key(k, 50), d.pressure * 60000):
		return
	d.pressure = 0
	var which := R.pick(R.key(k, 51), 4)
	if which == 0:  # an omen
		var omen: String = C.OMENS[R.pick(R.key(k, 3), C.OMENS.size())]
		V.fear = clampi(V.fear + 460, 0, 1000)
		V.stats["omens"] += 1
		V.omen_event = E.log_event(V, "omen", -1, -1, {"omen": omen}, PackedInt32Array(), omen)
	elif which == 1:  # blight: a hard season
		V.hardship = clampi(V.hardship + 250, 0, 1000)
		for h in V.households:
			h.food = maxi(0, h.food - 12)
		E.log_event(V, "famine", -1, -1, {"year": R.idiv(V.day, Village.YEAR), "blight": true}, PackedInt32Array(), "black spots on the leaves, and the field half lost in a week")
	elif which == 2:  # a lodger: a stranger taken in by the poorest house (outsiders draw suspicion, and some deserve it)
		var poor := -1
		for h in V.households:
			var lived := false
			for m in h.members:
				if V.people[m].alive and V.people[m].present:
					lived = true
					break
			if lived and (poor < 0 or h.food < V.households[poor].food):
				poor = h.id
		if poor < 0:
			return
		var id := Village.add_person(V, poor, R.pick(R.key(k, 52), 2), 20 + R.pick(R.key(k, 53), 25), -1, -1, {"quiet": true})
		var p := V.people[id]
		p.outsider = true; p.role = "beggar"
		p.traits[C.GREED] = clampi(p.traits[C.GREED] + 25, 0, 100); p.traits[C.HONESTY] = clampi(p.traits[C.HONESTY] - 20, 0, 100)
		E.log_event(V, "arrival", id, -1, {"lodger": true, "household": poor}, PackedInt32Array(), "a stranger with a pack at the %s house, taken in for the price of the work" % V.households[poor].home)
	else:  # a quarrel: a boundary stone moved in the night between two houses
		var heads: Array[int] = []
		for h in V.households:
			for m in h.members:
				var pm := V.people[m]
				if pm.alive and pm.present and Village.age_of(V, pm) >= 18:
					heads.append(m)
					break
		if heads.size() < 2:
			return
		var a := heads[R.pick(R.key(k, 54), heads.size())]
		var b := heads[R.pick(R.key(k, 55), heads.size())]
		if a == b:
			b = heads[(heads.find(a) + 1) % heads.size()]
		var ev := E.log_event(V, "rivalry", a, b, {"motive": "land"}, PackedInt32Array(), "a boundary stone moved in the night between the %s and %s fields" % [V.households[V.people[a].household].home, V.households[V.people[b].household].home])
		Village.set_opinion(V, a, b, Village.opinion(V, a, b) - 40)
		Justice.remember(V.people[a], b, ev)
		Village.set_opinion(V, b, a, Village.opinion(V, b, a) - 40)
		Justice.remember(V.people[b], a, ev)


# ---------- attention: the village the player is in brings something near after a quiet stretch ----------
# The director never makes anyone act against their motives. It picks a tension that already exists and chooses
# when and where it comes to a head: a theft someone planned for later today, now and at a pen near the player;
# two people who dislike each other meeting where the player is; a kind neighbour on their way to a hungry house.
const ATTENTION_MINUTES := [420, 480, 540, 600, 660, 720, 780, 840, 900, 960, 1020, 1080, 1140, 1200, 1260]   # the waking day, hourly
const ATTENTION_EVERY := 15   # the live village looks every quarter hour (plan LIVELY-VILLAGE 2.3, the review's round 2
                              # SHOULD 1: the hour's wait was up to 30 real seconds of the quiet gap); the chronicle keeps
                              # the hourly phases above, where attention brings nothing
const QUIET := 150            # game minutes (75 real seconds) with nothing shown near the player (was 240; 360 before
                              # that: plan LIVELY-VILLAGE 2.1, the quiet gap in view by day held to 120 real seconds)
const NEAR_DM := 400          # "near": the nearest public place within 40 m of the player
const LEAD := 15              # minutes from the choice to the moment (people have to walk there)
const NEAR_PLACES := ["well", "square", "field", "pasture", "mill", "forge", "shrine"]


## The minutes of a day the director looks: every quarter hour of the waking day in the live village, hourly in the
## chronicle (its phases, and so its golden hashes, unchanged).
static func attention_minutes(V: S.Village) -> Array:
	if V.runtime.is_empty():
		return ATTENTION_MINUTES
	return range(ATTENTION_MINUTES[0], ATTENTION_MINUTES[-1] + 1, ATTENTION_EVERY)


## -> the intent brought near (Dictionary), or {} if nothing was.
static func attention(V: S.Village) -> Dictionary:
	if V.runtime.is_empty() or not V.focus:
		return {}
	var pl: Dictionary = V.runtime.get("player", {})
	if not pl.get("present", false):
		return {}
	var now := int(V.runtime.now)
	if now - int(V.runtime.get("quiet_since", now)) < QUIET:
		return {}
	var minute := now % 1440 + LEAD
	if minute >= 1380:
		return {}
	var k := R.key(R.key(V.base, Village.P_CYCLE), now)
	var near := _nearest_place(V, pl)
	var last: String = V.runtime.get("last_scene", "")
	var brought := {} if last == "theft" else _bring_theft(V, pl, minute)
	if brought.is_empty() and near >= 0:
		# the rest in a keyed order, skipping whatever was shown last (the village has more than one mood)
		var kinds := ["quarrel", "kindness", "chat", "play", "help"]
		var start := R.pick(k, kinds.size())
		for i in kinds.size():
			var kind: String = kinds[(start + i) % kinds.size()]
			if kind == last:
				continue
			match kind:
				"quarrel": brought = _bring_quarrel(V, near, minute, k)
				"kindness": brought = _bring_kindness(V, minute, k)
				"chat": brought = _bring_pair(V, near, minute, k, "chat")
				"play": brought = _bring_play(V, near, minute, k)
				"help": brought = _bring_pair(V, near, minute, k, "help")
			if not brought.is_empty():
				break
	if not brought.is_empty():
		V.runtime.quiet_since = now
		V.runtime.last_scene = brought.kind
		Village.add_intent(V, brought)
	return brought


static func _nearest_place(V: S.Village, pl: Dictionary) -> int:
	var best := -1
	var best_d := NEAR_DM * NEAR_DM
	for name: String in NEAR_PLACES:
		var id: int = V.place_ids.get(name, -1)
		if id < 0 or not V.place_has_pos[id]:
			continue
		var dx := V.place_x[id] - int(pl.x)
		var dz := V.place_z[id] - int(pl.z)
		if dx * dx + dz * dz < best_d:
			best_d = dx * dx + dz * dz
			best = id
	return best


## A theft planned for later today comes now, at the eligible pen nearest the player (the same thief, the same want).
static func _bring_theft(V: S.Village, pl: Dictionary, minute: int) -> Dictionary:
	for it: Dictionary in V.intents:
		if it.kind != "theft" or int(it.minute) <= minute:
			continue
		var p := V.people[int(it.actor)]
		var best := -1
		var best_d := NEAR_DM * NEAR_DM * 4
		for h in V.households:
			if h.id == p.household or h.lineage == p.lineage or h.food + h.geese * 15 < 12:
				continue
			var pen := Village.place_id(V, "pen_" + h.home)
			if pen < 0 or not V.place_has_pos[pen]:
				continue
			var dx := V.place_x[pen] - int(pl.x)
			var dz := V.place_z[pen] - int(pl.z)
			if dx * dx + dz * dz < best_d:
				best_d = dx * dx + dz * dz
				best = h.id
		if best < 0:
			continue
		# the moved deed replaces the planned one (the old phase finds it already done)
		var moved := it.duplicate()
		it.minute = -1
		it.kind = "moved"
		moved.target = best
		moved.place = Village.place_id(V, "pen_" + V.households[best].home)
		moved.minute = minute
		moved.near = true
		return moved
	return {}


static func _bring_quarrel(V: S.Village, near: int, minute: int, k: int) -> Dictionary:
	var pairs: Array = []
	for p in V.people:
		if not _free(V, p):
			continue
		for i in p.rel_k.size():
			var o := p.rel_k[i]
			if o > p.id and p.rel_v[i] <= -25 and _free(V, V.people[o]):
				pairs.append([p.id, o])
	if pairs.is_empty():
		return {}
	var pair: Array = pairs[R.pick(R.key(k, 1), pairs.size())]
	for id: int in pair:
		Village.plan_insert(V.people[id], minute - 5, minute + 25, near)
	return {"kind": "quarrel", "actor": pair[0], "other": pair[1], "minute": minute, "k": R.key(k, 2), "place": near, "near": true, "tries": 0}


static func _bring_kindness(V: S.Village, minute: int, k: int) -> Dictionary:
	var hungry: Array = []
	for h in V.households:
		for m in h.members:
			var q := V.people[m]
			if q.alive and q.present and q.hunger >= 300:
				hungry.append(h.id)
				break
	if hungry.is_empty():
		return {}
	var target: int = hungry[R.pick(R.key(k, 3), hungry.size())]
	var giver := -1
	for p in V.people:
		if _free(V, p) and p.household != target and p.traits[C.COMPASSION] >= 60 and V.households[p.household].food >= 16:
			if giver < 0 or p.traits[C.COMPASSION] > V.people[giver].traits[C.COMPASSION]:
				giver = p.id
	if giver < 0:
		return {}
	var home := V.households[target].home_place
	Village.plan_insert(V.people[giver], minute - 5, minute + 20, home)
	return {"kind": "kindness", "actor": giver, "target": target, "minute": minute, "k": R.key(k, 4), "place": home, "near": true, "tries": 0}


## Two who get on (a friendly word; or one helping the other carry something home).
static func _bring_pair(V: S.Village, near: int, minute: int, k: int, kind: String) -> Dictionary:
	var pairs: Array = []
	for p in V.people:
		if not _free(V, p):
			continue
		for i in p.rel_k.size():
			var o := p.rel_k[i]
			if o > p.id and p.rel_v[i] >= 30 and _free(V, V.people[o]):
				pairs.append([p.id, o])
	if pairs.is_empty():
		return {}
	var pair: Array = pairs[R.pick(R.key(k, 5), pairs.size())]
	var place := near if kind == "chat" else V.households[V.people[pair[1]].household].home_place
	for id: int in pair:
		Village.plan_insert(V.people[id], minute - 5, minute + 25, place)
	return {"kind": kind, "actor": pair[0], "other": pair[1], "minute": minute, "k": R.key(k, 6), "place": place, "near": true, "tries": 0}


## Children at play near the player (two or three, chasing about).
static func _bring_play(V: S.Village, near: int, minute: int, k: int) -> Dictionary:
	var kids: Array = []
	for p in V.people:
		if p.alive and p.present and not p.locked and p.authored == "" and Village.age_of(V, p) >= 5 and Village.age_of(V, p) < 14:
			kids.append(p.id)
	if kids.size() < 2:
		return {}
	var first := R.pick(R.key(k, 7), kids.size())
	var group: Array = [kids[first], kids[(first + 1) % kids.size()]]
	if kids.size() >= 3:
		group.append(kids[(first + 2) % kids.size()])
	for id: int in group:
		Village.plan_insert(V.people[id], minute - 5, minute + 25, near)
	return {"kind": "play", "actor": group[0], "others": group, "minute": minute, "k": R.key(k, 8), "place": near, "near": true, "tries": 0}


## An adult who is here, free and not in any event.
static func _free(V: S.Village, p: S.Person) -> bool:
	return p.alive and p.present and not p.locked and p.ancestor < 0 and p.authored == "" and Village.age_of(V, p) >= 16


static func lethal_allowed(V: S.Village) -> bool:
	return V.director.on and V.director.lethal < 1 and V.day >= V.director.cooldown


static func note_act(V: S.Village, kind: String) -> void:
	var d := V.director
	d.last_act = V.day
	d.last.append(kind)
	if d.last.size() > 5:
		d.last.remove_at(0)
	if C.PUBLIC.has(kind) and C.PUBLIC[kind]["lethal"]:
		d.lethal += 1
		d.cooldown = V.day + 15
