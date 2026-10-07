extends Node
## A wolf that dies beside villagers and is freed 3 s later (wolf.gd: the Duskmaw's body goes) gives no script errors
## (desk 6 Oct, Water's finding: a body freed within the crowd's 0.5 s look for nearby animals, residents.gd
## OTHERS_EVERY, errored on a typed assignment - "previously freed instance"). Also the harder case: a wolf freed
## while still standing among them (a creature cleared, inside the look's cache).
##   --studio=village/live --merge-check=freed_wolf_check --save-guard --test-save=<fresh name>
## Prints PASS/FAIL lines and "FREED complete failures=N".
const Contact := preload("res://scripts/studio/village/contact.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const NoteLog := preload("res://scripts/studio/notes/note_log.gd")
const WOLF := preload("res://scenes/wolf.tscn")
const UnboundNotes := preload("res://scripts/studio/notes/unbound_notes.gd")
var failed := 0
var log := NoteLog.new()


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("FreedWolfCheck"):
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/merge/freed_wolf_check.gd").new()
	probe.name = "FreedWolfCheck"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	OS.add_logger(log)
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS freed " if ok else "FAIL freed ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


## The errors logged since `from` (the logger's count), as "said (where)" lines.
func errors_since(from: int) -> Array:
	var snap := log.snapshot()
	var n: int = int(snap.errors_seen) - from
	return (snap.errors as Array).slice(maxi(0, (snap.errors as Array).size() - n)).map(func(e: Dictionary) -> String: return "%s (%s)" % [e.said, e.at])


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
	var crowd := []
	for id: int in res.bodies:
		var p = v.people[id]
		if p.alive and p.present and p.authored == "" and Rules.age_of(v, p) >= 16:
			crowd.append(id)
			if crowd.size() == 6:
				break
	var centre := Vector2(player.global_position.x + 4.0, player.global_position.z + 4.0)
	for i in crowd.size():
		var a := TAU * float(i) / float(crowd.size())
		res._movers[crowd[i]].place(centre + Vector2(cos(a), sin(a)) * 1.6, a + PI)
	check(crowd.size() == 6, "six grown villagers round a spot beside the player (%d)" % crowd.size())
	await seconds(1.0)
	var at := Vector3(centre.x, player.global_position.y, centre.y)
	# 1. The Duskmaw dies among them; its body is freed 3 s later (wolf.gd _duskmaw_dies).
	var start := int(log.snapshot().errors_seen)
	var beast := WOLF.instantiate() as Wolf
	beast.player = player
	beast.duskmaw = true
	beast.home = at
	player.get_parent().add_child(beast)
	beast.global_position = at + Vector3(0, 0.5, 0)
	beast.set_physics_process(false)         # it stays where it stands, among them
	await seconds(1.0)                       # listed by the crowd's look (OTHERS_EVERY 0.5 s) and in its rows
	var listed: bool = res._world_others.any(func(pair: Array) -> bool: return is_instance_valid(pair[0]) and pair[0] == beast) \
		and res._crowd.nearby.rows.any(func(row: Dictionary) -> bool: return is_instance_valid(row.get("body")) and row.get("body") == beast)
	beast.take_hit(player.global_position, 9999)
	await seconds(3.4)                       # (its own 3 s timer starts at the hit, before this one)
	var freed := not is_instance_valid(beast)
	await seconds(1.0)
	var errs := errors_since(start)
	check(listed and freed and errs.is_empty(), "the Duskmaw killed beside villagers and freed 3 s later: 0 script errors over the next second (listed %s, freed %s, errors %s)" % [listed, freed, str(errs.slice(0, 3))])
	# 2. A wolf freed standing among them, inside the look's cache and the crowd's rows.
	start = int(log.snapshot().errors_seen)
	var wolf := WOLF.instantiate() as Wolf
	wolf.player = player
	wolf.home = at
	player.get_parent().add_child(wolf)
	wolf.global_position = at + Vector3(0, 0.5, 0)
	wolf.set_physics_process(false)          # it stays where it stands, among them
	await seconds(1.0)
	listed = res._world_others.any(func(pair: Array) -> bool: return is_instance_valid(pair[0]) and pair[0] == wolf) \
		and res._crowd.nearby.rows.any(func(row: Dictionary) -> bool: return is_instance_valid(row.get("body")) and row.get("body") == wolf)
	wolf.queue_free()
	await seconds(1.0)
	errs = errors_since(start)
	check(listed and errs.is_empty(), "a wolf freed standing among them (inside the crowd's 0.5 s look): 0 script errors over the next second (listed %s, errors %s)" % [listed, str(errs.slice(0, 3))])
	# 3. A wolf freed while a screen holds the village still (Controls.locked: the crowd keeps its last rows), then
	# the screen closes.
	start = int(log.snapshot().errors_seen)
	var held := WOLF.instantiate() as Wolf
	held.player = player
	held.home = at
	player.get_parent().add_child(held)
	held.global_position = at + Vector3(0, 0.5, 0)
	held.set_physics_process(false)
	await seconds(1.0)
	listed = res._crowd.nearby.rows.any(func(row: Dictionary) -> bool: return is_instance_valid(row.get("body")) and row.get("body") == held)
	Controls.locked = true
	await frames(3)
	held.queue_free()
	await seconds(1.0)
	Controls.locked = false
	await seconds(1.0)
	errs = errors_since(start)
	check(listed and errs.is_empty(), "a wolf freed while a screen holds the village still, then the screen closes: 0 script errors (listed %s, errors %s)" % [listed, str(errs.slice(0, 3))])
	# 4. A bandit among them, out of the fight and freed at once (as the water probe retired its foes: 20 errors).
	start = int(log.snapshot().errors_seen)
	var b := Bandit.new()
	b.kind = "cutthroat"
	b.player = player
	b.post = at
	b.look = BanditLooks.make(0, 7)
	player.get_parent().add_child(b)
	b.global_position = at + Vector3(0, 0.3, 0)
	await seconds(1.5)
	listed = res._crowd.nearby.rows.any(func(row: Dictionary) -> bool: return is_instance_valid(row.get("body")) and row.get("body") == b)
	b.remove_from_group("enemy")
	b.queue_free()
	await seconds(1.0)
	errs = errors_since(start)
	check(listed and errs.is_empty(), "a bandit among them, out of the fight and freed at once: 0 script errors over the next second (listed %s, errors %s)" % [listed, str(errs.slice(0, 3))])
	# 5. The note tool's sample (twice a second in play) reads the crowd's look itself: a wolf freed inside its 0.5 s.
	start = int(log.snapshot().errors_seen)
	var last := WOLF.instantiate() as Wolf
	last.player = player
	last.home = at
	player.get_parent().add_child(last)
	last.global_position = at + Vector3(0, 0.5, 0)
	last.set_physics_process(false)
	await seconds(1.0)
	listed = res._world_others.any(func(pair: Array) -> bool: return is_instance_valid(pair[0]) and pair[0] == last)
	last.queue_free()
	await frames(1)
	var stale: bool = res._world_others.any(func(pair: Array) -> bool: return not is_instance_valid(pair[0]))
	var sampled := UnboundNotes.state_now(get_viewport())
	await frames(2)
	errs = errors_since(start)
	check(listed and stale and sampled.has("others") and errs.is_empty(), "a note sampled while the crowd's look still lists a freed wolf: 0 script errors (listed %s, stale %s, errors %s)" % [listed, stale, str(errs.slice(0, 3))])
	OS.remove_logger(log)
	print("FREED complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
