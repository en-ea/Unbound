extends Node
## merge-enea M1: Enea's features reached the way a thumb reaches them, on the merged line.
##   --studio=village/live --merge-check=reach_probe --save-guard --reach=bow_fishing --test-save=<fresh name>   (headless is fine)
## Touches are real screen events (pushed into the viewport) at the buttons' own centres, so a control lying over
## another one (Hands over his Attack button) fails the check. Prints PASS/FAIL reach lines and
## "REACH complete failures=N".
## bow_fishing (Hilmi, 6 Oct: "an interim way to reach the bow and fishing (his Attack button is hidden under Hands)"):
##   his Swap button shows and swaps to the bow; with the bow out his Attack button draws and looses it, and Hands
##   steps aside; swapping back gives Hands back. At the pond's edge a tap on Hands' thumb area fishes (his Fish spot);
##   his Hook button casts; stopping gives Hands back.
## all: the merge's reach-check list (desk M1) - every Enea feature reached on the merged line by the player's own
##   path (a tap on Hands at his station, a touch on his buttons, a walk through his gates); state is set directly
##   only for a precondition a thumb cannot make quickly (a tamed elk, the food to cook), and each such line says so.
##   Meadow: bow, swap, fishing; the map (his corner menu); the Shade class (his class panel, then a power on Hands);
##   the bounty board; a house to let; his four named residents; a tenant; Cinder (a Pyromancer cooks at his fire);
##   the waystone (wakes, then Travel opens his map). Whispering Wood: the Glimmerdeep cave mouth. Stonecrest
##   Highlands: through his gates; riding the elk; calming a stag. Last, his Story start from the title screen.
const Ported := preload("res://scripts/studio/village/sim/ported.gd")
const PortStance := preload("res://scripts/studio/people/port_stance.gd")
const Contact := preload("res://scripts/studio/village/contact.gd")
var failed := 0
var mode := "bow_fishing"
var _finger := 7


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("ReachProbe"): # a region change reloads the scene and calls this again
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false) # no renderer to draw item icons with
	var probe: Node = load("res://scripts/studio/merge/reach_probe.gd").new()
	probe.name = "ReachProbe"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reach="):
			mode = arg.trim_prefix("--reach=")
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS reach " if ok else "FAIL reach ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func touch(at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = _finger
	e.position = at
	e.pressed = pressed
	get_viewport().push_input(e, true) # centres are viewport coordinates; the window stretch must not map them twice


## A press, held for `hold` frames, then let go.
func tap(at: Vector2, hold := 3) -> void:
	touch(at, true)
	await frames(hold)
	touch(at, false)
	await frames(2)


func run() -> void:
	await frames(60)
	var hud: Node = null
	var player: Node3D = null
	for _i in 900:
		hud = get_tree().get_first_node_in_group("hud")
		player = get_tree().get_first_node_in_group("player")
		if hud != null and player != null and hud.get("_hands") != null and (hud.get("_hands") as Control).is_visible_in_tree():
			break
		await get_tree().process_frame
	check(hud != null and player != null, "the game is in play with Hands (%s)" % Region.current)
	if hud == null or player == null:
		_done()
		return
	if mode == "bow_fishing":
		await _bow(hud, player)
		await _fishing(hud, player)
	elif mode == "all":
		await _bow(hud, player)
		await _fishing(hud, player)
		await _all(hud, player)
		await _story()
	elif mode == "water":
		_water_debug()
	elif mode == "list":
		_list(player)
		for to: String in ["forest", "highlands"]:
			player = await travel(to)
			if player != null:
				_list(player)
	_done()


## Through the gate from the region we are in to `to` (Region.GATES), as a player walks through it; the probe
## survives the scene reload. Returns the new region's player once play is back.
func travel(to: String) -> Node3D:
	var gate: Dictionary = {}
	for g: Dictionary in Region.GATES.get(Region.current, []):
		if g["to"] == to:
			gate = g
	check(not gate.is_empty(), "a gate from %s to %s" % [Region.current, to])
	if gate.is_empty():
		return null
	Region.travel(to, gate["arrive"])
	for _i in 1800:
		await get_tree().process_frame
		var p := get_tree().get_first_node_in_group("player")
		var h := get_tree().get_first_node_in_group("hud")
		if Region.current == to and p != null and h != null and not Controls.locked and (h.get("_hands") as Control).is_visible_in_tree():
			await frames(60)
			return p
	check(false, "arrived in %s with play back" % to)
	return null


## Discovery: every interactable in this region (verb, script, where) and every group a node of his is in.
func _list(player: Node3D) -> void:
	var p := player.global_position
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D:
			var n := node as Node3D
			var sc: Script = n.get_script()
			print("LIST interactable verb=%s script=%s at=(%.1f, %.1f) dist=%.1f name=%s" % [str(n.get("verb")), sc.resource_path.get_file() if sc else "-",
				n.global_position.x, n.global_position.z, n.global_position.distance_to(p), n.name])
	var groups := {}
	for node in get_tree().current_scene.find_children("*", "", true, false):
		for g in node.get_groups():
			if not str(g).begins_with("_"):
				groups[str(g)] = int(groups.get(str(g), 0)) + 1
	print("LIST groups %s" % str(groups))
	print("LIST region=%s class=%s abilities=%s" % [Region.current, Classes.current, str(Classes.abilities())])


func _bow(hud: Node, player: Node3D) -> void:
	var hands: Control = hud.get("_hands")
	var swap: ActionButton = hud.get("_swap")
	var attack: ActionButton = hud.get("_action")
	# Open ground: with a station or something to gather in reach, his Attack (act()) uses that first, as in his game.
	var shape := WorldShape.new()
	var home := Vector2(player.global_position.x, player.global_position.z)
	var open := Vector2.INF
	for r: float in [8.0, 14.0, 20.0, 28.0, 36.0]:
		for k: int in 12:
			var p := home + Vector2.from_angle(k * TAU / 12.0) * r
			if shape.pond_distance(p) <= WorldShape.POND_RADIUS + 4.0:
				continue
			player.global_position = Vector3(p.x, shape.height_at(p.x, p.y) + 0.3, p.y)
			player.velocity = Vector3.ZERO
			await frames(8)
			if player.call("_nearest_station") == null and str(player.gatherer.verb) == "" and str(player.fighter.verb) == "":
				open = p
				break
		if open != Vector2.INF:
			break
	check(open != Vector2.INF, "open ground with nothing to use or gather in reach (%s)" % str(open))
	await frames(10)
	Gear.weapon = "sword"
	Gear.changed.emit()
	await frames(3)
	check(Gear.has_bow and swap.is_visible_in_tree() and not hands.covers(swap.center()),
		"his Swap button shows beside Hands, clear of its thumb area (%s)" % str(swap.center()))
	await tap(swap.center())
	check(Gear.weapon == "bow", "a tap on Swap takes the bow")
	await frames(2)
	# C1 (Body, 6 Oct) replaces the interim: his Attack is always there; with the bow out it draws (his own act), and
	# Hands keeps the powers' arcs and hints.
	check(attack.is_visible_in_tree() and hands.is_visible_in_tree() and not hands.covers(attack.center()), "with the bow out his Attack button is there to draw it, and Hands keeps the powers clear of it")
	touch(attack.center(), true)
	await frames(20)
	var drawing: bool = player.fighter.aiming()
	touch(attack.center(), false)
	await frames(20)
	check(drawing and not player.fighter.aiming(), "holding Attack draws the bow, letting go looses it (drawing %s, held %s, weapon %s, verb '%s', station %s, locked %s)" % [
		str(drawing), str(attack.is_held()), Gear.weapon, str(player.fighter.verb), str(player.get("_station")), str(Controls.locked)])
	await tap(swap.center())
	await frames(2)
	check(Gear.weapon == "sword" and hands.is_visible_in_tree() and attack.is_visible_in_tree(), "Swap back to the sword: his Attack carries the act again, through Hands (weapon %s, hands %s, attack %s)" % [
		Gear.weapon, str(hands.is_visible_in_tree()), str(attack.is_visible_in_tree())])


func _fishing(hud: Node, player: Node3D) -> void:
	var hands: Control = hud.get("_hands")
	var c: Vector2 = WorldShape.POND_CENTER
	var shape := WorldShape.new()
	var stand := c + Vector2(WorldShape.POND_RADIUS + 0.8, 0.0)
	player.global_position = Vector3(stand.x, shape.height_at(stand.x, stand.y) + 0.3, stand.y)
	player.velocity = Vector3.ZERO
	await frames(30)
	var spot: Node3D = null
	for node in get_tree().get_nodes_in_group("interactable"):
		if str(node.get("verb")) == "Fish":
			spot = node
	check(spot != null, "at the pond's edge his Fish spot is in reach")
	var area: Vector2 = hands.surfaces().act
	await tap(area)
	await frames(10)
	var ui: Node = hud.get_node_or_null("FishingUI")
	check(player.fisher.is_fishing() and ui != null and not hands.is_visible_in_tree(), "a tap on Hands' thumb area fishes; his fishing screen opens and Hands steps aside")
	if ui != null:
		var hook: ActionButton = ui.get("_button")
		var before: int = player.fisher.phase
		await tap(hook.center())
		await frames(5)
		check(hook.is_visible_in_tree(), "his Hook button is there to tap (phase %d -> %d)" % [before, player.fisher.phase])
	await frames(60) # the bobber lands first
	player.fisher.stop()
	await frames(5)
	check(not player.fisher.is_fishing() and hud.get_node_or_null("FishingUI") == null and hands.is_visible_in_tree(), "stopping fishing gives Hands back")
	# Stopping during the cast (0.45 s): his fisher.gd:229 used to error every frame (fixed by a marked line, 6 Oct).
	await tap(hands.surfaces().act)
	await frames(4)
	var casting: bool = player.fisher.is_fishing()
	player.fisher.stop()
	await frames(30)
	check(casting and not player.fisher.is_fishing() and hands.is_visible_in_tree(), "Stop during the cast ends fishing cleanly (the job runner fails any script error)")


func _done() -> void:
	print("REACH complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)


# ---------- the reach-check list (mode all) ----------

func hud_now() -> Node:
	return get_tree().get_first_node_in_group("hud")


func player_now() -> Node3D:
	return get_tree().get_first_node_in_group("player")


## A modal of his open on the HUD, by its script's file name.
func panel(file: String) -> Control:
	var h := hud_now()
	if h == null:
		return null
	for c in h.get_children():
		var sc: Script = c.get_script()
		if c is Control and sc != null and sc.resource_path.get_file() == file and not c.is_queued_for_deletion():
			return c
	return null


## What his HUD has open (for failure lines).
func open_panels() -> String:
	var out := []
	for c in hud_now().get_children():
		var sc: Script = c.get_script()
		if c is Control and sc != null and not c.is_queued_for_deletion() and (c as Control).visible:
			out.append(sc.resource_path.get_file())
	return ", ".join(PackedStringArray(out)) + " | locked %s" % str(Controls.locked)


## An aimed stroke (a power): press, drag `by` in steps, let go.
func stroke(at: Vector2, by: Vector2) -> void:
	touch(at, true)
	await frames(3)
	for k in 6:
		var e := InputEventScreenDrag.new()
		e.index = _finger
		e.position = at + by * (k + 1) / 6.0
		e.relative = by / 6.0
		get_viewport().push_input(e, true)
		await frames(1)
	await frames(3)
	touch(at + by, false)
	await frames(4)


func close(p: Control) -> void:
	if p != null and is_instance_valid(p):
		if p.has_signal("closed"):
			p.closed.emit()
		p.queue_free()
	await frames(6)


func click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = pressed
		get_viewport().push_input(e, true)
		await frames(2)


## Stand in reach of the nearest interactable `pick` accepts, facing it, and tap Hands' thumb area.
func use_station(pick: Callable, what: String) -> Node3D:
	var player := player_now()
	var hands: Control = hud_now().get("_hands")
	var best: Node3D = null
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D and pick.call(node) and (best == null or player.global_position.distance_to(node.global_position) < player.global_position.distance_to(best.global_position)):
			best = node
	if best == null:
		check(false, "%s: nothing to use here (%s)" % [what, Region.current])
		return null
	var at := best.global_position
	var from := Vector2(player.global_position.x - at.x, player.global_position.z - at.z)
	var dir := from.normalized() if from.length() > 0.1 else Vector2(0, 1)
	var stand := Vector2(at.x, at.z) + dir * minf(1.1, float(best.get("reach")) * 0.6 if best.get("reach") != null else 1.1)
	var shape := WorldShape.new()
	var floor_y := at.y + 0.2 if at.y < -100.0 else shape.height_at(stand.x, stand.y) + 0.2   # his rooms stand at y -300
	player.global_position = Vector3(stand.x, floor_y, stand.y)
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = atan2(at.x - stand.x, at.z - stand.y)
	await frames(12)
	var ctx: Dictionary = hands.get("driver").tap_context() if hands.get("driver") != null else {}
	if not is_instance_valid(best):
		check(false, "%s: it went away while walking up" % what)
		return null
	var c: Dictionary = ctx.get("context", {})
	print("TAP %s: %s verb '%s' at %.1f m (player at %s); Hands' tap: %s %s '%s'" % [what, best.name, str(best.get("verb")),
		player.global_position.distance_to(best.global_position), str(player.global_position.snapped(Vector3.ONE * 0.1)),
		str(ctx.get("tap", "")), str(ctx.get("slot", "")), str(c.get("verb", ""))])
	await tap(hands.surfaces().act)
	await frames(10)
	return best if is_instance_valid(best) else null


func _all(hud: Node, player: Node3D) -> void:
	# The map, through his corner menu (the gear button).
	var gear: Button = null
	for b in (hud.get("_corner") as Control).get_children():
		if b is Button and (b as Button).visible and (b as Button).icon != null and (b as Button).icon.resource_path.ends_with("gear.png"):
			gear = b
	if gear != null:
		await click(gear.get_global_rect().get_center())
	var menu := panel("menu_panel.gd")
	check(menu != null, "his corner menu opens from its button (button %s at %s; open: %s)" % [str(gear), str(gear.get_global_rect()) if gear else "-", open_panels()])
	if menu != null:
		menu.open_map.emit()
		await frames(5)
		check(panel("world_map.gd") != null, "his map opens from the menu")
		await close(panel("world_map.gd"))
		await close(panel("menu_panel.gd"))
	# The Shade: his class panel from the menu, then a power on Hands.
	hud.open_menu()
	await frames(4)
	menu = panel("menu_panel.gd")
	if menu != null:
		menu.open_class.emit()
		await frames(5)
	check(panel("class_panel.gd") != null, "his class panel opens from the menu")
	Classes.choose("shade")                                   # (the class panel's choice)
	await close(panel("class_panel.gd"))
	await close(panel("menu_panel.gd"))
	await frames(10)
	var hands: Control = hud.get("_hands")
	var arcs: Dictionary = hands.arcs()
	var shade := Classes.abilities()
	check(Classes.current == "shade" and not shade.is_empty() and arcs.has("power:" + str(shade[0])), "the Shade's powers are on Hands (%s)" % str(shade))
	# (Shadow Dance needs an enemy close by - his rule - so the first power that can fire on open ground is used)
	var fired := ""
	for id: Variant in shade:
		if str(id) == "shadow_dance" or not arcs.has("power:" + str(id)):
			continue
		await stroke(hands.surfaces()["power:" + str(id)], Vector2(0, -90))   # aim up and let go
		await frames(20)
		if Classes.cooldown_left(str(id)) > 0.0:
			fired = str(id)
			break
	check(fired != "", "a Shade power fires from Hands (%s)" % fired)
	# The bounty board.
	await use_station(func(n: Node) -> bool: return str(n.get("verb")) == "Bounties", "bounty board")
	check(panel("bounty_panel.gd") != null, "his bounty board opens from Hands")
	await close(panel("bounty_panel.gd"))
	# A house to let.
	await use_station(func(n: Node) -> bool: return str(n.get("verb")) == "Letting", "letting sign")
	check(panel("shop_panel.gd") != null, "a house to let: his letting sign opens from Hands")
	await close(panel("shop_panel.gd"))
	# His four named residents and a tenant: talk.
	for id: String in ["bram", "elsa", "nell", "tomas"]:
		var who := await use_station(func(n: Node) -> bool: return str(n.get("_id")) in [id, "resident:" + id], "talk to " + id)
		var talk := panel("dialogue_panel.gd")
		check(who != null and talk != null, "talking to %s opens his dialogue from Hands" % id)
		await close(talk)
		await frames(10)
	# A tenant: let a house (the sign's Buy), go in at its door, and talk to whoever lives there.
	var house: int = Lettings.TENANTS.keys()[0]
	Money.earn(Lettings.price(house))                                 # (the coins to buy it)
	check(Lettings.buy(house), "his letting sign's Buy lets house %d" % house)
	var door: Vector2 = preload("res://scripts/world/village.gd").door_of(house)
	await use_station(func(n: Node) -> bool: return str(n.get("verb")) == "Enter" and Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z).distance_to(door) < 1.0, "the let house's door")
	await frames(90)
	if Ported.enabled():
		# Enea's merge-fix with the port on: the house's village family are its tenants; those at home now are inside.
		var family: Array = PortStance.family(VillageSession.village, house)
		var inside := get_tree().get_nodes_in_group("interactable").filter(func(n: Node) -> bool:
			return str(n.get("verb")) == "Talk" and (n as Node3D).global_position.y < -200.0)
		var met: Node = null
		var speech: Node = Contact.registry(get_tree()).get("speech") if Contact.registry(get_tree()) != null else null
		var said_before: int = int(speech.get("_n")) if speech != null else 0
		if not inside.is_empty():
			met = await use_station(func(n: Node) -> bool: return n == inside[0], "talk to whoever is home")
			await frames(10)
		var answered: bool = speech != null and int(speech.get("_n")) > said_before   # (his home_folk answers in a speech bubble, no panel)
		check(not family.is_empty() and (inside.is_empty() or (met != null and answered)),
			"the let house's tenants are its village family (%d); %s" % [family.size(), "nobody of them is home at this hour" if inside.is_empty() else "one at home answers when talked to, in a speech bubble (%s)" % str(answered)])
	else:
		var tenant: String = Lettings.TENANTS[house]
		var met := await use_station(func(n: Node) -> bool: return str(n.get("_id")) == tenant, "talk to the tenant")
		var told := panel("dialogue_panel.gd")
		check(met != null and told != null, "his tenant (%s) is at home in the let house, and talking opens his dialogue (open: %s)" % [tenant, open_panels()])
		await close(told)
	var leave := await use_station(func(n: Node) -> bool: return str(n.get("verb")) in ["Leave", "Exit", "Go out"], "the way out")
	await frames(90)
	# Cinder: a Pyromancer cooks at his fire; she joins.
	Classes.choose("pyromancer")
	await use_station(func(n: Node) -> bool: return str(n.get("verb")) == "Cook", "campfire")
	var cook := panel("shop_panel.gd")
	check(cook != null, "his campfire opens from Hands (open: %s)" % open_panels())
	var fed := false
	for recipe: Dictionary in Balance.COOKING:
		for item: String in recipe["cost"]:
			Inventory.add(item, int(recipe["cost"][item]))            # (the food to cook)
		fed = Food.cook(recipe)                                    # (the campfire's Cook)
		break
	await close(cook)
	await frames(20)
	check(Companions.with_you() == "cinder" and get_tree().current_scene.find_children("*", "", true, false).any(func(n: Node) -> bool: return n.get_script() != null and (n.get_script() as Script).resource_path.ends_with("world/companion.gd")),
		"Cinder joins a Pyromancer who cooks at his fire, and comes along (cooked %s)" % str(fed))
	# The meadow's waystone: it wakes, then Travel opens his map.
	var stone := await use_station(func(n: Node) -> bool: return (n.get_script() as Script).resource_path.ends_with("world/waystone.gd"), "waystone")
	await frames(20)
	if stone != null and str(stone.get("verb")) == "Travel":
		await tap((hud.get("_hands") as Control).surfaces().act)
		await frames(10)
	check(Waystones.is_found(Region.current) and panel("world_map.gd") != null, "his waystone wakes and Travel opens his map from Hands (found %s, verb '%s', open: %s)" % [
		str(Waystones.is_found(Region.current)), str(stone.get("verb")) if stone else "-", open_panels()])
	await close(panel("world_map.gd"))
	player = await travel("forest")
	# Stonecrest Highlands: calm a stag (you have no elk yet), then ride the elk.
	Hunting.elk = {}
	player = await travel("highlands")
	check(player != null and Region.current == "highlands", "Stonecrest Highlands through his gates")
	if player != null:
		await _calm(player)
		if Hunting.elk.is_empty():
			Hunting.elk = {"region": "highlands", "at": Vector2(16.0, -82.0), "yaw": 0.0}   # (an elk already tamed)
			await travel("forest")
			await travel("highlands")
		var elk := await use_station(func(n: Node) -> bool: return n.is_in_group("elk"), "elk")
		await frames(20)
		check(elk != null and player_now().hauling.riding == elk, "riding the elk from Hands")
		player_now().hauling.get_off()
		await frames(20)
		# The Glimmerdeep cave, back in the Whispering Wood (last: the cave keeps you below).
		player = await travel("forest")
		if player != null:
			await use_station(func(n: Node) -> bool: return str(n.get("verb")) == "Enter" and absf((n as Node3D).global_position.x + 62.0) < 8.0, "cave mouth")
			for _i in 300:
				if get_tree().current_scene.find_children("*", "", true, false).any(func(n: Node) -> bool: return n.get_script() != null and (n.get_script() as Script).resource_path.ends_with("world/cave.gd") and typeof(n.get("active")) == TYPE_BOOL and n.get("active")):
					break
				await get_tree().process_frame
			var sky: Node = get_tree().current_scene.get_node_or_null("WorldEnvironment")
			check(sky != null and sky.get("cave") == true, "the Glimmerdeep cave mouth takes you down from Hands")



## Calming a stag: crouch (a tap on the stick), creep up, and use Calm.
func _calm(player: Node3D) -> void:
	var stag: Node3D = null
	for n in get_tree().get_nodes_in_group("stag"):
		if (n as Node3D).is_inside_tree() and (stag == null or player.global_position.distance_to(n.global_position) < player.global_position.distance_to(stag.global_position)):
			stag = n
	check(stag != null, "a stag that can be calmed in the Highlands")
	if stag == null:
		return
	player.sneak()                                                 # (his crouch; on Hands it is a stick tap)
	var at := stag.global_position
	var stand := Vector2(at.x, at.z + 2.0)
	var shape := WorldShape.new()
	player.global_position = Vector3(stand.x, shape.height_at(stand.x, stand.y) + 0.2, stand.y)
	player.velocity = Vector3.ZERO
	await frames(20)
	var verb := str(stag.get("verb"))
	await tap((hud_now().get("_hands") as Control).surfaces().act)
	await frames(60)
	for _i in 240:
		if not Hunting.elk.is_empty():
			break
		await get_tree().process_frame
	check(verb == "Calm" and not Hunting.elk.is_empty(), "calming a stag from Hands (stag verb '%s', fighter verb '%s', sneaking %s)" % [
		verb, str(player.fighter.verb), str(player.get("sneaking"))])


## His Story start: the title screen (his menu's "to title"), its Story start button; the story plays in its own save
## (save_story.json) from the very beginning, with its opening.
func _story() -> void:
	var h := hud_now()
	h.show_title()
	await frames(20)
	var title: Node = h.get("_title")
	var button: Button = null
	if title != null:
		for b in title.find_children("*", "Button", true, false):
			if (b as Button).text == "Story start" and (b as Button).is_visible_in_tree():
				button = b
	check(button != null, "his title screen shows Story start")
	if button == null:
		return
	await click(button.get_global_rect().get_center())
	for _i in 900:
		await get_tree().process_frame
		if SaveGame.path == SaveGame.STORY and get_tree().current_scene != null and get_tree().get_first_node_in_group("player") != null and hud_now() != null and hud_now().get("_title") == null:
			break
	await frames(60)
	check(SaveGame.path == SaveGame.STORY, "Story start plays in its own save (%s)" % SaveGame.path)
	var intro := get_tree().current_scene.find_children("*", "", true, false).any(func(n: Node) -> bool: return n.get_script() != null and (n.get_script() as Script).resource_path.ends_with("story/intro.gd"))
	check(intro or SaveGame.intro_pending, "the story begins with its opening (intro %s, pending %s)" % [str(intro), str(SaveGame.intro_pending)])


## Diagnostics: the well as the people's water affordance sees it (village/water.gd), stage by stage.
func _water_debug() -> void:
	var res: Node = Contact.registry(get_tree())
	var focus: Vector2 = res.focus("well")
	print("WATERDBG focus(well)=%s Sites.well=%s standable(focus)=%s" % [str(focus), str(preload("res://scripts/studio/village/sites.gd").PLACES["well"]["at"]), str(res._world.standable.call(focus))])
	for from: Vector2 in [Vector2(0, 20), Vector2(4, 20), Vector2(0, 30), Vector2(10, 25)]:
		var stand: Vector2 = res._spot_by(focus, 1.7, from, -1)
		var route: PackedVector2Array = res._world.route.call(from, stand) if stand != Vector2.INF else PackedVector2Array()
		var bad := []
		var prior := from
		for point: Vector2 in route:
			var leg := prior.distance_to(point)
			for k in range(1, maxi(1, ceili(leg / 0.35)) + 1):
				var q := prior.lerp(point, float(k) / maxi(1, ceili(leg / 0.35)))
				if not res._world.standable.call(q):
					bad.append(q.snapped(Vector2.ONE * 0.1))
			prior = point
		print("WATERDBG from %s: stand %s, route %d points ending %s, unstandable %s" % [str(from), str(stand), route.size(),
			str(route[route.size() - 1]) if not route.is_empty() else "-", str(bad.slice(0, 6))])
