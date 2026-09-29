extends RefCounted
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")

static func report() -> PackedStringArray:
	var v := Runtime.create()
	var event := {}
	for _i in 150:
		Runtime.advance(v, v.day * 1440)
		for e: Dictionary in v.runtime.events:
			if not Runtime.terminal(e) and e.deadline > v.runtime.now:
				event = e
				break
		if not event.is_empty():
			break
	if event.is_empty():
		return ["FAIL runtime: no public act"]
	Runtime.advance(v, int(event.deadline) - 1)
	var req := {"action_id": "rescue:1", "player_id": "player:local", "village_id": v.runtime.village,
		"logical_time": v.runtime.now, "event_id": event.id, "verb": "free"}
	if Runtime.act(v, req, {"distance_dm": 99}).accepted:
		return ["FAIL runtime: range"]
	if not Runtime.act(v, req, {"distance_dm": 10}).accepted:
		return ["FAIL runtime: valid rescue"]
	if not Runtime.act(v, req, {"distance_dm": 10}).get("duplicate", false):
		return ["FAIL runtime: duplicate"]
	var restored := Save.from_data(JSON.parse_string(JSON.stringify(Save.to_data(v))))
	if restored == null:
		return ["FAIL runtime: restore"]
	if JSON.stringify(JSON.parse_string(JSON.stringify(Save.to_data(v)))) != JSON.stringify(JSON.parse_string(JSON.stringify(Save.to_data(restored)))):
		FileAccess.open("user://runtime-before.json", FileAccess.WRITE).store_string(JSON.stringify(Save.to_data(v)))
		FileAccess.open("user://runtime-after.json", FileAccess.WRITE).store_string(JSON.stringify(Save.to_data(restored)))
		return ["FAIL runtime: full state roundtrip"]
	Runtime.advance(v, int(v.runtime.now) + 1441)
	Runtime.advance(restored, int(restored.runtime.now) + 1441)
	if JSON.stringify(JSON.parse_string(JSON.stringify(Save.to_data(v)))) != JSON.stringify(JSON.parse_string(JSON.stringify(Save.to_data(restored)))):
		return ["FAIL runtime: future continuation"]
	if not v.people[int(event.victim)].alive or v.people[int(event.victim)].locked:
		return ["FAIL runtime: midnight undid rescue"]
	return ["PASS runtime: range, last minute, duplicate, immediate save/load, midnight, canonical future continuation"]
