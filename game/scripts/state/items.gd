class_name Items
extends RefCounted
## Every item in the game: display name, colour (for icons and drops), rarity and drop shape.

enum Rarity { COMMON, UNCOMMON, RARE }

const DEFS := {
	"wood": {"name": "Wood", "color": Color(0.62, 0.43, 0.26), "rarity": Rarity.COMMON, "shape": "log"},
	"stone": {"name": "Stone", "color": Color(0.62, 0.62, 0.6), "rarity": Rarity.COMMON, "shape": "rock"},
	"apple": {"name": "Apple", "color": Color(0.85, 0.2, 0.15), "rarity": Rarity.COMMON, "shape": "ball"},
	"mushroom": {"name": "Mushroom", "color": Color(0.86, 0.52, 0.32), "rarity": Rarity.COMMON, "shape": "cap"},
	"flower": {"name": "Wildflower", "color": Color(0.9, 0.5, 0.75), "rarity": Rarity.COMMON, "shape": "ball"},
	"flint": {"name": "Flint", "color": Color(0.3, 0.3, 0.34), "rarity": Rarity.UNCOMMON, "shape": "rock"},
	"resin": {"name": "Amber Resin", "color": Color(1.0, 0.68, 0.2), "rarity": Rarity.RARE, "shape": "gem"},
	"glowcap": {"name": "Glowcap", "color": Color(0.45, 1.0, 0.75), "rarity": Rarity.RARE, "shape": "cap"},
	"shard": {"name": "Glimmer Shard", "color": Color(0.5, 0.85, 1.0), "rarity": Rarity.RARE, "shape": "gem"},
}

const RARITY_COLORS := {
	Rarity.COMMON: Color(1, 1, 1, 0.25),
	Rarity.UNCOMMON: Color(0.55, 0.9, 0.5),
	Rarity.RARE: Color(1.0, 0.78, 0.3),
}


static func name_of(id: String) -> String:
	return DEFS[id]["name"]


static func color_of(id: String) -> Color:
	return DEFS[id]["color"]


static func rarity_of(id: String) -> int:
	return DEFS[id]["rarity"]
