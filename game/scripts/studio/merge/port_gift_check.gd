extends Node
## The gift seam for Mind's port (desk, 6 Oct, unit 2), in the live village with the port's switch on:
##   --studio=village/live --merge-check=port_gift_check --port-residents=on --save-guard --test-save=<fresh name>
## His Tomas is a person of the village; standing beside him, PlayerActs.gift(registry, "tomas", "apple", press) is one
## checked act: accepted, the apple taken from his Inventory once, the receipt saved, Tomas learning the gift. The
## same press again is the same act (nothing taken twice). Prints PASS/FAIL lines and "PORT GIFT complete failures=N".
const PlayerActs := preload("res://scripts/studio/village/player_acts.gd")
const Ported := preload("res://scripts/studio/village/sim/ported.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Contact := preload("res://scripts/studio/village/contact.gd")
var failed := 0


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("PortGiftCheck"):
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/merge/port_gift_check.gd").new()
	probe.name = "PortGiftCheck"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS port-gift " if ok else "FAIL port-gift ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func run() -> void:
	await frames(120)
	var res: Node = null
	for _i in 900:
		res = Contact.registry(get_tree())
		if res != null and VillageSession.village != null and res.call("all_built"):
			break
		await get_tree().process_frame
	var v = VillageSession.village
	var id := Ported.person_of(v, "tomas")
	check(id >= 0 and res != null and res.bodies.has(id), "his Tomas is a person of the village with a body (%d)" % id)
	if id < 0 or res == null or not res.bodies.has(id):
		_done()
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var body: Node3D = res.bodies[id]
	res._movers[id].place(Vector2(body.global_position.x, body.global_position.z), PI)
	player.global_position = body.global_position + Vector3(0, 0.1, -1.2)
	await frames(10)
	Inventory.add("apple", 2)
	var before := Inventory.count("apple")
	var receipt: Dictionary = PlayerActs.gift(res, "tomas", "apple", "port-gift-1")
	await frames(30)
	var known: bool = v.people[id].mind.known.keys().any(func(k: Variant) -> bool: return str(v.people[id].mind.known[k].get("kind", "")) == "gift")
	check(receipt.get("accepted", false) and Inventory.count("apple") == before - 1, "a gift to Tomas is one checked act and takes one apple (%s)" % str(receipt.get("reason", "")))
	check(known, "Tomas learns the gift (%d accounts)" % v.people[id].mind.known.size())
	var again: Dictionary = PlayerActs.gift(res, "tomas", "apple", "port-gift-1")
	await frames(10)
	check(Inventory.count("apple") == before - 1 and (again.get("duplicate", false) or not again.get("accepted", false)), "the same tap again takes nothing more")
	check(not PlayerActs.gift(res, "hesk", "apple", "port-gift-2").get("accepted", false), "someone who is not a resident of the village cannot be given a gift this way")
	_done()


func _done() -> void:
	print("PORT GIFT complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
