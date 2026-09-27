class_name Items
extends RefCounted
## Every item in the game: display name, colour and rarity. Models: tools-src/blender/make_items.py.

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
}

const MODELS := "res://assets/items/%s.glb"      # tools-src/blender/make_items.py
const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")

static var _meshes := {}

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
