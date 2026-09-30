class_name WorldShape
extends RefCounted
## The shape of the current region: ground height, the dirt path, the pond and the hill.
## Pure functions, shared by the terrain mesh and the scatter, so they always agree.
## Each region sets its features with use() (called by _init from Region.current).

const HALF_SIZE := 128.0         # the ground mesh covers -128..128 on x and z
const PLAY_HALF := 96.0          # invisible walls keep the player inside this
const WATER_Y := -0.45

## Per region: pond, hill (the standing stones), spawn, path, clearings (flattened: x, z, radius),
## keep_clear (not flattened), ground roughness and noise seed.
const REGIONS := {
	"meadow": {
		"pond": Vector2(24.0, -6.0), "pond_r": 10.0, "hill": Vector2(-26.0, -30.0), "hill_r": 16.0, "hill_h": 4.5,
		"spawn": Vector2(0.0, 22.0), "rough": 3.4, "seed": 7,
		"path": [Vector2(2, 125), Vector2(-2, 100), Vector2(4, 76), Vector2(-3, 52), Vector2(3, 34), Vector2(0, 18), Vector2(7, 4),
			Vector2(4, -10), Vector2(-8, -20), Vector2(-20, -26), Vector2(-26, -30)],
		"clearings": [Vector3(-5.5, 11.5, 4.2), Vector3(10.5, 13.0, 4.6), Vector3(5.4, 16.0, 1.5),
			Vector3(-9.0, 23.0, 4.4), Vector3(14.0, 3.0, 4.0), Vector3(-13.0, 2.0, 5.0),
			Vector3(9.0, 22.0, 5.0), Vector3(-6.0, 31.0, 5.0), Vector3(-1.0, 7.0, 3.0),
			Vector3(-17.0, 13.5, 5.5), Vector3(-3.5, 27.0, 2.6),
			Vector3(-76, -62, 8.0), Vector3(72, 44, 11.0), Vector3(-70, 58, 7.0),     # the places (places.gd)
			Vector3(-40, 36, 9.0), Vector3(-40, 41, 9.0)],                          # your home plot (Home)
		"keep_clear": [Vector3(-38, -12, 4.0), Vector3(40, 22, 4.0), Vector3(31, -40, 1.5), Vector3(10.8, -3.0, 3.2)],  # last: the Seeker
	},
	"forest": {
		"pond": Vector2(-24.0, -8.0), "pond_r": 8.0, "hill": Vector2(18.0, 30.0), "hill_r": 14.0, "hill_h": 3.5,
		"spawn": Vector2(-0.2, -86.0), "rough": 4.6, "seed": 21,
		"path": [Vector2(0, -125), Vector2(4, -100), Vector2(-2, -80), Vector2(0, -75), Vector2(-3, -52), Vector2(5, -36), Vector2(0, -20), Vector2(-9, -6),
			Vector2(-4, 8), Vector2(6, 18), Vector2(12, 25), Vector2(18, 30)],
		"clearings": [Vector3(0.0, -47.0, 5.0), Vector3(1.5, -83.0, 5.0),
			Vector3(-70, -45, 9.0), Vector3(66, 52, 8.0), Vector3(-62, 74, 8.0), Vector3(74, 10, 16.0)],     # camp + the places + the Red Hand camp
		"keep_clear": [Vector3(34, -18, 4.0), Vector3(-36, 30, 1.5), Vector3(-40, -40, 1.5)],
	},
}

static var region := "meadow"
static var POND_CENTER := Vector2(24.0, -6.0)
static var POND_RADIUS := 10.0
static var HILL_CENTER := Vector2(-26.0, -30.0)
static var HILL_RADIUS := 16.0
static var HILL_HEIGHT := 4.5
static var SPAWN := Vector2(0.0, 22.0)
static var ROUGH := 3.4
## The dirt path, from the edge of the region to the hill.
static var path := PackedVector2Array()
## Spots kept clear of trees, rocks and plants (houses, the merchant): (x, z, radius).
static var clearings := []
## Spots kept free of scatter without flattening the ground (ruins, treasure chests): (x, z, radius).
static var keep_clear := []

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()


func _init() -> void:
	use(Region.current)
	_noise.seed = REGIONS[region]["seed"]
	_noise.frequency = 0.02
	_noise.fractal_octaves = 3
	_detail.seed = 11
	_detail.frequency = 0.09


static func use(id: String) -> void:
	region = id if REGIONS.has(id) else "meadow"
	var r: Dictionary = REGIONS[region]
	POND_CENTER = r["pond"]
	POND_RADIUS = r["pond_r"]
	HILL_CENTER = r["hill"]
	HILL_RADIUS = r["hill_r"]
	HILL_HEIGHT = r["hill_h"]
	SPAWN = r["spawn"]
	ROUGH = r["rough"]
	path = PackedVector2Array(r["path"])
	clearings = r["clearings"]
	keep_clear = r["keep_clear"]


func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var path_d := path_distance(p)
	# Gentle rolling ground, calmer along the path.
	var h := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * ROUGH * lerpf(0.35, 1.0, smoothstep(1.5, 6.0, path_d))
	# Hills rise around the edges and close the meadow in.
	var edge := maxf(absf(x), absf(z)) / HALF_SIZE
	# The path out of the region cuts a notch through them (the way to the next region).
	h += smoothstep(0.6, 1.0, edge) * 16.0 * lerpf(0.2, 1.0, smoothstep(3.0, 12.0, path_d))
	# The hill with the old tree.
	var hill_d := p.distance_to(HILL_CENTER)
	h += (1.0 - smoothstep(HILL_RADIUS * 0.4, HILL_RADIUS, hill_d)) * HILL_HEIGHT
	# Level ground under the houses.
	for c: Vector3 in clearings:
		var k := 1.0 - smoothstep(c.z * 0.8, c.z + 2.0, p.distance_to(Vector2(c.x, c.y)))
		h = lerpf(h, 0.9, k)
	# A worn dip along the path.
	h -= 0.08 * (1.0 - smoothstep(0.8, 2.2, path_d))
	# The pond bowl (knee-deep water), with a wobbly shore.
	var pond_d := pond_distance(p)
	h = lerpf(h, -1.05, 1.0 - smoothstep(POND_RADIUS * 0.35, POND_RADIUS + 2.5, pond_d))
	return h


func in_clearing(p: Vector2) -> bool:
	for c: Vector3 in keep_clear:
		if p.distance_to(Vector2(c.x, c.y)) < c.z:
			return true
	for c: Vector3 in clearings:
		if p.distance_to(Vector2(c.x, c.y)) < c.z:
			return true
	return false


func pond_distance(p: Vector2) -> float:
	return p.distance_to(POND_CENTER) + _detail.get_noise_2d(p.x, p.y) * 2.5


func path_distance(p: Vector2) -> float:
	var best := INF
	for i in path.size() - 1:
		var a := path[i]
		var ab := path[i + 1] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## 0..1 noise used to vary grass colour and plant density.
func meadow_noise(x: float, z: float) -> float:
	return _detail.get_noise_2d(x * 0.35, z * 0.35) * 0.5 + 0.5
