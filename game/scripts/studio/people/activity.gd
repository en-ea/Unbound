extends RefCounted
## A stay is not a statue (Pass 3, stage 3; Hilmi: "try and get them to also not stand around as much ... so that life
## feels more natural and spontaneous"). While someone stays somewhere - at work, about the house, at prayer, waiting -
## they do what people there do, in bits of their own length: a spell of work, a step to the next bit of it, a pause to
## rest or look about, a short errand and back. Generic: it knows movers, bodies and what the director says of the
## world, not villages. A new kind of stay is a PROFILES entry.
##
##   var stay := Activity.Stay.new(kind, mover, body, anchor, world, who)
##       kind     a PROFILES entry ("farming", "about_the_house", "praying", ...; Activity.kind_for(verb, child))
##       anchor   {"at": Vector2 (their spot), "face": Vector2 (what the work faces; INF: none), "area": metres they
##                 keep within (-1: the profile's)}
##       world    {"route":   (Vector2, Vector2) -> PackedVector2Array   the way round the walls
##                 "good":    (Vector2) -> bool          a spot one can stand on (room round it, no wall, no doorstep)
##                 "open":    (Vector2, Vector2) -> bool nothing solid within OPEN_AHEAD of a spot, that way
##                 "busy":    (Vector2, float) -> bool   someone else stands (or is going to stand) that close
##                 "sights":  (Vector2) -> Array         things worth a look near a point: [[Vector2, weight], ...]
##                 "errands": (Vector2) -> Array         short errands from there: [{"at", "face", "clips", "seconds",
##                                                        "weight", "meet": Callable (called on arrival: a visit's word
##                                                        with a friend)}, ...]}  (any of them may be missing)
##       who      {"key": int, "restless": 0..1 (spells shorter, more stepping about and looking round),
##                 "sociable": 0..1 (more errands), "child": bool}
##   stay.update(dt)        each frame while they stay (the director stops calling while something else has them)
##   stay.resume()          back from a meeting or a talk: they carry on from where they are
##   stay.until             seconds the stay has left (no errand that would not be back in time)
##   stay.doing             the bit now: "work", "rest", "look", "shift", "errand", "play"
##
##     choose the next bit ── weights: the profile's, leaned on by who they are; no pause twice running
##        │
##        ├─ work    a clip of the work, for a spell drawn from a log-normal round the profile's median (people's
##        │          dwell times are long-tailed: mostly middling, now and then much longer)
##        ├─ rest    a still pose, a few seconds
##        ├─ look    turn to something worth a look (someone passing, the player, a quarrel) or away over open ground
##        ├─ shift   a step to another good spot in the area (along the row, round the yard), then work there
##        ├─ errand  a short walk to somewhere near, a bit there, and back to the area
##        └─ play    (children) a dash somewhere open, then a jump or a dance
##
## Clips are poses held in place: none with steps in it (Push walks at 0.7 m/s: standing, its feet slide).
##
## Cost: a choice every few seconds a person; a shift tries at most TRIES spots (the world's tests: a few physics
## queries).

const TRIES := 10
const SIGMA := 0.5            # the spread of a spell's length (log-normal)
const LOOK_S := 3.0           # seconds, median, of a look about
const REST_S := 4.0           # seconds, median, of a rest
const STEP := Vector2(1.0, 2.8)   # metres of a step to the next spot, least and most
const DASH := Vector2(3.0, 6.5)   # metres of a child's dash
const KEEP_APART := 1.2       # metres from anyone else's spot (two bodies and the room a walker keeps from someone
                              # standing: any nearer and the crowd's push holds them short of it)
const OPEN_AHEAD := 0.9       # metres clear in front of a spot they work facing
const ERRAND_SPARE := 12.0    # seconds an errand must leave over before the stay ends
const ERRAND_FAR := 22.0      # metres: no errand further than this
const SIGHT_TURN := 0.6       # radians: a sight nearer than this to where they face needs no turn (the head will do it)

const PROFILES := {
	"farming": {"work": ["Farm_Harvest", "Farm_PlantSeed", "Farm_Harvest"], "work_s": 8.5, "rest": ["Idle", "Idle_FoldArms"],
		"area": 5.0, "w": {"work": 5.0, "shift": 3.0, "rest": 0.8, "look": 1.0}},
	"gathering": {"work": ["Farm_PlantSeed", "Farm_Harvest", "Crouch_Idle"], "work_s": 8.0, "rest": ["Idle"], "area": 6.0,
		"w": {"work": 5.0, "shift": 3.5, "rest": 0.6, "look": 1.0}},
	"woodcutting": {"work": ["TreeChopping"], "work_s": 8.5, "rest": ["Idle", "Idle_FoldArms"], "area": 3.5,
		"w": {"work": 6.0, "shift": 1.5, "rest": 1.5, "look": 0.8}},
	"smithing": {"work": ["TreeChopping", "Interact", "TreeChopping"], "work_s": 8.0, "rest": ["Idle_FoldArms"], "area": 1.6,
		"w": {"work": 6.0, "shift": 1.5, "rest": 1.0, "look": 1.0}},
	"milling": {"work": ["Fixing_Kneeling", "Interact", "Farm_Harvest"], "work_s": 8.0, "rest": ["Idle"], "area": 3.0,
		"w": {"work": 5.0, "shift": 2.5, "rest": 1.0, "look": 1.0}},
	"hunting": {"work": ["Crouch_Idle", "Idle_FoldArms"], "work_s": 7.0, "rest": ["Idle"], "area": 6.0,
		"w": {"work": 3.0, "shift": 3.0, "rest": 0.5, "look": 2.0}},
	"herding": {"work": ["Idle_FoldArms", "Idle_Rail_Call", "Idle"], "work_s": 6.0, "rest": ["Idle"], "area": 7.0,
		"w": {"work": 3.0, "shift": 3.0, "rest": 0.5, "look": 2.0}},
	"fetching_water": {"work": ["Farm_Watering", "Interact"], "work_s": 6.0, "rest": ["Idle"], "area": 1.5,
		"w": {"work": 5.0, "shift": 1.0, "rest": 0.8, "look": 1.5}},
	"praying": {"work": ["Spell_Simple_Idle", "Crouch_Idle", "Spell_Simple_Idle"], "work_s": 8.5, "rest": ["Idle"],
		"rest_s": 4.0, "area": 0.0, "w": {"work": 8.0, "rest": 1.2, "look": 0.4}},
	"trading": {"work": ["Idle_Talking", "Interact", "Yes", "Idle_FoldArms"], "work_s": 5.0, "rest": ["Idle"], "area": 1.4,
		"w": {"work": 5.0, "shift": 1.0, "rest": 0.6, "look": 3.0}},
	"eating": {"work": ["Consume"], "work_s": 8.0, "rest": ["Idle"], "area": 0.6, "w": {"work": 6.0, "rest": 2.0, "look": 1.5}},
	"about_the_house": {"work": ["Farm_Watering", "Fixing_Kneeling", "Interact", "Farm_PlantSeed"], "work_s": 8.0,
		"rest": ["Idle", "Idle_FoldArms"], "area": 5.0, "w": {"work": 5.0, "shift": 3.0, "rest": 0.6, "look": 1.0, "errand": 0.7}},
	"visiting": {"work": ["Idle_Rail_Call", "Idle_FoldArms", "Idle_Talking", "Yes"], "work_s": 5.0, "rest": ["Idle"], "area": 1.5,
		"w": {"work": 4.0, "shift": 0.8, "rest": 1.0, "look": 2.0}},
	"loitering": {"work": ["Idle_FoldArms", "Idle_Talking", "Idle"], "work_s": 6.0, "rest": ["Idle"], "area": 4.0,
		"w": {"work": 2.0, "shift": 3.0, "rest": 0.6, "look": 3.0, "errand": 1.0}},
	"waiting": {"work": ["Idle_FoldArms", "Idle"], "work_s": 5.0, "rest": ["Idle"], "area": 1.0,
		"w": {"work": 2.0, "shift": 0.6, "rest": 0.6, "look": 4.0}},
	"child_about": {"work": ["Farm_PlantSeed", "Crouch_Idle", "Dance", "Jump", "OverhandThrow"], "work_s": 4.0,
		"rest": ["Idle"], "area": 7.0, "dash": true, "w": {"work": 4.0, "shift": 2.0, "play": 3.0, "look": 0.6, "errand": 0.9}},
}
## What a day's verb (sim/view.gd activity) is as a stay.
const KINDS := {"farming": "farming", "gathering": "gathering", "woodcutting": "woodcutting", "smithing": "smithing",
	"milling": "milling", "hunting": "hunting", "herding": "herding", "fetching_water": "fetching_water",
	"praying": "praying", "trading": "trading", "eating": "eating", "at_home": "about_the_house", "visiting": "visiting",
	"loitering": "loitering", "idle": "loitering", "chatting": "waiting", "hiding": "hunting"}
const PLAY := ["Jump", "Dance", "Jump", "OverhandThrow"]


## The kind of stay for a verb ("" none: they do not stay, or something else runs it).
static func kind_for(verb: String, child: bool) -> String:
	var kind: String = KINDS.get(verb, "")
	if child and kind in ["about_the_house", "loitering", "visiting", "gathering", "waiting"]:
		return "child_about"
	return kind


## A spell's length: log-normal round `median`, keyed (Box-Muller from two keyed numbers), cut at 0.4 and 1.6 times it (a
## longer bout of the same loop reads as a machine: people break off, step along, change hands).
static func spell(median: float, k: int) -> float:
	return Stay.spell(median, k)


static func first_spell(work_s: float, key: int) -> float:
	return Stay.first_spell(work_s, key)


## Picks a key of `w` (name -> weight) by a number u in [0, 1). "" if all weights are 0.
static func pick(w: Dictionary, u: float) -> String:
	return Stay.pick(w, u)


static func noise(k: int, salt: int) -> float:
	return Stay.noise(k, salt)


class Stay:
	var kind := ""
	var profile: Dictionary
	var mover: RefCounted         # people/mover.gd
	var body: Node3D
	var anchor := Vector2.ZERO
	var face := Vector2.INF
	var area := 0.0
	var world: Dictionary
	var key := 0
	var restless := 0.5
	var sociable := 0.5
	var child := false
	var until := INF
	var doing := ""
	var clip := ""
	var bits := 0                 # bits so far (keys every choice)
	var errands := 0
	var _steps: Array = []        # what is left of the bit: ["go", to (INF: back to the area), style] or
	                              # ["do", clip, seconds, face (INF: as they are)]
	var _left := 0.0              # seconds left of a "do"
	var _going := false           # the step under way is a "go"

	func _init(the_kind: String, the_mover: RefCounted, the_body: Node3D, the_anchor: Dictionary, the_world: Dictionary,
			who: Dictionary) -> void:
		kind = the_kind
		profile = PROFILES.get(kind, PROFILES["waiting"])
		mover = the_mover
		body = the_body
		anchor = the_anchor.get("at", the_mover.pos)
		face = the_anchor.get("face", Vector2.INF)
		var a := float(the_anchor.get("area", -1.0))
		area = a if a >= 0.0 else float(profile.get("area", 1.0))
		world = the_world
		key = int(who.get("key", 0))
		restless = float(who.get("restless", 0.5))
		sociable = float(who.get("sociable", 0.5))
		child = bool(who.get("child", false))
		bits = int(noise(key, 21) * 1000.0)     # each person starts at their own place in their own sequence
		doing = "work"
		_steps = [["do", _work_clip(), first_spell(float(profile.work_s), key), face]]
		_start(true)

	func update(dt: float) -> void:
		until -= dt
		if _going:
			if not mover.at_rest():
				return                           # (still slowing: the pose waits for them to stop)
			_going = false
			_steps.pop_front()
			_start()
			return
		if clip != "" and mover.at_rest() and is_instance_valid(body) and body.has_method("holding") and not body.holding():
			var again := clip                    # a nudge or a step aside broke the pose: back to what they were doing
			clip = ""
			_play(again)
		_left -= dt
		if _left > 0.0:
			return
		if not _steps.is_empty():
			_steps.pop_front()
		_start()

	## Back from something else (a meeting, a talk): carry on from where they are (back to their area first if led off).
	func resume() -> void:
		_going = false
		clip = ""
		_steps.clear()
		if mover.pos.distance_to(anchor) > area + 1.0:
			doing = "shift"
			_steps = [["go", Vector2.INF, "walk"], ["do", _work_clip(), spell(float(profile.work_s), key + bits), face]]
		_start()

	## Begins the step at the front (planning the next bit when there is none).
	func _start(first := false) -> void:
		for guard in 4:
			if _steps.is_empty():
				_next()
			var step: Array = _steps[0]
			if step[0] == "do":
				if step.size() > 4 and (step[4] as Callable).is_valid():
					(step[4] as Callable).call()     # (the director may take the mover now: a meeting)
				_play(str(step[1]), first)
				var at: Vector2 = step[3]
				if at != Vector2.INF:
					var facing := Vector2(sin(mover.yaw), cos(mover.yaw))
					if doing != "look" or absf(facing.angle_to(at - mover.pos)) > SIGHT_TURN:
						mover.face(at)
				_left = float(step[2])
				return
			var to: Vector2 = step[1]
			if to == Vector2.INF:
				to = _spot_near(true)
			if to != Vector2.INF and to.distance_to(mover.pos) >= 0.3:
				var route: Callable = world.get("route", Callable())
				mover.face_at = Vector2.INF          # (what they faced here is not what they face there)
				mover.go(route.call(mover.pos, to) if route.is_valid() else PackedVector2Array([to]), INF, str(step[2]))
				if mover.walking():
					_going = true
					return
			_steps.pop_front()                   # nowhere better to go: carry on here
		_steps = [["do", "Idle", 2.0, Vector2.INF]]
		_play("Idle")
		_left = 2.0

	## Plans the next bit.
	func _next() -> void:
		bits += 1
		var k := key * 1009 + bits
		var w: Dictionary = (profile.w as Dictionary).duplicate()
		w["shift"] = float(w.get("shift", 0.0)) * (0.6 + 0.8 * restless) * (1.0 if area > 0.3 else 0.0)
		w["look"] = float(w.get("look", 0.0)) * (0.6 + 0.8 * restless)
		w["errand"] = float(w.get("errand", 0.0)) * (0.4 + 1.2 * sociable) * (1.0 if until > 40.0 else 0.0) / (1.0 + errands)
		w["work"] = float(w.get("work", 0.0)) * (1.3 - 0.6 * restless)
		if doing in ["rest", "look"]:
			w["rest"] = 0.0                      # no pause after a pause
			w["look"] = float(w.get("look", 0.0)) * 0.3
		elif doing in ["shift", "play"]:
			w["shift"] = float(w.get("shift", 0.0)) * 0.3
		var was := doing
		var work := ["do", _work_clip(), spell(float(profile.work_s), k), face]
		doing = pick(w, noise(k, 1))
		match doing:
			"rest":
				var rest: Array = profile.get("rest", ["Idle"])
				_steps = [["do", rest[int(noise(k, 2) * rest.size()) % rest.size()], spell(float(profile.get("rest_s", REST_S)), k), Vector2.INF]]
			"look":
				_steps = [["do", "Idle", spell(LOOK_S, k), _sight(k)]]
			"shift":
				var to := _spot_near(false)
				_steps = [["go", to, "stroll" if not child else "walk"], work] if to != Vector2.INF else [work]
			"play":
				var to := _dash_to(k)
				if to != Vector2.INF:
					_steps = [["go", to, "jog"], ["do", PLAY[int(noise(k, 7) * PLAY.size()) % PLAY.size()], spell(3.0, k), Vector2.INF]]
				else:
					_steps = [work]
			"errand":
				var e := _errand(k)
				if e.is_empty():
					_steps = [work]
				else:
					errands += 1
					var clips: Array = e.get("clips", ["Idle"])
					_steps = [["go", e.at, "walk"],
						["do", clips[int(noise(k, 9) * clips.size()) % clips.size()], spell(float(e.get("seconds", 6.0)), k), e.get("face", Vector2.INF),
							e.get("meet", Callable())],
						["go", Vector2.INF, "walk"], work]
			_:
				doing = "work"
				_steps = [work]
				if was == "work" and str(work[1]) == clip:      # the same loop again: a breath between the bouts
					var rest: Array = profile.get("rest", ["Idle"])
					_steps.push_front(["do", rest[int(noise(k, 13) * rest.size()) % rest.size()], spell(1.6, k), Vector2.INF])

	## A clip of the work: another than the one playing, if the work has another.
	func _work_clip() -> String:
		var work: Array = profile.work
		var pick_at := int(noise(key * 1009 + bits, 3) * work.size()) % work.size()
		for t in work.size():
			var c: String = work[(pick_at + t) % work.size()]
			if c != clip:
				return c
		return work[pick_at]

	## Something worth a look (weighted by the world), else a point away over open ground.
	func _sight(k: int) -> Vector2:
		var sights: Callable = world.get("sights", Callable())
		if sights.is_valid():
			var list: Array = sights.call(mover.pos)
			var w := {}
			for i in list.size():
				w[str(i)] = float(list[i][1])
			var chosen := pick(w, noise(k, 4))
			if chosen != "":
				return list[int(chosen)][0]
		for t in 4:
			var a := TAU * noise(k, 5 + t)
			var dir := Vector2(sin(a), cos(a))
			if _open(mover.pos, dir):
				return mover.pos + dir * 6.0
		return Vector2.INF

	## Somewhere open for a child's dash.
	func _dash_to(k: int) -> Vector2:
		for t in TRIES:
			var a := TAU * noise(k, 30 + t)
			var c: Vector2 = mover.pos + Vector2(cos(a), sin(a)) * lerpf(DASH.x, DASH.y, noise(k, 50 + t))
			if c.distance_to(anchor) > area:
				c = anchor + (c - anchor).limit_length(area)
			if c.distance_to(mover.pos) > 1.5 and _good(c) and not _busy(c) and _open(c, c - mover.pos):
				return c                         # (they stop facing the way they ran: room in front)
		return Vector2.INF

	## An errand that fits the time left, the nearer the likelier ({} none).
	func _errand(k: int) -> Dictionary:
		var list_of: Callable = world.get("errands", Callable())
		if not list_of.is_valid():
			return {}
		var list: Array = list_of.call(mover.pos)
		var w := {}
		var pace := maxf(float(mover.m.pace), 0.8)
		for i in list.size():
			var e: Dictionary = list[i]
			var far: float = mover.pos.distance_to(e.at)
			var takes: float = 2.0 * far / pace + float(e.get("seconds", 6.0)) + ERRAND_SPARE
			if far < 2.0 or far > ERRAND_FAR or takes > until:
				continue
			w[str(i)] = float(e.get("weight", 1.0)) / (1.0 + far / 8.0)
		var chosen := pick(w, noise(k, 8))
		return list[int(chosen)] if chosen != "" else {}

	## The best spot for a step: within the area, standable, nobody's, with room in front of the work. `home`: anywhere
	## in the area near the anchor (back from somewhere).
	func _spot_near(home: bool) -> Vector2:
		var best := Vector2.INF
		var best_cost := INF
		var from: Vector2 = mover.pos if not home else anchor
		for t in TRIES:
			var k := key * 1009 + bits * 17 + t
			var a := TAU * noise(k, 40)
			var r := lerpf(STEP.x, STEP.y, noise(k, 41)) if not home else minf(area, 1.5) * sqrt(noise(k, 41))
			var c := from + Vector2(cos(a), sin(a)) * r
			if c.distance_to(anchor) > area:
				c = anchor + (c - anchor).limit_length(area)
			if not home and c.distance_to(mover.pos) < STEP.x * 0.7:
				continue
			if not _good(c) or _busy(c):
				continue
			if not _open(c, (face - c) if face != Vector2.INF else (c - mover.pos)):
				continue                         # room in front of the work (or, facing as they walked, ahead)
			var cost := c.distance_to(anchor) * 0.3
			if not home:
				cost += absf(c.distance_to(mover.pos) - (STEP.x + STEP.y) * 0.5)
			if cost < best_cost:
				best_cost = cost
				best = c
		if home and best == Vector2.INF and _good(anchor) and not _busy(anchor):
			best = anchor
		return best

	func _play(name: String, first := false) -> void:
		if name == clip:
			return
		clip = name
		if is_instance_valid(body) and body.has_method("play_loop"):
			body.play_loop(name, 0.3, 0.9 + 0.2 * noise(key, 60 + bits % 7), noise(key, 61 + bits % 5) * 3.0 if first else 0.0)

	func _good(p: Vector2) -> bool:
		var f: Callable = world.get("good", Callable())
		return f.call(p) if f.is_valid() else true

	func _open(p: Vector2, dir: Vector2) -> bool:
		var f: Callable = world.get("open", Callable())
		return f.call(p, dir) if f.is_valid() else true

	func _busy(p: Vector2) -> bool:
		var f: Callable = world.get("busy", Callable())
		return f.call(p, KEEP_APART) if f.is_valid() else false

	## (see the outer spell)
	static func spell(median: float, k: int) -> float:
		var u1 := maxf(noise(k, 11), 0.0001)
		var u2 := noise(k, 12)
		var z := sqrt(-2.0 * log(u1)) * cos(TAU * u2)
		return clampf(median * exp(SIGMA * z), median * 0.4, median * 1.6)

	## The first spell of a stay: found part-way through an ordinary one (a random part of it, keyed by who they are), as
	## anyone is when the scene opens on them. Stays that all begin at once (the clock jumped: a load, a night's sleep)
	## then change at their own moments, not all in the first few seconds.
	static func first_spell(work_s: float, key: int) -> float:
		return spell(work_s, key * 31 + 7) * maxf(noise(key, 23), 0.05)


	## Picks a key of `w` (name -> weight) by a number u in [0, 1). "" if all weights are 0.
	static func pick(w: Dictionary, u: float) -> String:
		var total := 0.0
		for k: String in w:
			total += maxf(float(w[k]), 0.0)
		if total <= 0.0:
			return ""
		var at := u * total
		var last := ""
		for k: String in w:
			var wk := maxf(float(w[k]), 0.0)
			if wk <= 0.0:
				continue
			last = k
			at -= wk
			if at <= 0.0:
				return k
		return last


	static func noise(k: int, salt: int) -> float:
		return float(posmod(hash(k * 7919 + salt * 104729), 100000)) / 100000.0
