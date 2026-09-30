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
const Incidents := preload("res://scripts/studio/village/sim/incidents.gd")
const WorldActions := preload("res://scripts/studio/village/sim/world_actions.gd")

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
		"hearings": [], "rites": [], "traces": [], "resolving": false, "challenge": false, "storm_cycle": 0,
		"day_open": false, "incidents": [], "player": {"present": false, "x": 0, "z": 0}, "quiet_since": v.day * 1440,
		"acquaintance": {}}
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
	all.append_array(r.get("incidents", []))
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
		# The first irreversible ending owns the decision boundary, including a crowd release.
		deadline = int(st.end)
		for phase: Dictionary in st.phases:
			if phase.name == "end":
				deadline = mini(deadline, int(phase.from))
		for beat: Dictionary in st.beats:
			if (int(beat.who) == int(a.victim) and beat["do"] in ["fall", "leave"]) or (beat["do"] == "release" and int(beat.target) == int(a.victim)):
				deadline = mini(deadline, int(beat.at))
		if a is Dictionary and r.get("incidents", []).has(a):
			type = "incident"   # shown, then over: no decision window
			deadline = int(st.end)
		elif a is Dictionary:
			type = "hearing" if r.hearings.has(a) else "rite"
			deadline = int(a.deadline)
		var raw_crowd: Array = a.attend.duplicate() if type == "public" else st.roles.get("crowd", []).duplicate()
		if type == "incident":
			raw_crowd = a.actors.duplicate()
		var crowd: Array[int] = []
		for witness: int in raw_crowd:
			if witness >= 0 and not crowd.has(witness):
				crowd.append(witness)
		var accuser := int(st.roles.get("accuser", -1))
		if accuser >= 0 and not crowd.has(accuser):
			crowd.append(accuser)
		var actors: Array[int] = []
		for actor: int in ([int(a.victim), int(st.roles.get("authority", -1)), int(st.roles.get("accuser", -1))] if type != "incident" else a.actors):
			if actor >= 0 and not actors.has(actor):
				actors.append(actor)
		var source: Variant = null if type in ["public", "incident"] else a.s
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
		if type == "public":
			st.phases = [{"name": "intervene", "from": int(e.from) - int(st.day) * 1440, "to": int(e.deadline) - int(st.day) * 1440, "rescue": true},
				{"name": "end", "from": int(e.deadline) - int(st.day) * 1440, "to": st.end, "rescue": false}]

static func advance(v: S.Village, target: int) -> void:
	var r := v.runtime
	assert(target >= int(r.now), "clock must advance monotonically")
	_migrate(v)
	while true:
		sync_events(v)
		var due := {}
		for e: Dictionary in r.events:
			if not terminal(e) and (due.is_empty() or e.deadline < due.deadline or (e.deadline == due.deadline and e.id < due.id)):
				due = e
		var never := 9223372036854775807
		# the day opens at its midnight; while it is open, its phases run at their minutes (village.gd begin_day)
		var dawn := never if r.day_open else v.day * 1440
		var phase_at := never
		if r.day_open and Village.next_phase_at(v) >= 0:
			phase_at = v.day * 1440 + Village.next_phase_at(v)
		var trace_at := never
		for trace: Dictionary in r.traces:
			if not trace.discovered:
				trace_at = mini(trace_at, int(trace.discover_at))
		var opening := {}
		for event: Dictionary in r.events:
			if event.phase == "prepared" and (opening.is_empty() or event.from < opening.from or (event.from == opening.from and event.id < opening.id)):
				opening = event
		var opening_at := int(opening.from) if not opening.is_empty() else never
		var due_at := int(due.deadline) if not due.is_empty() else never
		var next := mini(mini(dawn, phase_at), mini(due_at, mini(trace_at, opening_at)))
		if next > target:
			break
		r.now = maxi(int(r.now), next)
		if not opening.is_empty() and opening_at == next:
			activate(v, opening)
		elif trace_at == next:
			discover_traces(v)
		elif not due.is_empty() and due_at == next:
			resolve(v, due)
		elif phase_at == next:
			var ran := Village.run_phase(v)
			if ran.kind == "incident":
				Incidents.show(v, ran.intent, ran.result)
			elif ran.kind == "end":
				r.day_open = false
		else:
			Village.begin_day(v)
			r.day_open = true
		sync_events(v)
		discover_traces(v)
		for e: Dictionary in r.events:
			if not terminal(e) and not valid_participants(v, e):
				cancel(v, e, "participant unavailable")
	r.now = target
	for e: Dictionary in r.events:
		if terminal(e):
			continue
		if not valid_participants(v, e):
			cancel(v, e, "participant unavailable")
		elif target >= int(e.from):
			activate(v, e)
	r.events = r.events.filter(func(e: Dictionary) -> bool: return not terminal(e) or int(e.end) > target - 7 * 1440)


## Older saves ran the day at once at its midnight (the day number then already pointed at tomorrow); from their
## next midnight they run phased. Adds the fields later passes introduced.
static func _migrate(v: S.Village) -> void:
	var r := v.runtime
	if not r.has("day_open"):
		r.day_open = false
	for key: String in ["incidents"]:
		if not r.has(key):
			r[key] = []
	if not r.has("player"):
		r.player = {"present": false, "x": 0, "z": 0}
	if not r.has("quiet_since"):
		r.quiet_since = int(r.now)
	if not r.has("acquaintance"):
		r.acquaintance = {}


## The next midnight (when the next day opens): for waiting until "tomorrow".
static func next_dawn(v: S.Village) -> int:
	return (v.day + 1) * 1440 if v.runtime.get("day_open", false) else v.day * 1440


## The live village tells the rules where the player is (decimetres, the village's own frame) and whether they are
## in the village at all. Their eyes count at the moment a deed is done (crime.gd player_sees).
static func set_player(v: S.Village, present: bool, x_dm: int, z_dm: int) -> void:
	var pl: Dictionary = v.runtime.get_or_add("player", {"present": false, "x": 0, "z": 0})
	if present and not pl.get("present", false):
		v.runtime.quiet_since = int(v.runtime.now)   # arriving is not the moment for something to happen at once
	pl.present = present
	pl.x = x_dm
	pl.z = z_dm

static func resolve(v: S.Village, e: Dictionary) -> void:
	if e.type == "incident":
		e.phase = "resolved"; e.outcome = "done"; e.revision += 1
		v.runtime.incidents = v.runtime.incidents.filter(func(a: Dictionary) -> bool: return int(a.staging) != int(e.id))
		return
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
		Village.plan_day(v)
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
	p.locked_at = -1
	Village.plan_day(v)

static func cancel(v: S.Village, e: Dictionary, reason: String) -> void:
	v.pending = v.pending.filter(func(a: S.PublicAct) -> bool: return a.staging != int(e.id))
	v.runtime.hearings = v.runtime.hearings.filter(func(a: Dictionary) -> bool: return int(a.staging) != int(e.id))
	v.runtime.rites = v.runtime.rites.filter(func(a: Dictionary) -> bool: return int(a.staging) != int(e.id))
	if v.runtime.has("incidents"):
		v.runtime.incidents = v.runtime.incidents.filter(func(a: Dictionary) -> bool: return int(a.staging) != int(e.id))
	e.phase = "cancelled"; e.outcome = reason; e.revision += 1
	if e.type != "incident":
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
	if v.runtime.get("player", {}).get("present", false):
		v.runtime.quiet_since = int(v.runtime.now)
	if e.type != "hearing" and e.type != "incident":
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
	if not valid_participants(v, e):
		cancel(v, e, "participant unavailable")
		return fail("participant unavailable")
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
			return fail("Their words are unfamiliar; use gestures.", "unfamiliar_words")
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
			return fail("I did not see it.", "did_not_see")
		var clue := {"crime": belief.crime, "culprit": belief.culprit, "origin": belief.origin,
			"strength": belief.strength, "via": "retelling", "speaker": speaker.id}
		if not has_clue(player.knowledge, clue, true):
			player.knowledge.append(clue)
		if player.knowledge.size() > 32:
			player.knowledge = player.knowledge.slice(-32)
		return accept(r, e, request, "heard", {"clue": clue, "code": "heard"})
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
		return accept(r, e, request, "found a trace", {"clue": clue, "code": "found_trace"})
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
		WorldActions.remember(v, judge_id, "you_testified")
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
			("That supports the accusation." if clue.culprit == cs.accused else "That casts doubt on the accusation."),
			{"code": "testimony_known" if known else ("testimony_supports" if clue.culprit == cs.accused else "testimony_doubts")})
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
			WorldActions.remember(v, judge_id, "you_offered_coins", 5)
		else:
			WorldActions.remember(v, judge_id, "you_offered_coins", -30 if judge.traits[C.HONESTY] >= 70 else -10)
		e.revision += 1
		return accept(r, e, request, "I will weigh your request." if e.bribe == "accepted" else "Keep your coins. This is a hearing.",
			{"coins": 5 if e.bribe == "accepted" else 0, "code": "bribe_accepted" if e.bribe == "accepted" else "bribe_refused"})
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
		return accept(r, e, request, "Someone saw you leave the marked wood." if not observers.is_empty() else "Marked wood left by the door.",
			{"wood": 1, "code": "plant_seen" if not observers.is_empty() else "plant_unseen"})
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
		e.shields.append(beat_id)
		WorldActions.remember(v, p.id, "you_shielded", 15)
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
		return accept(r, e, request, "intercepted one throw", {"damage": 1 if beat.get("prop", "") == "stone" else 0, "code": "shielded"})
	var ritual_offer := false
	if verb == "offer":
		if e.type != "rite" or not str(e.bribe).is_empty():
			return fail("offering already decided")
		if int(context.get("wood", 0)) < 1:
			return fail("requires 1 wood")
		var leader := v.people[e.source.who]
		e.bribe = "offered"; ritual_offer = true
		if leader.traits[C.COMPASSION] + leader.values[C.V_MERCY] < 105:
			return accept(r, e, request, "They turn back to the fire.", {"wood": 1, "code": "offer_refused"})
	if (not ritual_offer and verb != "free") or e.type == "hearing":
		return fail("unknown action")
	if e.type == "rite":
		var leader := v.people[e.source.who]
		var ev := Events.log_event(v, "rite", leader.id, p.id,
			{"rite": "sacrifice", "outcome": "rescued", "by": request.player_id}, e.source.causes,
			"the rope cut; the captive running towards refuge")
		if not ritual_offer:
			Justice.remember(leader, -2, ev)
			WorldActions.remember(v, leader.id, "angered", -50)
		r.rites = r.rites.filter(func(a: Dictionary) -> bool: return int(a.staging) != int(e.id))
	else:
		var pending: S.PublicAct = null
		for a in v.pending:
			if a.staging == e.id:
				pending = a; break
		Justice.resolve_public(v, int(e.id), "free")
		for actor: int in e.actors:
			if actor != p.id:
				WorldActions.remember(v, actor, "angered", -40)
	p.present = true; p.locked = false; p.locked_at = -1
	v.outlaws.erase(p.id)
	v.schedule = v.schedule.filter(func(s: S.Sched) -> bool:
		return not ((s.kind == "return" and s.who == p.id) or
			(s.case_id >= 0 and v.cases[s.case_id].accused == p.id)))
	r.residents[str(p.id)] = {"refuge_until": int(r.now) + 2880, "rescued_by": request.player_id, "destination": "far_woods", "departed": r.now, "from": e.place}
	WorldActions.remember(v, p.id, "freed_by_you", 60)
	for other: Dictionary in r.events:
		if other.id != e.id and other.victim == p.id and not terminal(other):
			cancel(v, other, "rescued")
	e.phase = "resolved"; e.outcome = "spared" if ritual_offer else "rescued"; e.revision += 1
	Village.plan_day(v)
	return accept(r, e, request, e.outcome, {"wood": 1, "code": "spared"} if ritual_offer else {"code": "rescued"})

## Results carry a stable `code` beside the words (presentation keys its lines on the code, never the prose).
static func fail(reason: String, code: String = "") -> Dictionary:
	return {"accepted": false, "reason": reason, "code": code if not code.is_empty() else reason.to_snake_case().replace(" ", "_")}

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

static func routine(v: S.Village, id: int) -> Dictionary:
	var p := v.people[id]
	var now := int(v.runtime.now)
	var memory: Dictionary = v.runtime.residents.get(str(id), {})
	if int(memory.get("refuge_until", 0)) > now:
		var start := int(memory.get("departed", now - 120))
		return {"from": memory.get("from", memory.destination), "place": memory.destination, "start": start, "end": start + 120}
	var minute := now % 1440
	for i in range(0, p.plan.size(), 3):
		if minute < p.plan[i] or minute >= p.plan[i + 1]:
			continue
		var place := p.plan[i + 2]
		var origin := p.plan[i - 1] if i > 0 else place
		var start := now - minute + p.plan[i]
		return {"from": v.place_names[origin], "place": v.place_names[place], "start": start,
			"end": start + (mini(90, (p.plan[i + 1] - p.plan[i]) / 2) if origin != place else 0)}
	return {"from": "", "place": "", "start": now, "end": now}

static func settled_at(v: S.Village, p: S.Person, place: String) -> bool:
	var trip := routine(v, p.id)
	if trip.place != place or int(trip.end) > int(v.runtime.now):
		return false
	for e: Dictionary in v.runtime.events:
		if e.phase == "cancelled" or int(e.from) > int(v.runtime.now) or int(e.end) <= int(v.runtime.now):
			continue
		for person: Dictionary in staging(v, int(e.id)).get("people", []):
			if int(person.id) == p.id:
				return false
	return true

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
			if person.alive and person.present and person.id != t.culprit and Village.age_of(v, person) >= 14 and settled_at(v, person, t.place):
				finder = person.id; break
		if finder < 0:
			t.discover_at = int(r.now) + 15; continue
		t.discovered = true
		if not t.observers.is_empty():
			for observer: int in t.observers:
				WorldActions.remember(v, observer, "saw_you_plant", -30)
		else:
			Crime.give_belief(v, finder, t.crime, t.culprit, 350, t.origin, 0, -1)
