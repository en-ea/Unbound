extends Node
## Your tools and weapon (game state, no visuals): which tiers you own per slot and which one is
## equipped. Better tiers hit harder and swing faster. Crafting happens here too (recipes cost
## Inventory items), so every change goes through craft() and equip().

signal changed

const SLOTS := {"axe": "Axe", "pickaxe": "Pickaxe", "sword": "Sword"}
## power: hits dealt per swing (and sword damage); speed: swing speed multiplier.
const TIERS := [
	{"name": "Worn", "color": Color(0.58, 0.5, 0.44), "power": 1, "speed": 0.85},
	{"name": "Stone", "color": Color(0.66, 0.66, 0.64), "power": 1, "speed": 1.0},
	{"name": "Copper", "color": Color(0.9, 0.52, 0.3), "power": 2, "speed": 1.08},
	{"name": "Iron", "color": Color(0.82, 0.86, 0.92), "power": 3, "speed": 1.16},
]
## What each tool costs at the workbench.
const RECIPES := [
	{"slot": "axe", "tier": 1, "cost": {"wood": 4, "stone": 3, "flint": 1}},
	{"slot": "pickaxe", "tier": 1, "cost": {"wood": 4, "stone": 4, "flint": 1}},
	{"slot": "sword", "tier": 1, "cost": {"wood": 3, "stone": 5, "flint": 2}},
	{"slot": "axe", "tier": 2, "cost": {"wood": 4, "copper": 5, "hide": 1}},
	{"slot": "pickaxe", "tier": 2, "cost": {"wood": 4, "copper": 6, "hide": 1}},
	{"slot": "sword", "tier": 2, "cost": {"wood": 3, "copper": 7, "hide": 2}},
	{"slot": "axe", "tier": 3, "cost": {"wood": 4, "iron": 5, "resin": 1}},
	{"slot": "pickaxe", "tier": 3, "cost": {"wood": 4, "iron": 6, "resin": 1}},
	{"slot": "sword", "tier": 3, "cost": {"wood": 3, "iron": 7, "pelt": 2, "fang": 1}},
]

var owned := {"axe": [0], "pickaxe": [0], "sword": [0]}
var equipped := {"axe": 0, "pickaxe": 0, "sword": 0}


func tier(slot: String) -> int:
	return equipped.get(slot, 0)


func power(slot: String) -> int:
	return TIERS[tier(slot)]["power"]


func speed(slot: String) -> float:
	return TIERS[tier(slot)]["speed"]


func color(slot: String) -> Color:
	return TIERS[tier(slot)]["color"]


static func tool_name(slot: String, t: int) -> String:
	return "%s %s" % [TIERS[t]["name"], SLOTS[slot]]


func owns(slot: String, t: int) -> bool:
	return t in owned[slot]


func can_afford(recipe: Dictionary) -> bool:
	for item: String in recipe["cost"]:
		if Inventory.count(item) < recipe["cost"][item]:
			return false
	return true


## The action: craft a recipe. Spends the items, gives the tool and equips it if it's better.
func craft(recipe: Dictionary) -> bool:
	var slot: String = recipe["slot"]
	var t: int = recipe["tier"]
	if owns(slot, t) or not can_afford(recipe):
		return false
	for item: String in recipe["cost"]:
		Inventory.remove(item, recipe["cost"][item])
	owned[slot].append(t)
	if t > equipped[slot]:
		equipped[slot] = t
	changed.emit()
	return true


## The action: switch to another tool you own.
func equip(slot: String, t: int) -> void:
	if owns(slot, t) and equipped[slot] != t:
		equipped[slot] = t
		changed.emit()


func to_data() -> Dictionary:
	return {"owned": owned, "equipped": equipped}


func load_data(data: Dictionary) -> void:
	for slot: String in SLOTS:
		var have: Array = data.get("owned", {}).get(slot, [0])
		owned[slot] = have.map(func(t: Variant) -> int: return clampi(int(t), 0, TIERS.size() - 1))
		if not 0 in owned[slot]:
			owned[slot].append(0)
		var e := int(data.get("equipped", {}).get(slot, 0))
		equipped[slot] = e if e in owned[slot] else 0
	changed.emit()
