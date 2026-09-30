extends Node
## Programmatic probe for the people the player can meet (Pass 2, helper A). It plays the game as a player does:
## the player is set down beside a resident and the real action button is pressed (player.act), the real talk
## screen opens, the real buttons are pressed. Screenshots are saved and state is printed (PROBE lines), so the
## run can be checked without pixels first.
##
##   godot --path game --resolution 1560x720 -- --studio=village/live --people-probe=talk|hearing|daily|rite
##         --people-shots=DIR --test-save=NAME
##
## talk     three different residents at ordinary work, talked to; the meeting is recorded; the screen closes
## hearing  a hearing: a witness ("What did you see?"), the trace spot (Inspect), the judge (testify, a word in private)
## daily    the same village at 07:12, 10:00, 12:30, 18:30, 23:30 and 06:10: work, meals, chatting, indoors, the door
## rite     the leader of a rite offers the gesture
## The village session is the game's own; only the clock is moved (Runtime.advance), as time passing would.

const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const Lines := preload("res://scripts/studio/village/resident_lines.gd")
const React := preload("res://scripts/studio/village/resident_react.gd")
const Fixtures := preload("res://scripts/studio/village/sim/actions_test.gd")

var mode := "talk"
var dir := "user://people-shots"
var failures: Array[String] = []
var _player: Node3D
var _hud: Node
var _live: Node
var _shape := WorldShape.new()


static func on_device(tree: SceneTree) -> void:
	var probe: Node = (load("res://scripts/studio/village/people_probe.gd") as GDScript).new()
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--people-probe="):
			mode = arg.trim_prefix("--people-probe=")
		elif arg.begins_with("--people-shots="):
			dir = arg.trim_prefix("--people-shots=")
	DirAccess.make_dir_recursive_absolute(dir)
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	print(("PROBE PASS " if ok else "PROBE FAIL ") + message)
	if not ok:
		failures.append(message)


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func shot(label: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(dir.path_join(label + ".png"))
	print("PROBE shot %s (err %d) minute %d" % [label, err, int(VillageSession.village.runtime.now) % 1440])


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
	while _live.registry.bodies.size() < _alive_count():
		await get_tree().process_frame
	await frames(30)
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
	print("PROBE complete failures=%d" % failures.size())
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
func stand_near(body: Node3D, gap := 1.0) -> void:
	var best := body.global_position + Vector3(0.0, 0.0, gap)
	var best_score := -INF
	for k in 12:
		var a := TAU * k / 12.0
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
	Controls.locked = false
	VillageSession.active = true
	Money.load_data(31)
	Inventory.add("wood", 2)
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
		var at: Vector2 = _live.registry.place(params.place)
		_player.global_position = Vector3(at.x + 0.4, _shape.height_at(at.x, at.y), at.y + 1.0)
		get_tree().call_group("camera_rig", "snap")
		await frames(6)
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
		var at: Vector2 = _live.registry.place(plant.place)
		_player.global_position = Vector3(at.x + 0.4, _shape.height_at(at.x, at.y), at.y + 1.0)
		get_tree().call_group("camera_rig", "snap")
		await frames(6)
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
		if pick != "":
			for id: int in _live.registry.bodies:
				var body: Node3D = _live.registry.bodies[id]
				var d := View.describe(v, id)
				if body.visible and d.activity.verb == stop[2] and d.activity.place == pick and not _live.registry.borrowed.has(id):
					subject = body
					subject_id = id
					break
		if subject != null:
			var stand := subject.global_position + Vector3(0.6, 0.0, 3.2)
			_player.global_position = Vector3(stand.x, _shape.height_at(stand.x, stand.z) + 0.05, stand.z)
			get_tree().call_group("camera_rig", "snap")
			var rig := get_tree().current_scene.get_node("CameraRig")
			var off := subject.global_position - _player.global_position + Vector3(0.0, 1.0, 0.0)
			rig.set_view(4.6, -9.0, off, 0.01)
			await frames(25)
			print("PROBE close-up %s: %s (%s) plays %s, tool %s, faces %s" % [stop[0], v.people[subject_id].name, v.people[subject_id].role,
				_live.registry._picks.get(subject_id, {}).get("loop", "?"), _live.registry._picks.get(subject_id, {}).get("tool", ""), _live.registry._faces.get(subject_id, "-")])
			print("PROBE   borrowed=%s applied=%s picked_at=%s now=%s moving_trip=%s" % [_live.registry.borrowed.has(subject_id), _live.registry._applied.get(subject_id, "-"),
				_live.registry._pick_minute.get(subject_id, -1), int(v.runtime.now), _live.registry.destinations.get(subject_id, {})])
			await shot(str(stop[0]) + "-close")
			rig.reset_view(0.01)
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
