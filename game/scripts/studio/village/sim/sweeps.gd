extends RefCounted
## Long-run invariants in GDScript alone: many villages for a long time (with a storm now and then), checking
## the rules that must never break. Port of tools-src/studio/village-reference/invariants.mjs, same checks,
## same output. The JavaScript reference is frozen; this is how the rules are checked from here on.
##
##   godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/sweeps [seeds] [years] [pace] [focus] [runtime]
##
## Positional, after the spike name (all optional, in any order after the three numbers):
##   seeds  villages to run (default 4; the reference's default was 20)
##   years  village years each, 60 days a year (default 100; the reference's was 1000)
##   pace   how dense life is (default 1 in batch mode, the game's own 10 in runtime mode)
##   focus  the player's village, paced by play time (default off in batch mode, on in runtime mode; nofocus turns it off)
##   batch  (default) Village.create_village and Village.step_day, like invariants.mjs
##   runtime  the shipped game's path: Runtime.create, then Runtime.advance one game day at a time; public acts
##            resolve by themselves at their deadlines. Slower: it carries the clock, events and stagings.
## The output is the reference's: one summary line, then PASS or FAIL with the first 40 problems.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")

const EXEMPT := {"omen": true, "storm": true, "feud": true}   # things that simply happen (the kernel's, the sky's, the grudge's sum)
const LETHAL_KINDS := ["hanging", "bonfire", "stoning", "mob", "sacrifice"]
const MAX_FAILS := 40


## JavaScript truthiness for the two things the checks test: an event's motive and its cue.
static func _truthy(x: Variant) -> bool:
	match typeof(x):
		TYPE_NIL:
			return false
		TYPE_STRING:
			return not (x as String).is_empty()
		TYPE_INT:
			return x != 0
		TYPE_BOOL:
			return x
	return true


## A village of this run: a storm every century or so on a keyed household, for a season (the reference's plan).
static func _village(seed: int, years: int, pace: int, focus: bool, runtime: bool) -> S.Village:
	var plan := []
	var y := 50
	while y < years:
		plan.append({"day": y * Village.YEAR + 20, "household": (seed + y) % 6, "days": 90})
		y += 97
	var opts := {"pace": pace, "stormPlan": plan, "focus": focus}
	return Runtime.create(seed, opts) if runtime else Village.create_village(seed, opts)


## One day on: a step of the rules, or a game day of the runtime (the clock carries on from where it is).
static func _day(v: S.Village, runtime: bool) -> void:
	if runtime:
		Runtime.advance(v, int(v.runtime.now) + Village.DAY)
	else:
		Village.step_day(v)


static func _hash(v: S.Village) -> String:
	return "%s/%d" % [Village.hash_village(v), v.ev_hash]


static func report() -> PackedStringArray:
	var numbers: Array[int] = []
	var runtime := false
	var focus_arg := ""
	var args := OS.get_cmdline_user_args()
	for i in range(1, args.size()):
		if args[i] == "runtime":
			runtime = true
		elif args[i] in ["focus", "nofocus"]:
			focus_arg = args[i]
		elif args[i] != "batch" and args[i].is_valid_int():
			numbers.append(int(args[i]))
	var seeds: int = numbers[0] if numbers.size() > 0 else 4
	var years: int = numbers[1] if numbers.size() > 1 else 100
	var pace: int = numbers[2] if numbers.size() > 2 else (10 if runtime else 1)
	var focus: bool = (focus_arg == "focus") if not focus_arg.is_empty() else runtime

	var fails := PackedStringArray()
	var fail := func(seed: int, msg: String) -> void:
		if fails.size() < MAX_FAILS:
			fails.append("seed %d: %s" % [seed, msg])
	var total_ms := 0.0
	var min_alive := 1000000000
	var max_alive := 0
	var events := 0
	for s in seeds:
		var seed := 5000 + s * 7919
		var t0 := Time.get_ticks_usec()
		var V := _village(seed, years, pace, focus, runtime)
		var stuck := {}
		# a runtime village has already taken its first day (Runtime.create), as the reference's d = 0 step
		for d in years * Village.YEAR:
			if d > 0 or not runtime:
				_day(V, runtime)
			if d % Village.YEAR == 0:
				var alive := 0
				for p in V.people:
					if p.alive and p.present:
						alive += 1
				min_alive = mini(min_alive, alive)
				max_alive = maxi(max_alive, alive)
				if alive < 6:
					fail.call(seed, "year %d: only %d alive" % [d / Village.YEAR, alive])
				for p in V.people:
					if p.alive and (typeof(p.stress) != TYPE_INT or typeof(p.hunger) != TYPE_INT or typeof(p.guilt) != TYPE_INT):
						fail.call(seed, "person %d has a non-integer state" % p.id)
				for h in V.households:
					if typeof(h.food) != TYPE_INT:
						fail.call(seed, "household %d food %s" % [h.id, str(h.food)])
				for c in V.cases:
					var cr := V.crimes[c.crime]
					if cr.case_open and not cr.closed and V.day - c.day > 120 and not stuck.has(c.id):
						stuck[c.id] = true   # (a stuck case is named once, the year it is first found; the reference names it every year)
						fail.call(seed, "case %d (%s) open for %d days" % [c.id, cr.act, V.day - c.day])
				var open := 0
				for c in V.crimes:
					if not c.closed:
						open += 1
				if open > 40 + 10 * pace:   # bounded (cold cases close after 60 days)
					fail.call(seed, "year %d: %d crimes open" % [d / Village.YEAR, open])
		total_ms += (Time.get_ticks_usec() - t0) / 1000.0
		events += V.events.size()
		for e in V.events:
			if not E.NOTABLE.has(e.type):
				continue
			if not _truthy(e.cue):
				fail.call(seed, "%s %d without a cue" % [e.type, e.id])
			if e.causes.is_empty() and not _truthy(e.data.get("motive")) and not EXEMPT.has(e.type):
				fail.call(seed, "%s %d (day %d) without a cause" % [e.type, e.id, e.day])
			if e.type == "crime" and e.data.get("act") in ["murder", "sacrifice"] and e.other >= 0 \
					and Village.age_of(V, V.people[e.other]) < 16 and V.people[e.other].died == e.day:
				fail.call(seed, "a child killed (%s)" % e.data.get("act"))
		# the violence budget: a lethal public act (or rite) sets a 15-day cooldown, so no two fall closer
		var last_lethal := -1000000000
		for e in V.events:
			var lethal: bool = (e.type == "public_act" and e.data.get("kind") in LETHAL_KINDS and e.data.get("outcome") == "carried_out") \
				or (e.type == "rite" and e.data.get("outcome") == "carried_out")
			if not lethal:
				continue
			if e.day - last_lethal < 15:
				fail.call(seed, "two lethal public acts %d days apart (day %d)" % [e.day - last_lethal, e.day])
			last_lethal = e.day
		for st in V.stagings:
			for b: Dictionary in st["beats"]:
				if b["do"] == "throw":
					var p := V.people[b["who"]]
					if p.born > st["day"] - 14 * Village.YEAR:
						fail.call(seed, "a child threw (%s, day %d)" % [st["kind"], st["day"]])
		for c in V.crimes:
			if c.act == "sacrifice" and Village.age_of(V, V.people[c.victim]) < 16:
				fail.call(seed, "a child offered")
	# determinism: one village twice (the reference runs 100 years; a runtime sweep no more than it was asked for)
	var check_years := years if runtime and years < 100 else 100
	var a := _village(5000, years, pace, focus, runtime)
	var b := _village(5000, years, pace, focus, runtime)
	for d in check_years * Village.YEAR - (1 if runtime else 0):
		_day(a, runtime)
		_day(b, runtime)
	if _hash(a) != _hash(b):
		fail.call(5000, "two runs of one seed differ")
	var lines := PackedStringArray()
	lines.append("%d villages x %d years (pace %d%s%s): %.2f ms per village-year; alive %d-%d; %d events" % [
		seeds, years, pace, ", focus" if focus else "", ", runtime mode" if runtime else "", total_ms / seeds / years, min_alive, max_alive, events])
	if fails.is_empty():
		lines.append("PASS: causes and cues, no child victims or throwers, integer state, no stuck cases, population, violence budget, determinism")
	else:
		lines.append("FAIL: %d problem%s (the first %d shown)" % [fails.size(), "" if fails.size() == 1 else "s", MAX_FAILS])
		lines.append_array(fails)
	return lines
