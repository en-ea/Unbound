extends Node3D
## One body per resident. Events borrow it; routines resume from its actual position.
##
## Daily life: a resident walks the day plan (Runtime.routine), and while they stand somewhere their body does
## what the plan says they are doing (resident_anims.gd: farming, chopping, chatting with someone, eating on
## the step...). At night they are indoors: hidden, costing nothing, and back at their door in the morning.
## Every resident carries a talk spot (resident_talk.gd) while the player is near; the name shows over the
## one the action button would talk to. Nothing else of the village's is drawn.
##
## What the village says a resident is doing about the player (runtime.reactions: puzzled, flee, fight_back...) is
## acted out by resident_acts.gd until it ends; then the body walks back to where its day has got to.
## Enea's own characters (protected residents: authored != "") get no body here: they keep theirs (world/npc.gd).
const Body := preload("res://scripts/studio/village/villager_body.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")
const Sites := preload("res://scripts/studio/village/sites.gd")
const Stage := preload("res://scripts/studio/village/stage.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const Talk := preload("res://scripts/studio/village/resident_talk.gd")
const Anims := preload("res://scripts/studio/village/resident_anims.gd")
const React := preload("res://scripts/studio/village/resident_react.gd")
const Acts := preload("res://scripts/studio/village/resident_acts.gd")

const TALK_NEAR := 6.0          # metres: a talk spot exists only for a resident this close to the player
const PICKS_PER_FRAME := 3      # daily-life picks (a describe each) made in one frame: a minute's worth spread over frames
const TURN := 6.0               # radians per second a standing resident turns to face what they face
const CHILD_SCALE := 0.68

var bodies := {}
var borrowed := {}
var paths := {}
var destinations := {}
var _shape := WorldShape.new()
var _minute := -1
var build_usec: Array[int] = []
var frame_usec: Array[int] = []
var ready_for_play := false
var _router: Node3D
var _player: Node3D
var _spots := {}                # id -> Talk.Spot
var _picks := {}                # id -> resident_anims.gd pick (the loop, tool, whether indoors, what to face)
var _pick_minute := {}          # id -> the minute the pick was made
var _activity := {}             # id -> view activity at that minute
var _faces := {}                # id -> the ground point a standing body looks at
var _aligned := {}              # id -> true once a standing body faces what it should (no turning left to do)
var _who := {}                  # id -> {role, age_group, day}: what does not change within a day
var _tier := {}                 # id -> the detail tier last given to the body
var _applied := {}              # id -> "loop|tool" the body is playing
var _talking := -1              # the resident the player is talking to (they stand and talk until it ends)
var _talk_open := false         # a talk screen is open (what it asked for is done the frame it closes)
var _acts := {}                 # id -> Acts.Act: acting out a reaction to the player
var _carry := {}                # id -> the offset from the day's position a body is still walking off
var _carry_from_body := {}      # id -> true: take the offset from where the body stands now
var _skip := {}                 # id -> true: never given a body here (protected: Enea's own)
var _inside := {}               # id -> true: at home they stay indoors (else out in the yard)
var _at_offset := {}            # id -> the offset they stand at about the place they last went to
var _tag: React.Tag

func _ready() -> void:
	_router = Stage.new()
	add_child(_router)
	_router._build_blocks() # same existing obstacle routes as event actors, computed only on replanning
	_player = get_tree().get_first_node_in_group("player")
	_tag = React.Tag.new()
	add_child(_tag)

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	var v = VillageSession.village
	if v == null:
		return
	# Preparation is included in measured frame work, never subtracted from the stage's cost.
	for p in v.people:
		if p.alive and p.present and not bodies.has(p.id) and not _skip.has(p.id):
			if _is_protected(v, p):
				_skip[p.id] = true          # an authored character: their own body, their own talk
				continue
			ensure(Justice.person_entry(v, p.id))
			break
	ready_for_play = true
	var now := int(v.runtime.now)
	var replan := now != _minute
	_minute = now
	if _talk_open and not Controls.locked:
		_talk_open = false
		_talking = -1            # the talk screen closed: back to their day, and what it asked for is done
		Talk.run_pending(self, _player)
	_sync_reactions(v, now)
	var picks := PICKS_PER_FRAME
	var player_at := _player.global_position if _player != null else Vector3(INF, INF, INF)
	var controls_locked := Controls.locked
	var adelta := 0.0 if controls_locked or VillageSession.background else delta   # acts freeze with the clock
	for id: int in bodies:
		var body: Body = bodies[id]
		var p = v.people[id]
		var near2 := player_at.distance_squared_to(body.position)   # the registry and any stage sit at the origin
		if borrowed.has(id):
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		if not p.alive or not p.present:
			_show(id, body, 2)
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		if replan or not destinations.has(id):
			var trip := Runtime.routine(v, id)
			if not destinations.has(id) or destinations[id].start != trip.start or destinations[id].place != trip.place:
				_plan(v, id, trip)
		var trip: Dictionary = destinations[id]
		var progress := clampf((float(now) + float(v.runtime.fraction) - float(trip.start)) / maxf(1.0, float(trip.end) - float(trip.start)), 0.0, 1.0)
		var path: Array = paths[id]
		var length := 0.0
		for j in range(1, path.size()):
			length += (path[j] as Vector2).distance_to(path[j - 1])
		var left := length * progress
		var next: Vector2 = path[-1]
		for j in range(1, path.size()):
			var segment := (path[j] as Vector2).distance_to(path[j - 1])
			if left <= segment and segment > 0.001:
				next = (path[j - 1] as Vector2).lerp(path[j], left / segment)
				break
			left -= segment
		var act: Acts.Act = _acts.get(id)
		if act != null and act.done(now):
			_end_act(id, act, next)
			act = null
		if act != null:
			act.update(adelta, now)          # the body is theirs to move while they answer the player
			_show(id, body, 2 if act.hidden else (0 if near2 < 100.0 else 1))
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		var at := Vector2(body.position.x, body.position.z)
		var carried := 0.0
		var off: Vector2 = _carry.get(id, Vector2.ZERO)
		if _carry_from_body.erase(id):
			off = at - next
		if off != Vector2.ZERO:
			carried = 3.4 if off.length() > 6.0 else 1.3           # walking the way back to the day's place
			off = off.move_toward(Vector2.ZERO, carried * adelta)
			if off.length() < 0.05:
				off = Vector2.ZERO
				carried = 0.0
				_carry.erase(id)
			else:
				_carry[id] = off
		var here := next + off
		body.position = Vector3(here.x, _shape.height_at(here.x, here.y), here.y)
		var moving := (progress < 1.0 and length > 0.1) or carried > 0.0
		if at.distance_squared_to(here) > 0.00001:
			body.rotation.y = atan2(here.x - at.x, here.y - at.y)
		# what they are doing now: made once a minute for each, a few a frame
		if _pick_minute.get(id, -1) != now and picks > 0:
			picks -= 1
			_choose(v, id, now)
		var pick: Dictionary = _picks.get(id, {})
		if pick.get("hidden", false) and not moving:
			_show(id, body, 2)         # indoors: asleep, or away
			_offer_talk(id, body, p, near2, controls_locked)
			continue
		_show(id, body, 0 if near2 < 100.0 else 1)
		if moving:
			body.play_motion((carried if carried > 0.0 else 1.3) if not VillageSession.background and not Controls.locked else 0.0)
			if _applied.has(id):
				_applied.erase(id)
				_aligned.erase(id)
				body.show_tool("")
		elif not p.locked and id != _talking and not pick.is_empty():
			var key := "%s|%s" % [pick.loop, pick.tool]
			if _applied.get(id, "") != key:
				_applied[id] = key
				body.play_loop(pick.loop, 0.25, 1.0, id * 0.37)
				body.show_tool(pick.tool)
			if not _aligned.has(id):
				_face(body, id, delta)
		_offer_talk(id, body, p, near2, controls_locked)
	_name_tag(v, delta)
	frame_usec.append(Time.get_ticks_usec() - t0)
	if frame_usec.size() > 3600:
		frame_usec.pop_front()

## Plans a trip: where they stand about the destination, and the way there. A crowd stands on a sunflower spiral (a
## metre or so apart); at their own home in the daytime they are indoors (hidden at the door) or about a chore in
## the yard, spread round the house, never all at the door.
func _plan(v, id: int, trip: Dictionary) -> void:
	var who := _who_of(v, id)
	var offset := _offset(id, trip.place)
	var inside := false
	if Sites.HOMES.has(trip.place) and trip.place == who.home:
		inside = Anims.stays_in(id, int(trip.start) % 1440, int(trip.start) / 1440)
		offset = Vector2.ZERO if inside else _yard(id, trip.place) - place(trip.place)
	_inside[id] = inside
	var from_offset: Vector2 = _at_offset.get(id, Vector2.ZERO) if destinations.has(id) and destinations[id].place == trip.from else Vector2.ZERO
	var start := place(trip.from) + from_offset
	var goal := place(trip.place) + offset
	_at_offset[id] = offset
	destinations[id] = trip
	paths[id] = [start] + Array(_router._route(start, goal))

## Where a resident stands about a place: a sunflower spiral, by how many of the residents with a lower id are
## already heading there, so however many come they stay a metre or so apart (not one heap at the door).
func _offset(id: int, place_name: String) -> Vector2:
	var rank := 0
	for other: int in destinations:
		if other < id and destinations[other].place == place_name:
			rank += 1
	var angle := rank * 2.39996 + id * 0.5
	return Vector2(cos(angle), sin(angle)) * (1.0 * sqrt(rank + 0.6))

## A spot in the yard of a home, clear of walls, a different side for each of the household.
func _yard(id: int, home: String) -> Vector2:
	var centre: Vector2 = Sites.HOMES[home]
	var half := 2.5
	for h: Dictionary in Stage.Houses.HOUSES:
		if (h["at"] as Vector2).distance_to(centre) < 0.5:
			half = Vector2(h["size"].x, h["size"].z).length() * 0.5
	var rank := 0
	for other: int in destinations:
		if other < id and destinations[other].place == home:
			rank += 1
	for k in 8:
		var angle := float(rank + k) * 1.7 + id * 0.9
		var spot := centre + Vector2(cos(angle), sin(angle)) * (half + 1.5 + float((rank + k) % 3) * 0.6)
		if not _router._blocked(spot):
			return spot
	return place(home)

## Makes a body drawn (tier 0 or 1) or indoors (2). Indoors is not drawn at all; a body a stage had hidden
## shows again as soon as its day says so.
func _show(id: int, body: Body, tier: int) -> void:
	if _tier.get(id, -1) != tier:
		_tier[id] = tier
		body.set_detail(tier)
	var drawn := tier < 2
	if body.visible != drawn:
		body.visible = drawn

## The day's pick for one resident: the loop and tool for what they are doing, who they chat with, and where
## they look.
func _choose(v, id: int, now: int) -> void:
	var day := now / 1440
	var who := _who_of(v, id)
	var activity: Dictionary = View.activity(v, id)
	_pick_minute[id] = now
	_activity[id] = activity
	var partner := _partner_of(id, activity)
	var pick := Anims.pick(activity.verb, who.role, who.age_group, id, now, partner, _inside.get(id, false))
	_picks[id] = pick
	var target := Vector2.INF
	match pick.face:
		"partner":
			if bodies.has(partner):
				target = Vector2((bodies[partner] as Body).position.x, (bodies[partner] as Body).position.z)
		"place":
			target = focus(activity.place)
		"home":
			target = Sites.HOMES.get(activity.place, Vector2.INF)
	_aligned.erase(id)
	if target == Vector2.INF:
		_faces.erase(id)
	else:
		_faces[id] = target

## What does not change within a day about a resident: their trade, age, home, and whether they are Enea's.
func _who_of(v, id: int) -> Dictionary:
	var who: Dictionary = _who.get(id, {})
	var day := int(v.runtime.now) / 1440
	if int(who.get("day", -1)) != day:
		var d := View.describe(v, id)          # who they are changes at most with the years: asked once a day
		who = {"role": d.role, "age_group": d.age_group, "home": d.home, "day": day}
		_who[id] = who
	return who

func _is_protected(_v, p) -> bool:
	return p.authored != ""   # Enea's own characters (sim/authored.gd)

## Whether a resident is one of Enea's own characters (no body here; an event never borrows them).
func is_protected(id: int) -> bool:
	return _skip.has(id) or _is_protected(VillageSession.village, VillageSession.village.people[id])

## Whether every resident who should have a body here has one (probes wait on this).
func all_built() -> bool:
	var v = VillageSession.village
	for p in v.people:
		if p.alive and p.present and not bodies.has(p.id) and not _skip.has(p.id):
			return false
	return true

## Who a resident chats with: the residents chatting in the same place, paired by id order.
func _partner_of(id: int, activity: Dictionary) -> int:
	if activity.verb != "chatting":
		return -1
	var mates: Array[int] = []
	for other: int in _activity:
		var a: Dictionary = _activity[other]
		if a.verb == "chatting" and a.place == activity.place and bodies.has(other) and not borrowed.has(other):
			mates.append(other)
	mates.sort()
	var i := mates.find(id)
	if mates.size() < 2 or i < 0:
		return -1
	var j := i ^ 1
	return mates[j] if j < mates.size() else mates[i - 1]

## A standing body turns to what it faces (its work, its chat partner, its own door), then stops looking.
func _face(body: Body, id: int, delta: float) -> void:
	if not _faces.has(id):
		_aligned[id] = true
		return
	var to: Vector2 = (_faces[id] as Vector2) - Vector2(body.position.x, body.position.z)
	if to.length_squared() < 0.04:
		_aligned[id] = true
		return
	var goal := atan2(to.x, to.y)
	if absf(angle_difference(body.rotation.y, goal)) > 0.01:
		body.rotation.y = lerp_angle(body.rotation.y, goal, clampf(delta * TURN, 0.0, 1.0))
	else:
		_aligned[id] = true

## Where a place's work is done: its focus (the sails of the mill), else the place itself.
func focus(place_name: String) -> Vector2:
	if Sites.PLACES.has(place_name):
		return Sites.PLACES[place_name]["focus"]
	return place(place_name)

## The talk spot of a resident is in the player's reach group only while it can be used: the resident is
## near the player, drawn, and not held for an event. (near2: squared metres to the player.)
func _offer_talk(id: int, body: Body, p, near2: float, controls_locked: bool) -> void:
	var spot: Talk.Spot = _spots.get(id)
	if spot == null:
		return
	var want: bool = near2 < TALK_NEAR * TALK_NEAR and not controls_locked and body.visible and not p.locked
	if want != spot.offered:
		spot.offered = want
		if want:
			spot.add_to_group("interactable")
		else:
			spot.remove_from_group("interactable")

## The name over whoever the action button would talk to (the player's own choice of station), else nothing.
func _name_tag(v, delta: float) -> void:
	var aimed: Body = null
	var who := -1
	var height := 2.15
	if _player != null and not Controls.locked:
		var station: Object = _player.get("_station")
		if is_instance_valid(station) and station is Talk.Spot and bodies.has((station as Talk.Spot).resident):
			who = (station as Talk.Spot).resident
			aimed = bodies[who]
			height = 2.15 * aimed.scale.y
			if React.has_bubble(aimed):
				aimed = null          # they are speaking: the words are over their head, the name would sit on them
				who = -1
	_tag.aim(aimed, str(v.people[who].name) if who >= 0 else "", height, delta)

## The village is talking to this resident: they stop what they are doing, turn to the player and talk until
## the screen closes. (A body an event holds keeps to the event.)
func begin_talk(id: int, player: Node3D) -> void:
	_talk_open = true
	if not bodies.has(id) or borrowed.has(id):
		return
	_talking = id
	var act: Acts.Act = _acts.get(id)
	if act != null:                    # they stop what they were doing about the player to talk (from where they stand)
		act.cleanup()
		_acts.erase(id)
		_carry_from_body[id] = true
	var body: Body = bodies[id]
	var to := Vector2(player.global_position.x - body.global_position.x, player.global_position.z - body.global_position.z)
	if to.length_squared() > 0.01:
		body.rotation.y = atan2(to.x, to.y)
	body.play_motion(0.0)
	body.play_loop("Idle_Talking", 0.2, 1.0, 0.0)
	_applied.erase(id)
	_aligned.erase(id)

## ---- what resident_acts.gd asks of the registry ------------------------------------------------------------

func ground(p: Vector2) -> float:
	return _shape.height_at(p.x, p.y)

func route(a: Vector2, b: Vector2) -> PackedVector2Array:
	return _router._route(a, b)

func player() -> Node3D:
	return _player

func player_xz() -> Vector2:
	return Vector2(_player.global_position.x, _player.global_position.z) if _player != null else Vector2.ZERO

func player_can_be_hit() -> bool:
	return _player != null and _player.can_be_targeted()

func body_xz(id: int) -> Vector2:
	return Vector2((bodies[id] as Body).position.x, (bodies[id] as Body).position.z) if bodies.has(id) else player_xz()

func hurt_of(id: int) -> int:
	return int(VillageSession.village.people[id].hurt)

## Their door (where they run to when it is too much).
func door_of(id: int) -> Vector2:
	var home: String = _who_of(VillageSession.village, id).home
	return place(home) if not home.is_empty() else place("square")

## Someone to run to for help: a grown person nearby, drawn and free, the household first.
func helper_for(id: int) -> int:
	var v = VillageSession.village
	var mine := body_xz(id)
	var home: String = _who_of(v, id).home
	var best := -1
	var best_score := 40.0
	for other: int in bodies:
		if other == id or borrowed.has(other) or not (bodies[other] as Body).visible:
			continue
		var q = v.people[other]
		if not q.alive or not q.present or q.locked or q.down_until > int(v.runtime.now):
			continue
		var who := _who_of(v, other)
		if who.age_group == "child":
			continue
		var score := mine.distance_to(body_xz(other)) - (12.0 if who.home == home else 0.0)   # kin count as nearer
		if score < best_score:
			best_score = score
			best = other
	return best

## Who was struck at the minute an onlooker's answer began (only the struck give some answers).
func struck_of(since: int) -> int:
	var reactions: Dictionary = VillageSession.village.runtime.get("reactions", {})
	for key: String in reactions:
		var r: Dictionary = reactions[key]
		if int(r.since) == since and str(r.state) in Acts.STRUCK_ONLY:
			return int(key)
	return -1

## Starts acting out any new answer the village has written (runtime.reactions); an answer that has run its
## time is ended in the loop.
func _sync_reactions(v, now: int) -> void:
	var reactions: Dictionary = v.runtime.get("reactions", {})
	if reactions.is_empty():
		return
	for key: String in reactions:
		var r: Dictionary = reactions[key]
		if int(r.until) <= now:
			continue
		var id := int(key)
		if not bodies.has(id) or borrowed.has(id) or _skip.has(id):
			continue
		var old: Acts.Act = _acts.get(id)
		if old != null and old.since == int(r.since) and old.state == str(r.state):
			continue
		var p = v.people[id]
		if not p.alive or not p.present:
			continue
		var act := Acts.Act.new()
		act.id = id
		act.state = str(r.state)
		act.since = int(r.since)
		act.until = int(r.until)
		act.reg = self
		act.body = bodies[id]
		var struck := struck_of(act.since)
		act.onlooker = act.state in ["intervene", "shout", "back_away", "watch"] \
				or (act.state == "flee" and ((struck >= 0 and struck != id) or _who_of(v, id).age_group == "child"))
		if old != null:
			old.cleanup()
		if _talking == id:
			_talking = -1
		act.start()
		_acts[id] = act
		_applied.erase(id)
		_aligned.erase(id)

## An answer has run its time: the body is handed back, and walks from where it stands to where the day has got to.
func _end_act(id: int, act: Acts.Act, routine_pos: Vector2) -> void:
	var off := act.pos - routine_pos
	if off.length() > 0.3:
		_carry[id] = off
	act.cleanup()
	_acts.erase(id)
	_applied.erase(id)
	_aligned.erase(id)
	_tier.erase(id)

func place(name: String) -> Vector2:
	if Sites.DOORS.has(name):
		return Sites.DOORS[name] # simulation homes name buildings; bodies and clues use their accessible doors
	var v = VillageSession.village
	var index: int = v.place_ids.get(name, -1)
	return Vector2(v.place_x[index], v.place_z[index]) / 10.0 if index >= 0 else Sites.at(name)

func ensure(person: Dictionary) -> Body:
	var id := int(person.id)
	if bodies.has(id):
		return bodies[id]
	var t0 := Time.get_ticks_usec()
	var body := Body.new()
	var resident = VillageSession.village.people[id]
	body.hero_look = Talk.look_of(VillageSession.village, id)
	body.is_player_look = false
	add_child(body)
	var trip := Runtime.routine(VillageSession.village, id)
	var at := place(trip.from)
	body.position = Vector3(at.x, _shape.height_at(at.x, at.y), at.y)
	bodies[id] = body
	if Rules.age_of(VillageSession.village, resident) < 14:
		body.scale = Vector3.ONE * CHILD_SCALE
	var spot := Talk.Spot.new()
	spot.name = "TalkSpot"
	spot.resident = id
	body.add_child(spot)
	_spots[id] = spot
	build_usec.append(Time.get_ticks_usec() - t0)
	return body

func acquire(person: Dictionary, parent: Node) -> Body:
	var body := ensure(person)
	borrowed[int(person.id)] = true
	body.reparent(parent, true)
	body.process_mode = Node.PROCESS_MODE_INHERIT
	body.set_detail(1)
	_applied.erase(int(person.id))
	_tier.erase(int(person.id))
	var act: Acts.Act = _acts.get(int(person.id))
	if act != null:                    # an event needs them: the answer to the player is over
		act.cleanup()
		_acts.erase(int(person.id))
	_carry.erase(int(person.id))
	if _talking == int(person.id):
		_talking = -1
	return body

func release(id: int, body: Body) -> void:
	if not is_instance_valid(body):
		return
	body.release_hands()
	body.reparent(self, true)
	body.process_mode = Node.PROCESS_MODE_INHERIT
	borrowed.erase(id)
	destinations.erase(id)
	_applied.erase(id)
	_aligned.erase(id)
	_tier.erase(id)
	_pick_minute.erase(id)

func _exit_tree() -> void:
	# Only data belongs to VillageSession. This registry dies with its region scene.
	borrowed.clear()
