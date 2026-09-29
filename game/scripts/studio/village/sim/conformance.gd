extends RefCounted
## Conformance and timing for the village simulation port.
## Runs every golden case (golden_data.gd, written by tools-src/studio/village-reference/golden.mjs) and
## compares every 30-day checkpoint on all six columns: day, village hash, event-log hash, events so far,
## the hash of the stagings made since the last checkpoint, and how many. Reports the first mismatch per
## case (or PASS) and the time the simulation took (ms per village-year and per village-day).
##   godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/conformance
## On a phone: the dev argument --studio=village/sim/conformance (on_device), report saved to
## user://studio-village-conformance.txt.

const R := preload("res://scripts/studio/village/sim/rng.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Golden := preload("res://scripts/studio/village/sim/golden_data.gd")

const COLUMNS := ["day", "village hash", "event-log hash", "events", "staging hash", "stagings"]


## golden.mjs hashStagings: the stagings made since the last checkpoint (strings through str_key).
static func hash_stagings(list: Array) -> String:
	var h := R.FNV
	for st: Dictionary in list:
		h = R.key(h, st["id"]); h = R.key(h, R.str_key(st["kind"])); h = R.key(h, R.str_key(st["place"])); h = R.key(h, st["start"]); h = R.key(h, st["end"]); h = R.key(h, R.str_key(st["outcome"]))
		for b: Dictionary in st["beats"]:
			h = R.key(h, b["at"]); h = R.key(h, b["who"]); h = R.key(h, R.str_key(b["do"])); h = R.key(h, b["slot"]); h = R.key(h, b["target"]); h = R.key(h, R.str_key(b["anim"])); h = R.key(h, R.str_key(b["prop"]))
		for p: Dictionary in st["people"]:
			h = R.key(h, p["id"]); h = R.key(h, p["outfit"])
	return "%08x" % h


## One golden case: returns {"ok", "mismatch", "usec", "days", "final"}.
static func run_case(c: Dictionary) -> Dictionary:
	var V := Village.create_village(c["seed"], {"pace": c["pace"]})
	var days: int = c["years"] * Village.YEAR
	var checks: Array = c["checks"]
	var ci := 0
	var last_staging := -1
	var mismatch := ""
	var usec := 0
	var matched := 0
	for d in range(1, days + 1):
		var t0 := Time.get_ticks_usec()
		Village.step_day(V)
		usec += Time.get_ticks_usec() - t0
		if d % Golden.EVERY != 0:
			continue
		var fresh := []
		for st in V.stagings:
			if st["id"] > last_staging:
				fresh.append(st)
		if fresh.size() > 0:
			last_staging = fresh[fresh.size() - 1]["id"]
		var got := [V.day, Village.hash_village(V), "%08x" % V.ev_hash, V.events.size(), hash_stagings(fresh), fresh.size()]
		var want: Array = checks[ci] if ci < checks.size() else []
		ci += 1
		if mismatch == "" and want.size() == got.size():
			for col in got.size():
				if str(got[col]) != str(want[col]):
					mismatch = "day %d, %s: expected %s, got %s" % [V.day, COLUMNS[col], str(want[col]), str(got[col])]
					break
			if mismatch == "":
				matched += 1
	var final := {"people": V.people.size(), "events": V.events.size(), "crimes": V.crimes.size(), "cases": V.cases.size(), "stagings": V.staging_count}
	if mismatch == "" and ci != checks.size():
		mismatch = "%d checkpoints, the reference has %d" % [ci, checks.size()]
	if mismatch == "":
		var want_final: Dictionary = c["final"]
		for key: String in want_final:
			if int(want_final[key]) != int(final[key]):
				mismatch = "final %s: expected %d, got %d" % [key, want_final[key], final[key]]
				break
	return {"ok": mismatch == "", "mismatch": mismatch, "usec": usec, "days": days, "final": final, "matched": matched, "checks": checks.size()}


@warning_ignore("integer_division")
static func conform(say: Callable) -> bool:
	var ok := true
	var by_pace := {}
	for c: Dictionary in Golden.CASES:
		var r := run_case(c)
		var years: int = c["years"]
		var ms_year: float = r["usec"] / 1000.0 / years
		var ms_day: float = r["usec"] / 1000.0 / r["days"]
		var f: Dictionary = r["final"]
		say.call("seed %d pace %d, %d years: %s (%d of %d checkpoints x 6 columns)  [%.1f ms per village-year, %.3f ms per village-day; %d people, %d events, %d crimes, %d cases, %d stagings]" % [
			c["seed"], c["pace"], years, "PASS" if r["ok"] else "FAIL, first mismatch at " + r["mismatch"], r["matched"], r["checks"], ms_year, ms_day,
			f["people"], f["events"], f["crimes"], f["cases"], f["stagings"]])
		ok = ok and r["ok"]
		var pace: int = c["pace"]
		if not by_pace.has(pace):
			by_pace[pace] = [0, 0]
		by_pace[pace][0] += r["usec"]
		by_pace[pace][1] += years
	for pace: int in by_pace:
		say.call("pace %d: %.1f ms per village-year (all cases at this pace)" % [pace, by_pace[pace][0] / 1000.0 / by_pace[pace][1]])
	say.call("CONFORMANCE: %s" % ("PASS" if ok else "FAIL"))
	return ok


static func report() -> PackedStringArray:
	var lines := PackedStringArray()
	conform(func(s: String) -> void: lines.append(s))
	return lines


## The phone entry point (dev argument --studio=village/sim/conformance): every line goes to the log and to
## user://studio-village-conformance.txt, then the game quits.
static func on_device(tree: SceneTree) -> void:
	var lines := PackedStringArray()
	var say := func(s: String) -> void:
		lines.append(s)
		print("VILLAGE ", s)
	say.call("device: %s, %s, %s, %d cores" % [OS.get_model_name(), OS.get_name(), OS.get_processor_name(), OS.get_processor_count()])
	say.call("engine: Godot %s, %s build" % [Engine.get_version_info()["string"], "debug" if OS.is_debug_build() else "release"])
	conform(say)
	var f := FileAccess.open("user://studio-village-conformance.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	tree.quit()
