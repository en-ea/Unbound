class_name WaterFX
## Water for the Tidecaller (studio: water class). Presentation only: reads nothing, writes no fact.
## Each effect is one mesh or one CPU particle emitter, unshaded, no shadows, no lights; materials are shared
## (made once), so a cast costs a few draw calls and no shader compile mid-fight.

const TEAL := Color(0.14, 0.56, 0.84)
const FOAM := Color(0.82, 0.96, 1.0)

const SPHERE_SHADER := preload("res://scripts/studio/water/water_sphere.gdshader")

static var _mats := {}
static var _soft: GradientTexture2D


## A shared unshaded material: `key` names it, `add` for glowing (additive), else alpha.
static func mat(key: String, color: Color, add := false, billboard := false) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = soft()
	_mats[key] = m
	return m


## A round soft dot (particles are drops, not squares). Made once.
static func soft() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.55, Color(1, 1, 1, 0.85))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 32
		_soft.height = 32
	return _soft


## Droplets thrown out from a point (a splash, the slam's spray). One one-shot emitter.
static func splash(parent: Node, at: Vector3, radius: float, amount := 40) -> CPUParticles3D:
	var p := _particles(parent, "drop", Color(0.75, 0.93, 1.0, 0.9), 0.16, amount, 0.8, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.25
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, -14.0, 0)
	p.initial_velocity_min = radius * 1.2
	p.initial_velocity_max = radius * 2.4
	p.global_position = at + Vector3(0, 0.3, 0)
	p.emitting = true
	return p


static func _particles(parent: Node, key: String, color: Color, size: float, amount: int, life: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = mat("p_" + key, Color.WHITE, false, true)
	p.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	if one_shot:
		p.finished.connect(p.queue_free)
	return p


## The class card's emblem: a drop over a rolling wave (class_panel.gd).
static func emblem(c: Control, center: Vector2, tint: Color, time: float) -> void:
	var bob := sin(time * 2.4) * 2.0
	var drop := PackedVector2Array()
	for k in 17:                                 # a teardrop: a point on top, round below
		var a := PI * 0.5 + TAU * k / 16.0
		var r := 15.0
		var p := Vector2(cos(a) * r, sin(a) * r) if sin(a) > -0.2 else Vector2(cos(a) * r * (1.0 + sin(a)) * 0.9, sin(a) * r * 1.9)
		drop.append(center + Vector2(0, -6 + bob) + p)
	c.draw_colored_polygon(drop, Color(tint.lightened(0.25), 0.95))
	c.draw_circle(center + Vector2(-5, -2 + bob), 3.5, Color(FOAM, 0.8))
	var wave := PackedVector2Array()
	for j in 25:
		var x := -32.0 + j * (64.0 / 24.0)
		wave.append(center + Vector2(x, 22 + sin(x * 0.18 + time * 3.0) * 3.5))
	c.draw_polyline(wave, Color(FOAM, 0.9), 3.0, true)
	c.draw_polyline(wave, Color(tint, 0.9), 1.5, true)


## Drown's sphere of water round a foe: one alpha sphere (it follows the foe) with bubbles rising inside.
static func sphere(foe: Node3D, offset: Vector3, radius: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	if not _mats.has("sphere"):
		var sm := ShaderMaterial.new()
		sm.shader = SPHERE_SHADER
		_mats["sphere"] = sm
	mesh.material = _mats["sphere"]
	m.mesh = mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = offset
	m.scale = Vector3.ONE * 0.2
	foe.add_child(m)
	m.create_tween().tween_property(m, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var b := _particles(m, "bubble", Color(0.9, 0.98, 1.0, 0.85), 0.12, 14, 1.0, false)
	b.local_coords = true
	b.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	b.emission_sphere_radius = radius * 0.6
	b.direction = Vector3.UP
	b.spread = 15.0
	b.gravity = Vector3(0, 1.5, 0)
	b.initial_velocity_min = 0.2
	b.initial_velocity_max = 0.6
	b.emitting = true
	m.set_meta("bubbles", b)
	return m


## A gulp of air escaping (each trickle of harm): the sphere wobbles.
static func bubble_burst(sphere: MeshInstance3D) -> void:
	if not is_instance_valid(sphere):
		return
	var t := sphere.create_tween()
	t.tween_property(sphere, "scale", Vector3(1.08, 0.92, 1.08), 0.08)
	t.tween_property(sphere, "scale", Vector3.ONE, 0.18)


## The sphere lets go: it bursts into spray and is gone.
static func burst_sphere(sphere: MeshInstance3D) -> void:
	if not is_instance_valid(sphere):
		return
	splash(sphere.get_tree().current_scene, sphere.global_position, 2.0, 36)
	sphere.queue_free()


## A ring of water spreading over the ground (a slam, a puddle's splash). One flat mesh, 0.6 s.
static func ripple(parent: Node, at: Vector3, radius: float) -> void:
	var m := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	torus.material = mat("ripple", Color(0.8, 0.95, 1.0, 0.6))
	m.mesh = torus
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = at + Vector3(0, 0.08, 0)
	m.scale = Vector3(0.3, 0.05, 0.3)
	var t := m.create_tween()
	t.tween_property(m, "scale", Vector3(radius, 0.05, radius), 0.6).set_ease(Tween.EASE_OUT)
	t.tween_callback(m.queue_free)


## Tempest's cloud: a ring of dark puffs over `at` (one MultiMesh) with rain falling from it (one emitter).
## Move the returned node to move the storm; end_cloud() lets it drain away.
static func cloud(parent: Node, at: Vector3, radius: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 1.3
	puff.radial_segments = 8
	puff.rings = 4
	puff.material = mat("cloud", Color(0.2, 0.23, 0.3, 0.88))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = puff
	var count := 12
	mm.instance_count = count
	for i in count:
		var a := TAU * i / count + randf() * 0.3
		var r := radius * randf_range(0.35, 0.85)
		var s := randf_range(1.3, 2.1)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s * 0.6, s)), Vector3(cos(a) * r, 4.8 + randf() * 0.5, sin(a) * r)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	mmi.scale = Vector3(0.2, 1.0, 0.2)
	mmi.create_tween().tween_property(mmi, "scale", Vector3.ONE, 0.6).set_ease(Tween.EASE_OUT)
	var rain := CPUParticles3D.new()
	rain.amount = 180
	rain.lifetime = 0.55
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(radius * 0.8, 0.2, radius * 0.8)
	rain.direction = Vector3.DOWN
	rain.spread = 2.0
	rain.gravity = Vector3(0, -20.0, 0)
	rain.initial_velocity_min = 9.0
	rain.initial_velocity_max = 11.0
	var streak := QuadMesh.new()
	streak.size = Vector2(0.025, 0.45)
	if not _mats.has("rain"):
		var m := mat("rain_base", Color(0.78, 0.9, 1.0, 0.4)).duplicate() as StandardMaterial3D
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		_mats["rain"] = m
	streak.material = _mats["rain"]
	rain.mesh = streak
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rain)
	rain.position = Vector3(0, 4.5, 0)
	rain.emitting = true
	var shade := MeshInstance3D.new()           # the storm's shadow on the ground: where it reaches
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 32
	disc.rings = 1
	disc.material = mat("storm_shade", Color(0.05, 0.08, 0.14, 0.28))
	shade.mesh = disc
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shade)
	shade.position = Vector3(0, 0.12, 0)
	root.set_meta("rain", rain)
	root.set_meta("puffs", mmi)
	root.set_meta("shade", shade)
	return root


static func end_cloud(root: Node3D) -> void:
	if not is_instance_valid(root) or root.has_meta("ending"):
		return
	root.set_meta("ending", true)
	(root.get_meta("rain") as CPUParticles3D).emitting = false
	var mmi: Node3D = root.get_meta("puffs")
	var t := root.create_tween()
	t.set_parallel()
	t.tween_property(mmi, "scale", Vector3(0.1, 1.0, 0.1), 0.7).set_ease(Tween.EASE_IN)
	t.tween_property(root.get_meta("shade"), "scale", Vector3(0.05, 1.0, 0.05), 0.7)
	t.set_parallel(false)
	t.tween_callback(root.queue_free)


## A lightning bolt from `from` to `to`: one jagged ribbon, bright, gone in a fifth of a second, a splash of light
## where it lands. Faced to the camera so it never shows edge-on.
static func bolt(parent: Node, from: Vector3, to: Vector3) -> void:
	var cam := parent.get_viewport().get_camera_3d()
	var view := (cam.global_position - to).normalized() if cam else Vector3.BACK
	var points: Array[Vector3] = []
	var steps := 9
	for i in steps + 1:
		var f := float(i) / steps
		var p := from.lerp(to, f)
		if i > 0 and i < steps:
			p += Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * 0.55
		points.append(p)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat("bolt", Color(0.85, 0.92, 1.0, 1.0), true))
	for i in points.size():
		var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := along.cross(view).normalized() * (0.16 if i < points.size() - 1 else 0.05)
		im.surface_add_vertex(points[i] - side)
		im.surface_add_vertex(points[i] + side)
	im.surface_end()
	var m := MeshInstance3D.new()
	m.mesh = im
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	var t := m.create_tween()
	t.tween_interval(0.18)
	t.tween_callback(m.queue_free)
	var spark := _particles(parent, "spark", Color(0.9, 0.95, 1.0, 1.0), 0.18, 20, 0.35, true)
	spark.direction = Vector3.UP
	spark.spread = 90.0
	spark.initial_velocity_min = 3.0
	spark.initial_velocity_max = 7.0
	spark.gravity = Vector3(0, -9.0, 0)
	spark.global_position = to
	spark.emitting = true


## Rime Wave: frost spreading over the ground in a fan (`angle_deg` wide, 360 for a ring) and a cold mist with it.
static func frost(parent: Node, at: Vector3, forward: Vector3, reach: float, angle_deg: float) -> void:
	var fan := MeshInstance3D.new()
	fan.mesh = _fan(angle_deg)
	fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fan)
	fan.global_position = at + Vector3(0, 0.1, 0)
	fan.rotation.y = atan2(forward.x, forward.z)
	fan.scale = Vector3(0.3, 1.0, 0.3)
	var t := fan.create_tween()
	t.tween_property(fan, "scale", Vector3(reach, 1.0, reach), reach / 18.0).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.35)
	t.tween_property(fan, "scale", Vector3(reach, 0.01, reach), 0.25)
	t.tween_callback(fan.queue_free)
	var mist := _particles(parent, "frost", Color(0.85, 0.97, 1.0, 0.8), 0.5, 48, 0.7, true)
	mist.direction = forward + Vector3(0, 0.15, 0)
	mist.spread = angle_deg * 0.5 if angle_deg < 360.0 else 180.0
	mist.flatness = 0.85
	mist.gravity = Vector3.ZERO
	mist.initial_velocity_min = reach * 1.2
	mist.initial_velocity_max = reach * 1.9
	mist.damping_min = reach * 1.5
	mist.damping_max = reach * 2.0
	mist.global_position = at + Vector3(0, 0.4, 0)
	mist.emitting = true


static var _fans := {}

## A flat fan of unit radius, `angle_deg` wide, centred on +Z (one per width, made once).
static func _fan(angle_deg: float) -> ArrayMesh:
	var key := roundi(angle_deg)
	if _fans.has(key):
		return _fans[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 24 if angle_deg >= 360.0 else 12
	var half := deg_to_rad(angle_deg) * 0.5
	for i in steps:
		var a0 := -half + deg_to_rad(angle_deg) * i / steps
		var a1 := -half + deg_to_rad(angle_deg) * (i + 1) / steps
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a1), 0, cos(a1)))
		st.add_vertex(Vector3(sin(a0), 0, cos(a0)))
	var mesh := st.commit()
	mesh.surface_set_material(0, mat("frost_fan", Color(0.82, 0.95, 1.0, 0.45)))
	_fans[key] = mesh
	return mesh


## A shell of ice round a frozen foe: a six-sided crystal, clear in the middle, bright at the edges.
static func ice(foe: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var prism := CylinderMesh.new()
	prism.top_radius = 0.62
	prism.bottom_radius = 0.8
	prism.height = 2.1
	prism.radial_segments = 6
	prism.rings = 1
	if not _mats.has("ice"):
		var sm := ShaderMaterial.new()
		sm.shader = SPHERE_SHADER
		sm.set_shader_parameter("tint", Color(0.7, 0.92, 1.0))
		sm.set_shader_parameter("wobble", 0.0)
		sm.set_shader_parameter("core", 0.42)       # (opaque enough to read as ice at a glance, villager or bandit)
		_mats["ice"] = sm
	prism.material = _mats["ice"]
	m.mesh = prism
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foe.add_child(m)
	m.position = Vector3(0, 1.0, 0)
	m.rotation = Vector3(randf_range(-0.08, 0.08), randf() * TAU, randf_range(-0.08, 0.08))
	m.scale = Vector3(1.0, 0.1, 1.0)
	m.create_tween().tween_property(m, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT)
	return m


## The ice cracks: shards fly.
static func shatter(parent: Node, at: Vector3) -> void:
	var p := _particles(parent, "shard", Color(0.85, 0.97, 1.0, 1.0), 0.22, 30, 0.7, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3.UP
	p.spread = 80.0
	p.gravity = Vector3(0, -14.0, 0)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.global_position = at
	p.emitting = true


## The Tidebound roll's puddle: a flat pool that fades after `seconds`.
static func puddle(parent: Node, at: Vector3, radius: float, seconds: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 20
	disc.rings = 1
	disc.material = mat("puddle", Color(0.3, 0.6, 0.85, 0.5))
	m.mesh = disc
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = at + Vector3(0, 0.06, 0)
	m.scale = Vector3(0.2, 1.0, 0.2)
	var t := m.create_tween()
	t.tween_property(m, "scale", Vector3(radius, 1.0, radius), 0.25).set_ease(Tween.EASE_OUT)
	t.tween_interval(maxf(0.0, seconds - 0.85))
	t.tween_property(m, "scale", Vector3(0.05, 1.0, 0.05), 0.6).set_ease(Tween.EASE_IN)
	t.tween_callback(m.queue_free)
	return m


## Loading-screen warm-up (his world/ability_warmup.gd): every water effect once, so the phone prepares its shaders
## behind the loading cover. Returns the nodes to free afterwards (the rest free themselves).
static func warm(parent: Node3D, at: Vector3) -> Array[Node]:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = at
	sphere(holder, Vector3(0, 1.0, 0), 0.4)
	ice(holder)
	var storm := cloud(parent, at, 1.5)
	splash(parent, at, 0.5, 6)
	ripple(parent, at, 1.0)
	frost(parent, at, Vector3.FORWARD, 1.5, 70.0)
	frost(parent, at, Vector3.FORWARD, 1.5, 360.0)
	shatter(parent, at)
	puddle(parent, at, 0.6, 1.0)
	bolt(parent, at + Vector3(0, 3, 0), at)
	return [holder, storm]
