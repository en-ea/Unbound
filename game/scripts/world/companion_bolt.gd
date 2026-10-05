extends Node3D
## A companion's fire bolt (world/companion.gd): a glowing ember that curves onto its enemy, with a trail of
## sparks; on a hit it burns (take_burn, or take_hit for those without), and may set it alight.

const SPEED := 13.0

var _target: Node3D
var _damage := 1
var _ignite := false
var _done: Callable
var _dir := Vector3.FORWARD
var _age := 0.0


func fire(from: Vector3, target: Node3D, damage: int, ignite: bool, done: Callable) -> void:
	global_position = from
	_target = target
	_damage = damage
	_ignite = ignite
	_done = done
	_dir = (target.global_position + Vector3(0, 0.8, 0) - from).normalized()
	_dir = (_dir + Vector3(randf_range(-0.4, 0.4), 0.5, randf_range(-0.4, 0.4))).normalized()   # a little arc
	var ball := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.75, 0.35)
	s.material = m
	ball.mesh = s
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ball)
	FireFX.flames(self, Vector3.ZERO, 0.08, 10, 0.3, false, 0.25)


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(_target) or not _target.is_alive() or _age > 2.5:
		queue_free()
		return
	var to := _target.global_position + Vector3(0, 0.8, 0) - global_position
	_dir = _dir.slerp(to.normalized(), clampf(delta * 6.0, 0.0, 1.0)).normalized()
	global_position += _dir * SPEED * delta
	if to.length() < 0.6:
		if _target.has_method("take_burn"):
			_target.take_burn(_damage)
		else:
			_target.take_hit(global_position, _damage, 0.3)
		if _ignite and _target.is_alive():
			FireFX.ignite(_target, 2.5)
		FireFX.flames(get_parent(), global_position, 0.3, 12, 0.4, true, 0.35)
		if _done.is_valid():
			_done.call(not _target.is_alive())
		queue_free()
