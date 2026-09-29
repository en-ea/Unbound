extends Node
## Spike: the stage witness. Plays a staging on a stage (stage.gd) in the running game's meadow village,
## and optionally saves screenshots at its key beats, then quits. By default the hand-made pillory
## (staging.gd demo_pillory); --witness-staging=N plays the village simulation's staging N instead
## (sim_stagings.gd STAGINGS), printing its title and story and the contract check (staging.validate).
##   godot --path game --resolution 1560x720 -- --studio=village/witness --frame=fight --time=0.45
##         [--witness-staging=N] [--witness-shots=DIR] [--witness-speed=8] [--witness-hide-player]
##         [--witness-skip=MINUTES] [--witness-edge] [--witness-rescue=free|shield] [--witness-uncapped] [--at=x,z]
## --witness-skip jumps that many game minutes into the staging at once (stage.skip_to), to test it.
## --witness-edge adds what the demo lacks: a stance that doesn't loop by itself, a gesture, a fall.
## --witness-rescue plays a scripted player who steps in during a rescue phase (see _rescue_step):
##   free: walks to the locked victim and presses the game's interact key; shield: stands in a thrower's line.
## Without --at the player stands on the open side of the place (sites.arc leaves it for the camera).
## Shots: DIR/witness-<name>.png at each phase boundary and at the key beats read from the staging (the
## people coming out, the lock, the first throw, a stone, the release or the fall, the crowd leaving,
## everyone home), each with a close-up around the place. Each shot prints a probe line (state, not
## pixels) and the frame's rendering counts; the stage's own per-frame cost is printed at the end.
## Around a timed beat the stage drops to speed 1 for the shot: at x8 a prop is in the air for about one frame.

const Staging := preload("res://scripts/studio/village/staging.gd")
const SimStagings := preload("res://scripts/studio/village/sim_stagings.gd")
const StageScript := preload("res://scripts/studio/village/stage.gd")
const LOAD_WAIT := 5.0        # seconds for the game to load and the start position to settle
const SLOW_LEAD := 2.0        # game minutes before a timed shot that the stage slows to speed 1
const CLOSE_SIZE := Vector2(480, 270)   # pixels around the place, saved at twice the size
const GIVE_UP := 30.0        # game minutes after its mark that a shot is taken anyway (a probe line says so)
const VANTAGE := Vector2(0.0, 4.5)      # where the player stands from the place, on the camera's side
## Shot waits that need the stage at speed 1 to catch their moment.
const TIMED := ["flying", "released", "falling", "locked", "rescued", "shielded"]

var _stage: StageScript
var _t := 0.0
var _dir := ""
var _speed := 8.0
var _shots: Array[Dictionary] = []   # {"name", "at" (minute), "wait" (see _ready_for)}
var _slowed := false
var _hide_player := false
var _skip := 0.0
var _edge := false
var _index := -1            # --witness-staging: which of the simulation's stagings
var _rescue := ""           # --witness-rescue: free / shield
var _frame := 0
var _in_house := {}         # "id@minute" of anyone seen inside a house footprint (walking included)
var _crowded := {}          # pairs seen standing on top of each other
var _at := Vector2.INF      # --at=x,z: dev_args only applies it when --shot is given, so the witness does it too
var _player: Node3D
var _staging := {}
var _victim := -1
var _fall_at := -1.0        # game minute the victim's fall beat is due
var _intervened: Array[String] = []
var _rescuer := {}          # the scripted player's plan (see _rescue_step)
var _people := 0
## Costs while (nearly) everyone is out, every frame (the second after a shot, which pays for saving it,
## is left out): draw calls, frame time (ms; with --witness-uncapped the game's 30 fps cap and vsync are
## lifted, so it shows the real cost) and the stage's own _process time (us).
var _full_draws := PackedFloat32Array()
var _full_ms := PackedFloat32Array()
var _full_us := PackedFloat32Array()
var _shot_t := -100.0
var _out := 0
var _uncapped := false


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
		elif arg.begins_with("--witness-staging="):
			_index = int(arg.trim_prefix("--witness-staging="))
		elif arg.begins_with("--witness-rescue="):
			_rescue = arg.trim_prefix("--witness-rescue=")
		elif arg == "--witness-edge":
			_edge = true
		elif arg == "--witness-uncapped":
			_uncapped = true
			Engine.max_fps = 0
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
	if _out >= _people - 2 and _t > _shot_t + 1.0:
		_full_draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		_full_ms.append(delta * 1000.0)
		_full_us.append(_stage.last_cost_us())
	if _rescue != "":
		_rescue_step()
	if _shots.is_empty() or _frame < 3:
		return      # after a skip the bodies need a frame or two to take up their poses
	var shot := _shots[0]
	var minute: float = _stage.minute()
	var wait: String = shot["wait"]
	if wait in TIMED and not _slowed and minute >= float(shot["at"]) - SLOW_LEAD:
		_stage.set_speed(1.0)
		_slowed = true
	var ready := _ready_for(shot, minute)
	if not ready and minute > float(shot["at"]) + GIVE_UP:
		print("WITNESS shot %s never came (waited for %s); taking it anyway" % [shot["name"], wait])
		ready = true
	if ready:
		_shoot(shot["name"])
		_shots.pop_front()
		if _slowed and (_shots.is_empty() or not (_shots[0]["wait"] in TIMED) or float(_shots[0]["at"]) - SLOW_LEAD > minute):
			_stage.set_speed(_speed)
			_slowed = false
		if _shots.is_empty():
			_finish()


## Whether a shot's moment has come: its minute, plus what it waits for on the stage.
func _ready_for(shot: Dictionary, minute: float) -> bool:
	var at := float(shot["at"])
	match String(shot["wait"]):
		"flying":
			return minute >= at and _stage.flying() >= float(shot.get("along", 0.4))
		"released":
			return _stage.released_minute() >= 0.0 and minute >= _stage.released_minute() + 1.6
		"locked":
			return minute >= at and _stage.is_locked(_victim) and minute >= _stage.locked_minute() + 1.0
		"falling":      # mid-fall: the animation half done
			return _stage.fell_minute() >= 0.0 and minute >= _stage.fell_minute() + 1.2
		"rescued":
			return _intervened.size() > 0 and minute >= float(shot.get("since", at)) + 2.0
		"shielded":
			return _intervened.has("shield") and _stage.flying() < 0.0
		"finished":
			return _stage.is_finished()
	return minute >= at


func _begin() -> void:
	var people: Array
	if _index >= 0:
		var entry: Dictionary = SimStagings.STAGINGS[_index]
		_staging = entry
		people = entry["people"]
		print("WITNESS staging %d of %d: \"%s\" (%s at %s, %d people, outcome %s)" % [_index, SimStagings.STAGINGS.size(),
			entry.get("title", "?"), entry["kind"], entry["place"], people.size(), entry["outcome"]])
		print("WITNESS story: ", entry.get("story", ""))
		var problems := Staging.validate(_staging, people)
		print("WITNESS contract check: ", "no problems" if problems.is_empty() else "; ".join(problems))
	else:
		var demo := Staging.demo_pillory()
		_staging = demo[0]
		people = demo[1]
		if _edge:
			_add_edge_cases(_staging, people)
	_victim = int(_staging["roles"].get("victim", -1))
	_people = people.size()
	_stage = StageScript.new()
	get_tree().current_scene.add_child(_stage)
	_stage.player_intervened.connect(func(kind: String, minute: int) -> void:
		_intervened.append(kind)
		print("WITNESS player intervened: %s at minute %d; probe %s" % [kind, minute, _stage.probe()]))
	_player = get_tree().current_scene.get_node("Player") as Node3D
	var stand := _at
	if stand == Vector2.INF:
		stand = StageScript.Sites.at(_staging["place"]) + VANTAGE
	_player.global_position = Vector3(stand.x, WorldShape.new().height_at(stand.x, stand.y) + 0.3, stand.y)
	get_tree().current_scene.get_node("CameraRig").snap()
	if _hide_player:
		_player.visible = false
	_stage.finished.connect(func() -> void: print("WITNESS finished at minute %.1f" % _stage.minute()))
	var spawn_start := Time.get_ticks_usec()
	_stage.play(_staging, people, _speed)
	print("WITNESS play() took %d ms (%d people)" % [(Time.get_ticks_usec() - spawn_start) / 1000, people.size()])
	if _skip > 0.0:
		var t0 := Time.get_ticks_usec()
		_stage.skip_to(float(_staging["start"]) + _skip)
		print("WITNESS skipped to minute %.1f in %d ms: %s" % [_stage.minute(), (Time.get_ticks_usec() - t0) / 1000, _stage.probe()])
	for b: Dictionary in _staging["beats"]:
		if b["do"] == "fall" and b["who"] == _victim and _fall_at < 0.0:
			_fall_at = b["at"]
	if _rescue != "":
		_plan_rescue()
	if _dir != "":
		_plan_shots()
		print("WITNESS playing %s at x%.1f, %d beats, minutes %d-%d; player at %s; %d shots to %s" % [_staging["kind"], _speed,
			_staging["beats"].size(), _staging["start"], _staging["end"], _player.global_position.snapped(Vector3.ONE * 0.1), _shots.size(), _dir])


## The shots, read from the staging: the people coming out, each phase boundary, and the key beats.
func _plan_shots() -> void:
	var start: int = _staging["start"]
	var first_throw := -1
	var stones := []
	var release := -1
	var lock := -1
	var crowd_leaves := -1
	for b: Dictionary in _staging["beats"]:
		match String(b["do"]):
			"throw":
				if first_throw < 0:
					first_throw = b["at"]
				if b["prop"] == "stone":
					stones.append(b["at"])
			"release":
				if release < 0:
					release = b["at"]
			"lock":
				if lock < 0 and b["who"] == _victim:
					lock = b["at"]
			"leave":
				if crowd_leaves < 0 and b["who"] != _victim:
					crowd_leaves = b["at"]
	var shots: Array[Dictionary] = []
	shots.append({"name": "arriving", "at": start + 16, "wait": ""})
	var phases: Array = _staging["phases"]
	for i in phases.size():
		var p: Dictionary = phases[i]
		if i > 0:
			shots.append({"name": "phase%d-%s" % [i, p["name"]], "at": p["from"], "wait": ""})
		if phases.size() == 1:      # one long phase (a festival): a shot in its middle
			shots.append({"name": "mid-%s" % p["name"], "at": (int(p["from"]) + int(p["to"])) / 2, "wait": ""})
	if lock >= 0:
		shots.append({"name": "lock", "at": lock, "wait": "locked"})
	if first_throw >= 0:
		shots.append({"name": "first-throw", "at": first_throw, "wait": "flying"})
	if stones.size() > 0:     # the third stone if there is one: stones in the air and some already down
		shots.append({"name": "stones", "at": stones[mini(2, stones.size() - 1)], "wait": "flying", "along": 0.7})
	if release >= 0:
		shots.append({"name": "release", "at": release, "wait": "released"})
	if _fall_at >= 0.0:
		shots.append({"name": "fall", "at": _fall_at, "wait": "falling"})
		shots.append({"name": "after-fall", "at": _fall_at + 6.0, "wait": ""})
	if crowd_leaves >= 0:
		shots.append({"name": "leaving", "at": crowd_leaves + 8, "wait": ""})
	if _rescue != "":
		shots.append({"name": "rescue-" + _rescue, "at": _rescuer["at"], "since": _rescuer["at"],
			"wait": "rescued" if _rescue == "free" else "shielded"})
		shots.append({"name": "after-rescue", "at": _rescuer["at"] + 14, "wait": ""})
	shots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	shots.append({"name": "home", "at": int(_staging["end"]) + 30, "wait": "finished"})   # walks home can outlast the staging
	_shots = shots


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


## The scripted player: when to step in (the first throw of a rescue phase, or its middle), and what to do.
func _plan_rescue() -> void:
	var at := -1.0
	var thrower := -1
	for b: Dictionary in _staging["beats"]:
		if b["do"] == "throw" and b["target"] == _victim and _in_rescue_phase(float(b["at"])):
			at = float(b["at"]) - 6.0 if _rescue == "shield" else float(b["at"]) + 12.0
			thrower = b["who"]
			if _rescue == "shield":
				break
			break
	if at < 0.0:
		for p: Dictionary in _staging["phases"]:
			if p["rescue"] and int(p["to"]) > int(p["from"]) and int(p["from"]) > int(_staging["start"]):
				at = (int(p["from"]) + int(p["to"])) / 2.0
				break
	_rescuer = {"at": at, "thrower": thrower, "stage": 0}
	print("WITNESS scripted rescue (%s) at minute %.0f, thrower %d" % [_rescue, at, thrower])


func _in_rescue_phase(minute: float) -> bool:
	for p: Dictionary in _staging["phases"]:
		if p["rescue"] and minute >= float(p["from"]) and minute < float(p["to"]):
			return true
	return false


## Moves the player programmatically (no joystick): at the planned minute it is set down beside the
## victim (free) or in the next thrower's line (shield); for free it then presses the interact key,
## which goes through the game's own action path (player.gd: act -> the nearest interactable).
func _rescue_step() -> void:
	if _rescuer.is_empty() or _rescuer["at"] < 0.0:
		return
	var minute: float = _stage.minute()
	match int(_rescuer["stage"]):
		0:
			if minute < float(_rescuer["at"]):
				return
			var spot: Vector2
			if _rescue == "free":
				spot = _stage.rescue_spot()
			else:
				spot = _stage.shield_spot(int(_rescuer["thrower"]))
			_player.global_position = Vector3(spot.x, WorldShape.new().height_at(spot.x, spot.y) + 0.3, spot.y)
			var look := _stage.place_at() - spot
			(_player.get_node("Visual") as Node3D).rotation.y = atan2(look.x, look.y)
			print("WITNESS scripted player set down at %s (rescue open: %s)" % [spot, _stage.rescue_open()])
			_rescuer["stage"] = 1
			_rescuer["pressed_at"] = _t + 0.4
		1:
			if _rescue != "free" or _t < float(_rescuer["pressed_at"]):
				return
			var key := InputEventKey.new()
			key.physical_keycode = KEY_E
			key.pressed = true
			Input.parse_input_event(key)
			var up := InputEventKey.new()
			up.physical_keycode = KEY_E
			up.pressed = false
			Input.parse_input_event(up)
			print("WITNESS scripted player pressed interact (verb shown: \"%s\")" % _player.get("verb"))
			_rescuer["stage"] = 2


func _shoot(shot_name: String) -> void:
	_shot_t = _t
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
	print("WITNESS shot %s at minute %.1f: %s; %d fps, %d draws, %dk triangles; probe %s" % [shot_name,
		_stage.minute(), path, Engine.get_frames_per_second(),
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
	_out = p["out"]


func _finish() -> void:
	print("WITNESS over the run: inside a house %s; standing on each other %s" % [_in_house.keys(), _crowded.keys()])
	print("WITNESS stage cost and lateness: ", _stage.stats())
	print("WITNESS with (nearly) all %d out, %d frames (median / mean): draws %s, frame ms %s%s, stage _process us %s" % [_people,
		_full_draws.size(), _middle(_full_draws), _middle(_full_ms), " uncapped" if _uncapped else " (30 fps cap)", _middle(_full_us)])
	get_tree().quit()


static func _middle(values: PackedFloat32Array) -> String:
	if values.is_empty():
		return "-"
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	for v in values:
		sum += v
	return "%.1f / %.1f" % [sorted[sorted.size() / 2], sum / values.size()]
