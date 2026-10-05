extends Node3D
## Scatters our faceted nature models over the meadow.
## Each model is drawn with MultiMeshes split into chunks, so off-screen chunks are culled.

const OWN := "res://assets/nature/%s.glb"          # all models: tools-src/blender/make_trees.py
const SOLID_FOLIAGE_SHADER := preload("res://shaders/foliage_solid.gdshader")
const CHUNK := 60.0
const TREE_CELL := 5.0      # grid cell for fast "is there a tree near here" checks
const EDGE := WorldShape.PLAY_HALF - 8.0     # past this, the woods close in around the region

## Per model: cast shadows, visibility range (0 = always), wind sway (metres), sway height.
const KINDS := {
	"tree": {"shadow": true, "range": 0.0, "sway": 0.08, "sway_h": 6.0, "collide": 0.35},
	"bush": {"shadow": false, "range": 50.0, "sway": 0.04, "sway_h": 1.2, "collide": 0.0},
	"rock": {"shadow": true, "range": 0.0, "sway": 0.0, "sway_h": 1.0, "collide": 0.8},
	"small": {"shadow": false, "range": 36.0, "sway": 0.06, "sway_h": 0.5, "collide": 0.0},
	"ground": {"shadow": false, "range": 36.0, "sway": 0.0, "sway_h": 1.0, "collide": 0.0},
}

var _shape: WorldShape
var _rng := RandomNumberGenerator.new()
var _batches := {}         # "model|kind|cx|cz" -> Array[Transform3D]
var _meshes := {}          # "model|kind" -> Mesh with our materials
var _trees: Array[Vector2] = []
var _ore_spots: Array[Vector2] = []
var _tree_grid := {}        # Vector2i cell -> Array[Vector2] of trees in it
var _colliders: StaticBody3D
var _pending_gatherables: Array[Dictionary] = []

## Filled by build(): one entry per gatherable thing, for ResourceVisuals.
## {type, xf: Transform3D, multimesh: MultiMesh, index: int, collider: CollisionShape3D, scale}
var gatherables: Array[Dictionary] = []
## Filled by build(): every tree instance {xf, multimesh, index}, for the OcclusionFader.
var trees: Array[Dictionary] = []
## Filled by build(): soft shade to bake into the ground under trees, rocks and bushes.
## Each: Vector4(x, z, radius, strength).
var shade_spots: Array[Vector4] = []
const SHADE := {"tree": Vector2(2.4, 0.55), "rock": Vector2(1.5, 0.5), "bush": Vector2(1.1, 0.45)}
var _pending_trees: Array[Dictionary] = []


func build(shape: WorldShape) -> void:
	_shape = shape
	_rng.seed = 1234
	_colliders = StaticBody3D.new()
	add_child(_colliders)
	if WorldShape.region == "forest":
		_scatter_forest_trees()
	elif WorldShape.region == "highlands":
		_scatter_highland_trees()
	else:
		_scatter_trees()
	_scatter_landmarks()
	if WorldShape.region == "highlands":
		_scatter_highland_features()
	_scatter_path_stones()
	_scatter_rocks()
	_scatter_ores()
	_scatter_plants()
	if WorldShape.region == "meadow":
		_tobacco_patch(Vector2(-22.0, 19.0))
	_flush()


## Wren's tobacco patch, so the first quest can always be done: a handful of plants in a loose group.
func _tobacco_patch(center: Vector2) -> void:
	var placed := 0
	for i in 60:
		if placed >= 9:
			break
		var p := center + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.5, 4.0)
		if not _clear_of_features(p, 1.5, 3.0) or _near_tree(p, 1.5):
			continue
		_place("tobacco_1", "small", p, _rng.randf_range(1.0, 1.3), 0.06, "tobacco")
		placed += 1


# --- placement rules ---------------------------------------------------------

func _scatter_trees() -> void:
	# Weighted mix: mostly plain leafy trees, a few tall, apple and blossom ones.
	var commons := ["tree_oak_1", "tree_oak_2", "tree_round_1", "tree_round_2", "tree_round_1",
		"tree_small_1", "tree_small_2", "tree_tall_1", "tree_apple_1", "tree_blossom_1", "tree_dead_1"]
	var pines := ["tree_pine_1", "tree_pine_2"]
	for i in 16000:
		if _trees.size() >= 620:
			break
		var p := _random_point(WorldShape.HALF_SIZE - 8.0)
		var edge := maxf(absf(p.x), absf(p.y))
		var forest := _shape.meadow_noise(p.x * 0.6 + 40.0, p.y * 0.6)
		var chance := 0.02
		if edge > EDGE:
			chance = 0.9
		elif forest > 0.62:
			chance = 0.55
		if _rng.randf() > chance or not _clear_of_features(p, 4.5, 11.0):
			continue
		var spacing := 3.6 if edge > EDGE else 4.5
		if _near_tree(p, spacing):
			continue
		_add_tree(p)
		var model: String = _pick(pines) if (edge > EDGE - 2.0 and _rng.randf() < 0.6) else _pick(commons)
		var gather := "" if model == "tree_dead_1" else ("apple_tree" if model == "tree_apple_1" else "tree")
		# Sizes vary a lot: young, grown and old trees take different work and give different wood.
		_place(model, "tree", p, _rng.randf_range(0.72, 1.4), 0.2, gather)


## The Whispering Wood: close-packed old pines and oaks everywhere but the path, the pool and the
## shrine. Pines here are "pine" (pinewood, needs a Stone axe); the rest give plain wood.
func _scatter_forest_trees() -> void:
	var leafy := ["tree_oak_1", "tree_oak_2", "tree_round_2", "tree_tall_1", "tree_small_2", "tree_dead_1"]
	var pines := ["tree_pine_1", "tree_pine_2"]
	for i in 24000:
		if _trees.size() >= 950:
			break
		var p := _random_point(WorldShape.HALF_SIZE - 8.0)
		var edge := maxf(absf(p.x), absf(p.y))
		var thick := _shape.meadow_noise(p.x * 0.5 - 30.0, p.y * 0.5)
		if _rng.randf() > (0.95 if edge > EDGE else 0.35 + thick * 0.6) or not _clear_of_features(p, 3.5, 6.0):
			continue
		if _near_tree(p, 3.1 if edge > EDGE else 3.6):
			continue
		_add_tree(p)
		var pine := _rng.randf() < 0.55
		var model: String = _pick(pines) if pine else _pick(leafy)
		var gather := "" if model == "tree_dead_1" else ("pine" if pine else "tree")
		_place(model, "tree", p, _rng.randf_range(0.8, 1.55) if pine else _rng.randf_range(0.75, 1.3), 0.15, gather)


## The highlands: a few hardy pines in the low ground and thicker along the edges, none on the snow.
func _scatter_highland_trees() -> void:
	var pines := ["tree_pine_1", "tree_pine_2"]
	for i in 16000:
		if _trees.size() >= 320:
			break
		var p := _random_point(WorldShape.HALF_SIZE - 8.0)
		var edge := maxf(absf(p.x), absf(p.y))
		var thick := _shape.meadow_noise(p.x * 0.5 + 70.0, p.y * 0.5)
		if _rng.randf() > (0.7 if edge > EDGE else 0.04 + thick * 0.25) or not _clear_of_features(p, 4.0, 9.0):
			continue
		if _shape.height_at(p.x, p.y) > 7.5 or _near_tree(p, 4.0):
			continue
		_add_tree(p)
		var dead := _rng.randf() < 0.1
		_place("tree_dead_1" if dead else _pick(pines), "tree", p, _rng.randf_range(0.7, 1.3), 0.15, "" if dead else "pine")


## The highlands' bold shapes: rocky tors crowning the hilltops, tall crags on the slopes, cairns
## marking the path, and old drystone walls wandering over the low ground (gaps where the path goes).
func _scatter_highland_features() -> void:
	var rocks := ["rock_1", "rock_2", "rock_3"]
	# Tors: on the highest knolls below the snow, well apart.
	var knolls: Array[Vector3] = []
	var half := WorldShape.PLAY_HALF - 14.0
	var x := -half
	while x <= half:
		var z := -half
		while z <= half:
			var h := _shape.height_at(x, z)
			var around := 0.0
			for d in [Vector2(9, 0), Vector2(-9, 0), Vector2(0, 9), Vector2(0, -9)]:
				around += _shape.height_at(x + d.x, z + d.y) * 0.25
			if h - around > 0.5 and h < 7.0 and _clear_of_features(Vector2(x, z), 6.0, 14.0):
				knolls.append(Vector3(x, z, h - around))
			z += 5.0
		x += 5.0
	knolls.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z > b.z)
	var tors: Array[Vector2] = []
	for k in knolls:
		var p := Vector2(k.x, k.y)
		if tors.size() >= 9 or tors.any(func(t: Vector2) -> bool: return t.distance_to(p) < 26.0):
			continue
		tors.append(p)
		_tor(p, rocks)
	# Crags: tall stones leaning out of the slopes.
	var crags := 0
	for i in 3000:
		if crags >= 14:
			break
		var p := _random_point(WorldShape.PLAY_HALF - 10.0)
		var h := _shape.height_at(p.x, p.y)
		var slope := absf(_shape.height_at(p.x + 2.0, p.y) - _shape.height_at(p.x - 2.0, p.y)) \
			+ absf(_shape.height_at(p.x, p.y + 2.0) - _shape.height_at(p.x, p.y - 2.0))
		if slope < 1.4 or h > 9.0 or not _clear_of_features(p, 5.0, 12.0) or _near_tree(p, 3.0) \
				or tors.any(func(t: Vector2) -> bool: return t.distance_to(p) < 8.0):
			continue
		var s := _rng.randf_range(1.1, 1.8)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(2.2, 3.0), s * 0.85))
		basis = Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.05, 0.25)) * basis
		_place_free(_pick(rocks), Vector3(p.x, h - 0.4 * s, p.y), basis, 0.8 * s)
		crags += 1
	# Cairns beside the path, every so often, on alternate sides.
	var path := WorldShape.path
	var walked := 0.0
	var side := 1.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var seg := a.distance_to(b)
		var t := 0.0
		while t < seg:
			if walked + t >= 22.0:
				walked = -t
				var along := (b - a).normalized()
				var p := a.lerp(b, t / seg) + Vector2(-along.y, along.x) * 2.4 * side
				side = -side
				if p.distance_to(WorldShape.SPAWN) > 6.0:
					_cairn(p, rocks)
			t += 2.0
		walked += seg
	# Drystone walls.
	for wall in [[Vector2(-58, -66), Vector2(-40, -52), Vector2(-24, -30), Vector2(-4, -22), Vector2(18, -26)],
			[Vector2(32, -76), Vector2(44, -62), Vector2(52, -38), Vector2(76, -24)],
			[Vector2(-76, -14), Vector2(-60, -6), Vector2(-46, -12)],
			[Vector2(40, 46), Vector2(58, 40), Vector2(70, 56)]]:
		_drystone_wall(wall, rocks)


## A tor: a heap of great boulders with one balanced on top.
func _tor(p: Vector2, rocks: Array) -> void:
	var h := _shape.height_at(p.x, p.y)
	var big := _rng.randf_range(2.6, 3.6)
	_place_free(_pick(rocks), Vector3(p.x, h - 0.5, p.y), Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(big, big * 0.9, big)), 0.75 * big)
	for i in _rng.randi_range(2, 4):
		var q := p + Vector2.from_angle(_rng.randf() * TAU) * big * _rng.randf_range(0.8, 1.3)
		var s := _rng.randf_range(1.1, 2.0)
		var lean := Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf() * 0.3)
		_place_free(_pick(rocks), Vector3(q.x, _shape.height_at(q.x, q.y) - 0.3, q.y), lean * Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), 0.75 * s)
	var top := _rng.randf_range(1.2, 1.7)
	var tip := Basis(Vector3(1, 0, 0.3).normalized(), _rng.randf_range(0.1, 0.3)) * Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(top, top * 0.8, top))
	_place_free(_pick(rocks), Vector3(p.x + _rng.randf_range(-0.4, 0.4), h - 0.5 + big * 0.9 * 0.95, p.y + _rng.randf_range(-0.4, 0.4)), tip, 0.0)


## A cairn: four stones stacked, smaller each time.
func _cairn(p: Vector2, rocks: Array) -> void:
	var y := _shape.height_at(p.x, p.y)
	var lift := 0.0
	for s: float in [0.5, 0.4, 0.3, 0.2]:
		_place_free(_pick(rocks), Vector3(p.x + _rng.randf_range(-0.05, 0.05), y + lift - 0.15 * s, p.y + _rng.randf_range(-0.05, 0.05)),
			Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * 0.8, s)), 0.4 if s == 0.5 else 0.0)
		lift += s * 0.8


## An old drystone wall along `points`: a row of stones with a smaller row along the top.
func _drystone_wall(points: Array, rocks: Array) -> void:
	var n := 0
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var seg := a.distance_to(b)
		var yaw := atan2(b.x - a.x, b.y - a.y)
		var t := 0.0
		while t < seg:
			var p := a.lerp(b, t / seg) + Vector2(_rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.08, 0.08))
			t += 0.85
			n += 1
			var h := _shape.height_at(p.x, p.y)
			if h > 7.5 or _shape.path_distance(p) < 2.6 or _shape.in_clearing(p) \
					or _shape.pond_distance(p) < WorldShape.POND_RADIUS + 1.5 or _near_tree(p, 1.2):
				continue
			var s := _rng.randf_range(0.5, 0.62)
			var basis := Basis(Vector3.UP, yaw + _rng.randf_range(-0.25, 0.25)).scaled(Vector3(s * 0.85, s * 0.75, s * 1.15))
			_place_free(_pick(rocks), Vector3(p.x, h - 0.12, p.y), basis, 0.55 if n % 2 == 0 else 0.0)
			if n % 2 == 0:
				var s2 := _rng.randf_range(0.36, 0.44)
				_place_free(_pick(rocks), Vector3(p.x, h + s * 0.75 * 0.85, p.y),
					Basis(Vector3.UP, yaw + _rng.randf_range(-0.4, 0.4)).scaled(Vector3(s2 * 0.9, s2 * 0.7, s2 * 1.2)), 0.0)


## A rock placed exactly (any height, stretch or lean); `collide` is the collider's radius (0: none).
func _place_free(model: String, at: Vector3, basis: Basis, collide: float) -> void:
	var key := "%s|rock|%d|%d" % [model, floori(at.x / CHUNK), floori(at.z / CHUNK)]
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append(Transform3D(basis, at))
	if collide > 0.0:
		_add_collider(Vector3(at.x, _shape.height_at(at.x, at.z), at.z), collide)
		shade_spots.append(Vector4(at.x, at.z, collide * 1.8, 0.5))


func _scatter_landmarks() -> void:
	# A ring of standing stones on the hilltop (the light beams are in landmark_light.gd),
	# and a dead tree by the pond.
	var rocks := ["rock_1", "rock_2", "rock_3"]
	for i in 7:
		var p := WorldShape.HILL_CENTER + Vector2.from_angle(i * TAU / 7.0 + 0.3) * 4.2
		_place_stone(rocks[i % 3], p)
	_add_tree(WorldShape.HILL_CENTER)
	var pond := WorldShape.POND_CENTER + Vector2(-WorldShape.POND_RADIUS - 3.0, -6.0)
	_place("tree_dead_1", "tree", pond, 1.2, 0.0)


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
	var stones := ["stones_1", "stones_2", "stones_3"]
	var path := WorldShape.path
	var last := Vector2.INF
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
			if p.distance_to(last) < 1.6:      # groups that overlap flicker
				continue
			last = p
			_place(_pick(stones), "ground", p, _rng.randf_range(0.7, 1.0), 0.02)


## Ore rocks (before the plants, which keep off them): copper around the hill, iron
## deep in the north woods.
func _scatter_ores() -> void:
	var placed := 0
	for i in 200:
		if placed >= 7:
			break
		var p := WorldShape.HILL_CENTER + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(9.0, 17.0)
		if _clear_of_features(p, 2.5, 9.0) and not _near_tree(p, 2.5):
			_place("ore_copper", "rock", p, _rng.randf_range(0.7, 0.9), 0.2, "copper_rock")
			_ore_spots.append(p)
			placed += 1
	placed = 0
	for i in 200:
		if placed >= (9 if WorldShape.region == "highlands" else 5):
			break
		var p := Vector2(_rng.randf_range(-30, 40), _rng.randf_range(-52, -36)) if WorldShape.region == "meadow" \
			else (Vector2(_rng.randf_range(-70, -20), _rng.randf_range(-15, 10)) if WorldShape.region == "highlands" \
			else Vector2(_rng.randf_range(-48, -14), _rng.randf_range(34, 52)))
		if _clear_of_features(p, 2.5, 9.0) and not _near_tree(p, 2.5):
			_place("ore_iron", "rock", p, _rng.randf_range(0.7, 0.9), 0.2, "iron_rock")
			_ore_spots.append(p)
			placed += 1


func _scatter_rocks() -> void:
	var rocks := ["rock_1", "rock_2", "rock_3"]
	# Around the hill and the pond shore, plus a few loose ones.
	for i in 10:
		var ang := _rng.randf() * TAU
		var p := WorldShape.HILL_CENTER + Vector2.from_angle(ang) * _rng.randf_range(10.0, 15.0)
		if _shape.path_distance(p) > 2.5:
			_place(_pick(rocks), "rock", p, _rng.randf_range(0.5, 1.0), 0.3, "rock")
	for i in 6:
		var ang := _rng.randf() * TAU
		var p := WorldShape.POND_CENTER + Vector2.from_angle(ang) * (WorldShape.POND_RADIUS + _rng.randf_range(0.5, 2.5))
		_place(_pick(rocks), "rock", p, _rng.randf_range(0.5, 1.0), 0.25, "rock")
	for i in 1100:
		var p := _random_point(WorldShape.PLAY_HALF - 4.0)
		if _rng.randf() < 0.05 and _clear_of_features(p, 3.0, 9.0) and not _near_tree(p, 2.5):
			_place(_pick(rocks), "rock", p, _rng.randf_range(0.5, 1.2), 0.3, "rock")
	var pebbles := ["pebble_1", "pebble_2"]
	for i in 4000:
		var p := _random_point(WorldShape.PLAY_HALF - 2.0)
		var pd := _shape.path_distance(p)
		if pd > 1.2 and pd < 3.0 and _rng.randf() < 0.35:
			_place(_pick(pebbles), "ground", p, _rng.randf_range(0.8, 1.5), 0.0)


func _scatter_plants() -> void:
	var step := 1.8
	var half := WorldShape.PLAY_HALF - 2.0
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			var p := Vector2(x, z) + Vector2(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.7, 0.7))
			_plant_at(p)
			z += step
		x += step


func _plant_at(p: Vector2) -> void:
	if _shape.pond_distance(p) < WorldShape.POND_RADIUS + 1.5 or _shape.path_distance(p) < 1.6 or _shape.in_clearing(p):
		return
	for o in _ore_spots:                  # no grass growing through the ore rocks
		if o.distance_squared_to(p) < 2.0:
			return
	var m := _shape.meadow_noise(p.x, p.y)
	var near_tree := _near_tree(p, 3.5)
	if WorldShape.region == "forest":
		_forest_plant_at(p, m, near_tree)
		return
	if WorldShape.region == "highlands":
		var hr := _rng.randf()
		if _shape.height_at(p.x, p.y) > 8.0:
			return
		if hr < 0.16 + m * 0.1:
			_place(_pick(["grass_1", "grass_2", "grass_3"]), "small", p, _rng.randf_range(0.8, 1.3), 0.25)
		elif m > 0.55 and hr < 0.24:
			_place(_pick(["flower_2", "flower_4"]), "small", p, _rng.randf_range(0.7, 0.95), 0.25, "flower")
		elif hr < 0.255:
			_place(_pick(["rock_1", "rock_2", "rock_3"]), "rock", p, _rng.randf_range(0.4, 0.8), 0.3, "rock")
		return
	var r := _rng.randf()
	if near_tree:
		if r < 0.12:
			_place("fern_1", "small", p, _rng.randf_range(0.8, 1.2), 0.2)
		elif r < 0.16:
			_place(_pick(["mushroom_1", "mushroom_2"]), "small", p, _rng.randf_range(0.9, 1.2), 0.15, "mushroom")
		elif r < 0.2:
			_place(_pick(["bush_1", "bush_2", "bush_flower_1"]), "bush", p, _rng.randf_range(0.7, 1.1), 0.1)
		return
	# Sparse grass keeps the ground clean; it gathers a little more in lush patches.
	if r < 0.1 + m * 0.18:
		_place(_pick(["grass_1", "grass_2"]), "small", p, _rng.randf_range(0.9, 1.4), 0.2)
	elif r < 0.13 + m * 0.2:
		_place("grass_3", "small", p, _rng.randf_range(1.2, 1.8), 0.2)
	elif m > 0.45 and r < 0.54 + m * 0.2:
		_place(_pick(["flower_1", "flower_2", "flower_3", "flower_4", "flower_5"]), "small", p, _rng.randf_range(0.85, 1.15), 0.2, "flower")
	elif r < 0.66:
		if r > 0.63:                # wild tobacco, now and then, in the open
			_place("tobacco_1", "small", p, _rng.randf_range(0.9, 1.15), 0.08, "tobacco")
	elif r < 0.665:
		_place(_pick(["bush_1", "bush_2", "bush_flower_1"]), "bush", p, _rng.randf_range(0.7, 1.0), 0.1)


## Forest floor: ferns and mushrooms under the trees (glowcaps show up more here), moss grass,
## a few bushes, and flowers only in the odd sunny gap.
func _forest_plant_at(p: Vector2, m: float, near_tree: bool) -> void:
	var r := _rng.randf()
	if near_tree:
		if r < 0.22:
			_place("fern_1", "small", p, _rng.randf_range(0.9, 1.4), 0.2)
		elif r < 0.28:
			_place(_pick(["mushroom_1", "mushroom_2"]), "small", p, _rng.randf_range(0.9, 1.3), 0.15, "mushroom")
		elif r < 0.33:
			_place(_pick(["bush_1", "bush_2"]), "bush", p, _rng.randf_range(0.8, 1.2), 0.1)
		return
	if r < 0.14 + m * 0.12:
		_place(_pick(["grass_1", "grass_2", "grass_3"]), "small", p, _rng.randf_range(0.9, 1.5), 0.2)
	elif r < 0.2:
		_place("fern_1", "small", p, _rng.randf_range(0.8, 1.2), 0.2)
	elif m > 0.6 and r < 0.3:
		_place(_pick(["flower_2", "flower_4"]), "small", p, _rng.randf_range(0.85, 1.1), 0.2, "flower")


# --- helpers -------------------------------------------------------------------

func _random_point(half: float) -> Vector2:
	return Vector2(_rng.randf_range(-half, half), _rng.randf_range(-half, half))


func _clear_of_features(p: Vector2, path_gap: float, spawn_gap: float) -> bool:
	return not _shape.in_clearing(p) and _shape.path_distance(p) > path_gap \
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
	var y := _shape.height_at(p.x, p.y) - (0.0 if kind == "ground" else 0.05 * scale)
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
	if SHADE.has(kind):
		shade_spots.append(Vector4(p.x, p.y, SHADE[kind].x * scale, SHADE[kind].y))
	if kind == "tree":
		_pending_trees.append({"xf": xf, "key": key, "index": _batches[key].size() - 1})
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
		mmi.set_meta("kind", parts[1])
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
	for t in _pending_trees:
		t["multimesh"] = by_key[t["key"]]
		trees.append(t)
	_pending_trees.clear()
	_batches.clear()


## One gatherable on its own (the build lab's test spawns): its own small MultiMesh and collider,
## under `parent`. Returns the gatherable dict for ResourceVisuals.add_gatherable().
func make_single(parent: Node3D, model: String, kind: String, at: Vector3, scale: float, gather: String) -> Dictionary:
	var xf := Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * scale), at)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = kind in ["tree", "bush"]
	mm.mesh = _mesh_for(model, kind)
	mm.instance_count = 1
	mm.set_instance_transform(0, xf)
	if mm.use_custom_data:
		mm.set_instance_custom_data(0, _tint(at))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	parent.add_child(mmi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = KINDS[kind]["collide"] * scale
	shape.height = 3.0
	col.shape = shape
	col.position = at + Vector3(0, 1.5, 0)
	body.add_child(col)
	parent.add_child(body)
	return {"type": gather, "xf": xf, "multimesh": mm, "index": 0, "collider": col, "scale": scale}


## A small, stable colour variation per tree so a forest isn't one flat green.
func _tint(at: Vector3) -> Color:
	var a := fposmod(sin(at.x * 12.9898 + at.z * 78.233) * 43758.5453, 1.0)
	var b := fposmod(sin(at.x * 39.346 + at.z * 11.135) * 24634.6345, 1.0)
	return Color(0.9 + 0.22 * a, 0.92 + 0.14 * b, 0.86 + 0.14 * (1.0 - a))



## Loads a model once. Every surface except bare wood uses the solid foliage shader, which reads
## the per-face colours from the model's UVs (and sways leaves, grass and flowers in the wind).
func _mesh_for(model: String, kind_name: String) -> Mesh:
	var key := model + "|" + kind_name
	if _meshes.has(key):
		return _meshes[key]
	var scene := (load(OWN % model) as PackedScene).instantiate()
	var src := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := src.mesh.duplicate() as Mesh
	scene.free()
	var kind: Dictionary = KINDS[kind_name]
	for s in mesh.get_surface_count():
		var std := mesh.surface_get_material(s) as StandardMaterial3D
		if std == null:
			continue
		var name := std.resource_name
		if name not in ["Trunk", "Stump"]:
			var solid := ShaderMaterial.new()
			solid.shader = SOLID_FOLIAGE_SHADER
			solid.set_shader_parameter("albedo", std.albedo_color)
			solid.set_shader_parameter("sway", kind["sway"])
			solid.set_shader_parameter("sway_height", kind["sway_h"])
			mesh.surface_set_material(s, solid)
	_meshes[key] = mesh
	return mesh


## Where every tree stands (x, z), for the minimap.
func tree_points() -> Array[Vector2]:
	return _trees


## A random entry using the seeded generator, so the world is the same every launch.
func _pick(list: Array) -> Variant:
	return list[_rng.randi() % list.size()]
