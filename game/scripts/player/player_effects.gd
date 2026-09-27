extends Node3D
## Small feedback effects on the player: dust puffs when running, ripples when wading.

const RIPPLE_SHADER := preload("res://shaders/ripple.gdshader")
const RUN_DUST_SPEED := 3.0

@onready var player: CharacterBody3D = get_parent()

var _dust: CPUParticles3D
var _ripples: CPUParticles3D


func _ready() -> void:
	_dust = _make_dust()
	add_child(_dust)
	_ripples = _make_ripples()
	add_child(_ripples)


func _process(_delta: float) -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var feet := player.global_position.y
	var in_water := feet < WorldShape.WATER_Y - 0.05
	_dust.emitting = speed > RUN_DUST_SPEED and player.is_on_floor() and not in_water
	_ripples.emitting = in_water
	_ripples.global_position = Vector3(player.global_position.x, WorldShape.WATER_Y + 0.02, player.global_position.z)


func _make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.7
	p.local_coords = false
	p.emitting = false
	p.position = Vector3(0, 0.1, 0)
	p.direction = Vector3.UP
	p.spread = 60.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.4))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.45))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.35
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.82, 0.74, 0.62)
	mat.albedo_texture = _soft_dot()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _make_ripples() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 5
	p.lifetime = 1.4
	p.local_coords = false
	p.emitting = false
	p.gravity = Vector3.ZERO
	p.initial_velocity_max = 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.3))
	grow.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = grow
	p.scale_amount_min = 1.6
	p.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = RIPPLE_SHADER
	plane.material = mat
	p.mesh = plane
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## A small round, soft-edged white texture for the dust puffs.
func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex
