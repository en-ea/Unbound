extends Node
## The stage playing the small scenes (Pass 2): a hand-made staging of one incident kind (staging.gd
## demo_incident) on a stand-alone stage in the running game's meadow, in the witness's pattern - play it,
## step to its beats, save a screenshot at each and print a probe line (state, not pixels).
##   godot --path game --resolution 1560x720 -- --studio=village/incident_demo --incident-kind=theft
##         --incident-shots=DIR [--incident-speed=4] --test-save=NAME
## kinds: theft, theft_abandoned, quarrel, kindness, alarm, gathering (or all, one after the other)
## Prints "INCIDENT PASS/FAIL ..." checks; the exit code is the failures.

const Staging := preload("res://scripts/studio/village/staging.gd")
const StageScript := preload("res://scripts/studio/village/stage.gd")
const KINDS := ["theft", "theft_abandoned", "quarrel", "kindness", "alarm", "gathering"]
const LOAD_WAIT := 5.0
const CAMERA := Vector2(0.0, 4.6)      # where the player (the camera's eye) stands from the place

var _kind := "theft"
var _current := ""
var _camera: Camera3D
var _focus := Vector2.ZERO
var _dir := "user://incident-shots"
var _speed := 4.0
var _stage: StageScript
var _t := 0.0
var _failures: Array[String] = []
var _queue: Array[String] = []
var _shots: Array[Dictionary] = []
var _staging := {}
var _player: Node3D
var _begun := false
var _base_cost := PackedFloat32Array()
var _over := false


static func on_device(tree: SceneTree) -> void:
	var probe: Node = (load("res://scripts/studio/village/incident_demo.gd") as GDScript).new()
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--incident-kind="):
			_kind = arg.trim_prefix("--incident-kind=")
		elif arg.begins_with("--incident-shots="):
			_dir = arg.trim_prefix("--incident-shots=")
		elif arg.begins_with("--incident-speed="):
			_speed = float(arg.trim_prefix("--incident-speed="))
	DirAccess.make_dir_recursive_absolute(_dir)
	_queue.assign(KINDS if _kind == "all" else [_kind])


func check(ok: bool, message: String) -> void:
	print(("INCIDENT PASS " if ok else "INCIDENT FAIL ") + message)
	if not ok:
		_failures.append(message)


func _process(delta: float) -> void:
	_t += delta
	if _over:
		return
	if _stage == null:
		if _t >= LOAD_WAIT and not _begun:
			_begun = true
			_begin()
		return
	if _shots.is_empty():
		if _stage.is_finished() or _stage.minute() > float(_staging["end"]) + 90.0:
			_finish_one()
		return
	_follow(delta)
	var minute: float = _stage.minute()
	var shot: Dictionary = _shots[0]
	var ready := false
	if int(shot["index"]) >= 0:
		var began: float = _stage.beat_started(int(shot["index"]))
		ready = began >= 0.0 and minute >= began + float(shot["after"])
	else:
		ready = minute >= float(shot["at"])
	if not ready and minute > float(_staging["end"]) + 60.0:
		print("INCIDENT shot %s never came; taking it anyway" % shot["name"])
		ready = true
	if ready:
		_shots.pop_front()
		_shoot(shot)


func _begin() -> void:
	var kind: String = _queue.pop_front()
	_current = kind
	var demo := Staging.demo_incident(kind) if kind != "unknown" else _unknown()
	_staging = demo[0]
	var people: Array = demo[1]
	var problems := Staging.validate(_staging, people)
	if kind == "unknown":
		check(not problems.is_empty(), "unknown: the contract check names what is wrong (%d problems), and the stage plays it anyway" % problems.size())
	else:
		check(problems.is_empty(), "%s: the staging passes the contract (%s)" % [kind, "; ".join(problems)])
		check(Staging.KINDS.has(_staging["kind"]), "%s: kind %s is in KINDS" % [kind, _staging["kind"]])
	_stage = StageScript.new()
	get_tree().current_scene.add_child(_stage)
	_player = get_tree().current_scene.get_node("Player") as Node3D
	var centre: Vector2 = _stage._resolve(_staging["place"])
	var stand := centre + CAMERA
	_player.global_position = Vector3(stand.x, WorldShape.new().height_at(stand.x, stand.y) + 0.3, stand.y)
	_player.visible = false
	_player.process_mode = Node.PROCESS_MODE_DISABLED     # the camera's eye stays where it is set down
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED    # (and nothing bites it)
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false
	get_tree().current_scene.get_node("CameraRig").snap()
	# a camera of its own, on the game's side of the place (south, above head height), close enough to see hands
	# and what they carry; it keeps the people who are out in the middle of the picture
	if _camera == null:
		_camera = Camera3D.new()
		_camera.fov = 44.0
		add_child(_camera)
	_camera.make_current()
	_focus = centre
	_camera.global_position = Vector3(centre.x + 0.6, WorldShape.new().height_at(centre.x, centre.y) + 3.0, centre.y + 6.4)
	_camera.look_at(Vector3(centre.x, WorldShape.new().height_at(centre.x, centre.y) + 0.9, centre.y))
	_stage.play(_staging, people, _speed)
	for note in _stage.notes():
		print("INCIDENT stage note: ", note)
	print("INCIDENT playing %s at %s (%s), %d people, %d beats, minutes %d-%d, x%.0f" % [kind, _staging["place"], centre, people.size(), _staging["beats"].size(), _staging["start"], _staging["end"], _speed])
	_plan_shots(kind)


## A staging of a kind nobody has heard of, at a place nobody has heard of, carrying a prop nobody made, with a
## shove aimed at a child: it must play without a crash, and leave the child alone (kind "unknown").
func _unknown() -> Array:
	var people := [{"id": 0, "name": "Ann", "outfit": 1, "home": "cottage", "role": "villager", "marks": []},
		{"id": 1, "name": "Bo", "outfit": 2, "home": "cabin", "role": "child", "marks": []}]
	var t0 := 540
	var beats := [
		{"at": t0, "who": 0, "do": "carry", "slot": -1, "target": -1, "anim": "Walk_Carry", "prop": "zeppelin"},
		{"at": t0, "who": 1, "do": "walk_to", "slot": 0, "target": -1, "anim": "Walk", "prop": ""},
		{"at": t0 + 10, "who": 0, "do": "gesture", "slot": -1, "target": 1, "anim": "Push", "prop": ""},
		{"at": t0 + 11, "who": 1, "do": "react", "slot": 0, "target": 0, "anim": "Hit_Chest", "prop": ""},
		{"at": t0 + 14, "who": 0, "do": "juggle", "slot": -1, "target": -1, "anim": "Moonwalk", "prop": ""},
		{"at": t0 + 18, "who": 0, "do": "leave", "slot": -1, "target": -1, "anim": "Walk_Carry", "prop": "zeppelin"},
		{"at": t0 + 18, "who": 1, "do": "leave", "slot": -1, "target": -1, "anim": "Walk", "prop": ""}]
	var staging := {"id": 999, "kind": "zzz", "place": "nowhere_at_all", "start": t0, "end": t0 + 40,
		"phases": [{"name": "scene", "from": t0, "to": t0 + 40, "rescue": false}],
		"roles": {"victim": 0, "accuser": -1, "authority": -1, "crowd": []}, "beats": beats, "outcome": "surely", "cause": []}
	return [staging, people]


## Shots at the moments that matter: the people setting out, each gesture, the carrying, the leaving. A shot
## waits for its beat to have begun (a beat can begin late: the walk before it has to finish) and takes it
## a moment in.
func _plan_shots(kind: String) -> void:
	var shots: Array[Dictionary] = []
	var last := -100.0
	var n := 0
	var beats: Array = _staging["beats"]
	for i in beats.size():
		var b: Dictionary = beats[i]
		var interesting: bool = b["do"] in ["gesture", "react", "leave", "carry"] or (b["do"] == "stand" and b["anim"] in ["Idle_No", "Yes"])
		var after := 1.6
		if b["do"] == "walk_to":
			after = 7.0
		elif b["do"] == "leave":
			after = 4.0
		if (interesting or b["do"] == "walk_to") and float(b["at"]) + after - last >= 3.0:
			n += 1
			shots.append({"index": i, "after": after, "name": "%d-%s-%s" % [n, b["do"], String(b["anim"]).to_lower()], "kind": kind, "beat": b})
			last = float(b["at"]) + after
	shots.append({"index": -1, "after": 0.0, "at": float(_staging["end"]) + 4.0, "name": "%d-after" % (n + 1), "kind": kind, "beat": {}})
	_shots = shots


## The camera drifts to the middle of whoever is out, so a thief walking off is not lost.
func _follow(delta: float) -> void:
	var sum := Vector2.ZERO
	var n := 0
	for a in _stage._actors:
		if not a.inside:
			sum += a.pos
			n += 1
	var goal: Vector2 = _stage.place_at() if n == 0 else sum / float(n)
	_focus = _focus.lerp(goal, clampf(delta * 1.5, 0.0, 1.0))
	var ground := WorldShape.new().height_at(_focus.x, _focus.y)
	_camera.global_position = Vector3(_focus.x + 0.6, ground + 3.0, _focus.y + 6.4)
	_camera.look_at(Vector3(_focus.x, ground + 0.9, _focus.y))


func _shoot(shot: Dictionary) -> void:
	var name := "incident-%s-%s" % [shot["kind"], shot["name"]]
	var image := get_viewport().get_texture().get_image()
	image.save_png(_dir.path_join(name + ".png"))
	# and a close-up round the place, twice the size (the witness's habit): hands, props and feet
	var camera := get_viewport().get_camera_3d()
	var at: Vector2 = _stage.place_at()
	var subject = _stage._victim
	if subject != null and not subject.inside:
		at = subject.pos                      # the scene follows its subject (a thief walking off with a goose)
	var centre := camera.unproject_position(Vector3(at.x, WorldShape.new().height_at(at.x, at.y) + 0.9, at.y))
	var size := Vector2i(520, 292)
	var corner := Vector2i(clampi(int(centre.x) - size.x / 2, 0, image.get_width() - size.x), clampi(int(centre.y) - size.y / 2, 0, image.get_height() - size.y))
	var close := image.get_region(Rect2i(corner, size))
	close.resize(size.x * 2, size.y * 2, Image.INTERPOLATE_BILINEAR)
	close.save_png(_dir.path_join(name + "-close.png"))
	var facts := PackedStringArray()
	for a in _stage._actors:
		if a.inside:
			facts.append("%s inside" % a.person["name"])
			continue
		var held: String = a.held.name if a.held != null else "-"
		facts.append("%s at (%.1f, %.1f) %s%s held %s" % [a.person["name"], a.pos.x - _stage.place_at().x, a.pos.y - _stage.place_at().y, a.playing, " walking" if not a.path.is_empty() else "", held])
	var lying := 0
	for c in _stage.get_children():
		if c is Node3D and String(c.name) in ["Bread", "Goose", "Sack", "Basket"]:
			lying += 1
	print("INCIDENT shot %s at minute %.1f: %s; props on the ground %d; probe %s" % [name, _stage.minute(), "; ".join(facts), lying, _stage.probe()])
	_checks_at(shot)


## What must be true at a moment: a goose in the thief's arms while they leave, bread on the step after, and
## no one inside a house.
func _checks_at(shot: Dictionary) -> void:
	var kind: String = shot["kind"]
	var beat: Dictionary = shot["beat"]
	var p: Dictionary = _stage.probe()
	check(p["in_house"].is_empty(), "%s %s: nobody inside a house" % [kind, shot["name"]])
	if kind == "theft" and beat.get("do", "") == "leave":
		var thief = _stage._by_id[int(beat["who"])]
		check(thief.held != null and thief.held.name == "Goose", "theft: the thief carries the goose away")
	if kind == "kindness" and beat.get("do", "") == "leave" and int(beat["who"]) == 2:
		var lying := false
		for c in _stage.get_children():
			if c is Node3D and c.name == "Bread":
				lying = true
		check(lying, "kindness: the bread is left on the step")
	if kind == "quarrel" and beat.get("do", "") == "gesture" and beat["anim"] == "Push":
		check(true, "quarrel: the shove is played")


func _finish_one() -> void:
	var kind: String = _staging["kind"]
	var cost: Dictionary = _stage.stats()
	print("INCIDENT stage cost and lateness for %s: %s" % [_current, cost])
	check(_stage.is_finished() or _stage.minute() > float(_staging["end"]), "%s: the scene finished and everyone went home" % _current)
	var p: Dictionary = _stage.probe()
	check(p["out"] == 0, "%s: no one left standing about (%d out)" % [kind, p["out"]])
	var held := 0
	for a in _stage._actors:
		if a.held != null:
			held += 1
	if _current == "unknown":
		var notes := "; ".join(_stage.notes())
		check(notes.contains("child"), "unknown: the shove at the child was not shown (%s)" % notes)
	print("INCIDENT held props left on bodies: %d (a goose goes indoors with the thief)" % held)
	_stage.clear()
	_stage.queue_free()
	_stage = null
	_begun = false
	_t = LOAD_WAIT - 1.0
	if _queue.is_empty():
		_over = true
		print("INCIDENT complete failures=%d" % _failures.size())
		get_tree().quit(0 if _failures.is_empty() else 1)
