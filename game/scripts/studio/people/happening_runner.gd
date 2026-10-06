extends RefCounted
## Plays on the bodies a happening the rules decided (plan VILLAGE-LIFE-AND-NEWS section 5, #6): the cast walk to where
## it happens (or are there already), then each phase of the record's path at the minutes the record gives, its shape,
## beats and lines from happening_kinds.gd; while it is loud, those who hear it come to watch, one by one, from a ring -
## out of their doors too - and when it is over everyone goes back to their day. Generic: movers, bodies, a clock and
## what the director gives it, not villages.
##
##   var run := HappeningRunner.new(record, director)
##       record    the rules' record (sim/happenings.gd): kind, a, b, path, phases [[name, from, to] game minutes],
##                 peacemaker (an id, -2 the player, -1 none); a meeting's elder and outcome (sim/town_meeting.gd)
##       director  {"mover": (id) -> Mover, "body": (id) -> Node3D,
##                  "claim": (id, keep) -> bool    take the body for this (people/owners.gd); false: someone higher has
##                                                 it; keep: if someone higher takes it later, it comes back (resume)
##                  "holds": (id) -> bool          this has the body now (not lent to something higher meanwhile)
##                  "release": (id) -> void        done with it: back to its day
##                  "clock": () -> float           game minutes now, with the fraction
##                  "at": Vector2                  where it happens
##                  "world": Dictionary            what a situation asks (situation.gd: route, standable)
##                  "sees": (Vector2, Vector2) -> bool   nothing solid between
##                  "stimuli": Stimuli             the door: each phase gives off its voices
##                  "watchers": (Vector2, float, int, Array, String) -> Array   who may come to watch: [[id, metres],
##                                                 ...], free to be taken, within the loudness, nearest first, not those
##                                                 given; "bold" or "all" (happening_kinds.gd come)
##                  "out": (id) -> void            someone indoors steps out of their door (the director shows them)
##                  "say": (id, line_kind) -> void a line aloud
##                  "player": () -> Vector2        where the player stands (the peacemaker when it is them)
##                  "end": (record, ids, at) -> void   (optional) it is over: those just let go, to break up their way}
##   run.update(dt) -> bool   true once it is over and everyone is released
##   run.stop()               over early: everyone released
##   run.drop(id)             someone higher took `id`: out of it (one of the two: it is over on the bodies)
##   run.resume(id)           `id` is back from something higher (a kind that keeps its cast): to their place again
##   run.phase                the phase now: "coming" (the two on their way), a phase of the path, or "done"
##   run.watching             ids come to watch (arrived or on their way)
##   run.people_seen          the most there at once: the cast and those arrived to watch (a measure)
##   run.ended                why it ended on the bodies ("" while it goes on; a measure)
const Situation := preload("res://scripts/studio/people/situation.gd")
const Spots := preload("res://scripts/studio/people/spots.gd")
const Kinds := preload("res://scripts/studio/people/happening_kinds.gd")

const COME_LEAST := 0.3        # seconds before the first onlooker sets off, at least ...
const COME_PER_M := 0.09       # ... and this many more a metre away (the far ones notice later) ...
const COME_SPREAD := 1.2       # ... and up to this much more, each their own
const SPOT_FROM := 7.0         # metres from the middle: an onlooker on their way takes a spot on the ring from here
const WATCH_EVERY := 3.0       # seconds, about, between an onlooker's changes of pose
const LATE := 30.0             # seconds the two may take to get there before it goes on without waiting
const PLAYER := -2             # the player, in the rules' records

var record: Dictionary
var phase := ""
var watching: Array[int] = []
var people_seen := 0
var ended := ""
var _d: Dictionary
var _a := -1
var _b := -1
var _peace := -1
var _elder := -1
var _speakers: Array[int] = [] # an address's row, in order (a meeting: the aggrieved, the other, the elder)
var _front := Vector2.DOWN     # the way an address's row faces
var _speaking := -1            # who stepped forward to speak
var _to_pose := {}             # id -> clip: played once they stop walking
var _cast: Array[int] = []     # those taken: the two, the peacemaker, those come to watch
var _sit: Situation
var _ring: Spots.Gathering
var _coming := {}              # id -> seconds left before they set off to watch
var _arrived := {}             # id -> true: on the ring
var _pose_left := {}           # id -> seconds to their next pose
var _beat := -1
var _beat_left := 0.0
var _said := {}                # phase -> true: its lines were said
var _waited := 0.0
var _key := 0


func _init(the_record: Dictionary, director: Dictionary) -> void:
	record = the_record
	_d = director
	_a = int(record.a)
	_b = int(record.b)
	_elder = int(record.get("elder", -1))
	_peace = int(record.get("peacemaker", -1))
	_key = hash([int(record.id), _a, _b])
	var needs: Array = Kinds.meta(str(record.kind)).get("needs", ["a", "b"])
	for id: int in [_a, _b, _elder]:
		if id >= 0 and not _cast.has(id) and _d.claim.call(id, _keeps()):
			_cast.append(id)
	for role: String in needs:
		if not _cast.has(_id_of(role)):
			stop("could not take the %s" % role)
			return
	phase = "coming"
	if _addresses():
		for id: int in [_a, _b, _elder]:
			if _cast.has(id) and not _speakers.has(id):
				_speakers.append(id)
		if _d.has("player"):
			var to_player: Vector2 = (_d.player.call() as Vector2) - (_d.at as Vector2)
			if to_player.length() > 1.0:
				_front = to_player.normalized()   # the row faces the side the player comes from
		for id: int in _speakers:
			var m = _d.mover.call(id)
			m.go(_way(m.pos, _stand(id)), INF, "walk")
		return
	for id: int in [_a, _b]:
		var m = _d.mover.call(id)
		m.go(_way(m.pos, _side(id)), INF, "walk")


func update(dt: float) -> bool:
	if phase == "done":
		return true
	var now: float = _d.clock.call()
	var name := _phase_at(now)
	if phase == "coming":
		_waited += dt
		if name != "" and not _there() and _waited < LATE and bool(Kinds.meta(str(record.kind)).get("waits", true)):
			return false                        # the first phase waits for the two to arrive (its minutes run on)
	if name == "":
		if now >= float(record.ends):
			stop("over")
			return true
		return false
	if name != phase:
		_enter(name)
		if phase == "done":
			return true                         # (it dispersed)
	_play(dt)
	_watchers(dt)
	var here := _cast.size() - watching.size() + _arrived.size()
	people_seen = maxi(people_seen, here)
	return false


## Someone higher took `id` (people/owners.gd): they are no longer part of it (one of the two: it is over on the bodies).
func drop(id: int) -> void:
	if Kinds.meta(str(record.kind)).get("needs", ["a", "b"]).has(_role_of(id)):
		_cast.erase(id)
		stop("the %s taken by something higher" % _role_of(id))
		return
	_cast.erase(id)
	_speakers.erase(id)
	watching.erase(id)
	_arrived.erase(id)
	_coming.erase(id)
	if _ring != null:
		_ring.release(id)


func has(id: int) -> bool:
	return _cast.has(id) or _coming.has(id)


func resume(id: int) -> void:
	if not _cast.has(id):
		return
	var m = _d.mover.call(id)
	if _speakers.has(id):
		m.go(_way(m.pos, _stand(id)), INF, "walk")
		m.face_at = (_d.at as Vector2) + _front * 6.0
	elif watching.has(id):
		_arrived.erase(id)                       # on their way back: a spot on the ring again as they come near
		if _ring != null:
			_ring.release(id)
		m.go(_way(m.pos, (_d.at as Vector2) + (m.pos - (_d.at as Vector2)).normalized() * (SPOT_FROM - 1.0)), INF, "walk")


func stop(why := "stopped") -> void:
	if ended.is_empty():
		ended = why
	if _sit != null:
		_sit.cleanup()
		_sit = null
	var let_go: Array[int] = []
	for id: int in _cast:
		if _ring != null:
			_ring.release(id)
		var had: bool = _d.holds.call(id)
		_d.release.call(id)
		if had:
			let_go.append(id)
	_cast.clear()
	phase = "done"
	if _d.has("end") and not let_go.is_empty():
		_d.end.call(record, let_go, _d.at)     # they break up as people do, each their own way (the director's reactions)


# ---------- phases ----------

func _phase_at(now: float) -> String:
	for ph: Array in record.phases:
		if now >= float(ph[1]) and now < float(ph[2]):
			return str(ph[0])
	return ""


func _enter(name: String) -> void:
	phase = name
	_peace = int(record.get("peacemaker", -1))   # (the player may have stepped in since: the rules changed the record)
	var p := Kinds.phase(str(record.kind), name)
	_beat = -1
	_beat_left = 0.0
	if _sit != null:
		_sit.cleanup()
		_sit = null
	var ma = _d.mover.call(_a)
	var mb = _d.mover.call(_b)
	var middle: Vector2 = _d.at
	match str(p.get("shape", "pair")):
		"address":
			_speaking = -1
			for id: int in _speakers:
				if not _holds(id):
					continue
				var m = _d.mover.call(id)
				if m.pos.distance_to(_stand(id)) > 0.5:
					m.go(_way(m.pos, _stand(id)), INF, "walk")
				m.face_at = middle + _front * 6.0
		"disperse":
			stop("dispersed")                    # over: everyone back to their day
			return
		"pair":
			_sit = Situation.new("happening:" + name, {"shape": "pair", "beats": p.get("beats", []), "end": ""}, [ma, mb],
				[_d.body.call(_a), _d.body.call(_b)], INF, _key, _d.world)
			_sit.centre = middle
			_sit._meet()
		"between":
			var across: Vector2 = (mb.pos - ma.pos).normalized() if ma.pos.distance_to(mb.pos) > 0.1 else Vector2.RIGHT
			ma.go(_way(ma.pos, middle - across * Kinds.GAP_BETWEEN), INF, "walk")
			mb.go(_way(mb.pos, middle + across * Kinds.GAP_BETWEEN), INF, "walk")
			ma.face_at = middle
			mb.face_at = middle
			if _peace == PLAYER and _d.has("player"):
				ma.face_at = _d.player.call()        # the player stepped between them
				mb.face_at = _d.player.call()
			if _peace >= 0 and _d.claim.call(_peace):
				if not _cast.has(_peace):
					_cast.append(_peace)
				if _ring != null:
					_ring.release(_peace)
				watching.erase(_peace)
				_arrived.erase(_peace)
				var mp = _d.mover.call(_peace)
				mp.go(_way(mp.pos, middle), INF, "hurry")
				mp.face_at = ma.pos
		"apart":
			var away: Vector2 = (ma.pos - mb.pos).normalized() if ma.pos.distance_to(mb.pos) > 0.1 else Vector2.LEFT
			ma.go(_way(ma.pos, middle + away * Kinds.GAP_APART), INF, "walk")
			mb.go(_way(mb.pos, middle - away * Kinds.GAP_APART), INF, "walk")
			ma.face_at = middle + away * 6.0       # half turned away
			mb.face_at = middle
	var loud := float(p.get("loud", 0.0))
	if loud > 0.0 and _d.has("stimuli"):
		var minutes := 0.0
		for ph: Array in record.phases:
			if str(ph[0]) == name:
				minutes = float(ph[2]) - float(ph[1])
		_d.stimuli.emit(str(p.get("sound", "raised_voices" if name != "blows" else "fight")), middle, loud, _a,
			maxf(minutes * 0.5, 1.0), {"happening": int(record.id), "kind": str(record.kind), "phase": name})
	var draw := int(p.get("draw", 0))
	if draw > 0:
		_call_watchers(middle, float(p.get("draw_from", loud)), draw, p.get("ring", [3.5, 6.5]))
	if not _said.has(name):
		_said[name] = true
		var lines: Dictionary = p.get("lines", {})
		for role: String in lines:
			var who := _id_of(role)
			var line := str(lines[role]).replace("{outcome}", str(record.get("outcome", "")))
			if who >= 0 and _cast.has(who) and _d.has("say") and not line.ends_with("_"):
				_d.say.call(who, line)


func _play(dt: float) -> void:
	if _sit != null:
		_sit.update(dt)                        # the pair's shape and beats (situation.gd)
		return
	for id: int in _to_pose.keys():            # a pose waits until they stand still
		if not _cast.has(id) or not _holds(id):
			_to_pose.erase(id)
		elif not _d.mover.call(id).walking():
			_pose(_d.body.call(id), str(_to_pose[id]))
			_to_pose.erase(id)
	var p := Kinds.phase(str(record.kind), phase)
	var beats: Array = p.get("beats", [])
	if beats.is_empty():
		return
	_beat_left -= dt
	if _beat_left > 0.0:
		return
	_beat = (_beat + 1) % beats.size()
	var beat: Array = beats[_beat]
	_beat_left = float(beat[2])
	if str(p.get("shape", "")) == "address":
		_address_beat(str(beat[0]), str(beat[1]))
		return
	for role: String in ["a", "b", "peacemaker"]:
		var who := _id_of(role)
		if who < 0 or not _cast.has(who) or not _holds(who):
			continue
		var body = _d.body.call(who)
		var m = _d.mover.call(who)
		if m.walking():
			continue
		if beat[0] == role or beat[0] == "both" and role != "peacemaker":
			_pose(body, str(beat[1]))
		if role == "peacemaker":
			m.face_at = (_d.mover.call(_a).pos if _beat % 2 == 0 else _d.mover.call(_b).pos)


## An address's beat: the one whose turn it is steps out of the row and speaks; the one before steps back; the rest of
## the row turn to them. "all": everyone back in the row, facing the crowd.
func _address_beat(role: String, clip: String) -> void:
	var who := -1 if role == "all" else _id_of(role)
	if who >= 0 and not _speakers.has(who):
		return
	if _speaking >= 0 and _speaking != who and _speakers.has(_speaking):
		var back = _d.mover.call(_speaking)
		back.go(_way(back.pos, _stand(_speaking)), INF, "walk")
		back.face_at = (_d.at as Vector2) + _front * 6.0
	_speaking = who
	for id: int in _speakers:
		if not _holds(id):
			continue                              # lent to something higher for now (resume brings them back)
		var m = _d.mover.call(id)
		if id == who:
			if m.pos.distance_to(_stand(id) + _front * Kinds.STEP_FORWARD) > 0.3:
				m.go(_way(m.pos, _stand(id) + _front * Kinds.STEP_FORWARD), INF, "walk")
			m.face_at = (_d.at as Vector2) + _front * 8.0
			_to_pose[id] = clip
		elif who >= 0:
			m.face_at = _stand(who) + _front * Kinds.STEP_FORWARD
		else:
			m.face_at = (_d.at as Vector2) + _front * 6.0
			_to_pose[id] = clip


# ---------- those who come to watch ----------

func _call_watchers(middle: Vector2, loud: float, most: int, ring: Array) -> void:
	if _ring == null:
		var first := float(ring[0])
		_ring = Spots.Gathering.new(middle, _d.world.get("standable", func(_p: Vector2) -> bool: return true),
			_d.get("sees", Callable()), first, maxi(2, int((float(ring[1]) - first) / Spots.GAP) + 1))
	var room := most - watching.size()
	if room <= 0 or not _d.has("watchers"):
		return
	var those: Array = _cast.duplicate()
	if _peace >= 0:
		those.append(_peace)
	var come := str(Kinds.phase(str(record.kind), phase).get("come", "bold"))
	for w: Array in _d.watchers.call(middle, loud, room, those, come):
		var id := int(w[0])
		if watching.has(id) or _coming.has(id) or _cast.has(id):
			continue
		_coming[id] = COME_LEAST + COME_PER_M * float(w[1]) + COME_SPREAD * _noise(_key + id, 3)


func _watchers(dt: float) -> void:
	for id: int in _coming.keys():
		_coming[id] = float(_coming[id]) - dt
		if float(_coming[id]) > 0.0:
			continue
		_coming.erase(id)
		if not _d.claim.call(id, _keeps()):
			continue                            # taken by something higher meanwhile
		_cast.append(id)
		watching.append(id)
		if _d.has("out"):
			_d.out.call(id)                     # out of their door, if they were in
		var m = _d.mover.call(id)
		var toward: Vector2 = _d.at
		m.go(_way(m.pos, toward + (m.pos - toward).normalized() * (SPOT_FROM - 1.0)), INF, "hurry" if phase == "blows" else "walk")
	for id: int in watching:
		if not _holds(id):
			continue
		var m = _d.mover.call(id)
		if not _arrived.has(id):
			if _ring != null and (m.pos.distance_to(_d.at) <= SPOT_FROM or not m.walking()):
				var spot := _ring.claim(id, m.pos)
				m.go(_way(m.pos, spot), INF, "walk")
				m.face_at = _d.at
				_arrived[id] = true
				_pose_left[id] = 0.5 + _noise(_key + id, 5)
			continue
		if m.walking():
			continue
		m.face_at = _stand(_speaking) + _front * Kinds.STEP_FORWARD if _speaking >= 0 else _d.at
		_pose_left[id] = float(_pose_left.get(id, 0.0)) - dt
		if float(_pose_left[id]) <= 0.0:
			var p := Kinds.phase(str(record.kind), phase)
			var clips: Array = p.get("watch_by", {}).get(str(record.get("outcome", "")), p.get("watch", ["Idle"]))
			_pose_left[id] = WATCH_EVERY * (0.6 + 0.8 * _noise(_key + id + _beat, 7))
			_pose(_d.body.call(id), str(clips[(id + maxi(_beat, 0)) % clips.size()]))


# ---------- helpers ----------

func _there() -> bool:
	if _addresses():
		for id: int in _speakers:
			if (_d.mover.call(id).pos as Vector2).distance_to(_stand(id)) > 1.5:
				return false
		return true
	for id: int in [_a, _b]:
		if (_d.mover.call(id).pos as Vector2).distance_to(_d.at) > 2.5:
			return false
	return true


func _keeps() -> bool:
	return bool(Kinds.meta(str(record.kind)).get("keep", false))


func _holds(id: int) -> bool:
	return not _d.has("holds") or bool(_d.holds.call(id))


func _addresses() -> bool:
	var first: Array = record.phases[0] if not (record.phases as Array).is_empty() else []
	return not first.is_empty() and str(Kinds.phase(str(record.kind), str(first[0])).get("shape", "")) == "address"


## A speaker's place in the row: side by side across the middle, facing _front.
func _stand(id: int) -> Vector2:
	var i := _speakers.find(id)
	if i < 0:
		return _d.at
	var across := Vector2(-_front.y, _front.x)
	return (_d.at as Vector2) + across * (float(i) - float(_speakers.size() - 1) * 0.5) * Kinds.ROW_GAP


func _id_of(role: String) -> int:
	match role:
		"a": return _a
		"b": return _b
		"peacemaker": return _peace
		"elder": return _elder
	return -1


func _role_of(id: int) -> String:
	if id == _a: return "a"
	if id == _b: return "b"
	if id == _elder: return "elder"
	if id == _peace: return "peacemaker"
	return ""


## Where each of the two heads to start: their own side of the middle (they come from where they are).
func _side(id: int) -> Vector2:
	var other := _b if id == _a else _a
	var mine: Vector2 = _d.mover.call(id).pos
	var theirs: Vector2 = _d.mover.call(other).pos
	var across := (mine - theirs).normalized() if mine.distance_to(theirs) > 0.1 else (Vector2.LEFT if id == _a else Vector2.RIGHT)
	return (_d.at as Vector2) + across * 0.7


func _pose(body, clip: String) -> void:
	if not is_instance_valid(body):
		return
	if clip.begins_with("@"):
		if body.has_method(clip.substr(1)):
			body.call(clip.substr(1))
		return
	if body.has_method("play_loop"):
		body.play_loop(clip, 0.25, 1.0, 0.0)


func _way(from: Vector2, to: Vector2) -> PackedVector2Array:
	var route: Callable = _d.world.get("route", Callable())
	return route.call(from, to) if route.is_valid() else PackedVector2Array([to])


static func _noise(k: int, salt: int) -> float:
	return float(posmod(hash(k * 7919 + salt * 104729), 100000)) / 100000.0
