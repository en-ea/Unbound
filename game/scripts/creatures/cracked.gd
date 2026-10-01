extends Node3D
## An enemy cracked open by the Delver: glowing seams of ore light on it until `left` runs out or it dies.
## Cracked enemies take more from you and the earth swallows them sooner (player/delver.gd). Added by
## EarthFX.crack().

var left := 6.0
var _glow: CPUParticles3D


func _ready() -> void:
	_glow = CPUParticles3D.new()
	_glow.amount = 10
	_glow.lifetime = 0.7
	_glow.local_coords = true
	_glow.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_glow.emission_sphere_radius = 0.45
	_glow.direction = Vector3.UP
	_glow.spread = 30.0
	_glow.gravity = Vector3(0, 1.0, 0)
	_glow.initial_velocity_min = 0.2
	_glow.initial_velocity_max = 0.6
	var shard := BoxMesh.new()
	shard.size = Vector3(0.05, 0.16, 0.05)
	shard.material = EarthFX.ore_material()
	_glow.mesh = shard
	_glow.angular_velocity_min = -90.0
	_glow.angular_velocity_max = 90.0
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.position = Vector3(0, 0.8, 0)
	add_child(_glow)


func _physics_process(delta: float) -> void:
	left -= delta
	if left <= 0.0 or not get_parent().is_alive():
		queue_free()
