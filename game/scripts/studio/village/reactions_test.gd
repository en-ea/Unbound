extends RefCounted
## Headless tests for reactions as modules (plan LIVELY-VILLAGE 3.1-3.4): the registry, every module against every cue
## it answers on real people, the proof that a reaction is one new file and nothing else, a crowd breaking up at its own
## pace, the rules' aftermath settled once. Pure, a second or two:
##   godot --headless --path game --script res://scripts/studio/run.gd -- village/reactions_test
const Registry := preload("res://scripts/studio/village/reaction_registry.gd")
const Reacting := preload("res://scripts/studio/people/reacting.gd")
const Facts := preload("res://scripts/studio/village/reaction_facts.gd")
const Aftermath := preload("res://scripts/studio/village/sim/aftermath.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")

const KINDS := ["end:public:pillory:released", "end:public:stocks:released", "end:public:hanging:died",
	"end:public:burning:died", "end:public:exile:exiled", "end:public:pillory:rescued", "end:rite:offering:spared",
	"end:hearing:trial:guilty", "end:hearing:trial:acquitted", "end:happening:argument:parted", "parting", "enemy:wolf",
	"enemy:bandit", "alarm", "kill:stag", "kill:wolf", "carcass:stag", "beast:boar", "freed:public:pillory:released", "seeoff"]
const STEPS := {"face": 2, "clip": 2, "loop": 3, "nod": 1, "wave": 1, "say": 2, "wait": 2, "go": 3, "near": 4, "follow": 3,
	"back": 3, "knot": 2, "home": 1, "do": 2}
const TARGETS := ["subject", "other", "place", "player", "home", "enemy", "node", "away"]
const PROOF := "res://scripts/studio/village/reactions/_proof_wave_back.gd"
const DT := 0.1


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	out.append(_registry_finds_all())
	out.append(_every_module_every_cue())
	out.append(_one_file_is_enough())
	out.append(_crowd_breaks_up())
	out.append(_aftermath_once())
	out.append(_enemy_interrupts())
	return out


static func _check(ok: bool, what: String) -> String:
	return ("PASS " if ok else "FAIL ") + what


## The folder is the list: every script in it is found, each answers something.
static func _registry_finds_all() -> String:
	var files := 0
	for f: String in ResourceLoader.list_directory(Registry.REACTIONS):
		if f.trim_suffix(".remap").ends_with(".gd") and not f.begins_with("_proof_"):
			files += 1
	var reg := Registry.new(Registry.REACTIONS)
	var cues := Registry.new(Registry.CUES)
	var silent: Array = []
	for m: Script in reg.modules:
		if (Registry.constant(m, "ANSWERS", []) as Array).is_empty():
			silent.append(reg.name_of(m))
	return _check(reg.modules.size() == files and files >= 20 and cues.modules.size() >= 2 and silent.is_empty(),
		"registry: %d reaction files, %d found, %d cue sources, answering nothing: %s" % [files, reg.modules.size(),
		cues.modules.size(), silent])


## Every module, for every cue kind it answers, on 40 real people: a weight, a delay, a time limit, and steps the
## performer knows with targets the director knows. And every cue kind is taken up by someone.
static func _every_module_every_cue() -> String:
	var v = Runtime.create(3)
	Runtime.advance(v, int(v.runtime.now) + 600)
	var reg := Registry.new(Registry.REACTIONS)
	var ids := _present(v, 40)
	var subject: int = ids[0]
	var problems: Array = []
	var unanswered: Array = []
	var tried := 0
	for kind: String in KINDS:
		var c := {"kind": kind, "subject": subject, "subject_name": v.people[subject].name, "other": ids[1], "place": Vector2.ZERO,
			"who": ids, "key": hash(kind), "event": -1, "outcome": kind.get_slice(":", 3), "alive": not kind.ends_with("died")}
		var taken := false
		for m: Script in reg.answering(kind):
			for id: int in ids.slice(1):
				var me := Facts.of(v, id, c, Vector2(3.0, 0.0))
				var w := float(m.call("weight", c, me))
				tried += 1
				if is_nan(w) or w < 0.0:
					problems.append("%s weight %s" % [reg.name_of(m), w])
					continue
				if w <= 0.0:
					continue
				taken = true
				var d := float(m.call("delay", c, me))
				var l := float(m.call("lasts", c, me))
				if is_nan(d) or d < 0.0 or d > 60.0 or l <= 0.0:
					problems.append("%s delay %s lasts %s" % [reg.name_of(m), d, l])
				for s: Array in m.call("steps", c, me):
					var why := _bad_step(s)
					if why != "":
						problems.append("%s %s: %s" % [reg.name_of(m), s, why])
		if not taken:
			unanswered.append(kind)
	return _check(problems.is_empty() and unanswered.is_empty() and tried > 1000,
		"every module x every cue on real people: %d tried, problems %s, cues nobody takes up %s" % [tried,
		problems.slice(0, 4), unanswered])


static func _bad_step(s: Array) -> String:
	if s.is_empty() or not STEPS.has(str(s[0])):
		return "unknown step"
	if s.size() < int(STEPS[str(s[0])]):
		return "too short"
	if str(s[0]) in ["face", "go", "near", "follow", "back"]:
		var t: Variant = s[1]
		if not (t is int or t is Vector2 or str(t) in TARGETS):
			return "unknown target"
	return ""


## The proof (plan 3.1): a reaction added as one new file - written here, never in stage.gd, residents.gd or the runner -
## is found, offered its cue and played on people by the same director the village uses; gone with its file.
static func _one_file_is_enough() -> String:
	var path := ProjectSettings.globalize_path(PROOF)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return _check(false, "proof: could not write %s" % PROOF)
	f.store_string("extends \"res://scripts/studio/village/reaction.gd\"\nconst ANSWERS := [\"end:proof:\"]\n\n\n"
		+ "static func weight(_cue: Dictionary, _me: Dictionary) -> float:\n\treturn 5.0\n\n\n"
		+ "static func steps(_cue: Dictionary, _me: Dictionary) -> Array:\n\treturn [[\"wave\"], [\"say\", \"proof\"], [\"go\", \"away\", \"walk\"]]\n")
	f.close()
	var with_it := Registry.new(Registry.REACTIONS, true)
	var without := Registry.new(Registry.REACTIONS)
	var found := with_it.by_name("_proof_wave_back") != null and without.by_name("_proof_wave_back") == null
	var offered := with_it.answering("end:proof:x:y").has(with_it.by_name("_proof_wave_back")) \
		and not with_it.answering("end:public:pillory:released").has(with_it.by_name("_proof_wave_back"))
	var v = Runtime.create(3)
	var ids := _present(v, 6)
	var stage := Square.new(v, ids)
	var r := Reacting.new(with_it, stage.director())
	r.cue({"kind": "end:proof:x:y", "subject": -1, "place": Vector2.ZERO, "who": ids}, ids)
	stage.run(r, 40.0)
	DirAccess.remove_absolute(path)
	var played := 0
	for t: Array in r.trace:
		played += 1 if str(t[2]) == "_proof_wave_back" else 0
	var said := stage.said.filter(func(x: Array) -> bool: return x[1] == "proof").size()
	var gone := not FileAccess.file_exists(path) and Registry.new(Registry.REACTIONS, true).by_name("_proof_wave_back") == null
	return _check(found and offered and played == ids.size() and said == ids.size() and stage.released.size() == ids.size() and gone,
		"proof: one new file found %s, offered %s, played on %d of %d, said %d, back to their day %d, removed %s" % [found,
		offered, played, ids.size(), said, stage.released.size(), gone])


## A pillory let go: 20 people turn, each at their own moment, choose among what they would do, and leave at their own
## pace - spread, irregular, never all at once (the plan's end gates, on the director alone: section 2.1).
static func _crowd_breaks_up() -> String:
	var v = Runtime.create(3)
	Runtime.advance(v, int(v.runtime.now) + 600)
	var ids := _present(v, 21)
	var subject: int = ids.pop_front()
	var stage := Square.new(v, ids)
	var r := Reacting.new(Registry.new(Registry.REACTIONS), stage.director())
	r.cue({"kind": "end:public:pillory:released", "subject": subject, "subject_name": v.people[subject].name, "other": -1,
		"place": Vector2.ZERO, "who": ids, "event": -1, "outcome": "released", "alive": true}, ids)
	stage.run(r, 120.0)
	var stirs: Array = []                 # each one's first step or act
	var lefts: Array = []                 # each one's leaving: beyond the ring (4 m) + 6 m, or back to their day
	var back := {}
	for x: Array in stage.released:
		back[int(x[0])] = float(x[1])
	for id: int in ids:
		var m: FakeMover = stage.movers[id]
		var b: FakeBody = stage.bodies[id]
		stirs.append(minf(m.first_walk if m.first_walk >= 0.0 else INF, b.first_act if b.first_act >= 0.0 else INF))
		lefts.append([minf(m.left_at if m.left_at >= 0.0 else INF, float(back.get(id, INF))), int(v.people[id].household)])
	stirs.sort()
	lefts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var stir_median: float = stirs[stirs.size() / 2]
	var spread: float = stirs[int(stirs.size() * 0.9) - 1] - stirs[int(stirs.size() * 0.1)]
	var units: Array = []                 # a household leaving together counts once (life_watch.gd's units: plan 3.0)
	var gone_n := 0
	for x: Array in lefts:
		if float(x[0]) == INF:
			continue
		gone_n += 1
		if not units.any(func(u: Array) -> bool: return int(u[1]) == int(x[1]) and float(x[0]) - float(u[0]) <= 3.0):
			units.append(x)
	var left: Array = units.map(func(u: Array) -> float: return float(u[0]))
	var worst := 0
	for i in left.size():
		var n := 0
		for j in range(i, left.size()):
			if float(left[j]) - float(left[i]) <= 2.0:
				n += 1
		worst = maxi(worst, n)
	var gaps: Array = []
	for i in range(1, left.size()):
		gaps.append(float(left[i]) - float(left[i - 1]))
	var cv := _cv(gaps)
	var last_after: float = float(left.back()) - float(left.front()) if not left.is_empty() else 0.0
	var kinds := {}
	for t: Array in r.trace:
		kinds[str(t[2])] = true
	var exodus := maxi(3, int(ceil(ids.size() * 0.2)))
	return _check(gone_n == ids.size() and stir_median <= 5.0 and spread >= 3.0 and worst <= exodus and cv >= 0.5
		and last_after >= 45.0 and kinds.size() >= 4,
		"a pillory let go, 20 people: first stir median %.1f s (<= 5), first moves spread %.1f s (>= 3); %d left in %d units, most within 2 s %d (<= %d), gap CV %.2f (>= 0.5), the last %.0f s after the first (>= 45); %d kinds %s"
		% [stir_median, spread, gone_n, left.size(), worst, exodus, cv, last_after, kinds.size(), kinds.keys()])


## The rules' side, once: at a resolve, each module with a decide is asked; its cast and effects land once, keyed.
static func _aftermath_once() -> String:
	var v = Runtime.create(3)
	Runtime.advance(v, int(v.runtime.now) + 600)
	var ids := _present(v, 40)
	var victim: int = ids[0]              # with none of their kin there, so a friend is the one who goes to them
	ids = ids.filter(func(o: int) -> bool: return o == victim or not Village.is_kin(v, o, victim)).slice(0, 12)
	var friend: int = ids[1]
	var enemy: int = ids[2]
	v.people[enemy].traits[C.TEMPER] = 80   # (a temper that jeers)
	Village.set_opinion(v, friend, victim, 70)
	Village.set_opinion(v, enemy, victim, -70)
	var e := {"id": 990001, "type": "public", "victim": victim, "outcome": "released", "phase": "resolved"}
	v.stagings.append({"id": 990001, "kind": "pillory", "people": ids.map(func(i: int) -> Dictionary: return {"id": i}),
		"roles": {}})
	var before := Village.opinion(v, victim, enemy)
	Aftermath.settle(v, e)
	var once := Village.opinion(v, victim, enemy)
	Aftermath.settle(v, e)
	var twice := Village.opinion(v, victim, enemy)
	var cast := Aftermath.cast_of(v, {"event": 990001})
	return _check(cast.get(friend, "") == "go_to_them" and cast.get(enemy, "") == "jeer" and once < before and twice == once,
		"aftermath: the friend cast %s, the enemy cast %s, the victim's feeling for the one who jeered %d -> %d, again %d (once)"
		% [cast.get(friend, "-"), cast.get(enemy, "-"), before, once, twice])


## An enemy in the village is urgent: it takes people already answering an end (a new end does not).
static func _enemy_interrupts() -> String:
	var v = Runtime.create(3)
	Runtime.advance(v, int(v.runtime.now) + 600)
	var ids := _present(v, 8)
	var stage := Square.new(v, ids)
	var r := Reacting.new(Registry.new(Registry.REACTIONS), stage.director())
	r.cue({"kind": "end:public:stocks:released", "subject": -1, "place": Vector2.ZERO, "who": ids, "outcome": "released"}, ids)
	stage.run(r, 3.0)
	r.cue({"kind": "end:public:pillory:released", "subject": -1, "place": Vector2.ZERO, "who": ids}, ids)
	var kept := 0
	for id: int in ids:
		kept += 1 if r._people.has(id) and str(r._people[id].cue.kind).contains("stocks") else 0
	r.cue({"kind": "enemy:wolf", "subject": -1, "place": Vector2(6.0, 0.0), "who": ids, "node": null}, ids)
	stage.run(r, 1.0)
	var taken := 0
	for id: int in ids:
		taken += 1 if r._people.has(id) and str(r._people[id].cue.kind).begins_with("enemy") else 0
	return _check(kept == ids.size() and taken == ids.size(),
		"urgency: a second end left %d of %d to the first; the wolf took %d of %d" % [kept, ids.size(), taken, ids.size()])


static func _present(v, n: int) -> Array:
	var out: Array = []
	for p in v.people:
		if p.alive and p.present and p.authored == "":
			out.append(int(p.id))
	return out.slice(0, n)


static func _cv(xs: Array) -> float:
	if xs.size() < 2:
		return 0.0
	var mean := 0.0
	for x: float in xs:
		mean += x
	mean /= xs.size()
	var sd := 0.0
	for x: float in xs:
		sd += (x - mean) * (x - mean)
	sd = sqrt(sd / xs.size())
	return sd / mean if mean > 0.0 else 0.0


## A stand-in for the village: movers that walk their paths, bodies that only count, and the director's answers.
class Square:
	extends RefCounted
	var v
	var movers := {}
	var bodies := {}
	var held := {}
	var released: Array = []
	var said: Array = []
	var t := 0.0

	func _init(the_v, ids: Array) -> void:
		v = the_v
		for i in ids.size():
			var a := TAU * float(i) / float(ids.size())
			var m := FakeMover.new()
			m.pos = Vector2(cos(a), sin(a)) * 4.0
			movers[ids[i]] = m
			bodies[ids[i]] = FakeBody.new()

	func director() -> Dictionary:
		return {"mover": func(id: int) -> RefCounted: return movers[id], "body": func(id: int) -> RefCounted: return bodies[id],
			"claim": claim, "holds": holds, "release": release, "facts": facts, "cast": func(_c: Dictionary) -> Dictionary: return {},
			"at": at, "route": func(_a: Vector2, b: Vector2) -> PackedVector2Array: return PackedVector2Array([b]),
			"standable": func(_p: Vector2) -> bool: return true, "say": say,
			"murmur": func(_id: int, _g: int, _s: float) -> void: pass, "clock": func() -> float: return t}

	func claim(id: int, by: String, _p: int, _k: bool) -> bool:
		held[id] = by
		return true

	func holds(id: int, by: String) -> bool:
		return held.get(id, "") == by

	func release(id: int, by: String) -> void:
		if held.get(id, "") == by:
			held.erase(id)
			released.append([id, t])

	func facts(id: int, c: Dictionary) -> Dictionary:
		return Facts.of(v, id, c, movers[id].pos)

	func say(id: int, text: String) -> void:
		said.append([id, text])
		bodies[id]._act()                 # (a line said is a visible act of their own)

	func at(target: Variant, id: int, c: Dictionary) -> Vector2:
		if target is Vector2:
			return target
		match str(target):
			"place", "subject", "other", "enemy", "node":
				return c.get("place", Vector2.ZERO)
			"player":
				return Vector2(0.0, 8.0)
			"home":
				return Vector2(30.0, float(id % 7) * 4.0)
			"away":
				var m: FakeMover = movers[id]
				return m.pos + (m.pos - c.get("place", Vector2.ZERO)).normalized() * 8.0
		return movers[int(target)].pos if target is int and movers.has(int(target)) else Vector2.INF

	func run(r: Reacting, seconds: float) -> void:
		var end := t + seconds
		while t < end:
			t += DT
			for id: int in movers:
				bodies[id].now = t
			r._process(DT)
			for id: int in movers:
				movers[id].step(DT, t)


class FakeMover:
	extends RefCounted
	var pos := Vector2.ZERO
	var path := PackedVector2Array()
	var arrived := true
	var face_at := Vector2.INF
	var backing := false
	var enters := false
	var indoors := false
	var first_walk := -1.0
	var left_at := -1.0

	func go(way: PackedVector2Array, _s := INF, _how := "", _d := 0.0) -> void:
		path = way
		arrived = way.is_empty()
		enters = false

	func hold(at: Vector2, face := Vector2.INF) -> void:
		path = PackedVector2Array()
		arrived = true
		face_at = face
		indoors = false

	func face(at: Vector2) -> void:
		face_at = at

	func walking() -> bool:
		return not arrived

	func step(dt: float, now: float) -> void:
		if left_at < 0.0 and pos.length() > 10.0:
			left_at = now
		if path.is_empty():
			return
		if first_walk < 0.0 and pos.distance_to(path[0]) > 0.3:
			first_walk = now
		var to := path[0] - pos
		if to.length() <= 1.3 * dt:
			pos = path[0]
			path.remove_at(0)
			if path.is_empty():
				arrived = true
				indoors = enters
		else:
			pos += to.normalized() * 1.3 * dt


class FakeBody:
	extends RefCounted
	var acts := 0
	var now := 0.0
	var first_act := -1.0

	func _act() -> void:
		acts += 1
		if first_act < 0.0:
			first_act = now

	func play_action(_n: String, _s := 1.0) -> void:
		_act()

	func play_loop(_n: String, _b := 0.25, _s := 1.0, _st := 0.0) -> void:
		_act()

	func nod() -> void:
		_act()

	func wave() -> void:
		_act()

	func animation_length(_n: String) -> float:
		return 1.2
