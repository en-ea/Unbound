extends Node
## Your tools, weapon and bag (game state, no visuals). Each tool is a small record: its tier
## (Worn, Stone, Copper, Iron, Steel), its rarity (Common = crafted, up to Mythic; see Loot) and its
## bonuses {id: value}. One per slot is equipped; with none you use your fists. Every change goes
## through craft(), give(), equip(), drop_tool() and craft_bag(). Armour lives in Armor.

signal changed
signal tool_dropped(slot: String, tool: Dictionary)

const SLOTS := {"axe": "Axe", "pickaxe": "Pickaxe", "sword": "Sword"}
## power: hits taken off a tree or rock per swing; damage: sword damage (boar 10, wolf 6);
## speed: swing speed multiplier. Every tier is a clear step up. Fists: power 1, damage 1.
const TIERS := Balance.TIERS
## Which loot kind each slot is (for bonuses).
const KIND := {"axe": "tool", "pickaxe": "tool", "sword": "weapon"}
const CRIT_MULT := 2.0
## What a tier unlocks for a tool, shown at the workbench.
const PERKS := {"pickaxe": {1: "Mines copper ore", 2: "Mines iron ore"}}
## What each tool costs at the workbench, and the bags (numbers in Balance).
const RECIPES := Balance.TOOL_RECIPES
const BAGS := Balance.BAGS

var owned := {"axe": [_tool(0)], "pickaxe": [_tool(0)], "sword": [_tool(0)]}
var equipped := {"axe": 0, "pickaxe": 0, "sword": 0}      # index into owned[slot], -1 = fists
var bag := 0
var unlocked := {"axe": 0, "pickaxe": 0, "sword": 0}   # best tier you have ever had
## Bows (a first try): everyone has the Crystal Bow for now. `weapon` is the one you fight with.
const BOW := {"name": "Crystal Bow", "rarity": 3, "glow": Color(0.4, 1.0, 0.95)}
var has_bow := true
var weapon := "sword"


## The action: switch between sword and bow (the Swap button).
func swap_weapon() -> void:
	if has_bow:
		weapon = "bow" if weapon == "sword" else "sword"
		changed.emit()


static func _tool(tier_index: int, rarity := 0, bonuses := {}) -> Dictionary:
	return {"tier": tier_index, "rarity": rarity, "bonuses": bonuses, "seed": randi() % 100000}


## A bonus's value on the equipped tool (0 without it).
func bonus(slot: String, id: String) -> int:
	return current(slot).get("bonuses", {}).get(id, 0)


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
	return roundi(TIERS[t["tier"]]["power"] * Loot.stat(t["rarity"])) + bonus(slot, "mighty")


## Weapon damage per hit: tier x rarity x Sharp, plus skill and food.
func damage() -> int:
	var t := current("sword")
	var base := 1
	if not t.is_empty():
		base = roundi(TIERS[t["tier"]]["damage"] * Loot.stat(t["rarity"]) * (1.0 + bonus("sword", "sharp") / 100.0))
	return base + Skills.damage_bonus() + (Balance.STRONG_DAMAGE if Food.has("strong") else 0)


## One hit's damage, with Keen's chance of a critical: [damage, was_crit].
func hit_damage(multiplier := 1.0) -> Array:
	var crit := randf() < bonus("sword", "keen") / 100.0
	return [ceili(damage() * multiplier * (CRIT_MULT if crit else 1.0)), crit]


## Chance that a hit heals a heart (Vampiric).
func lifesteal() -> float:
	return bonus("sword", "vampiric") / 100.0


func speed(slot: String) -> float:
	var t := current(slot)
	if t.is_empty():
		return 1.0
	return TIERS[t["tier"]]["speed"] * (1.0 + bonus(slot, "swift") / 100.0)


## Chance of an extra drop: the tool's Lucky bonus plus any on your armour.
func luck(slot: String) -> float:
	return (bonus(slot, "lucky") + Armor.bonus_total("lucky")) / 100.0


func color(slot: String) -> Color:
	var t := tier(slot)
	return TIERS[t]["color"] if t >= 0 else Color.WHITE


## "Swift Copper Axe", "Sharp Iron Sword of Haste", "Emberfang, Steel Sword", or "Fists".
## Works for armour too (the slot says which).
static func name_of(slot: String, t: Dictionary) -> String:
	if Armor.SLOTS.has(slot):
		return Armor.name_of(slot, t)
	if t.is_empty():
		return "Fists"
	return Loot.name_for("%s %s" % [TIERS[t["tier"]]["name"], SLOTS[slot]], t)


## One line per bonus, for the Bag and the pickup card.
static func bonus_lines(t: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in t.get("bonuses", {}):
		out.append(Loot.bonus_text(id, t["bonuses"][id]))
	return out


## The action: a found piece of gear (a tool, the weapon or armour) joins your gear.
func take(slot: String, t: Dictionary) -> void:
	if Armor.SLOTS.has(slot):
		Armor.give(slot, t)
	else:
		give(slot, t)


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


## Tiers the workbench can make for a slot: any up to one past the best you've ever had,
## except ones you're carrying already.
func craftable_tiers(slot: String) -> Array[int]:
	var out: Array[int] = []
	for t in mini(unlocked[slot] + 1, TIERS.size() - 1) + 1:
		var needs: String = recipe_for(slot, t).get("needs", "")
		if needs != "" and not Projects.is_built(needs):
			continue
		if not owned[slot].any(func(o: Dictionary) -> bool: return o["tier"] == t):
			out.append(t)
	return out


func recipe_for(slot: String, t: int) -> Dictionary:
	for r: Dictionary in RECIPES:
		if r["slot"] == slot and r["tier"] == t:
			return r
	return {}


## The action: craft a tool recipe. Spends the items and gives (and equips) a plain tool.
func craft(recipe: Dictionary) -> bool:
	var slot: String = recipe["slot"]
	if not recipe["tier"] in craftable_tiers(slot) or not can_afford(recipe["cost"]):
		return false
	_spend(recipe["cost"])
	give(slot, _tool(recipe["tier"]))
	return true


## The action: a tool joins your gear (crafted or found). It's equipped if it beats yours.
func give(slot: String, t: Dictionary) -> void:
	owned[slot].append(t)
	unlocked[slot] = maxi(unlocked[slot], t["tier"])
	var now := current(slot)
	if now.is_empty() or score(t) > score(now):
		equipped[slot] = owned[slot].size() - 1
	changed.emit()


## How good a piece is overall, for "is this better?" (tier first, then rarity).
static func score(t: Dictionary) -> float:
	return t.get("tier", -1) * 1.0 + Loot.stat(t.get("rarity", 0)) - 1.0 + t.get("bonuses", {}).size() * 0.05


## The action: switch to another tool you own.
func equip(slot: String, index: int) -> void:
	if index >= 0 and index < owned[slot].size() and equipped[slot] != index:
		equipped[slot] = index
		changed.emit()


## The action: put down a tool (the equipped one unless `index` says another); it lands in the
## world (see tool_drop.gd). If it was the equipped one, the best one left takes its place, or fists.
func drop_tool(slot: String, index := -1) -> void:
	var i: int = equipped[slot] if index < 0 else index
	if i < 0 or i >= owned[slot].size():
		return
	var t: Dictionary = owned[slot][i]
	owned[slot].remove_at(i)
	tool_dropped.emit(slot, t)
	if i != equipped[slot]:
		if equipped[slot] > i:
			equipped[slot] -= 1
		changed.emit()
		return
	var best := -1
	for k in owned[slot].size():
		if best < 0 or score(owned[slot][k]) > score(owned[slot][best]):
			best = k
	equipped[slot] = best
	changed.emit()


## A random piece of gear found in a chest, on an enemy or at the trader (`source` sets the rarity
## odds, see Balance.LOOT_ODDS): a weapon, a gathering tool or armour, around the tiers you have,
## sometimes one better. Returns [slot, record].
func roll_found(source := "enemy") -> Array:
	var kind := Loot.roll_kind()
	var rarity := Loot.roll_rarity(source)
	if kind == "armor":
		return Armor.roll(rarity)
	var slot: String = "sword" if kind == "weapon" else ["axe", "pickaxe"].pick_random()
	var t := clampi(unlocked[slot] + (1 if randf() < Balance.FOUND_TIER_UP else -randi_range(0, 1)), 0, TIERS.size() - 1)
	return [slot, _tool(t, rarity, Loot.roll_bonuses(KIND[slot], rarity))]


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
	return {"owned": owned, "equipped": equipped, "bag": bag, "unlocked": unlocked, "weapon": weapon}


func load_data(data: Dictionary) -> void:
	weapon = "bow" if data.get("weapon", "sword") == "bow" and has_bow else "sword"
	for slot: String in SLOTS:
		var list: Array = data.get("owned", {}).get(slot, [_tool(0)])
		var old_save := not list.is_empty() and not list[0] is Dictionary     # older saves: plain tiers
		owned[slot] = []
		for entry: Variant in list:
			if entry is Dictionary:
				var rarity := clampi(int(entry.get("rarity", 0)), 0, Loot.MYTHIC)
				var t := _tool(clampi(int(entry.get("tier", 0)), 0, TIERS.size() - 1), rarity, Loot.clean_bonuses(entry.get("bonuses", {}), rarity))
				t["seed"] = int(entry.get("seed", t["seed"]))
				owned[slot].append(t)
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
	for slot: String in SLOTS:
		unlocked[slot] = clampi(maxi(int(data.get("unlocked", {}).get(slot, 0)), best_tier(slot)), 0, TIERS.size() - 1)
	changed.emit()
