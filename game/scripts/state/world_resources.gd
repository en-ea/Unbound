extends Node
## Gatherable things in the world (trees, rocks, plants) as plain state: where they are, how many
## hits they have left, and when they grow back. Visuals listen to the signals; nothing here
## touches nodes, so this can later be synced for co-op.

signal hit(id: int, hits_left: int)
signal depleted(id: int, drops: Array)     # drops: Array of item ids (one entry per item)
signal respawned(id: int)

## Per type: hits to deplete, seconds to grow back, reach radius, tool, and drops.
## Drops: [item, min, max, chance].
const TYPES := {
	"tree": {"hits": 4, "respawn": 60.0, "radius": 0.6, "tool": "axe", "verb": "Chop",
		"drops": [["wood", 2, 3, 1.0], ["resin", 1, 1, 0.08]]},
	"apple_tree": {"hits": 4, "respawn": 60.0, "radius": 0.6, "tool": "axe", "verb": "Chop",
		"drops": [["wood", 2, 2, 1.0], ["apple", 1, 3, 1.0], ["resin", 1, 1, 0.08]]},
	"rock": {"hits": 5, "respawn": 90.0, "radius": 1.0, "tool": "pickaxe", "verb": "Mine",
		"drops": [["stone", 2, 3, 1.0], ["flint", 1, 1, 0.15], ["shard", 1, 1, 0.04]]},
	"mushroom": {"hits": 1, "respawn": 40.0, "radius": 0.3, "tool": "", "verb": "Pick",
		"drops": [["mushroom", 1, 1, 1.0], ["glowcap", 1, 1, 0.06]]},
	"flower": {"hits": 1, "respawn": 40.0, "radius": 0.3, "tool": "", "verb": "Pick",
		"drops": [["flower", 1, 2, 1.0]]},
}

const CELL := 8.0

var _nodes: Array[Dictionary] = []   # id -> {type, pos: Vector3, scale, hits_left, respawn_at}
var _grid := {}                      # Vector2i -> Array[int] of ids
var _rng := RandomNumberGenerator.new()
var _check_timer := 0.0


func _ready() -> void:
	_rng.randomize()


func add_node(type: String, pos: Vector3, scale := 1.0) -> int:
	var id := _nodes.size()
	_nodes.append({"type": type, "pos": pos, "scale": scale, "hits_left": TYPES[type]["hits"], "respawn_at": -1.0})
	var cell := _cell(pos)
	if not _grid.has(cell):
		_grid[cell] = []
	_grid[cell].append(id)
	return id


func get_node_data(id: int) -> Dictionary:
	return _nodes[id]


func type_info(id: int) -> Dictionary:
	return TYPES[_nodes[id]["type"]]


func is_available(id: int) -> bool:
	return _nodes[id]["respawn_at"] < 0.0


## The closest available node whose edge is within `reach` of `pos`, or -1.
func nearest(pos: Vector3, reach: float) -> int:
	var best := -1
	var best_d := INF
	var c := _cell(pos)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for id: int in _grid.get(c + Vector2i(dx, dz), []):
				var n := _nodes[id]
				if n["respawn_at"] >= 0.0:
					continue
				var p: Vector3 = n["pos"]
				var d: float = Vector2(p.x - pos.x, p.z - pos.z).length() - TYPES[n["type"]]["radius"] * n["scale"]
				if d < reach and d < best_d:
					best_d = d
					best = id
	return best


## The action: one hit on a node. Returns true if that hit depleted it.
func hit_node(id: int) -> bool:
	var n := _nodes[id]
	if n["respawn_at"] >= 0.0:
		return false
	n["hits_left"] -= 1
	hit.emit(id, n["hits_left"])
	if n["hits_left"] > 0:
		return false
	var info: Dictionary = TYPES[n["type"]]
	n["respawn_at"] = _now() + info["respawn"]
	var drops: Array = []
	for d: Array in info["drops"]:
		if _rng.randf() <= d[3]:
			for i in _rng.randi_range(d[1], d[2]):
				drops.append(d[0])
	depleted.emit(id, drops)
	return true


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 1.0
	var now := _now()
	for id in _nodes.size():
		var n := _nodes[id]
		if n["respawn_at"] >= 0.0 and now >= n["respawn_at"]:
			n["respawn_at"] = -1.0
			n["hits_left"] = TYPES[n["type"]]["hits"]
			respawned.emit(id)


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
