class_name BoarVisual
extends Node3D
## The boar's look and procedural animation: legs trot in diagonal pairs, the body bobs, the head
## nods; it lowers its head to charge, paws the ground when alert, flashes white when hit and
## falls over when it dies. The model's parts come from tools-src/blender/make_boar.py.

const MODEL := preload("res://assets/creatures/boar.glb")
const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")

var speed := 0.0            # ground speed, set by Boar
var mode := "walk"          # walk / alert / charge / hurt / dead

var _parts := {}            # name -> Node3D
var _rest := {}             # name -> Transform3D
var _materials: Array[ShaderMaterial] = []
var _phase := 0.0
var _time := 0.0
var _flash := 0.0
var _fall := 0.0


func _ready() -> void:
	var model := MODEL.instantiate()
	add_child(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := ShaderMaterial.new()
			mat.shader = SOLID_SHADER
			mat.set_shader_parameter("albedo", Color.WHITE)
			mat.set_shader_parameter("sway", 0.0)
			mi.set_surface_override_material(s, mat)
			_materials.append(mat)
	for name in ["Body", "Head", "Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR"]:
		var node := model.find_child(name, true, false) as Node3D
		_parts[name] = node
		_rest[name] = node.transform


func flash() -> void:
	_flash = 1.0


func reset() -> void:
	_fall = 0.0
	rotation = Vector3.ZERO


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 5.0, 0.0)
	for m in _materials:
		m.set_shader_parameter("flash", _flash)
	if mode == "dead":
		_fall = minf(_fall + delta * 3.0, 1.0)
		rotation.z = ease(_fall, 0.4) * PI * 0.5
		_pose(0.0, 0.0, 0.0, 0.0)
		return
	# Legs cycle faster the faster it moves; a charge is a full gallop.
	var stride := clampf(speed / 7.0, 0.0, 1.0)
	_phase += delta * (4.0 + speed * 2.2)
	var swing := sin(_phase) * lerpf(0.0, 0.7, clampf(speed / 1.5, 0.0, 1.0))
	var bob := absf(sin(_phase)) * 0.05 * clampf(speed, 0.0, 1.5)
	var head_pitch := sin(_time * 1.6) * 0.04
	match mode:
		"charge":
			head_pitch = 0.35          # head down, tusks forward
		"alert":
			head_pitch = -0.15 + sin(_time * 12.0) * 0.05
			swing = 0.0
			# Paw the ground with a front leg.
			_parts["Leg_FR"].transform = _rest["Leg_FR"] * Transform3D(Basis(Vector3.RIGHT, -0.6 * maxf(sin(_time * 9.0), 0.0)), Vector3.ZERO)
		"hurt":
			head_pitch = -0.3
	_pose(swing, bob, head_pitch, stride)


func _pose(swing: float, bob: float, head_pitch: float, stride: float) -> void:
	_parts["Body"].transform = _rest["Body"] * Transform3D(Basis(Vector3.RIGHT, stride * 0.06), Vector3(0, bob, 0))
	_parts["Head"].transform = _rest["Head"] * Transform3D(Basis(Vector3.RIGHT, head_pitch), Vector3(0, bob, 0))
	for leg: String in ["Leg_FL", "Leg_BR"]:
		_parts[leg].transform = _rest[leg] * Transform3D(Basis(Vector3.RIGHT, swing), Vector3.ZERO)
	for leg: String in ["Leg_FR", "Leg_BL"]:
		if leg == "Leg_FR" and mode == "alert":
			continue
		_parts[leg].transform = _rest[leg] * Transform3D(Basis(Vector3.RIGHT, -swing), Vector3.ZERO)
