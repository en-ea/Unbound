extends Node3D
## An arrow from a bandit archer: flies straight and fast at where you were heading. It reaches you
## through player.receive_attack (roll through it, or parry it and it snaps), otherwise it sticks in the
## ground and fades.

const SPEED := 20.0
const LIFE := 2.2
const HIT_SOUND := preload("res://assets/sounds/arrow_hit.wav")

var _dir := Vector3.FORWARD
var _shooter: Node3D
var _player: Node3D
var _damage := 1
var _age := 0.0
var _done := false
var _stuck := 0.0


func fire(from: Vector3, target: Vector3, shooter: Node3D, player: Node3D, damage: int) -> void:
	global_position = from
	_dir = (target - from).normalized()
	_shooter = shooter
	_player = player
	_damage = damage
	var mi := MeshInstance3D.new()
	mi.mesh = Items.mesh("arrow")
	mi.scale = Vector3.ONE * 1.4
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	look_at(global_position + _dir, Vector3.UP if absf(_dir.y) < 0.95 else Vector3.RIGHT)
	mi.rotation_degrees = Vector3(-90, 0, 0)          # the model points along +Z; look_at faces -Z


func _physics_process(delta: float) -> void:
	_age += delta
	if _done:
		_stuck += delta
		if _stuck > 3.0:
			queue_free()
		return
	var step := _dir * SPEED * delta
	global_position += step
	var to_player := _player.global_position + Vector3(0, 1.0, 0) - global_position
	if to_player.length() < 0.7 and is_instance_valid(_shooter):
		var result: String = _player.receive_attack(_shooter, _damage, _dir * 3.0)
		if result == "dodge" or result == "perfect" or result == "miss":
			return                                   # flies on past
		var snd := AudioStreamPlayer3D.new()
		snd.stream = HIT_SOUND
		get_parent().add_child(snd)
		snd.global_position = global_position
		snd.play()
		snd.finished.connect(snd.queue_free)
		queue_free()
		return
	if _age > LIFE or global_position.y < _player.global_position.y - 0.4:      # into the ground
		_done = true
