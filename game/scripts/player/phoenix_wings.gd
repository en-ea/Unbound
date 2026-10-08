class_name PhoenixWings
extends Node3D
## The Pyromancer's Phoenix Wings (abilities.gd): two great wings of fire on the player's back.
## Built from fanned flame "feathers" (one additive mesh per wing) with flames streaming off them.
## `open` 0..1 spreads them; `flap` beats them. Free it with `dissolve()`.

const FEATHER := preload("res://shaders/phoenix_feather.gdshader")
const FEATHERS := 11

var open := 0.0
var flap_speed := 7.0
var _wings: Array[Node3D] = []
var _mats: Array[ShaderMaterial] = []
var _t := 0.0


func _ready() -> void:
	for s in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(s * 0.12, 1.32, -0.16)
		add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = _wing_mesh(s)
		var m := ShaderMaterial.new()
		m.shader = FEATHER
		m.set_shader_parameter("seed", s * 3.1)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		_mats.append(m)
		_wings.append(pivot)
		# flames pouring off the wing's leading edge and tips
		for k in 3:
			var at := Vector3(s * (0.9 + k * 0.9), 0.5 + k * 0.45, -0.2 - k * 0.15)
			var f := FireFX.flames(pivot, Vector3.ZERO, 0.3 + k * 0.1, 10, 0.5, false, 0.45)
			f.position = at
			f.local_coords = false
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position = Vector3(0, 1.8, -0.4)
	add_child(light)
	scale = Vector3.ONE * 0.01


## One wing: feathers fanned from the shoulder, outward (`s` = side) and up, sweeping back.
func _wing_mesh(s: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in FEATHERS:
		var k := float(i) / (FEATHERS - 1)
		var ang := deg_to_rad(lerpf(-35.0, 72.0, k))           # low trailing feathers to high leading ones
		var length := lerpf(1.6, 3.4, sin(k * PI * 0.85 + 0.25))
		var width := lerpf(0.28, 0.42, k)
		var dir := Vector3(s * cos(ang), sin(ang), -0.35 - 0.25 * (1.0 - k)).normalized()
		var side := dir.cross(Vector3(0, 0, 1)).normalized() * width
		var root := Vector3(0, 0, -0.02 * i)
		var tip := root + dir * length
		var bulge := root + dir * length * 0.4
		var curl := Vector3(0, -0.25 * k, -0.25)           # the tips curl back and down a little
		tip += curl
		var pts := [root, bulge + side, tip, bulge - side]
		var uvs := [Vector2(0.5, 0.0), Vector2(1.0, 0.4), Vector2(0.5, 1.0), Vector2(0.0, 0.4)]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for j in tri:
				st.set_uv(uvs[j])
				st.add_vertex(pts[j])
	# a glowing inner membrane joining the feather roots
	return st.commit()


func _process(delta: float) -> void:
	_t += delta
	var beat := sin(_t * flap_speed)
	for i in _wings.size():
		var s := 1.0 if i == 0 else -1.0
		_wings[i].rotation = Vector3(0.15 * beat, s * (0.35 - 0.3 * open + 0.12 * beat), s * (0.55 * (1.0 - open) - 0.2 * beat))


## Bursts open from nothing.
func unfurl(time := 0.35) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector3.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "open", 1.0, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Folds and burns away, then frees itself.
func dissolve(time := 0.5) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector3.ONE * 1.3, time)
	t.tween_method(func(v: float) -> void:
		for m in _mats:
			m.set_shader_parameter("fade", v), 1.0, 0.0, time)
	for p in find_children("*", "CPUParticles3D", true, false):
		(p as CPUParticles3D).emitting = false
	t.chain().tween_interval(0.6)
	t.chain().tween_callback(queue_free)
