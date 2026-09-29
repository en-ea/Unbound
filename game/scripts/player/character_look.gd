class_name CharacterLook
extends RefCounted
## What a "hero"-style character looks like: which parts it wears and its colours.
## Plain data, so it can be saved, randomised for villagers, and later sent to other players.

const SafeFile := preload("res://scripts/core/safe_file.gd")
const SAVE_PATH := "user://look.cfg"

## Part slots and their choices (the first is the default). Mesh names in hero.glb follow them.
const PARTS := {
	"eyes": ["calm", "happy", "bright", "narrow", "sleepy", "fierce"],
	"brows": ["soft", "arched", "raised", "stern", "thick"],
	"mouth": ["smile", "grin", "open", "flat", "smirk"],
	"nose": ["straight", "button", "long", "broad"],
	"ears": ["round", "pointed", "long"],
	"cheeks": ["none", "blush"],
	"marks": ["none", "freckles", "scar", "eyestripe", "warpaint", "mask", "tears", "claws", "dots", "chin", "noseband"],
	"extra": ["none", "glasses", "eyepatch", "earrings"],
	"mask": ["none", "kitsune", "oni", "hollow"],
	"hair": ["short", "messy", "swept", "curly", "long", "ponytail", "pigtails", "braid", "bun", "topknot", "mohawk", "none"],
	"beard": ["none", "stubble", "short", "full", "braided", "goatee", "mustache", "chinstrap"],
	"head": ["none", "hat", "hood", "helm", "cap", "straw", "crown", "band", "bandana", "circlet", "sunhat"],
	"top": ["tunic", "jacket", "coat", "robe", "armor", "jerkin"],
	"waist": ["none", "kilt", "apron", "tabard"],
	"chest": ["none", "strap", "vest", "sash", "bandolier"],
	"shoulders": ["none", "pads", "plates", "fur", "pauldron"],
	"back": ["none", "scarf", "backpack", "cape", "quiver", "shield", "leafcloak"],
	"feet": ["boots", "shoes", "wraps"],
}
const PART_LABELS := {"eyes": "Eyes", "brows": "Brows", "mouth": "Mouth", "nose": "Nose", "ears": "Ears", "cheeks": "Cheeks", "marks": "Markings", "extra": "Extras", "mask": "Mask", "hair": "Hair",
	"beard": "Beard", "head": "Headwear", "top": "Top", "waist": "Waist", "chest": "Chest", "shoulders": "Shoulders", "back": "Back",
	"feet": "Feet"}
## Nicer names for some choices in the picker (the rest are just capitalised).
const CHOICE_NAMES := {"armor": "Armour", "jerkin": "Jerkin", "straw": "Straw hat", "sunhat": "Sun hat", "leafcloak": "Leaf cloak", "crown": "Flower crown",
	"cap": "Feathered cap", "pauldron": "Pauldron", "fur": "Fur mantle", "bandolier": "Potions", "eyestripe": "Eye stripe",
	"warpaint": "War paint", "mask": "Painted mask", "tears": "Tear lines", "claws": "Claw marks", "dots": "Cheek dots",
	"chin": "Chin stripes", "noseband": "Nose band", "plates": "Steel plates", "pads": "Leather pads", "long": "Long",
	"strap": "Satchel", "none": "None", "kitsune": "Kitsune", "oni": "Oni", "hollow": "Hollow"}
## Body shape ranges (the picker's sliders): height and build scale the whole character.
const HEIGHT_RANGE := Vector2(0.9, 1.1)
const BUILD_RANGE := Vector2(0.88, 1.14)

const EARTHY: Array[Color] = [
	Color(0.42, 0.48, 0.32), Color(0.85, 0.64, 0.25), Color(0.52, 0.2, 0.22), Color(0.26, 0.32, 0.46),
	Color(0.3, 0.29, 0.3), Color(0.66, 0.36, 0.2), Color(0.22, 0.42, 0.44), Color(0.8, 0.74, 0.6),
	Color(0.36, 0.24, 0.46), Color(0.62, 0.14, 0.16), Color(0.16, 0.2, 0.34), Color(0.2, 0.34, 0.22),
	Color(0.18, 0.18, 0.2), Color(0.9, 0.86, 0.74), Color(0.44, 0.6, 0.78), Color(0.8, 0.46, 0.5),
]
## Colour slots (material names in hero.glb) and the palette each picks from.
const PALETTES := {
	"Eyes": [Color(0.1, 0.07, 0.07), Color(0.3, 0.17, 0.09), Color(0.14, 0.3, 0.6), Color(0.16, 0.42, 0.24), Color(0.66, 0.42, 0.1),
		Color(0.42, 0.46, 0.52), Color(0.42, 0.22, 0.62), Color(0.66, 0.12, 0.14)],
	"Skin": [Color(1.0, 0.86, 0.76), Color(0.98, 0.8, 0.66), Color(0.93, 0.72, 0.56), Color(0.8, 0.58, 0.42), Color(0.62, 0.42, 0.3), Color(0.45, 0.3, 0.22), Color(0.34, 0.22, 0.17)],
	"Hair": [Color(0.24, 0.15, 0.1), Color(0.1, 0.08, 0.08), Color(0.85, 0.62, 0.3), Color(0.96, 0.84, 0.58), Color(0.62, 0.26, 0.14), Color(0.74, 0.18, 0.16),
		Color(0.88, 0.88, 0.86), Color(0.54, 0.58, 0.66), Color(0.38, 0.28, 0.2), Color(0.3, 0.24, 0.48), Color(0.2, 0.44, 0.46),
		Color(0.9, 0.55, 0.65), Color(0.3, 0.45, 0.8)],
	"Main": EARTHY,
	"Second": [Color(0.3, 0.29, 0.3), Color(0.3, 0.22, 0.16), Color(0.24, 0.28, 0.38), Color(0.32, 0.36, 0.26), Color(0.48, 0.47, 0.45), Color(0.6, 0.5, 0.36),
		Color(0.14, 0.14, 0.16), Color(0.82, 0.76, 0.62), Color(0.42, 0.3, 0.2), Color(0.16, 0.2, 0.34)],
	"Cloth": [Color(0.85, 0.8, 0.68), Color(0.93, 0.92, 0.88), Color(0.62, 0.63, 0.64), Color(0.62, 0.72, 0.82), Color(0.74, 0.6, 0.42), Color(0.72, 0.42, 0.28)],
	"Accent": [Color(0.72, 0.25, 0.2), Color(0.85, 0.64, 0.25), Color(0.42, 0.48, 0.32), Color(0.22, 0.42, 0.44), Color(0.52, 0.2, 0.22), Color(0.8, 0.74, 0.6), Color(0.26, 0.32, 0.46), Color(0.86, 0.46, 0.2),
		Color(0.44, 0.28, 0.58), Color(0.2, 0.58, 0.62), Color(0.92, 0.74, 0.3), Color(0.66, 0.12, 0.14), Color(0.16, 0.2, 0.36), Color(0.92, 0.9, 0.86), Color(0.14, 0.14, 0.16), Color(0.86, 0.5, 0.56)],
	"Leather": [Color(0.5, 0.33, 0.2), Color(0.3, 0.2, 0.14), Color(0.66, 0.5, 0.32), Color(0.22, 0.22, 0.24), Color(0.6, 0.32, 0.18)],
	"Marks": [Color(0.36, 0.22, 0.16), Color(0.72, 0.18, 0.16), Color(0.16, 0.16, 0.2), Color(0.92, 0.92, 0.9), Color(0.24, 0.42, 0.72), Color(0.9, 0.7, 0.3),
		Color(0.3, 0.66, 0.46), Color(0.58, 0.34, 0.78)],
}
const COLOR_LABELS := {"Eyes": "Eye colour", "Skin": "Skin", "Hair": "Hair", "Main": "Top", "Second": "Trousers", "Cloth": "Shirt",
	"Accent": "Hood, cape, trim", "Leather": "Leather", "Marks": "Markings"}

## Ready-made outfits: each its own silhouette. Pick one, then change anything.
const OUTFITS := {
	"Wanderer": {"parts": {"hair": "short", "beard": "none", "head": "none", "top": "tunic", "waist": "none", "chest": "strap", "shoulders": "none", "back": "scarf", "feet": "boots"},
		"colors": {"Main": 3, "Second": 0, "Cloth": 0, "Accent": 0, "Leather": 0}},
	"Explorer": {"parts": {"hair": "long", "beard": "none", "head": "hat", "top": "tunic", "waist": "none", "chest": "vest", "shoulders": "none", "back": "backpack", "feet": "boots"},
		"colors": {"Main": 0, "Second": 3, "Cloth": 5, "Accent": 7, "Leather": 0}},
	"Merchant": {"parts": {"hair": "short", "beard": "short", "head": "hat", "top": "coat", "waist": "none", "chest": "strap", "shoulders": "none", "back": "scarf", "feet": "shoes"},
		"colors": {"Main": 2, "Second": 1, "Cloth": 0, "Accent": 4, "Leather": 2}},
	"Knight": {"parts": {"hair": "short", "beard": "stubble", "head": "helm", "top": "armor", "waist": "tabard", "chest": "none", "shoulders": "plates", "back": "shield", "feet": "boots"},
		"colors": {"Main": 10, "Second": 6, "Cloth": 1, "Accent": 11, "Leather": 1}},
	"Ranger": {"parts": {"hair": "long", "beard": "none", "head": "hood", "top": "tunic", "waist": "none", "chest": "strap", "shoulders": "pads", "back": "quiver", "feet": "wraps"},
		"colors": {"Main": 11, "Second": 1, "Cloth": 4, "Accent": 2, "Leather": 0}},
	"Mage": {"parts": {"hair": "long", "beard": "none", "head": "circlet", "top": "robe", "waist": "none", "chest": "none", "shoulders": "none", "back": "cape", "feet": "shoes", "marks": "eyestripe"},
		"colors": {"Main": 8, "Second": 6, "Cloth": 1, "Accent": 10, "Leather": 1, "Marks": 5}},
	"Smith": {"parts": {"hair": "short", "beard": "full", "head": "bandana", "top": "jerkin", "waist": "apron", "chest": "none", "shoulders": "none", "back": "none", "feet": "boots"},
		"colors": {"Main": 5, "Second": 1, "Cloth": 4, "Accent": 0, "Leather": 1}},
	"Northlander": {"parts": {"hair": "braid", "beard": "braided", "head": "band", "top": "jerkin", "waist": "kilt", "chest": "strap", "shoulders": "fur", "back": "none", "feet": "wraps", "marks": "warpaint"},
		"colors": {"Main": 12, "Second": 1, "Cloth": 0, "Accent": 6, "Leather": 1, "Marks": 4}},
	"Fisher": {"parts": {"hair": "messy", "beard": "stubble", "head": "straw", "top": "tunic", "waist": "none", "chest": "strap", "shoulders": "none", "back": "backpack", "feet": "wraps"},
		"colors": {"Main": 14, "Second": 7, "Cloth": 0, "Accent": 0, "Leather": 2}},
	"Bard": {"parts": {"hair": "swept", "beard": "goatee", "head": "cap", "top": "jacket", "waist": "none", "chest": "sash", "shoulders": "none", "back": "cape", "feet": "shoes"},
		"colors": {"Main": 9, "Second": 6, "Cloth": 1, "Accent": 10, "Leather": 1}},
	"Alchemist": {"parts": {"hair": "bun", "beard": "none", "head": "none", "top": "robe", "waist": "none", "chest": "bandolier", "shoulders": "none", "back": "backpack", "feet": "shoes", "extra": "glasses"},
		"colors": {"Main": 6, "Second": 6, "Cloth": 0, "Accent": 1, "Leather": 0}},
	"Druid": {"parts": {"hair": "curly", "beard": "none", "head": "crown", "top": "robe", "waist": "none", "chest": "none", "shoulders": "fur", "back": "none", "feet": "wraps", "marks": "dots"},
		"colors": {"Main": 11, "Second": 1, "Cloth": 4, "Accent": 1, "Leather": 0, "Marks": 3}},
	"Guardian": {"parts": {"hair": "topknot", "beard": "none", "head": "circlet", "top": "armor", "waist": "kilt", "chest": "none", "shoulders": "pauldron", "back": "cape", "feet": "boots"},
		"colors": {"Main": 13, "Second": 9, "Cloth": 1, "Accent": 6, "Leather": 1}},
}

## One line about each ready-made outfit, shown under its name.
const OUTFIT_BLURBS := {"Wanderer": "Light travelling clothes and a long scarf.", "Explorer": "Wide hat, vest and a full backpack.",
	"Merchant": "Long coat, hat and a trader's satchel.", "Knight": "Steel armour, plumed helm, tabard and shield.",
	"Ranger": "Hooded, light on the feet, a quiver of arrows.", "Mage": "A purple robe trimmed in gold, and a cape.",
	"Smith": "Bare arms, fur collar and a leather apron.", "Northlander": "Fur mantle, kilt, braids and war paint.",
	"Fisher": "Straw hat, rolled sleeves and a pack.", "Bard": "Feathered cap, a red jacket and a sash.",
	"Alchemist": "A robe, round glasses and a belt of potions.", "Druid": "Flower crown, fur and a forest robe.",
	"Guardian": "Armour, a great pauldron and a flowing cape."}

var outfit := "Wanderer"
var parts := {"eyes": "calm", "brows": "soft", "mouth": "smile", "nose": "straight", "ears": "round", "cheeks": "none", "marks": "none", "extra": "none", "hair": "short", "beard": "none",
	"head": "none", "top": "tunic", "waist": "none", "chest": "strap", "shoulders": "none", "back": "scarf", "feet": "boots"}
var colors := {"Eyes": 0, "Skin": 2, "Hair": 0, "Main": 3, "Second": 0, "Cloth": 0, "Accent": 0, "Leather": 0, "Marks": 0}   # palette indices
var height := 1.0
var build := 1.0


func color(slot: String) -> Color:
	return PALETTES[slot][clampi(colors.get(slot, 0), 0, PALETTES[slot].size() - 1)]


## The picker's name for a choice.
static func choice_name(choice: String) -> String:
	return CHOICE_NAMES.get(choice, choice.capitalize())


func set_part(slot: String, choice: String) -> void:
	if PARTS.has(slot) and PARTS[slot].has(choice):
		parts[slot] = choice


func cycle_part(slot: String, step: int) -> void:
	var choices: Array = PARTS[slot]
	parts[slot] = choices[posmod(choices.find(parts[slot]) + step, choices.size())]


func set_color(slot: String, index: int) -> void:
	colors[slot] = clampi(index, 0, PALETTES[slot].size() - 1)


## Applies a ready-made outfit (keeps the face, skin and hair colour).
func cycle_outfit(step: int) -> void:
	var names := OUTFITS.keys()
	set_outfit(names[posmod(names.find(outfit) + step, names.size())])


func set_outfit(name: String) -> void:
	var old: Dictionary = OUTFITS.get(outfit, {"parts": {}})["parts"]
	for slot in ["marks", "extra"]:      # face bits the last outfit added go with it
		if old.has(slot) and parts[slot] == old[slot]:
			parts[slot] = "none"
	outfit = name
	var o: Dictionary = OUTFITS[outfit]
	for slot: String in o["parts"]:
		parts[slot] = o["parts"][slot]
	for slot: String in o["colors"]:
		colors[slot] = o["colors"][slot]


func randomize_look(rng: RandomNumberGenerator) -> void:
	for slot in PARTS:
		parts[slot] = PARTS[slot][rng.randi() % PARTS[slot].size()]
	for slot in PALETTES:
		colors[slot] = rng.randi() % PALETTES[slot].size()
	for slot in ["marks", "extra", "waist", "shoulders", "ears"]:      # keep extras occasional
		if rng.randf() < 0.6:
			parts[slot] = PARTS[slot][0]
	if rng.randf() < 0.8:                    # masks are rare on a random look
		parts["mask"] = "none"
	height = snappedf(rng.randf_range(0.95, 1.05), 0.01)
	build = snappedf(rng.randf_range(0.94, 1.08), 0.01)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("look", "outfit", outfit)
	cfg.set_value("look", "parts", parts)
	cfg.set_value("look", "colors", colors)
	cfg.set_value("look", "height", height)
	cfg.set_value("look", "build", build)
	SafeFile.save_config(cfg, SAVE_PATH)


static func load_saved() -> CharacterLook:
	var look := CharacterLook.new()
	var cfg := ConfigFile.new()
	if SafeFile.load_config(cfg, SAVE_PATH) == OK:
		var saved_outfit: String = cfg.get_value("look", "outfit", look.outfit)
		if OUTFITS.has(saved_outfit):
			look.outfit = saved_outfit
		var saved_parts: Dictionary = cfg.get_value("look", "parts", {})
		var saved_colors: Dictionary = cfg.get_value("look", "colors", {})
		for slot in saved_parts:
			if PARTS.has(slot) and PARTS[slot].has(saved_parts[slot]):
				look.parts[slot] = saved_parts[slot]
		for slot in saved_colors:
			if PALETTES.has(slot):
				look.set_color(slot, saved_colors[slot])
		look.height = clampf(cfg.get_value("look", "height", 1.0), HEIGHT_RANGE.x, HEIGHT_RANGE.y)
		look.build = clampf(cfg.get_value("look", "build", 1.0), BUILD_RANGE.x, BUILD_RANGE.y)
	return look
