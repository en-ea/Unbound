extends Node
## Dev: --region=forest --sealtest. Takes Morrow's job, then strikes Varek down in his camp and checks
## that his black seal drops and can be picked up. Prints "SEALTEST ..." and quits.

var _t := 0.0
var _done := false


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < 2.0 or _done:
		return
	_done = true
	if Quests.status("morrow_seal") == "new":
		Quests.accept("morrow_seal")
	var leader: Node3D = null
	for b in get_tree().get_nodes_in_group("bandit"):
		if b.kind == "leader":
			leader = b
	if leader == null:
		print("SEALTEST no leader found")
		get_tree().quit()
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	player.global_position = leader.global_position + Vector3(0, 0.5, 2.0)
	leader.health = 1
	leader.take_hit(player.global_position, 5, 1.0)
	print("SEALTEST leader alive %s, quest %s" % [leader.is_alive(), Quests.status("morrow_seal")])
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		print("SEALTEST seal in bag %d, quest %s" % [Inventory.count("black_seal"), Quests.status("morrow_seal")])
		get_tree().quit())
