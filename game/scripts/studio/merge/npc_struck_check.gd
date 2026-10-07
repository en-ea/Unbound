extends Node
## Enea's story people struck (merge-fix: world/npc.gd struck(), group "npc_body", from fighter.gd _strike_people)
## against C1's severe act (the people's door: Contact.perform knock-down / finish). Live, port on:
##   --studio=village/live --merge-check=npc_struck_check --save-guard --port-residents=on --test-save=<fresh>
## Checks: his figures of the ported seven are hidden, so his strike never reaches them (they are village people,
## reached through Contact); a visible story NPC is never a Contact target, so no severe act (strike, finish) can
## take them, and no village fact is written; his struck() plays on them (they turn, reel, say a line) and they stay
## unhurt and present. Prints PASS/FAIL lines and "NPCSTRUCK complete failures=N".
const Contact := preload("res://scripts/studio/village/contact.gd")
var failed := 0


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("NpcStruckCheck"):
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/merge/npc_struck_check.gd").new()
	probe.name = "NpcStruckCheck"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS npc-struck " if ok else "FAIL npc-struck ") + text)
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
		if res != null and VillageSession.village != null and VillageSession.active and res.call("all_built") \
				and get_tree().get_first_node_in_group("player") != null:
			break
		await get_tree().process_frame
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var v = VillageSession.village
	var npcs: Array = get_tree().get_nodes_in_group("npc_body")
	var visible := npcs.filter(func(n: Node3D) -> bool: return n.is_visible_in_tree())
	var hidden := npcs.filter(func(n: Node3D) -> bool: return not n.is_visible_in_tree())
	var ported_ids := ["tomas", "elsa", "nell", "bram"]
	var ported_visible := visible.filter(func(n: Node) -> bool: return str(n.get("_id")) in ported_ids)
	print("NPCSTRUCK npc_body %d, visible %d (%s), hidden %d (%s)" % [npcs.size(), visible.size(), str(visible.map(func(n: Node) -> String: return str(n.get("_id")))),
		hidden.size(), str(hidden.map(func(n: Node) -> String: return str(n.get("_id"))))])
	check(ported_visible.is_empty(), "his figures of the ported people are hidden, so his strike passes them by (visible ported: %s)" % str(ported_visible.map(func(n: Node) -> String: return str(n.get("_id")))))
	if visible.is_empty():
		check(false, "a visible story NPC to strike")
		_done()
		return
	var target: Node3D = visible[0]
	var tid := str(target.get("_id"))
	player.global_position = target.global_position + Vector3(0, 0, -1.0)
	player.visual.rotation.y = 0.0
	await frames(5)
	var reach := Contact.measure(get_tree(), player, player.global_position, 2.8, Vector3.FORWARD)
	var bodies: Array = reach.map(func(row: Dictionary) -> Variant: return res.bodies.get(int(row.id)))
	check(not bodies.has(target) and reach.all(func(row: Dictionary) -> bool: return res.bodies.has(int(row.id))),
		"a story NPC is never a Contact target: the people's door measures village bodies only (%d near, %s not among them), so no knock-down or finish can take them" % [reach.size(), tid])
	var bubble: Label3D = target.get("_bubble")
	var before_text := bubble.text if bubble != null else ""
	var before_at := target.global_position
	player.fighter._strike_people(true)
	await frames(10)
	check(bubble != null and bubble.text != before_text and bubble.text != "" and target.is_inside_tree() and target.is_visible_in_tree(),
		"his struck() plays on %s: turned and spoke (\"%s\"), still there" % [tid, bubble.text if bubble != null else ""])
	check(target.global_position.distance_to(before_at) < 1.5, "pushed back a little, not knocked out of the world (%.2f m)" % target.global_position.distance_to(before_at))
	_done()


func _done() -> void:
	print("NPCSTRUCK complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
