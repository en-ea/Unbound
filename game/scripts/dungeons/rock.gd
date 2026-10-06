extends RefCounted
## The rock of a dungeon (the same way Glimmerdeep is made, world/cave.gd): one height grid, low where the
## rooms and tunnels are and high in the rock round them, so the walls come out jagged and faceted, and the
## same grid is the collision. Any layout (dungeons/layout.gd) in any theme's colours (dungeons/themes.gd).
##   build(parent, layout, theme, seed)   makes the meshes and the collision under `parent` (local metres)
##   floor_at(x, z)  dist(p)  by_wall(centre, radius, angle)  spot(p, lift)   for placing things

const ROCK_SHADER := preload("res://shaders/cave_rock.gdshader")
const TOP := 2.6                         # how high the rock stands over the floor (plus up to a metre)

var rooms: Array = []                    # {at, r, role} (layout.gd)
var tunnels: Array = []                  # [a, b, half width]
var corner := Vector2.ZERO               # the grid's corner (x, z); one vertex a metre
var size := Vector2i.ZERO
var material: ShaderMaterial
var _heights := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _bumps := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _theme: Dictionary


func build(parent: Node3D, layout: Dictionary, theme: Dictionary, seed: int, floor_y: float) -> void:
	rooms = layout.rooms
	tunnels = layout.tunnels
	corner = layout.corner
	size = layout.size
	_theme = theme
	_rng.seed = seed
	_noise.seed = seed
	_noise.frequency = 0.11
	_bumps.seed = seed + 1
	_bumps.frequency = 0.35
	_heights.resize(size.x * size.y)
	for iz in size.y:
		for ix in size.x:
			_heights[iz * size.x + ix] = _height(Vector2(corner.x + ix, corner.y + iz))
	var verts := PackedVector3Array()
	verts.resize(size.x * size.y)
	for iz in size.y:
		for ix in size.x:
			var h := _heights[iz * size.x + ix]
			var wall := clampf(h / 0.8, 0.0, 1.0)            # rock moves about more than the floor
			var j := Vector2(_rng.randf_range(-0.38, 0.38), _rng.randf_range(-0.38, 0.38)) * lerpf(0.5, 1.0, wall)
			verts[iz * size.x + ix] = Vector3(corner.x + ix + j.x, h, corner.y + iz + j.y)
	material = ShaderMaterial.new()
	material.shader = ROCK_SHADER
	material.set_shader_parameter("floor_y", floor_y)
	var rows := 16                                   # in strips, so each only takes the lights near it
	for z0 in range(0, size.y - 1, rows):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for iz in range(z0, mini(z0 + rows, size.y - 1)):
			for ix in size.x - 1:
				var a := verts[iz * size.x + ix]
				var b := verts[iz * size.x + ix + 1]
				var c := verts[(iz + 1) * size.x + ix]
				var d := verts[(iz + 1) * size.x + ix + 1]
				if _rng.randf() < 0.5:
					_face(st, a, b, c)
					_face(st, b, d, c)
				else:
					_face(st, a, b, d)
					_face(st, a, d, c)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = size.x
	shape.map_depth = size.y
	shape.map_data = _heights
	col.shape = shape
	col.position = Vector3(corner.x + (size.x - 1) * 0.5, 0.0, corner.y + (size.y - 1) * 0.5)
	body.add_child(col)
	parent.add_child(body)


## How far a spot is outside the open dungeon (negative inside), with wobbly walls.
func dist(p: Vector2) -> float:
	var d := INF
	for r: Dictionary in rooms:
		d = minf(d, p.distance_to(r.at) - float(r.r))
	for t: Array in tunnels:
		d = minf(d, _seg(p, t[0], t[1]) - float(t[2]))
	return d + _noise.get_noise_2d(p.x, p.y) * 1.1


## The floor height at a spot (local x, z).
func floor_at(x: float, z: float) -> float:
	var fx := clampf(x - corner.x, 0.0, size.x - 1.001)
	var fz := clampf(z - corner.y, 0.0, size.y - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h0 := lerpf(_heights[iz * size.x + ix], _heights[iz * size.x + ix + 1], tx)
	var h1 := lerpf(_heights[(iz + 1) * size.x + ix], _heights[(iz + 1) * size.x + ix + 1], tx)
	return lerpf(h0, h1, tz)


func spot(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, floor_at(p.x, p.y) + lift, p.y)


## A spot near the wall of a room, `angle` degrees round from east, pulled in until it's clear floor.
func by_wall(centre: Vector2, radius: float, angle: float, clear := 1.2) -> Vector2:
	var dir := Vector2.from_angle(deg_to_rad(angle))
	var r := radius
	while r > 0.5 and dist(centre + dir * r) > -clear:
		r -= 0.25
	return centre + dir * r


func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0))


func _height(p: Vector2) -> float:
	var ground := _bumps.get_noise_2d(p.x, p.y) * 0.12
	var top := TOP + (_noise.get_noise_2d(p.x * 0.7 + 40.0, p.y * 0.7) * 0.5 + 0.5) * 1.0
	return lerpf(ground, top, smoothstep(-0.3, 0.8, dist(p)))


## One flat-shaded triangle, coloured by what it is: floor, wall or the rock's dark top (the theme's colours).
func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (c - a).cross(b - a).normalized()
	var mid := (a + b + c) / 3.0
	var vary := 0.92 + 0.16 * _rng.randf()
	var col: Color
	if mid.y > TOP - 0.1 and n.y > 0.75:
		col = _theme.top * vary
	elif n.y < 0.8 or mid.y > 0.35:
		col = (_theme.wall as Color).lerp(_theme.wall_high, clampf(mid.y / TOP, 0.0, 1.0)) * vary
	else:
		col = _theme.floor * vary
	st.set_color(col.srgb_to_linear())
	st.set_normal(n)
	for v in [a, b, c]:
		st.add_vertex(v)
