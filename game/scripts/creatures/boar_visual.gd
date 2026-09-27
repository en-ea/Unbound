class_name BoarVisual
extends Node3D
## The boar's look and procedural animation: legs trot in diagonal pairs, the body bobs, the head
## nods; it lowers its head to charge, paws the ground when alert, flashes white when hit and
## falls over when it dies. The model's parts come from tools-src/blender/make_boar.py.

const PARTS := ["Body", "Head", "Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR", "Tail", "Jaw"]
const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")

var speed := 0.0            # ground speed, set by Boar
var mode := "walk"          # walk / alert / charge / hurt / dead
## Other creatures reuse this script (see wolf_visual.gd) with their own model and sizes.
var model_scene: PackedScene = preload("res://assets/creatures/boar.glb")
var paws := true            # paws the ground when alert
var mark_height := 2.0
var bar_height := 1.75

var _parts := {}            # name -> Node3D
var _rest := {}             # name -> Transform3D
var _materials: Array[ShaderMaterial] = []
var _eye_materials: Array[ShaderMaterial] = []
var _eyes := 0.0            # 0..1 red eye glow (warning before a charge)
var _alert_mark: Label3D
var _dust: CPUParticles3D
var _bar_back: MeshInstance3D
var _bar_fill: MeshInstance3D
var _bar_time := 0.0
var _phase := 0.0
var _time := 0.0
var _flash := 0.0
var _fall := 0.0


func _ready() -> void:
	var model := model_scene.instantiate()
	add_child(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := ShaderMaterial.new()
			mat.shader = SOLID_SHADER
			mat.set_shader_parameter("albedo", Color.WHITE)
			mat.set_shader_parameter("sway", 0.0)
			mi.set_surface_override_material(s, mat)
			_materials.append(mat)
			var src := mi.mesh.surface_get_material(s)
			if src and src.resource_name == "Eye":
				_eye_materials.append(mat)
	for name: String in PARTS:
		var node := model.find_child(name, true, false) as Node3D
		if node == null:
			continue
		_parts[name] = node
		_rest[name] = node.transform
	_alert_mark = Label3D.new()
	_alert_mark.text = "!"
	_alert_mark.font_size = 96
	_alert_mark.outline_size = 18
	_alert_mark.modulate = Color(1.0, 0.35, 0.25, 0.0)
	_alert_mark.outline_modulate = Color(0.1, 0.02, 0.02, 0.0)
	_alert_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_mark.no_depth_test = true
	_alert_mark.pixel_size = 0.006
	_alert_mark.position = Vector3(0, mark_height, 0)
	add_child(_alert_mark)
	_dust = _make_dust()
	add_child(_dust)
	_bar_back = _bar_quad(Color(0.08, 0.06, 0.08, 0.75), 0.9)
	_bar_fill = _bar_quad(Color(0.9, 0.28, 0.24), 0.84)
	_bar_fill.position.z = 0.002
	_bar_back.add_child(_bar_fill)
	_bar_back.position = Vector3(0, bar_height, 0)
	_bar_back.visible = false
	add_child(_bar_back)


func flash() -> void:
	_flash = 1.0


## Shows the health bar for a few seconds after a hit.
func show_health(fraction: float) -> void:
	_bar_time = 3.0
	_bar_back.visible = fraction > 0.0
	_bar_fill.scale.x = maxf(fraction, 0.001)
	_bar_fill.position.x = -0.42 * (1.0 - fraction)


func reset() -> void:
	_fall = 0.0
	rotation = Vector3.ZERO


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 5.0, 0.0)
	for m in _materials:
		m.set_shader_parameter("flash", _flash)
	var warn := mode == "alert" or mode == "charge"
	_eyes = move_toward(_eyes, 1.0 if warn else 0.0, delta * 4.0)
	for m in _eye_materials:
		m.set_shader_parameter("glow", _eyes * 2.5)
	var mark_a := move_toward(_alert_mark.modulate.a, 1.0 if mode == "alert" else 0.0, delta * 6.0)
	_alert_mark.modulate.a = mark_a
	_alert_mark.outline_modulate.a = mark_a
	_alert_mark.position.y = mark_height + sin(_time * 10.0) * 0.05
	_dust.emitting = mode == "charge"
	if _bar_time > 0.0:
		_bar_time -= delta
		_bar_back.visible = _bar_time > 0.0
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
			if paws:       # paw the ground with a front leg
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
		if leg == "Leg_FR" and mode == "alert" and paws:
			continue
		_parts[leg].transform = _rest[leg] * Transform3D(Basis(Vector3.RIGHT, -swing), Vector3.ZERO)


func _bar_quad(color: Color, width: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.render_priority = 1 if width < 0.88 else 0
	quad.material = mat
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 0.8
	p.local_coords = false
	p.emitting = false
	p.position = Vector3(0, 0.1, 0.4)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, 0.8, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.2
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.5))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.78, 0.68, 0.54)
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
