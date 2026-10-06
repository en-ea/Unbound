extends RefCounted
## Where the dungeons are: one line each (a region, a spot, a theme, a template, a seed, the coins for
## clearing it). Their entrances are built here when a region loads (build_entrances, from main.gd); going in
## is dungeon.gd. Each spot's ground is flattened in WorldShape.REGIONS (clearings): keep them in step.

const SITES := {
	"cannibal_den": {"name": "Cannibal Den", "region": "forest", "at": Vector2(58, -72), "theme": "den",
		"template": "rescue", "seed": 4401, "reward": 80},
	"old_barrow": {"name": "Old Barrow", "region": "meadow", "at": Vector2(62, -48), "theme": "barrow",
		"template": "hoard", "seed": 9127, "reward": 60},
}
const DARK := Color(0.03, 0.03, 0.04)
const STONE := Color(0.6, 0.6, 0.56)
const WOOD := Color(0.36, 0.24, 0.15)
const BONE := Color(0.88, 0.84, 0.72)


## The entrances in this region: a dark way down, dressed by the theme, its name over it, Enter by it.
static func build_entrances(parent: Node3D, shape: WorldShape) -> void:
	for id: String in SITES:
		var site: Dictionary = SITES[id]
		if site.region != Region.current:
			continue
		var at: Vector2 = site.at
		var r := Node3D.new()
		parent.add_child(r)
		r.global_position = Vector3(at.x, shape.height_at(at.x, at.y), at.y)
		r.add_to_group("map_building")
		r.set_meta("map_size", Vector2(5, 5))
		_box(r, Vector3(0, 0.0, 0), Vector3(3.6, 0.3, 3.0), Color(0.2, 0.17, 0.15))          # the ground falls away
		_box(r, Vector3(0, 1.2, -0.9), Vector3(2.4, 2.6, 0.4), DARK)                         # the dark way down
		_ramp(r)
		if site.theme == "den":
			for side in [-1.0, 1.0]:
				_cyl(r, Vector3(side * 1.7, 1.1, -0.4), 0.09, 2.4, WOOD)
				_ball(r, Vector3(side * 1.7, 2.4, -0.4), 0.18, BONE)
			_box(r, Vector3(0, 2.55, -0.4), Vector3(3.6, 0.14, 0.14), WOOD)
			for k in 3:
				_ball(r, Vector3((k - 1) * 0.7, 2.35, -0.4), 0.12, BONE)              # skulls hung on the lintel
		else:
			for side in [-1.0, 1.0]:
				_cyl(r, Vector3(side * 1.6, 1.3, -0.6), 0.32, 2.8, STONE)
			_box(r, Vector3(0, 2.85, -0.6), Vector3(4.0, 0.5, 0.8), STONE)
		var torch := OmniLight3D.new()
		torch.light_color = Color(1.0, 0.65, 0.35)
		torch.light_energy = 1.6
		torch.omni_range = 6.0
		torch.position = Vector3(1.9, 2.0, 0.6)
		r.add_child(torch)
		_cyl(r, Vector3(1.9, 1.0, 0.6), 0.06, 2.0, WOOD)
		var label := Label3D.new()
		label.text = site.name
		label.font_size = 52
		label.outline_size = 14
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 4.4, 0)
		label.visibility_range_end = 28.0
		label.visibility_range_end_margin = 4.0
		label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		r.add_child(label)
		var body := StaticBody3D.new()                                                    # the rock round the way in
		for side in [-1.0, 1.0]:
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.0, 3.0, 2.0)
			col.shape = box
			col.position = Vector3(side * 1.75, 1.5, -0.6)
			body.add_child(col)
		r.add_child(body)
		var door := Node3D.new()
		door.set_script(preload("res://scripts/world/use_spot.gd"))
		r.add_child(door)
		var out := r.global_position + Vector3(0, 0.3, 2.2)
		door.setup(r.global_position + Vector3(0, 0.5, 0.4), "Enter", func() -> void:
			r.get_tree().call_group("dungeon", "enter", id, out), 2.4)


static func _ramp(r: Node3D) -> void:
	for k in 4:                                                                           # steps going down into the dark
		_box(r, Vector3(0, 0.14 - k * 0.04, 0.5 - k * 0.35), Vector3(2.0, 0.08, 0.3), Color(0.32, 0.3, 0.28) * (1.0 - k * 0.18))


static func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	return m


static func _box(r: Node3D, at: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = _mat(col)
	mi.position = at
	r.add_child(mi)


static func _cyl(r: Node3D, at: Vector3, radius: float, h: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = h
	m.radial_segments = 6
	mi.mesh = m
	mi.material_override = _mat(col)
	mi.position = at
	r.add_child(mi)


static func _ball(r: Node3D, at: Vector3, radius: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	mi.mesh = m
	mi.material_override = _mat(col)
	mi.position = at
	r.add_child(mi)
