extends RefCounted
## Conformance and timing for the world kernel.
## - conform(): the kernel must reproduce golden.gd (written from the JavaScript reference): the world
##   hash at every 25-year checkpoint for 20 seeds, four scenarios (an edit to the past, two players'
##   logs merged in two orders, two time storms) and the hash of a whole chronicle's text.
## - bench(): the S1 timings, measured here instead of in JavaScript.
## Used by run.gd (headless, on the PC) and by the dev argument --kernel-bench (on phones).

const World := preload("res://scripts/studio/kernel/world.gd")
const History := preload("res://scripts/studio/kernel/history.gd")
const Chronicle := preload("res://scripts/studio/kernel/chronicle.gd")
const Golden := preload("res://scripts/studio/kernel/golden.gd")


static func _rows(actions: Array) -> Array:
	var out := []
	for row: Array in actions:
		out.append(PackedInt32Array(row))
	return out


static func _ms(usec: int) -> String:
	return "%.1f ms" % (usec / 1000.0)


@warning_ignore("integer_division")
static func _median(values: Array) -> int:
	var v := values.duplicate()
	v.sort()
	return v[v.size() / 2]


static func chronicle_hash(text: String) -> String:
	var h := World.FNV
	for byte in text.to_utf8_buffer():
		h = World.key(h, byte)
	return "%08x" % h


## Returns true when every golden value is reproduced.
@warning_ignore("integer_division")
static func conform(say: Callable) -> bool:
	var ok := true
	var t0 := Time.get_ticks_usec()
	var matched := 0
	var total := 0
	for s: int in Golden.SEEDS:
		var hist := History.new(s)
		var w := hist.run(Golden.YEARS)
		var expect: Array = Golden.CHECKPOINTS[s]
		for i in expect.size():
			var got := w.hash_hex() if i == expect.size() - 1 else (hist.checkpoints[i * Golden.EVERY] as World).hash_hex()
			total += 1
			if got == expect[i]:
				matched += 1
			else:
				say.call("  FAIL seed %d first diverges by year %d: %s, reference %s" % [s, i * Golden.EVERY, got, expect[i]])
				ok = false
				break
		if w.n != Golden.SETTLEMENTS[s] or w.ev_year.size() != Golden.EVENTS[s]:
			say.call("  FAIL seed %d: %d settlements, %d events; reference %d, %d" % [s, w.n, w.ev_year.size(), Golden.SETTLEMENTS[s], Golden.EVENTS[s]])
			ok = false
	say.call("checkpoint hashes: %d / %d match the reference (%d seeds x %d checkpoints) [%s]" % [matched, total, Golden.SEEDS.size(), Golden.YEARS / Golden.EVERY + 1, _ms(Time.get_ticks_usec() - t0)])
	for sc: Dictionary in Golden.SCENARIOS:
		var acts := _rows(sc["actions"])
		var got := History.new(sc["seed"], acts).run(sc["to"]).hash_hex()
		var line := "scenario %s: %s" % [sc["name"], got]
		if sc["name"] == "two-players-merged":
			var flipped := acts.duplicate()
			flipped.reverse()
			var got2 := History.new(sc["seed"], flipped).run(sc["to"]).hash_hex()
			line += " / other arrival order %s" % got2
			if got2 != got:
				ok = false
		if got == sc["hash"]:
			say.call(line + "  ok")
		else:
			say.call(line + "  FAIL, reference %s" % sc["hash"])
			ok = false
	var cw := History.new(Golden.CHRONICLE_SEED).run(Golden.YEARS)
	var ch := chronicle_hash(Chronicle.text(cw))
	var ch_ok: bool = ch == Golden.CHRONICLE_HASH and cw.ev_year.size() == Golden.CHRONICLE_LINES
	say.call("chronicle text, seed %d: %d lines, %s  %s" % [Golden.CHRONICLE_SEED, cw.ev_year.size(), ch, "ok" if ch_ok else "FAIL, reference %s" % Golden.CHRONICLE_HASH])
	ok = ok and ch_ok
	say.call("CONFORMANCE: %s" % ("PASS" if ok else "FAIL"))
	return ok


@warning_ignore("integer_division")
static func bench(say: Callable, seeds: int = 20) -> void:
	var years: int = Golden.YEARS
	History.new(Golden.SEEDS[0]).run(years)   # warm up
	# 1. whole histories
	var times := []
	var worst := 0
	var settlements := []
	var events := []
	for i in seeds:
		var t0 := Time.get_ticks_usec()
		var w := History.new(Golden.SEEDS[i % Golden.SEEDS.size()]).run(years)
		var dt := Time.get_ticks_usec() - t0
		times.append(dt)
		worst = maxi(worst, dt)
		settlements.append(w.n)
		events.append(w.ev_year.size())
	say.call("500 years of history: median %s, worst %s over %d seeds (%d settlements, %d events, median)" % [_ms(_median(times)), _ms(worst), seeds, _median(settlements), _median(events)])
	# 2. checkpoints
	var hist := History.new(Golden.SEEDS[3])
	var today := hist.run(years)
	var bytes := 0
	for cp: World in hist.checkpoints.values():
		bytes += var_to_bytes([cp.people, cp.x, cp.y, cp.pop, cp.food, cp.tech, cp.lost, cp.river, cp.ore, cp.founded, cp.parent, cp.ruined, cp.had_mill, cp.flood_proof, cp.era, cp.enclave_of, cp.names, cp.rel]).size()
	say.call("checkpoints: %d, %d KB in total" % [hist.checkpoints.size(), bytes / 1024])
	# 3. a time-storm view of any year
	var t1 := Time.get_ticks_usec()
	var then := hist.state_at(287)
	say.call("the world at year 287 (a storm's view): %s, %d settlements" % [_ms(Time.get_ticks_usec() - t1), then.n])
	# 4. edit the past and re-simulate to today
	var edit := History.new(Golden.SEEDS[3], [PackedInt32Array([240, 1, 1, World.A_WARN, 2, 20, 0])])
	edit.checkpoints = hist.checkpoints.duplicate()
	var t2 := Time.get_ticks_usec()
	var edited := edit.resume(hist.checkpoints[225], years)
	say.call("edit year 240, re-simulate to year 500 from the checkpoint: %s (%s)" % [_ms(Time.get_ticks_usec() - t2), edited.hash_hex()])
	# 5. catch-up after 30 days away (one world-year a day)
	var t3 := Time.get_ticks_usec()
	var later := hist.resume(today, years + 30)
	say.call("catch-up, 30 years: %s (%d settlements)" % [_ms(Time.get_ticks_usec() - t3), later.n])
	# 6. a time storm: fold 60%% of a village into year 350, and the 25 years after
	var sc: Dictionary = Golden.SCENARIOS[2]
	var t4 := Time.get_ticks_usec()
	History.new(sc["seed"], _rows(sc["actions"])).run(sc["to"])
	say.call("a storm scenario, 525 years from scratch: %s" % _ms(Time.get_ticks_usec() - t4))


## The phone entry point (dev argument --kernel-bench): conformance, then timings; every line goes
## to the log (adb logcat) and to user://studio-kernel.txt, then the game quits.
static func on_device(tree: SceneTree) -> void:
	var lines := PackedStringArray()
	var say := func(s: String) -> void:
		lines.append(s)
		print("KERNEL ", s)
	say.call("device: %s, %s, %s, %d cores" % [OS.get_model_name(), OS.get_name(), OS.get_processor_name(), OS.get_processor_count()])
	say.call("engine: Godot %s, %s build" % [Engine.get_version_info()["string"], "debug" if OS.is_debug_build() else "release"])
	conform(say)
	bench(say)
	var f := FileAccess.open("user://studio-kernel.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	tree.quit()
