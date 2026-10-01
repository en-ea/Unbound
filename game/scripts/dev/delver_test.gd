extends Node
## Dev: --delvertest (out in the meadow). Become a Delver, face a pack, and use everything: Fault Line, Sinkhole, then
## Burrow, Drag Under and Erupt. Prints their health after each ("DELVERTEST ...") and saves a screenshot
## at each big moment to %TEMP%\delver_<n>.png, then quits.

const BOAR := preload("res://scenes/boar.tscn")
const WOLF := preload("res://scenes/wolf.tscn")

var _player: Node3D
var _t := 0.0
var _step := 0
var _foes: Array = []


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	var plan := [
		[1.2, func() -> void:
			Classes.choose("delver")
			for k in ["cutthroat", "wolf", "boar", "wolf"]:
				_spawn(k)
			_foes = get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool:
				return e.is_alive() and (e as Node3D).global_position.distance_to(_player.global_position) < 12.0)
			_report("foes")],
		[2.4, func() -> void: _shot(0)],                                  # claws on, idle
		[2.6, func() -> void: _player.abilities.use("fault_line")],
		[3.25, func() -> void: _shot(1)],                                 # spikes up along the crack
		[4.5, func() -> void:
			_report("after fault line")
			_player.abilities.use("sinkhole")],
		[5.6, func() -> void: _shot(2)],                                  # the pit pulling them in
		[8.0, func() -> void:
			_report("after sinkhole")
			_player.abilities.use("burrow")],
		[8.6, func() -> void:
			Controls.joystick = Vector2(0.0, -1.0)],
		[9.1, func() -> void:
			Controls.joystick = Vector2.ZERO
			_shot(3)],                                                    # the mound
		[9.3, func() -> void: _player.abilities.use("burrow")],           # drag under
		[9.7, func() -> void: _shot(4)],
		[10.3, func() -> void:
			_report("after drag")
			_player.act()],                                               # erupt
		[10.5, func() -> void: _shot(5)],
		[11.6, func() -> void:
			_report("after erupt")
			print("DELVERTEST player hearts %d, burrowed %s" % [_player.health, _player.burrowed()])
			get_tree().quit()],
	]
	if _step < plan.size() and _t > plan[_step][0]:
		plan[_step][1].call()
		_step += 1


## A foe a few metres in front of you, a little to one side or the other.
func _spawn(kind: String) -> void:
	var facing := Vector3(sin(_player.visual.rotation.y), 0, cos(_player.visual.rotation.y))
	var at: Vector3 = _player.global_position + facing * randf_range(4.0, 6.0) + facing.cross(Vector3.UP) * randf_range(-1.5, 1.5)
	if Carcass.shape:
		at.y = Carcass.shape.height_at(at.x, at.z)
	if kind == "cutthroat":
		var b := Bandit.new()
		b.kind = kind
		b.player = _player
		b.post = at
		b.look = BanditLooks.make(0, randi())
		_player.get_parent().add_child(b)
		b.global_position = at + Vector3(0, 0.3, 0)
		return
	var e: CharacterBody3D = (BOAR if kind == "boar" else WOLF).instantiate()
	e.player = _player
	e.home = at
	_player.get_parent().add_child(e)
	e.global_position = at + Vector3(0, 0.5, 0)


func _report(what: String) -> void:
	print("DELVERTEST %s %s" % [what, _foes.map(func(e: Node) -> String:
		return ("%d/%d%s" % [e.health, e.max_health, "c" if EarthFX.is_cracked(e) else ""]) if is_instance_valid(e) else "gone")])


func _shot(n: int) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := OS.get_environment("TEMP").path_join("delver_%d.png" % n)
	print("DELVERTEST shot %s: %s" % [path, error_string(img.save_png(path))])
