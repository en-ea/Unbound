extends Node3D
## A campfire to cook at: flickering light, sparks and a soft crackle. One in each region's camp.

const MODEL := preload("res://assets/props/campfire.glb")
const STATION := preload("res://scripts/world/station.gd")

var _light: OmniLight3D
var _t := 0.0


func build(shape: WorldShape, at: Vector2) -> void:
	var spot := Node3D.new()
	spot.set_script(STATION)
	add_child(spot)
	spot.setup(Vector3(at.x, shape.height_at(at.x, at.y), at.y), "Cook", {"mode": "cook"}, MODEL, Vector3(1.4, 0.5, 1.4))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 6.0
	_light.light_energy = 1.4
	_light.position = Vector3(0, 0.8, 0)
	spot.add_child(_light)
	var sparks := CPUParticles3D.new()
	sparks.amount = 14
	sparks.lifetime = 1.4
	sparks.position = Vector3(0, 0.25, 0)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.2
	sparks.direction = Vector3.UP
	sparks.spread = 20.0
	sparks.gravity = Vector3(0, 0.8, 0)
	sparks.initial_velocity_min = 0.3
	sparks.initial_velocity_max = 0.8
	sparks.scale_amount_min = 0.03
	sparks.scale_amount_max = 0.06
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.7, 0.3)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	sparks.mesh = quad
	spot.add_child(sparks)


func _process(delta: float) -> void:
	_t += delta
	if _light:
		_light.light_energy = 1.3 + sin(_t * 9.0) * 0.12 + sin(_t * 23.0) * 0.08
