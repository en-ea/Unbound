class_name Loot
extends RefCounted
## Rarities and bonuses for gear (numbers in Balance: RARITIES, LOOT_ODDS, LOOT_KINDS, BONUSES).
## A piece of gear is a small record: {"tier", "rarity", "bonuses": {id: value}}; tools and weapons
## live in Gear, armour in Armor. Pure data and rolls, no visuals.

const COMMON := 0
const UNCOMMON := 1
const RARE := 2
const EPIC := 3
const LEGENDARY := 4
const MYTHIC := 5
## Mythic pieces get a name of their own instead of an adjective.
const MYTHIC_NAMES := ["Emberfang", "Dawnbreaker", "Veilpiercer", "Oathkeeper", "Stormcall", "Gloamspire", "Thornheart", "Starwake"]


static func rarity_name(r: int) -> String:
	return Balance.RARITIES[clampi(r, 0, MYTHIC)]["name"]


static func rarity_color(r: int) -> Color:
	return Balance.RARITIES[clampi(r, 0, MYTHIC)]["color"]


static func stat(r: int) -> float:
	return Balance.RARITIES[clampi(r, 0, MYTHIC)]["stat"]


## A rarity for a find from `source` (enemy, elite, chest, trader).
static func roll_rarity(source: String) -> int:
	var odds: Array = Balance.LOOT_ODDS.get(source, Balance.LOOT_ODDS["enemy"])
	return _pick_weighted(odds)


## What kind of gear a find is: weapon, tool or armor.
static func roll_kind() -> String:
	var kinds := Balance.LOOT_KINDS.keys()
	return kinds[_pick_weighted(kinds.map(func(k: String) -> float: return Balance.LOOT_KINDS[k]))]


## Rolls the rarity's number of different bonuses that suit `kind`, stronger at higher rarities.
static func roll_bonuses(kind: String, rarity: int) -> Dictionary:
	var pool: Array = Balance.BONUSES.keys().filter(func(id: String) -> bool: return kind in Balance.BONUSES[id]["on"])
	pool.shuffle()
	var out := {}
	for id: String in pool.slice(0, Balance.RARITIES[rarity]["bonuses"]):
		out[id] = bonus_value(id, rarity, randf())
	return out


static func bonus_value(id: String, rarity: int, roll: float) -> int:
	var r: Array = Balance.BONUSES[id]["range"]
	var t := clampf((rarity - 1 + roll) / 5.0, 0.0, 1.0)      # uncommon starts low, mythic reaches the top
	return maxi(roundi(lerpf(r[0], r[1], t)), r[0])


## "+12% damage"
static func bonus_text(id: String, value: int) -> String:
	return Balance.BONUSES[id]["text"] % value


## "Sharp Iron Sword of Haste"; Mythic: "Emberfang, Iron Sword". `base` is e.g. "Iron Sword".
static func name_for(base: String, piece: Dictionary) -> String:
	var ids: Array = piece.get("bonuses", {}).keys()
	if piece.get("rarity", 0) == MYTHIC:
		return "%s, %s" % [MYTHIC_NAMES[absi(hash(ids) + int(piece.get("seed", 0))) % MYTHIC_NAMES.size()], base]
	var out := base
	if ids.size() >= 1:
		out = "%s %s" % [Balance.BONUSES[ids[0]]["adj"], out]
	if ids.size() >= 2:
		out = "%s of %s" % [out, Balance.BONUSES[ids[1]]["noun"]]
	return out


## Cleans a saved bonus list: older saves stored ["swift", ...]; now {"swift": 15, ...}.
static func clean_bonuses(raw: Variant, rarity: int) -> Dictionary:
	var out := {}
	if raw is Array:
		for id: Variant in raw:
			if Balance.BONUSES.has(String(id)):
				out[String(id)] = bonus_value(String(id), maxi(rarity, 1), 0.5)
	elif raw is Dictionary:
		for id: Variant in raw:
			if Balance.BONUSES.has(String(id)):
				out[String(id)] = int(raw[id])
	return out


static func _pick_weighted(weights: Array) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	var x := randf() * total
	for i in weights.size():
		x -= weights[i]
		if x <= 0.0:
			return i
	return weights.size() - 1
