extends RefCounted
## Spike for Pass 3 (PA-1, B2): does anticipatory steering keep people apart, gently, at a price the phone can pay?
## Headless: godot --headless --path game --script res://scripts/studio/run.gd -- people/steer_bench
##   head-on       two walkers meet nose to nose: they swerve early (anticipation) and never touch
##   crossing      two paths cross at right angles, timed to meet
##   overtaking    a faster walker comes up behind a slower one on the same line
##   circle swap   24 walkers of different speeds and tempers cross a 14 m circle to the opposite side at once
##   chat circle   8 walkers cross the square through 6 people standing talking
##   cost          microseconds per step for 20, 40, 60 and 100 walkers milling in a 30 m square
## A spike: a line per scenario, PASS or FAIL against what people on foot would do.
const Steer := preload("res://scripts/studio/people/steer.gd")
const DT := 1.0 / 60.0
const BODY := 0.25            # metres: shoulders about half a metre across
const ROOM := 0.35            # metres of room a walker likes to keep
const TURN := 5.0             # rad/s a walking body turns to face where it goes

static var _out := PackedStringArray()
static var _every := 1        # neighbours re-judged by one walker in `_every` a step


static func report() -> PackedStringArray:
	_out.clear()
	for every in [1, 3]:
		_every = every
		_out.append("-- neighbours re-judged %s" % ("every step" if every == 1 else "by one walker in %d a step (20 times a second at 60 fps)" % every))
		_head_on()
		_crossing()
		_overtaking()
		_circle_swap()
		_chat_circle()
		_cost()
	return _out


## A walker's wish: towards its goal at its own speed, easing off over the last metre, still once there.
static func _wish(ag: Steer.Agents, i: int, goal: Vector2, speed: float) -> void:
	var to := goal - ag.pos[i]
	var d := to.length()
	ag.want[i] = Vector2.ZERO if d < 0.15 else to / d * speed * minf(1.0, d / 1.0)


static func _walker(ag: Steer.Agents, at: Vector2, speed: float, horizon := 3.0) -> int:
	return ag.add(at, BODY, ROOM, horizon, 4.0, speed * 1.4, Steer.WALKER)


## Runs walkers to their goals; returns what a viewer would notice.
static func _run(ag: Steer.Agents, goals: Array[Vector2], speeds: Array[float], seconds: float, anchors := {}) -> Dictionary:
	var closest := INF
	var undone := 0
	var snaps := 0
	var arrived_at := PackedFloat32Array()
	arrived_at.resize(ag.size)
	arrived_at.fill(-1.0)
	var heading := PackedFloat32Array()      # where the velocity points
	heading.resize(ag.size)
	var facing := PackedFloat32Array()       # where a body would face: turning after the velocity, at most TURN
	facing.resize(ag.size)
	var strafe := 0
	var moving := 0
	var drift := 0.0
	var steps := int(seconds / DT)
	for s in steps:
		for i in ag.size:
			if anchors.has(i):
				var back: Vector2 = (anchors[i] as Vector2) - ag.pos[i]
				ag.want[i] = back.limit_length(0.6) * 2.0 if back.length() > 0.05 else Vector2.ZERO
			elif i < goals.size():
				_wish(ag, i, goals[i], speeds[i])
		undone += Steer.step(ag, DT, [], _every)
		for i in ag.size:
			if anchors.has(i):
				drift = maxf(drift, ag.pos[i].distance_to(anchors[i]))
				continue
			var v := ag.vel[i]
			if v.length() > 0.3:
				var yaw := atan2(v.x, v.y)
				if s == 0 or facing[i] == 0.0 and heading[i] == 0.0:
					facing[i] = yaw
				facing[i] = rotate_toward(facing[i], yaw, TURN * DT)
				if v.length() > 0.5:
					moving += 1
					if s > 0 and absf(angle_difference(heading[i], yaw)) / DT > 6.0:
						snaps += 1
					if absf(angle_difference(facing[i], yaw)) > 0.87:
						strafe += 1
				heading[i] = yaw
			if i < goals.size() and arrived_at[i] < 0.0 and ag.pos[i].distance_to(goals[i]) < 0.3:
				arrived_at[i] = s * DT
		for i in ag.size:
			for j in range(i + 1, ag.size):
				var gap := ag.pos[i].distance_to(ag.pos[j]) - ag.body[i] - ag.body[j]
				closest = minf(closest, gap)
	return {"closest": closest, "undone": undone, "snaps": snaps, "arrived": arrived_at, "drift": drift,
		"strafe": float(strafe) / maxf(1.0, moving), "moving": moving}


static func _check(ok: bool, what: String) -> void:
	_out.append(("PASS " if ok else "FAIL ") + what)


static func _all_arrived(arrived: PackedFloat32Array, count: int) -> bool:
	for i in count:
		if arrived[i] < 0.0:
			return false
	return true


static func _head_on() -> void:
	var ag := Steer.Agents.new()
	_walker(ag, Vector2(0.0, 0.0), 1.3)
	_walker(ag, Vector2(12.0, 0.0), 1.3)
	var goals: Array[Vector2] = [Vector2(12.0, 0.0), Vector2(0.0, 0.0)]
	var speeds: Array[float] = [1.3, 1.3]
	# when does the first walker leave the straight line, against when they pass?
	var left_line := -1.0
	var passed := -1.0
	var closest := INF
	for s in int(16.0 / DT):
		for i in 2:
			_wish(ag, i, goals[i], speeds[i])
		Steer.step(ag, DT, [], _every)
		if left_line < 0.0 and absf(ag.pos[0].y) > 0.1:
			left_line = s * DT
		if passed < 0.0 and ag.pos[0].x > ag.pos[1].x:
			passed = s * DT
		closest = minf(closest, ag.pos[0].distance_to(ag.pos[1]) - 2.0 * BODY)
	_check(closest >= 0.0, "head-on: they never touch (closest gap %.2f m)" % closest)
	_check(left_line >= 0.0 and passed - left_line >= 1.0, "head-on: they swerve early (%.1f s before passing)" % (passed - left_line))
	_check(closest <= 0.8, "head-on: and pass at a natural distance, not a detour (gap %.2f m)" % closest)


static func _crossing() -> void:
	var ag := Steer.Agents.new()
	_walker(ag, Vector2(0.0, -6.0), 1.3)
	_walker(ag, Vector2(-6.0, 0.0), 1.3)
	var goals: Array[Vector2] = [Vector2(0.0, 6.0), Vector2(6.0, 0.0)]
	var speeds: Array[float] = [1.3, 1.3]
	var r := _run(ag, goals, speeds, 16.0)
	_check(r.closest >= 0.0, "crossing: they never touch (closest gap %.2f m)" % r.closest)
	_check(_all_arrived(r.arrived, 2) and maxf(r.arrived[0], r.arrived[1]) < 12.0 / 1.3 * 1.25, "crossing: both arrive with little delay (%.1f s and %.1f s; straight: %.1f s)" % [r.arrived[0], r.arrived[1], 12.0 / 1.3])


static func _overtaking() -> void:
	var ag := Steer.Agents.new()
	_walker(ag, Vector2(0.0, 0.0), 1.0)
	_walker(ag, Vector2(-3.0, 0.0), 1.6)
	var goals: Array[Vector2] = [Vector2(20.0, 0.0), Vector2(22.0, 0.0)]   # each stops at their own spot
	var speeds: Array[float] = [1.0, 1.6]
	var r := _run(ag, goals, speeds, 25.0)
	_check(r.closest >= 0.0, "overtaking: the faster one goes round, never through (closest gap %.2f m)" % r.closest)
	_check(r.arrived[1] >= 0.0 and r.arrived[1] <= 25.0 / 1.6 * 1.15, "overtaking: and is hardly held up (%.1f s for 25 m; straight: %.1f s)" % [r.arrived[1], 25.0 / 1.6])


static func _circle_swap() -> void:
	var ag := Steer.Agents.new()
	var goals: Array[Vector2] = []
	var speeds: Array[float] = []
	for k in 24:
		var a := TAU * k / 24.0
		var at := Vector2(cos(a), sin(a)) * 7.0
		var speed := 1.1 + 0.4 * fposmod(k * 0.618, 1.0)       # people walk at their own pace
		var horizon := 2.0 + 2.0 * fposmod(k * 0.382, 1.0)     # and give way at their own distance
		_walker(ag, at, speed, horizon)
		goals.append(-at)
		speeds.append(speed)
	var r := _run(ag, goals, speeds, 40.0)
	var last := 0.0
	for k in 24:
		last = maxf(last, r.arrived[k])
	_check(r.closest >= -0.02, "circle swap: 24 at once never visibly overlap (closest gap %.2f m; the hard pass undid %d overlaps over %d steps)" % [r.closest, r.undone, int(40.0 / DT)])
	_check(_all_arrived(r.arrived, 24), "circle swap: all arrive (the last after %.1f s; straight at the slowest pace: %.1f s)" % [last, 14.0 / 1.1])
	_check(r.strafe <= 0.02, "circle swap: bodies face where they go: %.1f%% of walking frames move more than 50 degrees off the way the body faces (turning at %.0f rad/s); the velocity itself turned faster than 6 rad/s in %d of %d" % [r.strafe * 100.0, TURN, r.snaps, r.moving])


static func _chat_circle() -> void:
	var ag := Steer.Agents.new()
	var goals: Array[Vector2] = []
	var speeds: Array[float] = []
	for k in 8:
		var z := -1.6 + 3.2 * k / 7.0
		var from := Vector2(-9.0 if k % 2 == 0 else 9.0, z)
		_walker(ag, from, 1.2 + 0.05 * k)
		goals.append(Vector2(-from.x, z))
		speeds.append(1.2 + 0.05 * k)
	var anchors := {}
	for k in 6:
		var a := TAU * k / 6.0
		var spot := Vector2(cos(a), sin(a)) * 0.75
		anchors[ag.add(spot, BODY, 0.1, 2.0, 2.0, 1.0, Steer.STANDING)] = spot
	var r := _run(ag, goals, speeds, 30.0, anchors)
	_check(r.closest >= -0.02, "chat circle: walkers go round six people talking, never through (closest gap %.2f m)" % r.closest)
	_check(_all_arrived(r.arrived, 8), "chat circle: every walker gets across")
	_check(r.drift <= 0.35, "chat circle: the talkers barely shift (at most %.2f m from their spots)" % r.drift)


static func _cost() -> void:
	for count in [20, 40, 60, 100]:
		var ag := Steer.Agents.new()
		var goals: Array[Vector2] = []
		var speeds: Array[float] = []
		for k in count:
			var at := Vector2(fposmod(k * 7.31, 30.0), fposmod(k * 3.77, 30.0))
			_walker(ag, at, 1.3)
			goals.append(Vector2(fposmod(k * 11.3 + 13.0, 30.0), fposmod(k * 5.9 + 7.0, 30.0)))
			speeds.append(1.1 + 0.4 * fposmod(k * 0.618, 1.0))
		for s in 30:                                            # let them get going
			for i in count:
				_wish(ag, i, goals[i], speeds[i])
			Steer.step(ag, DT, [], _every)
		var t0 := Time.get_ticks_usec()
		var steps := 300
		for s in steps:
			for i in count:
				_wish(ag, i, goals[i], speeds[i])
			Steer.step(ag, DT, [], _every)
		var per := float(Time.get_ticks_usec() - t0) / steps
		_out.append("COST %d walkers: %.0f us a step (%.1f us each), wish included" % [count, per, per / count])
	_check(true, "cost measured (desktop, headless; the web build is measured in play at stage 1)")
