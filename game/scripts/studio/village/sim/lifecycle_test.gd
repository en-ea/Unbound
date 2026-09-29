extends RefCounted
## Finite counterpart to tools-src/studio/village-reference/lifecycle-test.mjs.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")

static func _copy(v: S.Village) -> S.Village:
	return Save.from_data(JSON.parse_string(JSON.stringify(Save.to_data(v))))

static func _same(a: S.Village, b: S.Village) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(Save.to_data(a)))) == JSON.stringify(JSON.parse_string(JSON.stringify(Save.to_data(b))))

static func _find(type: String, throws_needed: int = 0) -> Array:
	for seed in range(1, 30):
		var v := Runtime.create(seed)
		for _day in 90:
			Runtime.advance(v, v.day * 1440)
			for e: Dictionary in v.runtime.events:
				if e.type != type or Runtime.terminal(e):
					continue
				var throws := 0
				for beat: Dictionary in Runtime.staging(v, int(e.id)).beats:
					if beat["do"] == "throw": throws += 1
				if throws >= throws_needed:
					Runtime.advance(v, maxi(int(v.runtime.now), int(e.from)))
					return [v, e]
	return []

static func _request(v: S.Village, e: Dictionary, verb: String, parameters: Dictionary = {}) -> Dictionary:
	return Runtime.act(v, {"action_id": verb + JSON.stringify(parameters), "village_id": v.runtime.village,
		"player_id": "player:local", "logical_time": v.runtime.now, "event_id": e.id,
		"verb": verb, "parameters": parameters}, {"distance_dm": 0, "intercepted": true})

static func report() -> PackedStringArray:
	for seed in [1, 16838, 48514]:
		var live := Runtime.create(seed)
		var away := _copy(live)
		if away == null: return ["FAIL lifecycle: initial codec seed %d" % seed]
		var target := int(live.runtime.now) + 8 * 1440
		while int(live.runtime.now) < target:
			Runtime.advance(live, mini(target, int(live.runtime.now) + 17))
		Runtime.advance(away, target)
		if not _same(live, away): return ["FAIL lifecycle: chunking seed %d" % seed]
	var pair := _find("hearing")
	if pair.is_empty(): return ["FAIL lifecycle: no hearing"]
	var v: S.Village = pair[0]
	var e: Dictionary = pair[1]
	var st := Runtime.staging(v, int(e.id))
	var pending := {}
	for hearing: Dictionary in v.runtime.hearings:
		if hearing.staging == e.id:
			pending = hearing; break
	if pending.is_empty(): return ["FAIL lifecycle: missing hearing source"]
	var other: Dictionary = st.duplicate(true)
	other.id = v.staging_count; v.staging_count += 1; v.stagings.append(other)
	var next_pending: Dictionary = pending.duplicate(true)
	next_pending.staging = other.id; v.runtime.hearings.append(next_pending)
	Runtime.sync_events(v)
	var delayed := Runtime.event_by_id(v, int(other.id))
	if delayed.is_empty() or int(delayed.from) < int(e.end) + 5:
		return ["FAIL lifecycle: shared actor/venue reservation"]
	var absent := -1
	for actor: int in e.actors:
		if actor != e.victim:
			absent = actor; break
	if absent < 0: return ["FAIL lifecycle: no hearing actor"]
	v.people[absent].present = false
	Runtime.advance(v, int(v.runtime.now))
	if e.phase != "cancelled" or delayed.phase != "cancelled": return ["FAIL lifecycle: disappearance cancellation"]
	if _request(v, e, "bribe").accepted: return ["FAIL lifecycle: absent judge bribe"]
	var dead_pair := _find("hearing")
	if dead_pair.is_empty(): return ["FAIL lifecycle: no death fixture"]
	var dead_v: S.Village = dead_pair[0]
	var dead_event: Dictionary = dead_pair[1]
	var judge_id := int(Runtime.staging(dead_v, int(dead_event.id)).roles.authority)
	if judge_id < 0: return ["FAIL lifecycle: no judge"]
	dead_v.people[judge_id].alive = false
	Runtime.advance(dead_v, int(dead_v.runtime.now))
	if dead_event.phase != "cancelled": return ["FAIL lifecycle: dead judge cancellation"]
	if _request(dead_v, dead_event, "bribe").accepted or _request(dead_v, dead_event, "testify", {"origin": 1}).accepted:
		return ["FAIL lifecycle: dead judge action"]
	pair = _find("public", 2)
	if pair.is_empty(): return ["FAIL lifecycle: no multi-throw public act"]
	var s: S.Village = pair[0]
	var se: Dictionary = pair[1]
	var stage := Runtime.staging(s, int(se.id))
	var throw_ids: Array[int] = []
	for i in stage.beats.size():
		if stage.beats[i]["do"] == "throw": throw_ids.append(i)
	var first := throw_ids[0]
	var second := throw_ids[1]
	Runtime.advance(s, maxi(int(s.runtime.now), int(stage.day) * 1440 + int(stage.beats[first].at)))
	if not _request(s, se, "shield", {"beat": first}).accepted: return ["FAIL lifecycle: shield contact"]
	if not _request(s, se, "shield", {"beat": first}).get("duplicate", false): return ["FAIL lifecycle: shield replay"]
	if se.shields != [first] or se.shields.has(second): return ["FAIL lifecycle: blanket shield"]
	var saved := _copy(s)
	if saved == null: return ["FAIL lifecycle: shield codec"]
	Runtime.advance(s, int(se.deadline)); Runtime.advance(saved, int(se.deadline))
	if not _same(s, saved): return ["FAIL lifecycle: shield continuation"]
	if _request(s, se, "free").accepted: return ["FAIL lifecycle: late free"]
	if s.people[int(se.victim)].locked: return ["FAIL lifecycle: terminal restraint"]
	var r := Runtime.create(1)
	var resident := -1
	for p in r.people:
		for i in range(3, p.plan.size(), 3):
			if p.alive and p.present and p.plan[i + 2] != p.plan[i - 1]:
				resident = p.id; break
		if resident >= 0: break
	if resident < 0: return ["FAIL lifecycle: no varied routine"]
	Runtime.advance(r, 600)
	var trip := Runtime.routine(r, resident)
	var restored := _copy(r)
	if restored == null or Runtime.routine(restored, resident) != trip: return ["FAIL lifecycle: routine restore"]
	return ["PASS lifecycle: chunk-independent live/offscreen continuation 3x8days; shared actor/venue reservations; disappearance and death cancellation; bounded contact/replay/reload; late free; terminal unlock; routine restore"]
