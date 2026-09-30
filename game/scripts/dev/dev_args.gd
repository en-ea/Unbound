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
##   --telltest        a boar frozen mid-warning (glint), a heavy blow's shockwave, stamina part used (screenshots)
##   --view=d,pitch    camera distance and pitch (e.g. 5,-12 for a side-on look at animations)
##   --cam=d,pitch,fov[,yaw]  try another camera framing (distance, pitch, lens, turn), with a far view
##   --census / --hudcost  print draw calls, meshes per world part, and each HUD piece's draw calls
##   --hide=Scatter,HUD    hide parts of the scene (cost checks); --noshadow turns sun shadows off
##   --lineup[=N]      stand 7 outfit presets (from the Nth) in a row in front of the camera
##   --outfit=Mage     wear a ready-made outfit
##   --title           keep the title screen (otherwise any dev argument skips it)
##   --touchtest       fake a finger drag on the left half, print the result, quit
##   --craft / --bag   open the workbench / Bag screen with a few items to show
##   --lab             go straight to the build lab
##   --house=hill      own a home (outside, standing wherever --at puts you)
##   --inside[=hill]   own a home (lodge, or the house named) and start inside it; --furnish opens the furnish bar

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
var _tell_test := false
var _lock_mock := false
var _lineup_from := 0
var _lineup_marks := false
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
		elif arg == "--lab" or arg.begins_with("--lab="):  # --lab, or --lab=x,z to stand at a spot in it
			var spot := Vector2(0.0, 7.5)
			if arg.begins_with("--lab="):
				var v := arg.trim_prefix("--lab=").split(",")
				spot = Vector2(float(v[0]), float(v[1]))
			get_tree().call_group.call_deferred("build_lab", "enter", spot)
			if "--labtest" in OS.get_cmdline_user_args():      # spawn one of everything, then clear it (prints counts)
				get_tree().create_timer(1.0).timeout.connect(func() -> void:
					var lab := get_tree().get_first_node_in_group("build_lab")
					var before := WorldResources.node_count()
					for k in ["boar", "wolf", "shadow", "tree", "pine", "apple", "rock", "copper", "iron", "chest", "gear", "sword"]:
						lab.spawn(k)
					print("LABTEST nodes ", before, " -> ", WorldResources.node_count(), " spawned children ", lab._spawns.get_child_count())
					get_tree().create_timer(1.0).timeout.connect(func() -> void:
						lab.clear_spawns()
						print("LABTEST after clear ", WorldResources.node_count())))
			if "--labmenu" in OS.get_cmdline_user_args():      # and open the lab menu
				get_tree().create_timer(0.5).timeout.connect(func() -> void:
					get_node("../HUD").open_station({"mode": "lab", "lab": get_tree().get_first_node_in_group("build_lab")}))
			for v_arg in OS.get_cmdline_user_args():             # --villager=wren[,far]: show one close up
				if v_arg.begins_with("--villager="):
					var vbits := v_arg.trim_prefix("--villager=").split(",")
					get_tree().create_timer(0.6).timeout.connect(func() -> void:
						var lab := get_tree().get_first_node_in_group("build_lab")
						lab.spin = false
						lab.show_villager(Npcs.NPCS.keys().find(vbits[0]))
						get_node("../HUD").open_station({"mode": "lab", "lab": lab})
						get_tree().create_timer(0.2).timeout.connect(func() -> void:
							for m in get_node("../HUD").find_children("*", "Control", true, false):
								if m.has_method("_frame_villager"):
									m._show_villager_name()
									m._frame_villager(vbits.size() < 2)))
		elif arg == "--craft" or arg == "--bag":      # open a screen (with some items to show)
			for item in ["wood", "stone", "flint", "copper", "hide", "apple", "resin"]:
				Inventory.add(item, 5)
			var hud := get_node("../HUD")
			(hud.open_crafting if arg == "--craft" else hud.open_bag).call_deferred()
		elif arg == "--lootcard":                      # show the found-gear card for a Legendary sword
			var sword := Gear._tool(3, Loot.LEGENDARY, Loot.roll_bonuses("weapon", Loot.LEGENDARY))
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				Gear.take("sword", sword)
				get_tree().call_group("hud", "found_tool", "sword", sword))
		elif arg == "--loot":                          # a sword of every rarity, an Epic armour set, and --bag opens on Gear
			for r in Loot.MYTHIC + 1:
				Gear.take("sword", Gear._tool(3, r, Loot.roll_bonuses("weapon", r)))
			for slot: String in Armor.SLOTS:
				Armor.give(slot, Armor.piece(3, Loot.EPIC, Loot.roll_bonuses("armor", Loot.EPIC)))
			get_tree().create_timer(0.5).timeout.connect(func() -> void:
				for panel in get_tree().root.find_children("*", "Control", true, false):
					if panel.get("_filter") != null and panel.has_method("_refresh_gear_grid"):
						panel._filter = "gear"
						panel._selected = "gear:sword:0"
						panel._refresh())
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
			if bits.size() > 1 and bits[0] == "project":
				props["project"] = bits[1]
			elif bits.size() > 1:
				props["_tab"] = int(bits[1])            # --open=trade:1 opens the Sell tab
			get_node("../HUD").open_station.call_deferred(props)
		elif arg.begins_with("--cheats"):                 # the settings test menu; --cheats=code shows the code page
			var hud := get_node("../HUD")
			hud._modal.call_deferred(hud.SETTINGS_PANEL, {"_page": "code" if arg.ends_with("=code") else "cheats"})
		elif arg.begins_with("--bagpick="):               # the Bag with an item selected
			var hud := get_node("../HUD")
			hud._modal.call_deferred(hud.INVENTORY_PANEL, {"_selected": arg.trim_prefix("--bagpick=")})
		elif arg.begins_with("--house="):
			Home.house = arg.trim_prefix("--house=")
			Home.furniture = Home.STARTER.duplicate(true)
			Home.changed.emit()
		elif arg.begins_with("--inside"):                 # own a home and start inside it
			Home.house = arg.trim_prefix("--inside=") if arg.begins_with("--inside=") else "lodge"
			Home.furniture = Home.STARTER.duplicate(true)
			Home.changed.emit()
			Home.furniture_changed.emit()
			get_tree().call_group.call_deferred("home_interior", "enter", true)
			if "--furnish" in OS.get_cmdline_user_args():
				get_tree().create_timer(0.5).timeout.connect(func() -> void: get_node("../HUD").start_build_mode(true))
		elif arg == "--home":                             # own the home, a few pieces built, build mode on
			Home.house = "lodge"
			Home.pieces = [{"id": "campfire", "x": -44.0, "z": 42.0, "turn": 0.0}, {"id": "bench", "x": -44.0, "z": 44.5, "turn": 0.0},
				{"id": "flower_bed", "x": -36.0, "z": 37.0, "turn": 0.0}, {"id": "lantern_post", "x": -33.5, "z": 41.0, "turn": 0.0},
				{"id": "fence", "x": -47.0, "z": 45.0, "turn": 0.0}, {"id": "fence", "x": -45.0, "z": 45.0, "turn": 0.0}]
			Home.changed.emit()
			get_node("../HUD").start_build_mode.call_deferred()
		elif arg == "--rich":                             # coins and a pile of materials for testing
			Money.earn(500)
			for item: String in ["raw_meat", "mushroom", "apple", "flower", "wood", "glowcap", "stone", "pinewood", "iron", "stew", "roast_meat", "tobacco", "cigarette"]:
				Inventory.add(item, 25)
		elif arg.begins_with("--talk"):                   # --talk: Wren's talk screen; --talk=quest: with his quest taken
			if arg == "--talk=quest":
				Quests.accept("wren_smokes")
				Inventory.add("tobacco", 2)
			if arg == "--talk=done":                      # hand it in after a moment, to see the reward banner
				Quests.accept("wren_smokes")
				Inventory.add("cigarette", 3)
				get_tree().create_timer(1.0).timeout.connect(func() -> void: Quests.turn_in("wren_smokes"))
				continue
			get_node("../HUD").open_dialogue.call_deferred("wren")
		elif arg == "--smoke":                            # some cigarettes, and light one
			Inventory.add("cigarette", 5)
			Inventory.add("tobacco", 6)
			get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().call_group("player", "smoke"))
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
		elif arg == "--telltest":
			_tell_test = true
		elif arg == "--lockmock":                     # with --telltest: a mock lock-on marker on the boar
			_lock_mock = true
		elif arg.begins_with("--gatheroffset="):
			var v := arg.trim_prefix("--gatheroffset=").split(",")
			_gather_offset = Vector3(float(v[0]), 0.3, float(v[1]))
		elif arg == "--gathertest":
			_gather_test = true
		elif arg.begins_with("--outfit="):              # --outfit=Mage: wear a ready-made outfit
			var pv: CharacterVisual = get_node("../Player/Visual")
			pv.hero_look.set_outfit(arg.trim_prefix("--outfit="))
			pv.apply_hero_look.call_deferred()
		elif arg.begins_with("--lineup"):                # --lineup, or --lineup=7 to start at the 8th outfit
			if arg == "--lineup=marks":                    # one character per marking, faces close
				_lineup_marks = true
			elif arg.begins_with("--lineup="):
				_lineup_from = int(arg.trim_prefix("--lineup="))
			_lineup = true
		elif arg == "--showcase":
			_showcase = true
		elif arg.begins_with("--view="):
			var v := arg.trim_prefix("--view=").split(",")
			get_node("../CameraRig").set_view.call_deferred(float(v[0]), float(v[1]), Vector3.ZERO, 0.01)
		elif arg.begins_with("--cam="):               # --cam=d,pitch,fov[,yaw]: try other camera framings
			var v := arg.trim_prefix("--cam=").split(",")
			var rig := get_node("../CameraRig")
			rig.set_view.call_deferred(float(v[0]), float(v[1]), Vector3.ZERO, 0.01, float(v[2]))
			rig.camera.far = 600.0
			if v.size() > 3:
				rig.turn.call_deferred(deg_to_rad(float(v[3])))
		elif arg.begins_with("--hide="):              # hide parts of the world (cost checks): --hide=Scatter,Village
			for n in arg.trim_prefix("--hide=").split(","):
				get_node("../" + n).visible = false
		elif arg == "--noshadow":                     # cost check: no sun shadows
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				for l in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
					(l as DirectionalLight3D).shadow_enabled = false)
		elif arg == "--hudcost":                      # cost check: draw calls of each HUD piece
			get_tree().create_timer(3.0).timeout.connect(_hud_cost)
		elif arg == "--census":                       # print how many meshes each part of the world adds
			get_tree().create_timer(3.0).timeout.connect(_census)
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
	if _tell_test:
		_run_tell_test()
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
	if _frames == _shot_frame and OS.get_cmdline_user_args().has("--census"):
		print("DRAWS ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
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


func _run_tell_test() -> void:
	var player := get_node("../Player") as Node3D
	var boars := get_tree().get_nodes_in_group("enemy")
	if boars.is_empty():
		return
	var boar: Node3D = boars[0]
	if _frames == 20:
		player.global_position = boar.global_position + Vector3(1.0, 0.3, 3.0)
		get_node("../CameraRig").snap()
		if _lock_mock:
			_add_lock_mock(boar)
	if _frames > 20 and player.stamina.value > 45.0:
		player.stamina._spend(player.stamina.value - 45.0)
	if boar.state == Boar.State.WINDUP:
		boar._t = minf(boar._t, 0.6)        # hold the warning just after the aim locks
		boar.visual._glint.visible = true   # with its glint mid-flare
		boar.visual._glint_t = 0.35
	if _frames > 20:                        # and a heavy blow's shockwave, sword glowing
		var f: Node = player.get_node("Fighter")
		f._shock.global_position = player.global_position + Vector3(0, 0.08, 1.1)
		f._shock.visible = true
		f._shock_t = 0.3
		player.visual.show_tool("sword")
		player.visual.charge_tool(1.0)


## A look-board mock of a lock-on marker: a ring on the ground and a small arrow over the target.
func _add_lock_mock(target: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.15)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.2
	ring.mesh = torus
	ring.material_override = mat
	ring.position = Vector3(0, 0.05, 0)
	target.add_child(ring)
	var arrow := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.22
	cone.bottom_radius = 0.0
	cone.height = 0.4
	cone.radial_segments = 4
	arrow.mesh = cone
	arrow.material_override = mat
	arrow.position = Vector3(0, 2.0, 0)
	target.add_child(arrow)


func _hud_cost() -> void:
	var info := RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
	for c in get_node("../HUD").get_children():
		if not c is CanvasItem or not c.visible:
			continue
		await get_tree().process_frame
		await get_tree().process_frame
		var before := RenderingServer.get_rendering_info(info)
		c.visible = false
		await get_tree().process_frame
		await get_tree().process_frame
		var after := RenderingServer.get_rendering_info(info)
		c.visible = true
		var what: String = c.get_script().resource_path.get_file() if c.get_script() else c.get_class()
		print("HUDCOST ", what, " ", before - after)


func _census() -> void:
	var main := get_parent()
	for top in main.get_children():
		var meshes := top.find_children("*", "MeshInstance3D", true, false).size()
		var mms := top.find_children("*", "MultiMeshInstance3D", true, false).size()
		var surf := 0
		for m in top.find_children("*", "MeshInstance3D", true, false):
			if (m as MeshInstance3D).mesh:
				surf += (m as MeshInstance3D).mesh.get_surface_count()
		if meshes + mms > 0:
			print("CENSUS ", top.name, ": ", meshes, " meshes (", surf, " surfaces), ", mms, " multimeshes")
		if top.name == "Village":
			for c in top.get_children():
				var n := c.find_children("*", "MeshInstance3D", true, false).size()
				if n >= 5:
					print("   ", c.name, " ", c.get_class(), ": ", n)


func _build_lineup() -> void:
	var player := get_node("../Player") as Node3D
	player.visible = false
	var names := CharacterLook.OUTFITS.keys().slice(_lineup_from, _lineup_from + 7)
	var marks: Array = CharacterLook.PARTS["marks"].slice(1)
	if _lineup_marks:
		names = []
		for m: String in marks:
			names.append("Wanderer")
	for i in names.size():
		var v := CharacterVisual.new()
		v.hero_look = CharacterLook.new()
		v.hero_look.set_outfit(names[i])
		v.hero_look.parts["eyes"] = ["calm", "happy", "fierce", "bright", "sleepy"][i % 5]
		if _lineup_marks:
			v.hero_look.parts["marks"] = marks[i]
			v.hero_look.parts["eyes"] = "calm"
			v.hero_look.colors["Marks"] = 1
		add_child(v)
		var gap := 0.5 if _lineup_marks else 1.1
		v.global_position = player.global_position + Vector3((i - (names.size() - 1) / 2.0) * gap, 0, 0)
	if _lineup_marks:
		get_node("../CameraRig").set_view(3.6, -3.0, Vector3(0, 1.1, 0), 0.01)
