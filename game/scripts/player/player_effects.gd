extends Node3D
## Small feedback effects on the player: a little puff at each footfall (grass bits on grass, dust
## on the path; bigger when running), a burst when you roll and land, and ripples when wading.

const RIPPLE_SHADER := preload("res://shaders/ripple.gdshader")
const RUN_DUST_SPEED := 3.0

@onready var player: CharacterBody3D = get_parent()

const GRASS_BITS := Color(0.62, 0.74, 0.4)
const DUST := Color(0.8, 0.72, 0.58)
const POOL := 6

var _dust: CPUParticles3D
var _ripples: CPUParticles3D
var _puffs: Array[CPUParticles3D] = []
var _next := 0


func _ready() -> void:
	_dust = _make_dust()
	add_child(_dust)
	_ripples = _make_ripples()
	add_child(_ripples)
	for i in POOL:                           # one-shot puffs, used in turn
		var p := _make_dust()
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = 5
		p.lifetime = 0.55
		_puffs.append(p)
		add_child(p)


## A footfall: a small puff behind the stepping foot.
func kick(surface: String, running: bool, left: bool) -> void:
	var p := _take()
	var back := -Vector3(player.velocity.x, 0, player.velocity.z).normalized()
	var side := back.cross(Vector3.UP) * (0.12 if left else -0.12)
	p.global_position = player.global_position + back * 0.25 + side + Vector3(0, 0.08, 0)
	var sprint: bool = player.sprinting
	p.amount = 11 if sprint else (6 if running else 3)
	p.color = GRASS_BITS if surface == "grass" else DUST
	p.initial_velocity_max = 2.0 if sprint else (1.2 if running else 0.6)
	p.direction = back + Vector3(0, 1.2, 0)
	p.restart()


## Rolling: a spray of dust and grass as you go down, and a puff where you land.
func burst(start: bool) -> void:
	for i in 2:
		var p := _take()
		p.global_position = player.global_position + Vector3(0, 0.1, 0)
		p.amount = 8
		p.color = GRASS_BITS if i == 0 else DUST
		p.initial_velocity_max = 1.8 if start else 1.2
		p.direction = Vector3.UP
		p.restart()


func _take() -> CPUParticles3D:
	var p := _puffs[_next]
	_next = (_next + 1) % POOL
	return p


func _process(_delta: float) -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var feet := player.global_position.y
	var in_water := feet < WorldShape.WATER_Y - 0.05
	_dust.emitting = false         # footfall puffs (kick) replace the old running trail
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
	ramp.set_color(0, Color(1, 1, 1, 0.7))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.35
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
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
