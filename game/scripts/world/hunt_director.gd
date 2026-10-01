extends Node3D
## Bait: leave three bodies close together out in the open at night and something comes for them. After a
## warning it walks in out of the dark: the Duskmaw (a huge wolf-thing, wolf.gd with `duskmaw`), which
## eats the dead and fights for them. Once a night.

const WOLF := preload("res://scenes/wolf.tscn")

var player: Node3D
var day_night: Node
var _tick := 0.0
var _waiting := -1.0           # seconds until it arrives (-1: nothing called)
var _where := Vector3.ZERO
var _used_tonight := false


func _ready() -> void:
	add_to_group("hunt_director")


## Test menu: the Duskmaw comes now, for a spot a little way in front of you (no bodies or night needed).
func call_now() -> void:
	var facing := Vector3(sin(player.visual.rotation.y), 0, cos(player.visual.rotation.y))
	_where = player.global_position + facing * 8.0
	_waiting = 1.0
	_used_tonight = true
	get_tree().call_group("hud", "hint", "Something big is coming out of the dark...")


func _process(delta: float) -> void:
	var night: float = day_night.night
	if night < 0.3:
		_used_tonight = false
	if _waiting >= 0.0:
		_waiting -= delta
		if _waiting < 0.0:
			_arrive()
		return
	_tick -= delta
	if _tick > 0.0 or _used_tonight or night < 0.5:
		return
	_tick = 2.0
	var bodies := get_tree().get_nodes_in_group("carcass").filter(func(c: Node) -> bool: return not c.dragged)
	var h: Dictionary = Balance.HUNT
	for c: Node3D in bodies:
		var near := bodies.filter(func(o: Node3D) -> bool: return o.global_position.distance_to(c.global_position) < h["summon_spread"])
		if near.size() >= h["summon_count"]:
			var mid := Vector3.ZERO
			for o: Node3D in near:
				mid += o.global_position
			_where = mid / near.size()
			_waiting = h["summon_wait"]
			_used_tonight = true
			get_tree().call_group("hud", "hint", "The dead lie out in the dark. Something has smelled them.")
			return


func _arrive() -> void:
	var away := _where - player.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3.FORWARD
	var at := _where + away.normalized() * 16.0
	var beast := WOLF.instantiate() as Wolf
	beast.player = player
	beast.duskmaw = true
	beast.home = _where
	get_parent().add_child(beast)
	beast.global_position = at + Vector3(0, 1.0, 0)
	get_tree().call_group("hud", "hint", "The Duskmaw.")
	Banner.show_now(get_tree().get_first_node_in_group("hud"), "THE DUSKMAW", "It came for the dead", Color(0.75, 0.3, 0.4),
		preload("res://assets/sounds/wolf_growl.wav"), 2.4)
