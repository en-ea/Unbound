extends RefCounted
## Placeholder props for the stage (stage.gd) until the real ones arrive (props.gd, another agent's
## work): one static function per prop, each returning a fresh Node3D, so the stage swaps to the real
## set by changing its one `Props` line. Plain boxes and spheres, low-poly to sit with the world's
## faceted look; meshes and materials are made once and shared, so fifty cabbages cost one material.
## A prop's origin is where it rests on the ground (thrown props: their centre, lifted by the stage).

## Every prop name a staging can ask for (staging.gd PROPS) has a function here with the same name, so
## the stage finds one by name (Script.call) and falls back here for any the real set lacks.

static var _meshes := {}
static var _materials := {}


## The pillory the victim is locked into, sized for a crouching body (Crouch_Idle puts the neck at
## ~0.84 m and the head 0.2 m in front of the feet). Origin: the ground under the head hole; the board
## faces +z, so the victim kneels on its -z side with the head poking out towards +z.
static func pillory() -> Node3D:
	var root := Node3D.new()
	root.name = "Pillory"
	var wood := _material("pillory_wood", Color(0.42, 0.28, 0.17))
	var dark := _material("pillory_dark", Color(0.16, 0.11, 0.08))
	for side: float in [-0.72, 0.72]:          # two posts
		_add(root, _box("post", Vector3(0.14, 1.25, 0.14)), wood, Vector3(side, 0.625, -0.05))
	_add(root, _box("board", Vector3(1.6, 0.26, 0.09)), wood, Vector3(0.0, 0.82, 0.0))      # the neck board
	_add(root, _box("cap", Vector3(1.7, 0.08, 0.16)), dark, Vector3(0.0, 1.27, -0.05))      # the top rail
	return root


static func cabbage() -> Node3D:
	return _ball("cabbage", 0.13, Color(0.45, 0.66, 0.28), Vector3(1.0, 0.85, 1.0))


static func turnip() -> Node3D:
	var root := _ball("turnip", 0.09, Color(0.86, 0.8, 0.84), Vector3(1.0, 1.1, 1.0))
	_add(root, _box("turnip_top", Vector3(0.04, 0.1, 0.02)), _material("leaf", Color(0.3, 0.55, 0.22)), Vector3(0.0, 0.12, 0.0))
	return root


static func mud() -> Node3D:
	return _ball("mud", 0.1, Color(0.3, 0.2, 0.12), Vector3(1.0, 0.8, 1.0))


static func stone() -> Node3D:
	return _ball("stone", 0.075, Color(0.52, 0.52, 0.54), Vector3(1.2, 0.8, 1.0), 5, 3)


static func flower() -> Node3D:
	return _ball("flower", 0.06, Color(0.95, 0.5, 0.62), Vector3.ONE)


static func wood() -> Node3D:
	var root := Node3D.new()
	_add(root, _box("wood", Vector3(0.12, 0.12, 0.6)), _material("wood", Color(0.5, 0.34, 0.2)), Vector3.ZERO)
	return root


static func torch() -> Node3D:
	var root := Node3D.new()
	_add(root, _box("torch_stick", Vector3(0.05, 0.5, 0.05)), _material("wood", Color(0.5, 0.34, 0.2)), Vector3.ZERO)
	var flame := _material("flame", Color(1.0, 0.62, 0.2))
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.55, 0.15)
	flame.emission_energy_multiplier = 2.0
	_add(root, _box("torch_flame", Vector3(0.09, 0.12, 0.09)), flame, Vector3(0.0, 0.3, 0.0))
	return root


static func _ball(key: String, radius: float, color: Color, squash: Vector3, segments := 7, rings := 4) -> Node3D:
	var root := Node3D.new()
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = segments
		m.rings = rings
		_meshes[key] = m
	var mi := _add(root, _meshes[key], _material(key, color), Vector3.ZERO)
	mi.scale = squash
	return root


static func _box(key: String, size: Vector3) -> Mesh:
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func _material(key: String, color: Color) -> StandardMaterial3D:
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.95
		_materials[key] = m
	return _materials[key]


static func _add(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	# Small props cast no shadow: a speck of shadow is invisible from the camera and costs a draw.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mesh is SphereMesh else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi
