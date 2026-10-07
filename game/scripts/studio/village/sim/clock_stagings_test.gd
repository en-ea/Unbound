extends RefCounted
## Which stagings a save keeps follows the clock (save.gd _kept_stagings: an event's staging is kept until its end),
## and the clock moves outside acceptance (WorldClock, his bed, the sky's set_time). A batch that names only a mind's
## plan right after a clock jump must still write the stagings the jump let go (desk 6 Oct: the intermittent
## "FAIL save-image guard after written batch: field stagings" in Mind's port probe). Headless, guard on:
##   godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/clock_stagings_test --save-guard
const S := preload("res://scripts/studio/village/sim/state.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const Journal := preload("res://scripts/studio/village/journal.gd")
const SafeFile := preload("res://scripts/core/safe_file.gd")
const STAGING := 990001


static func check(out: PackedStringArray, ok: bool, text: String) -> void:
	out.append(("PASS" if ok else "FAIL") + " clock-stagings " + text)


static func _text(v: S.Village) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(Codec.to_data(v, false))))


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var v: S.Village = Runtime.create(16838, {"anchored": true})
	var now := int(v.runtime.now)
	# An ended event whose staging is kept until its end, 30 minutes from now.
	v.stagings.append({"id": STAGING, "kind": "incident", "place": "square", "start": 0, "end": 0, "phases": [], "roles": {},
		"beats": [], "outcome": "carried_out", "cause": [], "cue": "", "day": v.day, "people": []})
	v.runtime.events.append({"id": STAGING, "type": "incident", "phase": "resolved", "victim": 0, "from": now, "deadline": now + 30,
		"end": now + 30, "revision": 1, "shields": [], "staging": STAGING, "source": null})
	var path := "user://studio-test-clock-stagings.json"
	SafeFile.remove(path)
	if FileAccess.file_exists(path + ".journal"):
		DirAccess.remove_absolute(path + ".journal")
	var journal = Journal.new(path)
	var previous = VillageSession.village
	VillageSession.village = v
	VillageImage.guard = true
	var save_id := "clock-stagings-%d" % randi()
	var text := JSON.stringify({"version": 1, "save_id": save_id, "village": Codec.to_data(v, true)})
	var written := SafeFile.write_text(path, text)
	journal.rebase(save_id, text)
	VillageImage.rebase(v, true)
	var writer := func() -> int: return journal.append({"village": VillageImage.staged.line})
	var kept_before := Codec._kept_stagings(v).has(STAGING)
	# The clock jumps outside acceptance (as his bed's 9.6 hours do), past the event's end.
	v.runtime.now = now + 576
	# A refused batch first (an act out of reach, a routine with nothing to change): putting it back takes the live
	# clock into the image (restore), and the stagings must not be left behind with it.
	var refused: Dictionary = Accept.transact(func(live) -> Dictionary:
		VillageImage.hinting()
		VillageImage.touch_key("runtime", "sequence")
		live.runtime.sequence = int(live.runtime.sequence) + 1
		return {"accepted": false}, writer)
	# A batch that names only one mind's plan (Mind's routine offer).
	var id := 0
	var routine: Dictionary = Accept.transact(func(live) -> Dictionary:
		VillageImage.hinting()
		VillageImage.touch(id)
		live.people[id].mind.plan = {"offer": "routine", "test": true}
		return {"accepted": true}, writer)
	var drift := VillageImage.verify(v)
	check(out, written == OK and kept_before and not refused.get("accepted", true) and not Codec._kept_stagings(v).has(STAGING) and routine.get("accepted", false) and drift.is_empty(),
		"a batch naming only a mind's plan after a clock jump writes the stagings the jump let go, the guard silent (%s)" % str(drift))
	# The rules add a staging outside acceptance with the clock still (a frame's catch-up); the next named batch takes
	# it in whatever it names.
	v.stagings.append({"id": STAGING + 1, "kind": "incident", "place": "square", "start": 0, "end": 0, "phases": [], "roles": {},
		"beats": [], "outcome": "carried_out", "cause": [], "cue": "", "day": v.day, "people": []})
	var named: Dictionary = Accept.transact(func(live) -> Dictionary:
		VillageImage.hinting()
		VillageImage.touch(id)
		live.people[id].mind.plan = {"offer": "routine", "test": 2}
		return {"accepted": true}, writer)
	var drift2 := VillageImage.verify(v)
	check(out, named.get("accepted", false) and drift2.is_empty(), "a staging the rules added outside acceptance is taken in by the next named batch, the guard silent (%s)" % str(drift2))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var back = Codec.from_data(Journal.replay(data, path + ".journal").village)
	check(out, back != null and _text(back) == _text(v), "the full save plus its journal reloads to exactly the live village")
	VillageImage.rebase(v, false)
	VillageImage.guard = false
	VillageSession.village = previous
	SafeFile.remove(path)
	if FileAccess.file_exists(path + ".journal"):
		DirAccess.remove_absolute(path + ".journal")
	return out
