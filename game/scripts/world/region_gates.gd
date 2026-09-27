extends Node3D
## The ways out of a region: an old stone arch where the path leaves, with the name of the place
## it leads to. Walk through it to travel (Region.travel). Gates are listed in Region.GATES.

const TREASURE := preload("res://scripts/world/treasure.gd")
const ARCH := preload("res://assets/props/ruin_arch.glb")
const ARCH_OUTSET := 1.5         # the arch stands just past the trigger, so it frames the way out and never hides you

@export var player: Node3D

var _gates: Array = []


func build(shape: WorldShape) -> void:
	_gates = Region.GATES.get(Region.current, [])
	for g: Dictionary in _gates:
		var at: Vector2 = g["at"]
		var p := at + at.normalized() * ARCH_OUTSET
		var arch := TREASURE._solid(ARCH.instantiate())
		add_child(arch)
		arch.global_position = Vector3(p.x, shape.height_at(p.x, p.y) - 0.1, p.y)
		for x in [-1.3, 1.3]:
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.7, 3.0, 0.7)
			col.shape = box
			col.position = Vector3(x, 1.5, 0)
			var body := StaticBody3D.new()
			body.add_child(col)
			arch.add_child(body)
		var sign := Label3D.new()
		sign.text = Region.NAMES[g["to"]]
		sign.font_size = 56
		sign.outline_size = 14
		sign.pixel_size = 0.008
		sign.modulate = Color(1.0, 0.93, 0.78)
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.position = Vector3(0, 4.8, 0)
		arch.add_child(sign)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var p := Vector2(player.global_position.x, player.global_position.z)
	for g: Dictionary in _gates:
		if p.distance_to(g["at"]) < g["radius"]:
			Region.travel(g["to"], g["arrive"])

