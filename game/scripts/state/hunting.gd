extends Node
## Hunting (game state, no visuals). Big kills leave a body (world/carcass.gd). You carve it where it lies
## (quick: basic meat and hide), or take the whole body to the butcher's rack in the village (more coins and
## the good parts: clean hides, antlers, trophies). Bodies rot: worth less, then gone. The ox cart carries
## up to three; where it is and what's in it is saved here. Actions: carve(), sell().

signal changed
signal sold(kind: String)

## Each kind of body: its name, how big (big and huge can't go on your shoulder; huge only in the cart),
## what carving gives [item, count, chance], and what the butcher gives for the whole body.
const KINDS := {
	"stag": {"name": "Stag", "size": "big", "carve": [["raw_meat", 2, 1.0], ["stag_hide", 1, 1.0], ["antler", 1, 0.35]],
		"coins": 70, "parts": {"raw_meat": 3, "stag_hide": 2, "crown_antlers": 1}},
	"boar": {"name": "Boar", "size": "big", "carve": [["hide", 1, 1.0], ["raw_meat", 1, 0.8], ["tusk", 1, 0.3]],
		"coins": 40, "parts": {"hide": 2, "raw_meat": 2, "tusk": 2}},
	"wolf": {"name": "Wolf", "size": "medium", "carve": [["pelt", 1, 1.0], ["raw_meat", 1, 0.5], ["fang", 1, 0.3]],
		"coins": 30, "parts": {"pelt": 2, "fang": 1}},
	"shadow_wolf": {"name": "Shadow Wolf", "size": "big", "carve": [["shadow_pelt", 1, 1.0], ["fang", 1, 0.6]],
		"coins": 80, "parts": {"shadow_pelt": 2, "fang": 2}},
	"duskmaw": {"name": "Duskmaw", "size": "huge", "carve": [["duskmaw_fang", 1, 1.0], ["shadow_pelt", 2, 1.0]],
		"coins": 300, "parts": {"duskmaw_fang": 2, "shadow_pelt": 4}},
}

## The ox cart: which region, where, facing, and the bodies in it ({kind, age}).
var cart := {"region": "meadow", "at": Vector2(-21.0, 33.0), "yaw": 0.0, "load": []}
var riding := false            # you were on the cart when you went through a gate (carried over)
var carried := {}              # a body you were dragging through a gate: {kind, age}
var sold_count := {}           # kind -> whole bodies sold (for jobs and bragging)


## How fresh a body is from its age (1 = fresh, 0 = rotten away).
static func freshness(age: float) -> float:
	var h: Dictionary = Balance.HUNT
	return clampf(1.0 - (age - h["fresh_for"]) / h["rot_time"], 0.0, 1.0)


## The action: carve a body where it lies. Rot takes some of it. Returns what you got.
func carve(kind: String, fresh: float) -> Dictionary:
	var got := {}
	for entry: Array in KINDS[kind]["carve"]:
		var n: int = entry[1]
		if fresh < 0.5 and entry[0] == "raw_meat":
			n = 0                                  # rotten meat isn't worth taking
		for i in n:
			if randf() < entry[2]:
				got[entry[0]] = got.get(entry[0], 0) + 1
	for item: String in got:
		Inventory.add(item, got[item])
	return got


## The action: the butcher takes a whole body. Coins shrink with rot; the good parts only if it's fresh.
func sell(kind: String, fresh: float) -> Dictionary:
	var def: Dictionary = KINDS[kind]
	var coins := maxi(5, roundi(def["coins"] * lerpf(0.25, 1.0, fresh)))
	Money.earn(coins)
	var got := {}
	for item: String in def["parts"]:
		var n: int = def["parts"][item]
		if fresh < 0.6 and item in ["raw_meat", "crown_antlers"]:
			n = 0 if item == "raw_meat" else n
		if fresh < 0.35:
			n = mini(n, 1)
		if n > 0:
			got[item] = n
			Inventory.add(item, n)
	sold_count[kind] = sold_count.get(kind, 0) + 1
	sold.emit(kind)
	Quests.note("sold_" + kind)
	return {"coins": coins, "items": got}


func load_cart(kind: String, age: float) -> bool:
	if cart["load"].size() >= Balance.HUNT["cart_slots"]:
		return false
	cart["load"].append({"kind": kind, "age": age})
	changed.emit()
	return true


func to_data() -> Dictionary:
	var c := cart.duplicate(true)
	c["at"] = [cart["at"].x, cart["at"].y]
	return {"cart": c, "sold": sold_count.duplicate()}


func load_data(data: Variant) -> void:
	var d: Dictionary = data if data is Dictionary else {}
	var c: Dictionary = d.get("cart", {})
	cart = {"region": "meadow", "at": Vector2(-21.0, 33.0), "yaw": 0.0, "load": []}
	if not c.is_empty():
		cart["region"] = str(c.get("region", "meadow"))
		var at: Array = c.get("at", [-21.0, 33.0])
		cart["at"] = Vector2(float(at[0]), float(at[1]))
		cart["yaw"] = float(c.get("yaw", 0.0))
		for b: Variant in c.get("load", []):
			if b is Dictionary and (KINDS.has(str(b.get("kind", ""))) or str(b.get("kind", "")) == "_"):
				cart["load"].append({"kind": str(b["kind"]), "age": float(b.get("age", 0.0))})
	sold_count = d.get("sold", {})
	changed.emit()
