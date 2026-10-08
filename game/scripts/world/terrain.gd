extends StaticBody3D
## Builds the ground mesh, its collision, the pond water and the edge walls from WorldShape.

const STEP := 2.0            # big triangles: the faceted low-poly look
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const SEA_SHADER := preload("res://shaders/sea.gdshader")

# Ground colours (sRGB).
const GRASS_LIGHT := Color(0.58, 0.68, 0.38)
const GRASS_DARK := Color(0.36, 0.52, 0.30)
const ROCK := Color(0.47, 0.46, 0.42)
# The forest floor: mossy and darker.
const MOSS_LIGHT := Color(0.44, 0.55, 0.30)
const MOSS_DARK := Color(0.25, 0.38, 0.24)

var material: ShaderMaterial


func build(shape: WorldShape) -> void:
	var n := int(WorldShape.HALF_SIZE * 2.0 / STEP) + 1
	var start := -WorldShape.HALF_SIZE
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for iz in n:
		for ix in n:
			heights[iz * n + ix] = shape.height_at(start + ix * STEP, start + iz * STEP)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	for iz in n:
		for ix in n:
			var i := iz * n + ix
			var x := start + ix * STEP
			var z := start + iz * STEP
			var hl := heights[iz * n + maxi(ix - 1, 0)]
			var hr := heights[iz * n + mini(ix + 1, n - 1)]
			var hu := heights[maxi(iz - 1, 0) * n + ix]
			var hd := heights[mini(iz + 1, n - 1) * n + ix]
			var nrm := Vector3(hl - hr, 2.0 * STEP, hu - hd).normalized()
			verts[i] = Vector3(x, heights[i], z)
			normals[i] = nrm
			colors[i] = _ground_color(shape, x, z, heights[i], nrm.y).srgb_to_linear()

	var indices := PackedInt32Array()
	for iz in n - 1:
		for ix in n - 1:
			var a := iz * n + ix
			indices.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	material = ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter("cloud_noise", _cloud_texture())
	material.set_shader_parameter("path_points", WorldShape.path)
	material.set_shader_parameter("path_count", WorldShape.path.size())
	material.set_shader_parameter("pond_center", WorldShape.POND_CENTER)
	material.set_shader_parameter("pond_radius", WorldShape.POND_RADIUS)
	material.set_shader_parameter("water_y", WorldShape.WATER_Y)
	if WorldShape.coast:                       # Sunreach: sun-bleached path, warm sand patches
		material.set_shader_parameter("dirt_color", Color(0.86, 0.74, 0.55))
		material.set_shader_parameter("dirt_edge", Color(0.74, 0.6, 0.42))
		material.set_shader_parameter("patch_warm", Color(0.95, 0.74, 0.46))
		material.set_shader_parameter("patch_cool", Color(0.78, 0.68, 0.52))
		material.set_shader_parameter("sand_color", Color(0.9, 0.8, 0.58))
	mesh.surface_set_material(0, material)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	hm.map_data = heights
	var col := CollisionShape3D.new()
	col.shape = hm
	col.scale = Vector3(STEP, 1.0, STEP)
	add_child(col)

	_build_walls()
	_build_water()
	if WorldShape.coast:
		_build_sea(shape, heights, n)


## Grass shades and rock on steep slopes. The path and pond shore are drawn by the shader,
## per pixel, so their edges stay crisp.
## Bakes soft shade under trees, rocks and bushes into a small ground texture.
func bake_shade(spots: Array[Vector4]) -> void:
	const RES := 512                 # ~2 px per metre over the whole ground (sharper shade under trees)
	var px := RES / (WorldShape.HALF_SIZE * 2.0)     # pixels per metre
	var data := PackedByteArray()
	data.resize(RES * RES)
	data.fill(255)
	for s in spots:
		var cx := (s.x + WorldShape.HALF_SIZE) * px
		var cy := (s.y + WorldShape.HALF_SIZE) * px
		var r := s.z * px
		for y in range(maxi(0, int(cy - r)), mini(RES, int(cy + r) + 1)):
			for x in range(maxi(0, int(cx - r)), mini(RES, int(cx + r) + 1)):
				var d := Vector2(x - cx, y - cy).length() / r
				if d >= 1.0:
					continue
				var shade := 1.0 - s.w * (1.0 - smoothstep(0.0, 1.0, d))
				var i := y * RES + x
				data[i] = mini(data[i], int(shade * 255.0))
	var img := Image.create_from_data(RES, RES, false, Image.FORMAT_L8, data)
	material.set_shader_parameter("shade_map", ImageTexture.create_from_image(img))
	material.set_shader_parameter("world_half", WorldShape.HALF_SIZE)


func _ground_color(shape: WorldShape, x: float, z: float, h: float, up: float) -> Color:
	if WorldShape.coast:
		return _sand_color(shape, x, z, h, up)
	if WorldShape.region == "highlands":
		return _highland_color(shape, x, z, h, up)
	var forest := WorldShape.region == "forest"
	var c := (MOSS_DARK if forest else GRASS_DARK).lerp(MOSS_LIGHT if forest else GRASS_LIGHT, shape.meadow_noise(x, z))
	return c.lerp(ROCK, smoothstep(0.86, 0.72, up))


## The highlands: ochre grass with patches of heather, bare grey rock on every slope, snow up high.
func _highland_color(shape: WorldShape, x: float, z: float, h: float, up: float) -> Color:
	var n := shape.meadow_noise(x, z)
	# Green in the hollows, gold and ochre on the rises.
	var c := Color(0.38, 0.5, 0.27).lerp(Color(0.74, 0.62, 0.33), clampf(smoothstep(-1.0, 6.0, h) * 0.75 + (n - 0.5) * 0.6, 0.0, 1.0))
	# Bold heather patches.
	c = c.lerp(Color(0.52, 0.28, 0.5), 0.75 * smoothstep(0.58, 0.74, shape.meadow_noise(x * 1.7 + 90.0, z * 1.7)) * smoothstep(9.0, 6.0, h))
	c = c.lerp(Color(0.48, 0.47, 0.5), smoothstep(0.93, 0.76, up))
	# Snow with a ragged edge, blue in its hollows.
	var snow := Color(0.82, 0.87, 0.95).lerp(Color(0.97, 0.98, 1.0), n)
	return c.lerp(snow, smoothstep(7.8, 9.6, h + (n - 0.5) * 3.0) * smoothstep(0.6, 0.82, up))


## Sunreach: pale gold sand with rippled dunes, green round the oasis, banded ochre and rust on the
## mesas, wet dark sand at the waterline.
func _sand_color(shape: WorldShape, x: float, z: float, h: float, up: float) -> Color:
	var n := shape.meadow_noise(x, z)
	var c := Color(0.93, 0.8, 0.56).lerp(Color(0.86, 0.66, 0.42), n)
	var oasis := 1.0 - smoothstep(WorldShape.POND_RADIUS + 3.0, WorldShape.POND_RADIUS + 11.0, shape.pond_distance(Vector2(x, z)))
	c = c.lerp(Color(0.46, 0.6, 0.3), oasis * 0.85)
	var band := fposmod(h * 0.62, 1.0)
	var rock := Color(0.78, 0.46, 0.28).lerp(Color(0.9, 0.66, 0.42), smoothstep(0.3, 0.7, band)).lerp(Color(0.62, 0.32, 0.22), smoothstep(0.85, 1.0, band))
	c = c.lerp(rock, smoothstep(0.88, 0.7, up) * smoothstep(1.5, 4.0, h))
	c = c.lerp(Color(0.66, 0.55, 0.4), 1.0 - smoothstep(0.0, 0.5, h))        # wet sand
	return c.lerp(Color(0.55, 0.62, 0.55), 1.0 - smoothstep(-1.2, -0.3, h))   # under the water


func _cloud_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	return tex


func _build_walls() -> void:
	var half := WorldShape.PLAY_HALF
	for side in [Vector3(half, 0, 0), Vector3(-half, 0, 0), Vector3(0, 0, half), Vector3(0, 0, -half)]:
		var box := BoxShape3D.new()
		box.size = Vector3(1.0 if side.x != 0.0 else half * 2.0, 60.0, 1.0 if side.z != 0.0 else half * 2.0)
		var col := CollisionShape3D.new()
		col.shape = box
		col.position = side
		add_child(col)


func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (WorldShape.POND_RADIUS * 2.0 + 10.0)
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("center", WorldShape.POND_CENTER)
	mat.set_shader_parameter("radius", WorldShape.POND_RADIUS)
	plane.material = mat
	var water := MeshInstance3D.new()
	water.mesh = plane
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(WorldShape.POND_CENTER.x, WorldShape.WATER_Y, WorldShape.POND_CENTER.y)
	add_child(water)


## The sea round Sunreach: one big plane out to the horizon, coloured by how deep the water is (a baked
## map), and walls a little way out from the beach so you wade but never walk off the sea floor.
func _build_sea(shape: WorldShape, heights: PackedFloat32Array, n: int) -> void:
	var data := PackedByteArray()
	data.resize(n * n)
	for i in n * n:
		data[i] = int(clampf((WorldShape.WATER_Y - heights[i]) / 6.0, 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(n, n, false, Image.FORMAT_L8, data)
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	plane.subdivide_width = 110
	plane.subdivide_depth = 110
	var mat := ShaderMaterial.new()
	mat.shader = SEA_SHADER
	mat.set_shader_parameter("depth_map", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("use_depth", true)
	mat.set_shader_parameter("world_half", WorldShape.HALF_SIZE)
	mat.set_shader_parameter("swell", 0.22)
	plane.material = mat
	var sea := MeshInstance3D.new()
	sea.mesh = plane
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position = Vector3(0, WorldShape.WATER_Y, 0)
	add_child(sea)
	# Walls where the water gets chest deep (a gap for the pier: world/sunreach.gd builds its rails).
	var last := Vector3.INF
	var x := -WorldShape.PLAY_HALF
	while x <= WorldShape.PLAY_HALF:
		var z := WorldShape.shore_z(x)
		while z < WorldShape.PLAY_HALF + 40.0 and shape.height_at(x, z) > WorldShape.WATER_Y - 1.0:
			z += 1.0
		var p := Vector3(x, 0, z)
		if last != Vector3.INF and not (absf(x - 12.0) < 3.5 and absf(last.x - 12.0) < 3.5):
			var box := BoxShape3D.new()
			box.size = Vector3(0.6, 40.0, last.distance_to(p) + 0.6)
			var col := CollisionShape3D.new()
			col.shape = box
			col.transform = Transform3D(Basis.looking_at(p - last, Vector3.UP), (last + p) * 0.5)
			add_child(col)
		last = p
		x += 3.0
