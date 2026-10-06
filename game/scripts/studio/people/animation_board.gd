extends Node
## Hidden filmstrips of bodies absorbing force (B5/B6/B8; animation specialist's look tool, never in play).
## A row of bodies, each one moment of a beat, captured in one frame: column k began its beat `offset` seconds before
## the capture, so a row reads left to right as time (or as variations of one moment).
##
##   --studio=people/animation_board --board=<row> --shot=<png> --shotframe=999999 --hide=HUD --at=-32,45 --time=0.45
##        --test-save=animation-board      (the HUD off, an open spot, late morning, never the real save)
##   rows: impact | fall | fire | aftermath | limp | death | carry | player | fear | attention | layers
##
## Facts are staged on each column's own clock (milliseconds since its beat began) and played the way residents play
## them (residents._physical): Body's runner reconciles them, updates in active seconds, and the body's apply_elements
## consumes the runner's layers, every frame. A checkout whose runner has no reconcile plays each new fact once through
## runner.play: the before board is honest, not staged - it shows what that checkout does. Cues an element sends
## (announce, vocal, emit) print to the log with their moment; vocals are the labelled PLACEHOLDERS.
## The player row drives player_pose.gd with Body's intent shapes (studio/player/hands.gd preview) on CharacterVisuals.
## The layers row posts the element layer vocabulary straight into apply_elements (no runner).
## The board hides every 3D child of the scene but the ground, lights and camera (KEEP), settles WARMUP seconds, runs
## the beats at TIME_SCALE so a slow hidden render (6-12 fps) still places each column within a few hundredths of a
## second, then saves the frame itself and quits (the game's own --shot frame is set out of reach).

const VillagerBody := preload("res://scripts/studio/village/villager_body.gd")
const BodyElements := preload("res://scripts/studio/people/body_elements.gd")
const Mover := preload("res://scripts/studio/people/mover.gd")
const Crowd := preload("res://scripts/studio/people/crowd.gd")
const Persona := preload("res://scripts/studio/people/persona.gd")
const PLAYER_POSE := "res://scripts/studio/player/player_pose.gd"
const GAP := 1.25
const KEEP := ["Terrain", "Sun", "Moon", "CameraRig"]     # the rest of the scene's 3D children are hidden (props, signs)
const PITCH := {"impact": -10.0, "fall": -16.0, "fire": -12.0, "aftermath": -14.0, "limp": -10.0, "death": -16.0,
	"carry": -12.0, "player": -8.0, "fear": -10.0, "attention": -8.0, "layers": -10.0}
const BURN := {"flail": 1.0, "head": Vector3(-0.35, 0.0, 0.0), "spine": Vector3(-0.1, 0.0, 0.0), "tremble": 0.04,
	"breath": Vector2(1.8, 0.04), "surface": Vector2(0.35, 0.9), "fx": {"kind": "flames", "size": 1.2}}
const HELD := [Vector3(0.16, 1.32, 0.42), Vector3(-0.16, 1.32, 0.42)]   # a pillory board's holes, body space
const SETTLE := 0.4             # seconds the capture waits after the last column's moment, at most
const WARMUP := 5.0             # real seconds after the player appears before the bodies are made
const TIME_SCALE := 0.3         # the game's clock while the beats run (finer steps on a slow render)

var _row := "fall"
var _shot := ""
var _clock := 0.0               # board seconds since the bodies were made
var _capture := INF
var _cols: Array = []
var _crowd: Node
var _built := false
var _saving := false
var _warm := 0.0


static func on_device(tree: SceneTree) -> void:
	var board: Node = (load("res://scripts/studio/people/animation_board.gd") as GDScript).new()
	tree.root.add_child.call_deferred(board)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--board="):
			_row = arg.trim_prefix("--board=")
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")


func _process(delta: float) -> void:
	if not _built:
		if get_tree().current_scene == null or get_tree().current_scene.get_node_or_null("Player") == null:
			return
		_warm += delta
		if _warm < WARMUP:
			return
		_build()
		_built = true
		Engine.time_scale = TIME_SCALE
		return
	_clock += delta
	for c: Dictionary in _cols:
		if not c.started and _clock >= float(c.start):
			c.started = true
		if c.started:
			_beat(c, _clock - float(c.start))
			_play(c, delta)
	if _clock >= _capture and not _saving:
		_saving = true
		_save()


func _now_ms(c: Dictionary) -> int:
	return roundi((_clock - float(c.start)) * 1000.0)


func _build() -> void:
	var scene := get_tree().current_scene
	var player := scene.get_node("Player") as Node3D
	player.visible = false
	for node: Node in scene.get_children():
		if node is Node3D and not (str(node.name) in KEEP):
			(node as Node3D).visible = false
	_crowd = Crowd.new()
	_crowd.drawn_only = true
	add_child(_crowd)
	var specs := _specs()
	var shape := WorldShape.new()
	var x := -(specs.size() - 1) * GAP / 2.0
	var latest := 0.0
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var at := player.global_position + Vector3(x, 0.0, 0.0)
		at.y = shape.height_at(at.x, at.z)
		var c := {"offset": float(spec.offset), "start": 0.0, "spec": spec, "facts": {}, "played": {}, "done": 0,
			"started": false, "i": i, "ground": at.y, "hints": spec.get("hints", {}), "runner": null}
		if _row == "player":
			c.body = CharacterVisual.new()
			add_child(c.body)
			c.body.global_position = at
			if ResourceLoader.exists(PLAYER_POSE):
				c.adapter = (load(PLAYER_POSE) as GDScript).new()
				c.adapter.visual = c.body
				add_child(c.adapter)
		else:
			var body := VillagerBody.new()
			var look := CharacterLook.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = 7 + i * 31
			look.randomize_look(rng)
			body.hero_look = look
			body.is_player_look = false
			add_child(body)
			body.global_position = at
			body.rotation.y = 0.0
			var mover := Mover.new(body, Persona.motion({"key": i, "age": 35, "bold": 50, "temper": 50, "sociable": 50,
				"alert": 50, "scale": 1.0}))
			mover.ground = func(p: Vector2) -> float: return shape.height_at(p.x, p.y)
			mover.actor_key = "board:%d" % i
			mover.active = not (spec.has("walk") or spec.has("raise") or spec.has("feel"))
			_crowd.add(mover)
			c.body = body
			c.mover = mover
			c.runner = BodyElements.new()
			c.port = _port(c)
		var label := Label3D.new()
		label.text = str(spec.label)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 24
		label.pixel_size = 0.0045
		label.outline_size = 10
		label.position = at + Vector3(0.0, 2.2, 0.0)
		add_child(label)
		latest = maxf(latest, float(spec.offset))
		_cols.append(c)
		x += GAP
	_capture = latest + SETTLE
	for c: Dictionary in _cols:
		c.start = _capture - float(c.offset)      # each column began its beat `offset` before the capture
	var rig := scene.get_node("CameraRig")
	rig.set_view(maxf(specs.size() * GAP * 1.05, 6.5), float(PITCH.get(_row, -12.0)), Vector3(0.0, 0.8, 0.0), 0.01)
	print("BOARD row=%s columns=%d capture=%.2f s" % [_row, _cols.size(), _capture])


## The column's element port: the shape of residents.element_port, its facts on the column's clock.
func _port(c: Dictionary) -> Dictionary:
	var current := func(fact: Dictionary) -> Dictionary:
		var now: Dictionary = (c.facts as Dictionary).get(str(fact.get("kind", "")), {})
		if now.is_empty() or str(now.get("deed", "")) != str(fact.get("deed", "")) \
				or int(now.get("revision", 0)) != int(fact.get("revision", 0)):
			return {}
		if now.has("until_tick") and int(now.until_tick) <= _now_ms(c):
			return {}
		return now
	return {"body": c.body, "mover": c.mover, "source": c.mover.actor_key, "visible": true, "hints": c.hints,
		"current": current,
		"live": func(fact: Dictionary) -> bool: return not (current.call(fact) as Dictionary).is_empty(),
		"emit": func(kind: String, _fields: Dictionary) -> void: _cue(c, "emit " + kind),
		"announce": func(kind: String, _fact: Dictionary, transition := false) -> bool:
			_cue(c, "announce %s%s" % [kind, " (transition)" if transition else ""])
			return true,
		"vocal": func(kind: String, strength: float) -> void:
			_cue(c, "vocal %s %.2f (PLACEHOLDER)" % [kind, strength])
			if c.body.has_method("vocal"):
				c.body.vocal(kind, strength)}


func _cue(c: Dictionary, text: String) -> void:
	print("BOARD col=%d at %.2f s: %s" % [c.i, _clock - float(c.start), text])


func _fact(c: Dictionary, kind: String, fields: Dictionary) -> Dictionary:
	var row := {"kind": kind, "id": kind, "deed": "board:%s:%d" % [_row, c.i], "cause_id": "board:%s:%d" % [_row, c.i],
		"revision": 1, "since_tick": _now_ms(c), "strength": 1000}
	row.merge(fields, true)
	if bool(row.get("from_right", false)):         # (the one who did it stands two metres to the body's right on screen)
		row.erase("from_right")
		var p: Vector3 = c.body.global_position
		row["from"] = [p.x + 2.0, p.z]
	return row


## A column's script: its events in order once their moment comes, then what it does every frame.
##   ["fact", t, kind, fields]  ["drop", t, kind]  ["impact", t, force]  ["raise", t, metres]  ["hold", t]
func _beat(c: Dictionary, t: float) -> void:
	var spec: Dictionary = c.spec
	var events: Array = spec.get("events", [])
	while int(c.done) < events.size() and float(events[c.done][1]) <= t:
		var e: Array = events[c.done]
		c.done = int(c.done) + 1
		match str(e[0]):
			"fact":
				c.facts[e[2]] = _fact(c, str(e[2]), e[3])
			"drop":
				(c.facts as Dictionary).erase(e[2])
			"impact":
				var force: float = e[2]
				c.runner.play("impact", c.port, force, {"kind": "impact", "from": Vector3(2.0, 0.0, 0.0),
					"force": roundi(force * 1000.0), "deed": "board:%s:%d:blow" % [_row, c.i], "since_tick": _now_ms(c)})
			"raise":                                    # (Body lifts a carried body behind its carrier, 0.8 m up)
				var lifted: Node3D = c.body
				lifted.global_position.y = float(c.ground) + float(e[2])
			"hold":                                     # (residents restrain a held body upright the same way)
				c.body.hold_hands(HELD[0], HELD[1])
				if c.has("mover"):
					c.mover.constraints["restraint"] = {"move": false, "postures": ["upright"]}
	if spec.has("walk"):
		c.body.play_motion(float(spec.walk))
	if spec.has("feel"):
		_feel(c, spec.feel)
	if spec.has("intent") and c.has("adapter"):
		c.adapter.show_intent(spec.intent)
	if spec.has("layers"):
		if c.body.has_method("apply_elements"):
			c.body.apply_elements(spec.layers)
		if spec.has("held") and not c.body.hands_held():
			c.body.hold_hands(HELD[0], HELD[1])


func _play(c: Dictionary, delta: float) -> void:
	if c.runner == null or (c.spec as Dictionary).has("layers"):
		return
	var tick := _now_ms(c)
	if c.runner.has_method("reconcile"):
		c.runner.reconcile(c.port, c.facts, tick, false)
		c.runner.update(delta)
		if c.body.has_method("apply_elements"):
			c.body.apply_elements(c.runner.layers)
		return
	for kind: String in c.facts:
		var fact: Dictionary = c.facts[kind]
		var version := "%s|%d" % [fact.get("deed", ""), int(fact.get("revision", 0))]
		if c.played.get(kind, "") != version and (not fact.has("until_tick") or tick < int(fact.until_tick)):
			c.played[kind] = version
			c.runner.play(kind, c.port, float(fact.get("strength", 1000)) / 1000.0, fact)
	c.runner.update(delta)


func _feel(c: Dictionary, args: Dictionary) -> void:
	var hints := {"fear": float(args.get("fear", 0.0)), "anger": float(args.get("anger", 0.0)), "pain": 0.0,
		"interest": float(args.get("interest", 0.2)), "alertness": float(args.get("alertness", 0.6)),
		"tension": maxf(float(args.get("fear", 0.0)), float(args.get("anger", 0.0))),
		"style": {"show": float(args.get("show", 0.5)), "steady": float(args.get("steady", 0.5)),
			"pace": 0.0, "lean": float(args.get("lean", 0.0))}}
	if c.body.has_method("express"):
		c.body.express(hints)
	else:
		c.body.pose().expression(hints)
	c.body.look_at_point(c.body.global_position + Vector3(-2.0, 1.5, 3.0))
	c.body.play_motion(float(args.get("run", 0.0)))


func _specs() -> Array:
	var down := {"until_tick": 2500, "strength": 900, "from_right": true, "at": [0.0, 0.0]}
	var long_down := {"until_tick": 60000, "strength": 800, "from_right": true, "at": [0.0, 0.0]}
	var burn := {"until_tick": 60000, "strength": 750, "heat": 750}
	match _row:
		"impact":
			var out: Array = []
			for k: float in [0.15, 0.5, 0.65]:
				for at: float in [0.1, 0.45]:
					out.append({"label": "blow %.2f\n%.2f s" % [k, at], "offset": at, "events": [["impact", 0.0, k]]})
			return out
		"fall":
			var out: Array = []
			for at: float in [0.15, 0.35, 0.9, 2.2, 2.9, 3.6]:
				out.append({"label": ("down" if at < 2.5 else "getting up") + "\n%.2f s" % at, "offset": at,
					"events": [["impact", 0.0, 0.9], ["fact", 0.0, "down", down]]})
			return out
		"fire":
			return [
				{"label": "burning\n1.5 s", "offset": 1.5, "events": [["fact", 0.0, "burning", burn]]},
				{"label": "burning\nwalking", "offset": 1.5, "walk": 1.3, "events": [["fact", 0.0, "burning", burn]]},
				{"label": "burning\nrunning", "offset": 1.5, "walk": 4.0, "events": [["fact", 0.0, "burning", burn]]},
				{"label": "burning\ngrounded", "offset": 2.5, "events": [["fact", 0.0, "down", long_down],
					["fact", 0.0, "burning", burn]]},
				{"label": "burning\nrestrained", "offset": 2.0, "events": [["hold", 0.0], ["fact", 0.0, "down", long_down],
					["fact", 0.0, "burning", burn]]},
				{"label": "doused\n0.4 s", "offset": 2.4, "events": [["fact", 0.0, "burning", burn], ["drop", 2.0, "burning"],
					["fact", 2.0, "doused", {"until_tick": 4500, "strength": 750, "method": "water"}]]},
			]
		"aftermath":
			return [
				{"label": "doused\n1.5 s", "offset": 3.5, "events": [["fact", 0.0, "burning", burn], ["drop", 2.0, "burning"],
					["fact", 2.0, "doused", {"until_tick": 4500, "strength": 750, "method": "water"}],
					["fact", 2.0, "hurt", {"strength": 500, "where": "burn"}]]},
				{"label": "beaten out\n1 s", "offset": 3.0, "events": [["fact", 0.0, "burning", burn], ["drop", 2.0, "burning"],
					["fact", 2.0, "doused", {"until_tick": 4500, "strength": 750, "method": "beat"}],
					["fact", 2.0, "hurt", {"strength": 500, "where": "burn"}]]},
				{"label": "burned out\n1 s", "offset": 3.0, "events": [["fact", 0.0, "burning", burn], ["drop", 2.0, "burning"],
					["fact", 2.0, "doused", {"until_tick": 4500, "strength": 750, "method": "burned_out"}],
					["fact", 2.0, "hurt", {"strength": 650, "where": "burn"}]]},
				{"label": "burned\nwalking", "offset": 2.0, "walk": 1.0, "events": [["fact", 0.0, "hurt",
					{"strength": 750, "where": "burn"}]]},
				{"label": "burned\ndead 3 s", "offset": 5.0, "events": [["fact", 0.0, "down", long_down],
					["fact", 0.0, "burning", burn], ["drop", 2.0, "burning"], ["drop", 2.0, "down"],
					["fact", 2.0, "dead", {"at": [0.0, 0.0], "event": 1}], ["fact", 2.0, "hurt", {"strength": 1000, "where": "burn"}]]},
			]
		"limp":
			return [
				{"label": "walk", "offset": 1.5, "walk": 1.1},
				{"label": "hurt 40\nchest", "offset": 1.5, "walk": 1.1, "events": [["fact", 0.0, "hurt", {"strength": 400, "where": "chest"}]]},
				{"label": "hurt 70\nleg", "offset": 1.5, "walk": 1.0, "events": [["fact", 0.0, "hurt", {"strength": 700, "where": "leg"}]]},
				{"label": "hurt 90\nbelly", "offset": 1.5, "walk": 0.0, "events": [["fact", 0.0, "hurt", {"strength": 900, "where": "belly"}]]},
				{"label": "hurt 50\nhead", "offset": 1.5, "walk": 0.0, "events": [["fact", 0.0, "hurt", {"strength": 500, "where": "head"}]]},
				{"label": "hurt 60\narm", "offset": 1.5, "walk": 0.0, "events": [["fact", 0.0, "hurt", {"strength": 600, "where": "arm"}]]},
			]
		"death":
			var out: Array = []
			for at: float in [0.3, 0.8, 1.5, 3.0]:
				out.append({"label": "dying\n%.1f s" % at if at < 3.0 else "dead\n3 s", "offset": at,
					"events": [["fact", 0.0, "dead", {"at": [0.0, 0.0], "event": 1}]]})
			out.append({"label": "died lying\n1.5 s", "offset": 3.0, "events": [["fact", 0.0, "down", long_down],
				["drop", 1.5, "down"], ["fact", 1.5, "dead", {"at": [0.0, 0.0], "event": 1}]]})
			return out
		"carry":
			return [
				{"label": "carried\nhurt", "offset": 2.0, "raise": true, "events": [["fact", 0.0, "down", long_down],
					["fact", 0.0, "hurt", {"strength": 700, "where": "chest"}], ["fact", 1.0, "carried", {"carrier": "board"}],
					["raise", 1.0, 0.8]]},
				{"label": "carried\nburning", "offset": 2.0, "raise": true, "events": [["fact", 0.0, "down", long_down],
					["fact", 0.0, "burning", burn], ["fact", 1.0, "carried", {"carrier": "board"}], ["raise", 1.0, 0.8]]},
				{"label": "carried\ncorpse", "offset": 3.0, "raise": true, "events": [["fact", 0.0, "dead", {"at": [0.0, 0.0], "event": 1}],
					["fact", 2.5, "carried", {"carrier": "board"}], ["raise", 2.5, 0.8]]},
				{"label": "corpse\nset down", "offset": 3.6, "raise": true, "events": [["fact", 0.0, "dead", {"at": [0.0, 0.0], "event": 1}],
					["fact", 2.5, "carried", {"carrier": "board"}], ["raise", 2.5, 0.8], ["drop", 3.1, "carried"], ["raise", 3.1, 0.0]]},
				{"label": "set down\ngetting up", "offset": 3.2, "raise": true, "events": [["fact", 0.0, "down",
					{"until_tick": 1500, "strength": 800, "from_right": true, "at": [0.0, 0.0]}],
					["fact", 0.8, "carried", {"carrier": "board"}], ["raise", 0.8, 0.8], ["drop", 2.4, "carried"], ["raise", 2.4, 0.0]]},
			]
		"player":
			return [
				{"label": "idle", "offset": 1.0, "intent": {"verb": "", "phase": "idle", "strength": 0.0, "load": "", "guard": false}},
				{"label": "strike\ncoiled", "offset": 1.0, "intent": {"verb": "strike", "phase": "prepared", "strength": 1.0}},
				{"label": "heavy\ncoiled", "offset": 1.0, "intent": {"verb": "heavy", "phase": "prepared", "strength": 1.0}},
				{"label": "shove\nready", "offset": 1.0, "intent": {"verb": "shove", "phase": "prepared", "strength": 0.8}},
				{"label": "guard", "offset": 1.0, "intent": {"verb": "guard", "phase": "prepared", "strength": 1.0}},
				{"label": "grip\nlift", "offset": 1.0, "intent": {"verb": "grip", "phase": "prepared", "strength": 1.0}},
				{"label": "carrying\na person", "offset": 1.0, "intent": {"verb": "", "phase": "idle", "strength": 0.0,
					"load": "person", "guard": false}},
			]
		"fear":
			var out: Array = []
			for fear: float in [0.3, 0.9]:
				out.append({"label": "timid\nfear %.1f" % fear, "offset": 1.5, "feel": {"fear": fear, "show": 0.9, "steady": 0.2, "lean": -0.6}})
				out.append({"label": "bold\nfear %.1f" % fear, "offset": 1.5, "feel": {"fear": fear, "show": 0.3, "steady": 0.9, "lean": -0.1}})
			out.append({"label": "angry\nbold", "offset": 1.5, "feel": {"anger": 0.8, "show": 0.6, "steady": 0.7, "lean": 0.7}})
			out.append({"label": "fleeing\nafraid", "offset": 1.5, "feel": {"fear": 0.8, "show": 0.8, "steady": 0.3, "run": 4.0}})
			return out
		"attention":
			var out: Array = []
			for spec: Array in [["calm", 0.0, 0.0], ["alert", 0.9, 0.0], ["interested", 0.0, 0.9], ["alert and\ninterested", 0.9, 0.9],
					["timid\nfear 0.6", 0.5, 0.3]]:
				out.append({"label": spec[0], "offset": 1.5, "feel": {"alertness": spec[1], "interest": spec[2],
					"fear": 0.6 if str(spec[0]).begins_with("timid") else 0.0, "show": 0.9 if str(spec[0]).begins_with("timid") else 0.5,
					"steady": 0.2 if str(spec[0]).begins_with("timid") else 0.5}})
			return out
		"layers":
			var grounded := BURN.duplicate()
			grounded.merge({"flail": 0.6, "writhe": 0.5}, true)
			var held := BURN.duplicate()
			held.merge({"writhe": 0.35}, true)
			return [
				{"label": "burning\nstanding", "offset": 1.5, "layers": {"burning": BURN}},
				{"label": "burning\nwalking", "offset": 1.5, "walk": 1.3, "layers": {"burning": BURN}},
				{"label": "burning\ngrounded", "offset": 1.5, "layers": {"burning": grounded,
					"down": {"posture": {"name": "down", "clip": "LayToIdle", "at": 0.0}}}},
				{"label": "burning\nrestrained", "offset": 1.5, "held": true, "layers": {"burning": held}},
				{"label": "doused\ngasping", "offset": 1.5, "layers": {"doused": {"surface": Vector2(0.7, 0.15),
					"fx": {"kind": "steam"}, "head": Vector3(0.35, 0.0, 0.0), "breath": Vector2(1.4, 0.06), "shoulders": 0.1,
					"reach_l": {"bone": "spine_03", "at": Vector3(0.12, 0.3, 0.32)}, "reach_r": {"bone": "spine_03", "at": Vector3(-0.12, 0.3, 0.32)}}}},
				{"label": "dead\nburned", "offset": 1.5, "layers": {"dead": {"still": true,
					"posture": {"name": "dead", "clip": "Death01", "at": 2.35}, "surface": Vector2(0.9, 0.0), "fx": {"kind": "smoke"}}}},
			]
	return []


func _save() -> void:
	Engine.time_scale = 1.0
	await RenderingServer.frame_post_draw
	if _shot != "":
		get_viewport().get_texture().get_image().save_png(_shot)
		print("BOARD saved %s" % _shot)
	get_tree().quit()
