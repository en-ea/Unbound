class_name BoarVisual
extends Node3D
## The boar's look and procedural animation: legs trot in diagonal pairs, the body bobs, the head
## nods; it lowers its head to charge, paws the ground when alert, flashes white when hit and
## falls over when it dies. The model's parts come from tools-src/blender/make_boar.py.

const PARTS := ["Body", "Head", "Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR", "Tail", "Jaw"]
const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")
const BAR_SHADER := preload("res://shaders/health_bar.gdshader")

var speed := 0.0            # ground speed, set by Boar
var mode := "walk"          # walk / alert / windup / stalk / charge / hurt / dead
var tell := 0.0             # 0..1 through an attack's wind-up: glows and the "!" swells
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
var _bar: MeshInstance3D
var _bar_mat: ShaderMaterial
var _bar_alpha := 0.0
var _trail := 1.0
var _fill := 1.0
var _trail_wait := 0.0
var _bar_time := 0.0
var _phase := 0.0
var _time := 0.0
var _flash := 0.0
var _flash_set := 0.0
var _tell_set := 0.0
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
	_bar = _make_bar()           # always drawn (see-through when hidden), so its shader is ready
	_bar.position = Vector3(0, bar_height, 0)
	add_child(_bar)


func flash() -> void:
	_flash = 1.0


## Shows the health bar for a few seconds after a hit.
func show_health(fraction: float, hit_points := 5) -> void:
	_bar_mat.set_shader_parameter("segments", float(hit_points))
	_bar_time = 3.0 if fraction > 0.0 else 0.6
	_fill = fraction
	_bar_mat.set_shader_parameter("fill", fraction)
	_trail_wait = 0.35


func reset() -> void:
	tell = 0.0
	_fall = 0.0
	_trail = 1.0
	_fill = 1.0
	_bar_mat.set_shader_parameter("fill", 1.0)
	rotation = Vector3.ZERO


func _process(delta: float) -> void:
	_time += delta
	if _flash > 0.0 or _flash_set > 0.0:        # only touch the materials while flashing
		_flash = maxf(_flash - delta * 5.0, 0.0)
		for m in _materials:
			m.set_shader_parameter("flash", _flash)
		_flash_set = _flash
	if tell > 0.0 or _tell_set > 0.0:           # a hot pulse that quickens as the attack nears
		var w := tell * (0.55 + 0.45 * sin(_time * lerpf(14.0, 30.0, tell)))
		for m in _materials:
			m.set_shader_parameter("warn", w)
		_tell_set = tell
	var warn := mode in ["alert", "windup", "charge", "stalk"]
	var eyes := move_toward(_eyes, 1.0 if warn else 0.0, delta * 4.0)
	if eyes != _eyes:
		_eyes = eyes
		for m in _eye_materials:
			m.set_shader_parameter("glow", _eyes * 2.5)
	var mark_a := move_toward(_alert_mark.modulate.a, 1.0 if mode in ["alert", "windup"] or tell > 0.0 else 0.0, delta * 6.0)
	var mark_col := Color(1.0, 0.35, 0.25).lerp(Color(1.0, 0.86, 0.45), tell * (0.5 + 0.5 * sin(_time * 30.0)))
	_alert_mark.modulate = Color(mark_col, mark_a)
	_alert_mark.outline_modulate.a = mark_a
	_alert_mark.scale = Vector3.ONE * (1.0 + tell * 0.6)
	_alert_mark.position.y = mark_height + sin(_time * 10.0) * 0.05 + tell * 0.15
	_dust.emitting = mode == "charge" or mode == "windup"
	_bar_time -= delta
	_bar_alpha = move_toward(_bar_alpha, 1.0 if _bar_time > 0.0 else 0.0, delta * 5.0)
	_trail_wait -= delta
	if _trail_wait <= 0.0:
		_trail = move_toward(_trail, _fill, delta * 1.2)
	_bar.visible = _bar_alpha > 0.001 or _time < 1.0    # drawn at the start so its shader gets ready
	if _bar.visible:
		_bar_mat.set_shader_parameter("trail", _trail)
		_bar_mat.set_shader_parameter("alpha", _bar_alpha)
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
		"windup":        # head down, tusks forward, pawing hard
			head_pitch = 0.28 + sin(_time * 20.0) * 0.03
			swing = 0.0
			if paws:
				_parts["Leg_FR"].transform = _rest["Leg_FR"] * Transform3D(Basis(Vector3.RIGHT, -0.75 * maxf(sin(_time * 16.0), 0.0)), Vector3.ZERO)
		"hurt":
			head_pitch = -0.3
	_pose(swing, bob, head_pitch, stride)


func _pose(swing: float, bob: float, head_pitch: float, stride: float) -> void:
	_parts["Body"].transform = _rest["Body"] * Transform3D(Basis(Vector3.RIGHT, stride * 0.06), Vector3(0, bob, 0))
	_parts["Head"].transform = _rest["Head"] * Transform3D(Basis(Vector3.RIGHT, head_pitch), Vector3(0, bob, 0))
	for leg: String in ["Leg_FL", "Leg_BR"]:
		_parts[leg].transform = _rest[leg] * Transform3D(Basis(Vector3.RIGHT, swing), Vector3.ZERO)
	for leg: String in ["Leg_FR", "Leg_BL"]:
		if leg == "Leg_FR" and mode in ["alert", "windup"] and paws:
			continue
		_parts[leg].transform = _rest[leg] * Transform3D(Basis(Vector3.RIGHT, -swing), Vector3.ZERO)


func _make_bar() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.05, 0.15)
	mi.mesh = quad
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = BAR_SHADER
	_bar_mat.set_shader_parameter("aspect", 7.0)
	_bar_mat.render_priority = 2
	mi.material_override = _bar_mat
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
