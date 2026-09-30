extends Node3D
## An enemy on fire: flames on it, 1 damage every half second (through its take_burn), until `left`
## runs out or it dies. Added by FireFX.ignite().

var left := 2.0
var _tick := 0.5
var _flames: CPUParticles3D


func _ready() -> void:
	_flames = FireFX.flames(self, (get_parent() as Node3D).global_position + Vector3(0, 0.8, 0), 0.35, 14, 0.6)
	_flames.local_coords = true
	_flames.position = Vector3(0, 0.8, 0)


func _physics_process(delta: float) -> void:
	var enemy := get_parent()
	left -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		if enemy.is_alive() and enemy.has_method("take_burn"):
			enemy.take_burn(1)
	if left <= 0.0 or not enemy.is_alive():
		queue_free()
