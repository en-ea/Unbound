extends Node
## Everyone the star sets alight knows they are burning (desk 6 Oct: Mind's port-probe, one run in three, Tomas burned
## to death with no burning account - only "act fall", the down notice of the same deed).
##   --studio=village/live --merge-check=fire_known_check --save-guard --test-save=<fresh name> [--fire-pairs=6]
## Groups of four grown villagers within the star's reach (sixteen first accounts, beyond one batch's twelve), a star
## dropped on each group; for every person whose burning fact the
## star wrote: their mind holds that deed's account as a burn (felt). Prints PASS/FAIL lines, a "FIRE known" line per
## person, and "FIRE complete failures=N".
const Contact := preload("res://scripts/studio/village/contact.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
var failed := 0


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("FireKnownCheck"):
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/merge/fire_known_check.gd").new()
	probe.name = "FireKnownCheck"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS fire " if ok else "FAIL fire ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


## What this person's mind holds for the deed: "" none, else the account's act and facets.
func known(v, id: int, deed: String) -> String:
	var m = v.people[id].mind
	var key := deed + ":" + People.key(v, id)
	for k: Variant in m.known:
		if str(k) == key or str(m.known[k].get("deed", "")) == deed:
			var a: Dictionary = m.known[k]
			return "act=%s facets=%s" % [str(a.get("evidence", {}).get("act", "")), str(a.get("facets", {}).keys().map(func(f: Variant) -> String: return str(f) + "/" + str(a.facets[f].get("via", ""))))]
	return ""


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
	var pairs := 5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fire-pairs="):
			pairs = int(arg.trim_prefix("--fire-pairs="))
	var pool := []
	for id: int in res.bodies:
		var p = v.people[id]
		if p.alive and p.present and p.authored == "" and Rules.age_of(v, p) >= 16:
			pool.append(id)
	var burned := 0
	var unaware := []
	var base: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	for n in pairs:
		if pool.size() < 2:
			break
		if pool.size() < 4:
			break
		var a: int = pool.pop_back()
		var b: int = pool.pop_back()
		var c: int = pool.pop_back()
		var d: int = pool.pop_back()
		var spot := base + Vector2(12.0 * (n % 3) - 12.0, 14.0 * float(n / 3) + 8.0)
		for pair: Array in [[a, spot], [b, spot + Vector2(2.6, 0)], [c, spot + Vector2(0, 1.8)], [d, spot + Vector2(1.6, -1.6)]]:
			res._movers[pair[0]].place(pair[1], 0.0)
			res._movers[pair[0]].hold(pair[1], pair[1] + Vector2(0, 1))
		player.global_position = Vector3(spot.x - 6, player.global_position.y, spot.y - 6)
		await frames(10)
		var before := {}
		for id: int in [a, b, c, d]:
			before[id] = v.people[id].body_facts.get("burning", {}).duplicate()
		player.abilities._drop_star(null, res.bodies[a].global_position, 1.0, "fire-known:%d" % n)
		await get_tree().create_timer(3.0).timeout
		for id: int in [a, b, c, d]:
			var fire: Dictionary = v.people[id].body_facts.get("burning", {})
			var dead: Dictionary = v.people[id].body_facts.get("dead", {})
			var deed := str(fire.get("deed", dead.get("deed", "")))
			if deed.is_empty() or (not before[id].is_empty() and str(before[id].deed) == deed):
				continue
			burned += 1
			var got := known(v, id, deed)
			print("FIRE known group %d id %d down %s deed %s -> %s" % [n, id, str(v.people[id].body_facts.has("down")), deed.substr(0, 14), got])
			if not got.begins_with("act=burn"):
				unaware.append(id)
	check(burned >= pairs, "the star set people alight (%d burned)" % burned)
	check(unaware.is_empty(), "everyone it set alight knows they were burned (unaware: %s)" % str(unaware))
	print("FIRE complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
