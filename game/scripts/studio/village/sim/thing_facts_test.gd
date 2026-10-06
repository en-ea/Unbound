extends RefCounted
## Things' facts (thing_facts.gd), checked headless: run.gd -- village/sim/thing_facts_test
## The agreed shape and its refusals; timed facts ending; the codec keeping the lasting kinds and dropping struck and
## malformed rows at load; an older save with no thing facts; accepted batches written as journal lines that reload to
## exactly the live village, with the image guard on; a batch that names its fields still carries thing facts; and a
## write outside acceptance seen by the guard's exact compare.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Things := preload("res://scripts/studio/village/sim/thing_facts.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const Journal := preload("res://scripts/studio/village/journal.gd")
const SafeFile := preload("res://scripts/core/safe_file.gd")
const FENCE := "fence@-123,456"
const CRATE := "camp_crates@80,-35"


static func check(out: PackedStringArray, ok: bool, description: String) -> void:
	out.append(("PASS" if ok else "FAIL") + " things " + description)


static func _disk(v: S.Village, compress: bool) -> Dictionary:
	return JSON.parse_string(JSON.stringify(Codec.to_data(v, compress)))


static func _text(v: S.Village) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(Codec.to_data(v, false))))


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var v: S.Village = preload("res://scripts/studio/village/sim/runtime.gd").create(16838, {"anchored": true})
	var t0 := People.tick(v)

	# The shape.
	check(out, Things.id_at("fence", -12.34, 45.6) == FENCE and Things.valid_id(CRATE) and not Things.valid_id("fence") and not Things.valid_id("@1,2")
		and not Things.valid_id("fence@1.5,2"), "ids are <kind>@<x dm>,<z dm>")
	var burn := Things.put(v, FENCE, "burning", "deed:fire", {"heat": 600, "until_tick": t0 + 5000})
	var again := Things.put(v, FENCE, "burning", "deed:fire", {"heat": 700, "until_tick": t0 + 6000})
	check(out, burn.kind == "burning" and burn.deed == "deed:fire" and burn.revision == 1 and burn.since_tick == t0 and again.revision == 2
		and Things.get_fact(v, FENCE, "burning").heat == 700, "a fact is one row per kind; its revision counts its writes")
	var refused := [Things.put(v, "fence", "burning", "d", {"heat": 1, "until_tick": 1}), Things.put(v, FENCE, "melting", "d", {}),
		Things.put(v, FENCE, "soaked", "d", {"method": "rain"}), Things.put(v, FENCE, "broken", "", {"by": "x"})]
	check(out, refused.all(func(r: Dictionary) -> bool: return r.is_empty()) and v.thing_facts.size() == 1 and v.thing_facts[FENCE].size() == 1,
		"a bad id, an unknown kind, a missing field or no deed writes nothing")
	Things.put(v, FENCE, "scorched", "deed:fire", {"level": 300})
	var struck := Things.put(v, CRATE, "struck", "deed:blow", {"from": "player:local", "force": 400, "n": 1})
	Things.put(v, CRATE, "soaked", "deed:douse", {"method": "bucket", "until_tick": t0 + 3000})
	Things.put(v, CRATE, "broken", "deed:blow", {"by": "player:local"})
	var paced := Things.put(v, FENCE, "burning", "deed:fire", {"heat": 700, "until_tick": t0 + 6000, "due_tick": t0 + 200})
	check(out, paced.due_tick == t0 + 200 and Things.next_due(v) == t0 + 200, "a rule's own due_tick on a row is the next moment due")
	v.runtime.now = int(v.runtime.now) + 1 # 500 ticks
	var reported := Things.advance(v)
	var due_only: bool = reported.size() == 1 and reported[0].kind == "burning" and not reported[0].ended and Things.get_fact(v, FENCE, "burning").has("due_tick")
	Things.put(v, FENCE, "burning", "deed:fire", {"heat": 700, "until_tick": t0 + 6000})
	check(out, due_only and Things.next_due(v) == t0 + Things.STRUCK_MS, "advance reports a due_tick that came and keeps its row; the rule moves it")
	check(out, struck.until_tick == t0 + Things.STRUCK_MS and Things.next_due(v) == t0 + Things.STRUCK_MS, "struck is short-lived: it ends STRUCK_MS after the blow unless told otherwise")

	# The codec: lasting kinds kept, struck and malformed rows dropped at load, older saves load empty.
	for compress: bool in [false, true]:
		var back := Codec.from_data(_disk(v, compress))
		var want: Dictionary = v.thing_facts.duplicate(true)
		want[CRATE].erase("struck")
		check(out, back != null and JSON.stringify(back.thing_facts) == JSON.stringify(want),
			"saved and loaded (%s): burning, scorched, soaked and broken kept field for field; struck gone" % ("packed" if compress else "plain"))
	var broken_save := v.thing_facts.duplicate(true)
	broken_save["no id"] = {"burning": {"kind": "burning"}}
	broken_save[FENCE]["scorched"] = {"kind": "scorched", "deed": "x"} # no level, no revision
	var held := v.thing_facts
	v.thing_facts = broken_save
	var damaged := Codec.from_data(_disk(v, false))
	v.thing_facts = held
	check(out, damaged != null and not damaged.thing_facts.has("no id") and not damaged.thing_facts[FENCE].has("scorched")
		and damaged.thing_facts[FENCE].has("burning") and damaged.thing_facts[CRATE].keys() == ["soaked", "broken"],
		"rows not in the agreed shape are dropped at load, the rest kept")
	var older := _disk(v, false)
	older.state.fields.erase("thing_facts")
	var old_v := Codec.from_data(older)
	check(out, old_v != null and old_v.thing_facts.is_empty(), "a save from before thing facts loads with none")

	# Timed facts end in the batch that reaches their tick; lasting ones stay.
	v.runtime.now = int(v.runtime.now) + 6 # 3500 ticks in all (500 a game minute): past the blow and the douse, before the fire ends
	var ended := Things.advance(v)
	var kinds := ended.filter(func(e: Dictionary) -> bool: return e.ended).map(func(e: Dictionary) -> String: return e.kind)
	kinds.sort()
	check(out, People.tick(v) - t0 >= 3000 and People.tick(v) - t0 < 6000 and kinds == ["soaked", "struck"] and v.thing_facts[FENCE].has("burning")
		and v.thing_facts[CRATE].keys() == ["broken"], "advance ends what is due (struck, soaked) and keeps the rest (%s)" % str(kinds))

	_journal(out, v)
	return out


## Accepted batches through the image and the journal, guard on; a reload equals the live village.
static func _journal(out: PackedStringArray, v: S.Village) -> void:
	var path := "user://studio-test-thing-facts.json"
	SafeFile.remove(path)
	if FileAccess.file_exists(path + ".journal"):
		DirAccess.remove_absolute(path + ".journal")
	var journal = Journal.new(path)
	var previous = VillageSession.village
	VillageSession.village = v
	VillageImage.guard = true
	var save_id := "thing-facts-%d" % randi()
	var text := JSON.stringify({"version": 1, "save_id": save_id, "village": Codec.to_data(v, true)})
	var written := SafeFile.write_text(path, text)
	journal.rebase(save_id, text)
	VillageImage.rebase(v, true)
	var writer := func() -> int: return journal.append({"village": VillageImage.staged.line})
	var t := People.tick(v)
	# Batches that name their fields (as the bridge's and people_actions' do): only the touched field is compared.
	var lit: Dictionary = Accept.transact(func(live) -> Dictionary:
		VillageImage.hinting()
		return {"accepted": not Things.put(live, "bench@10,20", "burning", "deed:torch", {"heat": 500, "until_tick": t + 900}).is_empty()}, writer)
	var hit: Dictionary = Accept.transact(func(live) -> Dictionary:
		VillageImage.hinting()
		return {"accepted": not Things.put(live, "bench@10,20", "struck", "deed:kick", {"from": [1.0, 2.0], "force": 250, "n": 2}).is_empty()}, writer)
	var drift := VillageImage.verify(v)
	v.runtime.now = int(v.runtime.now) + 2 # 1000 ticks: the torch fire (900) and the kick (1000) are due
	var cooled: Dictionary = Accept.transact(func(live) -> Dictionary:
		var gone := Things.advance(live)
		for e: Dictionary in gone:
			if e.kind == "burning":
				Things.put(live, e.thing, "scorched", str(e.row.deed), {"level": 500})
		return {"accepted": not gone.is_empty()}, writer)
	var refused: Dictionary = Accept.transact(func(live) -> Dictionary:
		VillageImage.hinting()
		Things.put(live, "rack@0,0", "broken", "deed:refused", {"by": "nobody"})
		return {"accepted": false}, writer)
	check(out, written == OK and lit.get("accepted", false) and hit.get("accepted", false) and cooled.get("accepted", false) and drift.is_empty()
		and journal.seq == 3 and v.thing_facts["bench@10,20"].keys() == ["scorched"] and not refused.get("accepted", true) and not v.thing_facts.has("rack@0,0"),
		"named batches write thing facts as journal lines, the guard silent; a refused batch is put back (%d lines, %d bytes)" % [journal.seq, journal.bytes])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var back = Codec.from_data(Journal.replay(data, path + ".journal").village)
	check(out, back != null and _text(back) == _text(v), "the full save plus its journal reloads to exactly the live village")
	# A write outside acceptance is seen by the exact compare.
	v.thing_facts[FENCE]["scorched"].level = 999
	var seen := VillageImage.verify(v)
	check(out, seen.size() == 1 and str(seen[0]).begins_with("field thing_facts"), "a write outside acceptance is seen by the guard's exact compare (%s)" % str(seen))
	VillageImage.rebase(v, false)
	VillageImage.guard = false
	VillageSession.village = previous
	SafeFile.remove(path)
	if FileAccess.file_exists(path + ".journal"):
		DirAccess.remove_absolute(path + ".journal")
