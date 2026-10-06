extends RefCounted
## world-things in the live game (Body): body_play_probe --body-play=things. Real carrier models are set by the well
## (a fence, a bench beside it, a camp crate down the lane); his own flame dash sets the fence burning, the fire spreads
## to the bench, a save read back from disk mid-fire holds the fires, well water puts the fence out with its char kept,
## and a shove breaks the crate. Everything goes through Contact and the people's checked door, under --save-guard.
## Prints MEASURE lines for rule 7 over the fire and over a quiet stretch with nothing burning.
const Contact := preload("res://scripts/studio/village/contact.gd")
const TF := preload("res://scripts/studio/village/sim/thing_facts.gd")
const T := preload("res://scripts/studio/village/sim/thing_actions.gd")
const Things := preload("res://scripts/studio/village/things.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")


static func _place(p: Node, path: String, at: Vector2, yaw: float) -> Node3D:
	var node: Node3D = preload("res://scripts/world/treasure.gd")._solid((load(path) as PackedScene).instantiate()) # Enea's solid shader, as the game builds carriers
	p.get_tree().current_scene.add_child(node)
	node.global_position = Vector3(at.x, WorldShape.new().height_at(at.x, at.y), at.y)
	node.rotation.y = yaw
	return node


static func _id(node: Node3D) -> String:
	return T.id_of(Things.CARRIERS[node.scene_file_path], node.global_position.x, node.global_position.z)


static func _measure(label: String) -> void:
	for field: String in ["accept_us", "save_us"]:
		var costs: Array = Accept.measures.map(func(row: Dictionary) -> int: return int(row.get(field, 0)))
		costs.sort()
		if not costs.is_empty():
			var sum := 0
			for c: int in costs:
				sum += c
			print("MEASURE %s %s n=%d median_ms=%.3f max_ms=%.3f sum_ms=%.1f" % [label, field, costs.size(), costs[costs.size() / 2] / 1000.0, costs[-1] / 1000.0, sum / 1000.0])
		else:
			print("MEASURE %s %s n=0" % [label, field])


static func run(p: Node) -> void:
	var tree: SceneTree = p.get_tree()
	var live := tree.current_scene.get_node("VillageLive")
	p.res = live.registry
	while not p.res.all_built():
		await tree.process_frame
	var v = VillageSession.village
	p.check(v.get("thing_facts") != null, "the village has a home for thing facts")
	var well: Vector2 = p.res.focus("well")
	p.check(well != Vector2.INF, "a well to fetch water from (%s)" % str(well))
	if well == Vector2.INF or v.get("thing_facts") == null:
		return
	p.camera = Camera3D.new()
	p.add_child(p.camera)
	p.camera.fov = 50
	p.camera.make_current()
	# A quiet stretch first: nothing burning, wet or struck; rule 7's no-fire side.
	Accept.measures.clear()
	Contact.thing_usec = 0
	Contact.thing_calls = 0
	await p.active(6.0)
	_measure("quiet")
	print("MEASURE quiet thing_time calls=%d total_ms=%.3f per_call_us=%.2f" % [Contact.thing_calls, Contact.thing_usec / 1000.0, float(Contact.thing_usec) / maxi(1, Contact.thing_calls)])
	var fence := _place(p, "res://assets/props/fence.glb", well + Vector2(1.3, 0.0), 0.0)
	var bench := _place(p, "res://assets/props/bench.glb", well + Vector2(3.7, 0.0), 0.0)
	var crate := _place(p, "res://assets/camp/camp_crates.glb", well + Vector2(1.3, -6.0), 0.0)
	await p.frames(2)
	var f := _id(fence)
	var b := _id(bench)
	var c := _id(crate)
	var standing := Things.ids(tree)
	p.check(standing.has(f) and standing.has(b) and standing.has(c), "the fence, bench and crate are found as things (%s)" % str(standing))
	# His fire: the flame dash, run at the fence from 2.6 m.
	p.position_player(Vector3(well.x + 1.3, WorldShape.new().height_at(well.x + 1.3, well.y - 2.6) + 0.05, well.y - 2.6))
	await p.frames(4)
	Accept.measures.clear()
	p.player.abilities._flame_dash({"dir": Vector3(0, 0, 1), "press_id": "things:dash"})
	await p.active(0.6)
	p.check(T.has(v, f, "burning") and TF.get_fact(v, f, "burning").deed.begins_with("thing:"), "his flame dash sets the fence burning")
	p.subject = -1
	await p.capture("01-fence-burning")
	await p.active(3.0)
	p.check(T.has(v, b, "burning") and TF.get_fact(v, b, "burning").deed == TF.get_fact(v, f, "burning").deed, "the fire spreads to the bench beside it, the dash its cause")
	p.check(int(TF.get_fact(v, f, "scorched").get("level", 0)) > 0, "the fence chars as it burns (%d)" % int(TF.get_fact(v, f, "scorched").get("level", 0)))
	await p.capture("02-spread-to-bench")
	# Save, read back from disk alone, mid-fire.
	SaveGame._journal.wait()
	SaveGame.save_game(true)
	SaveGame._journal.wait()
	var held: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveGame._path))
	var built = Codec.from_data(held.get("village", {})) if held.get("village") is Dictionary else null
	if built != null:
		TF.at_load(built)
	var same: bool = built != null and JSON.stringify(Codec.to_data(built, false)) == JSON.stringify(Codec.to_data(v, false))
	if not same and built != null:
		print("THINGS disk ", JSON.stringify(built.thing_facts), "\nTHINGS live ", JSON.stringify(v.thing_facts))
	p.check(same and T.has(built, f, "burning") and T.has(built, b, "burning"),
		"a save read back from disk mid-fire holds both fires and the char exactly")
	# Well water on the fence.
	p.position_player(Vector3(well.x + 1.3, WorldShape.new().height_at(well.x + 1.3, well.y - 0.9) + 0.05, well.y - 0.9))
	await p.frames(2)
	var level := int(TF.get_fact(v, f, "scorched").get("level", 0))
	var r: Dictionary = Contact.things(tree, Contact.actor_of(p.player), p.player, "extinguish", {"method": "water", "affordance": "water:well",
		"press_id": "things:water"}, p.player.global_position, 1.2, Vector3(0, 0, 1))
	p.check(r.get("accepted", false) and not T.has(v, f, "burning") and T.has(v, f, "soaked") and int(TF.get_fact(v, f, "scorched").level) >= level,
		"well water puts the fence out; it is soaked and its char stays (%d)" % int(TF.get_fact(v, f, "scorched").get("level", 0)))
	await p.capture("03-water-out-char-stays")
	await p.active(2.0)
	_measure("fire")
	# A shove at the crate, no one in the way.
	p.position_player(Vector3(well.x + 1.3, WorldShape.new().height_at(well.x + 1.3, well.y - 7.0) + 0.05, well.y - 7.0))
	await p.frames(2)
	var s: Dictionary = Contact.perform(tree, Contact.actor_of(p.player), p.player, "shove", {"force": 700, "press_id": "things:shove"},
		p.player.global_position, 1.0, Vector3(0, 0, 1))
	p.check(s.get("accepted", false) and T.has(v, c, "broken"), "a hard shove breaks the crate")
	await p.active(2.0)
	p.check(T.has(v, c, "broken") and not T.has(v, c, "struck") and T.has(v, f, "scorched"), "the crate stays broken and the fence stays charred")
	await p.capture("04-crate-broken")
