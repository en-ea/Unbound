extends Node3D
## Small life in the meadow, kept sparse: butterflies drifting over the grass by day, rabbits that
## hop about and bolt when you come close, and little flocks of birds that peck on the ground and
## take off as you walk up. Each kind is one MultiMesh (one draw call), moved here in code.

const CRITTER_SHADER := preload("res://shaders/critter.gdshader")
const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")
const RABBIT := preload("res://assets/props/rabbit.glb")
const BUTTERFLIES := 12
const RABBITS := 6
const FLOCKS := 2
const FLOCK_SIZE := 5
const BUTTERFLY_COLORS := [Color(1.0, 0.85, 0.35), Color(0.95, 0.95, 0.98), Color(0.55, 0.75, 1.0), Color(1.0, 0.6, 0.35)]

@export var player: Node3D
@export var day_night: Node

var _shape: WorldShape
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _butterflies: Array[Dictionary] = []
var _rabbits: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _bf_mm: MultiMesh
var _rb_mm: MultiMesh
var _bd_mm: MultiMesh


func build(shape: WorldShape) -> void:
	_shape = shape
	_rng.seed = 77
	_bf_mm = _multimesh(_butterfly_mesh(), BUTTERFLIES, true)
	_rb_mm = _multimesh(_rabbit_mesh(), RABBITS, false)
	_bd_mm = _multimesh(_bird_mesh(), FLOCKS * FLOCK_SIZE, true)
	for i in BUTTERFLIES:
		var c: Color = BUTTERFLY_COLORS[i % BUTTERFLY_COLORS.size()]
		_bf_mm.set_instance_color(i, c.srgb_to_linear())
		_bf_mm.set_instance_custom_data(i, Color(_rng.randf(), 0.9, 0.45, 0.0))
		var home := _spot()
		_butterflies.append({"home": home, "ground": _shape.height_at(home.x, home.y), "phase": _rng.randf() * TAU, "speed": _rng.randf_range(0.7, 1.2)})
	for i in RABBITS:
		var home := _spot()
		_rabbits.append({"home": home, "pos": _ground(home), "from": _ground(home), "to": _ground(home), "hop": 1.0,
			"wait": _rng.randf_range(0.5, 3.0), "facing": _rng.randf() * TAU, "flee": 0.0})
	for f in FLOCKS:
		var home := _spot()
		for i in FLOCK_SIZE:
			var p := home + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2))
			_bd_mm.set_instance_color(f * FLOCK_SIZE + i, Color(0.55, 0.45, 0.38).srgb_to_linear())
			_birds.append({"flock": f, "pos": _ground(p), "vel": Vector3.ZERO, "flying": false, "timer": 0.0,
				"facing": _rng.randf() * TAU, "phase": _rng.randf()})


func _process(delta: float) -> void:
	if _shape == null:
		return
	_time += delta
	var me := player.global_position
	_update_butterflies(delta)
	_update_rabbits(delta, me)
	_update_birds(delta, me)


func _update_butterflies(_delta: float) -> void:
	var night: float = day_night.night
	var shown := clampf(1.0 - night * 1.5, 0.0, 1.0)      # asleep at night (fireflies take over)
	for i in _butterflies.size():
		var b := _butterflies[i]
		var p := _butterfly_at(b, _time)
		var ahead := _butterfly_at(b, _time + 0.1) - p
		var basis := Basis.looking_at(ahead.normalized() if ahead.length() > 0.001 else Vector3.FORWARD, Vector3.UP, true)
		_bf_mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * maxf(shown, 0.001)), p))


func _butterfly_at(b: Dictionary, t: float) -> Vector3:
	var ph: float = b["phase"]
	var s: float = b["speed"]
	var home: Vector2 = b["home"]
	var x := home.x + sin(t * 0.45 * s + ph) * 2.6 + sin(t * 1.3 * s + ph * 3.0) * 0.5
	var z := home.y + sin(t * 0.33 * s + ph * 2.0) * 2.6 + cos(t * 1.1 * s + ph) * 0.5
	return Vector3(x, b["ground"] + 0.9 + sin(t * 2.1 + ph) * 0.25, z)      # ground height cached per home


func _update_rabbits(delta: float, me: Vector3) -> void:
	for i in _rabbits.size():
		var r := _rabbits[i]
		var pos: Vector3 = r["pos"]
		var away := pos - me
		away.y = 0.0
		if away.length() < 4.5 and r["flee"] <= 0.0:
			r["flee"] = 2.5                       # bolt!
			r["wait"] = 0.0
		r["flee"] = maxf(r["flee"] - delta, 0.0)
		if r["hop"] < 1.0:
			var fast: bool = r["flee"] > 0.0
			r["hop"] = minf(r["hop"] + delta / (0.22 if fast else 0.3), 1.0)
			var t: float = r["hop"]
			pos = (r["from"] as Vector3).lerp(r["to"], t) + Vector3(0, sin(t * PI) * (0.28 if fast else 0.16), 0)
			r["pos"] = pos
		else:
			r["wait"] -= delta
			if r["wait"] <= 0.0:
				var dir: Vector3
				var home: Vector2 = r["home"]
				if r["flee"] > 0.0 and away.length() > 0.01:
					dir = away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5)) * 1.3
					r["wait"] = 0.02
				else:
					var to_home := Vector3(home.x - pos.x, 0, home.y - pos.z)
					dir = (to_home * 0.15 + Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)).normalized() * 0.6
					r["wait"] = _rng.randf_range(0.6, 3.5)
				var target := pos + dir
				if _shape.height_at(target.x, target.z) < WorldShape.WATER_Y + 0.2:
					target = pos - dir                    # don't hop into the pond
				r["from"] = pos
				r["to"] = _ground(Vector2(target.x, target.z))
				r["hop"] = 0.0
				r["facing"] = atan2(dir.x, dir.z)
		var squash := 1.0 + sin(clampf(r["hop"], 0.0, 1.0) * PI) * 0.15
		var basis := Basis(Vector3.UP, r["facing"]).scaled(Vector3(1.0 / sqrt(squash), squash, 1.0 / sqrt(squash)))
		_rb_mm.set_instance_transform(i, Transform3D(basis * 1.1, pos))


func _update_birds(delta: float, me: Vector3) -> void:
	for i in _birds.size():
		var b := _birds[i]
		var pos: Vector3 = b["pos"]
		if b["flying"]:
			b["timer"] -= delta
			var vel: Vector3 = b["vel"]
			vel.y = minf(vel.y + 3.0 * delta, 4.0)
			b["vel"] = vel
			pos += vel * delta
			b["facing"] = atan2(vel.x, vel.z)
			if b["timer"] <= 0.0:                     # far away now: land somewhere else later
				b["flying"] = false
				b["timer"] = -_rng.randf_range(20.0, 35.0)
				pos = Vector3(0, -50, 0)
			b["pos"] = pos
			_bd_mm.set_instance_custom_data(i, Color(b["phase"], 1.0, 0.2, 0.0))
		elif b["timer"] < 0.0:                        # waiting off-map
			b["timer"] += delta
			if b["timer"] >= 0.0:
				var home := _spot()
				for other in _birds:
					if other["flock"] == b["flock"] and not other["flying"]:
						other["pos"] = _ground(home + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2)))
						other["timer"] = 0.0
			pos = b["pos"]
		else:
			var away := pos - me
			away.y = 0.0
			if away.length() < 6.0:
				for other in _birds:                   # the whole flock takes off together
					if other["flock"] == b["flock"] and not other["flying"] and other["timer"] >= 0.0:
						var dir := ((other["pos"] as Vector3) - me)
						dir.y = 0.0
						other["flying"] = true
						other["timer"] = 5.0
						other["vel"] = dir.normalized().rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * _rng.randf_range(4.5, 6.0) + Vector3(0, 2.5, 0)
			else:
				_bd_mm.set_instance_custom_data(i, Color(b["phase"], 0.0, 0.1, 1.0))
		# Sitting birds peck: a quick dip now and then.
		var peck := 0.0 if b["flying"] else maxf(sin(_time * 3.0 + b["phase"] * 20.0), 0.0) ** 8 * 0.5
		var basis := Basis(Vector3.UP, b["facing"]) * Basis(Vector3.RIGHT, peck)
		_bd_mm.set_instance_transform(i, Transform3D(basis, pos + Vector3(0, 0.05, 0)))


# --- setup helpers -------------------------------------------------------------------------

## A random open meadow spot: dry land, off the path and away from houses and the pond.
func _spot() -> Vector2:
	for i in 60:
		var p := Vector2(_rng.randf_range(-48, 48), _rng.randf_range(-48, 48))
		if _shape.height_at(p.x, p.y) > WorldShape.WATER_Y + 0.5 and not _shape.in_clearing(p) \
				and _shape.path_distance(p) > 2.5 and _shape.pond_distance(p) > WorldShape.POND_RADIUS + 1.5:
			return p
	return WorldShape.SPAWN


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, _shape.height_at(p.x, p.y), p.y)


func _multimesh(mesh: Mesh, count: int, custom: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = custom
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-80, -60, -80), Vector3(160, 120, 160))    # spread over the map
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if custom else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)
	return mm


func _critter_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CRITTER_SHADER
	return mat


## Two pairs of rounded wings on a thin dark body, facing +Z.
func _butterfly_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wing := [Vector3(0.012, 0, 0.0), Vector3(0.05, 0, 0.075), Vector3(0.1, 0, 0.06), Vector3(0.095, 0, 0.0),
		Vector3(0.075, 0, -0.045), Vector3(0.035, 0, -0.065)]
	for s in [1.0, -1.0]:
		for k in range(1, wing.size() - 1):
			for v: Vector3 in [wing[0], wing[k], wing[k + 1]]:
				st.set_color(Color.WHITE if k < 3 else Color(0.85, 0.85, 0.85))
				st.add_vertex(Vector3(v.x * s, v.y, v.z))
	var body := [Vector3(0, 0.006, 0.04), Vector3(0.008, 0, 0.0), Vector3(0, 0.006, -0.05), Vector3(-0.008, 0, 0.0)]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for k: int in tri:
			st.set_color(Color(0.04, 0.03, 0.03))
			st.add_vertex(body[k])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _critter_material())
	return mesh


## A small faceted bird: diamond body, pointed wings and tail, pale belly, facing +Z.
func _bird_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nose := Vector3(0, 0.06, 0.1)
	var tail := Vector3(0, 0.07, -0.1)
	var top := Vector3(0, 0.1, 0.0)
	var belly := Vector3(0, 0.02, 0.0)
	var l := Vector3(0.011, 0.06, 0.0)
	var r := Vector3(-0.011, 0.06, 0.0)
	var dark := Color(0.8, 0.8, 0.8)
	var pale := Color(1.6, 1.5, 1.35)
	for tri in [[nose, l, top, dark], [nose, top, r, dark], [nose, belly, l, pale], [nose, r, belly, pale],
			[tail, top, l, dark], [tail, r, top, dark], [tail, l, belly, pale], [tail, belly, r, pale],
			[tail, Vector3(0.03, 0.07, -0.16), Vector3(-0.03, 0.07, -0.16), dark]]:
		for k in 3:
			st.set_color(tri[3])
			st.add_vertex(tri[k])
	for s in [1.0, -1.0]:
		var root_f := Vector3(0.011 * s, 0.07, 0.03)
		var root_b := Vector3(0.011 * s, 0.07, -0.04)
		var tip := Vector3(0.17 * s, 0.07, -0.05)
		for v in [root_f, tip, root_b]:
			st.set_color(Color(0.62, 0.62, 0.62))
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _critter_material())
	return mesh


func _rabbit_mesh() -> Mesh:
	var model := RABBIT.instantiate()
	var mi := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mi.mesh.duplicate() as Mesh
	var mat := ShaderMaterial.new()
	mat.shader = SOLID_SHADER
	mat.set_shader_parameter("albedo", Color.WHITE)
	mat.set_shader_parameter("sway", 0.0)
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, mat)
	model.free()
	return mesh
