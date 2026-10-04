extends StaticBody3D
## Builds the ground mesh, its collision, the pond water and the edge walls from WorldShape.

const STEP := 2.0            # big triangles: the faceted low-poly look
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")

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
	if WorldShape.region == "highlands":
		return _highland_color(shape, x, z, h, up)
	var forest := WorldShape.region == "forest"
	var c := (MOSS_DARK if forest else GRASS_DARK).lerp(MOSS_LIGHT if forest else GRASS_LIGHT, shape.meadow_noise(x, z))
	return c.lerp(ROCK, smoothstep(0.86, 0.72, up))


## The highlands: ochre grass with patches of heather, bare grey rock on every slope, snow up high.
func _highland_color(shape: WorldShape, x: float, z: float, h: float, up: float) -> Color:
	var n := shape.meadow_noise(x, z)
	var c := Color(0.5, 0.52, 0.3).lerp(Color(0.68, 0.62, 0.38), n)
	c = c.lerp(Color(0.5, 0.36, 0.5), 0.55 * smoothstep(0.62, 0.8, shape.meadow_noise(x * 1.7 + 90.0, z * 1.7)))
	c = c.lerp(Color(0.5, 0.5, 0.52), smoothstep(0.93, 0.78, up))
	return c.lerp(Color(0.92, 0.94, 0.97), smoothstep(8.0, 10.5, h) * smoothstep(0.55, 0.8, up))


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
