extends RefCounted
## The things that stand about a dungeon's rooms, by name (themes.gd lists which go where): fire pits, bones,
## stakes, cages, skull posts, sacks, pillars, crystals, urns. Simple low-poly shapes in flat colours, like
## the game's places. place(kind, parent, at, rng) puts one at `at` (local metres, on the floor).

const WOOD := Color(0.42, 0.28, 0.17)
const DARK_WOOD := Color(0.3, 0.2, 0.13)
const BONE := Color(0.88, 0.84, 0.72)
const STONE := Color(0.55, 0.54, 0.5)
const FIRE := Color(1.0, 0.55, 0.18)
const CLAY := Color(0.62, 0.38, 0.24)
const CRYSTAL := Color(0.55, 0.88, 1.0)

static var _mats := {}


static func place(kind: String, parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.rotation.y = rng.randf() * TAU
	match kind:
		"fire_pit":
			for k in 7:
				var a := TAU * k / 7.0
				_box(root, Vector3(cos(a) * 0.55, 0.08, sin(a) * 0.55), Vector3(0.24, 0.16, 0.2), STONE, a)
			for k in 3:
				_cyl(root, Vector3(0, 0.1, 0), 0.06, 0.8, DARK_WOOD, 5, Vector3(PI / 2.0, TAU * k / 3.0, 0))
			for k in 3:
				_cone(root, Vector3(cos(k * 2.1) * 0.12, 0.35, sin(k * 2.1) * 0.12), 0.18 - k * 0.03, 0.55 - k * 0.1, FIRE, true)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.6, 0.3)
			light.light_energy = 2.2
			light.omni_range = 8.0
			light.position = Vector3(0, 0.9, 0)
			root.add_child(light)
		"bones":
			for k in rng.randi_range(3, 5):
				_cyl(root, Vector3(rng.randf_range(-0.5, 0.5), 0.04, rng.randf_range(-0.5, 0.5)), 0.035, rng.randf_range(0.35, 0.6), BONE, 5,
					Vector3(PI / 2.0, rng.randf() * TAU, 0))
			_ball(root, Vector3(rng.randf_range(-0.3, 0.3), 0.12, rng.randf_range(-0.3, 0.3)), 0.13, BONE)
		"stakes":
			for k in 3:
				var p := Vector3((k - 1) * 0.45, 0.0, rng.randf_range(-0.15, 0.15))
				_cyl(root, p + Vector3(0, 0.7, 0), 0.05, 1.4, WOOD, 5, Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15)))
				_cone(root, p + Vector3(0, 1.5, 0), 0.05, 0.2, WOOD)
			_ball(root, Vector3(0, 1.62, 0), 0.13, BONE)
		"skull_post":
			_cyl(root, Vector3(0, 0.8, 0), 0.07, 1.6, DARK_WOOD, 5)
			_ball(root, Vector3(0, 1.72, 0), 0.15, BONE)
			_box(root, Vector3(0, 1.3, 0), Vector3(0.7, 0.06, 0.06), DARK_WOOD)
		"cage":
			root.rotation.y = 0.0
			for k in 12:
				var a := TAU * k / 12.0
				_cyl(root, Vector3(cos(a) * 0.75, 0.9, sin(a) * 0.75), 0.04, 1.8, DARK_WOOD, 4)
			_cyl(root, Vector3(0, 1.82, 0), 0.82, 0.08, DARK_WOOD, 12)
			_cyl(root, Vector3(0, 0.04, 0), 0.82, 0.08, DARK_WOOD, 12)
		"sacks":
			for k in 3:
				var s := _ball(root, Vector3((k - 1) * 0.5, 0.25, rng.randf_range(-0.2, 0.2)), 0.3, Color(0.6, 0.48, 0.32))
				s.scale = Vector3(1.0, 1.25, 0.9)
		"pillar":
			var h := rng.randf_range(1.2, 2.4)
			_cyl(root, Vector3(0, h / 2.0, 0), 0.32, h, STONE, 6)
			_box(root, Vector3(0, 0.08, 0), Vector3(0.9, 0.16, 0.9), STONE * 0.85)
			if h < 1.8:
				_box(root, Vector3(0.6, 0.12, 0.3), Vector3(0.5, 0.24, 0.4), STONE, 0.6)     # the broken top fallen beside it
		"crystals":
			for k in rng.randi_range(3, 5):
				var p := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
				var h := rng.randf_range(0.5, 1.2)
				_cone(root, p + Vector3(0, h / 2.0, 0), rng.randf_range(0.08, 0.14), h, CRYSTAL, true,
					Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)))
			var glow := OmniLight3D.new()
			glow.light_color = CRYSTAL
			glow.light_energy = 1.2
			glow.omni_range = 5.0
			glow.position = Vector3(0, 0.8, 0)
			root.add_child(glow)
		"urns":
			for k in rng.randi_range(2, 3):
				var p := Vector3((k - 1) * 0.55, 0, rng.randf_range(-0.2, 0.2))
				var u := _ball(root, p + Vector3(0, 0.3, 0), 0.3, CLAY)
				u.scale = Vector3(1.0, 1.2, 1.0)
				_cyl(root, p + Vector3(0, 0.66, 0), 0.12, 0.16, CLAY * 0.9, 6)
	return root


static func _mat(col: Color, glow := false) -> StandardMaterial3D:
	var key := "%s%s" % [col.to_html(), glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.9
		if glow:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = 1.6
		_mats[key] = m
	return _mats[key]


static func _add(root: Node3D, mesh: Mesh, at: Vector3, col: Color, glow := false, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col, glow)
	mi.position = at
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _box(root: Node3D, at: Vector3, size: Vector3, col: Color, turn := 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(root, m, at, col, false, Vector3(0, turn, 0))


static func _cyl(root: Node3D, at: Vector3, r: float, h: float, col: Color, sides: int, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return _add(root, m, at, col, false, rot)


static func _cone(root: Node3D, at: Vector3, r: float, h: float, col: Color, glow := false, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 6
	m.rings = 1
	return _add(root, m, at, col, glow, rot)


static func _ball(root: Node3D, at: Vector3, r: float, col: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 4
	return _add(root, m, at, col)
