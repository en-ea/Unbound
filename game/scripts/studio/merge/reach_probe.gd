extends Node
## merge-enea M1: Enea's features reached the way a thumb reaches them, on the merged line.
##   --studio=village/live --merge-check=reach_probe --save-guard --reach=bow_fishing --test-save=<fresh name>   (headless is fine)
## Touches are real screen events (Input.parse_input_event) at the buttons' own centres, so a control lying over
## another one (Hands over his Attack button) fails the check. Prints PASS/FAIL reach lines and
## "REACH complete failures=N".
## bow_fishing (Hilmi, 6 Oct: "an interim way to reach the bow and fishing (his Attack button is hidden under Hands)"):
##   his Swap button shows and swaps to the bow; with the bow out his Attack button draws and looses it, and Hands
##   steps aside; swapping back gives Hands back. At the pond's edge a tap on Hands' thumb area fishes (his Fish spot);
##   his Hook button casts; stopping gives Hands back.
var failed := 0
var mode := "bow_fishing"
var _finger := 7


static func on_device(tree: SceneTree) -> void:
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
	_done()


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
	check(attack.is_visible_in_tree() and not hands.is_visible_in_tree(), "with the bow out his Attack button shows and Hands steps aside")
	touch(attack.center(), true)
	await frames(20)
	var drawing: bool = player.fighter.aiming()
	touch(attack.center(), false)
	await frames(20)
	check(drawing and not player.fighter.aiming(), "holding Attack draws the bow, letting go looses it (drawing %s, held %s, weapon %s, verb '%s', station %s, locked %s)" % [
		str(drawing), str(attack.is_held()), Gear.weapon, str(player.fighter.verb), str(player.get("_station")), str(Controls.locked)])
	await tap(swap.center())
	await frames(2)
	check(Gear.weapon == "sword" and hands.is_visible_in_tree() and not attack.is_visible_in_tree(), "Swap back to the sword gives Hands back (weapon %s, hands %s, attack %s)" % [
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
	await frames(60) # the bobber lands first: stopping mid-cast trips his own fisher.gd:229 (reported, not changed here)
	player.fisher.stop()
	await frames(5)
	check(not player.fisher.is_fishing() and hud.get_node_or_null("FishingUI") == null and hands.is_visible_in_tree(), "stopping fishing gives Hands back")


func _done() -> void:
	print("REACH complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
