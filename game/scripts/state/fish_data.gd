class_name FishData
extends RefCounted
## Fishing as plain data: which fish live in which water, how hard each fights, and your best catches
## (saved). The fishing itself is player/fisher.gd; the screen is ui/fishing_ui.gd.

## Per fish: the waters it lives in, how often it bites (weight), its size range (cm), and the fight:
## pull (how hard its surges yank the line, 0..1), zone (how wide the safe tension band is) and rate
## (how fast you bring it in while the tension is right). "time": only by "day" or only at "night".
const FISH := {
	"bluegill": {"waters": ["meadow"], "weight": 10.0, "size": [12, 22], "pull": 0.3, "zone": 0.42, "rate": 0.5},
	"perch": {"waters": ["meadow", "forest", "highlands"], "weight": 8.0, "size": [15, 32], "pull": 0.42, "zone": 0.38, "rate": 0.42},
	"trout": {"waters": ["forest", "highlands"], "weight": 10.0, "size": [20, 42], "pull": 0.45, "zone": 0.36, "rate": 0.44},
	"pike": {"waters": ["forest"], "weight": 4.0, "size": [45, 95], "pull": 0.65, "zone": 0.3, "rate": 0.33},
	"golden_carp": {"waters": ["meadow"], "weight": 1.5, "size": [40, 72], "pull": 0.72, "zone": 0.27, "rate": 0.28, "time": "day"},
	"ghost_koi": {"waters": ["forest"], "weight": 2.0, "size": [35, 62], "pull": 0.72, "zone": 0.25, "rate": 0.3, "time": "night"},
	"cavefish": {"waters": ["cave"], "weight": 10.0, "size": [10, 22], "pull": 0.4, "zone": 0.38, "rate": 0.5},
	"glimmer_eel": {"waters": ["cave"], "weight": 3.0, "size": [50, 115], "pull": 0.85, "zone": 0.24, "rate": 0.26},
	"old_boot": {"waters": ["meadow", "forest", "highlands"], "weight": 1.5, "size": [27, 30], "pull": 0.12, "zone": 0.5, "rate": 0.8},
}
const WATER_NAMES := {"meadow": "Meadow Pond", "forest": "Wood Pond", "highlands": "Stonecrest Tarn", "cave": "Glimmerdeep Pool"}

static var best := {}            # fish id -> biggest size caught (cm)


## What bites here: [fish id, size in cm].
static func roll(water: String, night: bool) -> Array:
	var pool := []
	var total := 0.0
	for id: String in FISH:
		var f: Dictionary = FISH[id]
		if not water in f["waters"]:
			continue
		if f.get("time", "") == "day" and night or f.get("time", "") == "night" and not night:
			continue
		pool.append(id)
		total += f["weight"]
	var pick := randf() * total
	for id: String in pool:
		pick -= FISH[id]["weight"]
		if pick <= 0.0:
			return [id, _size(id)]
	return [pool[0], _size(pool[0])]


## Sizes lean small: a big one is a real find.
static func _size(id: String) -> int:
	var s: Array = FISH[id]["size"]
	return roundi(lerpf(s[0], s[1], pow(randf(), 1.8)))


## How big a fight this one puts up (0..1 of its size range): bigger fish pull harder.
static func heft(id: String, size: int) -> float:
	var s: Array = FISH[id]["size"]
	return clampf(inverse_lerp(s[0], s[1], size), 0.0, 1.0)


## The action: note a catch. Returns "first", "record" or "".
static func record(id: String, size: int) -> String:
	if not best.has(id):
		best[id] = size
		return "first"
	if size > best[id]:
		best[id] = size
		return "record"
	return ""


static func to_data() -> Dictionary:
	return best.duplicate()


static func load_data(data: Dictionary) -> void:
	best = {}
	for id: String in data:
		if FISH.has(id):
			best[id] = int(data[id])
