extends Node3D
## An enemy cracked open by the Delver: glowing seams of ore light on it until `left` runs out or it dies.
## Cracked enemies take more from you and the earth swallows them sooner (player/delver.gd). Added by
## EarthFX.crack().

var left := 6.0
var _glow: CPUParticles3D


func _ready() -> void:
	_glow = EarthFX.shards(self)


func _physics_process(delta: float) -> void:
	left -= delta
	if left <= 0.0 or not get_parent().is_alive():
		queue_free()
