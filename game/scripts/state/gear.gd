extends Node
## Your tools, weapon and bag (game state, no visuals). Each tool is a small record: its tier
## (Worn, Stone, Copper, Iron), its rarity (0 common = crafted, 1 uncommon, 2 rare = found) and
## its bonuses. One per slot is equipped; with none you use your fists. Every change goes through
## craft(), give(), equip(), drop_tool() and craft_bag().

signal changed

const SLOTS := {"axe": "Axe", "pickaxe": "Pickaxe", "sword": "Sword"}
## power: hits taken off a tree or rock per swing; damage: sword damage (boar 10, wolf 6);
## speed: swing speed multiplier. Every tier is a clear step up. Fists: power 1, damage 1.
const TIERS := [
	{"name": "Worn", "color": Color(0.58, 0.5, 0.44), "power": 2, "damage": 2, "speed": 0.85},
	{"name": "Stone", "color": Color(0.33, 0.33, 0.32), "power": 3, "damage": 3, "speed": 1.0},
	{"name": "Copper", "color": Color(0.9, 0.52, 0.3), "power": 4, "damage": 4, "speed": 1.08},
	{"name": "Iron", "color": Color(0.82, 0.86, 0.92), "power": 6, "damage": 5, "speed": 1.16},
]
## Bonuses found tools can roll: Swift swings 15% faster, Mighty hits 1 harder, Lucky gives a
## 20% chance of an extra drop. Rare tools have two. [adjective, noun] for the name.
const BONUSES := {"swift": ["Swift", "Haste"], "mighty": ["Mighty", "Might"], "lucky": ["Lucky", "Luck"]}
## What a tier unlocks for a tool, shown at the workbench.
const PERKS := {"pickaxe": {1: "Mines copper ore", 2: "Mines iron ore"}}
## What each tool costs at the workbench (a Worn one is cheap, if you ever drop yours).
const RECIPES := [
	{"slot": "axe", "tier": 0, "cost": {"wood": 3, "stone": 2}},
	{"slot": "pickaxe", "tier": 0, "cost": {"wood": 3, "stone": 2}},
	{"slot": "sword", "tier": 0, "cost": {"wood": 3, "stone": 2}},
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
## Bags: how many different kinds of item you can carry. The first is what you start with.
const BAGS := [
	{"name": "Pouch", "slots": 12},
	{"name": "Leather Bag", "slots": 16, "cost": {"hide": 4, "wood": 4, "flint": 2}},
	{"name": "Traveller's Pack", "slots": 22, "cost": {"pelt": 3, "hide": 3, "resin": 2}},
]

var owned := {"axe": [_tool(0)], "pickaxe": [_tool(0)], "sword": [_tool(0)]}
var equipped := {"axe": 0, "pickaxe": 0, "sword": 0}      # index into owned[slot], -1 = fists
var bag := 0


static func _tool(tier_index: int, rarity := 0, bonuses: Array = []) -> Dictionary:
	return {"tier": tier_index, "rarity": rarity, "bonuses": bonuses}


## The equipped tool's record, or {} when you have none.
func current(slot: String) -> Dictionary:
	var i: int = equipped[slot]
	return owned[slot][i] if i >= 0 and i < owned[slot].size() else {}


func tier(slot: String) -> int:
	return current(slot).get("tier", -1)


func power(slot: String) -> int:
	var t := current(slot)
	if t.is_empty():
		return 1
	return TIERS[t["tier"]]["power"] + (1 if "mighty" in t["bonuses"] else 0)


func damage() -> int:
	var t := current("sword")
	var base: int = 1 if t.is_empty() else TIERS[t["tier"]]["damage"] + (1 if "mighty" in t["bonuses"] else 0)
	return base + Skills.damage_bonus()


func speed(slot: String) -> float:
	var t := current(slot)
	if t.is_empty():
		return 1.0
	return TIERS[t["tier"]]["speed"] * (1.15 if "swift" in t["bonuses"] else 1.0)


## Chance of an extra drop from the tool's Lucky bonus.
func luck(slot: String) -> float:
	return 0.2 if "lucky" in current(slot).get("bonuses", []) else 0.0


func color(slot: String) -> Color:
	var t := tier(slot)
	return TIERS[t]["color"] if t >= 0 else Color.WHITE


## "Swift Copper Axe", "Mighty Iron Sword of Luck", or "Fists".
static func name_of(slot: String, t: Dictionary) -> String:
	if t.is_empty():
		return "Fists"
	var base := "%s %s" % [TIERS[t["tier"]]["name"], SLOTS[slot]]
	var b: Array = t["bonuses"]
	if b.size() >= 1:
		base = "%s %s" % [BONUSES[b[0]][0], base]
	if b.size() >= 2:
		base = "%s of %s" % [base, BONUSES[b[1]][1]]
	return base


static func tool_name(slot: String, tier_index: int) -> String:
	return name_of(slot, _tool(tier_index)) if tier_index >= 0 else "Fists"


## The highest tier you have for a slot (-1 with none); the workbench offers the next one.
func best_tier(slot: String) -> int:
	var best := -1
	for t: Dictionary in owned[slot]:
		best = maxi(best, t["tier"])
	return best


func can_afford(cost: Dictionary) -> bool:
	for item: String in cost:
		if Inventory.count(item) < cost[item]:
			return false
	return true


func _spend(cost: Dictionary) -> void:
	for item: String in cost:
		Inventory.remove(item, cost[item])


## The action: craft a tool recipe. Spends the items and gives (and equips) a plain tool.
func craft(recipe: Dictionary) -> bool:
	var slot: String = recipe["slot"]
	if recipe["tier"] != best_tier(slot) + 1 or not can_afford(recipe["cost"]):
		return false
	_spend(recipe["cost"])
	give(slot, _tool(recipe["tier"]))
	return true


## The action: a tool joins your gear (crafted or found). It's equipped if it beats yours.
func give(slot: String, t: Dictionary) -> void:
	owned[slot].append(t)
	var now := current(slot)
	if now.is_empty() or t["tier"] > now["tier"] or (t["tier"] == now["tier"] and t["rarity"] > now["rarity"]):
		equipped[slot] = owned[slot].size() - 1
	changed.emit()


## The action: switch to another tool you own.
func equip(slot: String, index: int) -> void:
	if index >= 0 and index < owned[slot].size() and equipped[slot] != index:
		equipped[slot] = index
		changed.emit()


## The action: throw away the equipped tool; the best one left takes its place (or fists).
func drop_tool(slot: String) -> void:
	var i: int = equipped[slot]
	if i < 0:
		return
	owned[slot].remove_at(i)
	var best := -1
	for k in owned[slot].size():
		if best < 0 or owned[slot][k]["tier"] > owned[slot][best]["tier"]:
			best = k
	equipped[slot] = best
	changed.emit()


## A random tool found in a chest or on an enemy: around the tiers you have, sometimes one
## better; uncommon (one bonus) or rare (two). Returns [slot, tool].
func roll_found() -> Array:
	var slot: String = SLOTS.keys().pick_random()
	var t := clampi(best_tier(slot) + (1 if randf() < 0.2 else -randi_range(0, 1)), 0, TIERS.size() - 1)
	var rare := randf() < 0.25
	var pool := BONUSES.keys()
	pool.shuffle()
	return [slot, _tool(t, 2 if rare else 1, pool.slice(0, 2 if rare else 1))]


func bag_slots() -> int:
	return BAGS[bag]["slots"]


## The action: craft the next bag.
func craft_bag() -> bool:
	if bag + 1 >= BAGS.size() or not can_afford(BAGS[bag + 1]["cost"]):
		return false
	_spend(BAGS[bag + 1]["cost"])
	bag += 1
	changed.emit()
	return true


func to_data() -> Dictionary:
	return {"owned": owned, "equipped": equipped, "bag": bag}


func load_data(data: Dictionary) -> void:
	for slot: String in SLOTS:
		var list: Array = data.get("owned", {}).get(slot, [_tool(0)])
		var old_save := not list.is_empty() and not list[0] is Dictionary     # older saves: plain tiers
		owned[slot] = []
		for entry: Variant in list:
			if entry is Dictionary:
				var bonuses: Array = entry.get("bonuses", []).filter(func(b: Variant) -> bool: return BONUSES.has(b))
				owned[slot].append(_tool(clampi(int(entry.get("tier", 0)), 0, TIERS.size() - 1), clampi(int(entry.get("rarity", 0)), 0, 2), bonuses))
			else:
				owned[slot].append(_tool(clampi(int(entry), 0, TIERS.size() - 1)))
		var e := int(data.get("equipped", {}).get(slot, 0))
		if old_save:                            # the old save stored the equipped tier
			var at := 0
			for k in list.size():
				if int(list[k]) == e:
					at = k
			e = at
		equipped[slot] = clampi(e, -1, owned[slot].size() - 1)
	bag = clampi(int(data.get("bag", 0)), 0, BAGS.size() - 1)
	changed.emit()
