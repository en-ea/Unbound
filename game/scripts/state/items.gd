class_name Items
extends RefCounted
## Every item in the game: display name, colour, rarity. What the trader pays is in Balance.VALUES. Models: tools-src/blender/make_items.py.

enum Rarity { COMMON, UNCOMMON, RARE }

const DEFS := {
	"wood": {"name": "Wood", "color": Color(0.62, 0.43, 0.26), "rarity": Rarity.COMMON},
	"stone": {"name": "Stone", "color": Color(0.62, 0.62, 0.6), "rarity": Rarity.COMMON},
	"apple": {"name": "Apple", "color": Color(0.85, 0.2, 0.15), "rarity": Rarity.COMMON},
	"mushroom": {"name": "Mushroom", "color": Color(0.86, 0.52, 0.32), "rarity": Rarity.COMMON},
	"flower": {"name": "Wildflower", "color": Color(0.9, 0.5, 0.75), "rarity": Rarity.COMMON},
	"flint": {"name": "Flint", "color": Color(0.3, 0.3, 0.34), "rarity": Rarity.UNCOMMON},
	"resin": {"name": "Amber Resin", "color": Color(1.0, 0.68, 0.2), "rarity": Rarity.RARE},
	"glowcap": {"name": "Glowcap", "color": Color(0.45, 1.0, 0.75), "rarity": Rarity.RARE},
	"shard": {"name": "Glimmer Shard", "color": Color(0.5, 0.85, 1.0), "rarity": Rarity.RARE},
	"hide": {"name": "Boar Hide", "color": Color(0.42, 0.34, 0.38), "rarity": Rarity.COMMON},
	"tusk": {"name": "Boar Tusk", "color": Color(0.93, 0.88, 0.74), "rarity": Rarity.UNCOMMON},
	"copper": {"name": "Copper Ore", "color": Color(0.9, 0.55, 0.3), "rarity": Rarity.COMMON},
	"iron": {"name": "Iron Ore", "color": Color(0.72, 0.76, 0.84), "rarity": Rarity.UNCOMMON},
	"pelt": {"name": "Wolf Pelt", "color": Color(0.6, 0.64, 0.72), "rarity": Rarity.UNCOMMON},
	"fang": {"name": "Wolf Fang", "color": Color(0.97, 0.95, 0.88), "rarity": Rarity.RARE},
	"pinewood": {"name": "Pinewood", "color": Color(0.5, 0.33, 0.22), "rarity": Rarity.UNCOMMON},
	"shadow_pelt": {"name": "Shadow Pelt", "color": Color(0.36, 0.32, 0.55), "rarity": Rarity.RARE},
	"raw_meat": {"name": "Raw Meat", "color": Color(0.86, 0.42, 0.42), "rarity": Rarity.COMMON},
	"roast_meat": {"name": "Roast Meat", "color": Color(0.62, 0.34, 0.18), "rarity": Rarity.COMMON},
	"skewer": {"name": "Mushroom Skewer", "color": Color(0.72, 0.42, 0.22), "rarity": Rarity.COMMON},
	"apple_tart": {"name": "Apple Tart", "color": Color(0.85, 0.25, 0.2), "rarity": Rarity.UNCOMMON},
	"tobacco": {"name": "Wild Tobacco", "color": Color(0.5, 0.66, 0.26), "rarity": Rarity.COMMON},
	"cigarette": {"name": "Cigarette", "color": Color(0.96, 0.92, 0.82), "rarity": Rarity.COMMON},
	"stew": {"name": "Forest Stew", "color": Color(0.6, 0.36, 0.2), "rarity": Rarity.UNCOMMON},
}

## What each item is for, in a few words (shown in the Bag).
const DESC := {
	"wood": "Building and crafting.", "stone": "Tools and building.", "pinewood": "Tough forest wood for Steel tools.",
	"flint": "Sharp edges for Stone tools.", "copper": "Copper tools.", "iron": "Iron and Steel tools.",
	"apple": "A snack. Bake into a tart.", "mushroom": "A snack. Cook into skewers or stew.",
	"flower": "For tarts and flower beds.", "raw_meat": "Cook it at a campfire.",
	"resin": "Rare. Iron tools and lanterns.", "glowcap": "Rare glowing mushroom for stew.",
	"shard": "Rare crystal for Steel tools.", "hide": "Boar hide for bags and Copper tools.",
	"tusk": "A boar's tusk. The trader likes it.", "pelt": "Wolf pelt for packs and Iron swords.",
	"fang": "A wolf fang for the best swords.",
	"tobacco": "Wild leaves. Roll them into cigarettes at a campfire.",
	"cigarette": "Take a smoke, nice and slow. Just for the look of it.", "shadow_pelt": "From shadow wolves. Steel swords.",
}
## Loot: things you win from enemies and rare finds (the rest are materials or food).
const LOOT := ["hide", "tusk", "pelt", "fang", "shadow_pelt", "shard", "glowcap", "resin"]
const RARITY_NAMES := {Rarity.COMMON: "Common", Rarity.UNCOMMON: "Uncommon", Rarity.RARE: "Rare"}

const MODELS := "res://assets/items/%s.glb"      # tools-src/blender/make_items.py
const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")

static var _meshes := {}

## Materials use the same rarity colours as gear (Balance.RARITIES); common is a faint white.
const RARITY_COLORS := {
	Rarity.COMMON: Color(1, 1, 1, 0.25),
	Rarity.UNCOMMON: Color(0.46, 0.86, 0.4),
	Rarity.RARE: Color(0.36, 0.62, 1.0),
}


static func name_of(id: String) -> String:
	return DEFS[id]["name"]


static func color_of(id: String) -> Color:
	return DEFS[id]["color"]


## "food", "loot" or "material".
static func kind_of(id: String) -> String:
	if Balance.FOODS.has(id) or id == "raw_meat" or id == "cigarette":
		return "food"
	return "loot" if id in LOOT else "material"


static func value_of(id: String) -> int:
	return Balance.VALUES.get(id, 1)


static func rarity_of(id: String) -> int:
	return DEFS[id]["rarity"]


## The item's faceted model, with the shared solid shader (glowing parts shine a little).
static func mesh(id: String) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var scene := (load(MODELS % id) as PackedScene).instantiate()
	var m := (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.duplicate() as Mesh
	scene.free()
	for s in m.get_surface_count():
		var src := m.surface_get_material(s) as StandardMaterial3D
		var mat := ShaderMaterial.new()
		mat.shader = SOLID_SHADER
		mat.set_shader_parameter("albedo", Color.WHITE)
		mat.set_shader_parameter("sway", 0.0)
		mat.set_shader_parameter("glow", 0.9 if src and src.resource_name == "Glow" else 0.0)
		m.surface_set_material(s, mat)
	_meshes[id] = m
	return m
