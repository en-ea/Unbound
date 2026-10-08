extends SceneTree
## Dev: the Sunreach models (tools-src/blender/make_sunreach.py) in a row on sand or sea, drawn the way
## the game draws them (foliage_solid.gdshader, albedo white, glow on "Glow" surfaces), saved as a picture.
## Run (not headless): Godot --path game -s res://scripts/dev/sunreach_lineup.gd -- --set=nature --shot=C:/x.png

const SOLID := preload("res://shaders/foliage_solid.gdshader")
const DIR := "res://assets/sunreach/%s.glb"
const SETS := {
	"nature": ["palm_a", "palm_b", "palm_small", "cactus_a", "cactus_b", "desert_shrub", "dune_grass", "rock_sand_a",
		"rock_sand_b", "rock_sand_c", "mesa_big", "sand_arch"],
	"town": ["house_dome", "house_tower", "house_wide", "market_stall", "well", "lantern_post", "palm_planter", "lighthouse"],
	"sea": ["pier", "ship", "sea_rock", "islet", "serpent_head", "serpent_segment", "serpent_segment", "serpent_tail"],
}

var _frames := 0
var _shot := ""


func _initialize() -> void:
	var set_name := "nature"
	var yaw := 0.45
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			set_name = a.get_slice("=", 1)
		elif a.begins_with("--shot="):
			_shot = a.get_slice("=", 1)
		elif a.begins_with("--yaw="):
			yaw = float(a.get_slice("=", 1))
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.8, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	world.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(400, 400)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.55, 0.6) if set_name == "sea" else Color(0.93, 0.8, 0.56)
	floor_mesh.material = floor_mat
	var fl := MeshInstance3D.new()
	fl.mesh = floor_mesh
	world.add_child(fl)
	var x := 0.0
	var seg_i := 0
	for name: String in SETS[set_name]:
		var node := (load(DIR % name) as PackedScene).instantiate() as Node3D
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s)
				var mat := ShaderMaterial.new()
				mat.shader = SOLID
				mat.set_shader_parameter("albedo", Color.WHITE)
				mat.set_shader_parameter("sway", 0.0)
				mat.set_shader_parameter("glow", 1.5 if src and src.resource_name == "Glow" else 0.0)
				mi.set_surface_override_material(s, mat)
		world.add_child(node)
		var w := _width(node)
		if name == "serpent_segment" or name == "serpent_tail":
			node.position = Vector3(x - w * 0.5, 1.0, 2.2 + 2.2 * seg_i)     # chained behind the head
			node.rotation.y = 0.0
			seg_i += 1
			continue
		x += w * 0.5
		node.position = Vector3(x, 1.0 if name == "serpent_head" else 0.0, 0)
		node.rotation.y = yaw
		x += w * 0.5 + 1.5
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 50
	var mid := x * 0.5
	var dist := maxf(x * 0.75, 12.0)
	cam.position = Vector3(mid, dist * 0.42, dist)
	cam.look_at(Vector3(mid, 2.5, 0))
	cam.current = true


func _width(node: Node3D) -> float:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var bb := mi.transform * mi.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	return maxf(box.size.x, box.size.z) * 0.85


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 60 and _shot != "":
		root.get_texture().get_image().save_png(_shot)
		return true
	return false
