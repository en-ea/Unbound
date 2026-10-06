extends RefCounted
## Who meets whom, and who talks with whom (Pass 3, stage 3; Hilmi: "ensure this is cleanly done and modular (so it can
## be used in more contexts, efficiently)"). The meetings in passing and the conversations of a place, kept apart from
## any one place: people are ids with a mover and a body, and all the society knows of them comes from its director
## (the village, residents.gd, is one; a camp, a tavern, a market could be others). Presentation only: nothing here is
## saved, and the rules never read it.
##
##   var society := Society.new(director)
##       director  {"mover":    (id) -> Mover                    their mover
##                  "body":     (id) -> Node3D                   their body
##                  "world":    Dictionary                       what a situation asks (situation.gd: route, standable)
##                  "role":     (id, other) -> Dictionary        what the catalogue needs of id meeting other
##                                                               (encounters.gd: age, sociable, bold, temper, likes, kin)
##                  "affinity": (a, b) -> float                  how well a gets on with b (who talks with whom)
##                  "voice":    (id) -> float                    how readily they talk, 0..1
##                  "good":     (Vector2) -> bool                a spot to stand on (no wall, no doorstep, room round it)
##                  "busy":     (Vector2, float, Array) -> bool  someone not among those stands, or is going to, that near
##                  "doorstep": (Vector2) -> bool                (optional) nobody stops for a word here
##                  "together": (a, b) -> bool                   (optional) talking together already (no meeting)
##                  "taken":    (id, for_good: bool) -> void     (optional) the society has them now: for good (a
##                                                               conversation: the director lets go of what they were
##                                                               doing, their spot) or a while (a meeting: it waits)
##                  "back":     (id, carry_on: bool) -> void     done with them: back to their day (carry_on: to what they
##                                                               were doing; false: wanted elsewhere, plan them afresh)
##                  "ended":    (Situation) -> void}             (optional) a situation is over (its voices hushed)
##                  "parted":   (id, centre, staying) -> void    (optional) someone left a circle whose time was up
##                                                               (it thins out one at a time): their goodbye
##                  "instead":  (name, a, b, k) -> String          (optional) what a meeting the catalogue chose becomes:
##                                                               the same, another entry, or "" (the director took them)
##   society.update(dt)                        plays the situations going on; those over hand their people back
##   society.meet(candidates, key)             any two of these whose ways meet: what they do about it (encounters.gd)
##   society.start(name, a, b, k)              a meeting begun on purpose (a visit's word with a friend)
##   society.talk(place, id, lone) -> bool     someone at a place's chat finds company: a circle there with room that
##                                             would have them, else one of `lone` (those there on their own)
##   society.tend(place, lone)                 now and then: those alone find company, a circle's odd one out mingles to
##                                             one they like better, a circle down to one ends
##   society.leave(id)                         wanted elsewhere: out of their situation (a circle talks on without them)
##   society.in_sit                            id -> the Situation they are in
##   society.groups() / society.spaces()       the conversations (a measure) / their middles (crowd.gd walks round them)
##   society.log                               every meeting begun: [seconds, name, a, b] (a measure)
##
##     meet:   pairs among the candidates, near (4 m) ──how they meet (pass, same way, near, still)──> the catalogue's
##             choice for who they are (encounters.gd) ──> a Situation (each pair asked once in MEET_AGAIN)
##     talk:   a circle with room where nobody minds them (Groups.WELCOME), the warmest; else a new circle with the one
##             alone there they get on with best; its middle where every place round it is good and nobody else stands
##
## Cost: meet is O(candidates squared) a look (a few dozen near the eye, four times a second); the rest is per situation.

const Situation := preload("res://scripts/studio/people/situation.gd")
const Encounters := preload("res://scripts/studio/people/encounters.gd")
const Formation := preload("res://scripts/studio/people/formation.gd")
const Groups := preload("res://scripts/studio/people/groups.gd")
const Mover := preload("res://scripts/studio/people/mover.gd")

const MEET_WITHIN := 4.0        # metres: two this near may meet
const MEET_AGAIN := 90.0        # seconds before the same two are asked again
const MEET_REST := 20.0         # seconds after a meeting before either is free for the next
const THIN_LEAST := 10.0        # seconds a thinning circle talks on after someone goes, at least ...
const THIN_SPREAD := 18.0       # ... and up to this much more
const AT_ONCE := 5              # meetings in passing going on at once, at most
const TALK_MOST := 5            # the most in one conversation
const TALK_ROOM := 1.4          # metres between one conversation's ring and the next
const MINGLE_EVERY := 25.0      # seconds, about, between someone moving from one conversation to another they like better
const MINGLE_BETTER := 12.0     # ... if they get on that much better with the other
const LOG_MOST := 400
const SEEN_WITHIN := 18.0       # metres: meetings this near each other are seen by the same eyes (variety)
const SEEN_FADE := 40.0         # seconds: how long a meeting stays fresh in those eyes (e^-t/40: a third after 45 s)

var situations: Array = []      # the situations going on
var in_sit := {}                # id -> the Situation they are in
var log: Array = []             # [seconds, name, a, b]: every meeting begun (a measure)
var life := 0.0                 # seconds the society has run
var _d: Dictionary              # the director
var _met := {}                  # pair key -> when the two were last asked
var _free_at := {}              # id -> when they are free for the next meeting
var _talks := {}                # place -> Array of "talk" Situations there
var _mingle_at := {}            # a talk Situation -> when one of its members may move to another
var _seen: Array = []           # [name, where, when] of meetings begun lately: what looks fresh (_fresh)


func _init(director: Dictionary) -> void:
	_d = director


func update(dt: float) -> void:
	life += dt
	for sit: Situation in situations.duplicate():
		if sit.name == "talk" and sit.who.size() >= 3 and sit.phase == "beats" and sit.t + dt >= sit.seconds:
			_thin(sit)
		if sit.update(dt):
			end(sit)


## A circle whose time is up thins out as people do (Hilmi's note 234050: "suddenly they all just stopped at the same
## time and robotically left"): the least talkative goes first, with a word and a wave (the director's `parted`); the
## rest talk on a while; the last two end it together.
func _thin(sit: Situation) -> void:
	var i := 0
	for k in sit.who.size():
		if float(sit.voices[k]) < float(sit.voices[i]):
			i = k
	var id: int = sit.who[i]
	sit.seconds = sit.t + THIN_LEAST + THIN_SPREAD * _noise(sit.key + id, 5)
	var staying: Array = sit.who.filter(func(o: int) -> bool: return o != id)
	sit.leave(id)
	in_sit.erase(id)
	_free_at[id] = life + MEET_REST
	_d.back.call(id, false)
	var parted: Callable = _d.get("parted", Callable())
	if parted.is_valid():
		parted.call(id, sit.centre, staying)


## Whether `id` may be asked to meet someone now (not in a situation, rested since their last).
func available(id: int) -> bool:
	return not in_sit.has(id) and float(_free_at.get(id, 0.0)) <= life


## Looks at every pair of `candidates` (ids free for it: the director's choice) near each other, and asks the catalogue
## what they do about meeting. `key` keys the choices.
func meet(candidates: Array[int], key: int) -> void:
	if situations.size() >= AT_ONCE:
		return
	for i in candidates.size():
		for j in range(i + 1, candidates.size()):
			var a := candidates[i]
			var b := candidates[j]
			if in_sit.has(a) or in_sit.has(b):
				continue
			var ma: Mover = _d.mover.call(a)
			var mb: Mover = _d.mover.call(b)
			var d := ma.pos.distance_to(mb.pos)
			if d > MEET_WITHIN:
				continue
			var how := _how_they_meet(a, b, ma, mb, d)
			if how == "" or _on_doorstep(ma.pos) or _on_doorstep(mb.pos):
				continue                         # (nobody stops for a word on a doorstep)
			var pair := mini(a, b) * 100003 + maxi(a, b)
			if life - float(_met.get(pair, -INF)) < MEET_AGAIN:
				continue
			_met[pair] = life                # asked once (whether or not they do anything): not again for a while
			var k := hash([a, b, key])
			var da: Dictionary = _d.role.call(a, b)
			var db: Dictionary = _d.role.call(b, a)
			var first := a
			var second := b
			var fresh := _fresh((ma.pos + mb.pos) * 0.5)
			var name := Encounters.choose(da, db, how, k, fresh)
			if name == "" and da.get("age") != db.get("age"):
				name = Encounters.choose(db, da, how, k + 1, fresh)   # the roles the other way round (a grown one, a child)
				first = b
				second = a
			if name == "":
				continue
			var instead: Callable = _d.get("instead", Callable())
			if instead.is_valid():
				name = str(instead.call(name, first, second, k))   # the director's own (an argument the rules decide)
				if name == "":
					continue
			start(name, first, second, k)
			if situations.size() >= AT_ONCE:
				return


## How two near each other meet: "pass" (walking, closing on each other), "same_way" (walking on together, far to go),
## "near" (one stands about, the other passes close), "still" (both stand about, not already talking), or "".
func _how_they_meet(a: int, b: int, ma: Mover, mb: Mover, d: float) -> String:
	var wa := ma.walking() and ma.vel.length() > 0.4
	var wb := mb.walking() and mb.vel.length() > 0.4
	if wa and wb:
		if ma.vel.normalized().dot(mb.vel.normalized()) > 0.85 and d < 3.0 and ma._left() > 8.0 and mb._left() > 8.0:
			return "same_way"
		if (ma.vel - mb.vel).dot((mb.pos - ma.pos).normalized()) > 0.5 and d < 3.5:
			return "pass"
		return ""
	if wa != wb:
		return "near" if d < 2.8 else ""
	if d > 3.0:
		return ""
	var together: Callable = _d.get("together", Callable())
	if together.is_valid() and together.call(a, b):
		return ""                            # talking together already
	return "still"


func _on_doorstep(p: Vector2) -> bool:
	var f: Callable = _d.get("doorstep", Callable())
	return f.call(p) if f.is_valid() else false


## A meeting begun: `name` from the catalogue, `a` in its first role.
func start(name: String, a: int, b: int, k: int) -> void:
	var entry: Dictionary = Encounters.CATALOGUE[name]
	var sit := Situation.new(name, entry, [_d.mover.call(a), _d.mover.call(b)], [_d.body.call(a), _d.body.call(b)],
		Encounters.seconds(name, k), k, _d.world)
	sit.who = [a, b]
	_met[mini(a, b) * 100003 + maxi(a, b)] = life
	if str(entry.shape) in ["pair", "crouch"]:          # they step somewhere good to talk (not on a step, not in a crowd)
		var middle := ((_d.mover.call(a) as Mover).pos + (_d.mover.call(b) as Mover).pos) * 0.5
		sit.centre = place_for("", middle, 2, null, [a, b])
		sit._meet()
	situations.append(sit)
	for id in [a, b]:
		in_sit[id] = sit
		_taken(id, false)
	_log(name, a, b)
	_seen = _seen.filter(func(s: Array) -> bool: return life - float(s[2]) < SEEN_FADE * 3.0)
	_seen.append([name, ((_d.mover.call(a) as Mover).pos + (_d.mover.call(b) as Mover).pos) * 0.5, life])


## How much of each kind of meeting was seen lately round `at`: a count, each meeting fading over SEEN_FADE (1: one
## just now). Encounters.choose holds back the kinds seen most and most lately: a crowd where the same thing happens
## twice running looks scripted; people do not.
func _fresh(at: Vector2) -> Dictionary:
	var out := {}
	for s: Array in _seen:
		if (s[1] as Vector2).distance_to(at) <= SEEN_WITHIN:
			out[s[0]] = float(out.get(s[0], 0.0)) + exp(-(life - float(s[2])) / SEEN_FADE)
	return out


## Takes `id` (at `place`'s chat) into a conversation there: the one they get on with best that has room, else a new one
## with whoever of `lone` they get on with best. False if nobody there would have them yet.
func talk(place: String, id: int, lone: Array[int]) -> bool:
	var talks: Array = _talks.get_or_add(place, [])
	var best: Situation = null
	var best_score := -INF
	for sit: Situation in talks:
		if sit.who.size() >= TALK_MOST:
			continue
		var worst := INF
		var mean := 0.0
		for other: int in sit.who:
			var both := _mutual(id, other)
			worst = minf(worst, both)
			mean += both / sit.who.size()
		if worst >= Groups.WELCOME and mean > best_score:
			best_score = mean
			best = sit
	var partner := -1
	var partner_score := -INF
	for other: int in lone:
		if other == id or in_sit.has(other):
			continue
		var both := _mutual(id, other)
		if both >= Groups.WELCOME and both > partner_score:
			partner_score = both
			partner = other
	if best != null and (partner < 0 or best_score >= partner_score - 10.0):
		_taken(id, true)
		best.centre = place_for(place, best.centre, best.who.size() + 1, best)
		best.join(_d.mover.call(id), _d.body.call(id), id, float(_d.voice.call(id)))
		in_sit[id] = best
		return true
	if partner >= 0:
		_start_talk(place, [partner, id])
		return true
	return false


func _start_talk(place: String, ids: Array) -> void:
	var movers_of: Array = []
	var bodies_of: Array = []
	var middle := Vector2.ZERO
	for id: int in ids:
		_taken(id, true)
		movers_of.append(_d.mover.call(id))
		bodies_of.append(_d.body.call(id))
		middle += (_d.mover.call(id) as Mover).pos
	middle /= float(ids.size())
	var k := hash([ids, int(life)])
	var sit := Situation.new("talk", Encounters.CATALOGUE["talk"], movers_of, bodies_of, INF, k, _d.world)
	sit.who = ids.duplicate()
	for i in ids.size():
		sit.voices[i] = float(_d.voice.call(ids[i]))
	sit.centre = place_for(place, middle, ids.size(), null)
	sit._form()
	situations.append(sit)
	(_talks.get_or_add(place, []) as Array).append(sit)
	_mingle_at[sit] = life + MINGLE_EVERY * (0.6 + 0.8 * _noise(k, 1))
	for id: int in ids:
		in_sit[id] = sit
	_log("talk", ids[0], ids[1])


## Now and then, at `place`'s chat: those on their own there (`lone`) find company; someone in a circle moves to one they
## like better (a party mingles); a circle down to one ends.
func tend(place: String, lone: Array[int]) -> void:
	for id in lone:
		if not in_sit.has(id):
			talk(place, id, lone)
	for sit: Situation in (_talks.get(place, []) as Array).duplicate():
		if sit.who.size() < 2:
			sit.cleanup()
			end(sit)
			continue
		if sit.who.size() >= 3 and life >= float(_mingle_at.get(sit, INF)) and sit.phase == "beats":
			_mingle_at[sit] = life + MINGLE_EVERY * (0.6 + 0.8 * _noise(sit.key + int(life), 2))
			_mingle(place, sit)


## The places with conversations going on (for a director that tends them all).
func places() -> Array:
	return _talks.keys()


## The one in `sit` who gets on least with the rest moves to another conversation at the place they get on with better.
func _mingle(place: String, sit: Situation) -> void:
	var who := -1
	var lowest := INF
	for id: int in sit.who:
		var mean := 0.0
		for other: int in sit.who:
			if other != id:
				mean += float(_d.affinity.call(id, other)) / (sit.who.size() - 1)
		if mean < lowest:
			lowest = mean
			who = id
	var best: Situation = null
	var best_score := lowest + MINGLE_BETTER
	for o: Situation in _talks[place]:
		if o == sit or o.who.size() >= TALK_MOST:
			continue
		var mean := 0.0
		var worst := INF
		for other: int in o.who:
			mean += float(_d.affinity.call(who, other)) / o.who.size()
			worst = minf(worst, _mutual(who, other))
		if worst >= Groups.WELCOME and mean > best_score:
			best_score = mean
			best = o
	if best == null:
		return
	sit.leave(who)
	best.centre = place_for(place, best.centre, best.who.size() + 1, best)
	best.join(_d.mover.call(who), _d.body.call(who), who, float(_d.voice.call(who)))
	in_sit[who] = best
	_log("mingle", who, best.who[0])


## A good middle for a conversation of n near `near`: every place round it good to stand on and nobody else standing
## there, clear of the place's other conversations; the nearest such to where they are.
func place_for(place: String, near: Vector2, n: int, sit: Situation, those := []) -> Vector2:
	var r := Formation.radius_for(n)
	var others: Array = _talks.get(place, [])
	var members: Array = sit.who if sit != null else those
	for ring in 7:
		var count := 1 if ring == 0 else 8
		for k in count:
			var a := TAU * k / count + ring * 0.4
			var c := near + Vector2(cos(a), sin(a)) * ring * 0.6
			var ok := true
			for o: Situation in others:
				if o != sit and o.centre != Vector2.INF and o.centre.distance_to(c) < r + Formation.radius_for(o.who.size()) + TALK_ROOM:
					ok = false
					break
			if not ok:
				continue
			var round_n := maxi(n, 3) if n > 2 else 6          # (a pair may turn any way round its middle: all of it)
			for s in round_n:
				var slot := c + Vector2.from_angle(a + TAU * s / round_n) * r
				if not _d.good.call(slot) or _d.busy.call(slot, 0.8, members):
					ok = false
					break
			if ok:
				return c
	return near


## A situation is over: its people are free again (after a rest) and go back to what they were doing.
func end(sit: Situation) -> void:
	situations.erase(sit)
	var ended: Callable = _d.get("ended", Callable())
	if ended.is_valid():
		ended.call(sit)
	for place: String in _talks:
		(_talks[place] as Array).erase(sit)
	_mingle_at.erase(sit)
	for id: int in sit.who:
		in_sit.erase(id)
		_free_at[id] = life + MEET_REST
		_d.back.call(id, true)


## `id` is wanted elsewhere (an answer to the player, a talk, an event): out of their situation. A circle of three or
## more talks on without them; anything smaller is over for all.
func leave(id: int) -> void:
	var sit: Situation = in_sit.get(id)
	if sit == null:
		return
	if sit.name == "talk" and sit.who.size() > 2:
		sit.leave(id)                        # the others close up and talk on (a while yet: nobody ends on a leaving)
		sit.seconds = maxf(sit.seconds, sit.t + THIN_LEAST * (0.6 + 0.8 * _noise(sit.key + id, 6)))
		in_sit.erase(id)
		_free_at[id] = life + MEET_REST
		_d.back.call(id, false)
		return
	sit.cleanup()
	end(sit)


## The conversations going on (a measure: motion_watch.gd groups_source): the members standing in each (one still
## walking in is not yet a talker), who is talking, its planned middle.
func groups() -> Array:
	var out: Array = []
	for sit: Situation in situations:
		if sit.shape() in ["circle", "pair", "crouch"] and sit.phase == "beats":
			var s := sit.speaker()
			var members: Array = []
			for i in sit.who.size():
				if (sit.movers[i] as Mover).at_rest():
					members.append(sit.who[i])
			out.append({"members": members, "speaker": sit.who[s] if s >= 0 else -1, "centre": sit.centre, "phase": sit.phase,
				"name": sit.name})
	return out


## The middles of the conversations going on, for the crowd to walk round (crowd.gd spaces): [centre, radius, group].
func spaces() -> Array:
	var out: Array = []
	for sit: Situation in situations:
		var s := sit.space()
		if not s.is_empty():
			out.append([s[0], s[1], sit._group()])
	return out


func _mutual(a: int, b: int) -> float:
	return minf(float(_d.affinity.call(a, b)), float(_d.affinity.call(b, a)))


func _taken(id: int, for_good: bool) -> void:
	var f: Callable = _d.get("taken", Callable())
	if f.is_valid():
		f.call(id, for_good)


func _log(name: String, a: int, b: int) -> void:
	log.append([life, name, a, b])
	if log.size() > LOG_MOST:
		log.pop_front()


static func _noise(k: int, salt: int) -> float:
	return float(posmod(hash(k * 7919 + salt * 104729), 100000)) / 100000.0
