extends Node
## Dev: --lab --bandittest. 1) A bandit stands with its back to you: sneak up and take it down.
## 2) A cutthroat and a shield bandit come at you: swing now and then and parry each blow as it lands.
## Prints what happens ("BANDITTEST ...") and quits after ~40 s.

var _lab: Node
var _player: Node3D
var _t := 0.0
var _phase := 0
var _bandits: Array = []
var _parries := 0
var _hearts_low := 99


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		_lab = get_tree().get_first_node_in_group("build_lab")
		return
	if _t < 1.5:
		return
	_hearts_low = mini(_hearts_low, _player.health)
	match _phase:
		0:
			_lab.spawn("cutthroat")
			_bandits = get_tree().get_nodes_in_group("bandit")
			_player.set_sneaking(true)
			_phase = 1
			print("BANDITTEST spawned a bandit, sneaking up")
		1:
			var b: Node3D = _bandits[0]
			var to := b.global_position - _player.global_position
			to.y = 0.0
			if to.length() > 1.4:
				Controls.joystick = Vector2(to.normalized().x, to.normalized().z).rotated(Controls.cam_yaw) * 0.7
			else:
				Controls.joystick = Vector2.ZERO
			if _player.fighter.verb == "Takedown":
				_player.act()
				print("BANDITTEST takedown pressed, bandit aware %.2f alerted %s" % [b.aware, b.alerted])
				_phase = 2
				_t = 1.0
			elif _t > 14.0:
				print("BANDITTEST never got a takedown: aware %.2f alerted %s dist %.1f" % [b.aware, b.alerted, to.length()])
				_phase = 2
				_t = 1.0
		2:
			if _t > 2.5:
				print("BANDITTEST first bandit alive: %s" % _bandits[0].is_alive())
				Controls.joystick = Vector2.ZERO
				_player.set_sneaking(false)
				_lab.spawn("cutthroat")
				_lab.spawn("shield")
				_bandits = get_tree().get_nodes_in_group("bandit").filter(func(n: Node) -> bool: return n.is_alive())
				for b in _bandits:
					b._alert(true)
				_phase = 3
				_t = 0.0
		3:
			for b in _bandits:
				if b.is_alive() and b.state == Bandit.State.STAGGER and b._t < delta * 1.5:
					_parries += 1
			for b in _bandits:
				if b.is_alive() and b.state == Bandit.State.ATTACK and b._t < 0.06 and b._t + delta >= 0.04:
					_player.guard()
			if fmod(_t, 0.7) < delta and _player.fighter.verb == "Attack":
				_player.act()
			for b in _bandits:
				if b.is_open() and fmod(_t, 0.25) < delta:
					_player.act()
			if _t > 30.0 or _bandits.all(func(b: Node) -> bool: return not b.is_alive()):
				print("BANDITTEST fight over after %.1f s: bandits alive %s, health %s, lowest hearts %d, player hearts %d, staggers %d" % [
					_t, _bandits.map(func(b: Node) -> bool: return b.is_alive()), _bandits.map(func(b: Node) -> int: return b.health), _hearts_low, _player.health, _parries])
				get_tree().quit()
