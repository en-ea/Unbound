extends Node
## Dev: --carttest. Burn a villager down with a Meteor, lift the body, carry it to the ox cart and tap there.
## Prints "CARTTEST ..." lines and quits. (The owner's 6 Oct crash on the studio-merge preview.)

const Contact := preload("res://scripts/studio/village/contact.gd")

var _player: Node3D
var _t := 0.0
var _step := 0
var _victim := -1
var _mark := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	var res := Contact.registry(get_tree())
	var hud := get_tree().get_first_node_in_group("hud")
	if fmod(_t, 3.0) < delta:
		print("CARTTEST mem %.0f MB, video %.0f MB, objects %d, fps %d" % [OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.OBJECT_COUNT), Engine.get_frames_per_second()])
	if _step == 0 and _t > 3.0:
		Classes.choose("pyromancer")
		for id: int in res.bodies:
			if VillageSession.village.people[id].alive and Contact.capable(res, VillageSession.village, id):
				_victim = id
				break
		var at: Vector3 = res.bodies[_victim].global_position
		_player.global_position = at + Vector3(4, 0.5, 0)
		print("CARTTEST victim %d at %s" % [_victim, at])
		_step = 1
	elif _step == 1 and fmod(_t, 2.0) < delta:
		var p = VillageSession.village.people[_victim]
		if not p.alive or _t > 30.0:
			_step = 2
			return
		var at: Vector3 = res.bodies[_victim].global_position
		_player.global_position = at + Vector3(4, 0.5, 0)
		Classes.hurry_cooldowns(99.0)
		_player.abilities.use("meteor", {"at": at, "dir": Vector3.FORWARD, "press_id": "carttest:%d" % _t})
		print("CARTTEST meteor, hurt %d active=%s bg=%s locked=%s class=%s cd=%.1f pos=%s" % [p.hurt, VillageSession.active, VillageSession.background, Controls.locked, Classes.current, Classes.cooldown_left("meteor"), res.bodies[_victim].global_position])
	elif _step == 2:
		var p = VillageSession.village.people[_victim]
		print("CARTTEST after meteor alive=%s hurt=%d facts=%s" % [p.alive, p.hurt, p.body_facts.keys()])
		_player.global_position = res.bodies[_victim].global_position + Vector3(0.6, 0.3, 0)
		_step = 3
		_mark = _t
	elif _step == 3 and _t > _mark + 1.0:
		print("CARTTEST action button says %s" % _player.verb)
		var d = hud._hands.driver
		var intent: Dictionary = d.capture("grip")
		print("CARTTEST grip context %s" % intent.context)
		d.commit("grip", intent)
		_step = 4
	elif _step == 4 and _t > _mark + 2.0:
		print("CARTTEST carrying person=%s, action button says %s" % [_player.has_meta("studio_people_load"), _player.verb])
		var cart := get_tree().get_first_node_in_group("ox_cart") as Node3D
		_player.global_position = cart.global_position + Vector3(7, 0.5, 0)
		var to := Vector2(-1, 0)
		Controls.joystick = to.rotated(Controls.cam_yaw)
		print("CARTTEST walking to the cart %s" % cart.global_position)
		_step = 5
	elif _step == 5 and _t > _mark + 9.0:
		Controls.joystick = Vector2.ZERO
		var cart := get_tree().get_first_node_in_group("ox_cart") as Node3D
		_player.global_position = cart.global_position + Vector3(1.5, 0.5, 0)
		_step = 6
	elif _step == 6 and _t > _mark + 9.5:
		var d = get_tree().get_first_node_in_group("hud")._hands.driver
		var intent: Dictionary = d.capture("act")
		print("CARTTEST tap at cart: %s %s" % [intent.get("tap", ""), intent.context])
		d.commit(intent.tap if intent.tap == "grip" else "use", intent)
		_step = 7
	elif _step == 7 and _t > _mark + 11.0:
		var cart := get_tree().get_first_node_in_group("ox_cart") as Node3D
		var res2 := Contact.registry(get_tree())
		print("CARTTEST in bed=%s carrying=%s body at %s cart at %s" % [cart.get_meta("studio_people_load", -1), _player.has_meta("studio_people_load"), res2.bodies[_victim].global_position, cart.global_position])
		cart.interact()   # ride it with the body in the bed
		Controls.joystick = Vector2(0, 1)
		_step = 8
	elif _step == 8 and _t > _mark + 15.0:
		Controls.joystick = Vector2.ZERO
		var cart := get_tree().get_first_node_in_group("ox_cart") as Node3D
		var res2 := Contact.registry(get_tree())
		print("CARTTEST drove: riding=%s body at %s cart at %s" % [_player.hauling.riding != null, res2.bodies[_victim].global_position, cart.global_position])
		_player.hauling.get_off()
		var back := Vector3(sin(cart.rotation.y), 0, cos(cart.rotation.y))
		_player.global_position = cart.global_position - back * 1.6 + Vector3(0, 0.5, 0)
		_step = 9
	elif _step == 9 and _t > _mark + 16.0:
		var cart := get_tree().get_first_node_in_group("ox_cart") as Node3D
		var d = get_tree().get_first_node_in_group("hud")._hands.driver
		var intent: Dictionary = d.capture("act")
		print("CARTTEST verb %s, tap behind: %s %s" % [cart.verb, intent.get("tap", ""), intent.context])
		d.commit(intent.tap if intent.tap == "grip" else "use", intent)
		_step = 10
	elif _step == 10 and _t > _mark + 18.0:
		var cart := get_tree().get_first_node_in_group("ox_cart") as Node3D
		print("CARTTEST done: in bed=%s carrying=%s" % [cart.get_meta("studio_people_load", -1), _player.has_meta("studio_people_load")])
		get_tree().quit()
