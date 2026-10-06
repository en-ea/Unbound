extends Node
## Programmatic probe for the people the player can meet (Pass 2, helper A). It plays the game as a player does:
## the player is set down beside a resident and the real action button is pressed (player.act), the real talk
## screen opens, the real buttons are pressed. Screenshots are saved and state is printed (PROBE lines), so the
## run can be checked without pixels first.
##
##   godot --path game --resolution 1560x720 -- --studio=village/live --people-probe=talk|hearing|daily|rite
##         --people-shots=DIR --test-save=NAME   (also rescue, provoke)
##
## talk     three different residents at ordinary work, talked to; the meeting is recorded; the screen closes
## hearing  a hearing: a witness ("What did you see?"), the trace spot (Inspect), the judge (testify, a word in private)
## daily    the same village at 07:12, 10:00, 12:30, 18:30, 23:30 and 06:10: work, meals, chatting, indoors, the door
## rite     the leader of a rite offers the gesture
## rescue   freeing someone at the pillory: the freed one answers in a bubble
## provoke  Give... and Pick a fight from the talk screen, real blows, and every answer to them (see provoke_run)
## motion   how people move, at real speed, in five windows of the day (Pass 3; see motion_run); add
##          --people-targets=N to fail a window that misses a target the plan has due by stage N
## The village session is the game's own; only the clock is moved (Runtime.advance), as time passing would.

const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const Lines := preload("res://scripts/studio/village/resident_lines.gd")
const React := preload("res://scripts/studio/village/resident_react.gd")
const Fixtures := preload("res://scripts/studio/village/sim/actions_test.gd")
const Houses := preload("res://scripts/world/village.gd")
const FightTarget := preload("res://scripts/studio/village/fight_target.gd")
const MotionWatch := preload("res://scripts/studio/people/motion_watch.gd")
const Talk := preload("res://scripts/studio/village/resident_talk.gd")

var mode := "talk"
var pixels := DisplayServer.get_name() != "headless"   # headless (no window in front of anyone): no screenshots or look
                                                        # boards; the measures are the same (they never read pixels)
var targets := 0              # --people-targets=N: the motion mode holds each window to the targets due by stage N
var dir := "user://people-shots"
var failures: Array[String] = []
var _player: Node3D
var _hud: Node
var _live: Node
var _shape := WorldShape.new()
var minimised := 0            # times the window was found minimised (and put back)
var foreign := 0              # key presses, clicks and touches that did not come from the probe
var _own_keys := 0            # key events the probe itself sent and has not seen arrive yet (hold_key)
var _freeze := false          # hold the game clock still (the hearing must not close while the probe looks about)
var _kept := {}               # files in `dir` this run has begun (_keep_line)


static func on_device(tree: SceneTree) -> void:
	var probe: Node = (load("res://scripts/studio/village/people_probe.gd") as GDScript).new()
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	if not pixels:
		seed(20261002)   # headless runs repeat: Enea's creatures draw from the engine's own random numbers (unseeded)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--people-probe="):
			mode = arg.trim_prefix("--people-probe=")
		elif arg.begins_with("--people-shots="):
			dir = arg.trim_prefix("--people-shots=")
		elif arg.begins_with("--people-targets="):
			targets = int(arg.trim_prefix("--people-targets="))
		elif arg.begins_with("--people-fps="):    # the frame cap for this run (the player's own setting is not saved)
			var fps := int(arg.trim_prefix("--people-fps="))
			Engine.max_fps = fps
			Engine.physics_ticks_per_second = fps
			print("PROBE frame cap %d for this run" % fps)
	DirAccess.make_dir_recursive_absolute(dir)
	run.call_deferred()


func _process(_delta: float) -> void:
	if _freeze and VillageSession.village != null:
		VillageSession.village.runtime.fraction = 0.0
	# A minimised window stops drawing: screenshots wait for ever (or repeat one frame) and timing goes off. The probe's
	# window is its evidence: it is put back, and the run says so (what was measured while minimised is suspect).
	if pixels and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		minimised += 1
		print("PROBE note: the window was minimised (%d times); put back" % minimised)


## The probe plays through calls (player.act, buttons' signals), never input events: a key, click or touch is someone
## else's (a window that took the focus when it opened gets whatever is typed). What follows it is not the probe's run.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and _own_keys > 0:
		_own_keys -= 1                     # the probe's own (hold_key), sent through the game's input like a player's
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		foreign += 1
		if foreign <= 5:
			print("PROBE note: input from outside the probe at minute %d: %s" % [int(VillageSession.village.runtime.now) if VillageSession.village != null else -1, event.as_text()])


func check(ok: bool, message: String) -> void:
	print(("PROBE PASS " if ok else "PROBE FAIL ") + message)
	_keep_line("motion.txt", ("PROBE PASS " if ok else "PROBE FAIL ") + message)
	if not ok:
		failures.append(message)


## A line kept whole in a file beside the shots, begun afresh each run: a phone's log cuts lines at 1023 bytes.
func _keep_line(file_name: String, line: String) -> void:
	var path := dir.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.READ_WRITE if _kept.has(path) else FileAccess.WRITE)
	if file == null:
		return
	_kept[path] = true
	file.seek_end()
	file.store_string(line + "\n")


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func shot(label: String) -> void:
	if not pixels:
		return
	await frames(6)
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(dir.path_join(label + ".png"))
	print("PROBE shot %s (err %d) minute %d" % [label, err, int(VillageSession.village.runtime.now) % 1440])


## A screenshot from a camera of the probe's own, round the point `at` (the game's camera is sometimes behind a stall's
## parasol or a roof): the nearest clear side, 4.6 m off and above head height, looking at the point. `quick` takes
## it this frame, for a moment that will not last.
func look_shot(at: Vector3, label: String, quick := false) -> void:
	if not pixels:
		return
	var cam := Camera3D.new()
	cam.fov = 42.0
	add_child(cam)
	var eye := clear_eye(at, 4.6, 2.6)
	cam.global_position = eye
	cam.look_at(at + Vector3(0.0, 0.9, 0.0))
	cam.make_current()
	if quick:
		await get_tree().process_frame
		quick_shot(label)
	else:
		await frames(4)
		await shot(label)
	get_tree().current_scene.get_node("CameraRig").camera.make_current()
	cam.queue_free()


## A place to look at `at` from, `distance` off and `height` up: the nearest clear side (no house or stall in the
## way, nothing between), the camera's side first; else straight from the south.
func clear_eye(at: Vector3, distance: float, height: float) -> Vector3:
	var space := get_viewport().world_3d.direct_space_state
	for k in 16:
		var a := deg_to_rad(10.0 + k * 22.5)
		var candidate := at + Vector3(sin(a) * distance, height, cos(a) * distance)
		var blocked := false
		for h: Dictionary in Houses.HOUSES:
			var size := Vector2(h["size"].x, h["size"].z)
			if Rect2(h["at"] - size * 0.5, size).grow(1.0).has_point(Vector2(candidate.x, candidate.z)) or Rect2(h["at"] - size * 0.5, size).grow(0.3).intersects(Rect2(Vector2(at.x, at.z), Vector2.ZERO).expand(Vector2(candidate.x, candidate.z))):
				blocked = true
		if Rect2(Houses.MERCHANT_AT - Vector2(2.6, 2.6), Vector2(5.2, 5.2)).has_point(Vector2(candidate.x, candidate.z)):
			blocked = true      # the merchant's stall and its parasol
		if not blocked and space.intersect_ray(PhysicsRayQueryParameters3D.create(candidate, at + Vector3(0.0, 1.0, 0.0))).is_empty():
			return candidate
	return at + Vector3(0.5, height, distance)


## A screenshot of exactly this frame (no waiting: for a moment that will not last).
func quick_shot(label: String) -> void:
	if not pixels:
		return
	get_viewport().get_texture().get_image().save_png(dir.path_join(label + ".png"))
	print("PROBE quick shot %s" % label)


func run() -> void:
	await get_tree().create_timer(5.0).timeout
	_player = get_tree().get_first_node_in_group("player")
	_hud = get_tree().get_first_node_in_group("hud")
	_live = get_tree().current_scene.get_node_or_null("VillageLive")
	if _live == null or _player == null:
		print("PROBE FAIL no village in the scene (Living village off?)")
		get_tree().quit(1)
		return
	# the game's own arrival, no flags: check the presentation is the ordinary one
	check(Settings.living_village and VillageSession.active, "Living village on and the session active, with no other flag")
	check(not (_live as Node).has_node("Buttons") and _live.get_child_count() >= 1, "live.gd draws nothing of its own (no canvas layer)")
	var layers := 0
	for child in _live.get_children():
		if child is CanvasLayer or child is Control:
			layers += 1
	check(layers == 0, "no studio canvas layer or control under VillageLive")
	while not _live.registry.all_built():
		await get_tree().process_frame
	await frames(30)
	if mode == "hint":
		_hud.hint("Needs a Stone Pickaxe")
		await frames(10)
		await shot("hint-enea-short")
		_hud.hint("Feathers here. It leads to Hawise.")
		await frames(10)
		await shot("hint-mine")
		print("PROBE hint label rect: ", _hud._hint.get_global_rect(), " viewport ", get_viewport().get_visible_rect().size)
	match mode:
		"talk":
			await talk_run()
		"hearing":
			await hearing_run()
		"daily":
			await daily_run()
		"rite":
			await rite_run()
		"rescue":
			await rescue_run()
		"provoke":
			await provoke_run()
		"motion":
			await motion_run()
	check(foreign == 0, "nothing but the probe drove the game (%d outside key presses, clicks or touches)" % foreign)
	check(minimised == 0, "the window stayed drawn for the whole run (minimised %d times; the frames and timings near those moments are void)" % minimised)
	print("PROBE complete failures=%d" % failures.size())
	_keep_line("motion.txt", "PROBE complete failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _alive_count() -> int:
	var n := 0
	for p in VillageSession.village.people:
		if p.alive and p.present:
			n += 1
	return n


func at_minute(minute: int) -> void:
	var v = VillageSession.village
	var target: int = int(v.runtime.now) / 1440 * 1440 + minute
	Runtime.advance(v, target if target > int(v.runtime.now) else target + 1440)
	v.runtime.fraction = 0.0
	get_tree().current_scene.get_node("WorldEnvironment").time_of_day = float(minute) / 1440.0
	await frames(45)


## Sets the player down beside a body, on the side of it that leaves it the nearest of everyone (the action
## button talks to the nearest), the camera's side (south) preferred, looking at it.
func stand_near(body: Node3D, gap := 1.0, turn := 0) -> void:
	var best := body.global_position + Vector3(0.0, 0.0, gap)
	var best_score := -INF
	for k in (12 if turn == 0 else 1):     # (turn: the k-th of six sides, as it is)
		var a := TAU * k / 12.0 if turn == 0 else TAU * turn / 6.0
		var at := body.global_position + Vector3(sin(a), 0.0, cos(a)) * gap
		var nearest_other := INF
		for id: int in _live.registry.bodies:
			var other: Node3D = _live.registry.bodies[id]
			if other != body and other.visible:
				nearest_other = minf(nearest_other, at.distance_to(other.global_position))
		var score := minf(nearest_other - gap, 1.5) + 0.3 * cos(a)   # cos(a) = 1 due south
		if score > best_score:
			best_score = score
			best = at
	best.y = _shape.height_at(best.x, best.z) + 0.05
	_player.global_position = best
	_player.velocity = Vector3.ZERO
	var look := body.global_position - best
	(_player.get_node("Visual") as Node3D).rotation.y = atan2(look.x, look.z)
	get_tree().call_group("camera_rig", "snap")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await frames(4)          # the residents offer their talk spots in _process: a frame or two after the player arrives
	await get_tree().physics_frame


func dialogue_panel() -> Control:
	for child in _hud.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with("dialogue_panel.gd"):
			return child
	return null


## Presses the action button (the real route) and waits for the talk screen with all its words shown.
func press_act_and_read(label: String) -> Control:
	VillageSession.background = false   # a probe run does not depend on which window the desktop has focused
	_player.act()
	await frames(4)
	var panel := dialogue_panel()
	if panel == null:
		return null
	panel._shown = 99999.0
	await frames(30)
	await shot(label)
	return panel


func press_button(panel: Control, text: String) -> bool:
	for b: Button in panel.find_children("*", "Button", true, false):
		if b.text == text and b.visible:
			b.pressed.emit()
			return true
	return false


func button_labels(panel: Control) -> Array:
	var out := []
	for b: Button in panel.find_children("*", "Button", true, false):
		out.append(b.text)
	return out


func close_talk(panel: Control) -> void:
	if is_instance_valid(panel):
		press_button(panel, "Bye")
		press_button(panel, "Thank you")
	await frames(20)


## Three different people at ordinary work, in the ordinary village.
func talk_run() -> void:
	await at_minute(600)
	var v = VillageSession.village
	var wanted := [["farming", "adult"], ["woodcutting", "adult"], ["child", "child"]]
	var chosen: Array[int] = []
	for want: Array in wanted:
		for id: int in _live.registry.bodies:
			var d := View.describe(v, id)
			var ok: bool = (d.activity.verb == want[0] or d.age_group == want[0]) and not chosen.has(id) and not d.forebear and _live.registry.bodies[id].visible
			if ok and d.age_group == want[1]:
				chosen.append(id)
				break
	if chosen.size() < 3:
		for id: int in _live.registry.bodies:
			var d := View.describe(v, id)
			if not chosen.has(id) and d.activity.verb not in ["sleeping", "away"] and _live.registry.bodies[id].visible:
				chosen.append(id)
			if chosen.size() >= 3:
				break
	var said := []
	for id in chosen:
		var body: Node3D = _live.registry.bodies[id]
		await stand_near(body)
		var d := View.describe(v, id)
		var station = _player.get("_station")
		check(is_instance_valid(station) and station.verb == "Talk" and station.resident == id, "the action button offers Talk to %s (%s, %s)" % [d.name, d.role, d.activity.verb])
		check(not d.toward_player.met, "%s has not met the player yet" % d.name)
		await frames(20)
		await shot("talk-%d-prompt" % [chosen.find(id) + 1])
		var expected := Lines.line(d, int(v.runtime.now) / 1440, int(v.runtime.now) % 1440)
		var panel := await press_act_and_read("talk-%d-%s" % [chosen.find(id) + 1, str(d.name).to_lower()])
		check(panel != null, "the talk screen opened for %s" % d.name)
		if panel != null:
			var text: String = panel._text.text
			said.append(text)
			check(text == expected, "%s says: \"%s\"" % [d.name, text])
			check(Lines.words(text) <= 12, "the line is short")
			check(View.describe(v, id).toward_player.met, "the village recorded the meeting with %s" % d.name)
			check(Controls.locked, "the controls are locked while the screen is open")
			await close_talk(panel)
			check(not Controls.locked and dialogue_panel() == null, "the screen closed and the game is back")
	var distinct := {}
	for text in said:
		distinct[text] = true
	check(distinct.size() == said.size(), "%d residents said %d different things" % [said.size(), distinct.size()])
	# a second visit the same day: the same words
	if chosen.size() > 0:
		var id := chosen[0]
		var body: Node3D = _live.registry.bodies[id]
		await stand_near(body)
		var panel := await press_act_and_read("talk-again")
		if panel != null:
			var d := View.describe(v, id)
			check(d.toward_player.met, "met stays recorded")
			print("PROBE second visit: ", panel._text.text)
			await close_talk(panel)


## A hearing, in the real renderer, with what can be asked of whom.
func theft_hearing() -> Array:
	for seed in range(1, 25):
		var v := Runtime.create(seed, {"anchored": true})
		for _day in 100:
			Runtime.advance(v, v.day * 1440)
			for e: Dictionary in v.runtime.events:
				if e.type != "hearing" or Runtime.terminal(e):
					continue
				var crime := v.crimes[v.cases[e.source.case_id].crime]
				if crime.act == "theft" and crime.trace_at >= 0:
					Runtime.advance(v, maxi(int(v.runtime.now), int(e.from)))
					return [v, e]
	return Fixtures._hearing()


func hearing_run() -> void:
	var pair := theft_hearing()
	var v = pair[0]
	var e: Dictionary = pair[1]
	var old := get_tree().current_scene.get_node("VillageLive")
	old._close()
	get_tree().current_scene.remove_child(old)
	old.queue_free()
	VillageSession.village = v
	VillageSession.recovery_notice = "Village record damaged; your belongings were restored."   # the save's own words
	_live = load("res://scripts/studio/village/live.gd").new()
	_live.name = "VillageLive"
	get_tree().current_scene.add_child(_live)
	_live._open(e)
	var st := Runtime.staging(v, _live._event)
	Runtime.advance(v, int(e.from) + 70)
	_live._stage._player = null
	_live._stage.skip_to(float(int(v.runtime.now) - int(st.day) * 1440))
	_live._stage._player = _player
	await frames(60)
	_freeze = true
	Controls.locked = false
	VillageSession.active = true
	Money.load_data(31)
	Inventory.add("wood", 2)
	check(_live.last_hint == "Village record damaged; items restored." and VillageSession.recovery_notice.is_empty(), "the one-time recovery notice was a hint, said once")
	check(_live.get_children().filter(func(c: Node) -> bool: return c is CanvasLayer or c is Control).is_empty(), "no button bar and no top label under VillageLive during the hearing")
	# 1. a witness: What did you see?
	var witness := -1
	for id in e.witnesses:
		if id != int(e.victim) and _live.registry.bodies.has(id) and (_live._stage._authority == null or id != _live._stage._authority.id):
			witness = int(id)
			break
	var body: Node3D = _live.registry.bodies[witness]
	await stand_near(body)
	var panel := await press_act_and_read("hearing-1-witness")
	check(panel != null, "talking to a witness opens the screen")
	if panel != null:
		var labels := button_labels(panel)
		print("PROBE witness options: ", labels)
		check(labels.has("What did you see?"), "the witness offers What did you see?")
		check(press_button(panel, "What did you see?"), "pressed What did you see?")
		await frames(30)
		await shot("hearing-2-witness-answer")
		print("PROBE witness answers: ", panel._text.text)
		await close_talk(panel)
	# 2. the trace: Inspect, from the same action button
	var params: Dictionary = _live._parameters("inspect")
	if params.get("place", "") != "":
		var spot_at: Vector3 = (_live._spots["inspect"] as Node3D).global_position
		_player.global_position = Vector3(spot_at.x, spot_at.y + 0.05, spot_at.z + 0.5)
		get_tree().call_group("camera_rig", "snap")
		await frames(8)
		var station = _player.get("_station")
		check(is_instance_valid(station) and station.verb == "Inspect", "the action button offers Inspect at the trace")
		_player.act()
		await frames(10)
		print("PROBE inspect hint: ", _live.last_hint)
		check(_live.last_hint != "", "Inspect gave a hint")
		await shot("hearing-3-inspect")
	# 3. the judge: something to say, a word in private
	var judge: Node3D = _live.registry.bodies[_live._stage._authority.id]
	await stand_near(judge)
	panel = await press_act_and_read("hearing-4-judge")
	check(panel != null, "talking to the judge opens the screen")
	if panel != null:
		var labels := button_labels(panel)
		print("PROBE judge options: ", labels)
		check(labels.has("I have something to say"), "the judge offers to hear what the player knows")
		check(labels.has("A word in private... (5 coins)"), "the judge offers a word in private")
		var coins := Money.coins
		press_button(panel, "I have something to say")
		await frames(30)
		await shot("hearing-5-judge-answer")
		print("PROBE judge answers: ", panel._text.text)
		await close_talk(panel)
	# 4. the doorstep: Plant wood
	var plant: Dictionary = _live._parameters("plant")
	if plant.get("place", "") != "":
		var spot_at: Vector3 = (_live._spots["plant"] as Node3D).global_position
		_player.global_position = Vector3(spot_at.x, spot_at.y + 0.05, spot_at.z + 0.5)
		get_tree().call_group("camera_rig", "snap")
		await frames(8)
		var station = _player.get("_station")
		check(is_instance_valid(station) and station.verb == "Plant wood", "the action button offers Plant wood at the doorstep (wood in the bag)")
		await shot("hearing-6-doorstep")
	# 5. nobody actionable near: nothing studio-made on screen
	_player.global_position = Vector3(-30.0, _shape.height_at(-30.0, 30.0), 30.0)
	get_tree().call_group("camera_rig", "snap")
	await frames(20)
	check(not (_player.get("_station") != null and is_instance_valid(_player.get("_station")) and _player.get("_station").is_in_group("interactable") and str(_player.get("_station").verb) in ["Talk", "Inspect", "Plant wood"]), "no talk, inspect or plant station near far from the village")
	await shot("hearing-7-nothing-near")


func daily_run() -> void:
	var v = VillageSession.village
	# the sim's own day: the doorsteps in the early morning, the whole village at the shrine at ten, dinner on the
	# steps at half past twelve, the few at work in the afternoon, talk at the well and the square in the evening
	var stops := [
		["1-07-12-doors", 432, "at_home"],
		["2-10-00-shrine", 600, "praying"],
		["3-12-30-eating", 750, "eating"],
		["4-15-00-work", 900, "woodcutting"],
		["5-19-45-well", 1185, "chatting"],
		["6-19-45-square", 1185, "chatting"],
		["7-23-00-night", 1380, ""],
		["8-06-10-morning", 370, "at_home"],
	]
	var used := {}
	for stop: Array in stops:
		await at_minute(int(stop[1]))
		var verbs := {}
		var places := {}
		var group: Array[Node3D] = []
		for id: int in _live.registry.bodies:
			var body: Node3D = _live.registry.bodies[id]
			var d := View.describe(v, id)
			verbs[d.activity.verb] = int(verbs.get(d.activity.verb, 0)) + 1
			if body.visible and d.activity.verb == stop[2] and not _live.registry.borrowed.has(id):
				var key: String = d.activity.place
				places[key] = int(places.get(key, 0)) + 1
		# the vantage: the busiest place for that activity (the second visit to a verb takes the next place)
		var pick := ""
		var most := 0
		for key: String in places:
			if int(places[key]) > most and not used.has(str(stop[2]) + key):
				most = int(places[key])
				pick = key
		used[str(stop[2]) + pick] = true
		var centre := Vector2.ZERO
		var n := 0
		if pick != "":
			for id: int in _live.registry.bodies:
				var body: Node3D = _live.registry.bodies[id]
				var d := View.describe(v, id)
				if body.visible and d.activity.verb == stop[2] and d.activity.place == pick and not _live.registry.borrowed.has(id):
					centre += Vector2(body.global_position.x, body.global_position.z)
					n += 1
			centre /= float(n)
		else:
			centre = Vector2(-3.0, 12.0)
		var at := centre + Vector2(0.0, 3.6)
		_player.global_position = Vector3(at.x, _shape.height_at(at.x, at.y) + 0.05, at.y)
		get_tree().call_group("camera_rig", "snap")
		await frames(25)
		var out := 0
		for id: int in _live.registry.bodies:
			if (_live.registry.bodies[id] as Node3D).visible:
				out += 1
		print("PROBE %s: %d of %d residents drawn; %d %s at %s; verbs %s" % [stop[0], out, _live.registry.bodies.size(), n, stop[2], pick, JSON.stringify(verbs)])
		# a close look at one of them at that: who, what they play
		var subject: Node3D = null
		var subject_id := -1
		var fewest := 999
		if pick != "":
			for id: int in _live.registry.bodies:
				var body: Node3D = _live.registry.bodies[id]
				var d := View.describe(v, id)
				if body.visible and d.activity.verb == stop[2] and d.activity.place == pick and not _live.registry.borrowed.has(id):
					# the one with the clearest view: the fewest others within two metres (a chatter wants exactly one)
					var near := 0
					for other_id: int in _live.registry.bodies:
						var other: Node3D = _live.registry.bodies[other_id]
						if other != body and other.visible and other.global_position.distance_to(body.global_position) < 2.0:
							near += 1
					var score := absi(near - 1) if stop[2] == "chatting" else near
					if score < fewest:
						fewest = score
						subject = body
						subject_id = id
		if subject != null:
			var cam := Camera3D.new()
			cam.fov = 38.0
			add_child(cam)
			# a place to look from that is not inside a house (their footprints, grown a little), the game's side first
			var chest := subject.global_position + Vector3(0.0, 1.0, 0.0)
			var eye := subject.global_position + Vector3(0.5, 1.9, 3.6)
			for k in 16:
				var a := deg_to_rad(15.0 + k * 22.5)
				var candidate := subject.global_position + Vector3(sin(a) * 3.6, 1.9, cos(a) * 3.6)
				var inside := false
				for h: Dictionary in Houses.HOUSES:
					var size := Vector2(h["size"].x, h["size"].z)
					if Rect2(h["at"] - size * 0.5, size).grow(0.8).has_point(Vector2(candidate.x, candidate.z)):
						inside = true
				if not inside:
					eye = candidate
					break
			cam.global_position = eye
			cam.look_at(chest)
			cam.make_current()
			await frames(30)
			print("PROBE close-up %s: %s (%s) plays %s, tool %s, faces %s, borrowed %s" % [stop[0], v.people[subject_id].name, v.people[subject_id].role,
				_live.registry._picks.get(subject_id, {}).get("loop", "?"), _live.registry._picks.get(subject_id, {}).get("tool", ""),
				_live.registry._faces.get(subject_id, "-"), _live.registry.borrowed.has(subject_id)])
			await shot(str(stop[0]) + "-close")
			get_tree().current_scene.get_node("CameraRig").camera.make_current()
			cam.queue_free()
			await frames(5)
		if str(stop[0]).contains("night"):
			check(out <= 2, "at night the residents are indoors (%d drawn)" % out)
		if str(stop[0]).contains("morning"):
			check(out >= 8, "in the morning they are back at their doors (%d drawn)" % out)
		await shot(stop[0])


## A public act: the Free spot at the restraint, from the same action button; the freed one answers over their head.
func rescue_run() -> void:
	var v = Runtime.create(1)
	var e := {}
	for _day in 150:
		Runtime.advance(v, v.day * 1440)
		for candidate: Dictionary in v.runtime.events:
			if candidate.type == "public" and not Runtime.terminal(candidate) and candidate.place in ["pillory", "gallows", "stake"]:
				e = candidate
				break
		if not e.is_empty():
			break
	if e.is_empty():
		print("PROBE FAIL no public act fixture")
		return
	Runtime.advance(v, maxi(int(v.runtime.now), int(e.from)))
	var old := get_tree().current_scene.get_node("VillageLive")
	old._close()
	get_tree().current_scene.remove_child(old)
	old.queue_free()
	VillageSession.village = v
	_live = load("res://scripts/studio/village/live.gd").new()
	_live.name = "VillageLive"
	get_tree().current_scene.add_child(_live)
	_live._open(e)
	var st := Runtime.staging(v, _live._event)
	Runtime.advance(v, int(e.from) + 20)
	_live._stage._player = null
	_live._stage.skip_to(float(int(v.runtime.now) - int(st.day) * 1440))
	_live._stage._player = _player
	Controls.locked = false
	VillageSession.active = true
	VillageSession.background = false
	_freeze = true
	await frames(40)
	var spot: Vector2 = _live._stage.rescue_spot()
	_player.global_position = Vector3(spot.x, _shape.height_at(spot.x, spot.y) + 0.05, spot.y)
	get_tree().call_group("camera_rig", "snap")
	_live._stage._offer_free()
	await frames(6)
	var station = _player.get("_station")
	check(is_instance_valid(station) and station.verb == "Free", "the action button offers Free at the restraint")
	await shot("rescue-1-free-offered")
	_player.act()
	await frames(20)
	var victim: Node3D = _live.registry.bodies[int(e.victim)]
	check(React.has_bubble(victim), "the freed one answers with a speech bubble over their head")
	print("PROBE bubble says: ", React.bubble_text(victim))
	await shot("rescue-2-bubble")


## The provoke mode: pick a fight through the talk screen, land real blows through Enea's fighter, and see how the
## one struck and those who saw it answer (runtime.reactions, acted out by resident_acts.gd).
##   A  a timid villager: "Pick a fight" from the talk screen (children are never offered it), then blows:
##      protest (the squaring up), startled, flee
##   B  a bold one: protest, then fight_back with the player's parry, its stagger, then hurt and flee
##   C  knocked down (dazed on the ground, then getting up, then back to the day)
##   D  onlookers in a crowd: shout, flee, watch, back_away, intervene
## A state the natural run did not produce is injected into runtime.reactions and labelled "injected": the acting
## is the presentation's, so it is what is looked at.
func react_state(id: int) -> String:
	var r: Dictionary = VillageSession.village.runtime.get("reactions", {}).get(str(id), {})
	return str(r.get("state", "")) if int(r.get("until", 0)) > int(VillageSession.village.runtime.now) else ""


func adult_at_work(skip: Array) -> int:
	var v = VillageSession.village
	for id: int in _live.registry.bodies:
		var d := View.describe(v, id)
		var body: Node3D = _live.registry.bodies[id]
		if d.age_group == "adult" and not d.held and not d.authority and not d.priest and not d.forebear and body.visible \
				and not _live.registry.borrowed.has(id) and not skip.has(id) and d.activity.verb not in ["sleeping", "away", "walking"]:
			return id
	return -1


## Presses the swing (the real action button) beside the target until a blow lands (their bruise changes).
func swing_at(id: int, tries := 8) -> bool:
	var v = VillageSession.village
	var body: Node3D = _live.registry.bodies[id]
	var hurt0: int = v.people[id].hurt
	var down0: int = v.people[id].down_until
	for i in tries:
		var at: Vector3 = body.global_position + Vector3(0.9, 0.3, 0.6)
		_player.global_position = at
		_player.velocity = Vector3.ZERO
		(_player.get_node("Visual") as Node3D).rotation.y = atan2(body.global_position.x - at.x, body.global_position.z - at.z)
		await get_tree().physics_frame
		await get_tree().physics_frame
		VillageSession.background = false
		_player.act()
		await get_tree().create_timer(0.75).timeout
		if v.people[id].hurt != hurt0 or v.people[id].down_until != down0:
			return true
	return false


## Enea's wild creatures (boars, wolves) roam into the village and would fight a player who stands still: a scenario
## here tests the village's people, so the ground is cleared first (the creatures' own spawners bring them back later).
func clear_creatures() -> void:
	var gone := []
	for n: Node in get_tree().get_nodes_in_group("enemy"):
		if n is Node3D and n.get_script() != FightTarget and (n as Node3D).global_position.distance_to(_player.global_position) < 60.0:
			gone.append("%s (%s)" % [n.name, (n.get_script() as Script).resource_path.get_file() if n.get_script() != null else "?"])
			n.queue_free()
	if not gone.is_empty():
		print("PROBE cleared creatures from the village: ", gone)


func provoke_run() -> void:
	var v = VillageSession.village
	var C = Runtime.C
	await at_minute(600)
	Money.load_data(20)
	Inventory.add("apple", 3)
	var provoke: Node = _live.get_node("Provoke")
	clear_creatures()
	# every heart the player loses, and what was near (a probe run should not be hurt by anything but what it tests)
	_player.health_changed.connect(func(health: int, _max: int) -> void:
		var near := []
		for n: Node3D in get_tree().get_nodes_in_group("enemy"):
			if n.global_position.distance_to(_player.global_position) < 8.0:
				near.append("%s %.1f m" % [n.name, n.global_position.distance_to(_player.global_position)])
		var acting := []
		for id: int in _live.registry._acts:
			acting.append("%d %s" % [id, _live.registry._acts[id].state])
		print("PROBE health %d at minute %d; enemies near: %s; answering: %s" % [health, int(VillageSession.village.runtime.now), str(near), str(acting)]))
	var seen := {}
	# --- children are never offered a fight, and a gift is offered ------------------------------------------------
	var child := -1
	for id: int in _live.registry.bodies:
		var d := View.describe(v, id)
		if d.age_group == "child" and _live.registry.bodies[id].visible and not _live.registry.borrowed.has(id) and d.activity.verb not in ["sleeping", "away"]:
			child = id
			break
	if child >= 0:
		await stand_near(_live.registry.bodies[child])
		var child_panel := await press_act_and_read("provoke-0-child")
		if child_panel != null:
			var child_labels := button_labels(child_panel)
			print("PROBE child options: ", child_labels)
			check(not child_labels.has("Pick a fight"), "a child is never offered a fight")
			check(child_labels.has("Give..."), "a child is offered Give...")
			await close_talk(child_panel)
	# --- A: a timid adult -----------------------------------------------------------------------------------------
	var a := adult_at_work([])
	var pa = v.people[a]
	pa.traits[C.BOLD] = 20
	pa.traits[C.TEMPER] = 30
	var body_a: Node3D = _live.registry.bodies[a]
	await stand_near(body_a)
	var panel := await press_act_and_read("provoke-1-talk-options")
	check(panel != null, "the talk screen opens for %s" % pa.name)
	if panel != null:
		var labels := button_labels(panel)
		print("PROBE adult options: ", labels)
		check(labels.has("Pick a fight") and labels.has("Give..."), "an adult is offered Give... and Pick a fight")
		# Give...: what is carried: coins, an apple
		press_button(panel, "Give...")
		await frames(25)
		await shot("provoke-2-give-options")
		var gift_labels := button_labels(panel)
		print("PROBE give options: ", gift_labels)
		check(gift_labels.has("Give: 5 coins") and gift_labels.has("Give: Apple"), "Give... offers five coins and the apple")
		var coins0 := Money.coins
		var apples0 := Inventory.count("apple")
		var feeling0: int = View.toward_player(v, a).feeling
		press_button(panel, "Give: Apple")
		await frames(30)
		print("PROBE they say: ", panel._text.text)
		await shot("provoke-3-thanks")
		await close_talk(panel)
		await frames(20)
		check(Inventory.count("apple") == apples0 - 1 and View.toward_player(v, a).memories.has("gift_from_you"), "the apple left the bag and the gift is remembered (feeling %d -> %d)" % [feeling0, View.toward_player(v, a).feeling])
		# now the fight: through the talk screen
		await stand_near(body_a)
		panel = await press_act_and_read("provoke-4-again")
		check(panel != null and press_button(panel, "Pick a fight"), "Pick a fight pressed")
		await frames(20)
		check(provoke.is_squared_up(a), "after the screen closed, the villager is squared up (a fight target for Enea's fighter)")
		check(not Controls.locked, "the controls are free")
		seen[react_state(a)] = true
		print("PROBE reaction after squaring up: ", react_state(a), " bark: ", React.bubble_text(body_a))
		await look_shot((_player.global_position + body_a.global_position) * 0.5, "provoke-5-square-up-" + react_state(a))
	# the blows
	for blow in 4:
		var landed := await swing_at(a)
		var st := react_state(a)
		print("PROBE blow %d landed=%s -> %s, hurt %d" % [blow + 1, landed, st, v.people[a].hurt])
		await get_tree().create_timer(0.55).timeout
		seen[st] = true
		await look_shot((_player.global_position + body_a.global_position) * 0.5, "provoke-6-A-blow%d-%s" % [blow + 1, st])
		if st in ["flee", "plead", "down"]:
			break
	# --- B: a bold one who fights back, and a parry ---------------------------------------------------------------
	await at_minute(int(v.runtime.now) % 1440 + 5)
	var b := adult_at_work([a])
	var pb = v.people[b]
	pb.traits[C.BOLD] = 90
	pb.traits[C.TEMPER] = 60
	pb.hurt = 0
	var body_b: Node3D = _live.registry.bodies[b]
	await stand_near(body_b)
	var reg = _live.registry
	clear_creatures()
	print("PROBE player health before B: %d of %d (then healed: B's test is the parry, not what came before)" % [_player.health, _player.MAX_HEALTH])
	_player.heal_full()
	var squared_b: Dictionary = provoke.square_up(b)
	check(squared_b.get("accepted", false), "B squared up (%s)" % squared_b.get("reason", "accepted"))
	await frames(10)
	var landed_b: bool = await swing_at(b)
	await get_tree().create_timer(0.3).timeout
	landed_b = (await swing_at(b)) and landed_b
	check(landed_b, "both blows on B landed")
	var fight_state := react_state(b)
	print("PROBE B second blow -> ", fight_state)
	seen[fight_state] = true
	if fight_state == "fight_back":
		await frames(4)
		var act = reg._acts.get(b)
		if act != null and act.attacker != null:
			var glinted := [false]
			act.attacker.blow_coming.connect(func(_who: int) -> void: glinted[0] = true)
			var landed_result := [""]
			act.attacker.blow_landed.connect(func(_who: int, result: String) -> void: landed_result[0] = result)
			var waited := 0.0
			while not glinted[0] and waited < 10.0 and react_state(b) == "fight_back":
				await get_tree().process_frame
				waited += get_process_delta_time()
				_player.global_position = _player.global_position   # (keeps still)
			print("PROBE the glint came (wind-up shown): %s after %.2f s; the fight so far: %s; mode now %s, %.1f m from the player" % [glinted[0], waited, str(act.trace), act.mode, act.pos.distance_to(reg.player_xz())])
			print("PROBE where: player %s, B's body %s (local %s), the act's pos %s, the act still current %s, registry at %s, player health %d" % [_player.global_position, body_b.global_position, body_b.position, act.pos, reg._acts.get(b) == act, reg.global_position, _player.health])
			check(glinted[0], "a fight_back gives an honest wind-up and glint before the blow")
			var glint_ms := Time.get_ticks_msec()
			look_shot((_player.global_position + body_b.global_position) * 0.5, "provoke-7-B-glint", true)
			# the blow lands 0.45 s after the glint: the guard goes up at the right moment (perfect parry window is 0.22 s)
			await get_tree().create_timer(0.26).timeout
			print("PROBE guard raised %d ms after the glint (the perfect window is 220 ms wide, ending at 450)" % (Time.get_ticks_msec() - glint_ms))
			_player.guard()
			await get_tree().create_timer(0.5).timeout
			print("PROBE the blow: ", landed_result[0], " staggered: ", act.staggered() if act != null else "-")
			check(landed_result[0] == "parry", "the player's parry stopped the blow (%s)" % landed_result[0])
			await look_shot((_player.global_position + body_b.global_position) * 0.5, "provoke-8-B-parried")
			check(act.staggered() or act.mode == "recover" or act.mode == "stagger", "the parried villager reels (stagger)")
			await get_tree().create_timer(1.6).timeout
			await look_shot((_player.global_position + body_b.global_position) * 0.5, "provoke-9-B-after")
	# B fights on for a while (and would keep hitting the player beside C): let it end first
	var fought := 0.0
	while react_state(b) == "fight_back" and fought < 20.0:
		await get_tree().process_frame
		fought += get_process_delta_time()
	# --- C: knocked down ------------------------------------------------------------------------------------------
	var c := adult_at_work([a, b])
	var pc = v.people[c]
	pc.traits[C.BOLD] = 50
	pc.hurt = 88
	await stand_near(_live.registry.bodies[c])
	clear_creatures()
	var squared_c: Dictionary = provoke.square_up(c)
	check(squared_c.get("accepted", false), "C squared up (%s)" % squared_c.get("reason", "accepted"))
	await frames(10)
	check(await swing_at(c), "the blow on C landed")
	await get_tree().create_timer(0.9).timeout
	print("PROBE C -> ", react_state(c), " down_until ", pc.down_until, " now ", int(v.runtime.now))
	check(pc.down_until > int(v.runtime.now) or react_state(c) == "down", "C, already hurt, is knocked down")
	seen[react_state(c)] = true
	await look_shot(_live.registry.bodies[c].global_position, "provoke-10-C-down")
	await get_tree().create_timer(1.5).timeout
	await look_shot(_live.registry.bodies[c].global_position, "provoke-11-C-down-dazed")
	# wait for the getting up and the way back
	var t_wait := 0.0
	while react_state(c) == "down" and t_wait < 40.0:
		await get_tree().create_timer(1.0).timeout
		t_wait += 1.0
	await get_tree().create_timer(0.7).timeout
	await look_shot(_live.registry.bodies[c].global_position, "provoke-12-C-getting-up")
	await get_tree().create_timer(3.0).timeout
	check(reg._acts.get(c) == null, "the answer is over: the body is handed back to the day (walking back: %s)" % str(reg._movers[c].walking()))
	await look_shot(_live.registry.bodies[c].global_position, "provoke-13-C-back-to-day")
	# --- D: onlookers in a crowd ----------------------------------------------------------------------------------
	clear_creatures()
	await at_minute(1185)
	var crowd_at := ""
	var places := {}
	for id: int in reg.bodies:
		var d := View.describe(v, id)
		if d.activity.verb == "chatting" and not reg.borrowed.has(id):
			places[d.activity.place] = int(places.get(d.activity.place, 0)) + 1
	var best := 0
	for key: String in places:
		if int(places[key]) > best:
			best = int(places[key])
			crowd_at = key
	var crowd: Array[int] = []
	for id: int in reg.bodies:
		var d := View.describe(v, id)
		if d.activity.verb == "chatting" and d.activity.place == crowd_at and not reg.borrowed.has(id):
			crowd.append(id)
	print("PROBE crowd at %s: %d" % [crowd_at, crowd.size()])
	var victim := -1
	var roles := {}
	for id in crowd:
		var d := View.describe(v, id)
		if victim < 0 and d.age_group == "adult" and not d.authority and not d.priest and not d.forebear:
			victim = id
	var k := 0
	for id in crowd:
		if id == victim:
			continue
		var q = v.people[id]
		match k % 4:
			0:
				q.traits[C.COMPASSION] = 95     # speaks up
			1:
				q.traits[C.BOLD] = 15           # runs
			2:
				q.traits[C.BOLD] = 70           # (not close: watches or backs off)
			3:
				q.traits[C.COMPASSION] = 20
				q.traits[C.BOLD] = 45
		k += 1
	if victim >= 0:
		var vic_body: Node3D = reg.bodies[victim]
		v.people[victim].traits[C.BOLD] = 25
		var vic_home: String = View.describe(v, victim).home
		# a housemate of the one struck, bold: the one who steps between
		for id in crowd:
			if id != victim and View.describe(v, id).home == vic_home:
				v.people[id].traits[C.BOLD] = 85
				break
		await stand_near(vic_body, 1.2)
		provoke.square_up(victim)
		await frames(10)
		await swing_at(victim)
		await get_tree().create_timer(0.8).timeout
		var states := {}
		for id in crowd:
			var st := react_state(id)
			states[st] = int(states.get(st, 0)) + 1
			if st != "":
				seen[st] = true
		print("PROBE onlookers answered: ", states)
		await look_shot(vic_body.global_position, "provoke-14-D-onlookers-a")
		await get_tree().create_timer(1.2).timeout
		await look_shot(vic_body.global_position, "provoke-15-D-onlookers-b")
		await get_tree().create_timer(2.0).timeout
		await look_shot(vic_body.global_position, "provoke-16-D-onlookers-c")
	# --- states the run did not produce: injected, and looked at ----------------------------------------------------
	var want := ["puzzled", "startled", "protest", "flee", "call_help", "plead", "down", "fight_back", "intervene", "shout", "back_away", "watch"]
	print("PROBE states seen naturally: ", seen.keys())
	for st: String in want:
		if seen.has(st):
			continue
		var id := adult_at_work([a, b, c, victim])
		if id < 0:
			continue
		await at_minute(int(v.runtime.now) % 1440 + 1)
		var body: Node3D = reg.bodies[id]
		await stand_near(body, 2.4)
		var now := int(v.runtime.now)
		v.runtime.get_or_add("reactions", {})[str(id)] = {"state": st, "since": now, "until": now + 14}
		if st == "intervene":
			v.runtime.reactions[str(a)] = {"state": "protest", "since": now, "until": now + 14}
		await get_tree().create_timer(0.9).timeout
		print("PROBE injected %s on %s: bubble '%s'" % [st, v.people[id].name, React.bubble_text(body)])
		await look_shot(body.global_position, "provoke-17-injected-" + st)
	check(true, "the provoke run is over")


## ---- motion (Pass 3) -------------------------------------------------------------------------------------------
## The robotic signs of the plan's section 6, in six windows of the first two days, at real speed (Engine.time_scale
## is never touched: motion is measured as it plays). Each window prints MOTION <window> {json} (people/motion_watch.gd)
## and saves a frame sequence for the look board (sequence: listed in motion-shots.txt for toolbox/lookboard/sheet.gd):
##   shrine   the busiest setting-off of the morning: on the first day, a holy day, the pious walk to the shrine at
##            nine (village.gd day plans); the player stands on the way where the most of them will pass
##   evening  the walk from work to the evening's place at six, which the whole village makes every day, the same way
##   well     the evening talk at the well: standing groups, the player 3.6 m off
##   scene    a small scene the director brings near the player at the next hour, the next morning (the probe only
##            makes the village quiet for long enough, which is the director's own rule)
##   blow     then blows on up to three grown villagers near it, through the fight the talk screen offers
## With --people-targets=N, shrine, evening and well are judged from stage 1; scene and blow from stage 2 (their
## walkers - the stage's and the reactions' - move onto the mover then).
## Enea's world acts on its own: his creatures are cleared and the player healed before each window and every few
## seconds while it runs (a boar charging a player who stands still is not the village's motion).
var _listing := PackedStringArray()
var _windows := PackedStringArray()   # --people-windows=scene,blow: only these are watched (the clock still goes)


func _want(window: String) -> bool:
	return _windows.is_empty() or _windows.has(window)


func motion_run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--people-windows="):
			_windows = arg.trim_prefix("--people-windows=").split(",")
	var v = VillageSession.village
	var reg = _live.registry
	VillageSession.background = false
	var watch := MotionWatch.new()
	watch.name = "MotionWatch"
	watch.registry = reg
	watch.groups_source = reg.talking_groups          # the conversations as the village runs them (stage 3)
	watch.camera = get_tree().current_scene.get_node("CameraRig").camera   # bubbles as the player sees them
	add_child(watch)
	var provoke: Node = _live.get_node("Provoke")
	provoke.struck.connect(watch.blow)
	# the first day is a holy day (village.gd day plans: day % 7 == 0): the pious walk to the shrine at nine
	if _want("shrine"):
		await flow_window(watch, "shrine", 480, 660, 60.0)
	# the daytime village: people about their chores at home, at work, on small errands, meeting each other
	if _want("life"):
		await _life_window(watch)
	# every day at six in the evening, the whole village walks from work to the evening's place
	if _want("evening"):
		await flow_window(watch, "evening", 1050, 1120, 40.0)
	# the evening at the well
	if _want("well"):
		await at_minute(1180)
		await _well_window(watch)
	# a small scene, the next morning: quiet long enough, and the director brings one near the player at the next hour
	if _want("scene") or _want("blow"):
		await at_minute(650)
		await _scene_windows(watch, provoke)
	var file := FileAccess.open(dir.path_join("motion-shots.txt"), FileAccess.WRITE)
	file.store_string("\n".join(_listing) + "\n")
	file.close()
	print("PROBE motion shots listed in %s" % dir.path_join("motion-shots.txt"))


## The middle of the day, from the square (the houses round it within about 15 m): is it life, or people standing about?
func _life_window(watch: Node) -> void:
	var v = VillageSession.village
	if int(v.runtime.now) % 1440 < 840:
		await at_minute(840)
	await stand_at(_live.registry.place("square") + Vector2(0.0, 2.5))
	await frames(30)
	if not _village_here("life"):
		return
	await watch_window(watch, "life", 90.0, 20.0, Callable(), 3)


func _well_window(watch: Node) -> void:
	var v = VillageSession.village
	var reg = _live.registry
	var talkers := Vector2.ZERO
	var n := 0
	for id: int in reg.bodies:
		var d := View.describe(v, id)
		if (reg.bodies[id] as Node3D).visible and d.activity.verb == "chatting" and d.activity.place == "well" and not reg.borrowed.has(id):
			talkers += Vector2(reg.bodies[id].global_position.x, reg.bodies[id].global_position.z)
			n += 1
	var well: Vector2 = talkers / n if n > 0 else reg.place("well")
	print("PROBE well: %d chatting at the well" % n)
	await stand_at(well + Vector2(0.0, 3.6))
	if not _village_here("well"):
		return
	var ws := await watch_window(watch, "well", 60.0, 10.0)
	check(int(ws.head_samples) > 0, "well: talking groups were watched (%d head samples, groups %s)" % [int(ws.head_samples), str(ws.groups_seen)])


func _scene_windows(watch: Node, provoke: Node) -> void:
	var v = VillageSession.village
	var reg = _live.registry
	await stand_at(reg.place("square") + Vector2(2.0, 3.0))
	v.runtime.quiet_since = int(v.runtime.now) - 1000
	var waited := 0.0
	var tidy := 0.0
	while waited < 75.0 and not _incident_open():
		await get_tree().process_frame
		waited += get_process_delta_time()
		tidy += get_process_delta_time()
		if tidy > 4.0:
			tidy = 0.0
			clear_creatures()
	if not _village_here("scene"):
		return
	var open := _incident_open()
	var st: Dictionary = Runtime.staging(v, _live._event) if open else {}
	check(open, "scene: the director brought a small scene near the player (%s after %.0f s)" % [st.get("kind", "none"), waited])
	if not open:
		return
	var centre: Vector2 = _live._stage._centre
	print("PROBE scene: %s at %s, %d people" % [st.get("kind", "?"), _live._stage._place, _live._stage._actors.size()])
	await stand_at(centre + Vector2(0.0, 4.5))
	await watch_window(watch, "scene", 30.0, 4.0, Callable(), 2)
	# blows on grown villagers near it (not those the scene holds), one each, ten seconds apart
	var victims := free_adults_near(centre, 3)
	check(not victims.is_empty(), "blow: grown villagers free to strike within 20 m of the scene (%d)" % victims.size())
	if victims.is_empty():
		return
	provoke.struck.connect(func(id: int) -> void: sequence("blow", reg.bodies[id].global_position), CONNECT_ONE_SHOT)
	var bs := await watch_window(watch, "blow", 12.0 * victims.size(), -1.0, func() -> void: await strike_each(victims), 2)
	check((bs.blows as Array).size() == victims.size(), "blow: every blow landed and was timed (%s)" % str(bs.blows))


## A window on the village setting off: the busiest minute in [from, to) of the day plans (tomorrow's, when today's
## has passed), from 4 s before it, the player standing where the most of them will pass.
func flow_window(watch: Node, window: String, from: int, to: int, seconds: float) -> void:
	var v = VillageSession.village
	if int(v.runtime.now) % 1440 >= from - 10:
		await at_minute(from - 10)
	var busiest := busiest_start(from, to)
	if busiest.x - 8 > int(v.runtime.now) % 1440:
		await at_minute(busiest.x - 8)
	var stand := flow_point(busiest.x - 2, busiest.x + 30)
	print("PROBE %s: day %d, %d set off at %02d:%02d; the player stands at %s, where the most of them pass" % [window,
		int(v.runtime.now) / 1440, busiest.y, busiest.x / 60, busiest.x % 60, stand])
	check(busiest.y >= 3, "%s: at least three set off together in the day plans (%d)" % [window, busiest.y])
	await stand_at(stand)
	var s := await watch_window(watch, window, seconds, 5.0)
	check(int(s.departures) >= 3 and float(s.moving_s) > 10.0, "%s: the window saw people set off and walk (%d departures, %.0f s of moving)" % [window, int(s.departures), float(s.moving_s)])


## Whether the village scene the probe started with is still there (leaving the region frees it). -> false, a failure.
func _village_here(window: String) -> bool:
	var here := is_instance_valid(_live) and _live.is_inside_tree()
	check(here, "%s: the village scene is still there (it is gone when the player leaves the region)" % window)
	return here


## Up to `count` grown villagers free to strike (not a child, held, an authority, a priest, a forebear, nor anyone a
## scene holds), the nearest `at` first, within 20 m.
func free_adults_near(at: Vector2, count: int) -> Array[int]:
	var v = VillageSession.village
	var reg = _live.registry
	var found := []
	for id: int in reg.bodies:
		var d := View.describe(v, id)
		var body: Node3D = reg.bodies[id]
		var p = v.people[id]
		var far := at.distance_to(Vector2(body.global_position.x, body.global_position.z))
		if d.age_group == "adult" and not d.held and not d.authority and not d.priest and not d.forebear and body.visible 				and not reg.borrowed.has(id) and not p.locked and p.down_until <= int(v.runtime.now) and far < 20.0:
			found.append([far, id])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[int] = []
	for f: Array in found.slice(0, count):
		out.append(int(f[1]))
	return out


## Squares up to each in turn and lands one blow, through the fight the talk screen offers, ten seconds apart (the
## player healed and the creatures cleared before each).
func strike_each(victims: Array[int]) -> void:
	var provoke: Node = _live.get_node("Provoke")
	var first := true
	for id in victims:
		await stand_near(_live.registry.bodies[id], 1.2)
		clear_creatures()
		_player.heal_full()
		if first:                          # the first one the way a player does it: a tap talks, a hold squares up
			first = false
			await hold_to_fight(id)
			continue
		var squared: Dictionary = provoke.square_up(id)
		check(squared.get("accepted", false), "blow: squared up to %s (%s)" % [VillageSession.village.people[id].name, squared.get("reason", "accepted")])
		await frames(10)
		var landed := await swing_at(id)
		print("PROBE blow on %s landed=%s, answer %s" % [VillageSession.village.people[id].name, landed, react_state(id)])
		await get_tree().create_timer(10.0).timeout


## The action key pressed (and later let go) through the game's own input, as a player's would be.
func hold_key(down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.keycode = KEY_E
	ev.pressed = down
	_own_keys += 1
	Input.parse_input_event(ev)


## Tap to talk, hold to fight (hold_to_fight.gd), with real key presses: a tap opens the talk (no fight), a hold
## squares up with no talk screen, the button then reads Attack, and a tap lands a blow.
func hold_to_fight(id: int) -> void:
	var provoke: Node = _live.get_node("Provoke")
	var name: String = VillageSession.village.people[id].name
	VillageSession.background = false
	var aimed := await stand_aimed(id)
	check(aimed == id, "hold: the action button aims at %s (aims at %d)" % [name, aimed])
	var into: Vector3 = (_live.registry.bodies[id] as Node3D).global_position - _player.global_position
	into.y = 0.0
	await physics_frames(2)
	check(_player.test_move(_player.global_transform, into), "solid: walking into %s, the player's body stops at theirs" % name)
	hold_key(true)
	await frames(5)
	hold_key(false)
	await frames(12)
	var panel := dialogue_panel()
	var talked := Controls.locked and panel != null and panel.visible
	check(talked and not provoke.is_squared_up(id), "hold: a tap on %s opens the talk, no fight" % name)
	await close_talk(panel)
	await frames(10)
	aimed = await stand_aimed(id)                        # they turn back to their day: the player steps up again
	check(aimed == id, "hold: aimed at %s again before the hold (aims at %d)" % [name, aimed])
	hold_key(true)
	var t := 0.0
	while t < 0.7 and not provoke.is_squared_up(id):
		await get_tree().process_frame
		t += get_process_delta_time()
	var no_talk := not Controls.locked
	hold_key(false)
	await frames(6)
	check(provoke.is_squared_up(id) and no_talk and not Controls.locked,
		"hold: holding %.2f s on %s squares up, no talk screen" % [t, name])
	await physics_frames(4)
	check(_player.verb == "Attack", "hold: the button then reads %s (Attack)" % _player.verb)
	var landed := await swing_at(id)
	check(landed, "hold: a tap then lands a blow on %s" % name)
	print("PROBE blow on %s landed=%s, answer %s" % [name, landed, react_state(id)])
	await get_tree().create_timer(10.0).timeout


## Steps up to `id` where the action button aims at them (another's talk spot, or the well's, may be nearer from one
## side: the player walks round to where it is theirs) -> who it aims at from the last place tried.
func stand_aimed(id: int) -> int:
	var aimed := -1
	for gap: float in [1.2, 0.9, 1.5]:
		for k in 6:
			await stand_near(_live.registry.bodies[id], gap, k)
			await physics_frames(3)
			var station: Variant = _player.get("_station")   # (a freed one is not an Object to assign)
			aimed = (station as Talk.Spot).resident if is_instance_valid(station) and station is Talk.Spot else -1
			if aimed == id:
				return aimed
	return aimed


func physics_frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


## The incident the stage is playing, if one is open.
func _incident_open() -> bool:
	if not is_instance_valid(_live) or _live._stage == null:
		return false
	var e: Dictionary = Runtime.event_by_id(VillageSession.village, _live._event)
	return not e.is_empty() and e.type == "incident"


## The minute in [from, to) of the day when the most residents with a body set off somewhere else (x), and how many (y).
func busiest_start(from: int, to: int) -> Vector2i:
	var v = VillageSession.village
	var counts := {}
	for id: int in _live.registry.bodies:
		var p = v.people[id]
		if not p.alive or not p.present:
			continue
		for i in range(3, p.plan.size(), 3):
			if p.plan[i] >= from and p.plan[i] < to and p.plan[i - 1] != p.plan[i + 2]:
				counts[p.plan[i]] = int(counts.get(p.plan[i], 0)) + 1
	var best := Vector2i(from, 0)
	for m: int in counts:
		if int(counts[m]) > best.y or (int(counts[m]) == best.y and m < best.x):
			best = Vector2i(m, int(counts[m]))
	return best


## Where the most of them will pass: the way of everyone setting off within [from, to) (minutes of the day), routed
## round the houses as the residents route them, counted in 3 m cells; the busiest cell clear of houses and over 6 m
## from where they are going (on the way, not at the door).
func flow_point(from: int, to: int) -> Vector2:
	var v = VillageSession.village
	var reg = _live.registry
	var cells := {}
	var points := {}              # cell -> the way's points in it
	var ends: Array[Vector2] = []
	for id: int in reg.bodies:
		var p = v.people[id]
		if not p.alive or not p.present:
			continue
		for i in range(3, p.plan.size(), 3):
			if p.plan[i] < from or p.plan[i] >= to or p.plan[i - 1] == p.plan[i + 2]:
				continue
			var a: Vector2 = reg.place(v.place_names[p.plan[i - 1]])
			var b: Vector2 = reg.place(v.place_names[p.plan[i + 2]])
			ends.append(b)
			var way: Array = [a] + Array(reg.route(a, b))
			var mine := {}
			for j in range(1, way.size()):
				var steps := int((way[j - 1] as Vector2).distance_to(way[j])) + 1
				for k in steps + 1:
					var q: Vector2 = (way[j - 1] as Vector2).lerp(way[j], float(k) / steps)
					var cell := Vector2i(floori(q.x / 3.0), floori(q.y / 3.0))
					mine[cell] = true
					points.get_or_add(cell, []).append(q)
			for cell: Vector2i in mine:
				cells[cell] = int(cells.get(cell, 0)) + 1
	var best := Vector2.INF
	var best_cell := Vector2i.ZERO
	var most := 0
	for cell: Vector2i in cells:
		var at := (Vector2(cell) + Vector2(0.5, 0.5)) * 3.0
		if int(cells[cell]) <= most or reg._router._blocked(at):
			continue
		var by_end := false
		for e in ends:
			if at.distance_to(e) < 6.0:
				by_end = true
				break
		if not by_end:
			most = int(cells[cell])
			best = at
			best_cell = cell
	if best == Vector2.INF:
		return reg.place("square")
	# on the way itself (the ways run along the same lines round the houses): the point nearest the cell's middle way
	var mean := Vector2.ZERO
	for q: Vector2 in points[best_cell]:
		mean += q
	mean /= float(points[best_cell].size())
	for q: Vector2 in points[best_cell]:
		if q.distance_to(mean) < best.distance_to(mean):
			best = q
	return best


func stand_at(at: Vector2) -> void:
	_player.global_position = Vector3(at.x, _shape.height_at(at.x, at.y) + 0.05, at.y)
	_player.velocity = Vector3.ZERO
	get_tree().call_group("camera_rig", "snap")
	await frames(10)


## One window: the watch runs `seconds` of real time. The frame sequence starts `shots_at` seconds in (-1: the caller
## starts it). `during` runs alongside from the start (a swing). -> the window's summary.
## `judged_from`: the first stage whose targets apply to this window (scenes and reactions move on the mover in stage 2).
func watch_window(watch: Node, window: String, seconds: float, shots_at: float, during := Callable(), judged_from := 1) -> Dictionary:
	clear_creatures()
	_player.heal_full()
	watch.begin(window)
	if during.is_valid():
		during.call()
	var t := 0.0
	var tidy := 0.0
	var shot := shots_at < 0.0
	while t < seconds:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		tidy += dt
		if tidy > 4.0:
			tidy = 0.0
			clear_creatures()
			if _player.health < _player.MAX_HEALTH:
				_player.heal_full()
		if not shot and t >= shots_at:
			shot = true
			sequence(window)          # alongside the watch, not awaited
	var s: Dictionary = watch.summary()
	watch.stop()
	print("MOTION %s %s" % [window, JSON.stringify(s)])
	_keep_line("motion.txt", "MOTION %s %s" % [window, JSON.stringify(s)])   # (a phone's log cuts lines at 1023 bytes)
	if targets >= judged_from:
		var missed: Array[String] = MotionWatch.misses(s, targets)
		for m in missed:
			check(false, "%s: %s" % [window, m])
		if missed.is_empty():
			check(true, "%s meets every target due by stage %d" % [window, targets])
	return s


## For the look board: one frame of the game's own camera (what the player sees), then six from a camera 7 m off the
## busiest spot (or `focus`), half a second apart, close enough to see feet and bodies.
func sequence(window: String, focus := Vector3.INF) -> void:
	if not pixels:
		return
	if window == "blow":
		await get_tree().create_timer(0.2).timeout     # (a saved frame stalls one: never the one a blow's flinch is timed on)
	var label := "%s-game" % window
	var seen := {}                # image hashes: a hidden or minimised window stops drawing, and every frame is the same
	seen[_board_frame(label)] = true
	if focus == Vector3.INF:
		focus = densest_spot()
	var cam := Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	cam.global_position = clear_eye(focus, 7.0, 3.2)
	cam.look_at(focus + Vector3(0.0, 0.8, 0.0))
	cam.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	for k in 6:
		label = "%s-%.1f" % [window, k * 0.5]
		seen[_board_frame(label)] = true
		await get_tree().create_timer(0.5).timeout
	get_tree().current_scene.get_node("CameraRig").camera.make_current()
	cam.queue_free()
	check(seen.size() >= 3, "%s: the look board's frames were drawn live (%d different of 7; the window must stay visible)" % [window, seen.size()])


## One frame for the look board, saved and listed. -> the image's hash.
func _board_frame(label: String) -> int:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(label + ".png"))
	_listing.append(label)
	return hash(img.get_data())


## Where the people near the player are thickest: the drawn body within 20 m with the most others within 4 m.
func densest_spot() -> Vector3:
	var reg = _live.registry
	var best := _player.global_position
	var most := -1
	for id: int in reg.bodies:
		var body: Node3D = reg.bodies[id]
		if not body.is_visible_in_tree() or body.global_position.distance_to(_player.global_position) > 20.0:
			continue
		var near := 0
		for other: int in reg.bodies:
			var o: Node3D = reg.bodies[other]
			if other != id and o.is_visible_in_tree() and o.global_position.distance_to(body.global_position) < 4.0:
				near += 1
		if near > most:
			most = near
			best = body.global_position
	return best


func rite_run() -> void:
	var triple := Fixtures._rite()
	if triple.is_empty():
		print("PROBE FAIL no rite fixture")
		return
	var v = triple[0]
	var e: Dictionary = triple[1]
	var old := get_tree().current_scene.get_node("VillageLive")
	old._close()
	get_tree().current_scene.remove_child(old)
	old.queue_free()
	VillageSession.village = v
	_live = load("res://scripts/studio/village/live.gd").new()
	_live.name = "VillageLive"
	get_tree().current_scene.add_child(_live)
	_live._open(e)
	var st := Runtime.staging(v, _live._event)
	Runtime.advance(v, int(e.from) + 20)
	_live._stage._player = null
	_live._stage.skip_to(float(int(v.runtime.now) - int(st.day) * 1440))
	_live._stage._player = _player
	await frames(60)
	_freeze = true
	Controls.locked = false
	VillageSession.active = true
	Inventory.add("wood", 2)
	var leader: Node3D = _live.registry.bodies[_live._stage._authority.id]
	await stand_near(leader)
	var panel := await press_act_and_read("rite-1-leader")
	check(panel != null, "talking to the leader opens the screen")
	if panel != null:
		var labels := button_labels(panel)
		print("PROBE leader options: ", labels)
		check(labels.has("I'll make an offering (1 wood)"), "the leader offers the gesture")
		press_button(panel, "I'll make an offering (1 wood)")
		await frames(30)
		await shot("rite-2-answer")
		print("PROBE leader answers: ", panel._text.text)
		await close_talk(panel)
