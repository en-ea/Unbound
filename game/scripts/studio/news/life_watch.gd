extends RefCounted
## The liveliness measures the news probe adds for plan LIVELY-VILLAGE (section 0, the baselines; section 3.0, the end
## measures, rebuilt after the devil's-advocate review because the first ones could not tell people from a machine;
## section 2.1, the gates). A measure only: it reads the village and its bodies, never changes them.
##
##   ends     every end of a scene near the player, and how its people leave it:
##              a staged act's outcome (a public act, a hearing, a rite: the moment the rules decided it)
##              a happening over on the bodies (an argument, a town meeting: its runner gone)
##              a conversation circle (its members, once out of it, walking off)
##              a day's stretch: the end of work (WORK_LOOK), the noon meal (MEAL_LOOK), the evening (EVENING_LOOK):
##              those then at a gathering place or at work near the player
##            per member: `moved` (their first step or change of clip), `left` (beyond the scene's ring + LEAVE_M, or
##            indoors), and what they did of their own (own_acts: section 3.0 and the review's round 2, MUST 2);
##            kin of the subject reaching them (within KIN_M in KIN_S)
##            per end (end_stats): units (a household, or people walking off side by side, leave as one), an exodus
##            (more than max(3, 20% of the crowd) units within EXODUS_S), the irregularity of the departures (the
##            coefficient of variation of the gaps between units), first moves' spread, first to last leaving
##   purpose  everyone whose day has them within NEAR of the player, out of doors, by day: walking somewhere, with
##            people, at work on a thing, at play, or nothing visible ("none:<what they are at>")
##   village  the first village-scale event begun in view (seconds of play) and every one after
##   cost     the residents' frame work each frame (residents.gd frame_usec), and with the stage's own
##
## Moment: each probe frame. Clock: seconds of play (the probe's own count, at normal speed). Window: an end is watched
## for its kind's WATCH seconds; who has not left by then stayed.

const LEAVE_M := 6.0         # metres beyond the scene's ring: gone from it (a step toward the victim is not leaving)
const RING_SHARE := 0.8      # the ring: the distance from the middle within which this share of its people stood
const MOVED_M := 0.3         # metres: a step
const TURNED := 0.906        # cos 25 degrees: a turn from where they faced at the end is a first move too
const VEL_S := 0.25          # seconds: the time constant the bodies' velocity is smoothed over (it is read from where
                             # the bodies are, not from their movers: a stage drives its own and leaves theirs at rest)
const REACT_S := 10.0        # seconds after the end within which a reaction counts
const ANSWERING := ["stage", "happening", "reaction", "cast", "act"]   # who holds them when what they do answers the end:
                             # their day, a circle (society) or the player's talk is not an answer to it
const TOWARD_M := 3.0        # metres nearer the subject than at the end ...
const TOWARD_S := 30.0       # ... seen when they stop by them within this (the walk there takes time; walking past
const NEAR_STOP_M := 3.0     # does not stop): within this of them, or ...
const FACE_STOP_M := 6.0     # ... within this, facing them
const FACING := 0.5          # cos 60 degrees: facing the subject
const REST_SPEED := 0.3      # m/s: standing
const AWAY_SPEED := 2.2      # m/s: going away from it at a run (a hurry is 1.6-1.75, a jog 3.0 and up)
const KIN_M := 2.0           # metres: kin at their side ...
const KIN_S := 60.0          # ... within this many seconds
const CV_LEAST := 0.5         # the gaps between departure units, 8 or more: their coefficient of variation at least this
const EXODUS_S := 2.0        # seconds: a window more than max(3, 20% of the crowd) units leave in is an exodus
const UNIT_HOUSE_S := 3.0    # seconds: one household leaving within this of each other leaves as one
const UNIT_SIDE_S := 1.5     # seconds, and ...
const UNIT_SIDE_M := 2.0     # ... metres: people leaving side by side leave as one
const WATCH := {"evening": 260.0, "work": 120.0, "meal": 90.0, "circle": 60.0}
const WATCH_SCENE := 150.0
const WORK_LOOK := 1030      # 17:10: before the first work ends (1035)
const MEAL_LOOK := 705       # 11:45
const EVENING_LOOK := 1140   # 19:00: before the first evening ends (1150)
const EVENING_PLACES := ["well", "square", "shrine"]
const NEAR := 30.0
const WALK_IDLE := ["Walk", "Walk_Carry", "Walk_Formal", "Jog_Fwd", "Push", "Sprint", "", "Idle"]
## The stays whose work has a thing to work on standing in the village today (the plan's baseline definition:
## the well, the windmill, the merchant's stall, the anvil at the smithy, the trees at the woods). Farming at the
## bare field, gathering, herding with no flock, hunting at nothing, chores at nothing, eating with nothing in
## hand, loitering and waiting have none.
const OBJECT_KINDS := ["fetching_water", "milling", "trading", "smithing", "woodcutting"]
const VILLAGE_PREFIXES := ["public:", "hearing:", "rite:", "happening:meeting", "happening:feast", "happening:mourning",
	"happening:death_found", "happening:hue_and_cry", "happening:fire"]

var reg: Node                 # residents.gd
var live: Node                # live.gd
var ends_open: Array = []
var ends_done: Array = []
var village: Array = []       # [seconds of play, kind]
var purpose := {}             # what -> samples
var purpose_work := [0, 0]    # adults in working hours (08:00-17:00): [at work with a thing, all]
var cost := PackedInt32Array()
var cost_staged := PackedInt32Array()
var _runs := {}               # happening id -> {kind, cast, at, a, last}
var _circles := {}            # a talk Situation -> {centre, members: {id: true}}
var _staged := {}             # event id -> true: its end is watched
var _looked := {}             # "evening:<day>" -> true


func _init(the_live: Node) -> void:
	live = the_live
	reg = live.registry


## Each frame: `t` seconds of play, `eye` where the player stands, `minute` the game minute of the day.
func step(v, t: float, eye: Vector2, minute: int, by_day: bool) -> void:
	_cost_now()
	_staged_ends(v, t)
	_happening_ends(t)
	_circle_ends(v, t)
	var day := int(v.runtime.now) / 1440
	for look: Array in [["evening", EVENING_LOOK], ["work", WORK_LOOK], ["meal", MEAL_LOOK]]:
		var key := "%s:%d" % [look[0], day]
		if minute >= int(look[1]) and minute < int(look[1]) + 20 and not _looked.has(key):
			_looked[key] = true
			_stretch(v, str(look[0]), t, eye)
	for e: Dictionary in ends_open:
		_watch(v, e, t)
		e.t_last = t
	for i in range(ends_open.size() - 1, -1, -1):
		var e: Dictionary = ends_open[i]
		if t - float(e.at) > float(e.watch) or (e.members as Dictionary).values().all(func(m: Dictionary) -> bool: return float(m.left) >= 0.0):
			ends_done.append(e)
			ends_open.remove_at(i)


## A happening or a staged act begun in view (the probe's own _begun): village-scale ones are noted.
func begun(kind: String, t: float) -> void:
	for p: String in VILLAGE_PREFIXES:
		if kind.begins_with(p):
			village.append([snappedf(t, 0.1), kind])
			return


## Every PURPOSE sample: what each person near the player out of doors is visibly about.
func sample_purpose(v, eye: Vector2) -> void:
	for id: int in reg.bodies:
		var p = v.people[id]
		if not p.alive or not p.present:
			continue
		var m = reg._movers.get(id)
		var body: Node3D = reg.bodies[id]
		if m == null or (m.pos as Vector2).distance_to(eye) > NEAR or m.indoors or not body.is_visible_in_tree():
			continue
		var what := purpose_of(id)
		purpose[what] = int(purpose.get(what, 0)) + 1
		var minute := int(v.runtime.now) % 1440
		if minute >= 480 and minute < 1020 and VillageSession.Runtime.Village.age_of(v, p) >= 16:
			purpose_work[1] += 1
			if what == "object":
				purpose_work[0] += 1


func purpose_of(id: int) -> String:
	var by: String = reg.owners.owner(id)
	if by != "":
		return "with people (%s)" % by
	var m = reg._movers[id]
	if m.walking() and not (m.path as PackedVector2Array).is_empty() and (m.pos as Vector2).distance_to(m.path[-1]) > 3.0:
		return "walking"
	var stay = reg._stays.get(id)
	if stay == null:
		var a: Dictionary = reg._activity.get(id, {})
		return "none:no stay (%s)" % str(a.get("verb", "?"))
	if stay.doing == "errand":
		return "walking"
	if stay.kind == "child_about" and stay.doing == "play":
		return "play"
	if stay.kind in OBJECT_KINDS:
		return "object"
	if stay.get("thing") != null and is_instance_valid(stay.get("thing")):
		return "object"                       # (a task's stay names the thing it works on)
	if stay.kind == "praying":
		return "prayer"
	return "none:" + str(stay.kind)


func report(day_s: float) -> Dictionary:
	var out := {}
	var by := {}
	for e: Dictionary in ends_done + ends_open:
		(by.get_or_add(str(e.kind).get_slice(":", 0) + ":" + str(e.kind).get_slice(":", 1), []) as Array).append(e)
	var ends := {}
	for k: String in by:
		var rows: Array = by[k]
		var per: Array = []
		for e: Dictionary in rows:
			per.append(end_row(e))
		ends[k] = {"ends": rows.size(), "each": per}
	out.ends = ends
	# purpose
	var all := 0
	var with := 0
	var none := {}
	var parts := {}
	for what: String in purpose:
		all += int(purpose[what])
		if what.begins_with("none:"):
			none[what.trim_prefix("none:")] = int(purpose[what])
		else:
			with += int(purpose[what])
			parts[what.get_slice(" ", 0)] = int(parts.get(what.get_slice(" ", 0), 0)) + int(purpose[what])
	var none_share := {}
	for what: String in none:
		none_share[what] = snappedf(float(none[what]) / maxf(all, 1.0), 0.01)
	var part_share := {}
	for what: String in parts:
		part_share[what] = snappedf(float(parts[what]) / maxf(all, 1.0), 0.01)
	out.purpose_share = snappedf(float(with) / maxf(all, 1.0), 0.01)
	out.purpose_parts = part_share
	out.purpose_none = none_share
	out.purpose_samples = all
	# section 1.6's limits: walking of the purposeful, adults at work with a thing in working hours, work at nothing
	out.walking_of_purposeful = snappedf(float(purpose.get("walking", 0)) / maxf(with, 1.0), 0.01)
	out.work_thing_share = snappedf(float(purpose_work[0]) / maxf(purpose_work[1], 1.0), 0.01)
	var at_nothing := 0
	for what: String in none:
		if what in ["farming", "herding", "eating"] or what.begins_with("no stay"):
			at_nothing += int(none[what])
	out.at_nothing_share = snappedf(float(at_nothing) / maxf(all, 1.0), 0.01)
	# village-scale
	out.village_first_s = village[0][0] if not village.is_empty() else -1.0
	out.village_per_20 = snappedf(village.size() * 20.0 * 60.0 / maxf(day_s, 1.0), 0.1)
	out.village_kinds = village.map(func(x: Array) -> String: return "%s@%ds" % [x[1], int(x[0])])
	out.cost_ms = _percentiles(cost)
	out.cost_staged_ms = _percentiles(cost_staged)
	return out


## One end, measured (section 3.0).
static func end_row(e: Dictionary) -> Dictionary:
	var members: Dictionary = e.members
	var lefts: Array = []
	var moves: Array = []
	var stirs: Array = []                                    # never stirred: frozen to the watch's end
	var stayed := 0
	var reacted := 0
	var kinds := {}
	for id: int in members:
		var mm: Dictionary = members[id]
		if float(mm.moved) >= 0.0:
			moves.append(float(mm.moved))
		stirs.append(float(mm.get("stirred", mm.moved)) if float(mm.get("stirred", mm.moved)) >= 0.0 else float(e.get("watch", WATCH_SCENE)))
		if float(mm.left) >= 0.0:
			lefts.append([float(mm.left), int(mm.house), mm.at_left])
		else:
			stayed += 1
		if not (mm.own as Dictionary).is_empty():
			reacted += 1
			for o: String in mm.own:
				kinds[o] = true
	var stats := end_stats(lefts, members.size())
	var spread := float(stats.spread)
	if stayed > 0 and not lefts.is_empty():                  # who stays past the watch leaves after it
		var first := INF
		for l: Array in lefts:
			first = minf(first, float(l[0]))
		spread = snappedf(float(e.get("watch", WATCH_SCENE)) - first, 0.1)
	moves.sort()
	var row := {"kind": str(e.kind), "members": members.size(), "stayed": stayed, "units": stats.units,
		"exodus": stats.exodus, "worst_burst": stats.worst_burst, "gap_cv": stats.cv, "spread_s": spread,
		"first_move_spread_s": snappedf(_q(moves, 0.9) - _q(moves, 0.1), 0.1) if moves.size() >= 2 else -1.0,
		"first_move_median_s": snappedf(_q(moves, 0.5), 0.1) if not moves.is_empty() else -1.0,
		"first_stir_median_s": snappedf(_q(stirs, 0.5), 0.1), "first_stir_p80_s": snappedf(_q(stirs, 0.8), 0.1),
		"reacted_share": snappedf(float(reacted) / maxf(members.size(), 1.0), 0.01), "visible_kinds": kinds.keys().size(),
		"what": kinds.keys()}
	if int(e.get("kin_present", 0)) > 0:
		row.kin_present = int(e.kin_present)
		row.kin_reached = bool(e.get("kin_reached", false))
	if members.size() >= 8:                                  # the departures themselves, to replay (news_tests' fixtures):
		                                                     # [left, household, x, z, first step, set off, first stir, seen]
		var raw: Array = []
		for id: int in members:
			var mm: Dictionary = members[id]
			raw.append([snappedf(float(mm.left), 0.1), int(mm.house), snappedf((mm.at_left as Vector2).x, 0.1),
				snappedf((mm.at_left as Vector2).y, 0.1), snappedf(float(mm.moved), 0.1), snappedf(float(mm.get("set_off", -1.0)), 0.1),
				snappedf(float(mm.get("stirred", -1.0)), 0.1), (mm.own as Dictionary).keys()])
		row.raw = raw
	row.missed = end_missed(row)
	return row


## The gates an end of its size and kind misses (plan LIVELY-VILLAGE 2.1, with the review's round 2 MUST 3): [] when
## it meets every one that applies. Every end: no exodus. 10 or more people: first moves spread 3 s or more, the last
## leaving 45 s or more after the first (60 for the evening). 8 or more departure units: a gap CV of 0.5 or more (0.6
## re-based with the reviewer's agreement, round 3: natural ends fell under 0.6 up to 6% of the time, every conveyor
## stays under 0.45; plan/evidence/end-gates-montecarlo.py).
## 3-9 people: first moves spread 2 s or more, the last 15 s or more after the first. The ends of scenes (not a
## stretch of the day, not a circle): 0.4 or more reacting visibly, with 4 or more kinds seen in a crowd of 10 or
## more (3 in 5-9); kin there reach the one at the centre; and no freeze: the first stir (a step, a change of clip or a
## turn) median 5 s or less, p80 8 s or less (round 3: the real pillory stood 11 s; turns stay out of the first moves'
## spread, or the staggered turn would squeeze it).
static func end_missed(row: Dictionary) -> Array:
	var out: Array = []
	var n := int(row.members)
	var kind := str(row.kind)
	if row.exodus:
		out.append("exodus")
	if n >= 10:
		if float(row.first_move_spread_s) < 3.0:
			out.append("first moves %.1f s" % float(row.first_move_spread_s))
		var last := 60.0 if kind.begins_with("evening") else 45.0
		if float(row.spread_s) < last:
			out.append("last after first %.1f s" % float(row.spread_s))
	elif n >= 3:
		if float(row.first_move_spread_s) < 2.0:
			out.append("first moves %.1f s" % float(row.first_move_spread_s))
		if float(row.spread_s) < 15.0:
			out.append("last after first %.1f s" % float(row.spread_s))
	if int(row.units) >= 8 and float(row.gap_cv) < CV_LEAST:
		out.append("gap cv %.2f" % float(row.gap_cv))
	var scene := not (kind.begins_with("evening") or kind.begins_with("work") or kind.begins_with("meal") or kind.begins_with("circle"))
	if scene and n >= 5 and (float(row.get("first_stir_median_s", 0.0)) > 5.0 or float(row.get("first_stir_p80_s", 0.0)) > 8.0):
		out.append("frozen: first stir median %.1f s, p80 %.1f s" % [float(row.first_stir_median_s), float(row.first_stir_p80_s)])
	if scene and n >= 5:
		if float(row.reacted_share) < 0.4:
			out.append("reacted %.2f" % float(row.reacted_share))
		if int(row.visible_kinds) < (4 if n >= 10 else 3):
			out.append("kinds %d" % int(row.visible_kinds))
	if scene and int(row.get("kin_present", 0)) > 0 and not row.get("kin_reached", false):
		out.append("kin not reached")
	return out


## The departures of an end, as people leave (section 3.0). `lefts`: [[seconds after the end, household, where (a
## Vector2)], ...]; `crowd`: how many were in it. A household leaving within UNIT_HOUSE_S of each other, or people
## leaving side by side (UNIT_SIDE_S, UNIT_SIDE_M), leave as one unit. -> {units, exodus (more than max(3, 20% of the
## crowd) units within EXODUS_S), worst_burst (the most units within EXODUS_S), cv (the coefficient of variation of the
## gaps between units: -1 under four units), spread (first to last leaving, seconds)}
static func end_stats(lefts: Array, crowd: int) -> Dictionary:
	var s := lefts.duplicate()
	s.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var units: Array = []           # [time of the first, household, last where]
	for l: Array in s:
		var joined := false
		for u: Array in units:
			var same_house := int(l[1]) >= 0 and int(u[1]) == int(l[1]) and float(l[0]) - float(u[0]) <= UNIT_HOUSE_S
			var side := float(l[0]) - float(u[0]) <= UNIT_SIDE_S and (l[2] as Vector2).distance_to(u[2] as Vector2) <= UNIT_SIDE_M
			if same_house or side:
				u[2] = l[2]
				joined = true
				break
		if not joined:
			units.append([float(l[0]), int(l[1]), l[2]])
	var times: Array = units.map(func(u: Array) -> float: return float(u[0]))
	var worst := 0
	for i in times.size():
		var n := 0
		for j in range(i, times.size()):
			if float(times[j]) - float(times[i]) > EXODUS_S:
				break
			n += 1
		worst = maxi(worst, n)
	var cv := -1.0
	if times.size() >= 4:
		var gaps: Array = []
		for i in range(1, times.size()):
			gaps.append(float(times[i]) - float(times[i - 1]))
		var mean := 0.0
		for g: float in gaps:
			mean += g / gaps.size()
		var sd := 0.0
		for g: float in gaps:
			sd += (g - mean) * (g - mean) / gaps.size()
		cv = snappedf(sqrt(sd) / maxf(mean, 0.001), 0.01)
	return {"units": units.size(), "worst_burst": worst, "exodus": worst > maxi(3, int(ceil(0.2 * crowd))),
		"cv": cv, "spread": snappedf(float(s[-1][0]) - float(s[0][0]), 0.1) if not s.is_empty() else -1.0}


# ---------- the ends ----------

func _cost_now() -> void:
	var fu: Array = reg.get("frame_usec")
	if fu == null or fu.is_empty():
		return
	var us := int(fu[-1])
	cost.append(us)
	var stage = live.get("_stage")
	if stage != null and is_instance_valid(stage):
		cost_staged.append(us + int(stage.last_cost_us()))
	else:
		cost_staged.append(us)


func _staged_ends(v, t: float) -> void:
	var stage = live.get("_stage")
	var eid := int(live.get("_event"))
	if stage == null or not is_instance_valid(stage) or eid < 0 or _staged.has(eid):
		return
	var R = VillageSession.Runtime
	var e: Dictionary = R.event_by_id(v, eid)
	if e.is_empty() or e.type == "incident" or not R.terminal(e):
		return
	_staged[eid] = true
	var st: Dictionary = R.staging(v, eid)
	var ids: Array = []
	var victim := int(e.victim)
	for a in stage._actors:
		if ((not a.inside and not a.gone) or a.handed) and a.id != victim:     # (handed: let go to their reactions)
			ids.append(int(a.id))
	_open(v, "%s:%s:%s" % [e.type, str(st.get("kind", "")), str(e.outcome)], stage.place_at(), ids, t, victim, WATCH_SCENE)


func _happening_ends(t: float) -> void:
	for hid: int in _runs.keys():
		if not reg.runs.has(hid):
			var was: Dictionary = _runs[hid]
			_runs.erase(hid)
			_open(VillageSession.village, "happening:%s:%s" % [was.kind, was.last], was.at, was.cast, t, int(was.a), WATCH_SCENE)
	for hid: int in reg.runs:
		var run = reg.runs[hid]
		if run.phase == "done":
			continue
		_runs[hid] = {"kind": str(run.record.kind), "cast": (run._cast as Array).duplicate(), "a": int(run.record.a),
			"at": reg._happening_at(VillageSession.village, run.record), "last": str((run.record.path as Array).back())}


## A circle: each member's leaving is watched from the moment they are out of it (they part one by one, or all at
## once); the end is opened when the first leaves, so the first to go starts its clock.
func _circle_ends(v, t: float) -> void:
	var now := {}
	for sit in reg.society.situations:
		if sit.name == "talk":
			now[sit] = true
	for sit in _circles.keys():
		var c: Dictionary = _circles[sit]
		var still: Array = (sit.who as Array) if now.has(sit) else []
		var gone: Array = []
		for id: int in c.members:
			if not still.has(id):
				gone.append(id)
		if not gone.is_empty() and c.end == null and (c.members as Dictionary).size() >= 3:
			c.end = _open(v, "circle:talk", c.centre, (c.members as Dictionary).keys(), t, -1, WATCH.circle, 1.0)
		if not now.has(sit):
			_circles.erase(sit)
	for sit in now:
		if not _circles.has(sit):
			_circles[sit] = {"members": {}, "centre": sit.centre, "end": null}
		var c: Dictionary = _circles[sit]
		for id in sit.who:
			c.members[int(id)] = true
		if (sit.centre as Vector2) != Vector2.INF:
			c.centre = sit.centre


## Those at a gathering place (the evening), at work (the end of work) or at their meal near the player, standing:
## their leaving is watched.
func _stretch(v, what: String, t: float, eye: Vector2) -> void:
	var ids: Array = []
	var centre := Vector2.ZERO
	for id: int in reg.bodies:
		var trip: Dictionary = reg.destinations.get(id, {})
		if trip.is_empty():
			continue
		if what == "evening" and not str(trip.place) in EVENING_PLACES:
			continue
		var m = reg._movers[id]
		if m.walking() or m.indoors or (m.pos as Vector2).distance_to(eye) > NEAR or not (reg.bodies[id] as Node3D).is_visible_in_tree():
			continue
		if what != "evening" and reg.owners.owner(id) != "":
			continue
		var verb := str(reg._activity.get(id, {}).get("verb", ""))
		if what == "work" and verb in ["", "at_home", "eating", "loitering", "idle", "chatting", "praying", "visiting"]:
			continue
		ids.append(id)
		centre += m.pos
	if ids.size() >= 2:
		_open(v, "%s:stretch" % what, centre / ids.size(), ids, t, -1, WATCH[what])


func _open(v, kind: String, centre: Vector2, ids: Array, t: float, subject: int, watch: float, ring := -1.0) -> Variant:
	var members := {}
	var dists: Array = []
	for id in ids:
		var body: Node3D = reg.bodies.get(int(id))
		if body == null or not body.is_visible_in_tree():
			continue
		var at := _pos(int(id))
		dists.append(at.distance_to(centre))
		var house := -1
		if v != null and int(id) >= 0 and int(id) < v.people.size():
			house = int(v.people[int(id)].household)
		members[int(id)] = {"from": at, "clip": str(body.get("_current")), "moved": -1.0, "left": -1.0, "own": {},
			"stirred": -1.0, "house": house, "at_left": at, "rest": 0.0, "set_off": -1.0, "facing0": _facing(body), "last": at,
			"vel": Vector2.ZERO,
			"to_subject": at.distance_to(_pos(subject)) if subject >= 0 and reg.bodies.has(subject) else INF}
	if members.size() < 2:
		return null
	if ring < 0.0:
		dists.sort()
		ring = float(dists[mini(dists.size() - 1, int(RING_SHARE * dists.size()))])
	var e := {"kind": kind, "at": t, "centre": centre, "ring": ring, "subject": subject, "members": members, "watch": watch}
	if subject >= 0 and v != null and subject < v.people.size():
		var kin := 0
		for id: int in members:
			if VillageSession.Runtime.Village.is_kin(v, id, subject):
				kin += 1
		e.kin_present = kin
		e.kin_reached = false
	ends_open.append(e)
	return e


func _watch(v, e: Dictionary, t: float) -> void:
	var since := t - float(e.at)
	var s := int(e.subject)
	var subject_at := _pos(s) if s >= 0 and reg.bodies.has(s) else Vector2.INF
	for id: int in e.members:
		var mm: Dictionary = e.members[id]
		if float(mm.left) >= 0.0:
			continue
		var body: Node3D = reg.bodies.get(id)
		if body == null or not body.is_visible_in_tree():
			mm.left = since
			mm.at_left = mm.from
			mm.set_off = mm.rest
			if float(mm.moved) < 0.0:
				mm.moved = since
			if float(mm.stirred) < 0.0:
				mm.stirred = since
			continue
		var p := _pos(id)
		var clip := str(body.get("_current"))
		var dt := maxf(t - float(e.get("t_last", e.at)), 0.0001)
		var raw_vel := (p - (mm.last as Vector2)) / dt
		mm.vel = (mm.vel as Vector2).lerp(raw_vel, clampf(dt / VEL_S, 0.0, 1.0))
		mm.last = p
		var vel: Vector2 = mm.vel
		var facing := _facing(body)
		var stepped := p.distance_to(mm.from) > MOVED_M or clip != str(mm.clip)
		if str(e.kind).begins_with("circle") and reg.owners.owner(id) == "society":
			stepped = false                                   # still in the circle, talking: its gestures are the talk,
			                                                  # not a move on its end (plan 3.0; 2 Oct, step 3)
		if float(mm.moved) < 0.0 and stepped:
			mm.moved = since                                  # the first step or change of clip (the spread's measure)
		if float(mm.stirred) < 0.0 and (stepped or facing.dot(mm.facing0) < TURNED):
			mm.stirred = since                                # ... or a turn: the first stir (the freeze's measure)
		if since <= TOWARD_S:
			var pose = body.call("pose") if body.has_method("pose") else null
			for o: String in own_acts({"since": since, "clip": clip, "clip0": mm.clip, "owner": reg.owners.owner(id),
					"nod": pose != null and float(pose.get("_nod_t")) > 0.0, "wave": pose != null and float(pose.get("_wave_t")) > 0.0,
					"line": reg.get("speech") != null and reg.speech.saying(body), "pos": p, "vel": vel, "forward": facing,
					"subject": subject_at, "d0": mm.to_subject}):
				(mm.own as Dictionary)[o] = true
		if int(e.get("kin_present", 0)) > 0 and not e.kin_reached and since <= KIN_S and subject_at != Vector2.INF \
				and VillageSession.Runtime.Village.is_kin(v, id, s) and p.distance_to(subject_at) <= KIN_M:
			e.kin_reached = true
		if vel.length() < REST_SPEED:
			mm.rest = since                                   # the last moment they stood: where a leaving starts
		if p.distance_to(e.centre) > float(e.ring) + LEAVE_M:
			mm.left = since
			mm.at_left = p
			mm.set_off = mm.rest


## What a member did of their own, from what is seen this frame - never a module's report (section 3.0; the review's
## round 2, MUST 2: walking off, or home past the subject, is not a reaction). `f`:
##   since (seconds after the end), clip, clip0 (theirs at the end), owner (who holds them; "": their day), nod, wave,
##   line (bools), pos, vel, forward (unit Vector2), subject (Vector2.INF: none), d0 (metres to the subject at the end)
## -> the kinds seen: a clip's name, "@nod", "@wave", "line" (within REACT_S, while something answering the end holds
## them); "toward" (TOWARD_M nearer than at the end and standing, within NEAR_STOP_M of the subject or within
## FACE_STOP_M facing them, within TOWARD_S); "away" (within REACT_S, going away at a run, or backing off facing them)
static func own_acts(f: Dictionary) -> Array:
	var out: Array = []
	var since := float(f.since)
	if since <= REACT_S and str(f.owner) in ANSWERING:
		var clip := str(f.clip)
		if not clip in WALK_IDLE and not clip.begins_with("loop/") and clip != str(f.clip0):
			out.append(clip)
		if f.nod:
			out.append("@nod")
		if f.wave:
			out.append("@wave")
		if f.line:
			out.append("line")
	var s: Vector2 = f.subject
	if s == Vector2.INF:
		return out
	var p: Vector2 = f.pos
	var vel: Vector2 = f.vel
	var d := p.distance_to(s)
	var facing := d > 0.01 and (f.forward as Vector2).dot((s - p) / d) >= FACING
	if since <= TOWARD_S and float(f.d0) - d >= TOWARD_M and vel.length() < REST_SPEED \
			and (d <= NEAR_STOP_M or (d <= FACE_STOP_M and facing)):
		out.append("toward")
	if since <= REACT_S and vel.dot(p - s) > 0.0 and (vel.length() >= AWAY_SPEED or (vel.length() >= REST_SPEED and facing)):
		out.append("away")
	return out


## Where a body faces, on the ground (the mover and the stage both turn a body by its rotation.y: ahead is (sin, cos)).
static func _facing(body: Node3D) -> Vector2:
	var y := body.global_rotation.y
	return Vector2(sin(y), cos(y))


func _pos(id: int) -> Vector2:
	var body: Node3D = reg.bodies.get(id)
	return Vector2(body.global_position.x, body.global_position.z) if body != null else Vector2.INF


static func _q(xs: Array, q: float) -> float:
	if xs.is_empty():
		return -1.0
	var s := xs.duplicate()
	s.sort()
	return float(s[clampi(int(q * (s.size() - 1) + 0.5), 0, s.size() - 1)])


static func _percentiles(xs: PackedInt32Array) -> Dictionary:
	if xs.is_empty():
		return {}
	var s := Array(xs)
	s.sort()
	var at := func(q: float) -> float: return snappedf(float(s[mini(s.size() - 1, int(q * s.size()))]) / 1000.0, 0.01)
	return {"p50": at.call(0.5), "p90": at.call(0.9), "p99": at.call(0.99), "max": snappedf(float(s[-1]) / 1000.0, 0.01),
		"frames": s.size()}


## An end rebuilt from a row's `raw` (a fixture recorded by a probe): what end_row needs, nothing more.
static func end_from_raw(kind: String, raw: Array, watch: float, extra := {}) -> Dictionary:
	var members := {}
	for i in raw.size():
		var r: Array = raw[i]
		var own := {}
		if r.size() > 7:
			for o: String in r[7]:
				own[o] = true
		members[i] = {"left": float(r[0]), "house": int(r[1]), "at_left": Vector2(float(r[2]), float(r[3])),
			"moved": float(r[4]), "set_off": float(r[5]), "stirred": float(r[6]) if r.size() > 6 else float(r[4]), "own": own}
	var e := {"kind": kind, "members": members, "watch": watch}
	e.merge(extra)
	return e
