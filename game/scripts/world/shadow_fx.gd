class_name ShadowFX
extends RefCounted
## The Shade's effects: dark smoke shot through with a faint violet glow.

const VIOLET := Color(0.62, 0.42, 1.0)


## A puff of shadow (stepping out of one place and into another).
static func puff(parent: Node, at: Vector3, size := 1.0) -> void:
	_smoke(parent, at, 0.5 * size, int(26 * size), 0.7, 1.6 * size)
	_sparks(parent, at, 0.4 * size, int(10 * size))


## A burst of shadow: a ring of smoke rushing out to `radius`.
static func burst(parent: Node, at: Vector3, radius: float) -> void:
	var p := _smoke(parent, at + Vector3(0, 0.3, 0), 0.4, int(40 + radius * 10.0), 0.6, radius * 2.6)
	p.direction = Vector3(1, 0, 0)
	p.spread = 180.0
	p.flatness = 0.85
	_sparks(parent, at + Vector3(0, 0.5, 0), radius * 0.6, 24)


## A streak of violet-edged shadow from one place to another (Shadow Dance), fading fast.
static func streak(parent: Node, from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.2:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.09, 0.09, length)
	mi.mesh = box
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(VIOLET.lightened(0.35), 0.9)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.RIGHT)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.tween_property(mi, "scale", Vector3(0.2, 0.2, 1.0), 0.3)
	tw.chain().tween_callback(mi.queue_free)
	var p := _smoke(parent, (from + to) * 0.5, 0.15, int(6 + length * 3.0), 0.5, 0.6)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.1, 0.1, length * 0.5)
	p.rotation = mi.rotation


## Smoke streaming off you for `time` (the Shade's roll).
static func trail(on: Node3D, offset: Vector3, time: float) -> void:
	var p := _smoke(on, on.global_position + offset, 0.3, 24, 0.5, 0.5)
	p.one_shot = false
	p.explosiveness = 0.0
	p.local_coords = false
	p.position = offset
	on.get_tree().create_timer(time).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false)


## Wisps of shadow rising off a double, always on while it's out.
static func wisps(on: Node3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.1
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.25, 0.7, 0.25)
	p.position = Vector3(0, 0.9, 0)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0, 0.5, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.35, 0.2, 0.6, 0.85))
	ramp.set_color(1, Color(0.03, 0.01, 0.06, 0.0))
	p.color_ramp = ramp
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	on.add_child(p)
	return p


static func _smoke(parent: Node, at: Vector3, radius: float, amount: int, life: float, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = maxi(amount, 4)
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.25, 0.14, 0.4, 0.9))
	ramp.set_color(1, Color(0.02, 0.01, 0.04, 0.0))
	p.color_ramp = ramp
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	_add(parent, p, at)
	return p


static func _sparks(parent: Node, at: Vector3, radius: float, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = maxi(amount, 4)
	p.lifetime = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, 0.8, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	mesh.radial_segments = 4
	mesh.rings = 2
	p.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = VIOLET.lightened(0.2)
	p.material_override = m
	_add(parent, p, at)


static func _add(parent: Node, p: CPUParticles3D, at: Vector3) -> void:
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)
