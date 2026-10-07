extends RefCounted
## The Tidecaller's acts on people (water class, 6 Oct; plan/WATER-CLASS-PLAN-2026-10-06.md section 3), headless:
##   godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/water_verbs_test --save-guard
## wet: the doused fact on someone dry, the extinguish water branch on someone burning, nothing without water contact.
## hold: the suspended fact; when it ends, the slam is a fall (hurt and down through the one harm table); held its
## full time with drown, the rules' one death ("drowned"); children and Enea's authored refused. freeze: only on
## someone wet; a strike on the frozen is three blows' harm and cracks the ice. One act per press id. Then through
## acceptance and the journal with the guard on: a reload equals the live village.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Actions := preload("res://scripts/studio/village/sim/people_actions.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const Journal := preload("res://scripts/studio/village/journal.gd")
const SafeFile := preload("res://scripts/core/safe_file.gd")
const Things := preload("res://scripts/studio/village/sim/thing_actions.gd")
const PLAYER := "player:local"


static func check(out: PackedStringArray, ok: bool, text: String) -> void:
	out.append(("PASS" if ok else "FAIL") + " water " + text)


static func _text(v: S.Village) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(Codec.to_data(v, false))))


static func adults(v: S.Village, n: int) -> Array:
	var out := []
	for p in v.people:
		if p.alive and p.present and not p.locked and p.authored == "" and Rules.age_of(v, p) >= 18:
			out.append(p.id)
			if out.size() == n:
				break
	return out


static func act(v: S.Village, action: String, id: int, verb: String, params: Dictionary = {}, water := true) -> Dictionary:
	var request := {"action_id": action, "actor": PLAYER, "target": People.key(v, id), "verb": verb,
		"village_id": v.runtime.village, "logical_time": v.runtime.now, "parameters": params}
	return Actions.prepare(v, request, {"authorized": true, "distance_dm": 60 if verb in Actions.AREA else 8, "reach_dm": 120, "water_contact": water, "accounts": []})


## Moves the village's clock on by ms (ticks are milliseconds of the active clock) and lets the body facts run.
static func later(v: S.Village, ms: int) -> void:
	v.runtime.now = int(v.runtime.now) + ceili(ms / 500.0)
	Actions.advance(v)


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var v: S.Village = Runtime.create(16838, {"anchored": true})
	var ids := adults(v, 4)
	var a: S.Person = v.people[ids[0]]
	var b: S.Person = v.people[ids[1]]
	var c: S.Person = v.people[ids[2]]
	var d: S.Person = v.people[ids[3]]
	# wet
	var dry := act(v, "deed:w0", ids[0], "wet", {"method": "tide"}, false)
	var wet := act(v, "deed:w1", ids[0], "wet", {"method": "tide", "until_ms": 15000})
	var again := act(v, "deed:w1", ids[0], "wet", {"method": "tide", "until_ms": 15000})
	check(out, not dry.accepted and wet.accepted and Actions.live(v, a, "doused") and str(a.body_facts.doused.method) == "tide"
		and str(a.body_facts.doused.deed) == "deed:w1" and again.get("duplicate", false),
		"wet: the doused fact on someone dry, refused without water contact, the same press twice is one act")
	act(v, "deed:b1", ids[1], "burn", {"heat": 750})
	var put_out := act(v, "deed:w2", ids[1], "wet", {"method": "tide"})
	check(out, put_out.accepted and put_out.get("extinguished", false) and not b.body_facts.has("burning") and b.body_facts.has("doused"),
		"wet on someone burning is the extinguish water branch: the fire out, doused")
	# freeze, and the blow on the frozen
	var not_wet := act(v, "deed:f0", ids[2], "freeze")
	var frozen := act(v, "deed:f1", ids[0], "freeze", {"until_ms": 4000})
	var hurt := int(a.hurt)
	var blow := act(v, "deed:s1", ids[0], "strike", {"damage": 1})
	check(out, not not_wet.accepted and frozen.accepted and blow.accepted and blow.get("shattered", false) and int(a.hurt) - hurt == 42
		and not a.body_facts.has("frozen"),
		"freeze only on someone wet; a strike on the frozen is three blows' harm (%d) and cracks the ice" % (int(a.hurt) - hurt))
	# hold: the slam, then drowning
	var child := -1
	for q in v.people:
		if q.alive and q.present and Rules.age_of(v, q) < 14:
			child = q.id
			break
	var refused := act(v, "deed:h0", child, "hold")
	var held := act(v, "deed:h1", ids[2], "hold", {"until_ms": 3000})
	var hung := Actions.live(v, c, "suspended")
	later(v, 3500)
	check(out, child >= 0 and not refused.accepted and held.accepted and hung and not c.body_facts.has("suspended") and c.alive
		and Actions.down(v, c) and str(c.body_facts.down.deed) == "deed:h1" and int(c.hurt) >= 4,
		"hold: suspended, then the slam is a fall (down and hurt caused by the hold); a child refused")
	var deaths := int(v.stats["violentDeaths"])
	var drown := act(v, "deed:h2", ids[3], "hold", {"until_ms": 5000, "drown": true})
	later(v, 5500)
	var dead: Dictionary = d.body_facts.get("dead", {})
	var ev = v.events[int(dead.get("event", -1))] if int(dead.get("event", -1)) >= 0 else null
	check(out, drown.accepted and not d.alive and d.death_cause == "drowned" and str(dead.get("deed", "")) == "deed:h2"
		and ev != null and ev.type == "violent_death" and str(ev.data.get("by", "")) == PLAYER and int(v.stats["violentDeaths"]) == deaths + 1,
		"held its full time with drown: the rules' one death, drowned, naming the player")
	# Lightning: a strike measured from the bolt's ground point, not the caster's body.
	var e := adults(v, 6)
	var near_bolt := Actions.prepare(v, {"action_id": "deed:bolt1", "actor": PLAYER, "target": People.key(v, e[4]), "verb": "strike",
		"village_id": v.runtime.village, "logical_time": v.runtime.now, "parameters": {"damage": 5, "force": 900, "source": "lightning"}},
		{"authorized": true, "distance_dm": 15, "reach_dm": 15, "accounts": []})
	var far_bolt := Actions.prepare(v, {"action_id": "deed:bolt2", "actor": PLAYER, "target": People.key(v, e[5]), "verb": "strike",
		"village_id": v.runtime.village, "logical_time": v.runtime.now, "parameters": {"damage": 5, "force": 900, "source": "lightning"}},
		{"authorized": true, "distance_dm": 30, "reach_dm": 15, "accounts": []})
	check(out, Actions.area("strike", {"source": "lightning"}) and not Actions.area("strike", {}) and near_bolt.accepted
		and int(v.people[e[4]].hurt) >= 70 and not far_bolt.accepted and int(v.people[e[5]].hurt) == 0,
		"lightning: a bolt 1.5 m from someone 8 m from the caster lands with strike's harm; a bolt 3 m away does not")
	_rain(out)
	_journal(out)
	return out


## Rain under a cloud: rain_at puts out the burning things within its radius (only burning facts are read), and
## extinguish "rain" puts out a burning person under it - the area is the contact, no body for the weather.
static func _rain(out: PackedStringArray) -> void:
	var v: S.Village = Runtime.create(16838, {"anchored": true})
	v.thing_facts = {}
	var roots := {}
	var near := Things.id_of("fence", 3.0, -2.0)
	var also := Things.id_of("bench", 6.0, 1.0)
	var far := Things.id_of("rack", 20.0, 20.0)
	var dry := Things.id_of("crates", 2.0, 2.0)
	var n := 0
	for id: String in [near, also, far]:
		n += 1
		Things.prepare(v, roots, {"action_id": "lit%d" % n, "actor": PLAYER, "target": id, "verb": "burn", "parameters": {}}, {"distance_dm": 5})
	Things.prepare(v, roots, {"action_id": "kick", "actor": PLAYER, "target": dry, "verb": "strike", "parameters": {"force": 100}}, {"distance_dm": 5})
	var out_ids := Things.rain_at(v, roots, [3.0, 0.0], 6.0, "rain:cloud")
	check(out, out_ids == [also, near] and not Things.has(v, near, "burning") and not Things.has(v, also, "burning") and Things.has(v, far, "burning")
		and not Things.has(v, dry, "soaked"),
		"rain_at puts out the burning things under the cloud, leaves the far fire and touches nothing dry (%s)" % str(out_ids))
	var ids := adults(v, 2)
	act(v, "deed:rb1", ids[0], "burn", {"heat": 750})
	act(v, "deed:rb2", ids[1], "burn", {"heat": 750})
	var rained := Actions.prepare(v, {"action_id": "rain:p1", "actor": "weather", "target": People.key(v, ids[0]), "verb": "extinguish",
		"village_id": v.runtime.village, "logical_time": v.runtime.now, "parameters": {"method": "rain"}},
		{"authorized": true, "distance_dm": 50, "reach_dm": 70, "accounts": []})
	var beyond := Actions.prepare(v, {"action_id": "rain:p2", "actor": "weather", "target": People.key(v, ids[1]), "verb": "extinguish",
		"village_id": v.runtime.village, "logical_time": v.runtime.now, "parameters": {"method": "rain"}},
		{"authorized": true, "distance_dm": 90, "reach_dm": 70, "accounts": []})
	check(out, rained.accepted and rained.get("extinguished", false) and not v.people[ids[0]].body_facts.has("burning")
		and str(v.people[ids[0]].body_facts.doused.method) == "rain" and not beyond.accepted and v.people[ids[1]].body_facts.has("burning"),
		"extinguish rain puts out a burning person under the cloud (no water contact, no body), not one beyond its radius")


## Through acceptance and the journal with the guard on: wet, freeze, hold with drown and its end are journal lines,
## the guard silent, and the full save plus its journal reloads to exactly the live village.
static func _journal(out: PackedStringArray) -> void:
	var v: S.Village = Runtime.create(16838, {"anchored": true})
	var path := "user://studio-test-water.json"
	SafeFile.remove(path)
	if FileAccess.file_exists(path + ".journal"):
		DirAccess.remove_absolute(path + ".journal")
	var journal = Journal.new(path)
	var previous = VillageSession.village
	VillageSession.village = v
	VillageImage.guard = true
	var save_id := "water-%d" % randi()
	var text := JSON.stringify({"version": 1, "save_id": save_id, "village": Codec.to_data(v, true)})
	var written := SafeFile.write_text(path, text)
	journal.rebase(save_id, text)
	VillageImage.rebase(v, true)
	var writer := func() -> int: return journal.append({"village": VillageImage.staged.line})
	var ids := adults(v, 2)
	# The one to drown has a plan of their own (a routine): death clears it, and the image must be told.
	var planned: Dictionary = Accept.transact(func(live) -> Dictionary:
		VillageImage.hinting()
		VillageImage.touch(ids[1])
		live.people[ids[1]].mind.plan = {"offer": "routine", "test": true}
		return {"accepted": true}, writer)
	var ok: bool = planned.get("accepted", false)
	for step: Array in [["deed:j-w", ids[0], "wet", {}], ["deed:j-f", ids[0], "freeze", {}], ["deed:j-h", ids[1], "hold", {"until_ms": 2000, "drown": true}]]:
		var r: Dictionary = Accept.transact(func(live) -> Dictionary:
			VillageImage.hinting()
			return act(live, step[0], step[1], step[2], step[3]), writer)
		ok = ok and r.get("accepted", false)
	v.runtime.now = int(v.runtime.now) + 5
	var ended: Dictionary = Accept.transact(func(live) -> Dictionary:
		VillageImage.hinting()
		return {"accepted": not Actions.advance(live).is_empty()}, writer)
	var drift := VillageImage.verify(v)
	check(out, written == OK and ok and ended.get("accepted", false) and drift.is_empty() and not v.people[ids[1]].alive
		and v.people[ids[1]].mind.plan.is_empty(),
		"through acceptance: wet, freeze, a drowning hold and its end, the guard silent (%s)" % str(drift))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var back = Codec.from_data(Journal.replay(data, path + ".journal").village)
	check(out, back != null and _text(back) == _text(v), "the full save plus its journal reloads to exactly the live village")
	VillageImage.rebase(v, false)
	VillageImage.guard = false
	VillageSession.village = previous
	SafeFile.remove(path)
	if FileAccess.file_exists(path + ".journal"):
		DirAccess.remove_absolute(path + ".journal")
