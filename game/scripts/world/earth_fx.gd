class_name EarthFX
## Earth for the Delver: thrown dirt, stone spikes bursting up, the mound that follows you underground,
## the churning pit of a Sinkhole, and cracking an enemy open (see Cracked). Cheap CPU particles and a
## few primitive meshes, no shadows.

const CRACKED := preload("res://scripts/creatures/cracked.gd")
const ORE := Color(0.36, 0.86, 0.72)          # the glow in the cracks (the Delver's colour)
const ROCK := Color(0.44, 0.39, 0.34)
const DIRT := Color(0.34, 0.24, 0.15)

static var _rock_mat: StandardMaterial3D
static var _dirt_mat: StandardMaterial3D
static var _ore_mat: StandardMaterial3D


static func rock_material() -> StandardMaterial3D:
	if _rock_mat == null:
		_rock_mat = StandardMaterial3D.new()
		_rock_mat.albedo_color = ROCK
		_rock_mat.roughness = 0.95
	return _rock_mat


static func dirt_material() -> StandardMaterial3D:
	if _dirt_mat == null:
		_dirt_mat = StandardMaterial3D.new()
		_dirt_mat.albedo_color = DIRT
		_dirt_mat.roughness = 1.0
	return _dirt_mat


static func ore_material() -> StandardMaterial3D:
	if _ore_mat == null:
		_ore_mat = StandardMaterial3D.new()
		_ore_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ore_mat.albedo_color = Color(ORE.r * 1.6, ORE.g * 1.6, ORE.b * 1.6)
	return _ore_mat


## Clods of earth thrown up from `at`. One burst, or a steady spray (`steady`) that follows its parent.
static func dirt(parent: Node, at: Vector3, radius: float, amount: int, force := 5.0, steady := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.8 if not steady else 0.5
	p.one_shot = not steady
	p.explosiveness = 0.95 if not steady else 0.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 55.0
	p.gravity = Vector3(0, -14.0, 0)
	p.initial_velocity_min = force * 0.5
	p.initial_velocity_max = force
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.13
	box.material = dirt_material()
	p.mesh = box
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	if not steady:
		parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	return p


## A stone spike bursting up out of the ground, standing a moment, then sinking back.
static func spike(parent: Node, at: Vector3, height: float, lean: Vector3 = Vector3.ZERO, stay := 0.9) -> void:
	var s := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = height * 0.28
	cone.height = height
	cone.radial_segments = 5
	cone.rings = 1
	s.mesh = cone
	s.material_override = rock_material()
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(s)
	var up := (Vector3.UP + lean * 0.35).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up)).rotated(up, randf() * TAU)
	var low := at - up * height * 0.6
	var high := at + up * height * 0.45
	s.global_transform = Transform3D(basis, low)
	var vein := MeshInstance3D.new()          # a glowing seam of ore up one face
	var strip := BoxMesh.new()
	strip.size = Vector3(0.05, height * 0.55, 0.05)
	vein.mesh = strip
	vein.material_override = ore_material()
	vein.position = Vector3(height * 0.12, -height * 0.18, 0)
	vein.rotation.z = 0.24
	s.add_child(vein)
	var t := s.create_tween()
	t.tween_property(s, "global_position", high, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_interval(stay)
	t.tween_property(s, "global_position", low, 0.45).set_ease(Tween.EASE_IN)
	t.tween_callback(s.queue_free)
	dirt(parent, at, 0.3, 8, 4.0)


## The mound of earth that moves over you while you burrow (move it each frame; it sprays dirt).
static func mound(parent: Node) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var hump := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.75
	dome.height = 0.7
	dome.radial_segments = 9
	dome.rings = 4
	hump.mesh = dome
	hump.material_override = dirt_material()
	hump.scale = Vector3(1.0, 0.6, 1.3)
	hump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hump)
	for i in 4:                                   # a few stones turning in the soil
		var stone := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * randf_range(0.14, 0.24)
		stone.mesh = b
		stone.material_override = rock_material() if i < 3 else ore_material()
		stone.position = Vector3(randf_range(-0.45, 0.45), 0.22, randf_range(-0.5, 0.5))
		stone.rotation = Vector3(randf(), randf(), randf()) * TAU
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(stone)
	var spray := dirt(root, Vector3.ZERO, 0.5, 18, 3.0, true)
	spray.position = Vector3(0, 0.15, 0)
	return root


## The Sinkhole: a dark churning pit `radius` wide with earth swirling into it. Fades in; call close().
static func pit(parent: Node, at: Vector3, radius: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at + Vector3(0, 0.06, 0)
	var hole := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	disc.radial_segments = 24
	hole.mesh = disc
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = Color(0.08, 0.05, 0.03)
	hole.material_override = hm
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hole)
	var glow := MeshInstance3D.new()              # ore light deep in the middle
	var inner := CylinderMesh.new()
	inner.top_radius = radius * 0.35
	inner.bottom_radius = radius * 0.35
	inner.height = 0.05
	inner.radial_segments = 16
	glow.mesh = inner
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_color = Color(ORE, 0.45)
	glow.material_override = gm
	glow.position.y = 0.02
	root.add_child(glow)
	var rim := 10
	for i in rim:                                 # broken earth round the edge
		var a := TAU * i / rim
		var lump := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(randf_range(0.5, 0.8), randf_range(0.25, 0.4), randf_range(0.4, 0.6))
		lump.mesh = b
		lump.material_override = dirt_material() if i % 3 else rock_material()
		lump.position = Vector3(cos(a), 0.05, sin(a)) * radius
		lump.rotation = Vector3(randf_range(-0.4, 0.4), -a, randf_range(-0.4, 0.4))
		lump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lump)
	var swirl := CPUParticles3D.new()             # earth spiralling in
	swirl.amount = 50
	swirl.lifetime = 1.2
	swirl.local_coords = true
	swirl.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	swirl.emission_ring_axis = Vector3.UP
	swirl.emission_ring_radius = radius
	swirl.emission_ring_inner_radius = radius * 0.7
	swirl.emission_ring_height = 0.1
	swirl.gravity = Vector3(0, -1.0, 0)
	swirl.radial_accel_min = -6.0
	swirl.radial_accel_max = -4.0
	swirl.tangential_accel_min = 7.0
	swirl.tangential_accel_max = 9.0
	swirl.direction = Vector3.UP
	swirl.initial_velocity_min = 0.3
	swirl.initial_velocity_max = 0.8
	var clod := BoxMesh.new()
	clod.size = Vector3.ONE * 0.16
	clod.material = dirt_material()
	swirl.mesh = clod
	swirl.angular_velocity_min = -200.0
	swirl.angular_velocity_max = 200.0
	swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(swirl)
	root.scale = Vector3(0.1, 1.0, 0.1)
	root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return root


## Shuts a pit: it shrinks to nothing and is gone.
static func close_pit(p: Node3D) -> void:
	var t := p.create_tween()
	t.tween_property(p, "scale", Vector3(0.05, 1.0, 0.05), 0.2).set_ease(Tween.EASE_IN)
	t.tween_callback(p.queue_free)


## Little glowing shards of ore drifting up off a cracked enemy (Cracked uses it).
static func shards(parent: Node3D) -> CPUParticles3D:
	var glow := CPUParticles3D.new()
	glow.amount = 10
	glow.lifetime = 0.7
	glow.local_coords = true
	glow.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	glow.emission_sphere_radius = 0.45
	glow.direction = Vector3.UP
	glow.spread = 30.0
	glow.gravity = Vector3(0, 1.0, 0)
	glow.initial_velocity_min = 0.2
	glow.initial_velocity_max = 0.6
	var shard := BoxMesh.new()
	shard.size = Vector3(0.05, 0.16, 0.05)
	shard.material = ore_material()
	glow.mesh = shard
	glow.angular_velocity_min = -90.0
	glow.angular_velocity_max = 90.0
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(0, 0.8, 0)
	parent.add_child(glow)
	return glow


## Cracks an enemy open for `seconds` (or keeps it cracked longer): glowing seams, and it takes more from you.
static func crack(enemy: Node, seconds: float) -> void:
	if not enemy.is_alive():
		return
	var c := enemy.get_node_or_null("Cracked")
	if c:
		c.left = maxf(c.left, seconds)
		return
	c = CRACKED.new()
	c.name = "Cracked"
	c.left = seconds
	enemy.add_child(c)


static func is_cracked(enemy: Node) -> bool:
	return enemy.get_node_or_null("Cracked") != null
