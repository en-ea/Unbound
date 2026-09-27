class_name CharacterLook
extends RefCounted
## What a "hero"-style character looks like: which parts it wears and its colours.
## Plain data, so it can be saved, randomised for villagers, and later sent to other players.

const SAVE_PATH := "user://look.cfg"

## Part slots and their choices (the first is the default). Mesh names in hero.glb follow them.
const PARTS := {
	"eyes": ["calm", "happy", "bright", "narrow", "sleepy", "fierce"],
	"brows": ["soft", "arched", "raised", "stern", "thick"],
	"mouth": ["smile", "grin", "open", "flat", "smirk"],
	"cheeks": ["none", "blush"],
	"hair": ["short", "messy", "long", "ponytail", "bun", "none"],
	"beard": ["none", "stubble", "short", "full", "braided", "goatee", "mustache", "chinstrap"],
	"head": ["none", "hat", "band", "bandana", "circlet"],
	"top": ["tunic", "jacket", "coat"],
	"chest": ["none", "strap", "vest"],
	"shoulders": ["none", "pads", "plates"],
	"back": ["none", "scarf", "backpack", "cape"],
	"feet": ["boots", "shoes", "wraps"],
}
const PART_LABELS := {"eyes": "Eyes", "brows": "Brows", "mouth": "Mouth", "cheeks": "Cheeks", "hair": "Hair",
	"beard": "Beard", "head": "Headwear", "top": "Top", "chest": "Chest", "shoulders": "Shoulders", "back": "Back",
	"feet": "Feet"}
## Which slots the look picker shows on its "Face" tab (the rest go on "Outfit").
const FACE_SLOTS := ["eyes", "brows", "mouth", "cheeks", "hair", "beard"]

const EARTHY: Array[Color] = [
	Color(0.42, 0.48, 0.32), Color(0.85, 0.64, 0.25), Color(0.52, 0.2, 0.22), Color(0.26, 0.32, 0.46),
	Color(0.3, 0.29, 0.3), Color(0.66, 0.36, 0.2), Color(0.22, 0.42, 0.44), Color(0.8, 0.74, 0.6),
]
## Colour slots (material names in hero.glb) and the palette each picks from.
const PALETTES := {
	"Skin": [Color(0.98, 0.8, 0.66), Color(0.93, 0.72, 0.56), Color(0.8, 0.58, 0.42), Color(0.62, 0.42, 0.3), Color(0.45, 0.3, 0.22)],
	"Hair": [Color(0.24, 0.15, 0.1), Color(0.1, 0.08, 0.08), Color(0.85, 0.62, 0.3), Color(0.62, 0.26, 0.14), Color(0.88, 0.88, 0.86), Color(0.38, 0.28, 0.2)],
	"Main": EARTHY,
	"Second": [Color(0.3, 0.29, 0.3), Color(0.3, 0.22, 0.16), Color(0.24, 0.28, 0.38), Color(0.32, 0.36, 0.26), Color(0.48, 0.47, 0.45), Color(0.6, 0.5, 0.36)],
	"Cloth": [Color(0.85, 0.8, 0.68), Color(0.93, 0.92, 0.88), Color(0.62, 0.63, 0.64), Color(0.62, 0.72, 0.82), Color(0.74, 0.6, 0.42), Color(0.72, 0.42, 0.28)],
	"Accent": [Color(0.72, 0.25, 0.2), Color(0.85, 0.64, 0.25), Color(0.42, 0.48, 0.32), Color(0.22, 0.42, 0.44), Color(0.52, 0.2, 0.22), Color(0.8, 0.74, 0.6), Color(0.26, 0.32, 0.46), Color(0.86, 0.46, 0.2)],
	"Leather": [Color(0.5, 0.33, 0.2), Color(0.3, 0.2, 0.14), Color(0.66, 0.5, 0.32), Color(0.22, 0.22, 0.24)],
}
const COLOR_LABELS := {"Skin": "Skin", "Hair": "Hair", "Main": "Top", "Second": "Trousers", "Cloth": "Shirt",
	"Accent": "Scarf, hat, cape", "Leather": "Leather"}

## Ready-made outfits (from the owner's reference sheets); pick one, then tweak.
const OUTFITS := {
	"Wanderer": {"parts": {"hair": "short", "beard": "none", "head": "none", "feet": "boots", "top": "tunic", "chest": "strap", "shoulders": "none", "back": "scarf"},
		"colors": {"Main": 3, "Second": 0, "Cloth": 0, "Accent": 0, "Leather": 0}},
	"Explorer": {"parts": {"hair": "long", "beard": "none", "head": "hat", "feet": "boots", "top": "tunic", "chest": "vest", "shoulders": "none", "back": "backpack"},
		"colors": {"Main": 0, "Second": 3, "Cloth": 5, "Accent": 7, "Leather": 0}},
	"Fighter": {"parts": {"hair": "ponytail", "beard": "none", "head": "band", "feet": "wraps", "top": "jacket", "chest": "strap", "shoulders": "plates", "back": "scarf"},
		"colors": {"Main": 4, "Second": 1, "Cloth": 4, "Accent": 0, "Leather": 1}},
	"Merchant": {"parts": {"hair": "short", "beard": "short", "head": "hat", "feet": "shoes", "top": "coat", "chest": "strap", "shoulders": "none", "back": "scarf"},
		"colors": {"Main": 2, "Second": 1, "Cloth": 0, "Accent": 4, "Leather": 2}},
	# Hero looks: someone on the way to becoming one of the great guardians.
	"Guardian": {"parts": {"hair": "short", "beard": "stubble", "head": "circlet", "feet": "boots", "top": "jacket", "chest": "strap", "shoulders": "plates", "back": "cape"},
		"colors": {"Main": 3, "Second": 0, "Cloth": 1, "Accent": 6, "Leather": 1}},
	"Ranger": {"parts": {"hair": "long", "beard": "none", "head": "bandana", "feet": "wraps", "top": "tunic", "chest": "vest", "shoulders": "pads", "back": "scarf"},
		"colors": {"Main": 0, "Second": 3, "Cloth": 4, "Accent": 3, "Leather": 0}},
	"Fisher": {"parts": {"hair": "long", "beard": "braided", "head": "bandana", "feet": "boots", "top": "coat", "chest": "none", "shoulders": "none", "back": "backpack"},
		"colors": {"Main": 1, "Second": 0, "Cloth": 5, "Accent": 1, "Leather": 1}},
}

var outfit := "Wanderer"
var parts := {"eyes": "calm", "brows": "soft", "mouth": "smile", "cheeks": "none", "hair": "short", "beard": "none",
	"head": "none", "top": "tunic", "chest": "strap", "shoulders": "none", "back": "scarf", "feet": "boots"}
var colors := {"Skin": 1, "Hair": 0, "Main": 3, "Second": 0, "Cloth": 0, "Accent": 0, "Leather": 0}   # palette indices


func color(slot: String) -> Color:
	return PALETTES[slot][colors[slot]]


func cycle_part(slot: String, step: int) -> void:
	var choices: Array = PARTS[slot]
	parts[slot] = choices[posmod(choices.find(parts[slot]) + step, choices.size())]


func set_color(slot: String, index: int) -> void:
	colors[slot] = clampi(index, 0, PALETTES[slot].size() - 1)


## Applies a ready-made outfit (keeps the face, skin and hair colour).
func cycle_outfit(step: int) -> void:
	var names := OUTFITS.keys()
	outfit = names[posmod(names.find(outfit) + step, names.size())]
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


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("look", "outfit", outfit)
	cfg.set_value("look", "parts", parts)
	cfg.set_value("look", "colors", colors)
	cfg.save(SAVE_PATH)


static func load_saved() -> CharacterLook:
	var look := CharacterLook.new()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
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
	return look
