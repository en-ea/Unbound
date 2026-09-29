extends RefCounted
## Finite contracts from tools-src/studio/village-reference/actions-test.mjs.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")
const Storm := preload("res://scripts/studio/village/sim/storm.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const Bridge := preload("res://scripts/studio/village/sim/storm_bridge.gd")

static func _request(v: S.Village, e: Dictionary, verb: String, params: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var context := {"distance_dm": 0, "coins": 50, "wood": 1}
	context.merge(extra, true)
	return Runtime.act(v, {"action_id": "%s:%s:%s" % [e.id, verb, JSON.stringify(params)],
		"player_id": "player:local", "village_id": v.runtime.village, "logical_time": v.runtime.now,
		"event_id": e.id, "verb": verb, "parameters": params}, context)

static func _hearing() -> Array:
	for seed in range(1, 30):
		var v := Runtime.create(seed, {"anchored": true})
		for _day in 60:
			Runtime.advance(v, v.day * 1440)
			for e: Dictionary in v.runtime.events:
				if e.type == "hearing" and not Runtime.terminal(e):
					Runtime.advance(v, maxi(int(v.runtime.now), int(e.from)))
					return [v, e]
	return []

static func _rite() -> Array:
	var v := Runtime.create(16838, {"anchored": false})
	var sid := Storm.storm_hits(v, 2, 3)
	if sid < 0:
		return []
	var storm := v.storms[sid]
	var who := -1
	for id in storm.ancestors:
		if v.people[id].role != "child":
			who = id; break
	if who < 0:
		return []
	var victim := -1
	for p in v.people:
		if p.alive and p.present and p.ancestor < 0 and v.day - p.born >= 16 * 60 and p.lineage != v.people[who].lineage:
			victim = p.id; break
	if victim < 0:
		return []
	var s := S.Sched.new()
	s.day = v.day; s.kind = "rite"; s.who = who; s.other = victim; s.storm = sid; s.causes = PackedInt32Array([storm.event])
	v.people[victim].locked = true
	Storm.rite_act(v, s)
	Runtime.sync_events(v)
	for e: Dictionary in v.runtime.events:
		if e.type == "rite":
			Runtime.advance(v, int(e.from))
			return [v, e, storm]
	return []

static func _same(a: S.Village, b: S.Village) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(Save.to_data(a)))) == JSON.stringify(JSON.parse_string(JSON.stringify(Save.to_data(b))))

static func report() -> PackedStringArray:
	var pair := _hearing()
	if pair.is_empty(): return ["FAIL actions: no hearing"]
	var v: S.Village = pair[0]
	var e: Dictionary = pair[1]
	var cs := v.cases[e.source.case_id]
	if v.crimes[cs.crime].closed: return ["FAIL actions: early verdict"]
	var other := -1
	for p in v.people:
		if p.alive and p.present and p.id != cs.accused and p.id != v.authority:
			other = p.id; break
	if other < 0: return ["FAIL actions: no trace subject"]
	var place := v.households[v.people[other].household].home
	v.crimes[cs.crime].trace_at = v.place_ids[place]
	v.crimes[cs.crime].culprit = other
	if not _request(v, e, "inspect", {"place": place}).accepted: return ["FAIL actions: inspect"]
	var origin := 1000000 + cs.crime
	var before := cs.evidence
	if not _request(v, e, "testify", {"origin": origin}).accepted or cs.evidence >= before:
		return ["FAIL actions: testimony"]
	var once := cs.evidence
	if not _request(v, e, "testify", {"origin": origin}).get("duplicate", false) or cs.evidence != once:
		return ["FAIL actions: duplicate testimony"]
	var saved: S.Village = Save.from_data(JSON.parse_string(JSON.stringify(Save.to_data(v))))
	Runtime.advance(v, int(e.deadline)); Runtime.advance(saved, int(e.deadline))
	if e.outcome != "acquitted" or not _same(v, saved) or not v.people[int(e.victim)].alive:
		return ["FAIL actions: acquittal continuation"]
	for accepted in [true, false]:
		pair = _hearing()
		var b: S.Village = pair[0]
		var be: Dictionary = pair[1]
		var judge := b.people[int(Runtime.staging(b, be.id).roles.authority)]
		judge.traits[C.GREED] = 100 if accepted else 0
		judge.traits[C.HONESTY] = 0 if accepted else 100
		judge.values[C.V_LAW] = 50
		var receipt := _request(b, be, "bribe")
		if receipt.get("coins", -1) != (5 if accepted else 0): return ["FAIL actions: bribe cost"]
		if not _request(b, be, "bribe").get("duplicate", false): return ["FAIL actions: bribe replay"]
		var restored: S.Village = Save.from_data(JSON.parse_string(JSON.stringify(Save.to_data(b))))
		if not _request(restored, be, "bribe").get("duplicate", false): return ["FAIL actions: bribe reload"]
	for watched in [true, false]:
		pair = _hearing()
		var p_v: S.Village = pair[0]
		var pe: Dictionary = pair[1]
		var home := p_v.households[p_v.people[int(pe.victim)].household].home
		var judge_id := int(Runtime.staging(p_v, pe.id).roles.authority)
		var beliefs: Array[int] = []
		for person in p_v.people: beliefs.append(person.beliefs.size())
		var receipt := _request(p_v, pe, "plant", {"place": home}, {"witnesses": [judge_id] if watched else []})
		if receipt.get("wood", -1) != 1: return ["FAIL actions: plant cost"]
		for i in p_v.people.size():
			if p_v.people[i].beliefs.size() != beliefs[i]: return ["FAIL actions: instant plant discovery"]
		p_v.people[judge_id].plan = PackedInt32Array([0, 1440, p_v.place_ids[home]])
		Runtime.advance(p_v, int(p_v.runtime.now) + 16)
		if not p_v.runtime.traces[0].discovered: return ["FAIL actions: local discovery"]
		var player: Dictionary = p_v.runtime.players["player:local"]
		if player.enemies.has(judge_id) != watched: return ["FAIL actions: witness consequence"]
	for rescue in [true, false]:
		var triple := _rite()
		if triple.is_empty(): return ["FAIL actions: no rite"]
		var rv: S.Village = triple[0]
		var re: Dictionary = triple[1]
		var storm: S.Storm = triple[2]
		if not rv.people[int(re.victim)].alive: return ["FAIL actions: early rite death"]
		if rescue and not _request(rv, re, "free").accepted: return ["FAIL actions: rite rescue"]
		var restored: S.Village = Save.from_data(JSON.parse_string(JSON.stringify(Save.to_data(rv))))
		Runtime.advance(rv, int(re.deadline)); Runtime.advance(restored, int(re.deadline))
		if not _same(rv, restored): return ["FAIL actions: rite continuation"]
		if rescue and not rv.people[int(re.victim)].alive: return ["FAIL actions: rescue death"]
		Storm.storm_recedes(rv, storm); Runtime.advance(rv, int(rv.runtime.now))
		for id in storm.lost:
			if not rv.people[id].present: return ["FAIL actions: lost did not return"]
		for id in storm.ancestors:
			if rv.people[id].present: return ["FAIL actions: ancestor did not recede"]
	var triple := _rite()
	var rv: S.Village = triple[0]
	var re: Dictionary = triple[1]
	Storm.storm_recedes(rv, triple[2]); Runtime.advance(rv, int(re.deadline))
	if re.phase != "cancelled" or not rv.people[int(re.victim)].alive: return ["FAIL actions: obsolete rite"]
	var anchor := Runtime.create(1, {"anchored": true})
	if Storm.storm_hits(anchor, 0, 3) != -1: return ["FAIL actions: anchored storm"]
	var transition := Bridge.transition(16838, 1)
	if transition != {"epoch": 21, "source": 0, "enclave": 12, "displaced": 17, "past": 0, "hash": "22a8b05d"}:
		return ["FAIL actions: kernel bridge %s" % JSON.stringify(transition)]
	return ["PASS actions: undecided hearing; provenance and duplicate testimony; acquittal; bounded bribe/refusal/reload; local planting/discovery; rite preparation/rescue/inaction/recession; anchor; canonical continuation"]
