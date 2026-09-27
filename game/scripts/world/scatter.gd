extends Node3D
## Scatters the Quaternius nature models over the meadow.
## Each model is drawn with MultiMeshes split into chunks, so off-screen chunks are culled.

const NATURE := "res://assets/quaternius_nature/%s.gltf"
const OWN := "res://assets/nature/%s.glb"          # our own models (tools-src/blender/make_trees.py)
const FOLIAGE_SHADER := preload("res://shaders/foliage.gdshader")
const SOLID_FOLIAGE_SHADER := preload("res://shaders/foliage_solid.gdshader")
const CHUNK := 30.0
const TREE_CELL := 5.0      # grid cell for fast "is there a tree near here" checks
const GRASS_TINT := Color(0.72, 0.78, 0.64)   # the pack's grass is a bit neon

## Per model: cast shadows, visibility range (0 = always), wind sway (metres), sway height.
const KINDS := {
	"tree": {"shadow": true, "range": 0.0, "sway": 0.08, "sway_h": 6.0, "collide": 0.35},
	"bush": {"shadow": false, "range": 50.0, "sway": 0.04, "sway_h": 1.2, "collide": 0.0},
	"rock": {"shadow": true, "range": 0.0, "sway": 0.0, "sway_h": 1.0, "collide": 0.8},
	"small": {"shadow": false, "range": 36.0, "sway": 0.08, "sway_h": 1.2, "collide": 0.0},
	"ground": {"shadow": false, "range": 36.0, "sway": 0.0, "sway_h": 1.0, "collide": 0.0},
}

var _shape: WorldShape
var _rng := RandomNumberGenerator.new()
var _batches := {}         # "model|kind|cx|cz" -> Array[Transform3D]
var _meshes := {}          # "model|kind" -> Mesh with our materials
var _trees: Array[Vector2] = []
var _tree_grid := {}        # Vector2i cell -> Array[Vector2] of trees in it
var _colliders: StaticBody3D
var _pending_gatherables: Array[Dictionary] = []

## Filled by build(): one entry per gatherable thing, for ResourceVisuals.
## {type, xf: Transform3D, multimesh: MultiMesh, index: int, collider: CollisionShape3D, scale}
var gatherables: Array[Dictionary] = []


func build(shape: WorldShape) -> void:
	_shape = shape
	_rng.seed = 1234
	_colliders = StaticBody3D.new()
	add_child(_colliders)
	_scatter_trees()
	_scatter_landmarks()
	_scatter_path_stones()
	_scatter_rocks()
	_scatter_plants()
	_flush()


# --- placement rules ---------------------------------------------------------

func _scatter_trees() -> void:
	# Weighted mix: mostly plain leafy trees, a few tall, apple and blossom ones.
	var commons := ["tree_oak_1", "tree_oak_2", "tree_round_1", "tree_round_2", "tree_round_1",
		"tree_small_1", "tree_small_2", "tree_tall_1", "tree_apple_1", "tree_blossom_1", "tree_dead_1"]
	var pines := ["tree_pine_1", "tree_pine_2"]
	for i in 6000:
		if _trees.size() >= 230:
			break
		var p := _random_point(72.0)
		var edge := maxf(absf(p.x), absf(p.y))
		var forest := _shape.meadow_noise(p.x * 0.6 + 40.0, p.y * 0.6)
		var chance := 0.02
		if edge > 50.0:
			chance = 0.9
		elif forest > 0.62:
			chance = 0.55
		if _rng.randf() > chance or not _clear_of_features(p, 4.5, 11.0):
			continue
		var spacing := 3.6 if edge > 50.0 else 4.5
		if _near_tree(p, spacing):
			continue
		_add_tree(p)
		var model: String = pines.pick_random() if (edge > 48.0 and _rng.randf() < 0.6) else commons.pick_random()
		var gather := "" if model == "tree_dead_1" else ("apple_tree" if model == "tree_apple_1" else "tree")
		# Sizes vary a lot: young, grown and old trees take different work and give different wood.
		_place(model, "tree", p, _rng.randf_range(0.72, 1.4), 0.2, gather)


func _scatter_landmarks() -> void:
	# A ring of standing stones on the hilltop (the light beams are in landmark_light.gd),
	# and a dead tree by the pond.
	var rocks := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
	for i in 7:
		var p := WorldShape.HILL_CENTER + Vector2.from_angle(i * TAU / 7.0 + 0.3) * 4.2
		_place_stone(rocks[i % 3], p)
	_add_tree(WorldShape.HILL_CENTER)
	var pond := WorldShape.POND_CENTER + Vector2(-WorldShape.POND_RADIUS - 3.0, -6.0)
	_place("DeadTree_2", "tree", pond, 0.5, 0.0)


## A tall, narrow standing stone (a rock stretched upwards).
func _place_stone(model: String, p: Vector2) -> void:
	var y := _shape.height_at(p.x, p.y) - 0.3
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(0.55, 1.5, 0.55))
	basis = Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf() * 0.12) * basis
	var key := "%s|rock|%d|%d" % [model, floori(p.x / CHUNK), floori(p.y / CHUNK)]
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append(Transform3D(basis, Vector3(p.x, y, p.y)))
	_add_collider(Vector3(p.x, y, p.y), 0.6)


func _scatter_path_stones() -> void:
	var stones := ["RockPath_Round_Small_1", "RockPath_Round_Small_2", "RockPath_Round_Small_3",
		"RockPath_Square_Small_1", "RockPath_Square_Small_2"]
	var path := WorldShape.path
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var length := a.distance_to(b)
		var side := (b - a).normalized().orthogonal()
		var d := 0.0
		while d < length:
			d += _rng.randf_range(1.0, 1.8)
			if _rng.randf() < 0.45 or maxf(absf(a.x), absf(a.y)) > WorldShape.PLAY_HALF:
				continue
			var p := a.lerp(b, d / length) + side * _rng.randf_range(-0.7, 0.7)
			_place(stones.pick_random(), "ground", p, _rng.randf_range(0.7, 1.0), 0.02)


func _scatter_rocks() -> void:
	var rocks := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
	# Around the hill and the pond shore, plus a few loose ones.
	for i in 10:
		var ang := _rng.randf() * TAU
		var p := WorldShape.HILL_CENTER + Vector2.from_angle(ang) * _rng.randf_range(10.0, 15.0)
		if _shape.path_distance(p) > 2.5:
			_place(rocks.pick_random(), "rock", p, _rng.randf_range(0.5, 1.0), 0.3, "rock")
	for i in 6:
		var ang := _rng.randf() * TAU
		var p := WorldShape.POND_CENTER + Vector2.from_angle(ang) * (WorldShape.POND_RADIUS + _rng.randf_range(0.5, 2.5))
		_place(rocks.pick_random(), "rock", p, _rng.randf_range(0.5, 1.0), 0.25, "rock")
	for i in 400:
		var p := _random_point(54.0)
		if _rng.randf() < 0.05 and _clear_of_features(p, 3.0, 9.0) and not _near_tree(p, 2.5):
			_place(rocks.pick_random(), "rock", p, _rng.randf_range(0.5, 1.2), 0.3, "rock")
	var pebbles := ["Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3", "Pebble_Square_1", "Pebble_Square_3", "Pebble_Square_5"]
	for i in 1500:
		var p := _random_point(56.0)
		var pd := _shape.path_distance(p)
		if pd > 1.2 and pd < 3.0 and _rng.randf() < 0.35:
			_place(pebbles.pick_random(), "ground", p, _rng.randf_range(0.8, 1.5), 0.0)


func _scatter_plants() -> void:
	var step := 1.8
	var x := -56.0
	while x < 56.0:
		var z := -56.0
		while z < 56.0:
			var p := Vector2(x, z) + Vector2(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.7, 0.7))
			_plant_at(p)
			z += step
		x += step


func _plant_at(p: Vector2) -> void:
	if _shape.pond_distance(p) < WorldShape.POND_RADIUS + 1.5 or _shape.path_distance(p) < 1.6:
		return
	var m := _shape.meadow_noise(p.x, p.y)
	var near_tree := _near_tree(p, 3.5)
	var r := _rng.randf()
	if near_tree:
		if r < 0.12:
			_place(["Fern_1", "Plant_1"].pick_random(), "small", p, _rng.randf_range(0.35, 0.5), 0.3)
		elif r < 0.16:
			_place(["Mushroom_Common", "Mushroom_Laetiporus"].pick_random(), "small", p, _rng.randf_range(0.6, 0.9), 0.2, "mushroom")
		elif r < 0.2:
			_place(["bush_1", "bush_2", "bush_flower_1"].pick_random(), "bush", p, _rng.randf_range(0.7, 1.1), 0.1)
		return
	if r < 0.30 + m * 0.3:
		_place("Grass_Common_Short", "small", p, _rng.randf_range(0.45, 0.75), 0.25)
	elif r < 0.36 + m * 0.3:
		_place("Grass_Wispy_Short", "small", p, _rng.randf_range(0.5, 0.8), 0.25)
	elif m > 0.55 and r < 0.52 + m * 0.2:
		_place(["Flower_3_Single", "Flower_4_Single", "Flower_3_Group"].pick_random(), "small", p, _rng.randf_range(0.25, 0.4), 0.3, "flower")
	elif r < 0.66:
		_place(["Clover_1", "Plant_7", "Petal_1", "Petal_3"].pick_random(), "small", p, _rng.randf_range(0.5, 0.8), 0.2)
	elif r < 0.665:
		_place(["bush_1", "bush_2", "bush_flower_1"].pick_random(), "bush", p, _rng.randf_range(0.7, 1.0), 0.1)


# --- helpers -------------------------------------------------------------------

func _random_point(half: float) -> Vector2:
	return Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))


func _clear_of_features(p: Vector2, path_gap: float, spawn_gap: float) -> bool:
	return _shape.path_distance(p) > path_gap \
		and _shape.pond_distance(p) > WorldShape.POND_RADIUS + 2.5 \
		and p.distance_to(WorldShape.SPAWN) > spawn_gap \
		and p.distance_to(WorldShape.HILL_CENTER) > 7.0


func _add_tree(p: Vector2) -> void:
	_trees.append(p)
	var cell := Vector2i(floori(p.x / TREE_CELL), floori(p.y / TREE_CELL))
	if not _tree_grid.has(cell):
		_tree_grid[cell] = []
	_tree_grid[cell].append(p)


func _near_tree(p: Vector2, gap: float) -> bool:
	var c := Vector2i(floori(p.x / TREE_CELL), floori(p.y / TREE_CELL))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for t: Vector2 in _tree_grid.get(c + Vector2i(dx, dy), []):
				if t.distance_squared_to(p) < gap * gap:
					return true
	return false


func _place(model: String, kind: String, p: Vector2, scale: float, tilt: float, gather := "") -> void:
	var y := _shape.height_at(p.x, p.y) - 0.05 * scale
	var basis := Basis(Vector3.UP, _rng.randf() * TAU)
	if tilt > 0.0:
		basis = Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf() * tilt) * basis
	var xf := Transform3D(basis.scaled(Vector3.ONE * scale), Vector3(p.x, y, p.y))
	var key := "%s|%s|%d|%d" % [model, kind, floori(p.x / CHUNK), floori(p.y / CHUNK)]
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append(xf)
	var radius: float = KINDS[kind]["collide"]
	var collider: CollisionShape3D = null
	if radius > 0.0:
		collider = _add_collider(xf.origin, radius * scale)
	if gather != "":
		_pending_gatherables.append({"type": gather, "xf": xf, "key": key, "index": _batches[key].size() - 1,
			"collider": collider, "scale": scale})


func _add_collider(at: Vector3, radius: float) -> CollisionShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 3.0
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = at + Vector3(0, 1.5, 0)
	_colliders.add_child(col)
	return col


func _flush() -> void:
	var by_key := {}
	for key: String in _batches:
		var parts := key.split("|")
		var kind: Dictionary = KINDS[parts[1]]
		var list: Array = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		# Per-tree tint goes in custom data, so it multiplies the clump colours (vertex colours).
		mm.use_custom_data = parts[1] in ["tree", "bush"]
		mm.mesh = _mesh_for(parts[0], parts[1])
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			if mm.use_custom_data:
				mm.set_instance_custom_data(i, _tint(list[i].origin))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kind["range"] > 0.0:
			mmi.visibility_range_end = kind["range"]
			mmi.visibility_range_end_margin = 6.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)
		by_key[key] = mm
	for g in _pending_gatherables:
		g["multimesh"] = by_key[g["key"]]
		gatherables.append(g)
	_pending_gatherables.clear()
	_batches.clear()


## A small, stable colour variation per tree so a forest isn't one flat green.
func _tint(at: Vector3) -> Color:
	var a := fposmod(sin(at.x * 12.9898 + at.z * 78.233) * 43758.5453, 1.0)
	var b := fposmod(sin(at.x * 39.346 + at.z * 11.135) * 24634.6345, 1.0)
	return Color(0.9 + 0.22 * a, 0.92 + 0.14 * b, 0.86 + 0.14 * (1.0 - a))



## Loads a model once and swaps foliage materials for the wind-sway shader.
func _mesh_for(model: String, kind_name: String) -> Mesh:
	var key := model + "|" + kind_name
	if _meshes.has(key):
		return _meshes[key]
	var path := OWN % model if (model.begins_with("tree_") or model.begins_with("bush_")) else NATURE % model
	var scene := (load(path) as PackedScene).instantiate()
	var src := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := src.mesh.duplicate() as Mesh
	scene.free()
	var kind: Dictionary = KINDS[kind_name]
	for s in mesh.get_surface_count():
		var std := mesh.surface_get_material(s) as StandardMaterial3D
		if std == null:
			continue
		var name := std.resource_name
		if name in ["Canopy", "Needles", "Blossom", "Fruit", "Flower"]:
			var solid := ShaderMaterial.new()
			solid.shader = SOLID_FOLIAGE_SHADER
			solid.set_shader_parameter("albedo", std.albedo_color)
			solid.set_shader_parameter("sway", kind["sway"])
			solid.set_shader_parameter("sway_height", kind["sway_h"])
			mesh.surface_set_material(s, solid)
		elif name.begins_with("Leaves") or name.begins_with("Leaf") or name == "Grass" or name == "Flowers":
			var mat := ShaderMaterial.new()
			mat.shader = FOLIAGE_SHADER
			mat.set_shader_parameter("albedo_tex", std.albedo_texture)
			var tint := GRASS_TINT if name == "Grass" else Color.WHITE
			mat.set_shader_parameter("albedo", std.albedo_color * tint)
			mat.set_shader_parameter("sway", kind["sway"])
			mat.set_shader_parameter("sway_height", kind["sway_h"])
			mesh.surface_set_material(s, mat)
	_meshes[key] = mesh
	return mesh
