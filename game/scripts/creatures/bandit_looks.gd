class_name BanditLooks
## What the Red Hand wear: our character parts in dark cloth and leather with blood-red hoods, bandanas,
## tabards and capes, a few masks. make(n, seed) gives look n with small changes per bandit (skin, hair).

const LOOKS := [
	{"parts": {"head": "hood", "top": "jacket", "chest": "bandolier", "shoulders": "pads", "back": "none", "waist": "none",
		"feet": "wraps", "beard": "stubble", "marks": "warpaint", "hair": "short"},
		"colors": {"Main": 12, "Second": 6, "Cloth": 2, "Accent": 11, "Leather": 3, "Marks": 2}},
	{"parts": {"head": "bandana", "top": "jerkin", "chest": "strap", "shoulders": "fur", "back": "none", "waist": "kilt",
		"feet": "boots", "beard": "full", "marks": "scar", "hair": "short"},
		"colors": {"Main": 4, "Second": 6, "Cloth": 2, "Accent": 11, "Leather": 3, "Marks": 0}},
	{"parts": {"head": "helm", "top": "armor", "chest": "none", "shoulders": "plates", "back": "none", "waist": "tabard",
		"feet": "boots", "beard": "stubble", "hair": "short"},
		"colors": {"Main": 12, "Second": 6, "Cloth": 2, "Accent": 11, "Leather": 3}},
	{"parts": {"head": "hood", "mask": "raven", "top": "tunic", "chest": "strap", "shoulders": "pads", "back": "quiver", "waist": "none",
		"feet": "wraps", "hair": "long"},
		"colors": {"Main": 12, "Second": 6, "Cloth": 2, "Accent": 11, "Leather": 3}},
	{"parts": {"head": "none", "mask": "hollow", "top": "jerkin", "chest": "bandolier", "shoulders": "pauldron", "back": "none",
		"waist": "kilt", "feet": "boots", "hair": "mohawk", "marks": "claws"},
		"colors": {"Main": 12, "Second": 6, "Cloth": 2, "Accent": 11, "Leather": 3, "Hair": 5, "Marks": 1}},
	# Varek: long black hair, a braided beard, a scar, a long dark coat and a red cape, red eyes.
	{"parts": {"head": "none", "top": "coat", "chest": "sash", "shoulders": "pauldron", "back": "cape", "waist": "none",
		"feet": "boots", "hair": "long", "beard": "braided", "marks": "scar", "brows": "stern", "eyes": "narrow", "mouth": "flat"},
		"colors": {"Main": 12, "Second": 6, "Cloth": 2, "Accent": 11, "Leather": 3, "Hair": 1, "Eyes": 7, "Marks": 0}},
]


static func make(n: int, seed: int) -> CharacterLook:
	var look := CharacterLook.new()
	var def: Dictionary = LOOKS[n % LOOKS.size()]
	look.parts["mask"] = "none"
	look.parts["brows"] = "stern"
	look.parts["mouth"] = "flat"
	look.parts["eyes"] = "narrow"
	for slot: String in def["parts"]:
		look.parts[slot] = def["parts"][slot]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7717 + 3
	look.colors["Skin"] = rng.randi_range(1, 6)
	look.colors["Hair"] = [0, 1, 4, 8].pick_random() if n != 5 else 1
	for slot: String in def["colors"]:
		look.colors[slot] = def["colors"][slot]
	return look
