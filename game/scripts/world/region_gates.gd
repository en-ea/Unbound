extends Node3D
## The ways out of a region: a gateway where the path leaves (stone pillars with lanterns, a little
## roof and a hanging sign with the name of the place it leads to). Walk through it to travel
## (Region.travel). Gates are listed in Region.GATES. Model: make_props.py gateway().

const TREASURE := preload("res://scripts/world/treasure.gd")
const ARCH := preload("res://assets/props/gateway.glb")
const ARCH_OUTSET := 1.5         # the arch stands just past the trigger, so it frames the way out and never hides you

@export var player: Node3D

var _gates: Array = []


func build(shape: WorldShape) -> void:
	_gates = Region.GATES.get(Region.current, [])
	for g: Dictionary in _gates:
		var at: Vector2 = g["at"]
		if g["to"] == "sea" and WorldShape.coast:  # Sunreach's way out is the ship at the end of the pier
			continue
		var p := at + at.normalized() * ARCH_OUTSET
		var arch := TREASURE._solid(ARCH.instantiate())
		add_child(arch)
		arch.global_position = Vector3(p.x, shape.height_at(p.x, p.y) - 0.1, p.y)
		for x in [-1.7, 1.7]:
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.7, 3.0, 0.7)
			col.shape = box
			col.position = Vector3(x, 1.5, 0)
			var body := StaticBody3D.new()
			body.add_child(col)
			arch.add_child(body)
		var sign := Label3D.new()                  # painted on the hanging board
		sign.text = "Harbour: Sunreach" if g["to"] == "sea" else Region.NAMES[g["to"]]
		sign.font_size = 48
		sign.outline_size = 6
		sign.pixel_size = 0.0045
		sign.modulate = Color(0.28, 0.16, 0.08)
		sign.outline_modulate = Color(0.95, 0.85, 0.62, 0.5)
		sign.position = Vector3(0, 2.25, 0.13)
		arch.add_child(sign)
		var glow := OmniLight3D.new()              # the lanterns light the way at night
		glow.light_color = Color(1.0, 0.7, 0.4)
		glow.omni_range = 5.0
		glow.light_energy = 0.8
		glow.position = Vector3(0, 2.8, 0.6)
		arch.add_child(glow)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var p := Vector2(player.global_position.x, player.global_position.z)
	for g: Dictionary in _gates:
		if p.distance_to(g["at"]) < g["radius"]:
			Region.travel(g["to"], g["arrive"])

