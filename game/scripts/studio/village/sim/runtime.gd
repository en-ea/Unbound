extends RefCounted
## The authority for game minutes and accepted village actions. No nodes or render timers.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")

static func create(seed: int = 16838) -> S.Village:
	var v := Village.create_village(seed, {"pace": 10, "focus": true, "live": true})
	attach(v)
	return v

static func attach(v: S.Village, minute: int = 432) -> void:
	if not v.runtime.is_empty():
		return
	v.live = true
	v.runtime = {"version": 1, "village": "wenbrook:%d" % v.seed, "now": v.day * 1440,
		"events": [], "receipts": {}, "sequence": 0, "residents": {}, "players": {}, "fraction": 0.0}
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
	for a in v.pending:
		if not event_by_id(v, a.staging).is_empty():
			continue
		var st := staging(v, a.staging)
		assert(not st.is_empty(), "pending act without staging")
		var first := int(st.start)
		var deadline := -2147483648
		for p: Dictionary in st.phases:
			if p.rescue:
				first = mini(first, int(p.from))
				deadline = maxi(deadline, int(p.to))
		if deadline == -2147483648:
			deadline = int(st.end)
		var e := {"id": st.id, "revision": 0, "type": "public", "victim": a.victim, "place": st.place,
			"from": int(st.day) * 1440 + first, "deadline": int(st.day) * 1440 + deadline,
			"end": int(st.day) * 1440 + int(st.end), "phase": "prepared", "outcome": "", "shields": [], "witnesses": a.attend.duplicate()}
		for prior: Dictionary in v.runtime.events:
			if terminal(prior) or prior.end <= e.from or (prior.victim != e.victim and prior.place != e.place):
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
		var next := mini(dawn, int(due.deadline) if not due.is_empty() else 9223372036854775807)
		if next > target:
			break
		r.now = maxi(int(r.now), next)
		if not due.is_empty() and int(due.deadline) <= dawn:
			resolve(v, due)
		else:
			Village.step_day(v)
			sync_events(v)
	r.now = target
	for e: Dictionary in r.events:
		if terminal(e):
			continue
		var p := v.people[int(e.victim)]
		if not p.alive or not p.present:
			cancel(v, e, "participant unavailable")
		elif target >= int(e.from):
			e.phase = "active"; p.locked = true; p.locked_at = v.place_ids.get(e.place, -1)
	r.events = r.events.filter(func(e: Dictionary) -> bool: return not terminal(e) or int(e.end) > target - 7 * 1440)

static func resolve(v: S.Village, e: Dictionary) -> void:
	var p := v.people[int(e.victim)]
	if not p.alive or not p.present:
		cancel(v, e, "participant unavailable")
		return
	Justice.resolve_public(v, int(e.id))
	p.locked = false
	e.phase = "resolved"; e.revision += 1
	e.outcome = ("released" if p.present else "exiled") if p.alive else "died"

static func cancel(v: S.Village, e: Dictionary, reason: String) -> void:
	v.pending = v.pending.filter(func(a: S.PublicAct) -> bool: return a.staging != int(e.id))
	e.phase = "cancelled"; e.outcome = reason; e.revision += 1
	v.people[int(e.victim)].locked = false

static func act(v: S.Village, request: Dictionary, context: Dictionary) -> Dictionary:
	var r := v.runtime
	var id: String = request.get("action_id", "")
	if id.is_empty() or id.length() > 120:
		return {"accepted": false, "reason": "invalid action"}
	if r.receipts.has(id):
		var old: Dictionary = r.receipts[id].duplicate(true)
		old.duplicate = true
		return old
	if request.get("village_id") != r.village or request.get("player_id") != "player:local" or request.get("logical_time") != r.now:
		return {"accepted": false, "reason": "stale context"}
	var e := event_by_id(v, int(request.get("event_id", -1)))
	if e.is_empty() or terminal(e) or r.now < e.from or r.now >= e.deadline:
		return {"accepted": false, "reason": "window closed"}
	var p := v.people[int(e.victim)]
	if not p.alive or not p.present or float(context.get("distance_dm", INF)) > 25.0:
		return {"accepted": false, "reason": "out of reach"}
	if request.get("verb") != "free":
		return {"accepted": false, "reason": "unknown action"}
	Justice.resolve_public(v, int(e.id), "free")
	p.present = true; p.locked = false; p.locked_at = -1
	v.outlaws.erase(p.id)
	v.schedule = v.schedule.filter(func(s: S.Sched) -> bool: return not (s.kind == "return" and s.who == p.id))
	r.residents[str(p.id)] = {"refuge_until": int(r.now) + 2880, "rescued_by": request.player_id, "destination": "far_woods"}
	for other: Dictionary in r.events:
		if other.id != e.id and other.victim == p.id and not terminal(other):
			cancel(v, other, "rescued")
	e.phase = "resolved"; e.outcome = "rescued"; e.revision += 1
	var receipt := {"accepted": true, "action_id": id, "event_id": e.id, "verb": request.verb, "at": r.now,
		"outcome": e.outcome, "revision": e.revision, "player": request.player_id}
	r.receipts[id] = receipt; r.sequence += 1
	if r.receipts.size() > 256:
		r.receipts.erase(r.receipts.keys()[0])
	return receipt
