extends RefCounted
## Headless tests for the people layer's pure parts (Pass 3): persona.gd, mover.gd and crowd.gd stepped by hand on bare
## bodies, no village, no renderer. Milliseconds; run after every change to them:
##   godot --headless --path game --script res://scripts/studio/run.gd -- people/people_test
## (PEOPLE_DEBUG=1 in the environment: the gathering tests say where anyone inches along.)
## Each case prints PASS or FAIL with what it measured; the run fails if any case does.

const Persona := preload("res://scripts/studio/people/persona.gd")
const Steer := preload("res://scripts/studio/people/steer.gd")
const Mover := preload("res://scripts/studio/people/mover.gd")
const Crowd := preload("res://scripts/studio/people/crowd.gd")
const Spots := preload("res://scripts/studio/people/spots.gd")
const Formation := preload("res://scripts/studio/people/formation.gd")
const Groups := preload("res://scripts/studio/people/groups.gd")
const Encounters := preload("res://scripts/studio/people/encounters.gd")
const Situation := preload("res://scripts/studio/people/situation.gd")
const Activity := preload("res://scripts/studio/people/activity.gd")
const Speech := preload("res://scripts/studio/people/speech.gd")
const Society := preload("res://scripts/studio/people/society.gd")
const MotionWatch := preload("res://scripts/studio/people/motion_watch.gd")
const Owners := preload("res://scripts/studio/people/owners.gd")
const Stimuli := preload("res://scripts/studio/people/stimuli.gd")

const DT := 1.0 / 60.0
const OVERLAP := 0.45         # metres between centres (motion_watch.gd's threshold)


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	out.append_array(_personas())
	out.append_array(_head_on())
	out.append_array(_one_door())
	out.append_array(_doorway())
	out.append_array(_past_the_player())
	out.append_array(_late())
	out.append_array(_brisk())
	out.append_array(_uneven())
	out.append_array(_corner("walk"))
	out.append_array(_corner("jog"))
	out.append_array(_spots())
	out.append_array(_gathering(false))
	out.append_array(_gathering(true))
	out.append_array(_formations())
	out.append_array(_groups())
	out.append_array(_encounters())
	out.append_array(_variety())
	out.append_array(_word())
	out.append_array(_beside())
	out.append_array(_chase())
	out.append_array(_stay())
	out.append_array(_circle())
	out.append_array(_circle_evens_out())
	out.append_array(_aside())
	out.append_array(_door_shove())
	out.append_array(_in_step())
	out.append_array(_no_sudden_stops())
	out.append_array(_bumped())
	out.append_array(_sent_on_while_aside())
	out.append_array(_speech())
	out.append_array(_society())
	out.append_array(_owners())
	out.append_array(_stimuli())
	return out


static func _check(ok: bool, what: String) -> String:
	return ("PASS " if ok else "FAIL ") + what


## Paces by age keep to the styles, and no style falls in the walk-to-jog gap.
static func _personas() -> PackedStringArray:
	var out := PackedStringArray()
	var gap := 0
	var olds := []
	var kids := []
	var grown := []
	for key in 200:
		var age: int = [8, 30, 70][key % 3]
		var m := Persona.motion({"key": key, "age": age, "bold": key % 100, "temper": (key * 7) % 100, "alert": (key * 13) % 100})
		for style in ["stroll", "walk", "hurry", "jog", "run"]:
			var v := Persona.speed(m, style)
			if v > Persona.HURRY_TOP + 0.001 and v < Persona.JOG_LOW - 0.001:
				gap += 1
		(kids if age == 8 else (grown if age == 30 else olds)).append(float(m.pace))
	out.append(_check(gap == 0, "no style asks for a speed between the walk and the jog (%d did)" % gap))
	var mean := 0.0
	for v: float in grown:
		mean += v / grown.size()
	var sd := 0.0
	for v: float in grown:
		sd += (v - mean) * (v - mean) / grown.size()
	var cv := sqrt(sd) / mean
	out.append(_check(olds.max() < grown.max() and float(olds.max()) <= 1.05 and mean >= 1.2 and mean <= 1.4 and cv >= 0.11,
		"the old amble (%.2f-%.2f m/s), grown people walk (%.2f-%.2f, mean %.2f, spread %.0f%%), children dart (%.2f-%.2f)" % [
			olds.min(), olds.max(), grown.min(), grown.max(), mean, cv * 100.0, kids.min(), kids.max()]))
	return out


## A crowd of bare bodies, stepped by hand: [crowd, movers]. Each spec: [from, to, age, key].
static func _crowd(specs: Array, root: Node) -> Array:
	var crowd := Crowd.new()
	crowd.drawn_only = false
	root.add_child(crowd)
	var movers := []
	for spec: Array in specs:
		var body := Node3D.new()
		root.add_child(body)
		body.position = Vector3(spec[0].x, 0.0, spec[0].y)
		var mv := Mover.new(body, Persona.motion({"key": spec[3], "age": spec[2]}))
		crowd.add(mv)
		movers.append(mv)
	return [crowd, movers]


## Steps a crowd for `seconds`; -> the worst it did: closest pair, hardest speed change and fastest turn while
## walking (over 0.1 s, as motion_watch.gd measures them), and when each set off.
static func _run(crowd: Crowd, movers: Array, seconds: float, others := [], judge_from := 0.0) -> Dictionary:
	crowd.others = func() -> Array: return others
	var hist := []
	for mv in movers:
		hist.append([])
	var worst := {"closest": INF, "accel": 0.0, "turn": 0.0, "set_off": []}
	for mv in movers:
		worst.set_off.append(-1.0)
	var steps := int(seconds / DT)
	for k in steps:
		crowd._process(DT)
		var t := k * DT
		for i in movers.size():
			var mv: Mover = movers[i]
			var h: Array = hist[i]
			h.append([mv.pos, mv.yaw])
			if worst.set_off[i] < 0.0 and mv.vel.length() > 0.3:
				worst.set_off[i] = t
			var w := int(0.1 / DT)
			if h.size() > 2 * w and t >= judge_from + 0.2:
				var v1: float = (h[-1][0] as Vector2).distance_to(h[-1 - w][0]) / 0.1
				var v0: float = (h[-1 - w][0] as Vector2).distance_to(h[-1 - 2 * w][0]) / 0.1
				worst.accel = maxf(worst.accel, absf(v1 - v0) / 0.1)
				if v1 > 0.2:
					worst.turn = maxf(worst.turn, absf(angle_difference(float(h[-1 - w][1]), float(h[-1][1]))) / 0.1)
			if t < judge_from:
				continue
			for j in range(i + 1, movers.size()):
				worst.closest = minf(worst.closest, mv.pos.distance_to((movers[j] as Mover).pos))
			for o: Array in others:
				worst.closest = minf(worst.closest, mv.pos.distance_to(Vector2((o[0] as Node3D).position.x, (o[0] as Node3D).position.z)))
	return worst


static func _head_on() -> PackedStringArray:
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 12), 30, 1], [Vector2(0.1, 12), Vector2(0.1, 0), 30, 2]], root)
	for i in 2:
		var mv: Mover = c[1][i]
		mv.go(PackedVector2Array([Vector2(0.0 if i == 0 else 0.1, 12.0 if i == 0 else 0.0)]))
	var w := _run(c[0], c[1], 14.0)
	var there: bool = (c[1][0] as Mover).arrived and (c[1][1] as Mover).arrived
	root.free()
	return PackedStringArray([_check(w.closest >= OVERLAP and there and w.accel <= 4.0 and w.turn <= 8.0,
		"head-on: they pass %.2f m apart and arrive (%s); hardest speed change %.1f m/s2, fastest turn %.1f rad/s" % [w.closest, there, w.accel, w.turn])])


## Eight people leave one door for one place at once: each at their own moment, and never inside each other.
static func _one_door() -> PackedStringArray:
	var root := Node.new()
	var specs := []
	for k in 8:
		specs.append([Vector2(0.05 * k, 0.03 * k), Vector2(0, 15), [30, 9, 70][k % 3], 10 + k])
	var c := _crowd(specs, root)
	for mv: Mover in c[1]:
		mv.go(PackedVector2Array([Vector2(0, 15)]), INF, "", Persona.delay(mv.m, 600))
	# they all stand on one spot (a doorstep) at first: the hard pass spreads them; closeness is judged from 1 s on
	var w := _run(c[0], c[1], 20.0, [], 1.0)
	var offs: Array = w.set_off.filter(func(t: float) -> bool: return t >= 0.0)
	var spread: float = (offs.max() - offs.min()) if offs.size() > 1 else 0.0
	root.free()
	return PackedStringArray([_check(spread >= 1.5 and w.closest >= OVERLAP and w.accel <= 4.0,
		"one door: %d set off over %.1f s; closest %.2f m; hardest speed change %.1f m/s2" % [offs.size(), spread, w.closest, w.accel])])


## A household of six leaves from indoors through one door (mover.indoors): they come out one at a time, each when
## the doorstep is clear, and nobody who is out is ever inside anyone else, from the first frame.
static func _doorway() -> PackedStringArray:
	var root := Node.new()
	var specs := []
	for k in 6:
		specs.append([Vector2(0, 0), Vector2(1.5 * (k - 2.5), 14), [30, 9, 70][k % 3], 40 + k])
	var c := _crowd(specs, root)
	for mv: Mover in c[1]:
		mv.go(PackedVector2Array([mv.pos + Vector2(0, 2), Vector2((mv.m.key - 42.5) * 1.5, 14)]), INF, "", Persona.delay(mv.m, 300))
		mv.indoors = true
	(c[0] as Crowd).others = func() -> Array: return []
	var closest := INF
	var out_at := []
	for mv in c[1]:
		out_at.append(-1.0)
	for k in int(16.0 / DT):
		(c[0] as Crowd)._process(DT)
		for i in c[1].size():
			var a: Mover = c[1][i]
			if a.indoors:
				continue
			if out_at[i] < 0.0:
				out_at[i] = k * DT
			for j in range(i + 1, c[1].size()):
				var b: Mover = c[1][j]
				if not b.indoors:
					closest = minf(closest, a.pos.distance_to(b.pos))
	var times: Array = out_at.duplicate()
	times.sort()
	var gap := INF
	for i in range(1, times.size()):
		gap = minf(gap, times[i] - times[i - 1])
	var all_out: bool = times[0] >= 0.0
	root.free()
	return PackedStringArray([_check(all_out and closest >= OVERLAP and gap >= 0.2,
		"doorway: 6 came out over %.1f s, at least %.2f s apart; closest once out %.2f m" % [times[-1] - times[0], gap, closest])])


## A walker passes the player standing on their way, round them, not through.
static func _past_the_player() -> PackedStringArray:
	var root := Node.new()
	var player := Node3D.new()
	root.add_child(player)
	player.position = Vector3(0.0, 0.0, 6.0)
	var c := _crowd([[Vector2(0, 0), Vector2(0, 12), 30, 3]], root)
	(c[1][0] as Mover).go(PackedVector2Array([Vector2(0, 12)]))
	var w := _run(c[0], c[1], 14.0, [[player, 0.35]])
	var there := (c[1][0] as Mover).arrived
	root.free()
	return PackedStringArray([_check(w.closest >= 0.6 and there, "past the player: %.2f m from them at the closest (bodies touch at 0.60), arrived %s" % [w.closest, there])])


## Late: they hurry, never into the gap between walk and jog; with plenty of time they keep their own pace.
static func _late() -> PackedStringArray:
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 30), 30, 4], [Vector2(5, 0), Vector2(5, 30), 30, 5]], root)
	(c[1][0] as Mover).go(PackedVector2Array([Vector2(0, 30)]), 18.0)     # 30 m in 18 s: 1.67 m/s, a hurry
	(c[1][1] as Mover).go(PackedVector2Array([Vector2(5, 30)]), 60.0)     # plenty of time: their own pace
	var top := [0.0, 0.0]
	for k in int(10.0 / DT):
		(c[0] as Crowd)._process(DT)
		for i in 2:
			top[i] = maxf(top[i], (c[1][i] as Mover).vel.length())
	var pace: float = (c[1][1] as Mover).m.pace
	root.free()
	return PackedStringArray([_check(top[0] > pace and top[0] <= Persona.HURRY_TOP + 0.05 and absf(top[1] - pace) < 0.1,
		"late: hurries at %.2f m/s (pace %.2f, the walk tops out at %.2f); not late: %.2f m/s" % [top[0], pace, Persona.HURRY_TOP, top[1]])])


## Starting and stopping are brisk, as people's are (up to speed within a step or two): the time a walk spends between
## 0.3 and 0.6 m/s (too slow for the walk clip to look right) is short, for the young, grown and old alike.
static func _brisk() -> PackedStringArray:
	var out := PackedStringArray()
	for age in [9, 30, 75]:
		var root := Node.new()
		var c := _crowd([[Vector2(0, 0), Vector2(0, 8), age, 60 + age]], root)
		var mv: Mover = c[1][0]
		mv.go(PackedVector2Array([Vector2(0, 8)]))
		(c[0] as Crowd).others = func() -> Array: return []
		var slow := 0.0
		var last := mv.pos
		var hist: Array[Vector2] = []
		var w := int(0.1 / DT)
		for k in int(12.0 / DT):
			(c[0] as Crowd)._process(DT)
			hist.append(mv.pos)
			if hist.size() > w:
				var v := (hist[-1] - hist[-1 - w]).length() / 0.1      # as the watcher measures it
				if v > 0.3 and v < 0.6:
					slow += DT
		root.free()
		out.append(_check(slow <= 0.3 and mv.arrived, "brisk at %d: %.2f s of a start and a stop spent crawling (0.3-0.6 m/s)" % [age, slow]))
	return out


## Spots at a gathering by a wall with a door in it: 24 arrive one after another from every side. Nobody stands in
## the wall or within a body's room of it, on the doorstep, behind the wall from the focus, or on anyone; nobody's way
## in passes through someone already standing; and each stands on the side they came from.
static func _spots() -> PackedStringArray:
	var wall := Rect2(Vector2(-6, 2.5), Vector2(5, 3))             # a house just off the focus
	var door := Vector2(-3.5, 2.3)
	var standable := func(p: Vector2) -> bool: return not wall.grow(Spots.ROOM).has_point(p)
	var sees := func(a: Vector2, b: Vector2) -> bool:
		return not _crosses(wall, a, b)
	var g := Spots.Gathering.new(Vector2.ZERO, standable, sees)
	g.keep_clear.append([door, 1.5])
	var spots: Array[Vector2] = []
	var bad := PackedStringArray()
	var through := 0
	var side := 0.0
	for k in 24:
		var a := TAU * Spots._noise(k, 9)
		var from := Vector2(cos(a), sin(a)) * 25.0
		var p := g.claim(k, from)
		if wall.grow(Spots.ROOM - 0.01).has_point(p):
			bad.append("in the wall")
		if p.distance_to(door) < 1.5:
			bad.append("on the doorstep")
		if _crosses(wall, p, Vector2.ZERO):
			bad.append("behind the wall")
		for q in spots:
			if q.distance_to(p) < 0.7:
				bad.append("on someone (%.2f m)" % q.distance_to(p))
			if Geometry2D.get_closest_point_to_segment(q, from, p).distance_to(q) < Spots.PASS:
				through += 1
		side += absf(angle_difference(a, atan2(p.y, p.x)))
		spots.append(p)
	return PackedStringArray([_check(bad.is_empty() and through <= 1 and side / 24.0 < 0.6,
		"spots: 24 of %d at a wall and a door; awkward %s; ways in through someone %d; %.2f rad round from their side, on average" % [g.size(), bad, through, side / 24.0])])


static func _crosses(r: Rect2, a: Vector2, b: Vector2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


## A gathering of 16 fills and then empties towards one road: arriving, each takes the spot the gathering gives them
## (spots.gd), and leaving, those further out go first. Nobody is inside anyone, inching along (more than 0.3 s at
## 0.3-0.6 m/s) is rare (0.2 s a person at most, shuffling into a spot), and no speed snaps.
static func _gathering(leaving: bool) -> PackedStringArray:
	var root := Node.new()
	var g := Spots.Gathering.new(Vector2.ZERO, func(_p: Vector2) -> bool: return true)
	var specs := []
	var road := Vector2(0, 30)
	for k in 16:
		var a := TAU * Spots._noise(k, 3)
		var from := Vector2(cos(a), sin(a)) * 18.0 if not leaving else Vector2.ZERO
		specs.append([from, Vector2.ZERO, [30, 9, 70, 45][k % 4], 80 + k])
	var c := _crowd(specs, root)
	var movers: Array = c[1]
	for k in 16:
		var mv: Mover = movers[k]
		if leaving:
			var spot := g.claim(k, Vector2(cos(TAU * Spots._noise(k, 3)), sin(TAU * Spots._noise(k, 3))) * 18.0)
			mv.place(spot)
			mv.hold(spot)
		else:
			mv.go(PackedVector2Array([Vector2.ZERO + (mv.pos.normalized() * 4.0)]), INF, "", Persona.delay(mv.m, 7) + 3.0 * Spots._noise(k, 4))
	if leaving:
		for k in 16:
			var mv: Mover = movers[k]
			var home := road + Vector2((k % 4) * 3.0 - 4.5, (k / 4) * 3.0)      # each their own way home, up the road
			mv.go(PackedVector2Array([home]), INF, "", Persona.delay(mv.m, 9))
			var who := k
			mv.gate = func() -> bool:            # out of the crowd once nobody standing is in the way (residents.gd)
				if g.may_leave(who, home):
					g.release(who)
					return true
				return false
	(c[0] as Crowd).others = func() -> Array: return []
	var crawl := 0.0
	var closest := INF
	var worst := 0.0
	var hist := []
	var band := []
	for mv in movers:
		hist.append([])
		band.append(0.0)
	var w := int(0.1 / DT)
	var claimed := {}
	for k in int(50.0 / DT):
		(c[0] as Crowd)._process(DT)
		for i in movers.size():
			var mv: Mover = movers[i]
			if not leaving and not claimed.has(i) and mv.walking() and mv._left() < 7.0:
				claimed[i] = true         # on arrival, a spot (as residents.gd does)
				mv.go(PackedVector2Array([g.claim(i, mv.pos)]), INF, mv.style, mv.wait)
			var h: Array = hist[i]
			h.append(mv.pos)
			if h.size() > 2 * w:
				var v1: float = (h[-1] as Vector2).distance_to(h[-1 - w]) / 0.1
				var v0: float = (h[-1 - w] as Vector2).distance_to(h[-1 - 2 * w]) / 0.1
				worst = maxf(worst, absf(v1 - v0) / 0.1)
				if v1 > 0.3 and v1 < 0.6 and mv.walking():
					band[i] += DT
					if band[i] >= 0.3:
						crawl += DT if band[i] > 0.3 + DT * 0.5 else band[i]
						if OS.has_environment("PEOPLE_DEBUG") and band[i] < 0.3 + DT * 0.5:
							var near := 0
							for o: Mover in movers:
								if o != mv and o.pos.distance_to(mv.pos) < 1.2:
									near += 1
							print("  inching: %d at %.1f s, (%.1f, %.1f), %.1f m to go, %d near, wait %.1f" % [i, k * DT, mv.pos.x, mv.pos.y, mv._left(), near, mv.wait])
				else:
					band[i] = 0.0
			for j in range(i + 1, movers.size()):
				closest = minf(closest, mv.pos.distance_to((movers[j] as Mover).pos) / (0.5 * (float(mv.m.radius) + float((movers[j] as Mover).m.radius)) / 0.25))
	var there := 0
	for mv: Mover in movers:
		there += int(mv.arrived)
	root.free()
	return PackedStringArray([_check(closest >= OVERLAP and crawl / 16.0 <= 0.2 and worst <= 4.0 and there == 16,
		"a gathering %s: %d of 16 there; closest %.2f m (grown-size); %.2f s each of inching along; hardest speed change %.1f m/s2" % [
			"empties" if leaving else "fills", there, closest, crawl / 16.0, worst])])


## Frames are uneven on a phone (and a long one now and then): a crowd stepped at 60 fps with a 100 ms frame every
## second shows no snap, measured as the watcher measures (over 0.1 s of real frame time).
static func _uneven() -> PackedStringArray:
	var root := Node.new()
	var specs := []
	for k in 6:
		specs.append([Vector2(k * 1.5, 0), Vector2(k * 1.5, 20), [30, 9, 70][k % 3], 120 + k])
	var c := _crowd(specs, root)
	for mv: Mover in c[1]:
		mv.go(PackedVector2Array([mv.pos + Vector2(0, 20)]), INF, "", 0.3 * (mv.m.key % 4))
	(c[0] as Crowd).others = func() -> Array: return []
	var t := 0.0
	var times: Array[float] = []
	var hist := []
	for mv in c[1]:
		hist.append([])
	var worst := 0.0
	var k := 0
	while t < 18.0:
		var dt := 0.1 if k % 60 == 59 else DT
		k += 1
		(c[0] as Crowd)._process(dt)
		t += dt
		times.append(t)
		for i in c[1].size():
			(hist[i] as Array).append((c[1][i] as Mover).pos)
			var a := _at(times, hist[i], t - 0.1)
			var b := _at(times, hist[i], t - 0.2)
			if t > 0.4:
				var v1 := (hist[i][-1] as Vector2).distance_to(a) / 0.1
				var v0 := a.distance_to(b) / 0.1
				worst = maxf(worst, absf(v1 - v0) / 0.1)
	root.free()
	return PackedStringArray([_check(worst <= 4.0, "uneven frames (a 100 ms one every second): hardest speed change %.1f m/s2" % worst)])


## Where a track was at time `at` (linear between samples).
static func _at(times: Array[float], xs: Array, at: float) -> Vector2:
	for j in range(times.size() - 1, 0, -1):
		if times[j - 1] <= at:
			var f := (at - times[j - 1]) / maxf(times[j] - times[j - 1], 0.000001)
			return (xs[j - 1] as Vector2).lerp(xs[j], clampf(f, 0.0, 1.0))
	return xs[0]


## Round a house's corner (the way the routes go: a waypoint CORNER_PAD outside the wall's corner, a body's width
## out): never pushed by the wall, no speed snap, and a jogger keeps in a jog (no lingering between a walk and a jog,
## where no clip plays well).
static func _corner(how: String) -> PackedStringArray:
	var root := Node.new()
	var c := _crowd([[Vector2(-8, 3), Vector2(3, -8), 30, 150]], root)
	var crowd: Crowd = c[0]
	var wall := Rect2(Vector2(-6, -6), Vector2(6, 6))            # a house; its corner at the origin
	crowd.blocks.append(wall.grow(0.1))                          # as residents.gd gives the crowd its walls
	var mv: Mover = c[1][0]
	var corner := Vector2(0.35 + 0.3, 0.35 + 0.3)                # the router's corner: grown by a body, then padded
	mv.go(PackedVector2Array([corner, Vector2(3, -8)]), INF, how)
	crowd.others = func() -> Array: return []
	var walled := 0
	var gap := 0.0
	var worst := 0.0
	var hist := []
	var w := int(0.1 / DT)
	for k in int(22.0 / DT):
		crowd._process(DT)
		hist.append(mv.pos)
		if mv.shoved == 0.0 and mv.shoved_by == "wall":
			walled += 1
		var v := mv.vel.length()
		if v > 1.9 and v < 2.3:
			gap += DT
		if hist.size() > 2 * w:
			var v1: float = (hist[-1] as Vector2).distance_to(hist[-1 - w]) / 0.1
			var v0: float = (hist[-1 - w] as Vector2).distance_to(hist[-1 - 2 * w]) / 0.1
			worst = maxf(worst, absf(v1 - v0) / 0.1)
	var there := mv.arrived
	root.free()
	var ok := walled == 0 and worst <= 4.0 and there and (how != "jog" or gap <= 0.6)
	return PackedStringArray([_check(ok, "round a corner at a %s: pushed by the wall %d times; hardest speed change %.1f m/s2; %.2f s between a walk and a jog; there %s" % [
		how, walled, worst, gap, there])])


## Conversations: everyone a body's room from everyone else, at one distance from the middle; and when people walk
## into their places round it, nobody's way crosses another's.
static func _formations() -> PackedStringArray:
	var tight := INF
	var crossings := 0
	var pairs := 0
	for n in range(2, 7):
		var slots := Formation.circle(Vector2(3, 4), n, 0.3 * n)
		for i in n:
			for j in range(i + 1, n):
				tight = minf(tight, slots[i].distance_to(slots[j]))
		for trial in 20:
			var at := []
			for i in n:
				var a := TAU * Spots._noise(trial * 31 + i, n)
				at.append(Vector2(3, 4) + Vector2(cos(a), sin(a)) * (2.0 + 3.0 * Spots._noise(trial * 7 + i, 2)))
			var order := Formation.assign(Vector2(3, 4), slots, at)
			for i in n:
				for j in range(i + 1, n):
					pairs += 1
					if Geometry2D.segment_intersects_segment(at[i], slots[order[i]], at[j], slots[order[j]]) != null:
						crossings += 1
	return PackedStringArray([_check(tight >= 0.6 and crossings <= pairs / 100,
		"conversations of 2 to 6: talkers at least %.2f m apart (bodies touch at 0.50); ways into place that cross: %d of %d pairs" % [tight, crossings, pairs])])


## Who talks with whom: two households and two who cannot stand each other, at the well. Families stay together,
## the two at odds are never in one conversation, nobody is alone while a group would have them, and no group is
## bigger than five.
static func _groups() -> PackedStringArray:
	var house := {1: "a", 2: "a", 3: "a", 4: "b", 5: "b", 6: "c", 7: "c", 8: "d", 9: "e"}
	var affinity := func(a: int, b: int) -> float:
		if (a == 6 and b == 8) or (a == 8 and b == 6):
			return -60.0                 # at odds
		if house[a] == house[b]:
			return 60.0
		return 10.0 + 20.0 * Spots._noise(a * 13 + b, 1) - 10.0
	var groups := Groups.form([1, 2, 3, 4, 5, 6, 7, 8, 9], affinity)
	var together := true
	var apart := true
	var lonely := 0
	var biggest := 0
	for g: Array in groups:
		biggest = maxi(biggest, g.size())
		if g.size() == 1:
			lonely += 1
		if g.has(6) and g.has(8):
			apart = false
	for fam: Array in [[1, 2, 3], [4, 5]]:
		var homes := {}
		for g_i in groups.size():
			for m: int in fam:
				if (groups[g_i] as Array).has(m):
					homes[g_i] = true
		together = together and homes.size() == 1
	return PackedStringArray([_check(together and apart and lonely == 0 and biggest <= 5,
		"who talks with whom: %s; households together %s, the two at odds apart %s, alone %d" % [str(groups), together, apart, lonely])])


## The catalogue's choices: a village of every age and temper meeting each other in every way. People with a grudge
## never stop for a word, walk together or gossip; children never quarrel; only a grown one crouches to a child; and life is varied
## (many kinds of meeting, none of them most of all).
static func _encounters() -> PackedStringArray:
	var seen := {}
	var wrong := PackedStringArray()
	var met := 0
	for k in 3000:
		var ages := ["child", "adult", "elder"]
		# feelings as the village's rules give them (sim/village.gd): most neighbours neither here nor there (0), kin 50,
		# one pair in seven a friendship or a grudge (-60..60)
		var feel := func(salt: int) -> float:
			var r := Spots._noise(k, salt)
			return 50.0 if r < 0.15 else (lerpf(-60.0, 60.0, Spots._noise(k, salt + 10)) if r < 0.3 else 0.0)
		var a := {"age": ages[k % 3], "sociable": Spots._noise(k, 1), "temper": Spots._noise(k, 2), "likes": feel.call(3)}
		var b := {"age": ages[(k / 3) % 3], "sociable": Spots._noise(k, 4), "temper": Spots._noise(k, 5), "likes": feel.call(6)}
		var how: String = ["pass", "near", "still", "same_way"][(k / 9) % 4]
		var name := Encounters.choose(a, b, how, k)
		if name == "":
			continue
		met += 1
		seen[name] = int(seen.get(name, 0)) + 1
		var both := minf(float(a.likes), float(b.likes))
		if name in ["stop_for_a_word", "walk_together", "gossip"] and both < -20.0:     # (a grudge, in this village)
			wrong.append("%s between people at odds" % name)
		if name == "quarrel" and (a.age == "child" or b.age == "child"):
			wrong.append("a child quarrelling")
		if name == "crouch_to_child" and (a.age == "child" or b.age != "child"):
			wrong.append("crouch_to_child the wrong way round")
	var most := 0
	for n: String in seen:
		most = maxi(most, int(seen[n]))
	return PackedStringArray([_check(wrong.is_empty() and seen.size() >= 9 and float(most) / met < 0.35,
		"meetings: %d kinds in %d meetings (the commonest %.0f%%); wrong %s; %s" % [seen.size(), met, 100.0 * most / maxi(met, 1), wrong, str(seen)])])


## Variety: one stream of meetings at one spot, ten seconds apart, chosen with and without the memory of what was just
## seen there (society.gd _fresh). With it the same kind twice running, where another kind would have done, is much
## rarer; and nobody meets any less. (Where only one kind fits the two, a repeat is not a choice.)
static func _variety() -> PackedStringArray:
	var repeats := [0, 0]
	var forced := [0, 0]
	var met := [0, 0]
	var kinds := [{}, {}]
	for memory in 2:
		var seen: Array = []                 # [name, when]
		var last := ""
		for i in 600:
			var t := i * 10.0
			var k := i * 31 + 7
			var a := {"age": "adult", "sociable": Spots._noise(k, 1), "temper": Spots._noise(k, 2), "likes": 0.0}
			var b := {"age": ["adult", "adult", "elder", "child"][i % 4], "sociable": Spots._noise(k, 4),
				"temper": Spots._noise(k, 5), "likes": 0.0}
			var how: String = ["pass", "near", "still", "same_way"][(i / 2) % 4]
			var fresh := {}
			if memory == 1:
				for s: Array in seen:
					fresh[s[0]] = float(fresh.get(s[0], 0.0)) + exp(-(t - float(s[1])) / Society.SEEN_FADE)
			var name := Encounters.choose(a, b, how, k, fresh)
			if name == "":
				continue
			met[memory] += 1
			kinds[memory][name] = int(kinds[memory].get(name, 0)) + 1
			var fits := 0
			for n: String in Encounters.CATALOGUE:
				fits += 1 if Encounters.weight(n, a, b, how) > 0.0 else 0
			if name == last:
				if fits > 1:
					repeats[memory] += 1
				else:
					forced[memory] += 1
			last = name
			seen.append([name, t])
	return PackedStringArray([_check(met[0] == met[1] and met[0] > 100 and repeats[1] <= repeats[0] * 0.5,
		"variety: the same kind twice running where another would have done %d times in %d meetings without the memory of what was just seen, %d with it, at least halved (%d meetings; forced repeats %d, %d; kinds without %s, with %s)" % [
			repeats[0], met[0], repeats[1], met[1], forced[0], forced[1], str(kinds[0]), str(kinds[1])])])


## Two friends meet on the way and stop for a word: they come to stand face to face a conversation apart, nobody
## inside anyone, take turns, part, and walk on.
static func _word() -> PackedStringArray:
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 14), 30, 160], [Vector2(0.3, 9), Vector2(0.3, -5), 40, 161]], root)
	var a: Mover = c[1][0]
	var b: Mover = c[1][1]
	a.go(PackedVector2Array([Vector2(0, 14)]))
	b.go(PackedVector2Array([Vector2(0.3, -5)]))
	var crowd: Crowd = c[0]
	crowd.others = func() -> Array: return []
	var sit: Situation = null
	var closest := INF
	var apart := -1.0
	var facing := -1.0
	var ended := false
	for k in int(30.0 / DT):
		crowd._process(DT)
		if sit == null and not ended and a.pos.distance_to(b.pos) < 3.5:
			sit = Situation.new("stop_for_a_word", Encounters.CATALOGUE["stop_for_a_word"], [a, b], [null, null], 6.0, 7)
		if sit != null:
			if sit.phase == "beats" and apart < 0.0 and sit.t > 1.0:
				apart = a.pos.distance_to(b.pos)
				facing = rad_to_deg(absf(angle_difference(a.yaw, atan2(b.pos.x - a.pos.x, b.pos.y - a.pos.y))))
			if sit.update(DT):
				sit = null
				ended = true
				a.go(PackedVector2Array([Vector2(0, 14)]))
				b.go(PackedVector2Array([Vector2(0.3, -5)]))
		closest = minf(closest, a.pos.distance_to(b.pos))
	var there := a.arrived and b.arrived
	root.free()
	return PackedStringArray([_check(ended and apart > 0.8 and apart < 1.5 and facing < 25.0 and closest >= OVERLAP and there,
		"stop for a word: %.2f m apart, %.0f degrees off facing each other; closest %.2f m; parted and walked on %s" % [apart, facing, closest, there])])


## Two friends going the same way walk on side by side, at the slower one's pace.
static func _beside() -> PackedStringArray:
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 30), 30, 170], [Vector2(-1.5, -1.0), Vector2(-1, 30), 75, 171]], root)
	var a: Mover = c[1][0]
	var b: Mover = c[1][1]
	a.go(PackedVector2Array([Vector2(0, 30)]))
	b.go(PackedVector2Array([Vector2(-1, 30)]))
	var crowd: Crowd = c[0]
	crowd.others = func() -> Array: return []
	var sit := Situation.new("walk_together", Encounters.CATALOGUE["walk_together"], [a, b], [null, null], 14.0, 3)
	var beside := 0
	var steps := 0
	var closest := INF
	for k in int(14.0 / DT):
		crowd._process(DT)
		sit.update(DT)
		if k * DT > 3.0 and a.walking():
			steps += 1
			var d := a.pos.distance_to(b.pos)
			if d > 0.5 and d < 1.2:
				beside += 1
		closest = minf(closest, a.pos.distance_to(b.pos))
	sit.cleanup()
	root.free()
	var share := float(beside) / maxi(steps, 1)
	return PackedStringArray([_check(share >= 0.7 and closest >= OVERLAP,
		"walking together: side by side (0.5-1.2 m) %.0f%% of the way; closest %.2f m" % [share * 100.0, closest])])


## Two children chase each other: the one chased runs off, the other after; never inside each other, no snap.
static func _chase() -> PackedStringArray:
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 0), 8, 180], [Vector2(1.5, 0), Vector2(1.5, 0), 9, 181]], root)
	var a: Mover = c[1][0]
	var b: Mover = c[1][1]
	var crowd: Crowd = c[0]
	crowd.others = func() -> Array: return []
	var sit := Situation.new("chase", Encounters.CATALOGUE["chase"], [a, b], [null, null], 10.0, 11)
	var closest := INF
	var ran := 0.0
	var hist := []
	var worst := 0.0
	var w := int(0.1 / DT)
	for k in int(12.0 / DT):
		crowd._process(DT)
		if sit != null and sit.update(DT):
			sit = null
		ran = maxf(ran, a.vel.length())
		closest = minf(closest, a.pos.distance_to(b.pos) / 0.68)        # (children's bodies: grown-size)
		hist.append(b.pos)
		if hist.size() > 2 * w:
			var v1: float = (hist[-1] as Vector2).distance_to(hist[-1 - w]) / 0.1
			var v0: float = (hist[-1 - w] as Vector2).distance_to(hist[-1 - 2 * w]) / 0.1
			worst = maxf(worst, absf(v1 - v0) / 0.1)
	root.free()
	return PackedStringArray([_check(ran >= 2.5 and closest >= OVERLAP and worst <= 4.0,
		"children chasing: the chaser ran at %.1f m/s; closest %.2f m (grown-size); hardest speed change %.1f m/s2" % [ran, closest, worst])])


## A stay is not a statue: two minutes about the house - bits of work, steps round the yard (every spot a good one, in
## the yard), a look about, an errand to the well and back; never 15 s with nothing changing. And a dozen people
## starting the same stay change at their own moments, not in step.
static func _stay() -> PackedStringArray:
	var out := PackedStringArray()
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 0), 35, 190]], root)
	var mv: Mover = c[1][0]
	var crowd: Crowd = c[0]
	crowd.others = func() -> Array: return []
	var house := Rect2(2.0, -1.5, 3.0, 3.0)
	var well := Vector2(-9.0, 4.0)
	var world := {
		"good": func(p: Vector2) -> bool: return not house.grow(0.4).has_point(p) and p.distance_to(well) > 1.0,
		"open": func(p: Vector2, dir: Vector2) -> bool: return not house.has_point(p + dir.normalized() * 0.6),
		"busy": func(_p: Vector2, _r: float) -> bool: return false,
		"sights": func(_p: Vector2) -> Array: return [],
		"errands": func(_p: Vector2) -> Array: return [{"at": well + Vector2(1.5, 0.0), "face": well, "clips": ["Farm_Watering"],
			"seconds": 6.0, "weight": 1.0}],
	}
	var stay := Activity.Stay.new("about_the_house", mv, null, {"at": Vector2.ZERO, "face": Vector2(3.5, 0.0)}, world,
		{"key": 190, "restless": 0.6, "sociable": 0.9})
	stay.until = 400.0
	var did := {}
	var changes := 0
	var last := ""
	var spell := 0.0
	var longest := 0.0
	var spell_at := mv.pos
	var bad := 0
	var off := 0.0
	var errand_far := 0.0
	for k in int(150.0 / DT):
		crowd._process(DT)
		stay.update(DT)
		did[stay.doing] = int(did.get(stay.doing, 0)) + 1
		var now := "%s|%s" % [stay.doing, stay.clip]
		if now != last or mv.pos.distance_to(spell_at) > 0.3 or mv.walking():
			if now != last:
				changes += 1
			last = now
			spell = 0.0
			spell_at = mv.pos
		spell += DT
		longest = maxf(longest, spell)
		if not mv.walking() and house.has_point(mv.pos):
			bad += 1
		if stay.doing == "errand":
			errand_far = maxf(errand_far, mv.pos.distance_to(Vector2.ZERO))
		elif not mv.walking():
			off = maxf(off, mv.pos.distance_to(Vector2.ZERO))
	root.free()
	out.append(_check(longest < 15.0 and changes >= 12 and did.has("shift") and did.has("errand") and errand_far > 8.0
		and off <= 5.3 and bad == 0,
		"a stay about the house: %d changes in 150 s, the longest with nothing changing %.1f s; bits %s; off the anchor at most %.1f m (errand %.1f m); in the house %d" % [
			changes, longest, str(did.keys()), off, errand_far, bad]))
	# a dozen start together: their first changes spread out
	var firsts: Array[float] = []
	for n in 12:
		var r2 := Node.new()
		var c2 := _crowd([[Vector2(0, 0), Vector2(0, 0), 35, 300 + n]], r2)
		var s2 := Activity.Stay.new("praying", c2[1][0], null, {"at": Vector2.ZERO}, {}, {"key": 300 + n})
		var start := s2.clip
		var t := 0.0
		while t < 30.0 and s2.bits == int(Activity.noise(300 + n, 21) * 1000.0):
			s2.update(DT)
			t += DT
		firsts.append(t)
		r2.free()
	firsts.sort()
	out.append(_check(firsts[-1] - firsts[0] >= 2.0,
		"a dozen starting the same stay change at their own moments: first changes %.1f-%.1f s" % [firsts[0], firsts[-1]]))
	return out


## A conversation circle: four standing about come together round a middle (each 0.35-0.9 m from it, facing it within
## 30 degrees, as motion_watch.gd judges a heap), one joins and they open up for them, one leaves and they close up;
## never inside each other, the speaker changing.
static func _circle() -> PackedStringArray:
	var out := PackedStringArray()
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 0), 30, 400], [Vector2(2.2, 0.5), Vector2(0, 0), 40, 401],
		[Vector2(0.8, 2.4), Vector2(0, 0), 50, 402], [Vector2(-1.0, 1.6), Vector2(0, 0), 35, 403],
		[Vector2(4.0, 3.5), Vector2(0, 0), 28, 404]], root)
	var ms: Array = c[1]
	var crowd: Crowd = c[0]
	crowd.others = func() -> Array: return []
	var sit := Situation.new("talk", Encounters.CATALOGUE["talk"], ms.slice(0, 4), [null, null, null, null], INF, 21)
	sit.who = [0, 1, 2, 3]
	var closest := INF
	var speakers := {}
	var judged := []
	for k in int(24.0 / DT):
		var t := k * DT
		if k == int(8.0 / DT):
			sit.join(ms[4], null, 4, 0.8)
		if k == int(16.0 / DT):
			sit.leave(1)
		crowd._process(DT)
		sit.update(DT)
		if sit.speaker() >= 0:
			speakers[sit.who[sit.speaker()]] = true
		for i in ms.size():
			for j in range(i + 1, ms.size()):
				closest = minf(closest, (ms[i] as Mover).pos.distance_to((ms[j] as Mover).pos))
		for at: float in [7.5, 15.5, 23.5]:
			if k == int(at / DT):
				var ok := 0
				var why := []
				for m: Mover in sit.movers:
					var d := m.pos.distance_to(sit.centre)
					var facing := Vector2(sin(m.yaw), cos(m.yaw))
					var off := rad_to_deg(absf(facing.angle_to(sit.centre - m.pos)))
					if d >= 0.35 and d <= 0.9 and off <= 30.0:
						ok += 1
					else:
						why.append("%.2f m %.0f deg %s" % [d, off, "walking" if m.walking() else ""])
				judged.append("%d of %d" % [ok, sit.movers.size()])
				if not why.is_empty():
					judged.append(str(why))
	root.free()
	var all_in: bool = judged == ["4 of 4", "5 of 5", "4 of 4"]
	out.append(_check(all_in and closest >= OVERLAP and speakers.size() >= 3,
		"a conversation circle: in a ring facing in %s (4, then one joins, then one leaves); closest %.2f m; %d took a turn to talk" % [
			str(judged), closest, speakers.size()]))
	return out


## A circle evens itself out (Formation.fit, Situation._even_out): three talking have settled along one side of their
## middle, an arc 50 degrees apart (each held up a step short as they came), so that from where they stand one is
## almost in their midst and the others face past it. Within a few looks at the shape they stand round a ring, facing
## in, nobody inside anyone; and a ring already even stays as it is.
static func _circle_evens_out() -> PackedStringArray:
	var out := PackedStringArray()
	var even := Formation.circle(Vector2(1, 1), 4, 0.3)
	var fitted := Formation.fit(Vector2(1, 1), Array(even))
	var moved := 0.0
	for i in 4:
		moved = maxf(moved, even[i].distance_to(fitted[i]))
	out.append(_check(moved < 0.01, "a ring already even fits itself (the most anyone would move: %.3f m)" % moved))
	var root := Node.new()
	var centre := Vector2(0, 0)
	var arc: Array = []
	for deg: float in [200.0, 250.0, 300.0]:
		arc.append(Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * 0.7)
	var c := _crowd([[arc[0], Vector2(0, 0), 30, 410], [arc[1], Vector2(0, 0), 40, 411], [arc[2], Vector2(0, 0), 50, 412]], root)
	var ms: Array = c[1]
	var crowd: Crowd = c[0]
	crowd.others = func() -> Array: return []
	for m: Mover in ms:
		m.hold(m.pos, centre)
	var sit := Situation.new("talk", Encounters.CATALOGUE["talk"], ms, [null, null, null], INF, 23)
	sit.who = [0, 1, 2]
	sit.centre = centre
	sit.phase = "beats"
	var closest := INF
	for k in int(12.0 / DT):
		crowd._process(DT)
		sit.update(DT)
		for i in ms.size():
			for j in range(i + 1, ms.size()):
				closest = minf(closest, (ms[i] as Mover).pos.distance_to((ms[j] as Mover).pos))
	var mid := Vector2.ZERO
	for m: Mover in ms:
		mid += m.pos / 3.0
	var ok := 0
	var how := []
	for m: Mover in ms:
		var d := m.pos.distance_to(mid)
		var off := rad_to_deg(absf(Vector2(sin(m.yaw), cos(m.yaw)).angle_to(mid - m.pos)))
		if d >= 0.35 and d <= 0.9 and off <= 30.0 and not m.walking():
			ok += 1
		how.append("%.2f m %.0f deg" % [d, off])
	root.free()
	out.append(_check(ok == 3 and closest >= OVERLAP,
		"a circle settled along one side evens out: %d of 3 round their midst, facing in, after 12 s (%s); closest %.2f m" % [ok, str(how), closest]))
	return out


## The measure of leaving in step (motion_watch.gd in_step) still catches what the baseline showed, and only that:
## nineteen doors round a village opening in the same instant (8 m apart, as the houses stand) are in step; so is a
## household of three out of one door within a second; three strangers across the village who set off within 1.4 s
## on trips that began the same minute (the 60 fps evening, 1 Oct) are not: no eye sees them together.
static func _in_step() -> PackedStringArray:
	var village: Array = []
	for k in 19:
		village.append([0.0, "540", "door", Vector2(8.0 * (k % 5), 8.0 * (k / 5))])
	var household: Array = [[2.0, "540", "door", Vector2(1, 1)], [2.6, "540", "door", Vector2(1.3, 1)],
		[3.0, "540", "door", Vector2(1, 1.4)]]
	var strangers: Array = [[1.3, "660", "stood", Vector2(-17.8, 5.1)], [1.7, "660", "stood", Vector2(3.0, 21.3)],
		[2.7, "660", "stood", Vector2(6.6, 15.9)]]
	var v := MotionWatch.in_step(village, MotionWatch.SEEN_TOGETHER)
	var h := MotionWatch.in_step(household, MotionWatch.SEEN_TOGETHER)
	var s := MotionWatch.in_step(strangers, MotionWatch.SEEN_TOGETHER)
	# what counts as setting off: the holy day's walk at 09:02 and the evening's at 18:40 do; a child's dash at 18:01 on
	# a trip begun at 11:00 does not (the 60 fps evening, 1 Oct: three such steps within 0.92 s)
	var off := [MotionWatch.setting_off(540, 542), MotionWatch.setting_off(1080, 1120), MotionWatch.setting_off(660, 1081)]
	return PackedStringArray([_check(v == 0.0 and absf(h - 1.0) < 0.001 and s == INF and off == [true, true, false],
		"leaving in step, as seen: a village of doors at once %.2f s, a household %.2f s, strangers apart %s; setting off %s" % [
			v, h, str(s), str(off)])])


## No sudden starts or stops from bookkeeping (the S24 at 60 fps, 1 Oct): thirty stays that all begin at one moment
## (the clock jumped: a load, a night's sleep) take their first step spread over an ordinary spell, not all within the
## first seconds; and someone walking by whom a scene takes over (placed where they stand, then held) slows as people
## do, at most at the snap line (4 m/s2), and stops.
static func _no_sudden_stops() -> PackedStringArray:
	var out := PackedStringArray()
	var early := 0
	var last := 0.0
	for key in 30:
		var s := Activity.first_spell(8.0, key * 7 + 3)
		early += 1 if s < 4.0 else 0
		last = maxf(last, s)
	out.append(_check(early <= 15 and last > 8.0,
		"stays begun together: %d of 30 change within 4 s (before this change: 25, the last at 4.0 s); the last at %.1f s" % [early, last]))
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 20), 30, 430]], root)
	var crowd: Crowd = c[0]
	crowd.others = func() -> Array: return []
	var m: Mover = c[1][0]
	m.go(PackedVector2Array([Vector2(0, 20)]))
	for k in int(3.0 / DT):
		crowd._process(DT)
	var before := m.vel.length()
	m.place(m.pos, m.yaw)                     # what a scene does with someone it takes over (stage.gd _hide)
	m.hold(m.pos, Vector2.INF)
	var speeds := [before]
	for k in int(2.0 / DT):
		crowd._process(DT)
		speeds.append(m.vel.length())
	var hardest := 0.0
	var span := int(0.1 / DT)
	for i in range(span, speeds.size()):
		hardest = maxf(hardest, (float(speeds[i - span]) - float(speeds[i])) / 0.1)
	root.free()
	out.append(_check(before > 1.0 and hardest <= 4.0 and float(speeds[-1]) < 0.3,
		"a scene takes someone walking at %.2f m/s: they slow at most %.1f m/s2 to a stand (%.2f m/s after 2 s)" % [
			before, hardest, float(speeds[-1])]))
	return out


## Bumped by the player (the S24 at 60 fps, 1 Oct: a villager went from standing to 3.85 m/s in a frame): the player
## walks into someone standing at 4 m/s and presses on past their middle. They are never carried at the player's
## speed: the hard pass moves them a quick step at most (SHOVED_MOST), with their own step aside on top; they end clear.
static func _bumped() -> PackedStringArray:
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 0), 30, 440]], root)
	var crowd: Crowd = c[0]
	var m: Mover = c[1][0]
	m.hold(m.pos, Vector2.INF)
	var player := Node3D.new()
	root.add_child(player)
	crowd.others = func() -> Array: return [[player, 0.3]]
	var fastest := 0.0
	var trail: Array = []
	for k in int(2.0 / DT):
		var z := minf(-2.0 + 4.0 * k * DT, 0.1)          # in at 4 m/s, on 0.1 m past their middle
		player.position = Vector3(0.05, 0, z)
		crowd._process(DT)
		trail.append(m.pos)
		var span := int(0.1 / DT)
		if trail.size() > span:
			fastest = maxf(fastest, (trail[-1] as Vector2).distance_to(trail[-1 - span]) / 0.1)
	var gap := m.pos.distance_to(Vector2(player.position.x, player.position.z))
	root.free()
	return PackedStringArray([_check(fastest <= 2.5 and gap >= OVERLAP,
		"bumped by the player at 4 m/s: moved at most %.2f m/s, %.2f m clear at the end" % [fastest, gap])])


## A shove into the wall by a door: someone walking in at a door, close along the house wall, is pressed toward the wall
## by the crowd (a push of 12 m/s2, as the probe saw at the well). They walk on: the crowd never shoves anyone into a
## wall, so nobody stops dead against one. And someone placed partway along their way (a clock that jumped) is
## walking it from the first step, not setting off from a standstill.
static func _door_shove() -> PackedStringArray:
	var out := PackedStringArray()
	var ag := Steer.Agents.new()
	var walls: Array[Rect2] = [Rect2(-5.0, 0.0, 10.0, 3.0)]     # a house: its wall's face along y = 0
	var i := ag.add(Vector2(-2.0, -0.15), 0.25, 0.3, 2.0, 2.5, 1.6, Steer.WALKER)
	ag.vel[i] = Vector2(1.2, 0.0)
	ag.door[i] = 1
	var slowest := INF
	for k in 60:
		ag.avoid[i] = Vector2(0.0, 12.0)            # the crowd's push, toward the wall
		ag.want[i] = Vector2(1.2, 0.0)
		Steer.step(ag, DT, [], 1000, walls)
		slowest = minf(slowest, ag.vel[i].length())
	out.append(_check(slowest > 1.0 and ag.pos[i].x > -1.0,
		"pressed toward the wall by a door, they walk on (slowest %.2f m/s; at %s after 1 s)" % [slowest, str(ag.pos[i])]))
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 20), 30, 420]], root)
	var crowd: Crowd = c[0]
	crowd.others = func() -> Array: return []
	var m: Mover = c[1][0]
	m.place(Vector2(0, 6))
	m.go(PackedVector2Array([Vector2(0, 20)]), 20.0)
	m.under_way_already()
	crowd._process(DT)
	var first := m.vel.length()
	root.free()
	out.append(_check(first > 0.9, "put partway along their way, they are walking it from the first step (%.2f m/s)" % first))
	return out


## Stepping aside: someone stands in a lane 1.4 m wide between two walls; a walker comes through, and then the player
## (who never gives way). Each time they step out of the way and back to their spot; nobody is walked through.
static func _aside() -> PackedStringArray:
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 0), 40, 500], [Vector2(0, -8), Vector2(0, 8), 30, 501]], root)
	var crowd: Crowd = c[0]
	crowd.blocks = [Rect2(-3.7, -10, 3.0, 20), Rect2(0.7, -10, 3.0, 20)]   # the lane: x from -0.7 to 0.7
	var stander: Mover = c[1][0]
	var walker: Mover = c[1][1]
	stander.place(Vector2(0.1, 0))
	stander.hold(Vector2(0.1, 0), Vector2(0, -5))
	walker.go(PackedVector2Array([Vector2(0, 8)]))
	var player := Node3D.new()
	root.add_child(player)
	player.position = Vector3(0, 0, 30)
	var r := _run(crowd, [stander, walker], 30.0, [[player, 0.3]])
	var first := stander.asides
	var walked: bool = walker.arrived
	var walker_at := "%s vel %.2f wait %.2f path %s stander %s" % [str(walker.pos), walker.vel.length(), walker.wait, str(walker.path), str(stander.pos)]
	# the player walks straight down the lane at them
	var closest := INF
	var back := false
	for k in int(14.0 / DT):
		var t := k * DT
		player.position = Vector3(0.05, 0, clampf(-8.0 + 1.4 * t, -8.0, 8.0))
		crowd.others = func() -> Array: return [[player, 0.3]]
		crowd._process(DT)
		closest = minf(closest, stander.pos.distance_to(Vector2(player.position.x, player.position.z)))
	back = stander.pos.distance_to(Vector2(0.1, 0)) <= Mover.SETTLE
	walker_at += "; after the player: stander %s, walking %s, aside from %s" % [str(stander.pos), stander.walking(), str(stander._aside_from)]
	var second := stander.asides - first
	root.free()
	return PackedStringArray([_check(first >= 1 and walked and float(r.closest) >= OVERLAP and second >= 1 and closest >= 0.5 and back,
		"stepping aside in a lane: for a walker %d time(s) (the walker got through: %s, at %s; closest %.2f m), for the player %d (closest %.2f m); back on the spot %s" % [
			first, walked, str(walker_at), float(r.closest), second, closest, back])])


## Sent on while stepped aside: the same lane; once the stander has stepped out of the walker's way, they are sent to
## a new spot (a circle forming round them, their day moving on). They stay there: the spot they stepped off is no
## longer theirs to step back to.
static func _sent_on_while_aside() -> PackedStringArray:
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 0), 40, 500], [Vector2(0, -8), Vector2(0, 8), 30, 501]], root)
	var crowd: Crowd = c[0]
	crowd.blocks = [Rect2(-3.7, -10, 3.0, 20), Rect2(0.7, -10, 3.0, 20)]   # the lane: x from -0.7 to 0.7
	crowd.others = func() -> Array: return []
	var stander: Mover = c[1][0]
	var walker: Mover = c[1][1]
	stander.place(Vector2(0.1, 0))
	stander.hold(Vector2(0.1, 0), Vector2(0, -5))
	walker.go(PackedVector2Array([Vector2(0, 8)]))
	var new_spot := Vector2(0.2, -4.0)
	var sent := -1.0
	for k in int(20.0 / DT):
		crowd._process(DT)
		if sent < 0.0 and stander.asides > 0:
			sent = k * DT
			stander.go(PackedVector2Array([new_spot]), INF, "walk")
	var there := stander.pos.distance_to(new_spot)
	root.free()
	return PackedStringArray([_check(sent >= 0.0 and there <= Mover.SETTLE and stander.hold_at.distance_to(new_spot) < 0.3,
		"sent on while stepped aside: they stay at the new spot (sent at %.1f s; %.2f m from it after 20 s, holding %s)" % [
			sent, there, str(stander.hold_at)])])


## A society on its own (people/society.gd, no village): six at a chat - three who like each other, two who like each
## other, one nobody will have. They make two circles (the friends together), the one nobody will have stays alone,
## and each circle's middle is walked round (spaces); then 2 cools on 0 and 1 and warms to 3 and 4: the odd one out
## mingles to the circle they like better; then 3 is wanted elsewhere: their circle talks on without them.
static func _society() -> PackedStringArray:
	var root := Node.new()
	var c := _crowd([[Vector2(0, 0), Vector2(0, 0), 30, 500], [Vector2(1.6, 0.4), Vector2(0, 0), 40, 501],
		[Vector2(0.6, 1.8), Vector2(0, 0), 50, 502], [Vector2(6.0, 0.0), Vector2(0, 0), 35, 503],
		[Vector2(7.2, 1.0), Vector2(0, 0), 28, 504], [Vector2(3.5, -3.0), Vector2(0, 0), 45, 505]], root)
	var ms: Array = c[1]
	var crowd: Crowd = c[0]
	crowd.others = func() -> Array: return []
	var later := [false]
	var likes := func(a: int, b: int) -> float:
		if a == 5 or b == 5:
			return -40.0                     # nobody will have 5, and 5 will have nobody
		if later[0] and (a == 2 or b == 2):
			return 20.0 if mini(a, b) < 2 else (60.0 if maxi(a, b) == 4 else 30.0)   # 2 cools on 0, 1; warms to 3, 4
		if (a < 3) == (b < 3):
			return 40.0                      # friends: 0, 1, 2; and 3, 4
		return 0.0
	var back := []
	var director := {
		"mover": func(id: int) -> Mover: return ms[id],
		"body": func(_id: int) -> Node3D: return null,
		"world": {},
		"role": func(_id: int, _other: int) -> Dictionary: return {"age": "adult"},
		"affinity": likes,
		"voice": func(_id: int) -> float: return 0.5,
		"good": func(_p: Vector2) -> bool: return true,
		"busy": func(_p: Vector2, _r: float, _members: Array) -> bool: return false,
		"back": func(id: int, carry_on: bool) -> void: back.append([id, carry_on]),
	}
	var society := Society.new(director)
	crowd.spaces = society.spaces
	var everyone: Array[int] = [0, 1, 2, 3, 4, 5]
	var first := ""
	var mingled := ""
	var spaces := 0
	var closest := INF
	for k in int(70.0 / DT):
		if k % int(1.0 / DT) == 0:
			var lone: Array[int] = []
			for id in everyone:
				if not society.in_sit.has(id):
					lone.append(id)
			society.tend("square", lone)
		if k == int(10.0 / DT):
			first = _circles_of(society)
			spaces = society.spaces().size()
			later[0] = true
		if k == int(60.0 / DT):
			mingled = _circles_of(society)
			society.leave(3)
			everyone.erase(3)                # (gone: not at the chat to be asked again)
		crowd._process(DT)
		society.update(DT)
		for i in ms.size():
			for j in range(i + 1, ms.size()):
				closest = minf(closest, (ms[i] as Mover).pos.distance_to((ms[j] as Mover).pos))
	var after := _circles_of(society)
	root.free()
	var ok: bool = first == "[0, 1, 2] [3, 4]" and spaces == 2 and mingled == "[0, 1] [2, 3, 4]" and after == "[0, 1] [2, 4]"
	return PackedStringArray([_check(ok and not society.in_sit.has(5) and closest >= OVERLAP and [3, false] in back,
		"a society: circles %s at first (%d middles walked round), %s after a mingle, %s after one leaves; 5 alone: %s; closest %.2f m" % [
			first, spaces, mingled, after, not society.in_sit.has(5), closest])])


static func _circles_of(society: Society) -> String:
	var out: Array = []
	for sit: Situation in society.situations:
		var who: Array = sit.who.duplicate()
		who.sort()
		out.append(who)
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return " ".join(out.map(func(a: Array) -> String: return str(a)))


## Speech: four people say something at once (talk, a struck one's cry, a scene's line, talk): two bubbles show, the
## two that matter most; a conversation's second line ends its first; two bubbles over people side by side do not
## overlap on screen; a long line wraps within 30% of the screen's width.
static func _speech() -> PackedStringArray:
	var tree := Engine.get_main_loop() as SceneTree
	var root := Node3D.new()
	tree.root.add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 50.0
	cam.position = Vector3(0, 4, 9)
	cam.look_at(Vector3(0, 1.5, 0))
	cam.current = true
	var speech := Speech.new()
	speech.camera = cam
	root.add_child(speech)
	var bodies: Array = []
	for i in 4:
		var b := Node3D.new()
		b.position = Vector3(-1.5 + i * 0.6, 0, 0)
		root.add_child(b)
		bodies.append(b)
	speech.say(bodies[0], "The well tastes of iron lately.", Speech.TALK, 11)
	speech.say(bodies[1], "Help! Help me!", Speech.STRUCK)
	speech.say(bodies[2], "Free! I won't forget you.", Speech.SCENE)
	speech.say(bodies[3], "Rain soon. My knee says so.", Speech.TALK, 12)
	for k in 30:
		speech._process(DT)
	var shown := []
	for i in 4:
		if bodies[i].get_node_or_null(Speech.NAME) != null:
			shown.append(i)
	var screen := tree.root.get_visible_rect().size
	var r1: Rect2 = speech._rect(cam, speech._shown[0]) if speech._shown.size() > 0 else Rect2()
	var r2: Rect2 = speech._rect(cam, speech._shown[1]) if speech._shown.size() > 1 else Rect2()
	var overlap := r1.intersection(r2).get_area()
	# a conversation: its second line ends its first
	speech.hush(0)
	for l in speech._shown.duplicate():
		speech._drop(l)
	speech.say(bodies[0], "Did you see the stag?", Speech.TALK, 21)
	speech.say(bodies[3], "Never.", Speech.TALK, 21)
	var one_voice: bool = bodies[0].get_node_or_null(Speech.NAME) == null and bodies[3].get_node_or_null(Speech.NAME) != null
	# a long line wraps
	speech.say(bodies[2], "Half the village claims to be cousin to the other half, and the other half denies it to anyone who asks.", Speech.SCENE)
	for k in 10:
		speech._process(DT)
	var widest := 0.0
	for l in speech._shown:
		widest = maxf(widest, speech._rect(cam, l).size.x / screen.x)
	root.queue_free()
	tree.root.remove_child(root)
	root.free()
	return PackedStringArray([_check(shown == [1, 2] and overlap <= 1.0 and one_voice and widest > 0.05 and widest <= 0.30,
		"speech: of four at once, shown %s (the cry and the scene's line); on screen overlapping %.0f px2; a conversation's second line ends its first %s; the widest bubble %.0f%% of the screen" % [
			str(shown), overlap, one_voice, widest * 100.0])])


## One owner per body (owners.gd): a higher claim takes them and the holder lets go; a lower one is refused; equal, the
## latest wins; a kept claim waits under a higher one and has them back when it releases; only the holder's release
## counts; nobody holding them is their day.
static func _owners() -> PackedStringArray:
	var o := Owners.new()
	var log: Array = []
	var lost := func(id: int, by: String) -> void: log.append(["lost", id, by])
	o.resumed["happening"] = func(id: int) -> void: log.append(["resumed", id])
	var ok := true
	var notes: Array = []
	ok = ok and o.is_free(1) and o.owner(1) == ""
	ok = ok and o.claim(1, "society", 1, lost)
	ok = ok and not o.claim(1, "society2", 0, lost)                     # lower: refused
	notes.append("refused " + str(o.owner(1) == "society"))
	ok = ok and o.claim(1, "act", 4, lost) and log == [["lost", 1, "act"]]   # higher: the society lets go
	ok = ok and o.claim(1, "talk", 4, lost) and log.back() == ["lost", 1, "talk"]   # equal: the latest wins
	o.release(1, "act")                                                   # not the holder: nothing
	ok = ok and o.held(1, "talk")
	o.release(1, "talk")
	ok = ok and o.is_free(1)
	log.clear()
	ok = ok and o.claim(2, "happening", 3, lost, true)                    # kept: suspended, not let go
	ok = ok and o.claim(2, "stage", 5, lost) and log.is_empty() and o.held(2, "stage")
	ok = ok and o.of("happening") == [2]
	o.release(2, "stage")
	ok = ok and o.held(2, "happening") and log == [["resumed", 2]]
	ok = ok and o.claim(3, "happening", 3, lost, true) and o.claim(3, "stage", 5, lost)
	o.release(3, "happening")                                             # a suspended one withdraws
	o.release(3, "stage")
	ok = ok and o.is_free(3) and o.can_claim(4, 0)
	return PackedStringArray([_check(ok, "owners: higher takes and the holder lets go, lower refused, equal latest wins, "
		+ "kept resumed, only the holder releases (%s; log %s)" % [", ".join(notes), str(log)])])


## The stimulus door (stimuli.gd): a shout carries as far as it is loud, less through a wall, the strongest first, and
## is forgotten when it is over.
static func _stimuli() -> PackedStringArray:
	var st := Stimuli.new()
	var shout := st.emit("shout", Vector2(0, 0), 28.0, 4, 3.0)
	st.emit("word", Vector2(10, 0), 4.0, 5, 3.0)
	var at := Vector2(20, 0)
	var heard: Array = st.heard(at)
	var ok := heard.size() == 1 and int(heard[0].id) == shout                       # the word does not carry 10 m
	ok = ok and st.heard(Vector2(30, 0)).is_empty()                                # nor the shout 30 m
	ok = ok and st.heard(Vector2(11, 0)).size() == 2 and heard[0].kind == "shout"
	var near_word := st.heard(Vector2(11, 0))
	ok = ok and near_word[0].kind == "word"                                        # 1 m from a word: it is the stronger there
	ok = ok and is_equal_approx(st.carry(heard[0], Vector2(14, 0)), 0.5)
	st.muffle = func(a: Vector2, b: Vector2) -> float: return 0.5 if (a.x < 15.0) != (b.x < 15.0) else 1.0   # a wall at x 15
	ok = ok and st.heard(at).is_empty() and st.heard(Vector2(12, 0)).size() == 2  # behind the wall, 20 m: not heard
	ok = ok and st.near(Vector2(9, 0), 2.0).size() == 1
	st.update(2.0)
	ok = ok and st.all.size() == 2
	st.update(1.5)
	ok = ok and st.all.is_empty() and st.given == 2
	return PackedStringArray([_check(ok, "stimuli: a shout carries as loud as it is, a word does not, the nearer is stronger, a wall halves it, over is forgotten")])
