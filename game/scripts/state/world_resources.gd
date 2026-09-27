extends Node
## Gatherable things in the world (trees, rocks, plants) as plain state: where they are, how many
## hits they have left, and when they grow back. Visuals listen to the signals; nothing here
## touches nodes, so this can later be synced for co-op.

signal hit(id: int, hits_left: int)
signal depleted(id: int, drops: Array)     # drops: Array of item ids (one entry per item)
signal respawned(id: int)
signal grown(id: int, size: float)          # a regrowing tree got bigger (size = scale factor)
signal loaded                               # a save was loaded: visuals redraw every node

## Per type: hits to deplete (a Worn tool takes 2 per swing, see Gear.TIERS), seconds to grow back, reach radius, tool, and drops.
## Drops: [item, min, max, chance].
const TYPES := {
	"tree": {"hits": 8, "respawn": 60.0, "radius": 0.6, "tool": "axe", "verb": "Chop",
		"drops": [["wood", 2, 3, 1.0], ["resin", 1, 1, 0.08]]},
	"apple_tree": {"hits": 8, "respawn": 60.0, "radius": 0.6, "tool": "axe", "verb": "Chop",
		"drops": [["wood", 2, 2, 1.0], ["apple", 1, 3, 1.0], ["resin", 1, 1, 0.08]]},
	"rock": {"hits": 10, "respawn": 90.0, "radius": 1.0, "tool": "pickaxe", "verb": "Mine",
		"drops": [["stone", 2, 3, 1.0], ["flint", 1, 1, 0.15], ["shard", 1, 1, 0.04]]},
	# Ore rocks need a better pickaxe (min_tier, see Gear.TIERS).
	"copper_rock": {"hits": 12, "respawn": 120.0, "radius": 1.0, "tool": "pickaxe", "verb": "Mine", "min_tier": 1,
		"drops": [["copper", 2, 3, 1.0], ["stone", 1, 2, 1.0]]},
	"iron_rock": {"hits": 16, "respawn": 150.0, "radius": 1.0, "tool": "pickaxe", "verb": "Mine", "min_tier": 2,
		"drops": [["iron", 2, 3, 1.0], ["stone", 1, 2, 1.0], ["shard", 1, 1, 0.08]]},
	"mushroom": {"hits": 1, "respawn": 40.0, "radius": 0.3, "tool": "", "verb": "Pick",
		"drops": [["mushroom", 1, 1, 1.0], ["glowcap", 1, 1, 0.06]]},
	"flower": {"hits": 1, "respawn": 40.0, "radius": 0.3, "tool": "", "verb": "Pick",
		"drops": [["flower", 1, 2, 1.0]]},
	"chest": {"hits": 1, "respawn": 900.0, "radius": 0.5, "tool": "", "verb": "Open",
		"drops": [["flint", 2, 4, 1.0], ["resin", 1, 2, 0.8], ["shard", 1, 2, 0.7], ["glowcap", 1, 1, 0.5], ["fang", 1, 1, 0.3]]},
}

## Trees come in sizes by how big they look (their scale). Same size = same work and wood,
## whatever the kind of tree. Apple trees add their apples on top.
const TREE_STAGES := [
	{"up_to": 0.9, "name": "Young", "hits": 6, "wood": [1, 2], "resin": 0.04},
	{"up_to": 1.15, "name": "Grown", "hits": 8, "wood": [2, 3], "resin": 0.08},
	{"up_to": 99.0, "name": "Old", "hits": 12, "wood": [4, 5], "resin": 0.16},
]
const SAPLING_SIZE := 0.45       # a regrown tree starts at this fraction of its full size
const GROW_TIME := 240.0         # seconds from sapling to full size

const CELL := 8.0

var _nodes: Array[Dictionary] = []   # id -> {type, pos: Vector3, scale, hits_left, respawn_at}
var _grid := {}                      # Vector2i -> Array[int] of ids
var _rng := RandomNumberGenerator.new()
var _check_timer := 0.0


func _ready() -> void:
	_rng.randomize()


func add_node(type: String, pos: Vector3, scale := 1.0) -> int:
	var id := _nodes.size()
	_nodes.append({"type": type, "pos": pos, "scale": scale, "growth": 1.0, "hits_left": 0, "respawn_at": -1.0})
	_nodes[id]["hits_left"] = _hits_for(id)
	var cell := _cell(pos)
	if not _grid.has(cell):
		_grid[cell] = []
	_grid[cell].append(id)
	return id


func get_node_data(id: int) -> Dictionary:
	return _nodes[id]


func type_info(id: int) -> Dictionary:
	return TYPES[_nodes[id]["type"]]


func is_tree(id: int) -> bool:
	return _nodes[id]["type"] in ["tree", "apple_tree"]


## How big the thing looks right now, as a fraction of its full scatter size (saplings < 1).
func size_factor(id: int) -> float:
	return lerpf(SAPLING_SIZE, 1.0, _nodes[id]["growth"])


func tree_stage(id: int) -> Dictionary:
	var n := _nodes[id]
	var s: float = n["scale"] * size_factor(id)
	for stage: Dictionary in TREE_STAGES:
		if s <= stage["up_to"]:
			return stage
	return TREE_STAGES[-1]


func _hits_for(id: int) -> int:
	if is_tree(id):
		return tree_stage(id)["hits"]
	return TYPES[_nodes[id]["type"]]["hits"]


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


## The action: one hit on a node, taking `power` hits off it (0 = a glancing blow that does
## nothing, e.g. a pickaxe too weak for the ore). `luck` is the chance of one extra drop.
## Returns true if that hit depleted it.
func hit_node(id: int, power := 1, luck := 0.0) -> bool:
	var n := _nodes[id]
	if n["respawn_at"] >= 0.0:
		return false
	n["hits_left"] = maxi(n["hits_left"] - power, 0)
	hit.emit(id, n["hits_left"])
	if n["hits_left"] > 0:
		return false
	var info: Dictionary = TYPES[n["type"]]
	n["respawn_at"] = _now() + info["respawn"]
	var drops: Array = []
	var table: Array = info["drops"]
	if is_tree(id):
		var stage := tree_stage(id)
		table = [["wood", stage["wood"][0], stage["wood"][1], 1.0], ["resin", 1, 1, stage["resin"]]]
		if n["type"] == "apple_tree":
			table.append(["apple", 1, 3, 1.0])
	for d: Array in table:
		if _rng.randf() <= d[3]:
			for i in _rng.randi_range(d[1], d[2]):
				drops.append(d[0])
	if not drops.is_empty() and _rng.randf() < luck:      # skill level or a Lucky tool
		drops.append(drops[_rng.randi() % drops.size()])
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
			if is_tree(id):
				n["growth"] = 0.0          # comes back as a sapling
			n["hits_left"] = _hits_for(id)
			respawned.emit(id)
		elif n["respawn_at"] < 0.0 and n["growth"] < 1.0:
			var before: float = n["growth"]
			var hits_before := _hits_for(id)
			n["growth"] = minf(1.0, before + 1.0 / GROW_TIME)
			n["hits_left"] += _hits_for(id) - hits_before      # a bigger size takes more hits
			if floori(before * 20.0) != floori(n["growth"] * 20.0) or n["growth"] >= 1.0:
				grown.emit(id, size_factor(id))


## Plain data for the save file: [hits_left, growth, seconds until regrowth or -1] per node.
## Nodes are placed in the same order every run, so the list index is the id.
func to_data() -> Array:
	var now := _now()
	var out := []
	for n in _nodes:
		var wait: float = n["respawn_at"] - now if n["respawn_at"] >= 0.0 else -1.0
		out.append([n["hits_left"], snappedf(n["growth"], 0.001), snappedf(wait, 0.1)])
	return out


## A fingerprint of where every node stands, so a save from an older world layout is ignored.
func layout_id() -> int:
	var h := _nodes.size()
	for n in _nodes:
		var p: Vector3 = n["pos"]
		h = hash([h, snappedf(p.x, 0.01), snappedf(p.z, 0.01), n["type"]])
	return h


## Applies a save (after the world has been placed). Ignored if the world layout changed.
func load_data(data: Array) -> void:
	if data.size() != _nodes.size():
		return
	var now := _now()
	for id in _nodes.size():
		var d: Array = data[id]
		var n := _nodes[id]
		n["growth"] = clampf(d[1], 0.0, 1.0)
		n["respawn_at"] = now + maxf(d[2], 0.0) if d[2] >= 0.0 else -1.0
		n["hits_left"] = clampi(int(d[0]), 1, _hits_for(id))
	loaded.emit()


## Forgets every node (starting over; the world places them again).
func reset() -> void:
	_nodes.clear()
	_grid.clear()


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
