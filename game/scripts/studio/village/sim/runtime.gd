extends RefCounted
## The authority for game minutes and accepted village actions. No nodes or render timers.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")
const Storm := preload("res://scripts/studio/village/sim/storm.gd")
const Bridge := preload("res://scripts/studio/village/sim/storm_bridge.gd")
const Crime := preload("res://scripts/studio/village/sim/crime.gd")
const Events := preload("res://scripts/studio/village/sim/events.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")

static func create(seed: int = 1, opts: Dictionary = {}) -> S.Village:
	var settings := {"pace": 10, "focus": true, "live": true}
	settings.merge(opts, true)
	var v := Village.create_village(seed, settings)
	attach(v)
	return v

static func attach(v: S.Village, minute: int = 432) -> void:
	if not v.runtime.is_empty():
		return
	v.live = true
	v.runtime = {"version": 1, "village": "wenbrook:%d" % v.seed, "now": v.day * 1440,
		"events": [], "receipts": {}, "sequence": 0, "residents": {}, "players": {}, "fraction": 0.0,
		"hearings": [], "rites": [], "traces": [], "resolving": false, "challenge": false, "storm_cycle": 0}
	advance(v, v.day * 1440 + minute)

static func terminal(e: Dictionary) -> bool:
	return e.phase in ["resolved", "cancelled"]

static func event_by_id(v: S.Village, id: int) -> Dictionary:
	for e: Dictionary in v.runtime.events:
		if int(e.id) == id:
			return e
	return {}

static func staging(v: S.Village, id: int) -> Dictionary:
	for st in v.stagings:
		if int(st.id) == id:
			return st
	return {}

static func sync_events(v: S.Village) -> void:
	var r := v.runtime
	var all: Array = []
	all.append_array(v.pending)
	all.append_array(r.hearings)
	all.append_array(r.rites)
	for a in all:
		var staging_id: int = a.staging
		if not event_by_id(v, staging_id).is_empty():
			continue
		var st := staging(v, staging_id)
		assert(not st.is_empty(), "pending act without staging")
		var first := int(st.start)
		var deadline := -2147483648
		for p: Dictionary in st.phases:
			if p.rescue:
				first = mini(first, int(p.from))
				deadline = maxi(deadline, int(p.to))
		if deadline == -2147483648:
			deadline = int(st.end)
		var type := "public"
		if a is Dictionary:
			type = "hearing" if r.hearings.has(a) else "rite"
			deadline = int(a.deadline)
		var raw_crowd: Array = a.attend.duplicate() if type == "public" else st.roles.get("crowd", []).duplicate()
		var crowd: Array[int] = []
		for witness: int in raw_crowd:
			if witness >= 0 and not crowd.has(witness):
				crowd.append(witness)
		var accuser := int(st.roles.get("accuser", -1))
		if accuser >= 0 and not crowd.has(accuser):
			crowd.append(accuser)
		var actors: Array[int] = []
		for actor: int in [int(a.victim), int(st.roles.get("authority", -1)), int(st.roles.get("accuser", -1))]:
			if actor >= 0 and not actors.has(actor):
				actors.append(actor)
		var source: Variant = null if type == "public" else a.s
		var e := {"id": st.id, "revision": 0, "type": type, "victim": a.victim, "place": st.place,
			"from": int(st.day) * 1440 + first, "deadline": int(st.day) * 1440 + deadline,
			"end": int(st.day) * 1440 + int(st.end), "phase": "prepared", "outcome": "", "shields": [],
			"witnesses": crowd, "actors": actors, "testimony": [], "bribe": "", "challenge": 0, "source": source}
		for prior: Dictionary in v.runtime.events:
			if terminal(prior) or prior.end <= e.from:
				continue
			var shared_actor := false
			for actor in prior.actors:
				if actors.has(actor):
					shared_actor = true; break
			if prior.place != e.place and not shared_actor:
				continue
			var shift := int(prior.end) + 5 - int(e.from)
			e.from += shift; e.deadline += shift; e.end += shift
			st.start += shift; st.end += shift
			for p: Dictionary in st.phases:
				p.from += shift; p.to += shift
			for b: Dictionary in st.beats:
				b.at += shift
		v.runtime.events.append(e)

static func advance(v: S.Village, target: int) -> void:
	var r := v.runtime
	assert(target >= int(r.now), "clock must advance monotonically")
	while true:
		sync_events(v)
		var due := {}
		for e: Dictionary in r.events:
			if not terminal(e) and (due.is_empty() or e.deadline < due.deadline or (e.deadline == due.deadline and e.id < due.id)):
				due = e
		var dawn := v.day * 1440
		var trace_at := 9223372036854775807
		for trace: Dictionary in r.traces:
			if not trace.discovered:
				trace_at = mini(trace_at, int(trace.discover_at))
		var opening := {}
		for event: Dictionary in r.events:
			if event.phase == "prepared" and (opening.is_empty() or event.from < opening.from or (event.from == opening.from and event.id < opening.id)):
				opening = event
		var opening_at := int(opening.from) if not opening.is_empty() else 9223372036854775807
		var next := mini(mini(dawn, int(due.deadline) if not due.is_empty() else 9223372036854775807), mini(trace_at, opening_at))
		if next > target:
			break
		r.now = maxi(int(r.now), next)
		if not opening.is_empty() and opening_at == next:
			activate(v, opening)
		elif trace_at <= dawn and (due.is_empty() or trace_at <= int(due.deadline)):
			discover_traces(v)
		elif not due.is_empty() and int(due.deadline) <= dawn:
			resolve(v, due)
		else:
			Village.step_day(v)
			sync_events(v)
			if not v.anchored and v.day >= int(r.storm_cycle) + 4:
				r.storm_cycle = v.day
				var eligible: Array[int] = []
				for h in v.households:
					if h.home in ["round", "hill"]:
						eligible.append(h.id)
				var cycle := v.day / 4
				var transition := Bridge.transition(v.seed, cycle)
				if not eligible.is_empty() and not transition.is_empty():
					var sid := Storm.storm_hits(v, eligible[(cycle - 1) % eligible.size()], 3)
					if sid >= 0:
						v.storms[sid].kernel = transition
		discover_traces(v)
	r.now = target
	for e: Dictionary in r.events:
		if terminal(e):
			continue
		var p := v.people[int(e.victim)]
		if not valid_participants(v, e):
			cancel(v, e, "participant unavailable")
		elif target >= int(e.from):
			activate(v, e)
	r.events = r.events.filter(func(e: Dictionary) -> bool: return not terminal(e) or int(e.end) > target - 7 * 1440)

static func resolve(v: S.Village, e: Dictionary) -> void:
	var p := v.people[int(e.victim)]
	if not valid_participants(v, e):
		cancel(v, e, "participant unavailable")
		return
	if e.type == "hearing":
		v.runtime.resolving = true; v.runtime.challenge = int(e.challenge) >= 700
		var before := v.staging_count
		Justice.trial(v, e.source)
		v.runtime.resolving = false; v.runtime.challenge = false
		var realized := staging(v, before)
		e.outcome = realized.get("verdict", "dismissed")
		e.phase = "resolved"; e.revision += 1
		v.runtime.hearings = v.runtime.hearings.filter(func(a: Dictionary) -> bool: return int(a.staging) != int(e.id))
		return
	if e.type == "rite":
		v.runtime.resolving = true
		Storm.rite_act(v, e.source)
		v.runtime.resolving = false
		v.runtime.rites = v.runtime.rites.filter(func(a: Dictionary) -> bool: return int(a.staging) != int(e.id))
	else:
		Justice.resolve_public(v, int(e.id))
	p.locked = false
	e.phase = "resolved"; e.revision += 1
	e.outcome = ("released" if p.present else "exiled") if p.alive else "died"

static func cancel(v: S.Village, e: Dictionary, reason: String) -> void:
	v.pending = v.pending.filter(func(a: S.PublicAct) -> bool: return a.staging != int(e.id))
	v.runtime.hearings = v.runtime.hearings.filter(func(a: Dictionary) -> bool: return int(a.staging) != int(e.id))
	v.runtime.rites = v.runtime.rites.filter(func(a: Dictionary) -> bool: return int(a.staging) != int(e.id))
	e.phase = "cancelled"; e.outcome = reason; e.revision += 1
	v.people[int(e.victim)].locked = false

static func valid_participants(v: S.Village, e: Dictionary) -> bool:
	for actor: int in e.actors:
		if actor < 0 or actor >= v.people.size() or not v.people[actor].alive or not v.people[actor].present:
			return false
	if e.type == "rite":
		var sid: int = e.source.storm
		if sid < 0 or sid >= v.storms.size() or not v.storms[sid].active or int(v.runtime.now) >= v.storms[sid].until * 1440:
			return false
	return true

static func activate(v: S.Village, e: Dictionary) -> void:
	if not valid_participants(v, e):
		cancel(v, e, "participant unavailable")
		return
	e.phase = "active"
	if e.type != "hearing":
		var p := v.people[int(e.victim)]
		p.locked = true; p.locked_at = v.place_ids.get(e.place, -1)

static func act(v: S.Village, request: Dictionary, context: Dictionary) -> Dictionary:
	var r := v.runtime
	var id: String = request.get("action_id", "")
	if id.is_empty() or id.length() > 120:
		return fail("invalid action")
	if r.receipts.has(id):
		var old: Dictionary = r.receipts[id].duplicate(true)
		old.duplicate = true
		return old
	if request.get("village_id") != r.village or request.get("player_id") != "player:local" or request.get("logical_time") != r.now:
		return fail("stale context")
	var e := event_by_id(v, int(request.get("event_id", -1)))
	if e.is_empty() or terminal(e) or r.now < e.from or r.now >= e.deadline:
		return fail("window closed")
	var p := v.people[int(e.victim)]
	var verb: String = request.get("verb", "")
	var distance := float(context.get("distance_dm", INF))
	if not p.alive or not p.present or distance < 0 or distance > (100.0 if verb == "shield" else 25.0) or is_inf(distance) or is_nan(distance):
		return fail("out of reach")
	var params: Dictionary = request.get("parameters", {})
	var player: Dictionary = r.players.get(request.player_id, {})
	if player.is_empty():
		player = {"knowledge": [], "standing": 0, "enemies": []}
		r.players[request.player_id] = player
	if verb == "listen":
		var speaker_id := int(params.get("speaker", -1))
		if speaker_id < 0 or speaker_id >= v.people.size():
			return fail("no witness here")
		var speaker := v.people[speaker_id]
		if not speaker.alive or not speaker.present or not e.witnesses.has(speaker_id):
			return fail("no witness here")
		if v.lang[v.age * 3 + speaker.era] >= 60:
			return fail("Their words are unfamiliar; use gestures.")
		var case_id := -1
		if e.type == "hearing":
			case_id = e.source.case_id
		else:
			for a in v.pending:
				if a.staging == e.id:
					case_id = a.cs; break
		if case_id < 0:
			return fail("no testimony")
		var crime_id := v.cases[case_id].crime
		var belief: S.Belief = null
		for b in speaker.beliefs:
			if b.crime == crime_id and (belief == null or b.strength > belief.strength):
				belief = b
		if belief == null:
			return fail("I did not see it.")
		var clue := {"crime": belief.crime, "culprit": belief.culprit, "origin": belief.origin,
			"strength": belief.strength, "via": "retelling", "speaker": speaker.id}
		if not has_clue(player.knowledge, clue, true):
			player.knowledge.append(clue)
		if player.knowledge.size() > 32:
			player.knowledge = player.knowledge.slice(-32)
		return accept(r, e, request, "heard", {"clue": clue})
	if verb == "inspect":
		if e.type != "hearing":
			return fail("no open case")
		var cs := v.cases[e.source.case_id]
		var crime := v.crimes[cs.crime]
		if crime.trace_at < 0 or params.get("place") != v.place_names[crime.trace_at]:
			return fail("no trace here")
		var clue := {"crime": crime.id, "culprit": crime.culprit, "origin": 1000000 + crime.id,
			"strength": 800, "via": "trace", "speaker": -1}
		if not has_clue(player.knowledge, clue):
			player.knowledge.append(clue)
		return accept(r, e, request, "found a trace", {"clue": clue})
	if verb == "testify":
		if e.type != "hearing":
			return fail("hearing closed")
		var cs := v.cases[e.source.case_id]
		var clue := {}
		for known_clue: Dictionary in player.knowledge:
			if int(known_clue.crime) == cs.crime and int(known_clue.origin) == int(params.get("origin", -1)):
				clue = known_clue; break
		if clue.is_empty():
			return fail("no evidence to offer")
		if e.testimony.has(clue.origin):
			return fail("already heard this source")
		e.testimony.append(clue.origin)
		var judge_id := int(staging(v, e.id).roles.get("authority", -1))
		if judge_id < 0 or not v.people[judge_id].alive or not v.people[judge_id].present:
			return fail("no judge")
		var known := false
		for b in v.people[judge_id].beliefs:
			if b.crime == cs.crime and b.origin == clue.origin and b.culprit == clue.culprit:
				known = true; break
		Crime.give_belief(v, judge_id, cs.crime, clue.culprit, clue.strength, clue.origin, 1, -2)
		if not known:
			if clue.culprit == cs.accused:
				cs.evidence += int(clue.strength) / 2
			else:
				cs.evidence = maxi(0, cs.evidence - int(clue.strength)); e.challenge += clue.strength
		e.revision += 1
		return accept(r, e, request, "We already heard that account." if known else
			("That supports the accusation." if clue.culprit == cs.accused else "That casts doubt on the accusation."))
	if verb == "bribe":
		if e.type != "hearing" or not str(e.bribe).is_empty():
			return fail("offer already decided")
		if int(context.get("coins", 0)) < 5:
			return fail("requires 5 coins")
		var judge_id := int(staging(v, e.id).roles.get("authority", -1))
		if judge_id < 0 or not v.people[judge_id].alive or not v.people[judge_id].present:
			return fail("no judge")
		var judge := v.people[judge_id]
		e.bribe = "accepted" if judge.traits[C.GREED] > judge.traits[C.HONESTY] and judge.values[C.V_LAW] < 75 else "refused"
		if e.bribe == "accepted":
			var cs := v.cases[e.source.case_id]
			cs.evidence = maxi(0, cs.evidence - 350)
		else:
			player.standing -= 5
			if judge.traits[C.HONESTY] >= 70 and not player.enemies.has(judge_id):
				player.enemies.append(judge_id)
		e.revision += 1
		return accept(r, e, request, "I will weigh your request." if e.bribe == "accepted" else "Keep your coins. This is a hearing.",
			{"coins": 5 if e.bribe == "accepted" else 0})
	if verb == "plant":
		if e.type != "hearing":
			return fail("trace already placed")
		for t: Dictionary in r.traces:
			if t.event == e.id:
				return fail("trace already placed")
		if int(context.get("wood", 0)) < 1:
			return fail("requires 1 wood")
		var home := v.households[p.household].home
		if params.get("place") != home:
			return fail("not at their doorstep")
		var observers: Array[int] = []
		for observer: int in context.get("witnesses", []):
			if observer >= 0 and observer < v.people.size() and v.people[observer].alive and v.people[observer].present:
				observers.append(observer)
		r.traces.append({"event": e.id, "crime": v.cases[e.source.case_id].crime, "culprit": p.id,
			"place": home, "origin": 3000000 + int(e.id), "discover_at": int(r.now) + 15,
			"observers": observers, "discovered": false, "planted_by": request.player_id})
		return accept(r, e, request, "Someone saw you leave the marked wood." if not observers.is_empty() else "Marked wood left by the door.", {"wood": 1})
	if verb == "shield":
		var beat_id: Variant = params.get("beat")
		if e.type != "public" or not (beat_id is int) or e.shields.has(beat_id):
			return fail("contact already resolved")
		var st := staging(v, e.id)
		if beat_id < 0 or beat_id >= st.beats.size():
			return fail("no contact")
		var beat: Dictionary = st.beats[beat_id]
		if beat["do"] != "throw" or not context.get("intercepted", false) or int(r.now) < int(st.day) * 1440 + int(beat.at):
			return fail("no contact")
		e.shields.append(beat_id); player.standing += 2
		var pending: S.PublicAct = null
		for a in v.pending:
			if a.staging == e.id:
				pending = a; break
		var stones: Array[int] = []
		for i in st.beats.size():
			if st.beats[i]["do"] == "throw" and st.beats[i].get("prop", "") == "stone":
				stones.append(i)
		if pending != null and pending.lethal_by_stones and not stones.is_empty():
			var all_shielded := true
			for i in stones:
				if not e.shields.has(i):
					all_shielded = false; break
			if all_shielded:
				pending.lethal_by_stones = false
		return accept(r, e, request, "intercepted one throw", {"damage": 1 if beat.get("prop", "") == "stone" else 0})
	var ritual_offer := false
	if verb == "offer":
		if e.type != "rite" or not str(e.bribe).is_empty():
			return fail("offering already decided")
		if int(context.get("wood", 0)) < 1:
			return fail("requires 1 wood")
		var leader := v.people[e.source.who]
		e.bribe = "offered"; ritual_offer = true
		if leader.traits[C.COMPASSION] + leader.values[C.V_MERCY] < 105:
			return accept(r, e, request, "They turn back to the fire.", {"wood": 1})
	if (not ritual_offer and verb != "free") or e.type == "hearing":
		return fail("unknown action")
	if e.type == "rite":
		var leader := v.people[e.source.who]
		var ev := Events.log_event(v, "rite", leader.id, p.id,
			{"rite": "sacrifice", "outcome": "rescued", "by": request.player_id}, e.source.causes,
			"the rope cut; the captive running towards refuge")
		if not ritual_offer:
			Justice.remember(leader, -2, ev); player.enemies.append(leader.id)
		r.rites = r.rites.filter(func(a: Dictionary) -> bool: return int(a.staging) != int(e.id))
	else:
		var pending: S.PublicAct = null
		for a in v.pending:
			if a.staging == e.id:
				pending = a; break
		Justice.resolve_public(v, int(e.id), "free")
		player.standing -= int(C.PUBLIC[pending.kind]["shame"]) * 10
		for actor: int in e.actors:
			if actor != p.id and not player.enemies.has(actor):
				player.enemies.append(actor)
	p.present = true; p.locked = false; p.locked_at = -1
	v.outlaws.erase(p.id)
	v.schedule = v.schedule.filter(func(s: S.Sched) -> bool:
		return not ((s.kind == "return" and s.who == p.id) or
			(s.case_id >= 0 and v.cases[s.case_id].accused == p.id)))
	r.residents[str(p.id)] = {"refuge_until": int(r.now) + 2880, "rescued_by": request.player_id, "destination": "far_woods"}
	for other: Dictionary in r.events:
		if other.id != e.id and other.victim == p.id and not terminal(other):
			cancel(v, other, "rescued")
	e.phase = "resolved"; e.outcome = "spared" if ritual_offer else "rescued"; e.revision += 1
	Village.plan_day(v)
	return accept(r, e, request, e.outcome, {"wood": 1} if ritual_offer else {})

static func fail(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}

static func accept(r: Dictionary, e: Dictionary, request: Dictionary, outcome: String, costs: Dictionary = {}) -> Dictionary:
	var id: String = request.action_id
	var receipt := {"accepted": true, "action_id": id, "event_id": e.id, "verb": request.verb,
		"at": r.now, "outcome": outcome, "revision": e.revision, "player": request.player_id}
	receipt.merge(costs, true)
	r.receipts[id] = receipt; r.sequence += 1
	if r.receipts.size() > 256:
		r.receipts.erase(r.receipts.keys()[0])
	return receipt

static func has_clue(knowledge: Array, clue: Dictionary, compare_culprit: bool = false) -> bool:
	for known: Dictionary in knowledge:
		if known.crime == clue.crime and known.origin == clue.origin and (not compare_culprit or known.culprit == clue.culprit):
			return true
	return false

static func discover_traces(v: S.Village) -> void:
	var r := v.runtime
	for t: Dictionary in r.traces:
		if t.discovered or int(t.discover_at) > int(r.now):
			continue
		var e := event_by_id(v, int(t.event))
		if e.is_empty() or terminal(e):
			t.discovered = true; continue
		var finder := -1
		var target_place: int = v.place_ids.get(t.place, -1)
		for person in v.people:
			if person.alive and person.present and person.id != t.culprit and Village.age_of(v, person) >= 14 and Village.place_at(person, int(r.now) % 1440) == target_place:
				finder = person.id; break
		if finder < 0:
			t.discover_at = int(r.now) + 15; continue
		t.discovered = true
		if not t.observers.is_empty():
			var player: Dictionary = r.players[t.planted_by]
			player.standing -= 10
			for observer: int in t.observers:
				if not player.enemies.has(observer):
					player.enemies.append(observer)
		else:
			Crime.give_belief(v, finder, t.crime, t.culprit, 350, t.origin, 0, -1)
