extends Node
## Dev: --lab --shadetest. Become a Shade by two bandits and a boar: Mirage (is the double on the ground,
## not on your head?), Shadow Dance, a shadow roll, then Switch. Prints "SHADETEST ..." lines, saves
## screenshots to %TEMP% (shade_*.png) and quits.

var _lab: Node
var _player: Node3D
var _t := 0.0
var _step := 0
var _foes: Array = []


func _shot(name_: String) -> void:
	get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/shade_%s.png" % name_)


func _hp() -> Array:
	return _foes.map(func(e: Node) -> int: return e.health if is_instance_valid(e) else -1)


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		_lab = get_tree().get_first_node_in_group("build_lab")
		return
	var shade: Shade = _player.abilities.shade
	if _step == 0 and _t > 1.2:
		Classes.choose("shade")
		_lab.spawn("cutthroat")
		_lab.spawn("cutthroat")
		_lab.spawn("boar")
		_foes = get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool: return e.is_alive())
		print("SHADETEST foes %s" % [_hp()])
		_step = 1
	elif _step == 1 and _t > 2.0:
		_player.abilities.use("mirage")
		_step = 2
	elif _step == 2 and _t > 2.6:
		for d in shade._pool:
			if d.active:
				print("SHADETEST double y %.2f, player y %.2f" % [d.global_position.y, _player.global_position.y])
		_shot("mirage")
		_step = 3
	elif _step == 3 and _t > 3.4:
		_player.abilities.use("shadow_dance")
		_step = 4
	elif _step == 4 and _t > 3.68:
		_shot("dance")
		_step = 5
	elif _step == 5 and _t > 4.6:
		print("SHADETEST after dance %s, dancing %s" % [_hp(), shade.dancing])
		_player.roll()
		_step = 6
	elif _step == 6 and _t > 4.75:
		_shot("roll")
		_step = 7
	elif _step == 7 and _t > 5.4:
		_player.abilities.use("switch")
		_step = 8
	elif _step == 8 and _t > 5.6:
		print("SHADETEST after switch player y %.2f, ground %.2f" % [_player.global_position.y, shade.ground_at(_player.global_position).y])
		_step = 9
	elif _step == 9 and _t > 6.5:
		get_tree().quit()
