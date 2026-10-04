extends Node
## Dev: --bountytest. Takes this region's three bounties, walks you up to the wanted beast (screenshot
## %TEMP%/bounty_wanted.png), kills it, claims the reward. Prints "BOUNTYTEST ..." lines and quits.

var _t := 0.0
var _step := 0
var _player: Node3D
var _beast: Node3D


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	if _step == 0 and _t > 1.0:
		for b in Bounties.board(Region.current).duplicate():
			Bounties.take(b)
		for b in Bounties.taken:
			print("BOUNTYTEST took %s (%s) %d coins" % [b["title"], b["kind"], b["coins"]])
		_step = 1
	elif _step == 1 and _t > 1.5:
		for e in get_tree().get_nodes_in_group("elite"):
			_beast = e
		print("BOUNTYTEST beast %s hp %d" % [_beast.get_meta("bounty_id", -1) if _beast else "none", _beast.health if _beast else 0])
		if _beast:
			_player.global_position = _beast.global_position + Vector3(4, 0.5, 3)
			get_tree().call_group("camera_rig", "snap")
		_step = 2
	elif _step == 2 and _t > 3.2:
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/bounty_wanted.png")
		print("BOUNTYTEST tracker: %s | %s" % [Quests.name_of(Quests.tracked_quest()), Quests.step_text(Quests.tracked_quest())])
		while _beast and _beast.is_alive():
			_beast.take_hit(_player.global_position, 999)
		_step = 3
	elif _step == 3 and _t > 4.0:
		for b in Bounties.taken.duplicate():
			if Bounties.is_ready(b):
				var gear := Bounties.claim(b)
				print("BOUNTYTEST claimed %s, gear %s, coins now %d, renown %d" % [b["title"], gear, Money.coins, Bounties.renown])
		print("BOUNTYTEST elites left %d" % get_tree().get_nodes_in_group("elite").size())
		get_tree().quit()
