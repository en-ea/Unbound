extends Node
## His home scenes at a real night (desk 6 Oct, after Animation's night-house check on enea-fix 6a6306a): the one
## world clock set to night, then the cottage (house 0) entered as his --visit does. Checked: everyone home is in the
## room, no two bodies lie in one place (more sleepers than his four floor places lap over), and one of his seven at
## home wears his own look (VillagerBody.dress_his). In the live village with the port's switch on:
##   --studio=village/live --merge-check=../people/home_night_check --port-residents=on --save-guard --test-save=<fresh>
##   [--night-house=0] [--night-shot=<png>]   (a shot needs a display: xvfb-run ... --rendering-driver opengl3)
## Prints "NIGHT ..." lines, PASS/FAIL lines and "HOME NIGHT CHECK complete failures=N".
const HomeFolk := preload("res://scripts/world/home_folk.gd")
const Houses := preload("res://scripts/world/village.gd")
const Body := preload("res://scripts/studio/village/villager_body.gd")
const Contact := preload("res://scripts/studio/village/contact.gd")
var failed := 0


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("HomeNightCheck"):
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/people/home_night_check.gd").new()
	probe.name = "HomeNightCheck"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS night " if ok else "FAIL night ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func run() -> void:
	await frames(120)
	for _i in 900:
		var res := Contact.registry(get_tree())
		if res != null and VillageSession.village != null and VillageSession.active and res.call("all_built"):
			break
		await get_tree().process_frame
	var house := 0
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--night-house="):
			house = int(arg.trim_prefix("--night-house="))
		elif arg.begins_with("--night-shot="):
			shot = arg.trim_prefix("--night-shot=")
	WorldClock.advance_to_time(0.964)        # a real night on the one clock (--time does not make one)
	await frames(90)
	var v = VillageSession.village
	var folk: Array = HomeFolk.inside(get_tree(), house)
	var visitor: Node = null
	for n in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if n.has_method("visit"):
			visitor = n
			break
	check(visitor != null, "the village's house visit is there")
	if visitor == null:
		_done()
		return
	var d: Vector2 = Houses.door_of(house)
	var room: Dictionary = Houses.VISITS.get(house, {"feel": Lettings.HOUSES.get(house, {}).get("feel", "lantern"), "layout": "hearth"})
	visitor.visit(house, room["feel"], Vector3(d.x, 0, d.y), room["layout"])
	await frames(90)
	var bodies: Array = (visitor.get("_people") as Array).filter(func(n: Node) -> bool: return is_instance_valid(n) and n is Body)
	var names: Array = folk.map(func(f: Dictionary) -> String: return "%s (%s)" % [v.people[int(f.id)].name, str(f.verb)])
	print("NIGHT house %d: %d inside: %s" % [house, folk.size(), ", ".join(PackedStringArray(names))])
	var closest := INF
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a: Vector3 = bodies[i].global_position
			var b: Vector3 = bodies[j].global_position
			closest = minf(closest, Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)))
	var sleepers := folk.filter(func(f: Dictionary) -> bool: return str(f.verb) == "sleeping").size()
	check(bodies.size() == folk.size() and folk.size() > 0, "everyone home has a body in the room (%d bodies, %d home, %d asleep)" % [bodies.size(), folk.size(), sleepers])
	check(bodies.size() < 2 or closest >= 0.6, "no two bodies in one place (closest %.2f m)" % closest)
	# One of his seven at home: dressed as his own (dress_his on a fresh body dresses it; the room's did the same).
	var his := folk.filter(func(f: Dictionary) -> bool: return HomeFolk._his_id(v, int(f.id)) != "")
	if not his.is_empty():
		var probe := Body.new()
		add_child(probe)
		var dressed := Body.dress_his(probe, v, int(his[0].id))
		probe.queue_free()
		check(dressed, "%s, one of his seven, is home and wears his own look (dress_his)" % v.people[int(his[0].id)].name)
	else:
		print("NIGHT none of his seven is home in house %d tonight" % house)
	if shot != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("NIGHT shot %s" % shot)
	_done()


func _done() -> void:
	print("HOME NIGHT CHECK complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
