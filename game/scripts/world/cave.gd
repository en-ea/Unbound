extends Node3D
## Glimmerdeep: a small cave under the Whispering Wood, entered at the Cave Mouth (places.gd). Like your
## home's inside, it is built far below the map when you go in and taken down when you leave.
## The rock is one height grid: low where the caverns and tunnels are, high in the rock around them, so
## the walls come out jagged and faceted, and the same grid is the collision. Blue crystals glow (and can
## be mined for shards), there's iron and copper, glowcaps, a wolf den, and a hoard at the far end.
## Saving waits while you're down here (it saved at the mouth): leave the game inside and you wake at the mouth.

const ROCK_SHADER := preload("res://shaders/cave_rock.gdshader")
const WOLF := preload("res://scenes/wolf.tscn")
const DOOR_SOUND := preload("res://assets/kenney_impact/impactWood_medium_002.ogg")
const AT := Vector3(-300, -300, 0)       # far west of the map and far below it
const MIN := Vector2(-30, -72)           # the grid's corner (x, z), from AT; one vertex a metre
const SIZE := Vector2i(61, 95)
const ENTRY := Vector3(0, 0.3, 5.0)
const EXIT_Z := 7.6                      # walking this far south takes you back out
const ROCK_TOP := 2.5                    # how high the rock stands over the floor (plus up to a metre)
## The caverns (x, z, radius) and the tunnels joining them (from, to, half width).
const ROOMS := [Vector3(0, 0, 5.0), Vector3(-7, -17, 6.5), Vector3(-14, -11, 3.2), Vector3(7, -33, 7.5), Vector3(-1, -51, 5.5)]
const TUNNELS := [[Vector2(0, 2), Vector2(0, 9.5), 2.0], [Vector2(0, -2), Vector2(-6, -12), 2.2],
	[Vector2(-5, -20), Vector2(5, -29), 2.3], [Vector2(6, -38), Vector2(0, -47), 1.9]]
const POOL := Vector3(-14.5, -11.5, 2.3)
const HALL := Vector2(-7, -17)
const DEN := Vector2(7, -33)
const HOARD := Vector2(-1, -52.5)
const CRYSTAL := Color(0.42, 0.85, 1.0)
const FUNGUS := Color(0.45, 1.0, 0.6)
const HOARD_REFILL := 900.0              # seconds before the hoard has something in it again

static var _hoard_ready_at := 0.0

var player: CharacterBody3D
var day_night: Node
var scatter: Node                        # for the ore models
var visuals: Node                        # ResourceVisuals: mining works as anywhere else
var treasure: Node                       # the hoard's chest
var door_out := Vector3.ZERO             # where you stand when you come back out
var active := false

var _built: Node3D                       # the cave, placed at AT
var _loose: Node3D                       # things placed in world coordinates (ore, veins): at the origin
var _rock_mat: ShaderMaterial
var _torch: OmniLight3D
var _first_node := -1
var _chest := -1
var _leaving := false
var _heights := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _bumps := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _audio: AudioStreamPlayer


func _ready() -> void:
	add_to_group("cave")
	_noise.seed = 5
	_noise.frequency = 0.11
	_bumps.seed = 9
	_bumps.frequency = 0.35
	_audio = AudioStreamPlayer.new()
	_audio.stream = DOOR_SOUND
	_audio.volume_db = -10.0
	_audio.pitch_scale = 0.6
	add_child(_audio)
	WorldResources.depleted.connect(func(id: int, _drops: Array) -> void:
		if id == _chest and _chest != -1:
			_hoard_ready_at = Time.get_ticks_msec() / 1000.0 + HOARD_REFILL)


## The action: go down (a fade). Saves first, at the mouth.
func enter() -> void:
	if active:
		return
	SaveGame.save_game()
	_audio.play()
	Region.fade_through(_go_in)


## The action: climb back out to the mouth.
func leave() -> void:
	if not active or _leaving:
		return
	_leaving = true
	_audio.play()
	Region.fade_through(_go_out)


func _go_in() -> void:
	SaveGame.paused = true
	_build()
	active = true
	day_night.set_cave(true)
	player.global_position = AT + ENTRY
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = PI
	_torch = OmniLight3D.new()                   # you carry a little warm light
	_torch.light_color = Color(1.0, 0.74, 0.46)
	_torch.light_energy = 2.4
	_torch.omni_range = 9.0
	_torch.position = Vector3(0.3, 2.3, 0.4)
	player.add_child(_torch)
	get_tree().call_group("camera_rig", "enter_cave")
	get_tree().call_group("hud", "set_cave", true)
	get_tree().call_group("hud", "hint", "Glimmerdeep")


func _go_out() -> void:
	_back_outside()
	player.global_position = door_out
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = 0.0
	get_tree().call_group("camera_rig", "snap")


## Daylight, the land's camera and saving again, and the cave taken down (also when something else
## moved you out: a knock-out).
func _back_outside() -> void:
	active = false
	_leaving = false
	day_night.set_cave(false)
	get_tree().call_group("camera_rig", "leave_cave")
	get_tree().call_group("hud", "set_cave", false)
	if is_instance_valid(_torch):
		_torch.queue_free()
	if _first_node >= 0:
		for id in range(_first_node, WorldResources.node_count()):
			visuals.forget(id)
			treasure.remove_chest(id)
		WorldResources.truncate(_first_node)
		_first_node = -1
	_chest = -1
	if is_instance_valid(_built):
		_built.queue_free()
		_loose.queue_free()
	SaveGame.paused = false


func _physics_process(_delta: float) -> void:
	if not active:
		return
	if player.global_position.y > -100.0:        # knocked out and carried home
		_back_outside()
		return
	if player.global_position.z - AT.z > EXIT_Z:
		leave()


func _process(_delta: float) -> void:
	if active and _rock_mat:
		var cam := get_viewport().get_camera_3d()
		_rock_mat.set_shader_parameter("player_pos", player.global_position)
		if cam:
			_rock_mat.set_shader_parameter("camera_pos", cam.global_position)


# --- the shape of the cave ---------------------------------------------------------------------

## How far a spot is outside the open cave (negative inside), with wobbly walls.
func _dist(p: Vector2) -> float:
	var d := INF
	for r: Vector3 in ROOMS:
		d = minf(d, p.distance_to(Vector2(r.x, r.y)) - r.z)
	for t: Array in TUNNELS:
		d = minf(d, _seg(p, t[0], t[1]) - float(t[2]))
	return d + _noise.get_noise_2d(p.x, p.y) * 1.1


func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0))


func _height(p: Vector2) -> float:
	var ground := _bumps.get_noise_2d(p.x, p.y) * 0.12
	var pool := p.distance_to(Vector2(POOL.x, POOL.y)) - POOL.z
	if pool < 0.6:
		ground -= clampf((0.6 - pool) * 0.35, 0.0, 0.55)
	var top := ROCK_TOP + (_noise.get_noise_2d(p.x * 0.7 + 40.0, p.y * 0.7) * 0.5 + 0.5) * 1.0
	return lerpf(ground, top, smoothstep(-0.3, 0.8, _dist(p)))


## The floor height at a spot (local x, z).
func floor_at(x: float, z: float) -> float:
	var fx := clampf(x - MIN.x, 0.0, SIZE.x - 1.001)
	var fz := clampf(z - MIN.y, 0.0, SIZE.y - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h0 := lerpf(_heights[iz * SIZE.x + ix], _heights[iz * SIZE.x + ix + 1], tx)
	var h1 := lerpf(_heights[(iz + 1) * SIZE.x + ix], _heights[(iz + 1) * SIZE.x + ix + 1], tx)
	return lerpf(h0, h1, tz)


## A spot near the wall of a cavern, `angle` degrees round from east, pulled in until it's clear floor.
func _by_wall(center: Vector2, radius: float, angle: float, clear := 1.2) -> Vector2:
	var dir := Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle)))
	var r := radius
	while r > 0.5 and _dist(center + dir * r) > -clear:
		r -= 0.25
	return center + dir * r


func _local(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, floor_at(p.x, p.y) + lift, p.y)


# --- building it --------------------------------------------------------------------------------

func _build() -> void:
	_rng.seed = 77
	_built = Node3D.new()
	add_child(_built)
	_built.global_position = AT
	_loose = Node3D.new()
	add_child(_loose)
	_heights.resize(SIZE.x * SIZE.y)
	for iz in SIZE.y:
		for ix in SIZE.x:
			_heights[iz * SIZE.x + ix] = _height(Vector2(MIN.x + ix, MIN.y + iz))
	_build_rock()
	_build_void()
	_build_props()
	_build_exit()
	_build_lights()
	_first_node = WorldResources.node_count()
	_build_gatherables()
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _hoard_ready_at:
		_chest = treasure.add_chest(AT + _local(HOARD, 0.36), 0.0)
	_spawn_wolves()


func _build_rock() -> void:
	var verts := PackedVector3Array()
	verts.resize(SIZE.x * SIZE.y)
	for iz in SIZE.y:
		for ix in SIZE.x:
			var h := _heights[iz * SIZE.x + ix]
			var wall := clampf(h / 0.8, 0.0, 1.0)            # rock moves about more than the floor
			var j := Vector2(_rng.randf_range(-0.38, 0.38), _rng.randf_range(-0.38, 0.38)) * lerpf(0.5, 1.0, wall)
			verts[iz * SIZE.x + ix] = Vector3(MIN.x + ix + j.x, h, MIN.y + iz + j.y)
	_rock_mat = ShaderMaterial.new()
	_rock_mat.shader = ROCK_SHADER
	_rock_mat.set_shader_parameter("floor_y", AT.y)
	var rows := 16                                   # in strips, so each only takes the lights near it
	for z0 in range(0, SIZE.y - 1, rows):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for iz in range(z0, mini(z0 + rows, SIZE.y - 1)):
			for ix in SIZE.x - 1:
				var a := verts[iz * SIZE.x + ix]
				var b := verts[iz * SIZE.x + ix + 1]
				var c := verts[(iz + 1) * SIZE.x + ix]
				var d := verts[(iz + 1) * SIZE.x + ix + 1]
				if _rng.randf() < 0.5:
					_face(st, a, b, c)
					_face(st, b, d, c)
				else:
					_face(st, a, b, d)
					_face(st, a, d, c)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _rock_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_built.add_child(mi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = SIZE.x
	shape.map_depth = SIZE.y
	shape.map_data = _heights
	col.shape = shape
	col.position = Vector3(MIN.x + (SIZE.x - 1) * 0.5, 0.0, MIN.y + (SIZE.y - 1) * 0.5)
	body.add_child(col)
	_built.add_child(body)


## One flat-shaded triangle of rock, coloured by what it is: floor, wall or the rock's dark top.
func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (c - a).cross(b - a).normalized()
	var mid := (a + b + c) / 3.0
	var vary := 0.92 + 0.16 * _rng.randf()
	var col: Color
	if mid.y > ROCK_TOP - 0.1 and n.y > 0.75:
		col = Color(0.25, 0.25, 0.31) * vary
	elif n.y < 0.8 or mid.y > 0.35:
		col = Color(0.42, 0.4, 0.43).lerp(Color(0.58, 0.58, 0.66), clampf(mid.y / ROCK_TOP, 0.0, 1.0)) * vary
		var p := Vector2(mid.x, mid.z)
		col = col.lerp(Color(0.4, 0.6, 0.75), 0.35 * (1.0 - smoothstep(4.0, 9.0, p.distance_to(HALL))))
	else:
		col = Color(0.46, 0.42, 0.38) * vary
		var p := Vector2(mid.x, mid.z)
		col = col.lerp(Color(0.32, 0.48, 0.56), 0.55 * (1.0 - smoothstep(3.0, 8.0, p.distance_to(HALL))))
		col = col.lerp(Color(0.5, 0.4, 0.3), 0.4 * (1.0 - smoothstep(3.0, 8.0, p.distance_to(DEN))))
		col = col.lerp(Color(0.38, 0.52, 0.62), 0.5 * (1.0 - smoothstep(2.0, 6.0, p.distance_to(HOARD))))
	st.set_color(col.srgb_to_linear())
	st.set_normal(n)
	for v in [a, b, c]:
		st.add_vertex(v)


## Black under everything, so past the rock there's only darkness (no sky).
func _build_void() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	mi.mesh = plane
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.BLACK
	mi.material_override = m
	mi.position = Vector3(0, -2.5, -25)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_built.add_child(mi)


## Crystals, stalagmites, bones in the den, the pool and the hoard's plinth.
func _build_props() -> void:
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shine := SurfaceTool.new()
	shine.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fungus := SurfaceTool.new()
	fungus.begin(Mesh.PRIMITIVE_TRIANGLES)
	for room: Vector3 in ROOMS:                       # stalagmites by the walls
		for k in int(room.z * 0.9):
			var p := _by_wall(Vector2(room.x, room.y), room.z + 1.0, _rng.randf() * 360.0, 0.5)
			_spike(rock, _local(p, -0.1), _rng.randf_range(0.25, 0.45), _rng.randf_range(0.6, 1.6), Color(0.33, 0.32, 0.35))
	for k in 9:                                       # crystal clusters round the hall and the hoard
		var p := _by_wall(HALL, 7.5, k * 40.0 + _rng.randf_range(-12.0, 12.0), 0.4)
		_cluster(shine, _local(p, -0.1), _rng.randf_range(0.5, 1.0), 3 + _rng.randi() % 3)
	for k in 5:
		var p := _by_wall(HOARD, 6.5, 180.0 + k * 45.0, 0.4)
		_cluster(shine, _local(p, -0.1), _rng.randf_range(0.7, 1.2), 4)
	_cluster(shine, _local(HOARD + Vector2(0, -3.4), -0.2), 2.0, 7)    # the great crystal behind the hoard
	_cluster(shine, _local(Vector2(POOL.x - 1.8, POOL.y - 1.4), -0.1), 0.7, 4)
	for k in 7:                                       # glowcaps on the den floor
		var p := _by_wall(DEN, 8.0, k * 52.0, 0.6)
		_mushrooms(fungus, _local(p), 2 + _rng.randi() % 3)
	for k in 14:                                      # gnawed bones round the den
		var p := DEN + Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0))
		var yaw := _rng.randf() * TAU
		var half := Vector3(cos(yaw), 0.0, sin(yaw)) * _rng.randf_range(0.2, 0.4)
		_prism(rock, _local(p, 0.05) - half, _local(p, 0.05) + half, 0.05, 4, Color(0.82, 0.78, 0.68))
	var plinth := _local(HOARD)                        # a stepped stone for the hoard
	_prism(rock, plinth - Vector3(0, 0.3, 0), plinth + Vector3(0, 0.18, 0), 1.5, 6, Color(0.3, 0.3, 0.34))
	_prism(rock, plinth, plinth + Vector3(0, 0.36, 0), 1.05, 6, Color(0.36, 0.36, 0.41))
	_add_mesh(rock, _flat_mat(false, Color.BLACK))
	_add_mesh(shine, _flat_mat(true, CRYSTAL))
	_add_mesh(fungus, _flat_mat(true, FUNGUS))
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(POOL.z * 2.4, POOL.z * 2.4)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.05, 0.2, 0.28, 0.85)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.emission_enabled = true
	wm.emission = Color(0.05, 0.25, 0.35)
	wm.roughness = 0.05
	water.material_override = wm
	water.position = Vector3(POOL.x, -0.2, POOL.y)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_built.add_child(water)


func _add_mesh(st: SurfaceTool, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_built.add_child(mi)


func _flat_mat(glow: bool, color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9 if not glow else 0.35
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.45
	return m


## One triangle, turned to face away from `inside`, with its own flat normal.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	st.set_color(col)
	st.set_normal(n.normalized())
	for v in [a, b, c]:
		st.add_vertex(v)


## A faceted prism from `a` to `b` (a crystal shaft, a bone, a plinth), capped at both ends.
func _prism(st: SurfaceTool, a: Vector3, b: Vector3, r: float, sides: int, col: Color, tip := Vector3.INF) -> void:
	var axis := (b - a).normalized()
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var mid := (a + b) * 0.5
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	for i in sides:
		var ang := TAU * i / sides
		var off := (u * cos(ang) + v * sin(ang)) * r
		ring_a.append(a + off)
		ring_b.append(b + off)
	for i in sides:
		var j := (i + 1) % sides
		var shade := col * (0.85 + 0.3 * _rng.randf())
		shade.a = 1.0
		_tri(st, ring_a[i], ring_a[j], ring_b[i], shade, mid)
		_tri(st, ring_a[j], ring_b[j], ring_b[i], shade, mid)
		_tri(st, ring_a[i], ring_a[j], a, col * 0.7, mid)
		if tip == Vector3.INF:
			_tri(st, ring_b[i], ring_b[j], b, col * 1.1, mid)
		else:
			var lit := col.lightened(0.25 * _rng.randf())
			_tri(st, ring_b[i], ring_b[j], tip, lit, mid)


func _spike(st: SurfaceTool, at: Vector3, r: float, h: float, col: Color) -> void:
	var lean := Vector3(_rng.randf_range(-0.15, 0.15), 0.0, _rng.randf_range(-0.15, 0.15))
	_prism(st, at, at + Vector3(0, h * 0.25, 0), r, 5, col, at + Vector3(0, h, 0) + lean * h)


## A clump of crystal shafts leaning out from one spot.
func _cluster(st: SurfaceTool, at: Vector3, size: float, count: int) -> void:
	for k in count:
		var dir := Vector3(_rng.randf_range(-0.55, 0.55), 1.0, _rng.randf_range(-0.55, 0.55)).normalized()
		if k == 0:
			dir = Vector3(0, 1, 0)
		var base := at + Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3)) * size
		var length := size * (1.6 if k == 0 else _rng.randf_range(0.6, 1.2))
		var col := CRYSTAL.lerp(Color(0.3, 0.55, 0.95), _rng.randf() * 0.7)
		_prism(st, base, base + dir * length * 0.72, length * 0.17, 6, col, base + dir * length)


func _mushrooms(st: SurfaceTool, at: Vector3, count: int) -> void:
	for k in count:
		var p := at + Vector3(_rng.randf_range(-0.35, 0.35), 0.0, _rng.randf_range(-0.35, 0.35))
		var h := _rng.randf_range(0.18, 0.4)
		_prism(st, p, p + Vector3(0, h, 0), 0.035, 5, Color(0.75, 0.85, 0.72))
		var cap := p + Vector3(0, h, 0)
		_prism(st, cap - Vector3(0, 0.02, 0), cap + Vector3(0, 0.04, 0), h * 0.42, 6, FUNGUS, cap + Vector3(0, h * 0.35, 0))


## The way out: daylight at the end of the first tunnel, with faint shafts of it falling in.
func _build_exit() -> void:
	var sky := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(4.0, 3.2)
	sky.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.93, 0.76)
	sky.material_override = m
	sky.position = Vector3(0, 1.5, 10.6)
	sky.rotation.y = PI
	_built.add_child(sky)
	for k in 2:
		var ray := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.4, 5.5)
		ray.mesh = q
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rm.albedo_color = Color(1.0, 0.85, 0.6, 0.1)
		rm.cull_mode = BaseMaterial3D.CULL_DISABLED
		ray.material_override = rm
		ray.position = Vector3(-0.7 + k * 1.3, 1.4, 7.8)
		ray.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(-8.0 + k * 16.0), 0)
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_built.add_child(ray)


func _build_lights() -> void:
	_light(Vector3(0, 1.8, 8.6), Color(1.0, 0.86, 0.62), 2.5, 8.0)          # daylight at the mouth
	_light(_local(HALL + Vector2(-2.5, -1.5), 2.2), CRYSTAL, 3.0, 10.0)
	_light(_local(HALL + Vector2(3.0, 2.5), 2.0), CRYSTAL, 2.2, 8.0)
	_light(_local(DEN, 1.6), FUNGUS, 1.8, 10.0)
	_light(_local(HOARD + Vector2(0, -2.2), 2.6), CRYSTAL, 3.5, 11.0)


func _light(at: Vector3, col: Color, energy: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.4
	l.position = at
	_built.add_child(l)


## Things to mine and pick: crystal veins in the hall (shards), iron in the den, copper by the entrance,
## glowcaps by the pool.
func _build_gatherables() -> void:
	var spots := [["crystal_vein", HALL, 6.5, 200.0], ["crystal_vein", HALL, 6.5, 300.0], ["crystal_vein", HALL, 6.5, 60.0],
		["iron_rock", DEN, 7.5, 330.0], ["iron_rock", DEN, 7.5, 150.0],
		["copper_rock", Vector2(0, 0), 5.0, 200.0], ["copper_rock", Vector2(0, 0), 5.0, 330.0],
		["glowcap_patch", Vector2(POOL.x, POOL.y), 3.5, 90.0], ["glowcap_patch", DEN, 7.5, 240.0]]
	for s: Array in spots:
		var p := _by_wall(s[1], s[2], s[3], 1.3)
		var at := AT + _local(p)
		match String(s[0]):
			"iron_rock", "copper_rock":
				var model := "ore_iron" if s[0] == "iron_rock" else "ore_copper"
				visuals.add_gatherable(scatter.make_single(_loose, model, "rock", at, 0.8, s[0]))
			_:
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				var mesh := ArrayMesh.new()
				if s[0] == "crystal_vein":                 # a stone base (not glowing) under the crystals
					var base := SurfaceTool.new()
					base.begin(Mesh.PRIMITIVE_TRIANGLES)
					_prism(base, Vector3(0, -0.2, 0), Vector3(0, 0.25, 0), 0.75, 6, Color(0.42, 0.42, 0.47))
					base.commit(mesh)
					mesh.surface_set_material(0, _flat_mat(false, Color.BLACK))
					_cluster(st, Vector3(0, 0.15, 0), 0.75, 5)
				else:
					_mushrooms(st, Vector3.ZERO, 5)
				st.commit(mesh)
				mesh.surface_set_material(mesh.get_surface_count() - 1, _flat_mat(true, CRYSTAL if s[0] == "crystal_vein" else FUNGUS))
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mesh
				mm.instance_count = 1
				var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), at)
				mm.set_instance_transform(0, xf)
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				_loose.add_child(mmi)
				visuals.add_gatherable({"type": s[0], "xf": xf, "multimesh": mm, "index": 0, "collider": null, "scale": 1.0})


## The den: two grey wolves and a shadow wolf.
func _spawn_wolves() -> void:
	for k in 3:
		var wolf := WOLF.instantiate() as Wolf
		wolf.player = player
		wolf.shadow = k == 2
		wolf.home = AT + _local(DEN)
		_built.add_child(wolf)
		wolf.global_position = AT + _local(DEN + Vector2(k * 1.6 - 1.6, k * 0.8), 0.5)
