extends Node
## The motion watcher: what an eye notices about how people move and speak, measured live, every frame (Pass 3, the
## plan's section 6 and L10). A sensor any run can carry - the motion probe, the web probe, a play session - in the
## spirit of L015 (a run needs a nervous system). It only reads: nothing it watches is moved or changed.
##
##   var watch := MotionWatch.new()
##   watch.registry = live.registry          # residents.gd: every villager body (those a scene borrowed too)
##   add_child(watch)
##   watch.begin("shrine")  ...  watch.summary()   # -> the robotic signs over the window, one Dictionary
##   provoke.struck.connect(watch.blow)       # a blow's answer is timed from the moment it lands
##   MotionWatch.misses(summary, stage)       # the targets due by that stage of the plan that the window missed
##
## It watches the drawn villager bodies within RADIUS of the player:
##
##   sign                 measured as
##   walking through      bodies closer than OVERLAP between centres: villager pairs, villager and player, villager and
##                        Enea's people and creatures (new contacts per minute, and seconds in contact per minute)
##   skating              share of moving time with the clip's ground speed (VillagerBody.gait) more than SKATE off
##                        the speed actually moved
##   one speed for all    each walker's cruise (median speed while animated as walking): the spread across people;
##                        and the share of walking at a pace no one walks (a spread of accidents is not character)
##   snapping             speed changing faster than SNAP_ACCEL, facing turning faster than SNAP_TURN (over WINDOW)
##   leaving in step      setting off (moving after standing DEPART_STILL, or out of a door), grouped by trip start:
##                        the time from first to last of three or more within SEEN_TOGETHER of each other (in_step)
##   heaps                talking groups of 3 or more: members HEAP_NEAR-HEAP_FAR from the centre, facing it
##   heads                talkers whose heads point at the group's speaker (with no speaker, at another member)
##   onlookers            onlookers of a blow within ONLOOK_NEAR of the one struck without stepping in
##   blows                time from a blow landing to the struck one's head moving HEAD_MOVE against their own body
##                        (the blow rocks them); a body that only snaps round to face the striker is not that
##   talking over         speech bubbles on screen at once, overlapping, and the widest as a share of the screen
##   meetings             people meeting people (registry.meetings): how many a minute, how many kinds, the commonest
##                        kind's share (one interaction over and over is not life)
##   standing about       share of standing time spent doing nothing (IDLE_CLIPS, busy with nobody: registry.engaged)
##   statues              share of standing time in a spell longer than STATUE with nothing changing: the same clip, on
##                        the same spot, facing the same way (people shift, look about, change what they do)
##   awkward spots        share of standing samples where the village says the spot looks wrong (registry.awkward_at:
##                        in a wall, on a doorstep, nose to a wall, on top of someone)
##   cost                 the residents' own frame time over the window (registry.frame_usec)
const React := preload("res://scripts/studio/village/resident_react.gd")

const RADIUS := 25.0          # metres from the player
const OVERLAP := 0.45         # metres between two grown people's centres: inside each other (scaled by body size:
                              # two children touch at about 0.34)
const OTHER_OVERLAP := 0.6    # ... and between a villager and one of Enea's people or creatures (bigger bodies)
const SKATE := 0.2            # the clip's speed this share off the real speed: the feet slide
const WINDOW := 0.1           # seconds: speeds and turn rates are measured over this (a frame is too noisy)
const MOVING := 0.2           # m/s
const STILL := 0.1            # m/s
const SNAP_ACCEL := 4.0       # m/s2 of speed change
const SNAP_TURN := 8.0        # rad/s of facing
const WALK_CLIP := "Walk"
const CRUISE_MIN := 0.3       # m/s: slower than this is not walking
const CRAWL_HOLD := 0.3       # seconds in the crawl band (0.3-0.6 m/s) before it counts: a start or a stop passes
                              # through it in a step, which nobody sees; inching along for longer is what looks wrong
const CRUISE_SECONDS := 2.0   # of walking before a walker's cruise counts
const DEPART_STILL := 1.0     # seconds of standing before moving counts as setting off
const SETTING_OFF := 120      # game minutes: a trip begun longer ago is under way; its steps are not departures
const SEEN_TOGETHER := 15.0   # metres: departures this near each other are seen together (about the game camera's view);
                              # strangers across the village who happen to share a trip's minute are not "in step"
const TELEPORT := 1.5         # metres in one frame: put there, not walked (the track starts again)
const HEAP_NEAR := 0.35
const HEAP_FAR := 0.9
const HEAP_FACE := 0.5236     # 30 degrees
const HEAD_AT := 0.3491       # 20 degrees
const HEAD_MOVE := 0.1396     # 8 degrees
const BLOW_WAIT := 1.5        # seconds: a blow not shown by then is never shown
const BLOW_QUIET := 1.0       # seconds after a blow when its knock-back is not a snap
const ONLOOK_NEAR := 1.2
const ONLOOK_GRACE := 2.0     # seconds after a blow before onlookers are judged (time to react and step back)
const ONLOOK_FOR := 30.0      # seconds after a blow its onlookers are watched
const SAMPLE_EVERY := 0.25    # seconds between the slower samples (groups, heads, onlookers, others)
const IDLE_CLIPS := ["Idle", "Idle_FoldArms"]
const STATUE := 15.0          # seconds of nothing changing before standing reads as a statue
const STATUE_MOVE := 0.3      # metres ...
const STATUE_TURN := 0.35     # ... or radians (20 degrees) of change that end a spell
const SETTLED := 1.0          # seconds stood before a spot is judged (a stop on the way is not a spot)

## The plan's section 6 targets: [summary key, test, value, due by stage, what it is]. A key at -1 had nothing to
## judge in the window and is skipped.
const TARGETS := [
	["overlap_per_min", "<=", 0.0, 1, "villagers walking through each other"],
	["skate_share", "<", 0.10, 1, "feet sliding (clip speed more than 20% off)"],
	["cruise_cv", ">=", 0.10, 1, "the spread of walking speeds across people"],
	["odd_pace_share", "<", 0.05, 1, "walking at a pace no one walks (under 0.6 or over 1.9 m/s)"],
	["snaps_per_min", "<=", 0.0, 1, "speed snapping (over 4 m/s2)"],
	["turn_snaps_per_min", "<=", 0.0, 1, "facing snapping while walking (over 8 rad/s)"],
	["stand_turn_snaps_per_min", "<=", 0.0, 1, "facing snapping while standing (over 8 rad/s)"],
	["departure_spread_min", ">=", 1.5, 1, "people leaving in step (seconds between first and last)"],
	["player_overlap_per_min", "<=", 0.0, 2, "villagers walking through the player"],
	["heap_share", ">=", 0.9, 3, "talkers standing in a circle"],
	["onlookers_close", "<=", 0.0, 3, "onlookers crowding the one struck"],
	["awkward_share", "<=", 0.02, 3, "standing in an awkward spot (a wall, a doorstep, nose to a wall, on someone)"],
	["idle_share", "<=", 0.25, 3, "standing about doing nothing"],
	["statue_share", "<=", 0.15, 3, "standing like a statue (15 s and more with nothing changing)"],
	["meetings_per_min", ">=", 1.0, 3, "people meeting people near the player"],
	["meeting_top_share", "<=", 0.5, 3, "the commonest kind of meeting's share (variety)"],
	["blow_slowest", "<", 0.1, 4, "seconds before a blow shows"],
	["head_share", ">=", 0.6, 4, "listeners' heads on the speaker"],
	["bubble_overlaps", "<=", 0.0, 5, "speech bubbles on top of each other"],
	["bubbles_at_once", "<=", 2.0, 5, "speech bubbles on screen at once"],
	["widest_bubble", "<=", 0.30, 5, "the widest bubble, as a share of the screen"],
]

var registry                  # residents.gd (bodies, borrowed, destinations, _activity, _acts)
var camera: Camera3D          # the view speech is judged from (the game's camera); else the viewport's current one
## Optional: -> Array of {"members": Array[int], "speaker": int} (talking groups). Without it, a group is the
## residents chatting at the same place (the day's activity). The formations of stage 3 will answer here instead.
var groups_source := Callable()

var label := ""
var _on := false
var _clock := 0.0
var _seconds := 0.0
var _tracks := {}             # id -> Track
var _seen := {}               # ids watched in the window
var _peak := 0
var _pairs := {}              # overlapping villager pairs this frame
var _player_pairs := {}
var _other_pairs := {}
var _others: Array[Node3D] = []
var _sample_left := 0.0
var _n := {}                  # counters (see begin)
var _departures: Array = []   # [clock, trip key, "door" or "stood", where]
var _blows: Array = []        # {id, at, head, shown}
var _bubble_pairs := {}
var _bubbles_seen := {}
var _onlookers := {}
var _onlookers_close := {}
var _cost := PackedInt32Array()
var _parts_at := {}                   # the registry's cost_parts when the window began (its parts' cost is the difference)
var _own := PackedInt32Array()      # the watcher's own time a frame (a sensor's price must be known)
var _frame := PackedFloat32Array()  # milliseconds between frames (the whole game's frame time, wall clock)
var _last_us := 0
var _detail := {}             # kind -> the first few and the latest few, named: who, doing what
var _by := {}                 # "what:state" -> seconds or count (which state of a mover the misses come from)
var _size := {}               # id -> body scale this frame (a child's body is smaller: closer is not inside)
var _life0 := 0.0             # the village's life clock when the window began (registry._life)
var _asides := {}             # id -> the mover's asides when first seen in the window
var _idle_by := {}            # what they were about (registry.doing_of) -> seconds standing doing nothing
const DETAIL_MAX := 6


class Track:
	var t := PackedFloat64Array()
	var x := PackedVector2Array()
	var yaw := PackedFloat64Array()
	var clip := PackedFloat32Array()      # the clip's ground speed at each sample
	var still := 0.0
	var walking := PackedFloat32Array()   # speeds while animated as walking
	var walking_s := 0.0
	var accel_on := false
	var crawl_on := false
	var glide_on := false
	var skate_t := 0.0
	var skate_on := false
	var crawl_t := 0.0
	var turn_on := false
	var spell_t := 0.0                    # seconds of standing with nothing changing
	var spell_clip := ""
	var spell_at := Vector2.INF
	var spell_yaw := 0.0
	var statue_on := false
	var hidden := false                   # in range but not drawn (indoors): drawn again, they came out of a door
	var came_out := false
	var recent := PackedStringArray()     # the mover's last wishes (why, speed wished, speed): told with a snap

	func reset() -> void:
		t.clear()
		x.clear()
		yaw.clear()
		clip.clear()
		still = 0.0
		accel_on = false
		turn_on = false
		crawl_t = 0.0
		crawl_on = false
		spell_t = 0.0
		spell_clip = ""
		spell_at = Vector2.INF
		statue_on = false
		glide_on = false
		skate_t = 0.0
		skate_on = false

	func push(time: float, at: Vector2, facing: float, clip_speed := 0.0) -> void:
		t.append(time)
		x.append(at)
		yaw.append(facing)
		clip.append(clip_speed)
		while t.size() > 2 and t[1] < time - 3.0 * WINDOW:
			t.remove_at(0)
			x.remove_at(0)
			yaw.remove_at(0)
			clip.remove_at(0)

	## The clip's ground speed over the last `span` seconds to `time` (the same window the body's speed is measured
	## over: a clip's speed now against the body's mean over the window would read every brisk start as a skate).
	func clip_mean(time: float, span: float) -> float:
		var sum := 0.0
		var n := 0
		for k in range(t.size() - 1, -1, -1):
			if t[k] <= time - span:
				break
			sum += clip[k]
			n += 1
		return sum / n if n > 0 else 0.0

	func covers(time: float) -> bool:
		return not t.is_empty() and t[0] <= time

	func _index(time: float) -> int:
		var i := t.size() - 1
		while i > 0 and t[i - 1] > time:
			i -= 1
		return i         # t[i - 1] <= time < t[i] (or the first sample)

	func at(time: float) -> Vector2:
		var i := _index(time)
		if i == 0:
			return x[0]
		var span := t[i] - t[i - 1]
		return x[i - 1].lerp(x[i], (time - t[i - 1]) / span if span > 0.0 else 1.0)

	func facing_at(time: float) -> float:
		var i := _index(time)
		if i == 0:
			return yaw[0]
		var span := t[i] - t[i - 1]
		return lerp_angle(yaw[i - 1], yaw[i], (time - t[i - 1]) / span if span > 0.0 else 1.0)


func _ready() -> void:
	process_priority = 1000       # after everything that moves a body this frame


## Starts a new window: everything counted so far is dropped.
func begin(window_label: String) -> void:
	label = window_label
	_on = true
	_seconds = 0.0
	_tracks.clear()
	_seen.clear()
	_peak = 0
	_pairs.clear()
	_player_pairs.clear()
	_other_pairs.clear()
	_departures.clear()
	_blows.clear()
	_bubble_pairs.clear()
	_bubbles_seen.clear()
	_onlookers.clear()
	_onlookers_close.clear()
	_cost.clear()
	_parts_at = (registry.get("cost_parts") as Dictionary).duplicate(true) if registry != null and registry.get("cost_parts") != null else {}
	for part: String in _parts_at:
		(registry.cost_parts[part] as Array)[2] = 0   # (the most in a frame counts from the window's start, not the game's)
	_own.clear()
	_frame.clear()
	_last_us = 0
	_detail = {}
	_by = {}
	_idle_by = {}
	_asides = {}
	_sample_left = 0.0
	_life0 = float(registry.get("_life")) if registry != null and registry.get("_life") != null else 0.0
	_n = {"stand_s": 0.0, "idle_s": 0.0, "statue_s": 0.0, "awk": 0, "awk_n": 0, "overlap": 0, "overlap_s": 0.0, "player": 0, "player_s": 0.0, "other": 0, "other_s": 0.0,
		"moving_s": 0.0, "walk_s": 0.0, "skate_s": 0.0, "crawl_s": 0.0, "crawl_raw_s": 0.0, "glide_s": 0.0, "snaps": 0, "turns": 0, "stand_turns": 0,
		"heap": 0, "heap_ok": 0, "heap_d": 0.0, "head": 0, "head_ok": 0, "head_spk": 0, "head_spk_ok": 0,
		"bubble_overlaps": 0, "bubble_overlap_s": 0.0, "bubbles_at_once": 0, "widest": 0.0, "groups": {}}


func stop() -> void:
	_on = false


## A blow from the player landed on `id` now (provoke.gd struck).
func blow(id: int) -> void:
	var body = registry.bodies.get(id) if registry != null else null
	if body == null or not body.has_method("head_forward"):
		return
	_blows.append({"id": id, "at": _clock, "head": _head_in_body(body), "yaw": body.global_rotation.y, "shown": -1.0,
		"turned": -1.0, "done": false})


func _process(delta: float) -> void:
	if not _on or registry == null:
		return
	var t0 := Time.get_ticks_usec()
	if _last_us > 0:
		_frame.append(float(t0 - _last_us) / 1000.0)
	_last_us = t0
	var crowd = registry.get("_crowd")
	if crowd != null and crowd.paused:
		for id: int in _tracks:
			(_tracks[id] as Track).reset()      # time stands still (a talk screen): nothing moves, nothing is judged
		return
	delta = minf(delta, 0.1)      # the time bodies live in (crowd.gd steps no more than this): a stalled frame stalls the
	                              # whole picture, a frame-time matter measured by cost, not a snap in anyone's walk
	_clock += delta
	_seconds += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var centre := Vector2(player.global_position.x, player.global_position.z) if player != null else Vector2.ZERO
	var drawn: Array[int] = []
	var pos := {}
	for id: int in registry.bodies:
		var body: Node3D = registry.bodies[id]
		if not is_instance_valid(body):
			continue
		var p2 := Vector2(body.global_position.x, body.global_position.z)
		var tr: Track = _tracks.get(id)
		if tr == null:
			tr = Track.new()
			_tracks[id] = tr
		if p2.distance_to(centre) > RADIUS:
			tr.reset()
			tr.hidden = false
			continue
		if not body.is_visible_in_tree():
			tr.reset()
			tr.hidden = true
			continue
		if tr.hidden:
			tr.hidden = false
			tr.came_out = true
		_seen[id] = true
		drawn.append(id)
		pos[id] = p2
		_size[id] = body.scale.x
		_track(id, body, tr, p2, delta)
		if not _asides.has(id) and registry.get("_movers") != null and (registry._movers as Dictionary).has(id):
			_asides[id] = int(registry._movers[id].asides)
	_peak = maxi(_peak, drawn.size())
	_overlaps(drawn, pos, centre, delta)
	_speech(delta)
	_check_blows()
	_sample_left -= delta
	if _sample_left <= 0.0:
		_sample_left += SAMPLE_EVERY
		_find_others()
		_sample_groups(drawn, pos)
		_sample_onlookers(pos)
		_sample_spots(drawn, pos)
	var cost: Array = registry.get("frame_usec")
	if cost != null and not cost.is_empty():
		_cost.append(int(cost[-1]))
	_own.append(Time.get_ticks_usec() - t0)


func _track(id: int, body: Node3D, tr: Track, p2: Vector2, delta: float) -> void:
	if not tr.x.is_empty() and p2.distance_to(tr.x[-1]) > TELEPORT:
		tr.reset()
	var gait: Dictionary = body.gait() if body.has_method("gait") else {}
	tr.push(_clock, p2, body.global_rotation.y, float(gait.get("speed", 0.0)))
	var movers = registry.get("_movers")
	if movers != null and (movers as Dictionary).has(id):
		var mv = movers[id]
		var crowd = registry.get("_crowd")
		var wall: float = crowd.Steer._wall(mv.pos, crowd.blocks).z if crowd != null else INF
		var way: PackedVector2Array = mv.path
		tr.recent.append("%s %.2f/%.2f w%.2f a%.1f at(%.2f,%.2f) to(%s) %s" % [mv.why, mv.wished, (mv.vel as Vector2).length(),
			minf(wall, 9.0), (mv.avoid as Vector2).length(), mv.pos.x, mv.pos.y,
			",".join(Array(way).slice(0, 3).map(func(q: Vector2) -> String: return "%.1f %.1f" % [q.x, q.y])),
			"in" if mv.enters else ""])
		if tr.recent.size() > 9:
			tr.recent.remove_at(0)
	if not tr.covers(_clock - 2.0 * WINDOW):
		return               # too new to judge
	var back := tr.at(_clock - WINDOW)
	var speed := (p2 - back).length() / WINDOW
	var before := (back - tr.at(_clock - 2.0 * WINDOW)).length() / WINDOW
	var clip_speed := tr.clip_mean(_clock, WINDOW)
	if speed > MOVING or clip_speed > 0.0:
		_n.moving_s += delta
		if absf(clip_speed - speed) > SKATE * maxf(speed, 0.25):
			_n.skate_s += delta
			_count("skate", id, delta)
			tr.skate_t += delta
			if tr.skate_t >= 0.3 and not tr.skate_on:
				tr.skate_on = true
				_note("skate", "%d %s %.2f m/s, clip %s at %.2f m/s, %s, at %.1f s; %s" % [id, _state_of(id), speed,
					str(gait.get("clip", "")), clip_speed, _context(id, p2), _seconds, " | ".join(tr.recent.slice(-4))])
		else:
			tr.skate_t = 0.0
			tr.skate_on = false
	if str(gait.get("clip", "")) == WALK_CLIP and speed > CRUISE_MIN:
		tr.walking.append(speed)
		tr.walking_s += delta
		_n.walk_s += delta
		if speed < 0.6:
			_n.crawl_raw_s += delta
			tr.crawl_t += delta
			if tr.crawl_t >= CRAWL_HOLD:          # inching along, not passing through on the way to a stop or a walk
				var add := delta
				if not tr.crawl_on:
					tr.crawl_on = true
					add = tr.crawl_t
					_note("crawl", "%d %s %.2f m/s, %s, at %.1f s; %s" % [id, _state_of(id), speed, _context(id, p2), _seconds,
						" | ".join(tr.recent.slice(-4))])
				_n.crawl_s += add
				_count("crawl", id, add)
		elif speed > 1.9:
			_n.glide_s += delta
			_count("glide", id, delta)
			if not tr.glide_on:
				tr.glide_on = true
				_note("glide", "%d %s %.2f m/s, %s, at %.1f s; %s" % [id, _state_of(id), speed, _context(id, p2), _seconds, _inner(id)])
	if str(gait.get("clip", "")) != WALK_CLIP or speed <= CRUISE_MIN or speed >= 0.6:
		tr.crawl_t = 0.0
		tr.crawl_on = false
	if str(gait.get("clip", "")) != WALK_CLIP or speed <= 1.9:
		tr.glide_on = false
	var quiet := _blown(id)
	var accel := absf(speed - before) / WINDOW
	if accel > SNAP_ACCEL and not quiet:
		if not tr.accel_on:
			tr.accel_on = true
			_n.snaps += 1
			_count("snap", id, 1.0)
			_note("snap", "%d %s %.2f->%.2f m/s at %.1f s, (%.1f, %.1f); %s, frame %.0f ms; %s" % [id, _state_of(id), before,
				speed, _seconds, p2.x, p2.y, _inner(id), delta * 1000.0, " | ".join(tr.recent)])
	elif accel < SNAP_ACCEL * 0.5:
		tr.accel_on = false
	var turn := absf(angle_difference(tr.facing_at(_clock - WINDOW), body.global_rotation.y)) / WINDOW
	if turn > SNAP_TURN and not quiet:
		if not tr.turn_on:
			tr.turn_on = true
			if speed > MOVING:
				_n.turns += 1
			else:
				_n.stand_turns += 1
			_note("turn", "%d %s %.1f rad/s at %.2f m/s, %.1f s; %s; %s" % [id, _state_of(id), turn, speed, _seconds, _inner(id),
				registry.doing_of(id) if registry.has_method("doing_of") else ""])
	elif turn < SNAP_TURN * 0.5:
		tr.turn_on = false
	# setting off on the day's trip: after standing a while, or straight out of a door (a step within a stay hours into
	# its trip is not a departure)
	if speed < STILL:
		tr.still += delta
	elif speed > CRUISE_MIN:
		var trip: Dictionary = registry.destinations.get(id, {})
		var now_minute: int = int(registry.get("_minute")) if registry.get("_minute") != null else -1
		if (tr.still >= DEPART_STILL or tr.came_out) and setting_off(int(trip.get("start", -1)), now_minute):
			_departures.append([_clock, _trip_key(id), "door" if tr.came_out else "stood", p2])
			_note("depart", "%d %s, trip %s, at %.1f s, %s after %.1f s still, (%.1f, %.1f); %s; %s" % [id, _state_of(id),
				_trip_key(id), _seconds, "out of a door" if tr.came_out else "stood", tr.still, p2.x, p2.y, _inner(id),
				" | ".join(tr.recent.slice(-3))])
		tr.still = 0.0
	tr.came_out = false
	_standing(id, tr, p2, body.global_rotation.y, speed, gait, delta)


## Standing: is it doing nothing, and has nothing changed for a long while?
func _standing(id: int, tr: Track, p2: Vector2, yaw: float, speed: float, gait: Dictionary, delta: float) -> void:
	var clip := str(gait.get("clip", ""))
	if speed >= STILL or float(gait.get("speed", 0.0)) > 0.0 or tr.still < SETTLED:
		tr.spell_t = 0.0
		tr.spell_clip = ""
		tr.statue_on = false
		return
	_n.stand_s += delta
	var busy: String = registry.engaged(id) if registry.has_method("engaged") else ""
	if busy == "" and clip in IDLE_CLIPS:
		_n.idle_s += delta
		_count("idle", id, delta)
		var about: String = registry.doing_of(id) if registry.has_method("doing_of") else "?"
		_idle_by[about] = float(_idle_by.get(about, 0.0)) + delta
	if clip != tr.spell_clip or tr.spell_at == Vector2.INF or p2.distance_to(tr.spell_at) > STATUE_MOVE \
			or absf(angle_difference(tr.spell_yaw, yaw)) > STATUE_TURN:
		tr.spell_t = 0.0
		tr.spell_clip = clip
		tr.spell_at = p2
		tr.spell_yaw = yaw
		tr.statue_on = false
	tr.spell_t += delta
	if tr.spell_t > STATUE:
		var add := delta
		if not tr.statue_on:
			tr.statue_on = true
			add = tr.spell_t - STATUE
			_note("statue", "%d %s %s, %s, %s, at %.1f s" % [id, clip, busy, _doing(id), _context(id, p2), _seconds])
		_n.statue_s += add
		_count("statue", id, add)


## What the day has them doing (residents.gd _activity), for the notes.
func _doing(id: int) -> String:
	var acts = registry.get("_activity")
	if acts == null or not (acts as Dictionary).has(id):
		return "-"
	var a: Dictionary = acts[id]
	return "%s at %s" % [a.get("verb", ""), a.get("place", "")]


## Every SAMPLE_EVERY: anyone settled on a spot that looks wrong.
func _sample_spots(drawn: Array[int], pos: Dictionary) -> void:
	if not registry.has_method("awkward_at"):
		return
	for id: int in drawn:
		var tr: Track = _tracks[id]
		if tr.still < SETTLED:
			continue
		var why: String = registry.awkward_at(id)
		if why == "-":
			continue                    # (not standing on a spot of their own: walking, or someone else moves them)
		_n.awk_n += 1
		if why != "":
			_n.awk += 1
			_count("awkward_" + why, id, 1.0)
			_note("awkward", "%d %s, %s, %s, %s, at %.1f s; %s" % [id, why, _doing(id), _state_of(id), _context(id, pos[id]), _seconds,
				registry.doing_of(id) if registry.has_method("doing_of") else ""])


func _note(kind: String, text: String) -> void:
	var first: Array = _detail.get(kind, [])
	_detail[kind] = first
	if first.size() < DETAIL_MAX:
		first.append(text)
		return
	var late: Array = _detail.get(kind + "_late", [])
	_detail[kind + "_late"] = late
	late.append(text)
	if late.size() > DETAIL_MAX:
		late.pop_front()


func _count(what: String, id: int, amount: float) -> void:
	var key := what + ":" + _state_of(id)
	_by[key] = float(_by.get(key, 0.0)) + amount


## The mover's own view at that moment: its velocity, the most it may change it by, starting or stopping on purpose.
func _inner(id: int) -> String:
	var movers = registry.get("_movers")
	if movers == null or not (movers as Dictionary).has(id):
		return "-"
	var mv = movers[id]
	return "vel %.2f, accel %.1f, relax %.2f, brisk %s, under way %.1f s, style %s, exact %s" % [(mv.vel as Vector2).length(),
		mv.accel_now(), mv.relax_now(), mv._brisk, mv._under_way, mv.style, mv.exact]


## Where a body is going and who is round it: metres of way left, the people within 1.2 m, where it is.
func _context(id: int, p2: Vector2) -> String:
	var movers = registry.get("_movers")
	var left := -1.0
	if movers != null and (movers as Dictionary).has(id):
		left = movers[id]._left()
	var close := 0
	for other: int in registry.bodies:
		if other != id and (registry.bodies[other] as Node3D).is_visible_in_tree():
			var o: Vector3 = (registry.bodies[other] as Node3D).global_position
			if Vector2(o.x, o.z).distance_squared_to(p2) < 1.44:
				close += 1
	var crowd = registry.get("_crowd")
	var wall: String = ", IN A WALL" if crowd != null and crowd.in_wall(p2) else ""
	return "%.1f m to go, %d within 1.2 m, (%.1f, %.1f)%s" % [left, close, p2.x, p2.y, wall]


## What a body's mover is doing (people/mover.gd, when the registry has movers): walk, wait (to set off), stand, or
## off (a scene or a reaction moves it).
func _state_of(id: int) -> String:
	var movers = registry.get("_movers")
	if movers == null or not (movers as Dictionary).has(id):
		return "?"
	var mv = movers[id]
	if not mv.active:
		return "off"
	var shove: String = ("/shoved by " + str(mv.get("shoved_by"))) if float(mv.get("shoved")) < 0.25 else ""
	if mv.walking():
		return ("wait" if mv.wait > 0.0 else "walk") + shove
	return "stand" + shove


## Setting off on the day's trip, not a step within a stay: the trip began at most SETTING_OFF game minutes ago (people
## leave within the trip's spare time, residents.gd LEAVE_SPREAD). A child's dash or a step at work at 18:00 on a trip
## that began at 11:00 is life going on, not a departure.
static func setting_off(trip_start: int, now: int) -> bool:
	return trip_start >= 0 and now >= 0 and now - trip_start <= SETTING_OFF


## Leaving in step, as an eye sees it: of departures [clock, trip, kind, where] on one trip, the shortest time from the
## first to the last of any three or more within `together` metres of one of them; INF if no three were that near.
static func in_step(departures: Array, together: float) -> float:
	var best := INF
	for d: Array in departures:
		var times := []
		for e: Array in departures:
			if (e[3] as Vector2).distance_to(d[3] as Vector2) <= together:
				times.append(float(e[0]))
		if times.size() >= 3:
			best = minf(best, float(times.max()) - float(times.min()))
	return best


## The trip a departure belongs to: the minute the day's plan sent them (residents.gd destinations); "" for a body a
## scene has borrowed (its timing is the scene's).
func _trip_key(id: int) -> String:
	if registry.borrowed.has(id):
		return ""
	var trip: Dictionary = registry.destinations.get(id, {})
	return str(trip.get("start", "")) if not trip.is_empty() else ""


func _blown(id: int) -> bool:
	for b: Dictionary in _blows:
		if int(b.id) == id and _clock - float(b.at) < BLOW_QUIET:
			return true
	return false


func _overlaps(drawn: Array[int], pos: Dictionary, player_at: Vector2, delta: float) -> void:
	var now := {}
	for i in drawn.size():
		var a: Vector2 = pos[drawn[i]]
		for j in range(i + 1, drawn.size()):
			var near := OVERLAP * 0.5 * (float(_size[drawn[i]]) + float(_size[drawn[j]]))
			if a.distance_squared_to(pos[drawn[j]]) < near * near:
				var key := mini(drawn[i], drawn[j]) * 100000 + maxi(drawn[i], drawn[j])
				now[key] = true
				_n.overlap_s += delta
				if not _pairs.has(key):
					_n.overlap += 1
					_count("overlap", drawn[i], 0.5)
					_count("overlap", drawn[j], 0.5)
					_note("overlap", "%d %s + %d %s, %.2f m, at %.1f s" % [drawn[i], _state_of(drawn[i]), drawn[j], _state_of(drawn[j]),
						a.distance_to(pos[drawn[j]]), _seconds])
	_pairs = now
	now = {}
	for id in drawn:
		if (pos[id] as Vector2).distance_squared_to(player_at) < OVERLAP * OVERLAP:
			now[id] = true
			_n.player_s += delta
			if not _player_pairs.has(id):
				_n.player += 1
	_player_pairs = now
	now = {}
	for k in _others.size():
		var other := _others[k]
		if not is_instance_valid(other):
			continue
		var o := Vector2(other.global_position.x, other.global_position.z)
		for id in drawn:
			if (pos[id] as Vector2).distance_squared_to(o) < OTHER_OVERLAP * OTHER_OVERLAP:
				var key := k * 100000 + id
				now[key] = true
				_n.other_s += delta
				if not _other_pairs.has(key):
					_n.other += 1
	_other_pairs = now


## Enea's people and creatures near the player: his characters (world/npc.gd), the wild things, the ox cart.
func _find_others() -> void:
	_others.clear()
	for group: String in ["enemy", "ox_cart", "interactable"]:
		for n: Node in get_tree().get_nodes_in_group(group):
			if not n is Node3D or n.get_script() == null:
				continue
			var path: String = (n.get_script() as Script).resource_path
			if group == "interactable" and not path.ends_with("world/npc.gd"):
				continue
			if path.ends_with("fight_target.gd"):
				continue          # the studio's marker on a villager squared up to, not a body
			if not _others.has(n):
				_others.append(n)


func _speech(delta: float) -> void:
	var cam := camera if is_instance_valid(camera) else get_viewport().get_camera_3d()
	if cam == null:
		return
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var rects: Array[Rect2] = []
	var keys: Array[int] = []
	for id: int in registry.bodies:
		var body: Node3D = registry.bodies[id]
		if not is_instance_valid(body) or not body.is_visible_in_tree():
			continue
		var bubble := body.get_node_or_null(React.NAME) as Label3D
		if bubble == null or bubble.modulate.a < 0.05:
			continue
		var r := _screen_rect(cam, bubble)
		if r.size == Vector2.ZERO or not r.intersects(screen):
			continue
		rects.append(r)
		keys.append(bubble.get_instance_id())
		_bubbles_seen[bubble.get_instance_id()] = true
		_n.widest = maxf(_n.widest, r.size.x / screen.size.x)
	_n.bubbles_at_once = maxi(_n.bubbles_at_once, rects.size())
	var now := {}
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersection(rects[j]).get_area() > 4.0:
				var key := "%d:%d" % [mini(keys[i], keys[j]), maxi(keys[i], keys[j])]
				now[key] = true
				if not _bubble_pairs.has(key):
					_n.bubble_overlaps += 1
	if not now.is_empty():
		_n.bubble_overlap_s += delta
	_bubble_pairs = now


## A billboarded label's rectangle on screen (it faces the camera: its corners lie along the camera's right and up).
static func _screen_rect(cam: Camera3D, label3d: Label3D) -> Rect2:
	if cam.is_position_behind(label3d.global_position):
		return Rect2()
	var box := label3d.get_aabb()
	var s := label3d.global_basis.get_scale()
	var right := cam.global_basis.x.normalized()
	var up := cam.global_basis.y.normalized()
	var mid := label3d.global_position + right * box.get_center().x * s.x + up * box.get_center().y * s.y
	var hw := right * box.size.x * 0.5 * s.x
	var hh := up * box.size.y * 0.5 * s.y
	var out := Rect2(cam.unproject_position(mid), Vector2.ZERO)
	for corner: Vector3 in [mid - hw - hh, mid + hw - hh, mid - hw + hh, mid + hw + hh]:
		out = out.expand(cam.unproject_position(corner))
	return out


func _check_blows() -> void:
	for b: Dictionary in _blows:
		if b.done:
			continue
		var body = registry.bodies.get(int(b.id))
		if body == null or not is_instance_valid(body):
			b.done = true
			continue
		if float(b.turned) < 0.0 and absf(angle_difference(float(b.yaw), body.global_rotation.y)) >= HEAD_MOVE:
			b.turned = _clock - float(b.at)          # the whole body turned (to face the striker)
		if _turned_by(b.head, _head_in_body(body)) >= HEAD_MOVE:
			b.shown = _clock - float(b.at)           # the head moved on the body: rocked, a flinch, a hit clip
			b.done = true
		elif _clock - float(b.at) > BLOW_WAIT:
			b.done = true


## How the head sits in the body's own frame (the body's turning taken out): its whole turn where the body can tell
## (a roll is a flinch too), else where it points.
static func _head_in_body(body: Node3D) -> Variant:
	if body.has_method("head_basis"):
		return Basis(Vector3.UP, -body.global_rotation.y) * body.head_basis()
	return Basis(Vector3.UP, -body.global_rotation.y) * body.head_forward()


## Radians between two of _head_in_body's readings.
static func _turned_by(a: Variant, b: Variant) -> float:
	if a is Basis and b is Basis:
		return ((a as Basis).inverse() * (b as Basis)).get_rotation_quaternion().get_angle()
	return (a as Vector3).angle_to(b as Vector3)


## Talking groups: from groups_source, or the residents chatting at the same place, standing, drawn, held by nothing.
func _talking_groups(drawn: Array[int]) -> Array:
	if groups_source.is_valid():
		return groups_source.call()
	var activity: Dictionary = registry.get("_activity")
	var acts: Dictionary = registry.get("_acts")
	var by_place := {}
	for id in drawn:
		var a: Dictionary = activity.get(id, {})
		if str(a.get("verb", "")) != "chatting" or registry.borrowed.has(id) or acts.has(id):
			continue
		var tr: Track = _tracks.get(id)
		if tr == null or tr.still < 0.5:
			continue
		by_place.get_or_add(str(a.get("place", "")), []).append(id)
	var out := []
	for place: String in by_place:
		var members: Array = by_place[place]
		var speaker := -1
		for id: int in members:
			if React.has_bubble(registry.bodies[id]):
				speaker = id
				break
		out.append({"members": members, "speaker": speaker})
	return out


func _sample_groups(drawn: Array[int], pos: Dictionary) -> void:
	for g: Dictionary in _talking_groups(drawn):
		var members: Array = g.members
		if members.size() < 2 or members.any(func(id: int) -> bool: return not pos.has(id)):
			continue                        # (a conversation not all in view)
		_n.groups[members.size()] = int(_n.groups.get(members.size(), 0)) + 1
		var centre := Vector2.ZERO
		for id: int in members:
			centre += pos[id]
		centre /= float(members.size())
		var speaker := int(g.get("speaker", -1))
		for id: int in members:
			var body: Node3D = registry.bodies[id]
			var at: Vector2 = pos[id]
			if members.size() >= 3:
				var d := at.distance_to(centre)
				var facing := Vector2(sin(body.global_rotation.y), cos(body.global_rotation.y))
				var ok := d >= HEAP_NEAR and d <= HEAP_FAR and absf(facing.angle_to(centre - at)) <= HEAP_FACE
				_n.heap += 1
				_n.heap_d += d
				if ok:
					_n.heap_ok += 1
				else:
					var tr: Track = _tracks.get(id)
					var movers = registry.get("_movers")
					_note("heap", "%d of %d %s %s: %.2f m from the middle, facing %.0f deg off it, %s, at %.1f s; %s; planned middle %s, holds %s; %s" % [id,
						members.size(), str(members), str(g.get("name", "")), d, rad_to_deg(absf(facing.angle_to(centre - at))),
						_state_of(id), _seconds, _doing(id), str(g.get("centre", "")),
						str(movers[id].hold_at) if movers != null and movers.has(id) else "", " | ".join(tr.recent.slice(-2)) if tr != null else ""])
			if id == speaker or not body.has_method("head_forward"):
				continue
			var head: Vector3 = body.head_forward()
			var look := Vector2(head.x, head.z)
			if look.length_squared() < 0.0001:
				continue
			var target := Vector2.INF
			if speaker >= 0:
				target = pos[speaker]
			else:
				for other: int in members:
					if other != id and (target == Vector2.INF or at.distance_squared_to(pos[other]) < at.distance_squared_to(target)):
						target = pos[other]
			var on := absf(look.angle_to(target - at)) <= HEAD_AT
			if speaker >= 0:
				_n.head_spk += 1
				_n.head_spk_ok += int(on)
			_n.head += 1
			_n.head_ok += int(on)


func _sample_onlookers(pos: Dictionary) -> void:
	var acts: Dictionary = registry.get("_acts")
	for b: Dictionary in _blows:
		if _clock - float(b.at) > ONLOOK_FOR or _clock - float(b.at) < ONLOOK_GRACE or not pos.has(int(b.id)):
			continue                          # (the first moments: anyone near is still where the blow found them)
		var struck: Vector2 = pos[int(b.id)]
		for id: int in acts:
			var act = acts[id]
			if id == int(b.id) or not act.onlooker or act.state == "intervene" or not pos.has(id):
				continue
			_onlookers[id] = true
			if (pos[id] as Vector2).distance_to(struck) < ONLOOK_NEAR:
				if not _onlookers_close.has(id):
					_note("onlooker", "%d (%s, %s) %.2f m from %d (%s) at %.1f s after the blow" % [id, str(act.state), _state_of(id),
						(pos[id] as Vector2).distance_to(struck), int(b.id), _state_of(int(b.id)), _clock - float(b.at)])
				_onlookers_close[id] = true


## The window so far: every sign, per minute where it is a count. -1: nothing to judge.
func summary() -> Dictionary:
	var minutes := maxf(_seconds, 0.001) / 60.0
	var cruise := PackedFloat32Array()
	for id: int in _tracks:
		var tr: Track = _tracks[id]
		if tr.walking_s >= CRUISE_SECONDS:
			var speeds := tr.walking.duplicate()
			speeds.sort()
			cruise.append(speeds[speeds.size() / 2])
	var mean := 0.0
	for s in cruise:
		mean += s
	mean = mean / cruise.size() if not cruise.is_empty() else 0.0
	var spread := 0.0
	for s in cruise:
		spread += (s - mean) * (s - mean)
	var cv := sqrt(spread / cruise.size()) / mean if cruise.size() >= 2 and mean > 0.0 else -1.0
	var by_trip := {}
	for d: Array in _departures:
		if str(d[1]) != "":
			by_trip.get_or_add(str(d[1]), []).append(d)
	var spreads := PackedFloat32Array()
	var detail := {}              # trip minute -> [how many, seconds into the window, spread, out of a door, in step]
	for key: String in by_trip:
		var times := []
		var doors := 0
		for d: Array in by_trip[key]:
			times.append(float(d[0]))
			doors += int(d[2] == "door")
		var first: float = times.min()
		var together := in_step(by_trip[key], SEEN_TOGETHER)
		detail[key] = [times.size(), snappedf(first - (_clock - _seconds), 0.1), snappedf(float(times.max()) - first, 0.01), doors,
			snappedf(together, 0.01) if together != INF else -1.0]
		if together != INF:
			spreads.append(together)
	spreads.sort()
	var latencies := []
	var slowest := -1.0
	for b: Dictionary in _blows:
		var shown := float(b.shown) if b.done else -1.0
		latencies.append({"rocked": snappedf(shown, 0.01) if shown >= 0.0 else "never",
			"turned": snappedf(float(b.turned), 0.01) if float(b.turned) >= 0.0 else "no"})
		slowest = maxf(slowest, shown if shown >= 0.0 else 99.0)
	var kinds := {}
	var met := 0
	var log = registry.get("meetings")
	if log != null:
		for m: Array in log:
			if float(m[0]) >= _life0:
				met += 1
				kinds[m[1]] = int(kinds.get(m[1], 0)) + 1
	var top := 0
	for k: String in kinds:
		top = maxi(top, int(kinds[k]))
	var cost := _cost.duplicate()
	cost.sort()
	var own := _own.duplicate()
	own.sort()
	return {
		"window": label, "seconds": snappedf(_seconds, 0.1), "people": _seen.size(), "peak": _peak,
		"overlap_per_min": snappedf(_n.overlap / minutes, 0.1), "overlap_s_per_min": snappedf(_n.overlap_s / minutes, 0.1),
		"player_overlap_per_min": snappedf(_n.player / minutes, 0.1), "player_overlap_s_per_min": snappedf(_n.player_s / minutes, 0.1),
		"other_overlap_per_min": snappedf(_n.other / minutes, 0.1),
		"moving_s": snappedf(_n.moving_s, 0.1),
		"skate_share": snappedf(_n.skate_s / _n.moving_s, 0.01) if _n.moving_s > 1.0 else -1.0,
		"crawl_share": snappedf(_n.crawl_s / _n.moving_s, 0.01) if _n.moving_s > 1.0 else -1.0,
		"crawl_raw_share": snappedf(_n.crawl_raw_s / _n.walk_s, 0.01) if _n.walk_s > 1.0 else -1.0,
		"glide_share": snappedf(_n.glide_s / _n.moving_s, 0.01) if _n.moving_s > 1.0 else -1.0,
		"odd_pace_share": snappedf((_n.crawl_s + _n.glide_s) / _n.walk_s, 0.01) if _n.walk_s > 1.0 else -1.0,
		"cruise_n": cruise.size(), "cruise_min": snappedf(Array(cruise).min(), 0.01) if not cruise.is_empty() else -1.0,
		"cruise_max": snappedf(Array(cruise).max(), 0.01) if not cruise.is_empty() else -1.0,
		"cruise_mean": snappedf(mean, 0.01), "cruise_cv": snappedf(cv, 0.01),
		"snaps_per_min": snappedf(_n.snaps / minutes, 0.1), "turn_snaps_per_min": snappedf(_n.turns / minutes, 0.1),
		"stand_turn_snaps_per_min": snappedf(_n.stand_turns / minutes, 0.1),
		"departures": _departures.size(), "departure_groups": spreads.size(), "departure_detail": detail,
		"departure_spread_min": snappedf(spreads[0], 0.01) if not spreads.is_empty() else -1.0,
		"departure_spread_median": snappedf(spreads[spreads.size() / 2], 0.01) if not spreads.is_empty() else -1.0,
		"groups_seen": _n.groups,
		"heap_samples": _n.heap, "heap_share": snappedf(float(_n.heap_ok) / _n.heap, 0.01) if _n.heap > 0 else -1.0,
		"heap_distance": snappedf(_n.heap_d / _n.heap, 0.01) if _n.heap > 0 else -1.0,
		"head_samples": _n.head, "head_share": snappedf(float(_n.head_spk_ok) / _n.head_spk, 0.01) if _n.head_spk > 0 \
			else (snappedf(float(_n.head_ok) / _n.head, 0.01) if _n.head > 0 else -1.0),
		"head_on_speaker_samples": _n.head_spk,
		"onlookers": _onlookers.size() if not _blows.is_empty() else -1,
		"onlookers_close": _onlookers_close.size() if not _blows.is_empty() else -1,
		"blows": latencies, "blow_slowest": snappedf(slowest, 0.01),
		"bubbles": _bubbles_seen.size(), "bubbles_at_once": _n.bubbles_at_once if not _bubbles_seen.is_empty() else -1,
		"bubble_overlaps": _n.bubble_overlaps if not _bubbles_seen.is_empty() else -1,
		"widest_bubble": snappedf(_n.widest, 0.01) if not _bubbles_seen.is_empty() else -1.0,
		"meetings": met, "meetings_per_min": snappedf(met / minutes, 0.1) if log != null and _seconds > 20.0 else -1.0,
		"meeting_kinds": kinds.size(), "meeting_seen": kinds,
		"meeting_top_share": snappedf(float(top) / met, 0.01) if met >= 4 else -1.0,
		"stand_s": snappedf(_n.stand_s, 0.1),
		"idle_share": snappedf(_n.idle_s / _n.stand_s, 0.01) if _n.stand_s > 5.0 else -1.0,
		"statue_share": snappedf(_n.statue_s / _n.stand_s, 0.01) if _n.stand_s > 5.0 else -1.0,
		"asides_per_min": snappedf(_stepped_aside() / minutes, 0.1),
		"awkward_samples": _n.awk_n, "idle_by": _rounded(_idle_by),
		"awkward_share": snappedf(float(_n.awk) / _n.awk_n, 0.001) if _n.awk_n >= 20 else -1.0,
		"cost_p50_ms": snappedf(cost[cost.size() / 2] / 1000.0, 0.01) if not cost.is_empty() else -1.0,
		"cost_p90_ms": snappedf(cost[cost.size() * 9 / 10] / 1000.0, 0.01) if not cost.is_empty() else -1.0,
		"cost_parts": _parts(),
		"watch_p50_ms": snappedf(own[own.size() / 2] / 1000.0, 0.01) if not own.is_empty() else -1.0,
		"frame_p50_ms": _quantile(_frame, 0.5), "frame_p90_ms": _quantile(_frame, 0.9), "frame_p99_ms": _quantile(_frame, 0.99),
		"fps": snappedf(_frame.size() / maxf(_sum(_frame) / 1000.0, 0.001), 0.1) if not _frame.is_empty() else -1.0,
		"cap": Engine.max_fps, "device": OS.get_model_name(),
		"detail": _detail,
		"by_state": _rounded(_by),
	}


## How many times people stepped out of someone's way in the window.
## The registry's frame work by part over the window: part -> [mean ms a frame, most ms in a frame in the window].
func _parts() -> Dictionary:
	var out := {}
	var now = registry.get("cost_parts") if registry != null else null
	if now == null:
		return out
	for part: String in now:
		var c: Array = now[part]
		var b: Array = _parts_at.get(part, [0, 0, 0])
		var frames: int = c[1] - b[1]
		if frames > 0:
			out[part] = [snappedf((c[0] - b[0]) / 1000.0 / frames, 0.001), snappedf(c[2] / 1000.0, 0.01)]
	return out


func _stepped_aside() -> int:
	var n := 0
	for id: int in _asides:
		if (registry._movers as Dictionary).has(id):
			n += int(registry._movers[id].asides) - int(_asides[id])
	return n


## The targets due by `stage` that a window's summary misses (empty: it meets them all, or had nothing to judge).
static func misses(s: Dictionary, stage: int) -> Array[String]:
	var out: Array[String] = []
	for t: Array in TARGETS:
		if int(t[3]) > stage or not s.has(t[0]):
			continue
		var value := float(s[t[0]])
		if value == -1.0:
			continue
		var ok := true
		match str(t[1]):
			"<=": ok = value <= float(t[2])
			"<": ok = value < float(t[2])
			">=": ok = value >= float(t[2])
		if not ok:
			out.append("%s: %s is %s, the target %s %s" % [t[4], t[0], str(s[t[0]]), t[1], str(t[2])])
	return out


static func _quantile(values: PackedFloat32Array, q: float) -> float:
	if values.is_empty():
		return -1.0
	var sorted := values.duplicate()
	sorted.sort()
	return snappedf(sorted[mini(int(q * sorted.size()), sorted.size() - 1)], 0.01)


static func _sum(values: PackedFloat32Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total


static func _rounded(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = snappedf(float(d[k]), 0.1)
	return out
