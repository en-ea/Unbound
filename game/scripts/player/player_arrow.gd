extends Node3D
## An arrow from your bow (player/fighter.gd's _loose): flies fast, bending towards the enemy it was loosed
## at (a full or Perfect draw bends harder), and hits the first enemy its path passes close to, through
## the fighter's arrow_hit. A full draw goes on through up to two more. It sticks where it lands: in the
## enemy it hit (for a moment), or in the ground.

const SPEED := 38.0
const LIFE := 0.55                 # about 20 m, then it drops
const HIT_RADIUS := 0.75
const HIT_SOUND := preload("res://assets/sounds/arrow_hit.wav")

var _dir := Vector3.FORWARD
var _fighter: Node
var _mult := 1.0
var _pierce := 0
var _age := 0.0
var _hit := {}
var _stuck := -1.0
var _target: Node3D
var _homing := 0.0
var _crit := false
var _trail: MeshInstance3D


func fire(from: Vector3, dir: Vector3, fighter: Node, mult: float, pierce: int, glow: Color, target: Node3D = null,
		homing := 0.0, crit := false) -> void:
	global_position = from
	_dir = dir.normalized()
	_fighter = fighter
	_mult = mult
	_pierce = pierce
	_target = target
	_homing = homing
	_crit = crit
	var mi := MeshInstance3D.new()
	mi.mesh = Items.mesh("arrow")
	mi.scale = Vector3.ONE * 1.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees = Vector3(-90, 0, 0)          # the model points along +Y (Blender's Z); the node looks along -Z
	add_child(mi)
	_trail = MeshInstance3D.new()                     # a thin glowing streak behind it
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.03, 1.4 if crit or pierce > 0 else 0.9)
	_trail.mesh = box
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(glow if not crit else Color(1.0, 0.9, 0.5), 0.6)
	_trail.material_override = m
	_trail.position = Vector3(0, 0, box.size.z * 0.6)
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	_face()


func _face() -> void:
	look_at(global_position + _dir, Vector3.UP if absf(_dir.y) < 0.95 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	if _stuck >= 0.0:
		_stuck += delta
		if _stuck > 2.5 or (get_parent() is Node3D and get_parent().has_method("is_alive") and not get_parent().is_alive()):
			queue_free()
		return
	_age += delta
	if _homing > 0.0 and is_instance_valid(_target) and _target.is_alive() and not _hit.has(_target):
		var want := (_target.global_position + Vector3(0, 0.7, 0) - global_position).normalized()
		if want.dot(_dir) > 0.0:                      # only while it's still ahead
			_dir = _dir.slerp(want, clampf(_homing * delta, 0.0, 1.0)).normalized()
			_face()
	var from := global_position
	global_position += _dir * SPEED * delta
	for e in get_tree().get_nodes_in_group("enemy"):
		if _hit.has(e) or not e.is_alive() or (e.has_method("is_evading") and e.is_evading()):
			continue
		var c: Vector3 = (e as Node3D).global_position + Vector3(0, 0.7, 0)
		var on_path := Geometry3D.get_closest_point_to_segment(c, from, global_position)
		if c.distance_to(on_path) < HIT_RADIUS + (0.5 if e.is_in_group("elite") else 0.0):
			_hit[e] = true
			_fighter.arrow_hit(e, _mult, _crit)
			var snd := AudioStreamPlayer3D.new()
			snd.stream = HIT_SOUND
			get_parent().add_child(snd)
			snd.global_position = on_path
			snd.play()
			snd.finished.connect(snd.queue_free)
			if _pierce <= 0:
				_stick_in(e as Node3D, on_path)
				return
			_pierce -= 1
	var ground: float = Carcass.shape.height_at(global_position.x, global_position.z) if Carcass.shape else -INF
	if _age > LIFE or global_position.y < ground + 0.05:
		_stuck = 0.0
		_trail.visible = false


## Stays in what it hit for a moment, moving with it.
func _stick_in(e: Node3D, at: Vector3) -> void:
	_stuck = 0.0
	_trail.visible = false
	var keep := global_transform
	keep.origin = at - _dir * 0.25
	get_parent().remove_child(self)
	e.add_child(self)
	global_transform = keep
