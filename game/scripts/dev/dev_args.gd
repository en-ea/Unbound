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
##   --defencetest     a boar charges: parry the first, perfect-dodge the second (prints what happened)
##   --lab --packtest  three wolves against you swinging now and then (prints lowest health, states seen)
##   --telltest        a boar frozen mid-warning (glint), a heavy blow's shockwave, stamina part used (screenshots)
##   --view=d,pitch    camera distance and pitch (e.g. 5,-12 for a side-on look at animations)
##   --cam=d,pitch,fov[,yaw]  try another camera framing (distance, pitch, lens, turn), with a far view
##   --census / --hudcost  print draw calls, meshes per world part, and each HUD piece's draw calls
##   --hide=Scatter,HUD    hide parts of the scene (cost checks); --noshadow turns sun shadows off
##   --lineup[=N]      stand 7 outfit presets (from the Nth) in a row in front of the camera
##   --outfit=Mage     wear a ready-made outfit
##   --style=carved    the player (and a --lineup) in the carved character style
##   --title           keep the title screen (otherwise any dev argument skips it)
##   --touchtest       fake a finger drag on the left half, print the result, quit
##   --craft / --bag   open the workbench / Bag screen with a few items to show
##   --lab             go straight to the build lab
##   --house=hill      own a home (outside, standing wherever --at puts you)
##   --inside[=hill]   own a home (lodge, or the house named) and start inside it; --furnish opens the furnish bar
##   --kernel-bench    (studio branch) world-kernel conformance and timings, saved to user://studio-kernel.txt, then quit
##   --kernel-thread   (studio branch) the game's frame times with and without the kernel running on a worker thread
##   --studio=name     (studio branch) run a studio spike on the device (scripts/studio/<name>.gd), then quit
##   --frame=explore   (studio branch) a camera framing: explore, fight, build (today's), vantage
##   --fog=60,400      (studio branch) fog begin and end in metres
##   --turntable[=90]  (studio branch) spin the camera a full turn twice (deg/s), record frame times, quit

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
var _lineup_style := ""         # --style=carved
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
			if "--packtest" in OS.get_cmdline_user_args():     # three wolves against you swinging now and then (prints states)
				get_tree().create_timer(1.0).timeout.connect(func() -> void:
					var lab := get_tree().get_first_node_in_group("build_lab")
					for i in 3:
						lab.spawn("wolf")
					var player := get_node("../Player")
					var seen := {}
					var lowest: int = player.health
					for k in 60:
						await get_tree().create_timer(0.25).timeout
						if k % 2 == 0:
							player.act()
						lowest = mini(lowest, player.health)
						for w in get_tree().get_nodes_in_group("enemy"):
							seen[Wolf.State.keys()[w.state]] = true
					print("PACKTEST lowest health ", lowest, " now ", player.health, " states seen ", seen.keys())
					get_tree().quit())
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
			if WorldClock != null: # studio: merge - the one world clock owns time (day_night.gd reads it each frame): move it there
				WorldClock.advance_to_time(float(arg.trim_prefix("--time="))) # studio:
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
			elif bits.size() > 1 and bits[0] == "letting":    # --open=letting:3 (a village house to let)
				props["letting"] = int(bits[1])
			elif bits.size() > 1:
				props["_tab"] = int(bits[1])            # --open=trade:1 opens the Sell tab
			get_node("../HUD").open_station.call_deferred(props)
		elif arg.begins_with("--dungeon="):              # go straight down a dungeon: --dungeon=cannibal_den (dungeons/sites.gd)
			var parts := arg.trim_prefix("--dungeon=").split(":")    # --dungeon=cannibal_den:goal starts at the end room
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				var p := get_tree().get_first_node_in_group("player") as Node3D
				get_tree().call_group("dungeon", "enter", parts[0], p.global_position)
				if parts.size() > 1:
					get_tree().create_timer(1.5).timeout.connect(func() -> void: get_tree().call_group("dungeon", "jump_to", parts[1])))
		elif arg.begins_with("--homeverb="):              # with --visit: everyone home is sleeping / eating / at_home
			preload("res://scripts/world/home_folk.gd").dev_verb = arg.trim_prefix("--homeverb=")
		elif arg.begins_with("--visit="):                 # go into a village house: --visit=2 (with --time=0.95 they're home); 5 the mill, 3 4 6 lettings
			var house := int(arg.trim_prefix("--visit="))
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				var v: Node = get_parent().get_node("Village").find_children("*", "Node3D", false, false).filter(func(n: Node) -> bool: return n.has_method("visit"))[0]
				var d: Vector2 = preload("res://scripts/world/village.gd").door_of(house)
				var room: Dictionary = preload("res://scripts/world/village.gd").VISITS.get(house,
					{"feel": Lettings.HOUSES.get(house, {}).get("feel", "lantern"), "layout": "hearth"})
				v.visit(house, room["feel"], Vector3(d.x, 0, d.y), room["layout"])
				if "--homesay" in OS.get_cmdline_user_args():   # someone inside speaks (bubble check)
					get_tree().create_timer(1.0).timeout.connect(func() -> void:
						for n in get_tree().get_nodes_in_group("interactable"):
							if n.get("verb") == "Talk" and n.global_position.y < -200.0:
								n.interact()
								break))
		elif arg == "--elk":                          # you have a tamed elk and start riding it
			Hunting.elk = {"region": Region.current, "at": Vector2.ZERO, "yaw": 0.0}
			Hunting.elk_riding = true
		elif arg == "--bowtest":                      # with --lab: bow out, a boar, a power shot (screenshot mid-flight with --shotframe)
			Gear.weapon = "bow"
			Gear.changed.emit.call_deferred()
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				get_tree().get_first_node_in_group("build_lab").spawn("boar")
				get_tree().create_timer(0.6).timeout.connect(func() -> void: get_node("../Player").fighter.heavy()))
		elif arg == "--cinder":                       # a Pyromancer with Cinder at your shoulder (--cinder=3: her level)
			Classes.choose("pyromancer")
			Companions.owned["cinder"] = {"level": 1, "xp": 0}
			Companions.changed.emit()
		elif arg.begins_with("--cinder="):
			Classes.choose("pyromancer")
			Companions.owned["cinder"] = {"level": int(arg.trim_prefix("--cinder=")), "xp": 0}
			Companions.changed.emit()
		elif arg == "--tenant":                       # own the Hill House with Odo in it, asking for wood (and the wood in your bag)
			Lettings.owned[3] = 1
			Lettings.mood[3] = 60
			Lettings.asks[3] = ["wood", 8]
			Inventory.add("wood", 8)
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				var talk := Lettings.talk("tenant_odo")
				print("TENANT ", talk["text"], " | ", talk["options"].map(func(o: Dictionary) -> String: return o["label"]))
				print("TENANT after: ", talk["options"][0]["do"].call().get("text", ""), " | mood ", Lettings.mood[3], " rent ", Lettings.rent(3)))
		elif arg == "--stash":                        # the home stash screen (with --inside)
			get_tree().create_timer(1.5).timeout.connect(func() -> void: get_node("../HUD").open_stash())
		elif arg == "--bow":                          # the bow as your weapon (on your back outside fights)
			Gear.weapon = "bow"
			Gear.changed.emit.call_deferred()
		elif arg == "--bowdraw":                      # bow out, holding a full draw (a screenshot of the pose; --view=4,-8 side-on)
			Gear.weapon = "bow"
			Gear.changed.emit.call_deferred()
			get_tree().create_timer(1.6).timeout.connect(func() -> void:
				Controls.attack_key = true
				get_node("../Player").fighter._start_draw()
				if "--loose" in OS.get_cmdline_user_args():    # then let go: a full-draw shot
					get_tree().create_timer(1.2).timeout.connect(func() -> void: Controls.attack_key = false))
		elif arg == "--bountytest":                   # take the bounties, find and kill the wanted beast, claim
			add_child(preload("res://scripts/dev/bounty_test.gd").new())
		elif arg.begins_with("--bounties="):              # take this region's bounties: --bounties=2 takes two (with --open=bounty to see the board)
			var n := int(arg.trim_prefix("--bounties="))
			(func() -> void:
				var list: Array = Bounties.board(Region.current).duplicate()
				for i in mini(n, list.size()):
					Bounties.take(list[i])
				for b in Bounties.taken:
					print("BOUNTY %s | %s | %d coins" % [b["title"], Bounties.step_text(b), b["coins"]])).call_deferred()
		elif arg.begins_with("--hunt"):                   # by the butcher: a live stag, bodies, the cart (--hunt=ride sits you on it)
			_hunt_test.call_deferred(arg.trim_prefix("--hunt").trim_prefix("="))
		elif arg == "--talents" or arg == "--talents=delver":   # a Pyromancer (or Delver) with a few talents, on the talent screen
			var delver := arg.ends_with("delver")
			Classes.choose("delver" if delver else "pyromancer")
			Classes.bonus_points = 5
			Classes.talents.assign(["deep_runner", "ambush", "wide_pit"] if delver else ["scorched_path", "second_wind", "greater_star"])
			var hud := get_node("../HUD")
			hud._modal.call_deferred(preload("res://scripts/ui/talent_panel.gd"))
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
		elif arg == "--grand":                            # (after --inside or --house=lodge) the Grand Swoop Home
			(func() -> void:
				if not Home.owned():
					Home.house = "lodge"
					Home.furniture = Home.STARTER.duplicate(true)
				Home.house = "lodge"
				Home.upgraded = ["lodge"]
				Home._refit(Home.ROOM_HALF, Home.GRAND_HALF)
				Home.changed.emit()
				Home.furniture_changed.emit()).call()
		elif arg.begins_with("--layout="):                # the inside's layout (after --inside): --layout=bright
			Home.set_layout(arg.trim_prefix("--layout="))
		elif arg.begins_with("--feel="):                  # the inside's feel: --feel=hill
			Home.set_feel(arg.trim_prefix("--feel="))
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
		elif arg == "--pyrotest":                     # with --lab: meteor and flame dash on three foes
			add_child(preload("res://scripts/dev/pyro_test.gd").new())
		elif arg.begins_with("--looktest="):         # screenshot named NPCs up close: --looktest=tomas,morrow
			var lt := preload("res://scripts/dev/look_test.gd").new()
			lt.ids = Array(arg.trim_prefix("--looktest=").split(","))
			lt.suffix = "_off" if "--studio-merge=off" in OS.get_cmdline_user_args() else ""
			add_child(lt)
		elif arg == "--carttest":                     # meteor a villager, carry the body to the ox cart
			add_child(preload("res://scripts/dev/cart_carry_test.gd").new())
		elif arg == "--thumb":                       # Hilmi's thumb area for this run (not saved)
			Settings.thumb_controls = true
		elif arg == "--controlstest":                # switch Settings > Controls both ways, print what shows
			add_child(preload("res://scripts/dev/controls_test.gd").new())
		elif arg.begins_with("--class="):            # start as a class: --class=pyromancer|delver|shade
			Classes.choose.call_deferred(arg.trim_prefix("--class="))
		elif arg == "--classpanel":                  # open the class screen as the shrine would
			get_tree().create_timer(0.5).timeout.connect(func() -> void: get_node("../HUD").open_class_panel(true))
		elif arg == "--sealtest":                     # with --region=forest: Varek drops Morrow's seal
			add_child(preload("res://scripts/dev/seal_test.gd").new())
		elif arg == "--pyro":                         # be a Pyromancer (abilities on Z/X too)
			Classes.choose.call_deferred("pyromancer")
		elif arg == "--cave" or arg.begins_with("--cave="):   # (with --region=forest) straight down into Glimmerdeep; =x,z to stand there
			var spot := arg.trim_prefix("--cave=").split(",") if arg.begins_with("--cave=") else PackedStringArray()
			get_tree().create_timer(0.8).timeout.connect(func() -> void:
				var cave := get_tree().get_first_node_in_group("cave")
				cave.enter()
				if spot.size() == 2:
					get_tree().create_timer(0.7).timeout.connect(func() -> void:
						var p: Vector3 = cave.AT + Vector3(float(spot[0]), 0.0, float(spot[1]))
						p.y = cave.AT.y + cave.floor_at(float(spot[0]), float(spot[1])) + 0.3
						get_node("../Player").global_position = p))
		elif arg.begins_with("--rodgrip="):
			var g := arg.trim_prefix("--rodgrip=").split(",")
			Fisher.grip = Vector3(float(g[0]), float(g[1]), float(g[2]))
		elif arg == "--fishtest" or arg == "--fishcatch":   # fishing at the meadow pond: into the fight (or straight to a catch)
			var land := arg == "--fishcatch"
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				var pl := get_node("../Player")
				pl.global_position = Vector3(24.0, WorldShape.new().height_at(24.0, 5.5) + 0.2, 5.5)
				pl.fisher.start(Region.current, Vector3(24.0, WorldShape.WATER_Y + 0.05, 1.3))
				get_tree().create_timer(2.5).timeout.connect(func() -> void:     # straight to a hooked fish
					var roll := FishData.roll(Region.current, false)
					pl.fisher.fish = roll[0]
					pl.fisher.size = roll[1]
					pl.fisher._hook()
					pl.fisher.reeling = true
					pl.fisher.progress = 0.99 if land else 0.45
					if not land:                          # held mid-fight, for a look at the bars
						pl.fisher.tension = 0.6
						pl.fisher.set_process(false)))
		elif arg.begins_with("--sword="):                 # try a sword look in hand: plain, runeblade, frost
			CharacterVisual.lab_sword_style = arg.trim_prefix("--sword=")
			get_tree().create_timer(1.0).timeout.connect(func() -> void: get_node("../Player").visual.show_tool("sword"))
		elif arg == "--shade":                        # be a Shade
			Classes.choose.call_deferred("shade")
		elif arg == "--mirage":                       # (with --shade) a double steps out after a moment
			get_tree().create_timer(2.0).timeout.connect(func() -> void: get_node("../Player").abilities.shade.mirage())
		elif arg == "--shadetest":                    # with --lab: Mirage, Shadow Dance, shadow roll, Switch
			add_child(preload("res://scripts/dev/shade_test.gd").new())
		elif arg == "--tidecaller": Classes.choose.call_deferred("tidecaller") # studio: water class (be a Tidecaller)
		elif arg == "--delver":                       # be a Delver
			Classes.choose.call_deferred("delver")
		elif arg == "--delvertest":                   # every Delver ability on a pack in the meadow, screenshots to %TEMP%
			add_child(preload("res://scripts/dev/delver_test.gd").new())
		elif arg == "--bandittest":                   # with --lab: sneak-kill a bandit, then fight two
			add_child(preload("res://scripts/dev/bandit_test.gd").new())
		elif arg == "--defencetest":                  # parry a boar's charge, perfect-dodge the next
			add_child(preload("res://scripts/dev/defence_test.gd").new())
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
		elif arg.begins_with("--style="):               # --style=carved: the player (and a --lineup) in that character style
			_lineup_style = arg.trim_prefix("--style=")
			var pv: CharacterVisual = get_node("../Player/Visual")
			pv.hero_look.style = _lineup_style
			pv.apply_hero_look.call_deferred()
		elif arg.begins_with("--lineup"):               # --lineup, or --lineup=7 to start at the 8th outfit
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
		elif arg == "--kernel-bench":                   # studio branch: the world kernel's conformance and timings, then quit
			load("res://scripts/studio/kernel/bench.gd").on_device(get_tree())
		elif arg.begins_with("--studio="):              # studio branch: run a studio spike on the device (e.g. village/decision_bench), then quit
			load("res://scripts/studio/%s.gd" % arg.trim_prefix("--studio=")).on_device(get_tree())
		elif arg == "--kernel-thread":                  # studio branch: frame times with the kernel on a worker thread, then quit
			add_child(load("res://scripts/studio/kernel/thread_probe.gd").new())
		elif arg.begins_with("--frame="):                 # studio branch: a camera framing (explore, fight, build, vantage)
			var rig := get_node("../CameraRig")
			var frame := arg.trim_prefix("--frame=")
			(func() -> void: load("res://scripts/studio/camera/framings.gd").apply(rig, frame)).call_deferred()
		elif arg.begins_with("--turntable"):             # studio branch: spin the camera twice, record frame times, quit
			var probe: Node = load("res://scripts/studio/camera/turntable_probe.gd").new()
			probe.rig = get_node("../CameraRig")
			if arg.begins_with("--turntable="):
				probe.speed = float(arg.trim_prefix("--turntable="))
			add_child(probe)
		elif arg.begins_with("--fog="):                   # studio branch: fog begin,end in metres (horizon tests)
			var v := arg.trim_prefix("--fog=").split(",")
			(func() -> void:
				day_night.environment.fog_depth_begin = float(v[0])
				day_night.environment.fog_depth_end = float(v[1])).call_deferred()
		elif arg == "--traveltest":                   # (with --memlog) travel meadow <-> forest every 15 s (leaks across region reloads)
			get_tree().create_timer(15.0).timeout.connect(func() -> void:
				Region.travel("forest" if Region.current == "meadow" else "meadow", Vector2.INF))
		elif arg == "--drawlog":                      # after 10 s: what draws the most (visible mesh surfaces within 70 m, by owner)
			get_tree().create_timer(10.0).timeout.connect(_drawlog)
		elif arg == "--memlog":                       # print memory and object counts every 5 s (leak hunt)
			var t := Timer.new()
			t.wait_time = 5.0
			t.autostart = true
			t.timeout.connect(_memlog)
			add_child(t)
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


## Hunting test (--hunt): by the butcher's rack with the ox cart, a stag body beside you and a live stag.
func _hunt_test(mode: String) -> void:
	await get_tree().create_timer(0.3).timeout
	var player := get_node("../Player") as Node3D
	var shape := Carcass.shape
	var at := Vector2(-16.0, 31.0)
	player.global_position = Vector3(at.x, shape.height_at(at.x, at.y) + 0.2, at.y)
	player.visual.rotation.y = PI * 0.8
	var body := Carcass.spawn(get_parent(), "stag", Vector3(-14.0, shape.height_at(-14.0, 29.0), 29.0), 1.2, player)
	Carcass.spawn(get_parent(), "boar", Vector3(-17.5, shape.height_at(-17.5, 29.0), 29.0), 2.4, player, 380.0)
	var stag := Stag.new()
	stag.player = player
	stag.home = Vector3(-12.0, shape.height_at(-12.0, 40.0), 40.0)
	get_node("../Enemies").add_child(stag)
	stag.global_position = stag.home + Vector3(0, 0.5, 0)
	get_tree().get_first_node_in_group("camera_rig").snap()
	if mode == "look":                            # the live stag stood still side-on in front of you (a model check)
		stag.global_position = player.global_position + Vector3(-3.5, 0.0, -2.0)
		stag.process_mode = Node.PROCESS_MODE_DISABLED
		body.visible = false
	if mode == "ride":
		player.hauling.mount(get_tree().get_first_node_in_group("ox_cart"))
	elif mode == "choices":
		player.global_position = body.global_position + Vector3(1.5, 0.2, 1.0)
		body.interact()
	elif mode == "wild":                          # crows on the body, the Duskmaw walking in
		player.global_position = body.global_position + Vector3(9.0, 0.2, 6.0)
		for i in 3:
			var crow := Node3D.new()
			crow.set_script(preload("res://scripts/world/crow.gd"))
			crow.carcass = body
			crow.player = player
			get_parent().add_child(crow)
		var beast := preload("res://scenes/wolf.tscn").instantiate() as Wolf
		beast.player = player
		beast.duskmaw = true
		beast.home = body.global_position
		get_parent().add_child(beast)
		beast.global_position = body.global_position + Vector3(-5.0, 1.0, 3.0)
	elif mode == "drag":                          # pulls the stag away from the rack, to watch it come along
		player.hauling.start_carry(body)
		Controls.joystick = Vector2(-0.9, -0.4)


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


func _drawlog() -> void:
	var cam := get_viewport().get_camera_3d()
	var by := {}
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree() or g.global_position.distance_to(cam.global_position) > 70.0:
			continue
		var surfaces := 1
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			surfaces = (g as MeshInstance3D).mesh.get_surface_count()
		elif g is MultiMeshInstance3D:
			surfaces = 1
		var top: Node = g
		while top.get_parent() and top.get_parent() != get_parent():
			top = top.get_parent()
		var key := "%s/%s" % [top.name, g.get_class()]
		by[key] = by.get(key, 0) + surfaces
	var keys := by.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return by[a] > by[b])
	for k: String in keys.slice(0, 25):
		print("DRAW ", by[k], " ", k)
	print("DRAW frame total ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " tris ",
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var main := get_parent()
	var base: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	for n in main.get_children():                   # each part hidden in turn: what it costs (4 or more)
		if not (n is Node3D or n is CanvasLayer) or not n.visible:
			continue
		n.visible = false
		for i in 3:
			await get_tree().process_frame
		var cost: float = base - Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		if cost >= 4.0:
			print("DRAW %s costs %d" % [n.name, cost])
		n.visible = true
		for i in 2:
			await get_tree().process_frame
	var scatter := main.get_node("Scatter")
	for kind: String in ["tree", "bush", "rock", "small", "ground"]:
		var hidden := []
		for c in scatter.get_children():
			if c is MultiMeshInstance3D and c.get_meta("kind", "") == kind and c.visible:
				c.visible = false
				hidden.append(c)
		for i in 3:
			await get_tree().process_frame
		print("DRAW without %s: %d (%d batches)" % [kind, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), hidden.size()])
		for c in hidden:
			c.visible = true
		for i in 2:
			await get_tree().process_frame
	get_tree().quit()


func _memlog() -> void:
	var P := Performance
	print("MEM t=%ds static=%dMB video=%dMB tex=%dMB buf=%dMB objects=%d nodes=%d orphans=%d resources=%d draws=%d" % [
		Time.get_ticks_msec() / 1000, OS.get_static_memory_usage() / 1048576,
		P.get_monitor(P.RENDER_VIDEO_MEM_USED) / 1048576, P.get_monitor(P.RENDER_TEXTURE_MEM_USED) / 1048576,
		P.get_monitor(P.RENDER_BUFFER_MEM_USED) / 1048576, P.get_monitor(P.OBJECT_COUNT),
		P.get_monitor(P.OBJECT_NODE_COUNT), P.get_monitor(P.OBJECT_ORPHAN_NODE_COUNT),
		P.get_monitor(P.OBJECT_RESOURCE_COUNT), P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


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
		if _lineup_style != "":
			v.hero_look.style = _lineup_style
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
