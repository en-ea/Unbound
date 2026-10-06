extends RefCounted
## The save codec (save.gd), checked headless: run.gd -- village/sim/save_test
## Old saves still load, the new format keeps the canonical state through save, load and continuation,
## past stagings and layout tables stay out, dead people are thin, damage is refused.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")


## What the disk does to a payload: text, and back (every number a float).
static func _disk(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


## The canonical state: every field readable, numbers as the disk gives them.
static func _canon(v: S.Village) -> String:
	return JSON.stringify(_disk(Save.to_data(v, false)))


static func _through(v: S.Village, compress: bool = true) -> S.Village:
	return Save.from_data(_disk(Save.to_data(v, compress)))


static func _advance(v: S.Village, minutes: int) -> void:
	Runtime.advance(v, int(v.runtime.now) + minutes)


## A village with an open event of this type, advanced the way the game does it.
static func _open(type: String, seeds: Array) -> S.Village:
	for seed: int in seeds:
		var v := Runtime.create(seed)
		for _day in 120:
			_advance(v, 1440)
			for e: Dictionary in v.runtime.events:
				if e.type == type and not Runtime.terminal(e):
					_advance(v, maxi(0, int(e.from) - int(v.runtime.now)))
					return v
	return null


static func _staged(v: S.Village) -> Array[int]:
	var ids: Array[int] = []
	for st: Dictionary in v.stagings:
		ids.append(int(st.id))
	return ids


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var check := func(ok: bool, what: String) -> void:
		out.append(("PASS " if ok else "FAIL ") + what)

	# 1. A save written by the first codec loads and carries on exactly like the village it came from.
	for spec: Array in [["hearing", [16838]], ["public", [1]], ["rite", [3, 5, 8, 13]]]:
		var v := _open(spec[0], spec[1])
		if v == null:
			out.append("SKIP old format with an open %s: none found" % spec[0])
			continue
		var old := _disk(Save.to_data_v1(v))
		var loaded := Save.from_data(old)
		check.call(Save.valid(old) and loaded != null and old.version == 1, "old format (open %s): valid and loads" % spec[0])
		if loaded != null:
			_advance(v, 3 * 1440)
			_advance(loaded, 3 * 1440)
			check.call(Village.hash_village(v) == Village.hash_village(loaded) and v.ev_hash == loaded.ev_hash and _canon(v) == _canon(loaded),
				"old format (open %s): three days on, the same village" % spec[0])

	# 2. The new format: what is saved, what is not, and that the payload is smaller for it.
	var v := _open("hearing", [16838])
	if v == null:
		return ["FAIL save: no hearing to test with"]
	var data := Save.to_data(v, false)
	var fields: Dictionary = data.state.fields
	check.call(data.version == Save.VERSION and data.layout == "meadow", "new format written, meadow layout")
	var absent := true
	for name: String in ["homes", "place_names", "place_ids", "place_x", "place_z", "place_has_pos", "place_pen", "place_rank", "dist2",
			"n_places", "pl_square", "pl_shrine", "pl_pillory", "pl_home_word", "pl_far_woods", "pl_road", "pl_woods", "pl_well", "role_work"]:
		absent = absent and not fields.has(name)
	check.call(absent, "no layout tables in the payload")
	var open_ids := {}
	for e: Dictionary in v.runtime.events:
		if not Runtime.terminal(e) or int(e.end) > int(v.runtime.now):
			open_ids[int(e.id)] = true
	for a in v.pending:
		open_ids[a.staging] = true
	for list: String in ["hearings", "rites"]:
		for a: Dictionary in v.runtime.get(list, []):
			open_ids[int(a.staging)] = true
	var kept: int = _disk(data).state.fields.stagings.size()
	check.call(not open_ids.is_empty() and v.stagings.size() > open_ids.size() and kept == open_ids.size(),
		"only the stagings something still needs: %d of %d kept, %d open acts" % [kept, v.stagings.size(), open_ids.size()])
	var back := _through(v, false)
	check.call(back != null, "new format loads")
	if back == null:
		return out
	var tables := back.place_names == v.place_names and back.dist2 == v.dist2 and back.place_ids == v.place_ids and back.role_work == v.role_work \
		and back.place_x == v.place_x and back.place_z == v.place_z and back.place_rank == v.place_rank and back.pl_pillory == v.pl_pillory \
		and back.homes == v.homes and back.n_places == v.n_places and back.pl_far_woods == v.pl_far_woods
	check.call(tables, "layout tables rebuilt as they were")
	var staged_ok := true
	for id in open_ids:
		staged_ok = staged_ok and not Runtime.staging(back, id).is_empty()
	check.call(staged_ok, "every open act still has its staging after a load")
	check.call(back.staging_count == v.staging_count, "the next staging id carries on")
	var thin := true
	var full := 0
	var dead := 0
	for p in back.people:
		if not p.alive or p.faded:
			dead += 1
			thin = thin and p.beliefs.is_empty() and p.rel_k.is_empty() and p.grudge_k.is_empty() and p.plan.is_empty()
		elif p.alive and p.present:
			full += p.rel_k.size()
	check.call(dead > 0 and thin and full > 0, "%d dead or faded people saved thin; the living keep their %d feelings" % [dead, full])
	check.call(_canon(v) == _canon(back), "save and load: the same canonical state")
	var packed := _through(v, true)
	check.call(packed != null and _canon(packed) == _canon(v), "compressed save loads to the same state")
	_advance(v, 1441)
	_advance(back, 1441)
	_advance(packed, 1441)
	check.call(_canon(v) == _canon(back) and _canon(v) == _canon(packed), "a day on: the same canonical state (open, compressed)")
	for _i in 60:
		_advance(v, 1440)

	# 3. Save and load again and again, in chunks of every size, against a run that never stops.
	var stress_ok := true
	var stress_days := 0
	var stress_open := 0
	for seed: int in [1, 7, 16838, 48514]:
		var whole := Runtime.create(seed)
		var cut := Runtime.create(seed)
		var sizes := [17, 61, 240, 1439, 1440, 2900]
		var step := 0
		var horizon := 200 if seed == 7 else 100
		while int(whole.runtime.now) < horizon * 1440:
			var chunk: int = sizes[(step + seed) % sizes.size()]
			step += 1
			_advance(whole, chunk)
			_advance(cut, chunk)
			if not Save._kept_stagings(cut).is_empty():
				stress_open += 1
			cut = _through(cut, step % 2 == 0)
			if cut == null:
				stress_ok = false
				out.append("FAIL stress: seed %d did not reload at step %d" % [seed, step])
				break
		if cut != null and _canon(whole) != _canon(cut):
			stress_ok = false
			out.append("FAIL stress: seed %d, saving and loading %d times changed the state" % [seed, step])
		stress_days += horizon
	check.call(stress_ok and stress_open > 20, "canonical continuation: %d village-days saved and reloaded in chunks from 17 minutes to 2 days (%d of the saves with an open act)" % [stress_days, stress_open])

	# 4. Damage is refused, and the runtime's new event type is accepted.
	var good := _disk(Save.to_data(v, true))
	var damaged := good.duplicate(true)
	damaged.state.fields.people = ["bad resident"]
	check.call(Save.valid(good) and not Save.valid(damaged), "a damaged people list is refused")
	damaged = good.duplicate(true)
	damaged.state.fields.events = [[1, 2, 3, "x", "y", "z", "w", [], [1]]]
	damaged.state.fields.crimes = {"z": "AAAA", "n": 20, "m": "zstd"}
	check.call(not Save.valid(damaged), "a corrupt blob is refused")
	damaged = good.duplicate(true)
	damaged.schemas["Nobody"] = ["id"]
	check.call(not Save.valid(damaged), "an unknown class is refused")
	damaged = good.duplicate(true)
	damaged.state.fields.erase("runtime")
	check.call(not Save.valid(damaged), "a missing runtime is refused")
	check.call(not Save.valid({"version": 3, "state": {}}) and not Save.valid({"version": "x"}) and not Save.valid({}), "unknown versions are refused")
	var incident := _through(v, false)
	var template: Dictionary = {}
	for e: Dictionary in incident.runtime.events:
		if not Runtime.terminal(e):
			template = e.duplicate(true)
			break
	if template.is_empty():
		template = {"id": 999999, "revision": 0, "type": "public", "victim": 0, "place": "square", "from": int(v.runtime.now) + 5,
			"deadline": int(v.runtime.now) + 30, "end": int(v.runtime.now) + 60, "phase": "prepared", "outcome": "", "shields": [],
			"witnesses": [], "actors": [0], "testimony": [], "bribe": "", "challenge": 0, "source": null}
	template.id = 999999
	template.type = "incident"
	template.source = null
	template.phase = "resolved"
	template.end = 0
	incident.runtime.events.append(template)
	var with_null := _disk(Save.to_data(incident, true))
	check.call(Save.valid(with_null), "an incident with no source is accepted")
	var source := S.Sched.new()
	source.kind = "trial"
	var with_source_event: Dictionary = template.duplicate(true)
	with_source_event.id = 999998
	with_source_event.source = source
	incident.runtime.events.append(with_source_event)
	check.call(Save.valid(_disk(Save.to_data(incident, true))), "an incident with a source is accepted")
	var hearing_event: Dictionary = template.duplicate(true)
	hearing_event.id = 999997
	hearing_event.type = "hearing"
	hearing_event.source = null
	incident.runtime.events.append(hearing_event)
	check.call(not Save.valid(_disk(Save.to_data(incident, true))), "a hearing with no source is still refused")

	# 5. A village that is not on the meadow layout keeps its tables (nothing to rebuild them from).
	var odd := Runtime.create(2, {"layout": {"homes": ["cottage", "cabin", "round", "hill", "lodge", "loaf"],
		"pos": Village.MEADOW.pos.merged({"square": [16, 181]}, true)}})
	var odd_data := _disk(Save.to_data(odd))
	var odd_back := Save.from_data(odd_data)
	check.call(odd_data.layout == "saved" and odd_back != null and odd_back.dist2 == odd.dist2 and odd_back.place_x == odd.place_x, "a village on another layout keeps its tables")
	# a place the rules named on the fly is carried too
	var named := Runtime.create(3)
	Village.place_id(named, "somewhere_new")
	var named_data := _disk(Save.to_data(named))
	var named_back := Save.from_data(named_data)
	check.call(named_data.layout == "meadow" and named_data.extra_places == ["somewhere_new"] and named_back != null and named_back.place_names == named.place_names 		and named_back.place_ids == named.place_ids and named_back.dist2 == named.dist2, "a place added on the fly survives a load")
	# 6. Every new game gets the same home village; other seeds are for testing (and, later, villages found on the map).
	check.call(Save.new_seed(PackedStringArray()) == Save.HOME_SEED and Save.new_seed(PackedStringArray()) == Save.HOME_SEED, "a new game gets the home village, the same for everyone (seed %d)" % Save.HOME_SEED)
	check.call(Save.new_seed(PackedStringArray(["--test-save=x", "--village-soon"])) == Save.HOME_SEED, "a dev or test run gets the home village too")
	check.call(Save.new_seed(PackedStringArray(["--test-save=x", "--village-seed=4242"])) == 4242, "--village-seed=N sets it")
	var drawn := [Save.new_seed(PackedStringArray(["--village-seed=random"])), Save.new_seed(PackedStringArray(["--village-seed=random"])), Save.new_seed(PackedStringArray(["--village-seed=random"]))]
	check.call(drawn.all(func(n: int) -> bool: return n >= 1) and (drawn[0] != drawn[1] or drawn[1] != drawn[2]), "--village-seed=random draws a fresh one for testing (%s)" % str(drawn))
	var mine := Runtime.create(4242)
	check.call(_through(mine).seed == 4242 and _through(mine).runtime.village == "wenbrook:4242", "the seed is kept in the save with the village")
	# 7. A save from before an authored stand moved (Brakk's, 2 Oct: his entry still has the old spot): it loads with
	# the spot where the table has him now, and the same tables as a village made since.
	var moved := Runtime.create(5)
	Runtime.attach(moved)
	for entry: Dictionary in moved.runtime.authored:
		if entry.id == "brakk":
			entry.x = -135
			entry.z = 110
	var moved_back := Save.from_data(_disk(Save.to_data(moved)))
	var spot: int = moved_back.place_ids.get("spot_brakk", -1) if moved_back != null else -1
	check.call(spot >= 0 and moved_back.place_x[spot] == -108 and moved_back.place_z[spot] == 72 and moved_back.dist2 == moved.dist2,
		"a save from before Brakk's stand moved loads with his spot where he stands now")
	var fails := 0
	for line in out:
		fails += 1 if line.begins_with("FAIL") else 0
	out.append("SAVE: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	return out
