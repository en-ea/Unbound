extends Node3D
## Fernhollow, the village in the Whispering Wood (placed by places.gd at its clearing): homes made from
## the wood itself (make_forest_village.py and the old stump house from make_buildings.py) round a
## campfire, with lantern posts. Its people are in Npcs (region "forest"); world/npc.gd builds them.

const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")
const DIR := "res://assets/buildings/%s.glb"
## Homes: model, spot from the middle (x, z), how wide to block them, map footprint.
const HOMES := [
	{"model": "house_lantern_inn", "at": Vector2(8.0, -5.0), "radius": 2.2, "size": Vector2(5, 5)},
	{"model": "house_sawn_stump", "at": Vector2(-8.5, -2.5), "radius": 2.5, "size": Vector2(5, 5)},
	{"model": "house_toadstool", "at": Vector2(-5.5, 8.5), "radius": 1.8, "size": Vector2(6, 6)},
	{"model": "house_root", "at": Vector2(7.5, 7.0), "radius": 2.0, "size": Vector2(4, 4)},
	{"model": "house_stump", "at": Vector2(0.5, -11.0), "radius": 3.0, "size": Vector2(6, 6)},
]
const POSTS := [Vector2(3.5, -2.0), Vector2(-3.5, 2.5), Vector2(2.5, 4.0), Vector2(-2.0, -4.5)]
const GLOW := Color(1.0, 0.72, 0.38)


func build(shape: WorldShape) -> void:
	var mid := Vector2(global_position.x, global_position.z)
	for h: Dictionary in HOMES:
		var at: Vector2 = mid + h["at"]
		var house := (load(DIR % h["model"]) as PackedScene).instantiate() as Node3D
		_solid(house)
		add_child(house)
		house.global_position = Vector3(at.x, shape.height_at(at.x, at.y) - 0.1, at.y)
		var to_mid: Vector2 = mid - at                     # every door faces the fire
		house.rotation.y = atan2(to_mid.x, to_mid.y)
		house.add_to_group("map_building")
		house.set_meta("map_size", h["size"])
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = h["radius"]
		cyl.height = 5.0
		col.shape = cyl
		col.position = Vector3(0, 2.5, 0)
		body.add_child(col)
		house.add_child(body)
	for p: Vector2 in POSTS:
		_post(Vector3(mid.x + p.x, shape.height_at(mid.x + p.x, mid.y + p.y), mid.y + p.y))
	var fire := Node3D.new()
	fire.set_script(preload("res://scripts/world/campfire.gd"))
	add_child(fire)
	fire.build(shape, mid)


func _solid(node: Node) -> void:
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var mat := ShaderMaterial.new()
			mat.shader = SOLID_SHADER
			mat.set_shader_parameter("albedo", Color.WHITE)
			mat.set_shader_parameter("sway", 0.0)
			mat.set_shader_parameter("glow", 1.5 if src and src.resource_name == "Glow" else 0.0)
			mi.set_surface_override_material(s, mat)


## A crooked wooden post with a glowing lantern.
func _post(at: Vector3) -> void:
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.1
	cyl.height = 2.0
	cyl.radial_segments = 5
	cyl.rings = 1
	post.mesh = cyl
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.24, 0.16)
	post.material_override = wood
	add_child(post)
	post.global_position = at + Vector3(0, 1.0, 0)
	post.rotation.z = randf_range(-0.06, 0.06)
	var lamp := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.28, 0.22)
	lamp.mesh = box
	var glow := StandardMaterial3D.new()
	glow.albedo_color = GLOW
	glow.emission_enabled = true
	glow.emission = GLOW
	glow.emission_energy_multiplier = 1.6
	lamp.material_override = glow
	add_child(lamp)
	lamp.global_position = at + Vector3(0, 2.1, 0)
