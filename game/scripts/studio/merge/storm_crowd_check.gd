extends Node
## Rule 7 for the Tidecaller (desk, 6 Oct): a Tempest over a crowd of villagers, measured against the same crowd
## standing. In the live village, the port's switch as given:
##   --studio=village/live --merge-check=storm_crowd_check --save-guard --test-save=<fresh name> [--storm-crowd=12]
##   [--storm-cast=tempest|star]   (the star: Meteor dropped on the crowd's centre, every one in its reach touched at once)
## At midday, a crowd of grown villagers who can be stood is placed round the player; [--storm-rounds=4] rounds of A
## (nothing cast, 4 s), B (cast, 4 s) and C (the aftermath, 6 s). Prints how many of the crowd each cast touched. Per window: the frame time (mean, worst), the engine's process
## time, and the checked batches written in it (count, accept_us median and max, from acceptance's own measures).
## Prints "STORM <window> ..." lines and "STORM complete failures=N".
const Contact := preload("res://scripts/studio/village/contact.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
var failed := 0
var player: Node3D
var _watch := {}                          # id -> body facts before the cast: sampled every frame of the B window
var _seen_touched := {}


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("StormCrowdCheck"):
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/merge/storm_crowd_check.gd").new()
	probe.name = "StormCrowdCheck"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS storm " if ok else "FAIL storm ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func run() -> void:
	await frames(120)
	var res: Node = null
	for _i in 900:
		res = Contact.registry(get_tree())
		if res != null and VillageSession.village != null and VillageSession.active and res.call("all_built") \
				and get_tree().get_first_node_in_group("player") != null:
			break
		await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	var want := 12
	var cast := "tempest"
	var rounds := 4                           # a star kills: by its third round the crowd is dead (--storm-rounds=2)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--storm-crowd="):
			want = int(arg.trim_prefix("--storm-crowd="))
		if arg.begins_with("--storm-cast="):
			cast = arg.trim_prefix("--storm-cast=")
		if arg.begins_with("--storm-rounds="):
			rounds = int(arg.trim_prefix("--storm-rounds="))
	var v = VillageSession.village
	WorldClock.advance_to_time(0.5)           # midday: most are out of doors (at the probe's own early hour few are)
	await seconds(3.0)
	# Only who can be stood (desk 6 Oct: at the probe's hour 23 of 34 are indoors, asleep or away, and a star "over 20"
	# touched about 6): each grown villager is put on a trial spot, and one whose body did not get there is left out.
	var people := []
	for id: int in res.bodies:
		var p = v.people[id]
		if p.alive and p.present and p.authored == "" and Rules.age_of(v, p) >= 14:
			people.append(id)
	var trial := Vector2(player.global_position.x, player.global_position.z) + Vector2(3.0, 0.0)
	var spots := {}
	for i in people.size():
		spots[people[i]] = trial + Vector2(float(i % 6), float(i / 6)) * 1.5
		res._movers[people[i]].place(spots[people[i]], 0.0)
	await frames(30)
	var crowd := []
	for id: int in people:
		var body: Node3D = res.bodies[id]
		if Vector2(body.global_position.x, body.global_position.z).distance_to(spots[id]) <= 2.0 and crowd.size() < want:
			crowd.append(id)
	print("STORM can be stood %d grown of %d (hour %.2f)" % [crowd.size(), people.size(), float(v.runtime.now % 1440) / 60.0])
	var centre := Vector2(player.global_position.x, player.global_position.z)
	for i in crowd.size():
		var a := TAU * float(i) / float(crowd.size())
		var r := 2.5 + 1.5 * float(i % 3)
		res._movers[crowd[i]].place(centre + Vector2(cos(a), sin(a)) * r, a + PI)
	check(crowd.size() == want, "a crowd of %d villagers round the player (%d)" % [want, crowd.size()])
	if cast == "tempest":
		Classes.choose("tidecaller")
	await seconds(2.0)
	var rows := {"A": [], "B": [], "C": []}   # C: the aftermath, the 6 s after the cast window (helpers, cries, the summaries)
	var touched := []                         # per round: how many of the crowd the cast changed (a new or renewed body fact)
	for round in rounds:
		rows.A.append(await _window(4.0))
		var before := {}
		for id: int in crowd:
			before[id] = _facts(v, id)
		if cast == "star":
			for i in crowd.size():            # stood again where they were (the last round's star knocked them about)
				var a := TAU * float(i) / float(crowd.size())
				res._movers[crowd[i]].place(centre + Vector2(cos(a), sin(a)) * (1.2 + 0.8 * float(i % 3)), a + PI)
			player.global_position = Vector3(centre.x - 7.0, player.global_position.y, centre.y - 7.0)
			player.abilities._drop_star(null, Vector3(centre.x, player.global_position.y, centre.y), 1.0, "storm-star:%d" % round)
		else:
			Classes.start_cooldown("tempest", 0.0)
			player.abilities.use("tempest", {"at": player.global_position, "dir": Vector3.FORWARD, "press_id": "storm:%d:%d" % [round, Time.get_ticks_usec()]})
		_watch = before
		_seen_touched = {}
		rows.B.append(await _window(4.0))
		_watch = {}
		touched.append(_seen_touched.size())       # changed at any frame of the cast window (a soaking may dry before its end)
		rows.C.append(await _window(6.0))
	for w: String in ["A", "B", "C"]:
		var mean := 0.0
		var worst := 0.0
		var proc := 0.0
		var n := 0
		var acc := []
		for r: Dictionary in rows[w]:
			mean += r.mean / float(rounds)
			worst = maxf(worst, r.worst)
			proc += r.process / float(rounds)
			n += int(r.batches)
			acc.append_array(r.accept)
		acc.sort()
		var med: float = acc[acc.size() / 2] if not acc.is_empty() else 0.0
		var top: float = acc.back() if not acc.is_empty() else 0.0
		var built := 0
		for r: Dictionary in rows[w]:
			built += int(r.built)
		print("STORM %s accounts_built=%d (%d rounds, %d a cast)" % [w, built, rounds, built / rounds])
		print("STORM %s cast=%s crowd=%d frame_mean_ms=%.2f frame_worst_ms=%.1f process_ms=%.2f batches=%d accept_us_median=%.0f accept_us_max=%.0f rounds=%d" % [w, cast, crowd.size(), mean, worst, proc, n, med, top, rounds])
	# Per-frame CPU by owner (ms a frame, mean over the window's frames, all rounds), A against B and C: where the time goes.
	for w: String in ["A", "B", "C"]:
		var totals := {}
		var frames := 0
		var phys := 0.0
		for r: Dictionary in rows[w]:
			frames += int(r.frames)
			phys += float(r.physics) * int(r.frames)
			for owner: Variant in r.owners:
				totals[owner] = float(totals.get(owner, 0.0)) + float(r.owners[owner])
		var parts := []
		for owner: Variant in totals:
			if not str(owner).ends_with("_prof_inner"):
				parts.append("%s %.2f" % [owner, float(totals[owner]) / maxf(1, frames)])
		print("STORM %s per_frame_ms physics %.2f %s" % [w, phys / maxf(1, frames), ", ".join(PackedStringArray(parts))])
	for round in rounds:
		print("STORM round %d A frame %.2f/%.1f batches %d | B frame %.2f/%.1f batches %d | C frame %.2f/%.1f batches %d" % [round, rows.A[round].mean, rows.A[round].worst,
			rows.A[round].batches, rows.B[round].mean, rows.B[round].worst, rows.B[round].batches, rows.C[round].mean, rows.C[round].worst, rows.C[round].batches])
	# The worst frames of the cast windows, broken down: the checked batches written in that frame (acceptance, its
	# minds' learning and appraisal inside), physics, and the rest of the frame (scripts: bodies, fire, offers, effects).
	var tops := []
	for r: Dictionary in rows.B + rows.C:
		tops.append_array(r.top)
	tops.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	for t: Array in tops.slice(0, 5):
		print("STORM worst cast=%s frame_ms=%.1f accept_ms=%.1f batches=%d physics_ms=%.1f process_ms=%.1f rest_ms=%.1f" % [cast, t[0], t[1] / 1000.0, t[2],
			t[3], t[4], maxf(0.0, t[0] - t[1] / 1000.0 - t[3])], " parts_ms=", str((t[5] as Dictionary).keys().map(func(k2: Variant) -> String: return "%s %.1f" % [k2, float(t[5][k2]) / 1000.0])) if t.size() > 5 else "")
	var b_batches := 0
	for r: Dictionary in rows.B:
		b_batches += int(r.batches)
	print("STORM touched cast=%s crowd=%d per_round=%s (changed at any frame of the cast window) B_fps=%s" % [cast, crowd.size(), str(touched), str(rows.B.map(func(r: Dictionary) -> String: return "%.1f" % (1000.0 / maxf(0.001, float(r.mean)))))])
	if cast == "star":                       # (the Tempest's strikes fall where they fall: its count is printed only)
		check(touched.all(func(n: int) -> bool: return n >= crowd.size() * 3 / 4), "every round's star touched most of the crowd (%s of %d)" % [str(touched), crowd.size()])
	var heavy := []                          # the heaviest batches of all windows, with acceptance's own parts
	for w: String in ["A", "B", "C"]:
		for r: Dictionary in rows[w]:
			for m: Dictionary in r.measures:
				heavy.append([w, m])
	heavy.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1].accept_us) > float(y[1].accept_us))
	for h: Array in heavy.slice(0, 5):
		print("STORM heavy %s accept_ms=%.1f prepare_ms=%.1f check_ms=%.1f stage_ms=%.1f save_ms=%.1f" % [h[0], float(h[1].accept_us) / 1000.0,
			float(h[1].prepare_us) / 1000.0, float(h[1].check_us) / 1000.0, float(h[1].stage_us) / 1000.0, float(h[1].save_us) / 1000.0])
	check(b_batches > 0, "the %s over the crowd made checked batches (%d in the B windows)" % [cast, b_batches])
	_done()


## A person's body facts as kind -> deed (and alive): what a cast changes on them.
func _facts(v, id: int) -> String:
	var p = v.people[id]
	var out := []
	for k: Variant in p.body_facts:
		out.append("%s=%s" % [k, str(p.body_facts[k].get("deed", "")) if p.body_facts[k] is Dictionary else ""])
	out.sort()
	return str(p.alive) + ":" + ",".join(PackedStringArray(out)) + ":" + str(p.hurt)


## One measured window: frame times from the process deltas, the engine's process time, and the batches acceptance
## wrote meanwhile (its measures are appended per real write).
func _window(length: float) -> Dictionary:
	var res: Node = Contact.registry(get_tree())
	var built0: int = int(res.people_bridge.get("accounts_built")) if res != null and res.people_bridge.get("accounts_built") != null else 0
	var start := Accept.measures.size()
	var first: Dictionary = Accept.measures.back() if not Accept.measures.is_empty() else {}
	var n := 0
	var total := 0.0
	var worst := 0.0
	var proc := 0.0
	var last := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(length * 1000.0)
	var last_seen: Dictionary = Accept.measures.back() if not Accept.measures.is_empty() else {}
	var frames_seen := []                     # [frame ms, accept us in it, batches in it, physics ms, process ms, parts]
	var owners := {}                          # per-owner script ms over the window (a profiling build's Engine meta "prof")
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := float(now - last) / 1000.0
		last = now
		total += ms
		worst = maxf(worst, ms)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		n += 1
		var acc := 0.0
		var k := 0
		# This frame's batches: those after the last one seen (acceptance keeps its last 128, so by identity, not count).
		var from := Accept.measures.rfind(last_seen) + 1 if not last_seen.is_empty() else 0
		for m: Dictionary in Accept.measures.slice(from):
			acc += float(m.accept_us)
			k += 1
		if not Accept.measures.is_empty():
			last_seen = Accept.measures.back()
		var prof: Dictionary = Engine.get_meta("prof", {})
		Engine.set_meta("prof", {})
		for owner: Variant in prof:
			owners[owner] = float(owners.get(owner, 0.0)) + float(prof[owner]) / 1000.0
		if not _watch.is_empty():
			var vv = VillageSession.village
			for id: int in _watch:
				if not _seen_touched.has(id) and _facts(vv, id) != _watch[id]:
					_seen_touched[id] = true
		frames_seen.append([ms, acc, k, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, prof])
	# acceptance keeps its last 128 measures: count from where this window began (or from the last one seen).
	var fresh: Array = Accept.measures.slice(start) if Accept.measures.size() > start else []
	if Accept.measures.size() >= 128 and not first.is_empty():
		var at := Accept.measures.rfind(first)
		fresh = Accept.measures.slice(at + 1) if at >= 0 else Accept.measures.duplicate()
	var accept := fresh.map(func(m: Dictionary) -> float: return float(m.accept_us))
	frames_seen.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var phys := 0.0
	for f: Array in frames_seen:
		phys += float(f[3])
	var built: int = (int(res.people_bridge.get("accounts_built")) - built0) if res != null and res.people_bridge.get("accounts_built") != null else -1
	return {"measures": fresh, "mean": total / maxf(1, n), "worst": worst, "process": proc / maxf(1, n), "batches": fresh.size(), "accept": accept,
		"top": frames_seen.slice(0, 5), "owners": owners, "frames": n, "physics": phys / maxf(1, n), "built": built}


func _done() -> void:
	print("STORM complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
