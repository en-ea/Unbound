extends StaticBody3D
## Builds the ground mesh, its collision, the pond water and the edge walls from WorldShape.

const STEP := 1.0
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")

# Ground colours (sRGB).
const GRASS_LIGHT := Color(0.58, 0.68, 0.38)
const GRASS_DARK := Color(0.36, 0.52, 0.30)
const ROCK := Color(0.47, 0.46, 0.42)

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
	add_child(col)

	_build_walls()
	_build_water()


## Grass shades and rock on steep slopes. The path and pond shore are drawn by the shader,
## per pixel, so their edges stay crisp.
func _ground_color(shape: WorldShape, x: float, z: float, _h: float, up: float) -> Color:
	var c := GRASS_DARK.lerp(GRASS_LIGHT, shape.meadow_noise(x, z))
	return c.lerp(ROCK, smoothstep(0.86, 0.72, up))


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
