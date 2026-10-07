extends Node
## Mind port, unit 5: the in-session cost of the port, for an interleaved A/B on one VM (rule 7 is Foundations' A/B on
## the real saves; this is what a session without them can measure). The live village on a generated seed, the port's
## switch given on the command line; after the village is built and a settling minute, it times FRAMES frames of
## ordinary play with the player standing on the green among his residents, and prints one line:
##   PORT COST port=<on|off> frames=N process_ms_mean=.. process_ms_p99=.. process_ms_worst=.. accept_n=.. accept_us_mean=..
##   --studio=village/live --merge-check=../people/port_cost --port-residents=on|off --village-seed=1 --test-save=<fresh name>
## Cloud frame times are software rendering on shared CPUs: compare on and off runs of the same session, interleaved.
const Contact := preload("res://scripts/studio/village/contact.gd")
const Ported := preload("res://scripts/studio/village/sim/ported.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const FRAMES := 1800


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("PortCost"):
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/people/port_cost.gd").new()
	probe.name = "PortCost"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func run() -> void:
	await frames(120)
	for _i in 900:
		var res := Contact.registry(get_tree())
		if res != null and VillageSession.village != null and res.call("all_built"):
			break
		await get_tree().process_frame
	var player: Node3D = get_tree().get_first_node_in_group("player")
	player.global_position = Vector3(-1.0, player.global_position.y, 16.0)   # the green, among his residents' day
	await frames(1800)
	var times: Array[float] = []
	var accepted := Accept.measures.size()
	var before: Array = Accept.measures.duplicate()
	for _i in FRAMES:
		await get_tree().process_frame
		times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var sum := 0.0
	for t in times:
		sum += t
	var sorted := times.duplicate()
	sorted.sort()
	var new_measures: Array = Accept.measures.filter(func(m: Dictionary) -> bool: return not before.has(m))
	var accept_sum := 0.0
	for m: Dictionary in new_measures:
		accept_sum += float(m.accept_us)
	print("PORT COST port=%s frames=%d process_ms_mean=%.3f process_ms_p99=%.3f process_ms_worst=%.3f accept_n=%d accept_us_mean=%.0f people=%d" % [
		"on" if Ported.enabled() else "off", FRAMES, sum / FRAMES, sorted[int(FRAMES * 0.99)], sorted[-1], new_measures.size(),
		accept_sum / maxf(1.0, new_measures.size()), VillageSession.village.people.size()])
	print("PORT COST complete")
	get_tree().quit(0)
