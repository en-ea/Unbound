extends Node3D
## Soft light beams and drifting motes over the standing stones on the hill.
## Brighter at dusk and night, so the place feels a little mysterious.

const BEAM_SHADER := preload("res://shaders/light_beam.gdshader")

@export var day_night: Node

var _beam_mats: Array[ShaderMaterial] = []


func place(shape: WorldShape) -> void:
	var c := WorldShape.HILL_CENTER
	position = Vector3(c.x, shape.height_at(c.x, c.y), c.y)
	for i in 3:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.7 + i * 0.35
		mesh.bottom_radius = 1.4 + i * 0.4
		mesh.height = 16.0
		mesh.cap_top = false
		mesh.cap_bottom = false
		mesh.radial_segments = 16
		mesh.rings = 1
		var mat := ShaderMaterial.new()
		mat.shader = BEAM_SHADER
		mesh.material = mat
		_beam_mats.append(mat)
		var beam := MeshInstance3D.new()
		beam.mesh = mesh
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position = Vector3((i - 1) * 0.6, 7.0, (i % 2) * 0.5)
		beam.rotation = Vector3(0.12 * (i - 1), 0.0, -0.18 + 0.1 * i)
		add_child(beam)
	add_child(_make_motes())


func _process(_delta: float) -> void:
	var night: float = day_night.night
	for i in _beam_mats.size():
		_beam_mats[i].set_shader_parameter("strength", lerpf(0.10, 0.22, night) / (1.0 + i * 0.6))


func _make_motes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.5
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.position = Vector3(0, 1.5, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.07
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(2.2, 2.0, 1.4)
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
