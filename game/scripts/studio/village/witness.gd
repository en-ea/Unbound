extends Node
## Spike: the stage witness. Plays the hand-made pillory (staging.gd demo_pillory) on a stage (stage.gd)
## in the running game's meadow village, and optionally saves screenshots at its key beats, then quits.
##   godot --path game --resolution 1560x720 -- --studio=village/witness --frame=fight --at=1.5,26 --time=0.45
##         [--witness-shots=DIR] [--witness-speed=8] [--witness-hide-player] [--witness-skip=MINUTES]
## --witness-skip jumps that many game minutes into the staging at once (stage.skip_to), to test it.
## --witness-edge adds what the demo lacks: a stance that doesn't loop by itself, a gesture, a fall.
## For a close look, stand the (hidden) player at the place: --at=-0.5,18 --view=6,-40 --witness-hide-player.
## Shots: DIR/witness-<beat>.png for the people coming out, the crowd gathered, the first throw, stones
## flying, the release and everyone home. Each shot also prints a probe line (state, not pixels) and the
## frame's rendering counts; the stage's own per-frame cost is printed at the end.
## The key beats are read from the staging (first throw, a stone, the release), not hard-coded minutes.
## Around a throw the stage drops to speed 1 for the shot: at x8 a prop is in the air for about one frame.

const Staging := preload("res://scripts/studio/village/staging.gd")
const StageScript := preload("res://scripts/studio/village/stage.gd")
const LOAD_WAIT := 5.0        # seconds for the game to load and the start position to settle
const SLOW_LEAD := 2.0        # game minutes before a timed shot that the stage slows to speed 1
const CLOSE_SIZE := Vector2(480, 270)   # pixels around the place, saved at twice the size
const GIVE_UP := 30.0        # game minutes after its mark that a shot is taken anyway (a probe line says so)

var _stage: StageScript
var _t := 0.0
var _dir := ""
var _speed := 8.0
var _shots: Array[Dictionary] = []   # {"name", "at" (minute), "wait" ("" / "flying" / "released" / "finished")}
var _slowed := false
var _hide_player := false
var _skip := 0.0
var _edge := false
var _frame := 0
var _in_house := {}         # "id@minute" of anyone seen inside a house footprint (walking included)
var _crowded := {}          # pairs seen standing on top of each other
var _at := Vector2.INF      # --at=x,z: dev_args only applies it when --shot is given, so the witness does it too


static func on_device(tree: SceneTree) -> void:
	var witness: Node = (load("res://scripts/studio/village/witness.gd") as GDScript).new()
	tree.root.add_child.call_deferred(witness)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--witness-shots="):
			_dir = arg.trim_prefix("--witness-shots=")
		elif arg.begins_with("--witness-speed="):
			_speed = float(arg.trim_prefix("--witness-speed="))
		elif arg.begins_with("--witness-skip="):
			_skip = float(arg.trim_prefix("--witness-skip="))
		elif arg == "--witness-edge":
			_edge = true
		elif arg == "--witness-hide-player":
			_hide_player = true
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split(",")
			_at = Vector2(float(v[0]), float(v[1]))
	if _dir != "":
		DirAccess.make_dir_recursive_absolute(_dir)


func _process(delta: float) -> void:
	_t += delta
	if _stage == null:
		if _t >= LOAD_WAIT:
			_begin()
		return
	_watch()
	if _shots.is_empty() or _frame < 3:
		return      # after a skip the bodies need a frame or two to take up their poses
	var shot := _shots[0]
	var minute: float = _stage.minute()
	var wait: String = shot["wait"]
	if wait == "flying" or wait == "released":
		if not _slowed and minute >= float(shot["at"]) - SLOW_LEAD:
			_stage.set_speed(1.0)
			_slowed = true
	var ready := minute >= float(shot["at"])
	if ready and wait == "flying":
		ready = _stage.flying() >= float(shot.get("along", 0.4))
	elif ready and wait == "released":
		ready = _stage.released_minute() >= 0.0 and minute >= _stage.released_minute() + 1.6
	elif wait == "finished":
		ready = _stage.is_finished()
	if not ready and minute > float(shot["at"]) + GIVE_UP:
		print("WITNESS shot %s never came (waited for %s); taking it anyway" % [shot["name"], wait])
		ready = true
	if ready:
		_shoot(shot["name"])
		_shots.pop_front()
		if _slowed:
			_stage.set_speed(_speed)
			_slowed = false
		if _shots.is_empty():
			_finish()


func _begin() -> void:
	var demo := Staging.demo_pillory()
	var staging: Dictionary = demo[0]
	if _edge:
		_add_edge_cases(staging, demo[1])
	_stage = StageScript.new()
	get_tree().current_scene.add_child(_stage)
	var player := get_tree().current_scene.get_node("Player") as Node3D
	if _at != Vector2.INF:
		player.global_position = Vector3(_at.x, WorldShape.new().height_at(_at.x, _at.y) + 0.3, _at.y)
		get_tree().current_scene.get_node("CameraRig").snap()
	if _hide_player:
		player.visible = false
	_stage.finished.connect(func() -> void: print("WITNESS finished at minute %.1f" % _stage.minute()))
	var spawn_start := Time.get_ticks_usec()
	_stage.play(staging, demo[1], _speed)
	print("WITNESS play() took %d ms (spawning %d bodies)" % [(Time.get_ticks_usec() - spawn_start) / 1000, demo[1].size()])
	if _skip > 0.0:
		var t0 := Time.get_ticks_usec()
		_stage.skip_to(float(staging["start"]) + _skip)
		print("WITNESS skipped to minute %.1f in %d ms: %s" % [_stage.minute(), (Time.get_ticks_usec() - t0) / 1000, _stage.probe()])
	if _dir == "":
		return
	var first_throw := -1
	var stones := []
	var release := -1
	for b: Dictionary in staging["beats"]:
		if b["do"] == "throw" and first_throw < 0:
			first_throw = b["at"]
		if b["do"] == "throw" and b["prop"] == "stone":
			stones.append(b["at"])
		if b["do"] == "release" and release < 0:
			release = b["at"]
	var start: int = staging["start"]
	_shots.append({"name": "arriving", "at": start + 16, "wait": ""})
	_shots.append({"name": "gathered", "at": first_throw - 1, "wait": ""})
	_shots.append({"name": "first-throw", "at": first_throw, "wait": "flying"})
	if stones.size() > 0:     # the third stone if there is one: stones in the air and some already down
		_shots.append({"name": "stones", "at": stones[mini(2, stones.size() - 1)], "wait": "flying", "along": 0.7})
	_shots.append({"name": "release", "at": release, "wait": "released"})
	_shots.append({"name": "home", "at": staging["end"] + 30, "wait": "finished"})   # walks home can outlast the staging
	print("WITNESS playing %s at x%.1f, %d beats, minutes %d-%d; player at %s; shots to %s" % [staging["kind"], _speed, staging["beats"].size(),
		start, staging["end"], player.global_position.snapped(Vector3.ONE * 0.1), _dir])


## Tobin (3) stands saying "Yes" (a one-shot, so the stage replays it), Ilse (4) shakes her head once,
## and Garrow (5) collapses before the stones and lies there until everyone goes home.
func _add_edge_cases(staging: Dictionary, people: Array) -> void:
	var t0: int = staging["start"]
	var beats: Array = staging["beats"]
	for b: Dictionary in beats:
		if b["who"] == 3 and b["do"] == "stand":
			b["anim"] = "Yes"
	beats.append({"at": t0 + 50, "who": 4, "do": "gesture", "slot": 3, "target": -1, "anim": "Idle_No", "prop": ""})
	beats.append({"at": t0 + 230, "who": 5, "do": "fall", "slot": 4, "target": -1, "anim": "Death01", "prop": ""})
	beats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["at"] < b["at"] or (a["at"] == b["at"] and a["who"] < b["who"]))
	print("WITNESS edge cases added; staging problems: ", Staging.validate(staging, people))


func _shoot(shot_name: String) -> void:
	var path := _dir.path_join("witness-%s.png" % shot_name)
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	# And a close-up around the place, twice the size: at the game's framing the event is a small part
	# of the screen, too small to judge feet on the ground or a prop in the air.
	var camera := get_viewport().get_camera_3d()
	var at: Vector2 = _stage.place_at()
	var centre := camera.unproject_position(Vector3(at.x, WorldShape.new().height_at(at.x, at.y) + 0.8, at.y))
	var size := Vector2i(CLOSE_SIZE)
	var corner := Vector2i(clampi(int(centre.x) - size.x / 2, 0, image.get_width() - size.x), clampi(int(centre.y) - size.y / 2, 0, image.get_height() - size.y))
	var close := image.get_region(Rect2i(corner, size))
	close.resize(size.x * 2, size.y * 2, Image.INTERPOLATE_BILINEAR)
	close.save_png(_dir.path_join("witness-%s-close.png" % shot_name))
	print("WITNESS shot %s: %s; %d fps, %d draws, %dk triangles; probe %s" % [shot_name, path,
		Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		_stage.probe()])


## Every few frames, the probe's view of the whole run (not only the shots): anyone walking through a
## house, anyone standing on someone else.
func _watch() -> void:
	_frame += 1
	if _frame % 4 != 0:
		return
	var p: Dictionary = _stage.probe()
	for id: String in p["in_house"]:
		if _in_house.size() < 20:
			_in_house["%s@%d" % [id, int(p["minute"])]] = true
	for pair: String in p["crowded"]:
		_crowded[pair] = true


func _finish() -> void:
	print("WITNESS over the run: inside a house %s; standing on each other %s" % [_in_house.keys(), _crowded.keys()])
	print("WITNESS stage cost and lateness: ", _stage.stats())
	get_tree().quit()
