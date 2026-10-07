extends Node
## Rule 7 inside one of Enea's dungeons (merge-fix: dungeons/, 16 files). Live, port on, his dev arg entering:
##   --studio=village/live --dungeon=cannibal_den --merge-check=dungeon_frames_check --save-guard --port-residents=on
##     --test-save=<fresh> [--dungeon-goal]
## Waits until the dungeon is entered, then for 30 s of the player standing in it (foes come at them) and 30 s walking
## through it (the stick held forward, turning at walls): every frame's time, the engine's process time, the checked
## batches written (acceptance's measures) and the village's own per-frame costs. Prints "DUNGEON ..." lines, the
## rule 7 lines (worst batch under 33 ms, frames over 33 ms) and "DUNGEON complete failures=N".
const Accept := preload("res://scripts/studio/village/acceptance.gd")
var failed := 0


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("DungeonFramesCheck"):
		return
	var probe: Node = load("res://scripts/studio/merge/dungeon_frames_check.gd").new()
	probe.name = "DungeonFramesCheck"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS dungeon " if ok else "FAIL dungeon ") + text)
	if not ok:
		failed += 1


func run() -> void:
	var dungeon: Node = null
	for _i in 1800:                                     # up to about a minute for the village and the dev arg's entry
		await get_tree().process_frame
		dungeon = get_tree().get_first_node_in_group("dungeon")
		if dungeon != null and _inside(dungeon):
			break
	var entered := dungeon != null and _inside(dungeon)
	check(entered, "the dev arg entered the dungeon (%s)" % (str((dungeon.get("_site") as Dictionary).get("name", "")) if dungeon != null and dungeon.get("_site") is Dictionary else "no dungeon node"))
	if not entered:
		_done()
		return
	await get_tree().create_timer(2.0).timeout
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var stand := await _window(30.0, false, player)
	var walk := await _window(30.0, true, player)
	Controls.joystick = Vector2.ZERO
	for w in [["stand", stand], ["walk", walk]]:
		var r: Dictionary = w[1]
		print("DUNGEON %s frames=%d cpu_median_ms=%.1f cpu_p95_ms=%.1f cpu_max_ms=%.1f cpu_over33=%d frame_max_ms=%.1f batches=%d accept_max_ms=%.1f foes=%d" % [w[0], r.n, r.median, r.p95,
			r.max, r.over33, r.frame_max, r.batches, r.accept_max, r.foes])
	var worst_batch := maxf(float(stand.accept_max), float(walk.accept_max))
	check(worst_batch < 33.0, "rule 7: the worst checked batch in the dungeon is under 33 ms (%.1f ms)" % worst_batch)
	print("DUNGEON rule7 frames whose CPU is over 33 ms: stand %d of %d, walk %d of %d" % [stand.over33, stand.n, walk.over33, walk.n])
	_done()


func _inside(dungeon: Node) -> bool:
	for prop in ["active", "inside", "_inside", "_active"]:
		if dungeon.get(prop) != null:
			return bool(dungeon.get(prop))
	return dungeon.get_child_count() > 0


func _window(length: float, walking: bool, player: Node3D) -> Dictionary:
	var times: Array = []
	var cpu: Array = []                        # the engine's process + physics time a frame (the game caps itself at 30 fps)
	var last := Time.get_ticks_usec()
	var until := Time.get_ticks_msec() + int(length * 1000.0)
	var first: Dictionary = Accept.measures.back() if not Accept.measures.is_empty() else {}
	var turn := 0.0
	var stuck_at := player.global_position
	var stuck_for := 0.0
	while Time.get_ticks_msec() < until:
		if walking:
			Controls.joystick = Vector2(sin(turn), -cos(turn)) * 0.8
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := float(now - last) / 1000.0
		last = now
		times.append(ms)
		cpu.append((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		if walking:
			stuck_for += ms / 1000.0
			if stuck_for > 1.5:
				if player.global_position.distance_to(stuck_at) < 0.8:
					turn += 1.3                              # a wall: turn and go on
				stuck_at = player.global_position
				stuck_for = 0.0
	var from := Accept.measures.rfind(first) + 1 if not first.is_empty() else 0
	var fresh: Array = Accept.measures.slice(from)
	var accept: Array = fresh.map(func(m: Dictionary) -> float: return float(m.accept_us) / 1000.0)
	var sorted := cpu.duplicate()
	sorted.sort()
	return {"n": times.size(), "median": sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0,
		"p95": sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else 0.0, "max": sorted.back() if not sorted.is_empty() else 0.0,
		"over33": cpu.filter(func(t: float) -> bool: return t > 33.0).size(), "frame_max": times.max() if not times.is_empty() else 0.0, "batches": fresh.size(),
		"accept_max": accept.max() if not accept.is_empty() else 0.0, "foes": get_tree().get_nodes_in_group("enemy").size()}


func _done() -> void:
	print("DUNGEON complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
