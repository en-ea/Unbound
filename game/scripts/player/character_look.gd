class_name CharacterLook
extends RefCounted
## What a "hero"-style character looks like: which parts it wears and its colours.
## Plain data, so it can be saved, randomised for villagers, and later sent to other players.

const SAVE_PATH := "user://look.cfg"

## Part slots and their choices (the first is the default). Mesh names in hero.glb follow them.
const PARTS := {
	"face": ["calm", "happy", "bright", "stern"],
	"cheeks": ["none", "blush"],
	"hair": ["short", "long", "bun", "none"],
	"beard": ["none", "beard"],
	"head": ["none", "hood"],
	"shoulders": ["none", "pads"],
	"back": ["scarf", "cape", "none"],
}
const PART_LABELS := {"face": "Face", "cheeks": "Cheeks", "hair": "Hair", "beard": "Beard", "head": "Hood", "shoulders": "Shoulders", "back": "Back"}

const CLOTH: Array[Color] = [
	Color(0.30, 0.38, 0.52), Color(0.26, 0.42, 0.32), Color(0.62, 0.22, 0.18), Color(0.80, 0.72, 0.56),
	Color(0.38, 0.30, 0.46), Color(0.28, 0.28, 0.30), Color(0.78, 0.52, 0.22), Color(0.20, 0.45, 0.52),
]
## Colour slots (material names in hero.glb) and the palette each picks from.
const PALETTES := {
	"Skin": [Color(0.98, 0.80, 0.66), Color(0.93, 0.72, 0.56), Color(0.80, 0.58, 0.42), Color(0.62, 0.42, 0.30), Color(0.45, 0.30, 0.22)],
	"Hair": [Color(0.24, 0.15, 0.10), Color(0.10, 0.08, 0.07), Color(0.85, 0.62, 0.30), Color(0.62, 0.26, 0.14), Color(0.90, 0.90, 0.88), Color(0.42, 0.46, 0.56)],
	"Main": CLOTH,
	"Second": CLOTH,
	"Accent": CLOTH,
	"Leather": [Color(0.40, 0.26, 0.16), Color(0.25, 0.17, 0.11), Color(0.55, 0.40, 0.26), Color(0.22, 0.22, 0.24)],
}
const COLOR_LABELS := {"Skin": "Skin", "Hair": "Hair colour", "Main": "Tunic", "Second": "Trim & pants", "Accent": "Scarf, cape, hood", "Leather": "Leather"}

var parts := {"face": "calm", "cheeks": "none", "hair": "short", "beard": "none", "head": "none", "shoulders": "none", "back": "scarf"}
var colors := {"Skin": 1, "Hair": 0, "Main": 0, "Second": 3, "Accent": 2, "Leather": 0}   # palette indices


func color(slot: String) -> Color:
	return PALETTES[slot][colors[slot]]


func cycle_part(slot: String, step: int) -> void:
	var choices: Array = PARTS[slot]
	parts[slot] = choices[posmod(choices.find(parts[slot]) + step, choices.size())]


func set_color(slot: String, index: int) -> void:
	colors[slot] = clampi(index, 0, PALETTES[slot].size() - 1)


func randomize_look(rng: RandomNumberGenerator) -> void:
	for slot in PARTS:
		parts[slot] = PARTS[slot][rng.randi() % PARTS[slot].size()]
	for slot in PALETTES:
		colors[slot] = rng.randi() % PALETTES[slot].size()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("look", "parts", parts)
	cfg.set_value("look", "colors", colors)
	cfg.save(SAVE_PATH)


static func load_saved() -> CharacterLook:
	var look := CharacterLook.new()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var saved_parts: Dictionary = cfg.get_value("look", "parts", {})
		var saved_colors: Dictionary = cfg.get_value("look", "colors", {})
		for slot in saved_parts:
			if PARTS.has(slot) and PARTS[slot].has(saved_parts[slot]):
				look.parts[slot] = saved_parts[slot]
		for slot in saved_colors:
			if PALETTES.has(slot):
				look.set_color(slot, saved_colors[slot])
	return look
