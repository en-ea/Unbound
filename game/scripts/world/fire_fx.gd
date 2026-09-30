class_name FireFX
## Fire for the Pyromancer: flame particles, burning ground that hurts enemies standing in it, a big
## blast (meteor), and setting an enemy alight (see Burning). All cheap CPU particles, no shadows.

const BURNING := preload("res://scripts/creatures/burning.gd")
const LOOP := preload("res://assets/sounds/fire_loop.wav")


## Flame particles: `radius` wide, `amount` flames, rising. Returns the emitter (already added).
static func flames(parent: Node, at: Vector3, radius: float, amount: int, life := 0.7, one_shot := false, size := 0.5) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 18.0 if not one_shot else 80.0
	p.gravity = Vector3(0, 2.5, 0)
	p.initial_velocity_min = 0.8 if not one_shot else 3.0
	p.initial_velocity_max = 2.0 if not one_shot else 8.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.45, 1.0))
	ramp.add_point(0.35, Color(1.0, 0.45, 0.1, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.4, 0.08, 0.02, 0.0))
	p.color_ramp = ramp
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(0.3, 1.0))
	grow.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = grow
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	if one_shot:
		p.finished.connect(p.queue_free)
	return p


## A patch of burning ground: flames and a crackle for `seconds`; enemies inside take `damage` every
## half second and catch fire.
static func burning_ground(parent: Node, at: Vector3, radius: float, seconds: float, damage: int) -> void:
	var patch := Node3D.new()
	parent.add_child(patch)
	patch.global_position = at
	var f := flames(patch, at + Vector3(0, 0.15, 0), radius * 0.8, int(10 + radius * 10), 0.8)
	var crackle := AudioStreamPlayer3D.new()
	var s: AudioStreamWAV = LOOP.duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	crackle.stream = s
	crackle.unit_size = 5.0
	crackle.volume_db = -6.0
	patch.add_child(crackle)
	crackle.play()
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 1.2
	light.omni_range = radius * 3.0
	light.position = Vector3(0, 0.8, 0)
	patch.add_child(light)
	var tree := parent.get_tree()
	var ticks := int(seconds / 0.5)
	for i in ticks:
		tree.create_timer(0.5 * (i + 1)).timeout.connect(func() -> void:
			if not is_instance_valid(patch):
				return
			for e in tree.get_nodes_in_group("enemy"):
				if e.is_alive() and (e as Node3D).global_position.distance_to(at) < radius:
					ignite(e, 2.0)
					if e.has_method("take_burn"):
						e.take_burn(damage))
	tree.create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(f):
			f.emitting = false
		var fade := patch.create_tween()
		fade.tween_property(light, "light_energy", 0.0, 0.8)
		fade.tween_callback(patch.queue_free))


## Sets an enemy burning for `seconds` (1 damage every half second, flames on it). Refreshes if already alight.
static func ignite(enemy: Node, seconds: float) -> void:
	var b := enemy.get_node_or_null("Burning")
	if b:
		b.left = maxf(b.left, seconds)
		return
	b = BURNING.new()
	b.name = "Burning"
	b.left = seconds
	enemy.add_child(b)


## A blast: a burst of flame and embers, a flash of light, a shockwave ring on the ground.
static func blast(parent: Node, at: Vector3, radius: float) -> void:
	flames(parent, at + Vector3(0, 0.3, 0), radius * 0.35, 60, 0.9, true, 0.9)
	flames(parent, at + Vector3(0, 0.2, 0), radius * 0.25, 30, 1.6, true, 0.25)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 6.0
	light.omni_range = radius * 4.0
	parent.add_child(light)
	light.global_position = at + Vector3(0, 1.5, 0)
	var t := light.create_tween()
	t.tween_property(light, "light_energy", 0.0, 0.6)
	t.tween_callback(light.queue_free)
	var ring := MeshInstance3D.new()
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE * radius * 2.4
	ring.mesh = disc
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/shockwave.gdshader")
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = at + Vector3(0, 0.15, 0)
	var rt := ring.create_tween()
	rt.tween_method(func(v: float) -> void: mat.set_shader_parameter("t", v), 0.0, 1.0, 0.5)
	rt.tween_callback(ring.queue_free)
