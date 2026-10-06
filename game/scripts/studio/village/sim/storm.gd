extends RefCounted
## Port of tools-src/studio/village-reference/storm.mjs.
## Time storms: a storm folds a household's ground back to its own ancestors. The people who lived there are
## gone for the storm's length (lost in it), and the lineage's forebears from the tribal age stand in their
## place: their own names, their age's norms (theft merely shunned, sacrifice respected), their old feuds
## with the other lineages, and a speech the villagers barely follow. When the storm recedes the ancestors
## fade and the lost come home. An anchored story village is never touched.
##
## The world kernel decides when and where a storm strikes (storm_hits); a village can also be given a plan
## for tests (opts.stormPlan). Nothing here runs unless a storm has struck, so a storm-free village behaves
## exactly as before (the golden hashes do not move).

const R := preload("res://scripts/studio/village/sim/rng.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Crime := preload("res://scripts/studio/village/sim/crime.gd")
const Director := preload("res://scripts/studio/village/sim/director.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")


static func storm_hits(V: S.Village, hid: int, days: int, causes: PackedInt32Array = PackedInt32Array()) -> int:
	if V.anchored:
		return -1  # anchored story villages are exempt
	var hh := V.households[hid]
	for s in V.storms:
		if s.active and s.household == hid:
			return -1
	var k := R.key(R.key(V.base, Village.P_STORM), V.day * 31 + hid)
	var lin := V.lineages[hh.lineage]
	var ev := E.log_event(V, "storm", -1, -1, {"household": hid, "lineage": hh.lineage, "days": days, "phase": "strikes"}, causes,
		"the air over the %s house folding like heat-haze; when it clears, strangers in furs stand at the door" % hh.home)
	var st := S.Storm.new()
	st.id = V.storms.size(); st.household = hid; st.from = V.day; st.until = V.day + days; st.event = ev; st.active = true
	V.storms.append(st)
	for m in hh.members:
		var p := V.people[m]
		if not p.alive or not p.present:
			continue
		p.present = false; p.lost_to_storm = st.id; p.locked = false
		st.lost.append(m)
	# the forebears: a couple in their prime, sometimes an old one, and children (tribal names, tribal ways)
	var tribal := {"era": C.TRIBAL, "quiet": true}
	var father := Village.add_person(V, hid, 0, 26 + R.pick(R.key(k, 1), 14), -1, -1, tribal)
	var mother := Village.add_person(V, hid, 1, 22 + R.pick(R.key(k, 2), 14), -1, -1, tribal)
	V.people[father].spouse = mother; V.people[mother].spouse = father
	var born: Array[int] = [father, mother]
	if R.chance(R.key(k, 3), 500000):
		born.append(Village.add_person(V, hid, R.pick(R.key(k, 4), 2), 50 + R.pick(R.key(k, 5), 15), -1, -1, tribal))
	var c := 0
	while c < 1 + R.pick(R.key(k, 6), 3):
		born.append(Village.add_person(V, hid, R.pick(R.key(k, 10 + c), 2), 3 + R.pick(R.key(k, 20 + c), 14), father, mother, tribal))
		c += 1
	for id in born:
		var a := V.people[id]
		a.ancestor = st.id
		# a harder age: quicker tempers, deeper faith
		a.traits[C.TEMPER] = clampi(a.traits[C.TEMPER] + 12, 0, 100)
		a.traits[C.PIETY] = clampi(a.traits[C.PIETY] + 18, 0, 100)
		st.ancestors.append(id)
	# the old feuds come with them; their descendants are strangers who share their blood
	for id in born:
		for q in V.people:
			if not q.alive or not q.present or q.ancestor >= 0:
				continue
			if lin.feuds.get(V.lineages[q.lineage].id, 0) >= 6:
				Village.set_opinion(V, id, q.id, -45)
			elif q.lineage == hh.lineage:
				Village.set_opinion(V, id, q.id, 20)
	V.fear = clampi(V.fear + 200, 0, 1000)
	Village.elect_authorities(V)
	var tribal_names: Array = C.LINEAGE_NAMES[C.TRIBAL]
	E.log_event(V, "arrival", father, mother, {"ancestors": born.size(), "storm": st.id}, PackedInt32Array([ev]),
		"%s of the %s, looking at the houses as if they were a dream" % [E.name_of(V, father), tribal_names[hh.lineage % tribal_names.size()]])
	return st.id


static func storm_recedes(V: S.Village, st: S.Storm) -> void:
	st.active = false
	for id in st.ancestors:
		var a := V.people[id]
		a.faded = true  # the exiled among them fade too, wherever they are
		if not a.alive or not a.present:
			continue
		a.present = false; a.locked = false
	var outlaws: Array[int] = []
	for id in V.outlaws:
		if not st.ancestors.has(id):
			outlaws.append(id)
	V.outlaws = outlaws
	# their open cases go cold: the accused are not of this world any more
	for c in V.crimes:
		if not c.closed and st.ancestors.has(c.culprit):
			c.closed = true
	var schedule: Array[S.Sched] = []
	for s in V.schedule:
		if not (st.ancestors.has(s.who) or (s.case_id >= 0 and st.ancestors.has(V.cases[s.case_id].accused))):
			schedule.append(s)
	V.schedule = schedule
	for id in st.lost:
		var p := V.people[id]
		if not p.alive:
			continue
		p.present = true; p.lost_to_storm = -1
	Village.elect_authorities(V)
	E.log_event(V, "storm", -1, -1, {"household": st.household, "phase": "recedes", "storm": st.id}, PackedInt32Array([st.event]),
		"morning mist over the %s house; the strangers gone, a ring of fire-stones on the floor, and the family home, blinking" % V.households[st.household].home)


# ---------- each day of a storm: its end, and the old gods ----------
static func storm_day(V: S.Village) -> void:
	var plan := V.storm_plan
	var i := 0
	while i < plan.size():
		if plan[i] == V.day:
			storm_hits(V, plan[i + 1], plan[i + 2])
		i += 3
	for st in V.storms:
		if not st.active:
			continue
		if V.day >= st.until:
			storm_recedes(V, st)
			continue
		rite_today(V, st)


# The forebears read the strange world as the gods' anger and answer it the old way: an offering at the
# stone. The one they fear most is seized at dusk and held overnight (the window in which kin, or the
# player, can free them); at dawn the rite is done. To the village it is murder, and it is tried as one.
static func rite_today(V: S.Village, st: S.Storm) -> void:
	if V.tier == "store":
		return  # the store build has no rites
	if st.offered:
		return  # one offering satisfies them
	for s in V.schedule:
		if s.kind == "rite":
			return
	var leader := -1
	for id in st.ancestors:
		var a := V.people[id]
		if not a.alive or not a.present or a.locked or Village.age_of(V, a) < 25:
			continue
		if leader < 0 or a.traits[C.PIETY] > V.people[leader].traits[C.PIETY]:
			leader = id
	if leader < 0:
		return
	var L := V.people[leader]
	var k := R.key(R.key(R.key(V.base, Village.P_STORM), V.day), 0x417e + st.id)
	var need := 100 + R.idiv(V.fear, 4) + R.idiv(V.hardship, 5) + L.traits[C.PIETY] - 90
	if need <= 0 or not Director.lethal_allowed(V) or not R.chance(k, need * 120 * V.pace):
		return
	# the offering: an adult of this age, not of their blood, the one they like least (never a child)
	var victim := -1
	var worst := 1000
	for q in V.people:
		if not q.alive or not q.present or q.ancestor >= 0 or q.locked or Village.age_of(V, q) < 16 or q.lineage == L.lineage or q.authored != "":
			continue
		var o := Village.opinion(V, leader, q.id) + R.pick(R.key(k, 100 + q.id), 20)
		if o < worst or (o == worst and q.id < victim):
			worst = o; victim = q.id
	if victim < 0:
		return
	var q := V.people[victim]
	q.locked = V.runtime.is_empty(); q.locked_at = Village.place_id(V, "stake")
	var ev := E.log_event(V, "rite", leader, victim, {"rite": "seized", "storm": st.id}, PackedInt32Array([st.event]),
		"%s dragged towards the stake at dusk by strangers in furs, drums starting" % E.name_of(V, victim))
	V.fear = clampi(V.fear + 150, 0, 1000)
	var s := S.Sched.new()
	s.day = V.day + 1; s.kind = "rite"; s.who = leader; s.other = victim; s.storm = st.id; s.causes = PackedInt32Array([ev])
	if not V.runtime.is_empty():
		rite_act(V, s); st.offered = true
	else:
		V.schedule.append(s)


static func rite_act(V: S.Village, s: S.Sched) -> void:
	var L := V.people[s.who]
	var q := V.people[s.other]
	if not V.runtime.is_empty() and not V.runtime.get("resolving", false):
		if not q.alive or not q.present or not L.alive or not L.present:
			return
		var pending_storm := V.storms[s.storm]
		var worshippers_pending: Array[int] = []
		for id in pending_storm.ancestors:
			if V.people[id].alive and V.people[id].present:
				worshippers_pending.append(id)
		var pending_stage := make_rite_staging(V, L.id, q.id, worshippers_pending, "pending", -1, s.causes[0])
		pending_stage.day = s.day
		pending_stage.start = -180
		pending_stage.beats[0].at = -180
		V.runtime.rites.append({"staging": pending_stage.id, "s": s.copy(), "victim": q.id, "deadline": 360})
		return
	q.locked = false
	if not q.alive or not q.present or not L.alive or not L.present:
		return
	var k := R.key(R.key(R.key(V.base, Village.P_STORM), V.day), 0x5ac + q.id)
	var st := V.storms[s.storm]
	var worshippers: Array[int] = []
	for id in st.ancestors:
		if V.people[id].alive and V.people[id].present:
			worshippers.append(id)
	# kin try to cut them free in the night (the player's window, taken by the simulation when no player is there)
	for r in V.people:
		if not r.alive or not r.present or r.ancestor >= 0 or r.id == q.id or Village.age_of(V, r) < 16 or r.lineage != q.lineage:
			continue
		var nerve := r.traits[C.BOLD] + r.traits[C.COMPASSION] - 80
		if nerve > 0 and R.chance(R.key(k, 700 + r.id), nerve * 6000):
			var rev := E.log_event(V, "rite", L.id, q.id, {"rite": "sacrifice", "outcome": "rescued", "rescuer": r.id}, s.causes,
				"ropes cut at the stake before dawn; %s and %s running for the houses" % [E.name_of(V, r.id), E.name_of(V, q.id)])
			Justice.earn(V, r.id, "rescuer")
			Village.set_opinion(V, L.id, r.id, -80)
			Justice.remember(L, r.id, rev)
			V.events[rev].data["staging"] = make_rite_staging(V, L.id, q.id, worshippers, "rescued", r.id, rev)["id"]
			return
	# the offering (only ever an adult; the heart kept for the fire in the private build, as their fathers did)
	var heart := V.tier != "store" and R.chance(R.key(k, 9), 400000)
	var ev := E.log_event(V, "rite", L.id, q.id, {"rite": "sacrifice", "outcome": "carried_out", "heart": heart}, s.causes,
		"drums at the stake before dawn, strangers painted with ash, and a still shape on the stone")
	Director.note_act(V, "sacrifice")
	st.offered = true
	var acts: Dictionary = V.stats["acts"]
	acts["sacrifice"] = acts.get("sacrifice", 0) + 1
	Village.die(V, q.id, "sacrificed", PackedInt32Array([ev]), "a still shape on the stone at dawn")
	V.events[ev].data["staging"] = make_rite_staging(V, L.id, q.id, worshippers, "carried_out", -1, ev)["id"]
	# to the village it is murder, done openly: every grown member of the dead's household saw the drums
	var c := Crime.add_crime(V, "sacrifice", L.id, q.household, q.id, 300, Village.place_id(V, "stake"), "", PackedInt32Array([ev]), "ash and blood on the stone", {"motive": "rite"})
	c.discovered = true
	c.discovery_event = ev
	var hh := V.households[q.household]
	for m in hh.members:
		var w := V.people[m]
		if not w.alive or not w.present or Village.age_of(V, w) < 14:
			continue
		Crime.give_belief(V, m, c.id, L.id, 950, m, 0, -1)
		Village.set_opinion(V, m, L.id, -90)
		Justice.remember(w, L.id, ev)
	if V.authority >= 0:
		Crime.give_belief(V, V.authority, c.id, L.id, 900, V.authority, 0, -1)
	V.fear = clampi(V.fear + 200, 0, 1000)


static func make_rite_staging(V: S.Village, leader: int, victim: int, worshippers: Array[int], outcome: String, rescuer: int, ev: int) -> Dictionary:
	var start := 300
	var beats: Array[Dictionary] = []
	Justice._beat(beats, start, victim, "lock", -1, -1, "Idle")
	var ring: Array[int] = []
	for id in worshippers:
		if id != leader and Village.age_of(V, V.people[id]) >= 14:
			ring.append(id)
	for i in ring.size():
		Justice._beat(beats, start + i, ring[i], "walk_to", i, -1, "Walk")
		Justice._beat(beats, start + 20 + i, ring[i], "stand", i, -1, "Idle_FoldArms", "torch")
	Justice._beat(beats, start, leader, "walk_to", -1, victim, "Walk_Formal")
	Justice._beat(beats, start + 30, leader, "gesture", -1, victim, "Spell_Simple_Idle")
	if outcome == "rescued":
		Justice._beat(beats, start + 10, rescuer, "walk_to", -1, victim, "Jog_Fwd")
		Justice._beat(beats, start + 14, rescuer, "release", -1, victim, "Interact")
		Justice._beat(beats, start + 15, victim, "leave", -1, -1, "Jog_Fwd")
		Justice._beat(beats, start + 16, rescuer, "leave", -1, -1, "Jog_Fwd")
	else:
		Justice._beat(beats, start + 60, victim, "fall", -1, -1, "Death01")
	# the village wakes to the drums: the nearest dozen come, and stand back appalled (outer slots, after the ring)
	var onlookers: Array[int] = []
	for p in V.people:
		if onlookers.size() < 12 and p.alive and p.present and p.ancestor < 0 and p.id != victim and p.id != rescuer and Village.age_of(V, p) >= 14:
			onlookers.append(p.id)   # (people are in id order: the reference's sort and slice)
	for i in onlookers.size():
		Justice._beat(beats, start + 15 + i, onlookers[i], "walk_to", ring.size() + i, -1, "Jog_Fwd")
		Justice._beat(beats, start + 35 + i, onlookers[i], "stand", ring.size() + i, -1, "Idle_No")
	var end := start + 90
	for i in ring.size():
		Justice._beat(beats, end + i, ring[i], "leave", -1, -1, "Walk")
	for i in onlookers.size():
		Justice._beat(beats, end + 5 + i, onlookers[i], "leave", -1, -1, "Walk")
	Justice._beat(beats, end, leader, "leave", -1, -1, "Walk")
	Justice._sort_beats(beats)
	# (not de-duplicated, as in the reference)
	var ids: Array[int] = [victim, leader]
	ids.append_array(ring)
	ids.append_array(onlookers)
	if rescuer >= 0:
		ids.append(rescuer)
	var people := []
	for id in ids:
		people.append(Justice.person_entry(V, id))
	var cue := V.events[ev].cue
	var staging := {
		"id": V.staging_count, "kind": "sacrifice", "place": "stake", "start": start, "end": end + ring.size() + onlookers.size() + 10,
		"phases": [{"name": "night", "from": start - 480, "to": start, "rescue": true}, {"name": "rite", "from": start, "to": start + 60, "rescue": true},
			{"name": "end", "from": start + 60, "to": end + ring.size() + onlookers.size() + 10, "rescue": false}],
		"roles": {"victim": victim, "accuser": leader, "authority": leader, "crowd": ring + onlookers},
		"beats": beats, "outcome": outcome, "cause": ["rite: %s" % cue], "cue": cue, "day": V.day, "people": people,
	}
	V.staging_count += 1
	V.stagings.append(staging)
	if V.stagings.size() > 300:
		V.stagings.remove_at(0)
	return staging
