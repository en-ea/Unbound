extends Node3D
## Where you can fish in this region: anywhere along the pond's edge. While you stand at the shore, a
## "Fish" spot follows you (so the action button says Fish); pressing it casts towards open water.
## (The cave's pool has its own spot, in world/cave.gd.)

const USE_SPOT := preload("res://scripts/world/use_spot.gd")
const OUT := 4.2                 # how far out the bobber lands

var player: CharacterBody3D
var shape: WorldShape
var _spot: Node3D
var _check := 0.0


func build(world: WorldShape) -> void:
	shape = world
	_spot = Node3D.new()
	_spot.set_script(USE_SPOT)
	add_child(_spot)
	_spot.setup(Vector3(0, -50, 0), "Fish", _fish, 2.0)
	_spot.remove_from_group("interactable")


func _physics_process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or shape == null:
		return
	_check = 0.15
	var p := Vector2(player.global_position.x, player.global_position.z)
	var shore := shape.pond_distance(p) - WorldShape.POND_RADIUS
	var near: bool = shore > -2.5 and shore < 2.5 and player.global_position.y > -100.0 \
		and not player.fisher.is_fishing()
	if near:
		_spot.global_position = player.global_position
		if not _spot.is_in_group("interactable"):
			_spot.add_to_group("interactable")
	elif _spot.is_in_group("interactable"):
		_spot.remove_from_group("interactable")


func _fish() -> void:
	var p := Vector2(player.global_position.x, player.global_position.z)
	var c := WorldShape.POND_CENTER
	var out := p + (c - p).normalized() * minf(OUT, p.distance_to(c))
	player.fisher.start(Region.current, Vector3(out.x, WorldShape.WATER_Y + 0.06, out.y))
