extends Node
## Dev: --lab --pyrotest. Become a Pyromancer, face two bandits and a boar, call a Meteor, then Flame Dash
## through them. Prints their health after each ("PYROTEST ...") and quits.

var _lab: Node
var _player: Node3D
var _t := 0.0
var _step := 0
var _foes: Array = []


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		_lab = get_tree().get_first_node_in_group("build_lab")
		return
	if _step == 0 and _t > 1.2:
		Classes.choose("pyromancer")
		_lab.spawn("cutthroat")
		_lab.spawn("cutthroat")
		_lab.spawn("boar")
		_foes = get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool: return e.is_alive())
		print("PYROTEST foes %s" % [_foes.map(func(e: Node) -> int: return e.health)])
		_step = 1
	elif _step == 1 and _t > 2.0:
		_player.abilities.use("meteor")
		print("PYROTEST meteor cast, cooldown %.2f" % Classes.cooldown_left("meteor"))
		_step = 2
	elif _step == 2 and _t > 4.0:
		print("PYROTEST after meteor %s" % [_foes.map(func(e: Node) -> int: return e.health if is_instance_valid(e) else -1)])
		_player.abilities.use("flame_dash")
		_step = 3
	elif _step == 3 and _t > 7.5:
		print("PYROTEST after dash + burning %s, player hearts %d" % [_foes.map(func(e: Node) -> int: return e.health if is_instance_valid(e) else -1), _player.health])
		get_tree().quit()
