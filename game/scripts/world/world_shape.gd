class_name WorldShape
extends RefCounted
## The shape of the starting meadow: ground height, the dirt path and the pond.
## Pure functions, shared by the terrain mesh and the scatter, so they always agree.

const HALF_SIZE := 80.0          # the ground mesh covers -80..80 on x and z
const PLAY_HALF := 58.0          # invisible walls keep the player inside this
const WATER_Y := -0.45
const POND_CENTER := Vector2(24.0, -6.0)
const POND_RADIUS := 10.0
const HILL_CENTER := Vector2(-26.0, -30.0)
const HILL_RADIUS := 16.0
const HILL_HEIGHT := 4.5
const SPAWN := Vector2(0.0, 22.0)

## The dirt path, from the south edge through the meadow up onto the hill.
static var path := PackedVector2Array([
	Vector2(2, 75), Vector2(-3, 52), Vector2(3, 34), Vector2(0, 18), Vector2(7, 4),
	Vector2(4, -10), Vector2(-8, -20), Vector2(-20, -26), Vector2(-26, -30),
])

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()


func _init() -> void:
	_noise.seed = 7
	_noise.frequency = 0.02
	_noise.fractal_octaves = 3
	_detail.seed = 11
	_detail.frequency = 0.09


func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var path_d := path_distance(p)
	# Gentle rolling ground, calmer along the path.
	var h := (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 2.6 * lerpf(0.35, 1.0, smoothstep(1.5, 6.0, path_d))
	# Hills rise around the edges and close the meadow in.
	var edge := maxf(absf(x), absf(z)) / HALF_SIZE
	h += smoothstep(0.6, 1.0, edge) * 16.0
	# The hill with the old tree.
	var hill_d := p.distance_to(HILL_CENTER)
	h += (1.0 - smoothstep(HILL_RADIUS * 0.4, HILL_RADIUS, hill_d)) * HILL_HEIGHT
	# A worn dip along the path.
	h -= 0.08 * (1.0 - smoothstep(0.8, 2.2, path_d))
	# The pond bowl, with a wobbly shore.
	var pond_d := pond_distance(p)
	h = lerpf(h, -1.8, 1.0 - smoothstep(POND_RADIUS * 0.35, POND_RADIUS + 2.5, pond_d))
	return h


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
