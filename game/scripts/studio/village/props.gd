extends RefCounted
## Props for the village's public acts (a pillory, stocks, a stake, gallows, a shrine, a notice board)
## and things a crowd throws (cabbage, turnip, mud, stone). Placeholders in the game's own low-poly look,
## built in code until they get proper models.
##
## Each prop is ONE MeshInstance3D: its pieces (boxes, prisms, lumpy balls) are welded into one ArrayMesh
## with flat faces, drawn with the solid shader the characters and trees use (foliage_solid.gdshader:
## colour x per-face shade, lighter on top, soft rim). As in VillagerBody the colour rides in the shade
## UVs, so every prop shares one white material: a prop costs one draw call and one for its shadow.
## Meshes are made once per kind and shared (fifty cabbages are fifty instances of one mesh).
##
## Origins are on the ground, props face +Z (the crowd's side); VICTIM says where a body goes.

const SHADER := preload("res://shaders/foliage_solid.gdshader")

## Wood, rope and stone in the tones places.gd and the village use.
const WOOD := Color(0.55, 0.37, 0.23)
const DARK_WOOD := Color(0.38, 0.26, 0.18)
const PALE_WOOD := Color(0.68, 0.52, 0.34)
const IRON := Color(0.3, 0.3, 0.32)
const HOLE := Color(0.12, 0.09, 0.07)
const ROPE := Color(0.74, 0.64, 0.44)
const STONE := Color(0.66, 0.64, 0.6)
const DARK_STONE := Color(0.5, 0.49, 0.47)
const PAPER := Color(0.93, 0.89, 0.76)

## Where the one being punished stands or sits: the body's origin (its feet), relative to the prop's
## origin, facing +Z, in the pose VICTIM_POSE names (the stage plays it; the numbers are measured on the
## rig in that pose, so the two go together):
## pillory: on the platform, bent forward on the board (Idle_Rail: the neck drops to 1.33-1.38 m and leads
##   the feet by 0.3 m), the neck through the hole and the face just out in front of the board;
## stocks: sitting (Sitting_Idle: hips 0.33 m behind the feet, seat ~0.44 m) with the hips over the log;
## stake: standing on the board, back to the post;
## gallows: on the trapdoor, under the noose (a little forward of it, so a fall backwards stays on the deck).
const VICTIM := {
	"pillory": Vector3(0.0, 0.3, 0.1),
	"stocks": Vector3(0.0, 0.0, -0.29),
	"stake": Vector3(0.0, 0.5, 0.22),
	"gallows": Vector3(0.45, 1.2, 0.25),
}
const VICTIM_POSE := {"pillory": "Idle_Rail", "stocks": "Sitting_Idle", "stake": "Idle", "gallows": "Idle"}
## The pillory's holes (neck in the middle, wrists either side): at the neck of a body bent forward in
## VICTIM_POSE on the platform (0.3 m).
const PILLORY_HOLES := 1.66

static var _meshes := {}        # prop name -> ArrayMesh
static var _material: ShaderMaterial


## A post on a low platform with the two-part board at neck height: holes for the neck and both wrists.
static func pillory() -> Node3D:
	return _prop("pillory", func(k: Kit) -> void:
		k.box(Vector3(0, 0.15, -0.2), Vector3(1.5, 0.3, 1.3), DARK_WOOD)         # platform
		k.box(Vector3(0, 0.08, 0.6), Vector3(0.7, 0.16, 0.3), DARK_WOOD)         # a step up
		var y := PILLORY_HOLES
		k.box(Vector3(0, (0.3 + y + 0.4) / 2.0, 0), Vector3(0.16, y + 0.1, 0.16), WOOD)      # post
		k.box(Vector3(0, y - 0.09, 0.1), Vector3(1.2, 0.18, 0.08), PALE_WOOD)    # lower half of the board
		k.box(Vector3(0, y + 0.09, 0.1), Vector3(1.2, 0.18, 0.08), PALE_WOOD)    # upper half (it lifts)
		for x in [-0.36, 0.0, 0.36]:                                             # wrist, neck, wrist
			var r := 0.075 if x == 0.0 else 0.045
			k.prism(Vector3(x, y, 0.145), r, 0.012, HOLE, 8, Basis(Vector3.RIGHT, PI / 2.0))
			k.prism(Vector3(x, y, 0.055), r, 0.012, HOLE, 8, Basis(Vector3.RIGHT, PI / 2.0))
		k.box(Vector3(-0.62, y, 0.1), Vector3(0.05, 0.4, 0.1), IRON)             # hinge
		k.box(Vector3(0.62, y, 0.1), Vector3(0.05, 0.12, 0.11), IRON)            # hasp
		k.box(Vector3(0, y + 0.44, 0), Vector3(0.24, 0.08, 0.24), DARK_WOOD))     # cap


## A low frame for sitting in: two uprights, the ankle board, and a log to sit on behind it.
static func stocks() -> Node3D:
	return _prop("stocks", func(k: Kit) -> void:
		for x in [-0.62, 0.62]:
			k.box(Vector3(x, 0.3, 0), Vector3(0.12, 0.6, 0.14), WOOD)            # uprights
			k.box(Vector3(x, 0.04, 0), Vector3(0.2, 0.08, 0.4), DARK_WOOD)       # their feet
		k.box(Vector3(0, 0.21, 0), Vector3(1.3, 0.18, 0.1), PALE_WOOD)           # lower half of the board
		k.box(Vector3(0, 0.4, 0), Vector3(1.3, 0.18, 0.1), PALE_WOOD)            # upper half
		for x in [-0.14, 0.14]:                                                   # ankle holes
			for z in [0.051, -0.051]:
				k.prism(Vector3(x, 0.305, z), 0.05, 0.01, HOLE, 8, Basis(Vector3.RIGHT, PI / 2.0))
		k.box(Vector3(0.66, 0.305, 0), Vector3(0.04, 0.1, 0.12), IRON)           # hasp
		k.prism(Vector3(0, 0.2, -0.62), 0.2, 1.0, DARK_WOOD, 7, Basis(Vector3.FORWARD, PI / 2.0)))   # log seat


## A tall post with a rope round its middle, standing in a pile of logs and brushwood.
static func stake() -> Node3D:
	return _prop("stake", func(k: Kit) -> void:
		k.prism(Vector3(0, 1.4, 0), 0.1, 2.8, WOOD, 7)                         # post
		for y in [1.15, 1.25]:                                                  # rope turns
			k.prism(Vector3(0, y, 0), 0.115, 0.05, ROPE, 7)
		k.box(Vector3(0, 0.46, 0.2), Vector3(0.5, 0.08, 0.36), DARK_WOOD)       # a board to stand on
		for i in range(2, 11):                                                  # logs leaning on the post, a gap in front
			var a := i * TAU / 12.0
			var lean := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.6)
			var at := Vector3(sin(a), 0.0, cos(a)) * 0.36 + Vector3(0, 0.42, 0)
			k.prism(at, 0.065, 1.0, WOOD if i % 3 else DARK_WOOD, 6, lean)
		for i in 9:                                                             # brushwood round the foot
			var a := (i + 0.5) * TAU / 9.0
			var lie := Basis(Vector3.UP, a + 0.4) * Basis(Vector3.RIGHT, PI / 2.0 - 0.25)
			k.prism(Vector3(sin(a), 0.0, cos(a)) * 0.78 + Vector3(0, 0.12, 0), 0.035, 0.7, PALE_WOOD, 5, lie))


## A raised platform with steps and a trapdoor; a post, beam and brace; a rope ending in a noose.
static func gallows() -> Node3D:
	return _prop("gallows", func(k: Kit) -> void:
		k.box(Vector3(0, 1.12, 0), Vector3(2.4, 0.16, 2.0), DARK_WOOD)          # deck
		for x in [-1.1, 1.1]:
			for z in [-0.9, 0.9]:
				k.box(Vector3(x, 0.52, z), Vector3(0.16, 1.04, 0.16), WOOD)    # legs
		k.box(Vector3(0, 0.55, 0.92), Vector3(2.3, 0.1, 0.06), WOOD)            # rails between the legs
		k.box(Vector3(0, 0.55, -0.92), Vector3(2.3, 0.1, 0.06), WOOD)
		for i in 4:                                                             # steps up the front
			k.box(Vector3(-0.6, 0.14 + i * 0.26, 1.72 - i * 0.2), Vector3(0.8, 0.08, 0.3), WOOD)
		for x in [-1.03, -0.17]:                                                # the steps' side boards
			k.box(Vector3(x, 0.56, 1.45), Vector3(0.06, 1.5, 0.14), DARK_WOOD, Basis(Vector3.RIGHT, -0.675))
		k.box(Vector3(0.45, 1.205, 0), Vector3(0.8, 0.02, 0.8), HOLE)           # the trapdoor's gap
		k.box(Vector3(0.45, 1.21, 0), Vector3(0.74, 0.03, 0.74), WOOD)          # the trapdoor
		k.box(Vector3(-0.95, 2.72, 0), Vector3(0.2, 3.0, 0.2), WOOD)            # post
		k.box(Vector3(-0.2, 4.1, 0), Vector3(1.7, 0.18, 0.18), WOOD)            # beam
		k.box(Vector3(-0.6, 3.72, 0), Vector3(0.1, 0.9, 0.1), DARK_WOOD, Basis(Vector3.BACK, -PI / 4.0))   # brace
		k.box(Vector3(0.45, 3.62, 0), Vector3(0.03, 0.8, 0.03), ROPE)           # rope
		for i in 8:                                                             # the noose's loop
			var a := i * TAU / 8.0
			k.box(Vector3(0.45 + cos(a) * 0.1, 3.1 + sin(a) * 0.12, 0), Vector3(0.035, 0.1, 0.035), ROPE, Basis(Vector3.BACK, a))
		k.box(Vector3(0.45, 3.24, 0), Vector3(0.06, 0.08, 0.06), ROPE))        # the knot


## A wayside shrine: a stone plinth, a post and a small roofed box with an idol and a candle.
static func shrine() -> Node3D:
	return _prop("shrine", func(k: Kit) -> void:
		k.box(Vector3(0, 0.12, 0), Vector3(0.9, 0.24, 0.9), DARK_STONE)         # plinth
		k.box(Vector3(0, 0.3, 0), Vector3(0.7, 0.12, 0.7), STONE)
		k.box(Vector3(0, 0.75, 0), Vector3(0.18, 0.8, 0.18), WOOD)              # post
		k.box(Vector3(0, 1.3, 0), Vector3(0.56, 0.5, 0.42), PALE_WOOD)          # the little house
		k.box(Vector3(0, 1.28, 0.2), Vector3(0.36, 0.34, 0.04), HOLE)           # its opening
		k.box(Vector3(0, 1.07, 0.27), Vector3(0.5, 0.04, 0.16), WOOD)           # a ledge in front of it
		k.prism(Vector3(0, 1.17, 0.28), 0.045, 0.16, Color(0.9, 0.78, 0.4), 6)  # the idol
		k.blob(Vector3(0, 1.28, 0.28), Vector3(0.045, 0.045, 0.045), Color(0.9, 0.78, 0.4), 0.0, 1)
		k.prism(Vector3(0.16, 1.13, 0.29), 0.018, 0.08, Color(0.95, 0.92, 0.8), 5)   # a candle
		for side in [-1.0, 1.0]:                                                # roof
			k.box(Vector3(side * 0.17, 1.66, 0), Vector3(0.44, 0.05, 0.6), Color(0.62, 0.3, 0.22), Basis(Vector3.BACK, side * -0.62))
		for i in 3:                                                             # offerings on the plinth
			var c: Color = [Color(0.86, 0.3, 0.3), Color(0.95, 0.85, 0.4), Color(0.7, 0.5, 0.85)][i]
			k.blob(Vector3(-0.22 + i * 0.22, 0.38, 0.26), Vector3(0.05, 0.035, 0.05), c, 0.2, 10 + i))


## Two posts, a board with notices pinned to it, and a little roof.
static func notice_board() -> Node3D:
	return _prop("notice_board", func(k: Kit) -> void:
		for x in [-0.62, 0.62]:
			k.box(Vector3(x, 1.0, 0), Vector3(0.12, 2.0, 0.12), WOOD)           # posts
		k.box(Vector3(0, 1.35, 0), Vector3(1.4, 0.9, 0.06), PALE_WOOD)          # board
		k.box(Vector3(0, 0.88, 0.02), Vector3(1.4, 0.06, 0.08), DARK_WOOD)      # its frame, top and bottom
		k.box(Vector3(0, 1.82, 0.02), Vector3(1.4, 0.06, 0.08), DARK_WOOD)
		var notes := [[Vector3(-0.38, 1.46, 0.035), Vector2(0.34, 0.44), 0.06], [Vector3(0.05, 1.32, 0.035), Vector2(0.3, 0.38), -0.05],
			[Vector3(0.43, 1.5, 0.035), Vector2(0.28, 0.32), 0.1], [Vector3(-0.1, 1.64, 0.04), Vector2(0.22, 0.18), -0.12]]
		for n: Array in notes:                                                  # the notices
			var size: Vector2 = n[1]
			k.box(n[0], Vector3(size.x, size.y, 0.008), PAPER, Basis(Vector3.BACK, n[2]))
			k.box((n[0] as Vector3) + Vector3(0, size.y * 0.4, 0.006), Vector3(0.025, 0.025, 0.01), IRON)   # nail
		for side in [-1.0, 1.0]:                                                # roof
			k.box(Vector3(0, 2.02, side * 0.12), Vector3(1.6, 0.04, 0.3), DARK_WOOD, Basis(Vector3.RIGHT, side * 0.5)))


## About 0.22 m across: a round head in layered greens, outer leaves curling off it.
static func cabbage() -> Node3D:
	return _prop("cabbage", func(k: Kit) -> void:
		k.blob(Vector3(0, 0.1, 0), Vector3(0.09, 0.085, 0.09), Color(0.62, 0.78, 0.4), 0.08, 3)
		for i in 5:                                                             # outer leaves
			var a := i * TAU / 5.0
			var tilt := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.5)
			k.box(Vector3(sin(a), 0, cos(a)) * 0.07 + Vector3(0, 0.08, 0), Vector3(0.12, 0.1, 0.012), Color(0.42, 0.62, 0.3), tilt))


## About 0.2 m tall: a purple-topped white bulb, a thin root and a tuft of leaves.
static func turnip() -> Node3D:
	return _prop("turnip", func(k: Kit) -> void:
		k.blob(Vector3(0, 0.07, 0), Vector3(0.06, 0.055, 0.06), Color(0.93, 0.9, 0.82), 0.06, 4)
		k.blob(Vector3(0, 0.1, 0), Vector3(0.055, 0.035, 0.055), Color(0.62, 0.3, 0.56), 0.06, 5)
		k.prism(Vector3(0, 0.02, 0), 0.02, 0.04, Color(0.9, 0.86, 0.78), 5, Basis.IDENTITY, 0.0, true)   # root, pointing down
		for i in 3:                                                             # leaves
			var a := i * TAU / 3.0
			k.box(Vector3(sin(a) * 0.015, 0.16, cos(a) * 0.015), Vector3(0.03, 0.1, 0.008), Color(0.36, 0.6, 0.28), Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.35)))


## About 0.2 m across: a flattened, lumpy clod of wet earth.
static func mud() -> Node3D:
	return _prop("mud", func(k: Kit) -> void:
		k.blob(Vector3(0, 0.045, 0), Vector3(0.1, 0.045, 0.085), Color(0.32, 0.23, 0.16), 0.3, 6)
		k.blob(Vector3(0.04, 0.07, -0.02), Vector3(0.045, 0.03, 0.04), Color(0.38, 0.27, 0.18), 0.3, 7))


## About 0.15 m across: an irregular grey stone.
static func stone() -> Node3D:
	return _prop("stone", func(k: Kit) -> void:
		k.blob(Vector3(0, 0.05, 0), Vector3(0.075, 0.05, 0.065), DARK_STONE, 0.25, 8))


## Every prop, by name (for line-ups and the stage).
static func all() -> Dictionary:
	return {"pillory": pillory, "stocks": stocks, "stake": stake, "gallows": gallows, "shrine": shrine,
		"notice_board": notice_board, "cabbage": cabbage, "turnip": turnip, "mud": mud, "stone": stone}


static func _prop(prop_name: String, build: Callable) -> Node3D:
	if not _meshes.has(prop_name):
		var k := Kit.new()
		build.call(k)
		_meshes[prop_name] = k.mesh(_shared_material())
	var mi := MeshInstance3D.new()
	mi.name = prop_name.to_pascal_case()
	mi.mesh = _meshes[prop_name]
	return mi


static func _shared_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("sway", 0.0)
		_material.set_shader_parameter("albedo", Color.WHITE)   # colours ride in the UVs
	return _material


## Collects flat-shaded triangles from simple convex pieces. Each piece's faces are turned to face
## away from its centre (so a piece can't come out inside-out), and each face gets a small shade step
## so neighbouring facets read apart, as on the characters.
class Kit:
	var _verts := PackedVector3Array()
	var _normals := PackedVector3Array()
	var _uv := PackedVector2Array()
	var _uv2 := PackedVector2Array()

	func box(centre: Vector3, size: Vector3, c: Color, basis := Basis.IDENTITY) -> void:
		var xf := Transform3D(basis, centre)
		var h := size / 2.0
		var p: Array[Vector3] = []
		for i in 8:
			p.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
		for f: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
			_quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], c, centre)

	## A prism of `sides` round an axis (local +Y) through `centre`, `height` long; top_radius < 0 keeps
	## it straight, 0 makes a cone. `down` points a cone's tip down instead of up.
	func prism(centre: Vector3, radius: float, height: float, c: Color, sides := 6, basis := Basis.IDENTITY, top_radius := -1.0, down := false) -> void:
		var xf := Transform3D(basis, centre)
		var r_top := radius if top_radius < 0.0 else top_radius
		var r_low := radius
		if down:
			r_low = r_top
			r_top = radius
		var low: Array[Vector3] = []
		var high: Array[Vector3] = []
		for i in sides:
			var a := i * TAU / sides
			low.append(xf * Vector3(cos(a) * r_low, -height / 2.0, sin(a) * r_low))
			high.append(xf * Vector3(cos(a) * r_top, height / 2.0, sin(a) * r_top))
		for i in sides:
			var j := (i + 1) % sides
			_quad(low[i], low[j], high[j], high[i], c, centre)
			if r_low > 0.0:
				_tri(xf * Vector3(0, -height / 2.0, 0), low[i], low[j], c, centre)
			if r_top > 0.0:
				_tri(xf * Vector3(0, height / 2.0, 0), high[j], high[i], c, centre)

	## A low-poly ball (5 rings of 7), stretched to `radii`, its points pushed in and out by up to
	## `lumpy` of the radius (seeded, so each kind of prop keeps its shape).
	func blob(centre: Vector3, radii: Vector3, c: Color, lumpy: float, shape_seed: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = shape_seed
		var rings := 5
		var segs := 7
		var top := centre + Vector3(0, radii.y * (1.0 + rng.randf_range(-lumpy, lumpy) * 0.5), 0)
		var bottom := centre - Vector3(0, radii.y * (1.0 + rng.randf_range(-lumpy, lumpy) * 0.5), 0)
		var grid: Array = []
		for r in range(1, rings):
			var row: Array[Vector3] = []
			var polar := PI * r / rings
			for s in segs:
				var az := TAU * (s + 0.5 * (r % 2)) / segs
				var d := Vector3(sin(polar) * cos(az), cos(polar), sin(polar) * sin(az))
				row.append(centre + d * radii * (1.0 + rng.randf_range(-lumpy, lumpy)))
			grid.append(row)
		for s in segs:
			var t := (s + 1) % segs
			_tri(top, grid[0][s], grid[0][t], c, centre)
			_tri(bottom, grid[rings - 2][t], grid[rings - 2][s], c, centre)
		for r in rings - 2:
			for s in segs:
				var t := (s + 1) % segs
				_quad(grid[r][s], grid[r + 1][s], grid[r + 1][t], grid[r][t], c, centre)

	func mesh(material: Material) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts
		arrays[Mesh.ARRAY_NORMAL] = _normals
		arrays[Mesh.ARRAY_TEX_UV] = _uv
		arrays[Mesh.ARRAY_TEX_UV2] = _uv2
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		m.surface_set_material(0, material)
		return m

	func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, centre: Vector3) -> void:
		var shade := _shade()
		_tri(a, b, c, col, centre, shade)
		_tri(a, c, d, col, centre, shade)

	## Godot draws clockwise faces: seen from outside, a -> b -> c turns clockwise, so the outward
	## normal is (c - a) x (b - a). A face whose normal points at the piece's centre is flipped.
	func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color, centre: Vector3, shade := -1.0) -> void:
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-14:
			return          # a degenerate sliver (a cone's tip)
		if n.dot((a + b + c) / 3.0 - centre) < 0.0:
			var swap := b
			b = c
			c = swap
			n = -n
		n = n.normalized()
		if shade < 0.0:
			shade = _shade()
		for v in [a, b, c]:
			_verts.append(v)
			_normals.append(n)
			_uv.append(Vector2(col.r * shade, col.g * shade))
			_uv2.append(Vector2(col.b * shade, 0.0))

	## A face's shade step, between 0.94 and 1.03, the same for the same face every time.
	func _shade() -> float:
		return 0.94 + 0.09 * float(hash(_verts.size()) % 1000) / 1000.0
