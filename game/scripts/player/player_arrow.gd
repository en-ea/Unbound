extends Node3D
## An arrow from your bow (player/fighter.gd's _shoot): flies fast at the enemy it was loosed at (or
## straight ahead), hits the first enemy it passes close to through take_hit, with the usual numbers.
## A power shot goes on through up to two more. Sticks in the ground when it misses.

const SPEED := 34.0
const LIFE := 1.4
const HIT_RADIUS := 0.75
const HIT_SOUND := preload("res://assets/sounds/arrow_hit.wav")

var _dir := Vector3.FORWARD
var _fighter: Node
var _mult := 1.0
var _pierce := 0
var _age := 0.0
var _hit := {}
var _stuck := -1.0


func fire(from: Vector3, dir: Vector3, fighter: Node, mult: float, pierce: int, glow: Color) -> void:
	global_position = from
	_dir = dir.normalized()
	_fighter = fighter
	_mult = mult
	_pierce = pierce
	var mi := MeshInstance3D.new()
	mi.mesh = Items.mesh("arrow")
	mi.scale = Vector3.ONE * 1.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	look_at(global_position + _dir, Vector3.UP if absf(_dir.y) < 0.95 else Vector3.RIGHT)
	mi.rotation_degrees = Vector3(-90, 0, 0)          # the model points along +Z; look_at faces -Z
	var trail := MeshInstance3D.new()                 # a thin glowing streak behind it
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.03, 0.9)
	trail.mesh = box
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(glow, 0.55)
	trail.material_override = m
	trail.position = Vector3(0, 0, 0.55)
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)


func _physics_process(delta: float) -> void:
	if _stuck >= 0.0:
		_stuck += delta
		if _stuck > 3.0:
			queue_free()
		return
	_age += delta
	global_position += _dir * SPEED * delta
	for e in get_tree().get_nodes_in_group("enemy"):
		if _hit.has(e) or not e.is_alive():
			continue
		var c: Vector3 = (e as Node3D).global_position + Vector3(0, 0.7, 0)
		if c.distance_to(global_position) < HIT_RADIUS + (0.5 if e.is_in_group("elite") else 0.0):
			_hit[e] = true
			_fighter.arrow_hit(e, _mult)
			var snd := AudioStreamPlayer3D.new()
			snd.stream = HIT_SOUND
			get_parent().add_child(snd)
			snd.global_position = global_position
			snd.play()
			snd.finished.connect(snd.queue_free)
			if _pierce <= 0:
				queue_free()
				return
			_pierce -= 1
	var ground: float = Carcass.shape.height_at(global_position.x, global_position.z) if Carcass.shape else -INF
	if _age > LIFE or global_position.y < ground + 0.05:
		_stuck = 0.0
