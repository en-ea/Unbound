class_name Hollow
extends Node3D
## The Hollow: what the Long Night left behind, rising out of the land behind the hill in the awakening
## (story/awakening.gd). A colossal shadow, about fifty metres tall, built from a few simple shapes merged
## into two meshes (body, head) with one shader (shaders/hollow.gdshader): near-black, a violet rim, the
## surface boiling. Burning eyes that show through the fog. Smoke rolls off its base.
## Also makes the shadow tendrils that tear out of the ground (`tendril()`).

const SHADER := preload("res://shaders/hollow.gdshader")
const EYE_SHADER := preload("res://shaders/hollow_eye.gdshader")
const SINK := 62.0            # metres under the ground while it sleeps

var _mat: ShaderMaterial
var _body: Node3D             # leans back when the stones strike it
var _head: Node3D             # tilts to look at you
var _eyes: Array[Node3D] = []
var _eye_mats: Array[ShaderMaterial] = []
var _smoke: CPUParticles3D
var _ground_y := 0.0


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("boil", 0.45)
	_mat.set_shader_parameter("rim", 1.1)
	_body = Node3D.new()
	add_child(_body)
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ball := _sphere()
	var limb := CapsuleMesh.new()
	limb.radius = 0.5
	limb.height = 2.0
	limb.radial_segments = 10
	limb.rings = 4
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	_add(body, ball, Transform3D(Basis.from_scale(Vector3(17, 15, 12)), Vector3(0, 4, -2)))           # haunches, half in the ground
	_add(body, ball, Transform3D(Basis(Vector3.RIGHT, 0.28).scaled(Vector3(14, 19, 10)), Vector3(0, 18, 0)))   # the hunched chest
	for s in [-1.0, 1.0]:
		_add(body, ball, Transform3D(Basis.from_scale(Vector3(9, 7, 8)), Vector3(12.5 * s, 27, 2)))    # shoulders
		var shoulder := Vector3(13.5 * s, 26, 3)
		var hand := Vector3(18 * s, 0.5, 24)
		_add(body, limb, _between(shoulder, hand, 4.2))                                                  # arms, reaching to the ground
		_add(body, ball, Transform3D(Basis.from_scale(Vector3(6, 2.6, 7)), hand + Vector3(0, 0.5, 1)))  # hands
		for f in 4:                                                                                       # claws dug into the land
			var a := (f - 1.5) * 0.32
			var dir := Vector3(sin(a) * 0.9, -0.25, cos(a)).normalized()
			_add(body, cone, _between(hand + Vector3(sin(a) * 2.5, 0.8, 2.5), hand + Vector3(sin(a) * 2.5, 0.8, 2.5) + dir * 8.0, 1.6, true))
	for k in 3:                                                                                           # spines down its back
		_add(body, cone, Transform3D(Basis(Vector3.RIGHT, -0.7 - k * 0.15).scaled(Vector3(2.4, 9.0 - k * 1.5, 2.4)), Vector3(0, 30 - k * 6.5, -6 - k * 1.5)))
	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = body.commit()
	body_mesh.material_override = _mat
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(body_mesh)
	_head = Node3D.new()
	_head.position = Vector3(0, 31, 6)
	_body.add_child(_head)
	var head := SurfaceTool.new()
	head.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add(head, ball, Transform3D(Basis.from_scale(Vector3(7.5, 8, 8.5)), Vector3(0, 4.5, 3)))                     # skull
	_add(head, ball, Transform3D(Basis(Vector3.RIGHT, 0.35).scaled(Vector3(5.5, 3.5, 6.5)), Vector3(0, 1.5, 6.5)))  # jaw, jutting
	for s in [-1.0, 1.0]:                                                                                           # horns sweeping back
		_add(head, cone, _between(Vector3(3.2 * s, 7.5, 2), Vector3(9.5 * s, 16, -6), 2.6, true))
		_add(head, cone, _between(Vector3(2.0 * s, 8.0, 4), Vector3(4.0 * s, 13, -1), 1.4, true))
	var head_mesh := MeshInstance3D.new()
	head_mesh.mesh = head.commit()
	head_mesh.material_override = _mat
	head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(head_mesh)
	for s in [-1.0, 1.0]:                                                                                           # the eyes
		var eye := Node3D.new()
		eye.position = Vector3(2.6 * s, 4.6, 11.0)
		_head.add_child(eye)
		eye.add_child(_eye_quad(Vector2(3.2, 1.3), 0.0))
		eye.add_child(_eye_quad(Vector2(13.0, 9.0), 1.0))
		eye.scale = Vector3(1, 0.02, 1)
		_eyes.append(eye)
	_smoke = _make_smoke()
	add_child(_smoke)
	_ground_y = position.y
	position.y = _ground_y - SINK


## Puts it at `at` (on the ground), facing `face`, asleep under the land.
func place(at: Vector3, face: Vector3) -> void:
	_ground_y = at.y
	global_position = Vector3(at.x, at.y - SINK, at.z)
	var to := face - at
	rotation.y = atan2(to.x, to.z)


## It climbs out of the land over `secs`.
func rise(secs: float) -> Tween:
	_smoke.emitting = true
	var t := create_tween()
	t.tween_property(self, "position:y", _ground_y - 4.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return t


func open_eyes(secs: float) -> void:
	for e in _eyes:
		var t := e.create_tween()
		t.tween_property(e, "scale", Vector3.ONE, secs).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Its eyes narrow (0..1 of open).
func narrow(amount: float, secs: float) -> void:
	for e in _eyes:
		e.create_tween().tween_property(e, "scale", Vector3(1, amount, 1), secs)


## It lowers its head and leans in to look at `point`.
func look_at_point(point: Vector3, secs: float) -> void:
	var from := _head.global_position
	var down := atan2(from.y - point.y, Vector2(point.x - from.x, point.z - from.z).length())
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_head, "rotation:x", clampf(down * 0.8, 0.0, 0.7), secs)
	t.tween_property(_body, "rotation:x", 0.12, secs)


## Struck by the stones' light: it rears back, its eyes pinch shut, and it sinks into the land, smoking.
func recoil_and_sink(secs: float) -> Tween:
	_mat.set_shader_parameter("rim_color", Color(0.85, 0.9, 1.0))
	var t := create_tween()
	t.tween_property(_body, "rotation:x", -0.32, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_head, "rotation:x", -0.45, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(func(c: Color) -> void: _mat.set_shader_parameter("rim_color", c), Color(0.85, 0.9, 1.0), Color(0.55, 0.32, 0.95), 1.2)
	t.tween_property(self, "position:y", _ground_y - SINK, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: _smoke.emitting = false)
	narrow(0.15, 0.5)
	return t


func head_position() -> Vector3:
	return _head.global_position + _head.global_basis * Vector3(0, 4.5, 6)


## A shadow tendril tearing out of the ground at `at`, `height` tall, swaying. Returns its root (scale y
## grows it). They share one material, so a ring of them costs little.
static func tendril(parent: Node, at: Vector3, height: float, mat: ShaderMaterial) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.42 + height * 0.04
	cyl.height = height
	cyl.radial_segments = 6
	cyl.rings = 6
	mi.mesh = cyl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = height * 0.5
	root.add_child(mi)
	parent.add_child(root)
	root.global_position = at + Vector3(0, -0.3, 0)
	root.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
	root.scale = Vector3(1, 0.01, 1)
	return root


static func tendril_material(height: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("boil", 0.04)
	m.set_shader_parameter("lean", 1.1)
	m.set_shader_parameter("base_y", -height * 0.5)
	m.set_shader_parameter("tall", height)
	return m


func _sphere() -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 14
	s.rings = 8
	return s


func _add(st: SurfaceTool, mesh: Mesh, xf: Transform3D) -> void:
	st.append_from(mesh, 0, xf)


## A part stretched between two points (a limb, a horn): its local up runs from a to b. Cones point at b.
func _between(a: Vector3, b: Vector3, thick: float, cone := false) -> Transform3D:
	var up := (b - a)
	var length := up.length()
	var y := up / length
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var basis := Basis(x * thick, y * (length if cone else length * 0.5), z * thick)
	return Transform3D(basis, (a + b) * 0.5)


func _eye_quad(size: Vector2, glow: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = EYE_SHADER
	m.set_shader_parameter("glow", glow)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_eye_mats.append(m)
	return mi


func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 26
	p.lifetime = 4.5
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(26, 2, 16)
	p.position = Vector3(0, SINK - 2.0, 8)     # at the land's surface once it has risen: placed in _process
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(0.35, 1.0))
	curve.add_point(Vector2(1, 0.6))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.1, 0.05, 0.16, 0.0))
	ramp.add_point(0.2, Color(0.08, 0.04, 0.12, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.02, 0.01, 0.04, 0.0))
	p.color_ramp = ramp
	var mesh := SphereMesh.new()
	mesh.radius = 3.5
	mesh.height = 7.0
	mesh.radial_segments = 8
	mesh.rings = 4
	p.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _process(_delta: float) -> void:
	if _smoke:                                  # the smoke rolls along the ground, wherever the body is
		_smoke.global_position = Vector3(global_position.x, _ground_y - 1.0, global_position.z) + global_basis.z * 8.0
