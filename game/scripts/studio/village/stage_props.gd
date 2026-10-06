extends RefCounted
## Placeholder props for the stage (stage.gd): what the real set (props.gd) lacks - flowers, wood and
## torches to carry, the elder's bench for a trial (built with props.gd's kit, so it matches), and the fire
## at the stake. One static function per prop, each returning a fresh Node3D; the stage asks props.gd
## first and falls back here. Plain boxes and spheres, low-poly to sit with the world's faceted look;
## meshes and materials are made once and shared, so fifty cabbages cost one material.
## A prop's origin is where it rests on the ground (thrown props: their centre, lifted by the stage).

const Props := preload("res://scripts/studio/village/props.gd")

## Every prop name a staging can ask for (staging.gd PROPS) has a function here with the same name, so
## the stage finds one by name (Script.call) and falls back here for any the real set lacks.

static var _meshes := {}
static var _materials := {}


## The pillory the victim is locked into, sized for a crouching body (Crouch_Idle puts the neck at
## ~0.84 m and the head 0.2 m in front of the feet): the board stops just under the chin, so the head
## shows over it and the body hides behind. Origin: the ground under the head hole; the board faces +z,
## so the victim kneels on its -z side with the head poking out towards +z.
static func pillory() -> Node3D:
	var root := Node3D.new()
	root.name = "Pillory"
	var wood := _material("pillory_wood", Color(0.42, 0.28, 0.17))
	var dark := _material("pillory_dark", Color(0.16, 0.11, 0.08))
	for side: float in [-0.72, 0.72]:          # two posts
		_add(root, _box("post", Vector3(0.14, 1.25, 0.14)), wood, Vector3(side, 0.625, -0.05))
	_add(root, _box("board", Vector3(1.6, 0.28, 0.09)), wood, Vector3(0.0, 0.72, 0.0))      # the neck board
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
	# Light and a little large: the path is strewn with dark grey pebbles, and a stone has to read in flight.
	return _ball("stone", 0.1, Color(0.78, 0.75, 0.7), Vector3(1.2, 0.8, 1.0), 5, 3)


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


## The elder's bench for a trial: a trestle table with a ledger and a little stack of coins on it. One
## mesh (props.gd's kit). Faces +z (the accused stands on that side, the elder behind it).
static func bench() -> Node3D:
	return Props._prop("bench", func(k: Props.Kit) -> void:
		k.box(Vector3(0, 0.74, 0), Vector3(1.5, 0.07, 0.62), Props.PALE_WOOD)           # top
		for x in [-0.6, 0.6]:
			k.box(Vector3(x, 0.36, 0), Vector3(0.08, 0.72, 0.5), Props.WOOD)            # trestles
			k.box(Vector3(x, 0.03, 0), Vector3(0.14, 0.06, 0.6), Props.DARK_WOOD)
		k.box(Vector3(0, 0.3, 0), Vector3(1.2, 0.06, 0.06), Props.DARK_WOOD)            # stretcher
		k.box(Vector3(-0.3, 0.79, -0.05), Vector3(0.34, 0.03, 0.26), Color(0.45, 0.2, 0.16))   # ledger
		k.box(Vector3(-0.3, 0.805, -0.05), Vector3(0.3, 0.01, 0.23), Props.PAPER)
		for i in 4:                                                                      # coins
			k.prism(Vector3(0.3 + (i % 2) * 0.09, 0.785 + (i / 2) * 0.018, 0.08), 0.035, 0.016, Color(0.9, 0.76, 0.3), 7))


## The fire at the stake, lit by the stage: low-poly flames (one unshaded mesh, orange outside and yellow
## in, which the stage scales to grow and flicker) and a column of smoke (CPU particles, one draw call).
## Origin on the ground at the post; "Flames" and "Smoke" are its children.
static func fire() -> Node3D:
	var root := Node3D.new()
	root.name = "Fire"
	if not _meshes.has("flames"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tongues := [[0.0, 0.0, 0.34, 1.25, 0], [0.3, 0.1, 0.22, 0.9, 1], [-0.28, 0.12, 0.22, 1.0, 1], [0.12, -0.3, 0.24, 1.05, 0],
			[-0.2, -0.24, 0.2, 0.85, 1], [0.34, -0.2, 0.18, 0.7, 0], [-0.36, -0.05, 0.18, 0.75, 0], [0.05, 0.32, 0.2, 0.8, 1],
			[0.0, 0.0, 0.2, 1.5, 2], [0.18, 0.12, 0.13, 1.1, 2], [-0.15, -0.1, 0.13, 1.15, 2]]
		for t: Array in tongues:
			var colour: Color = [Color(0.95, 0.42, 0.1), Color(1.0, 0.6, 0.15), Color(1.0, 0.86, 0.35)][t[4]]
			_cone(st, Vector3(t[0], 0.25, t[1]), t[2], t[3], colour, 5)
		_meshes["flames"] = st.commit()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials["flames"] = m
	var flames := MeshInstance3D.new()
	flames.name = "Flames"
	flames.mesh = _meshes["flames"]
	flames.material_override = _materials["flames"]
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flames)
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	if not _meshes.has("puff"):
		var puff := SphereMesh.new()
		puff.radius = 0.36
		puff.height = 0.72
		puff.radial_segments = 6
		puff.rings = 3
		_meshes["puff"] = puff
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		puff.material = m
	smoke.mesh = _meshes["puff"]
	smoke.amount = 40
	smoke.lifetime = 6.0
	smoke.emitting = false
	smoke.local_coords = false
	smoke.position = Vector3(0.0, 1.3, 0.0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.35
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.15, 0.25, 0.0)          # rises, drifting a little east
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.0
	smoke.scale_amount_min = 0.7
	smoke.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 3.2))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.3, 0.29, 0.28, 0.85))
	fade.set_color(1, Color(0.62, 0.6, 0.58, 0.0))
	smoke.color_ramp = fade
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(smoke)
	return root


## A cone of `sides` faces from `base` up `height` metres, flat-shaded, in one colour.
static func _cone(st: SurfaceTool, base: Vector3, radius: float, height: float, colour: Color, sides: int) -> void:
	var tip := base + Vector3(0.0, height, 0.0)
	st.set_color(colour)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := base + Vector3(cos(a0), 0.0, sin(a0)) * radius
		var p1 := base + Vector3(cos(a1), 0.0, sin(a1)) * radius
		st.add_vertex(p0)
		st.add_vertex(tip)
		st.add_vertex(p1)
