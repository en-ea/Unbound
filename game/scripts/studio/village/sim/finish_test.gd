extends RefCounted
## Killing by hand (Hilmi, 6 Oct: "I do"), headless:
##   godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/finish_test --save-guard
## people_actions' finish: on someone standing it is refused (the knock-down comes first); on someone down it is the
## same death a fire's takes (Rules.die: a violent death naming the actor and the verb, the funeral) and the dead fact
## with its cause; the same press again adds nothing; a child or one of Enea's authored is protected; his seven are
## not (the player's acts reach them). Then through acceptance and the journal with the guard on: a reload equals
## the live village.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Actions := preload("res://scripts/studio/village/sim/people_actions.gd")
const Ported := preload("res://scripts/studio/village/sim/ported.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const Journal := preload("res://scripts/studio/village/journal.gd")
const SafeFile := preload("res://scripts/core/safe_file.gd")
const PLAYER := "player:local"


static func check(out: PackedStringArray, ok: bool, text: String) -> void:
	out.append(("PASS" if ok else "FAIL") + " finish " + text)


static func _text(v: S.Village) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(Codec.to_data(v, false))))


static func adult(v: S.Village, skip: Array = []) -> int:
	for p in v.people:
		if p.alive and p.present and not p.locked and p.authored == "" and Rules.age_of(v, p) >= 18 and not skip.has(p.id) \
				and not Ported.held(v, p):
			return p.id
	return -1


static func act(v: S.Village, action: String, id: int, verb: String, params: Dictionary = {}) -> Dictionary:
	var request := {"action_id": action, "actor": PLAYER, "target": People.key(v, id), "verb": verb,
		"village_id": v.runtime.village, "logical_time": v.runtime.now, "parameters": params}
	return Actions.prepare(v, request, {"authorized": true, "distance_dm": 8, "accounts": []})


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var v: S.Village = Runtime.create(16838, {"anchored": true})
	var id := adult(v)
	var p: S.Person = v.people[id]
	var standing := act(v, "deed:finish-standing", id, "finish")
	check(out, not standing.accepted and p.alive and not p.body_facts.has("dead"), "on someone standing it is refused: the knock-down first (%s)" % str(standing.get("reason", "")))
	var felled := act(v, "deed:fell", id, "strike", {"force": 850, "damage": 1})
	var deaths := int(v.stats["violentDeaths"])
	var events := v.events.size()
	var done := act(v, "deed:finish", id, "finish")
	var dead: Dictionary = p.body_facts.get("dead", {})
	var ev = v.events[int(done.get("death_event", -1))] if int(done.get("death_event", -1)) >= 0 else null
	check(out, felled.accepted and felled.down and done.accepted and not p.alive and p.death_cause == "finish"
		and str(dead.get("deed", "")) == "deed:finish" and str(dead.get("by", "")) == PLAYER and str(dead.get("verb", "")) == "finish"
		and not p.body_facts.has("down"),
		"on someone down it kills: alive false, the dead fact caused by this act, naming the actor and the verb")
	check(out, ev != null and ev.type == "violent_death" and str(ev.data.get("by", "")) == PLAYER and str(ev.data.get("cause", "")) == "finish"
		and int(v.stats["violentDeaths"]) == deaths + 1 and v.schedule.any(func(s) -> bool: return s.kind == "funeral" and s.who == id)
		and (ev.causes.size() == 1 and ev.causes[0] == int(v.people_facts["deed:fell"].event)),
		"the death a fire's takes: a violent death naming the player, caused by the blow that felled them, and a funeral")
	var count := v.events.size()
	var again := act(v, "deed:finish", id, "finish")
	check(out, again.get("duplicate", false) and v.events.size() == count and int(v.stats["violentDeaths"]) == deaths + 1,
		"the same press again adds nothing (%d events before, %d after the act)" % [events, count])
	var other := act(v, "deed:finish-dead", id, "finish")
	check(out, not other.accepted, "the dead cannot be finished again (%s)" % str(other.get("reason", "")))
	# A child and one of Enea's authored are protected; one of his seven is not.
	var child := -1
	for q in v.people:
		if q.alive and q.present and Rules.age_of(v, q) < 14:
			child = q.id
			break
	var wren := -1
	for q in v.people:
		if q.authored != "" and q.alive:
			wren = q.id
			break
	var protected := true
	for who: int in [child, wren]:
		if who >= 0:
			v.people[who].body_facts["down"] = {"kind": "down", "id": "down", "deed": "deed:test-down", "until_tick": People.tick(v) + 6000}
			protected = protected and not act(v, "deed:finish-%d" % who, who, "finish").accepted and v.people[who].alive
	check(out, child >= 0 and wren >= 0 and protected, "a child and one of Enea's authored cannot be finished")
	_journal(out, v)
	return out


## Through acceptance and the journal with the guard on: the knock-down and the finish are journal lines, the guard
## silent, and the full save plus its journal reloads to exactly the live village.
static func _journal(out: PackedStringArray, v0: S.Village) -> void:
	var v: S.Village = Runtime.create(16838, {"anchored": true})
	var path := "user://studio-test-finish.json"
	SafeFile.remove(path)
	if FileAccess.file_exists(path + ".journal"):
		DirAccess.remove_absolute(path + ".journal")
	var journal = Journal.new(path)
	var previous = VillageSession.village
	VillageSession.village = v
	VillageImage.guard = true
	var save_id := "finish-%d" % randi()
	var text := JSON.stringify({"version": 1, "save_id": save_id, "village": Codec.to_data(v, true)})
	var written := SafeFile.write_text(path, text)
	journal.rebase(save_id, text)
	VillageImage.rebase(v, true)
	var writer := func() -> int: return journal.append({"village": VillageImage.staged.line})
	var id := adult(v)
	# They have a plan of their own (a routine): death clears it, and the image must be told.
	var planned: Dictionary = Accept.transact(func(live) -> Dictionary:
		VillageImage.hinting()
		VillageImage.touch(id)
		live.people[id].mind.plan = {"offer": "routine", "test": true}
		return {"accepted": true}, writer)
	var felled: Dictionary = Accept.transact(func(live) -> Dictionary:
		VillageImage.hinting()
		return act(live, "deed:j-fell", id, "strike", {"force": 850}), writer)
	var finished: Dictionary = Accept.transact(func(live) -> Dictionary:
		VillageImage.hinting()
		return act(live, "deed:j-finish", id, "finish"), writer)
	var drift := VillageImage.verify(v)
	check(out, written == OK and felled.get("accepted", false) and finished.get("accepted", false) and drift.is_empty() and journal.seq == 3
		and not v.people[id].alive and planned.get("accepted", false) and v.people[id].mind.plan.is_empty(), "through acceptance: the knock-down and the finish are two journal lines, the guard silent (%s)" % str(drift))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var back = Codec.from_data(Journal.replay(data, path + ".journal").village)
	check(out, back != null and _text(back) == _text(v) and not back.people[id].alive and back.people[id].body_facts.has("dead"),
		"the full save plus its journal reloads to exactly the live village, the dead fact and the lineage's past names kept")
	VillageImage.rebase(v, false)
	VillageImage.guard = false
	VillageSession.village = previous
	SafeFile.remove(path)
	if FileAccess.file_exists(path + ".journal"):
		DirAccess.remove_absolute(path + ".journal")
