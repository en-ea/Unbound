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
