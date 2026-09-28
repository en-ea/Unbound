extends Node
## Dev-only command-line helpers (after `--`):
##   --shot=path.png   save a screenshot after ~180 frames (or --shotframe=N), then quit
##   --time=0.5        start at this time of day
##   --walk=x,y        hold the joystick in this direction
##   --at=x,z          start the player at this spot
##   --zoom=5          camera distance (for close-up checks)
##   --picker          open the look picker
##   --showcase        line up one of every tree/bush model in front of the player
##   --gathertest      stand by the nearest tree and chop it (checks tools, hits, drops)
##   --fighttest       stand by a boar and fight it (prints its health and the loot)
##   --view=d,pitch    camera distance and pitch (e.g. 5,-12 for a side-on look at animations)
##   --lineup          stand every outfit preset in a row in front of the camera
##   --title           keep the title screen (otherwise any dev argument skips it)
##   --touchtest       fake a finger drag on the left half, print the result, quit
##   --craft / --bag   open the workbench / Bag screen with a few items to show
##   --lab             go straight to the build lab

@export var day_night: Node

var _shot_path := ""
var _shot_frame := 180
var _frames := 0
var _touch_test := false
var _start_at := Vector2.INF
var _showcase := false
var _lineup := false
var _gather_test := false
var _fight_test := false
var _gather_offset := Vector3(0, 0.3, -1.3)


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and not args.has("--title"):
		get_node("../HUD").start_game.call_deferred(true)
	for arg in args:
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shotframe="):
			_shot_frame = int(arg.trim_prefix("--shotframe="))
		elif arg.begins_with("--lab"):                    # --lab, or --lab=x,z to stand at a spot in it
			get_tree().call_group.call_deferred("build_lab", "enter")
			if arg.begins_with("--lab="):
				var v := arg.trim_prefix("--lab=").split(",")
				get_tree().create_timer(0.2).timeout.connect(func() -> void:
					(get_node("../Player") as Node3D).global_position = Vector3(float(v[0]), -299.4, float(v[1]))
					get_node("../CameraRig").snap())
		elif arg == "--craft" or arg == "--bag":      # open a screen (with some items to show)
			for item in ["wood", "stone", "flint", "copper", "hide", "apple", "resin"]:
				Inventory.add(item, 5)
			var hud := get_node("../HUD")
			(hud.open_crafting if arg == "--craft" else hud.open_bag).call_deferred()
		elif arg.begins_with("--time="):
			day_night.time_of_day = float(arg.trim_prefix("--time="))
		elif arg.begins_with("--walk="):
			var v := arg.trim_prefix("--walk=").split(",")
			Controls.joystick = Vector2(float(v[0]), float(v[1]))
		elif arg.begins_with("--at="):
			var v := arg.trim_prefix("--at=").split(",")
			_start_at = Vector2(float(v[0]), float(v[1]))
		elif arg.begins_with("--zoom="):
			get_node("../CameraRig").set_distance.call_deferred(float(arg.trim_prefix("--zoom=")))
		elif arg.begins_with("--open="):                  # --open=cook / trade / project:smithy
			var bits := arg.trim_prefix("--open=").split(":")
			var props := {"mode": bits[0]}
			if bits.size() > 1:
				props["project"] = bits[1]
			get_node("../HUD").open_station.call_deferred(props)
		elif arg.begins_with("--cheats"):                 # the settings test menu; --cheats=code shows the code page
			var hud := get_node("../HUD")
			hud._modal.call_deferred(hud.SETTINGS_PANEL, {"_page": "code" if arg.ends_with("=code") else "cheats"})
		elif arg == "--home":                             # own the home, a few pieces built, build mode on
			Home.house = "lodge"
			Home.pieces = [{"id": "campfire", "x": -44.0, "z": 42.0, "turn": 0.0}, {"id": "bench", "x": -44.0, "z": 44.5, "turn": 0.0},
				{"id": "flower_bed", "x": -36.0, "z": 37.0, "turn": 0.0}, {"id": "lantern_post", "x": -33.5, "z": 41.0, "turn": 0.0},
				{"id": "fence", "x": -47.0, "z": 45.0, "turn": 0.0}, {"id": "fence", "x": -45.0, "z": 45.0, "turn": 0.0}]
			Home.changed.emit()
			get_node("../HUD").start_build_mode.call_deferred()
		elif arg == "--rich":                             # coins and a pile of materials for testing
			Money.earn(500)
			for item: String in ["raw_meat", "mushroom", "apple", "flower", "wood", "glowcap", "stone", "pinewood", "iron", "stew", "roast_meat"]:
				Inventory.add(item, 25)
		elif arg == "--picker":
			get_node("../HUD").open_look_picker.call_deferred()
		elif arg.begins_with("--pickertab="):              # e.g. hair:braid,marks:freckles,extra:glasses
			var bits := arg.trim_prefix("--pickertab=").split("/")
			var hud := get_node("../HUD")
			hud.open_look_picker.call_deferred()
			var tab := bits[0]
			var set_parts := bits[1] if bits.size() > 1 else ""
			get_tree().create_timer(0.3).timeout.connect(func() -> void:
				var picker := hud.find_children("*", "Control", true, false).filter(func(c: Node) -> bool: return c.has_method("_show_tab"))
				if picker.is_empty():
					return
				for pair in set_parts.split(",", false):
					var kv := pair.split(":")
					picker[0]._visual.hero_look.parts[kv[0]] = kv[1]
				picker[0]._changed()
				picker[0]._show_tab(tab))
		elif arg == "--fighttest":
			_fight_test = true
		elif arg.begins_with("--gatheroffset="):
			var v := arg.trim_prefix("--gatheroffset=").split(",")
			_gather_offset = Vector3(float(v[0]), 0.3, float(v[1]))
		elif arg == "--gathertest":
			_gather_test = true
		elif arg == "--lineup":
			_lineup = true
		elif arg == "--showcase":
			_showcase = true
		elif arg.begins_with("--view="):
			var v := arg.trim_prefix("--view=").split(",")
			get_node("../CameraRig").set_view.call_deferred(float(v[0]), float(v[1]), Vector3.ZERO, 0.01)
		elif arg == "--touchtest":
			_touch_test = true
	if _shot_path == "" and not _touch_test and not _gather_test and not _fight_test:
		set_process(false)


func _process(_delta: float) -> void:
	_frames += 1
	if _gather_test:
		_run_gather_test()
	if _fight_test:
		_run_fight_test()
	if _frames == 3 and _lineup:
		_build_lineup()
	if _frames == 3 and _showcase:
		_build_showcase()
	if _frames == 2 and _start_at != Vector2.INF:
		var player := get_node("../Player") as Node3D
		player.global_position = Vector3(_start_at.x, WorldShape.new().height_at(_start_at.x, _start_at.y) + 0.3, _start_at.y)
		get_node("../CameraRig").snap()
	if _touch_test:
		_run_touch_test()
		return
	if _frames == _shot_frame and _shot_path != "":
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _run_touch_test() -> void:
	var start := Vector2(250, 500)
	if _frames == 30:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = start
		t.pressed = true
		Input.parse_input_event(t)
	elif _frames > 30 and _frames < 40:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = start + Vector2(0, -10) * (_frames - 30)
		d.relative = Vector2(0, -10)
		Input.parse_input_event(d)
	elif _frames == 45:
		print("TOUCHTEST joystick=", Controls.joystick, " player=", get_node("../Player").global_position)
	elif _frames == 90:
		print("TOUCHTEST joystick=", Controls.joystick, " player=", get_node("../Player").global_position)
		get_tree().quit()


func _build_showcase() -> void:
	var scatter := get_node("../Scatter")
	var player := get_node("../Player") as Node3D
	var models: Array[String] = []
	for f in DirAccess.get_files_at("res://assets/nature"):
		if f.ends_with(".glb"):
			models.append(f.get_basename())
	for i in models.size():
		var mi := MeshInstance3D.new()
		mi.mesh = scatter._mesh_for(models[i], "tree")
		add_child(mi)
		var col := i % 6
		var row := i / 6
		mi.global_position = player.global_position + Vector3((col - 2.5) * 4.5, 0, -6.0 - row * 6.0)


func _run_gather_test() -> void:
	var player := get_node("../Player") as Node3D
	var gatherer := player.get_node("Gatherer")
	if _frames == 30:
		# Stand just north of the nearest tree (behind it, so it also tests the see-through fade).
		var best := -1
		var best_d := INF
		for id in 4000:
			if not WorldResources.has_method("get_node_data"):
				break
			if id >= WorldResources._nodes.size():
				break
			var n: Dictionary = WorldResources.get_node_data(id)
			if n["type"] != "tree":
				continue
			var near_boar := false
			for h: Vector2 in preload("res://scripts/creatures/enemies.gd").HOMES["meadow"]["boars"]:
				if Vector2(n["pos"].x, n["pos"].z).distance_to(h) < 16.0:
					near_boar = true
			if near_boar:
				continue
			var d: float = (n["pos"] as Vector3).distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = id
		var at: Vector3 = WorldResources.get_node_data(best)["pos"]
		player.global_position = at + _gather_offset
		get_node("../CameraRig").snap()
	if _frames in [40, 70, 100, 165]:
		if _frames == 40:
			print("GATHERTEST at ", player.global_position.snapped(Vector3.ONE * 0.1), " target ", gatherer.target, " verb ", gatherer.verb, " locked ", Controls.locked)
		gatherer.act()
	if _frames == 179 or _frames == 260:
		print("GATHERTEST frame ", _frames, " inventory ", Inventory.items().map(func(i: String) -> String: return "%s x%d" % [i, Inventory.count(i)]))
		if _shot_path == "" and _frames == 260:
			get_tree().quit()


func _run_fight_test() -> void:
	var player := get_node("../Player") as Node3D
	var boars := get_tree().get_nodes_in_group("enemy")
	if boars.is_empty():
		return
	var boar: Node3D = boars[0]
	if _frames == 20:
		player.global_position = boar.global_position + Vector3(0, 0.3, 1.6)
		get_node("../CameraRig").snap()
	if _frames > 30 and _frames % 12 == 0 and _frames < 200:
		if boar.is_alive():
			player.global_position = boar.global_position + Vector3(0, 0.3, 1.5)
		player.act()
	if _frames in [60, 120, 199, 300]:
		print("FIGHTTEST frame ", _frames, " boar health ", boar.health, " state ", boar.state,
			" inventory ", Inventory.items().map(func(i: String) -> String: return "%s x%d" % [i, Inventory.count(i)]))
	if _frames == 300 and _shot_path == "":
		get_tree().quit()


func _build_lineup() -> void:
	var player := get_node("../Player") as Node3D
	player.visible = false
	var names := CharacterLook.OUTFITS.keys()
	for i in names.size():
		var v := CharacterVisual.new()
		v.hero_look = CharacterLook.new()
		v.hero_look.outfit = names[names.size() - 1]
		v.hero_look.cycle_outfit(i + 1)
		v.hero_look.parts["eyes"] = ["calm", "happy", "fierce", "bright", "sleepy"][i]
		add_child(v)
		v.global_position = player.global_position + Vector3((i - 2) * 1.1, 0, 0)
