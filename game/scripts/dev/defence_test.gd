extends Node
## Dev: --defencetest. Stands you 6 m from a boar and lets it attack. The first charge is parried just
## before it lands, the second is dodged with a last-moment roll, then you hit it (a counter). Prints what
## happened ("DEFENCE ...") and quits after ~20 s.

var _player: Node3D
var _boar: Node3D
var _t := 0.0
var _charges := 0
var _acted := false
var _last_state := -1


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		var enemies := get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool: return e is Boar)
		if enemies.is_empty() or _player == null:
			return
		_boar = enemies[0]
		_player.global_position = _boar.global_position + Vector3(0, 0.3, 6.0)
		get_tree().call_group("camera_rig", "snap")
		return
	var st: int = _boar.state
	if st != _last_state:
		print("DEFENCE t=%.1f boar state %d health %d" % [_t, st, _boar.health])
		if st == Boar.State.CHARGE:
			_charges += 1
			_acted = false
		_last_state = st
	var dist := _player.global_position.distance_to(_boar.global_position)
	if st == Boar.State.CHARGE and not _acted and dist < (2.6 if _charges == 1 else 2.2):
		_acted = true
		if _charges == 1:
			_player.guard()
			print("DEFENCE guard at dist %.2f" % dist)
		else:
			_player.roll()
			print("DEFENCE roll at dist %.2f" % dist)
	if st == Boar.State.DAZED and _boar.is_open() and _player.fighter.verb == "Attack" and fmod(_t, 0.5) < delta:
		_player.act()
	if Engine.time_scale < 1.0 and fmod(_t, 0.3) < delta:
		print("DEFENCE slow motion %.2f" % Engine.time_scale)
	if _t > 20.0:
		print("DEFENCE end hearts %d boar health %d" % [_player.health, _boar.health])
		get_tree().quit()
