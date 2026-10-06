extends RefCounted
## Pass 2 contracts, checked headless: the resident view and the talk action (run.gd -- village/sim/contracts_test).
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const WorldActions := preload("res://scripts/studio/village/sim/world_actions.gd")


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var fails := 0
	var v := Runtime.create(7)
	Runtime.advance(v, int(v.runtime.now) + 600)
	var adult := -1
	for p in v.people:
		if p.alive and p.present and View.describe(v, p.id).age_group == "adult":
			adult = p.id
			break
	var d := View.describe(v, adult)
	out.append("describe %s: %s, %s, %s, doing %s at %s" % [d.name, d.age_group, d.role, d.mood, d.activity.verb, d.activity.place])
	var req := {"action_id": "talk:%d:test1" % adult, "player_id": "player:local", "village_id": v.runtime.village,
		"logical_time": v.runtime.now, "verb": "talk", "target": adult, "parameters": {}}
	var first := WorldActions.act(v, req, {"distance_dm": 12})
	var again := WorldActions.act(v, req, {"distance_dm": 12})
	var far := WorldActions.act(v, {"action_id": "talk:%d:test2" % adult, "player_id": "player:local", "village_id": v.runtime.village,
		"logical_time": v.runtime.now, "verb": "talk", "target": adult, "parameters": {}}, {"distance_dm": 80})
	var met: Dictionary = View.toward_player(v, adult)
	for check: Array in [[first.accepted and first.outcome == "first meeting", "first talk accepted as a first meeting"],
			[again.get("duplicate", false), "the same press again is a duplicate"],
			[not far.accepted and far.reason == "out of reach", "talk from 8 m is out of reach"],
			[met.met and met.memories.has("met"), "the view now says they have met"]]:
		out.append(("PASS " if check[0] else "FAIL ") + check[1])
		fails += 0 if check[0] else 1
	out.append("CONTRACTS: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	return out
