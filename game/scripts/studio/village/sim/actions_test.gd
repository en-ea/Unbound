extends RefCounted
## Finite contracts from tools-src/studio/village-reference/actions-test.mjs.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")
const Storm := preload("res://scripts/studio/village/sim/storm.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const Bridge := preload("res://scripts/studio/village/sim/storm_bridge.gd")
const Crime := preload("res://scripts/studio/village/sim/crime.gd")

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
	var tp := _hearing()
	var tv: S.Village = tp[0]
	var te: Dictionary = tp[1]
	var tc := tv.cases[te.source.case_id]
	var retell_judge := int(Runtime.staging(tv, int(te.id)).roles.authority)
	var speakers: Array[int] = []
	for person in tv.people:
		if person.alive and person.present and person.id != retell_judge and person.id != tc.accused:
			speakers.append(person.id)
			if speakers.size() == 2: break
	var source := 4000000 + tc.crime
	for id in speakers:
		var speaker := tv.people[id]
		speaker.era = tv.age
		speaker.beliefs = speaker.beliefs.filter(func(b: S.Belief) -> bool: return b.crime != tc.crime)
		Crime.give_belief(tv, id, tc.crime, tc.accused, 600, source, 1, speakers[0])
		if not te.witnesses.has(id): te.witnesses.append(id)
		if not _request(tv, te, "listen", {"speaker": id}).accepted: return ["FAIL actions: retold account unavailable"]
	var knowledge: Array = tv.runtime.players["player:local"].knowledge
	if knowledge.filter(func(k: Dictionary) -> bool: return k.origin == source).size() != 1:
		return ["FAIL actions: retelling manufactured another source"]
	var counts: Array[int] = []
	for person in tv.people: counts.append(person.beliefs.size())
	var evidence := tc.evidence
	if not _request(tv, te, "testify", {"origin": source}).accepted or tc.evidence != evidence + 300:
		return ["FAIL actions: single retold source evidence"]
	for person in tv.people:
		if person.id != retell_judge and person.beliefs.size() != counts[person.id]: return ["FAIL actions: nonrecipient learned testimony"]
	var repeated := Runtime.act(tv, {"action_id": "new-input-same-origin", "player_id": "player:local", "village_id": tv.runtime.village,
		"logical_time": tv.runtime.now, "event_id": te.id, "verb": "testify", "parameters": {"origin": source}}, {"distance_dm": 0})
	if repeated.accepted or tc.evidence != evidence + 300: return ["FAIL actions: repeated source became corroboration"]
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
		var finder := -1
		for person in p_v.people:
			if person.alive and person.present and person.id != int(pe.victim) and person.id != judge_id and Runtime.Village.age_of(p_v, person) >= 14:
				finder = person.id; break
		p_v.people[finder].plan = PackedInt32Array([0, 1440, p_v.place_ids[home]])
		var pst := Runtime.staging(p_v, int(pe.id))
		pst.people = pst.people.filter(func(person: Dictionary) -> bool: return int(person.id) != finder)
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
	for accepts in [true, false]:
		var offer_fixture := _rite()
		var ov: S.Village = offer_fixture[0]
		var oe: Dictionary = offer_fixture[1]
		var leader := ov.people[int(oe.source.who)]
		leader.traits[C.COMPASSION] = 100 if accepts else 0
		leader.values[C.V_MERCY] = 100 if accepts else 0
		if _request(ov, oe, "offer").get("wood", 0) != 1 or Runtime.terminal(oe) != accepts:
			return ["FAIL actions: differentiated rite offering"]
		if not _request(ov, oe, "offer").get("duplicate", false): return ["FAIL actions: offer replay"]
		if ov.runtime.players["player:local"].enemies.has(leader.id): return ["FAIL actions: gesture created authority grudge"]
		if not accepts and not _request(ov, oe, "free").accepted: return ["FAIL actions: refused offering blocked rescue"]
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
