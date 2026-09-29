extends Node
## Your armour (game state, no visuals): pieces you own for the helm, chest and boots slots, which
## one of each you wear, and whether the helm shows. A piece is a record like a tool's:
## {"tier", "rarity", "bonuses", "seed"}; tiers and defence are in Balance.ARMOR_TIERS. Changes go
## through give(), equip(), unequip() and set_show_helm(). Worn armour shows on your character.

signal changed
signal dropped(slot: String, piece: Dictionary)

const SLOTS := {"helm": "Helm", "chest": "Chestplate", "boots": "Boots"}
const TIERS := Balance.ARMOR_TIERS

var owned := {"helm": [], "chest": [], "boots": []}
var equipped := {"helm": -1, "chest": -1, "boots": -1}     # index into owned[slot], -1 = none
var show_helm := false            # off: your chosen headwear shows even with a helm on


static func piece(tier: int, rarity := 0, bonuses := {}) -> Dictionary:
	return {"tier": tier, "rarity": rarity, "bonuses": bonuses, "seed": randi() % 100000}


func current(slot: String) -> Dictionary:
	var i: int = equipped[slot]
	return owned[slot][i] if i >= 0 and i < owned[slot].size() else {}


## One piece's defence: tier defence x its slot's share x rarity, plus Sturdy.
static func piece_defence(slot: String, p: Dictionary) -> int:
	if p.is_empty():
		return 0
	var base: float = TIERS[p["tier"]]["defence"] * Balance.ARMOR_SHARE[slot] * Loot.stat(p["rarity"])
	return roundi(base) + int(p.get("bonuses", {}).get("sturdy", 0))


## Total defence of what you wear.
func defence() -> int:
	var total := 0
	for slot: String in SLOTS:
		total += piece_defence(slot, current(slot))
	return total


## The chance a hit costs you no heart (see Balance.ARMOR_HALF).
func block_chance() -> float:
	var d := float(defence())
	return d / (d + Balance.ARMOR_HALF)


## A bonus summed over everything you wear (Fleet, Mending, Lucky...).
func bonus_total(id: String) -> int:
	var total := 0
	for slot: String in SLOTS:
		total += int(current(slot).get("bonuses", {}).get(id, 0))
	return total


## "Sturdy Iron Chestplate of Wind"
static func name_of(slot: String, p: Dictionary) -> String:
	if p.is_empty():
		return "No %s" % SLOTS[slot].to_lower()
	return Loot.name_for("%s %s" % [TIERS[p["tier"]]["name"], SLOTS[slot]], p)


## A random armour piece of `rarity`, a tier around the best armour you've had. Returns [slot, piece].
func roll(rarity: int) -> Array:
	var slot: String = SLOTS.keys().pick_random()
	var best := 0
	for s: String in SLOTS:
		for p: Dictionary in owned[s]:
			best = maxi(best, p["tier"])
	var tier := clampi(best + (1 if randf() < Balance.FOUND_TIER_UP else -randi_range(0, 1)), 0, TIERS.size() - 1)
	return [slot, piece(tier, rarity, Loot.roll_bonuses("armor", rarity))]


## The action: a piece joins your armour; you put it on if it beats what you wear.
func give(slot: String, p: Dictionary) -> void:
	owned[slot].append(p)
	var now := current(slot)
	if now.is_empty() or Gear.score(p) > Gear.score(now):
		equipped[slot] = owned[slot].size() - 1
	changed.emit()


## The action: wear another piece you own.
func equip(slot: String, index: int) -> void:
	if index >= 0 and index < owned[slot].size() and equipped[slot] != index:
		equipped[slot] = index
		changed.emit()


## The action: take a piece off (it stays in your gear).
func unequip(slot: String) -> void:
	if equipped[slot] != -1:
		equipped[slot] = -1
		changed.emit()


## The action: put a piece down in the world (see tool_drop.gd, via `dropped`).
func drop(slot: String, index: int) -> void:
	if index >= 0 and index < owned[slot].size():
		var p: Dictionary = owned[slot][index]
		discard(slot, index)
		dropped.emit(slot, p)


## The action: remove a piece for good (sold or thrown away).
func discard(slot: String, index: int) -> void:
	if index < 0 or index >= owned[slot].size():
		return
	owned[slot].remove_at(index)
	if equipped[slot] == index:
		equipped[slot] = -1
	elif equipped[slot] > index:
		equipped[slot] -= 1
	changed.emit()


func set_show_helm(on: bool) -> void:
	show_helm = on
	changed.emit()


func to_data() -> Dictionary:
	return {"owned": owned, "equipped": equipped, "helm_shown": show_helm}


func load_data(data: Variant) -> void:
	for slot: String in SLOTS:
		owned[slot] = []
		equipped[slot] = -1
	if data is Dictionary:
		for slot: String in SLOTS:
			for entry: Variant in data.get("owned", {}).get(slot, []):
				if entry is Dictionary:
					var rarity := clampi(int(entry.get("rarity", 0)), 0, Loot.MYTHIC)
					var p := piece(clampi(int(entry.get("tier", 0)), 0, TIERS.size() - 1), rarity, Loot.clean_bonuses(entry.get("bonuses", {}), rarity))
					p["seed"] = int(entry.get("seed", p["seed"]))
					owned[slot].append(p)
			equipped[slot] = clampi(int(data.get("equipped", {}).get(slot, -1)), -1, owned[slot].size() - 1)
		show_helm = bool(data.get("helm_shown", false))
	changed.emit()
