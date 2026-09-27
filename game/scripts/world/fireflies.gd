extends CPUParticles3D
## A few glowing fireflies drifting around the player at night.

@export var day_night: Node
@export var follow: Node3D


func _ready() -> void:
	amount = 40
	lifetime = 6.0
	preprocess = 6.0
	local_coords = false
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = Vector3(16.0, 1.2, 12.0)
	direction = Vector3.UP
	spread = 180.0
	gravity = Vector3.ZERO
	initial_velocity_min = 0.1
	initial_velocity_max = 0.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.09
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(3.0, 2.6, 1.0)
	quad.material = mat
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	emitting = day_night.night > 0.3
	if follow:
		global_position = follow.global_position + Vector3(0, 1.0, 0)
