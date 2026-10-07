extends RefCounted
## The think scheduler (think.gd), headless:
##   godot --headless --path game --script res://scripts/studio/run.gd -- village/think_test
## Twenty villagers' work at 0.5 ms each, a 0.25 s period, a 2 ms budget, 60 frames a second: the budget holds each
## frame (one item over it at most), every villager runs at about its period (none starves, the latest within a few
## frames), first runs are staggered (not all in one frame), an interrupt runs in the very next frame ahead of the
## queue and whatever the budget, forget stops work, once runs once, and a freed object's work is dropped.
const Think := preload("res://scripts/studio/village/think.gd")


static func check(out: PackedStringArray, ok: bool, text: String) -> void:
	out.append(("PASS" if ok else "FAIL") + " think " + text)


static func spin(us: int) -> void:
	var until := Time.get_ticks_usec() + us
	while Time.get_ticks_usec() < until:
		pass


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	Think.manual = true
	Think.clear()
	var saved_budget := Think.budget_ms
	Think.budget_ms = 2.0
	var runs := {}
	var first_frame := {}
	var frame := [0]
	for id in 20:
		runs[id] = []
		Think.every(id, "plan", 0.25, func(elapsed: float) -> void:
			spin(500)
			if not first_frame.has(id):
				first_frame[id] = frame[0]
			(runs[id] as Array).append(elapsed))
	var over := 0
	var worst := 0.0
	for f in 300:                                    # 5 s at 60 fps
		frame[0] = f
		Think.tick(1.0 / 60.0)
		worst = maxf(worst, float(Think.stats.spent_ms_last))
		if float(Think.stats.spent_ms_last) > 2.0 + 0.8:
			over += 1
	check(out, over <= 3, "the budget holds (2 ms + at most one 0.5 ms item; frames over it %d of 300, the machine's own jitter; worst %.2f ms)" % [over, worst])
	var counts := runs.values().map(func(r: Array) -> int: return r.size())
	var least: int = counts.min()
	var most: int = counts.max()
	check(out, least >= 14 and most - least <= 3, "round robin: every villager ran about every period (runs %d..%d in 5 s; 20 at 0.25 s if the budget allowed)" % [least, most])
	var gaps: Array = []
	for r: Array in runs.values():
		for g in r.slice(1):
			gaps.append(g)
	check(out, gaps.max() <= 0.45, "no villager waits much past its period (longest gap %.2f s for 0.25 s)" % gaps.max())
	var frames_used := {}
	for id: int in first_frame:
		frames_used[first_frame[id]] = true
	check(out, frames_used.size() >= 8, "first runs are staggered across the period (%d distinct first frames for 20)" % frames_used.size())
	# Overloaded: twice the work the budget holds. The budget still holds, the work is shared evenly (round robin,
	# most overdue first), and everyone runs at a slower, even cadence instead of some never.
	Think.clear()
	Think.budget_ms = 1.0
	var load := {}
	for id in 20:
		load[id] = 0
		Think.every(id, "steer", 0.1, func(_e: float) -> void:
			spin(500)
			load[id] += 1)
	var over_load := 0
	for f in 300:
		Think.tick(1.0 / 60.0)
		if float(Think.stats.spent_ms_last) > 1.0 + 0.8:
			over_load += 1
	var lo: int = load.values().min()
	var hi: int = load.values().max()
	check(out, over_load <= 3 and int(Think.stats.deferred) > 0 and lo >= 0.8 * hi and lo > 0,
		"overloaded twice over: the budget holds (frames over %d), work waits (%d deferrals) and is shared evenly (runs %d..%d each)" % [over_load, int(Think.stats.deferred), lo, hi])
	Think.budget_ms = 2.0
	# An interrupt: the next frame, ahead of the queue, whatever the budget.
	var hit := [-1]
	Think.every("wolf:1", "react", 10.0, func(_e: float) -> void:
		hit[0] = frame[0])
	Think.budget_ms = 0.0
	frame[0] = 1000
	Think.now("wolf:1", "react", "struck")
	Think.tick(1.0 / 60.0)
	check(out, hit[0] == 1000 and Think.due_in("wolf:1", "react") >= 9.9, "an interrupt runs in the next frame with no budget left, and its next ordinary run is a full period on (%.1f s)" % Think.due_in("wolf:1", "react"))
	Think.budget_ms = 2.0
	# forget, once, a freed object's work.
	for id in 20:
		Think.every(id, "plan", 0.25, func(_e: float) -> void: (runs[id] as Array).append(_e))
	Think.forget(3)
	var before: int = (runs[3] as Array).size()
	for f in 60:
		Think.tick(1.0 / 60.0)
	check(out, (runs[3] as Array).size() == before and not Think.has(3, "plan"), "forget stops a villager's work")
	var n := [0]
	Think.once("x", "tell", func(_e: float) -> void: n[0] += 1, 0.1)
	for f in 30:
		Think.tick(1.0 / 60.0)
	check(out, n[0] == 1 and not Think.has("x", "tell"), "once runs once, after its delay")
	var obj := Node.new()
	Think.every("gone", "steer", 0.1, obj.queue_free)
	obj.free()
	for f in 20:
		Think.tick(1.0 / 60.0)
	check(out, not Think.has("gone", "steer"), "work whose object was freed is dropped, not called")
	Think.clear()
	Think.budget_ms = saved_budget
	Think.manual = false
	return out
