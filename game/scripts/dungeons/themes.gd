extends RefCounted
## How a dungeon looks and who lives in it. A theme is data: the rock's colours, the light, which props stand
## about its rooms (props.gd) and its foes (foes.gd). Add a theme here and every template can use it.

const THEMES := {
	# A cannibal clan's den: reddish earth, fire pits, bones, stakes, cages. Foes: the clan (people).
	"den": {
		"floor": Color(0.58, 0.45, 0.32), "wall": Color(0.36, 0.24, 0.2), "wall_high": Color(0.5, 0.36, 0.3),
		"top": Color(0.2, 0.16, 0.14), "light": Color(1.0, 0.6, 0.3), "glow": 2.2,
		"props": {"fight": ["fire_pit", "bones", "stakes"], "side": ["bones", "sacks", "fire_pit"], "goal": ["fire_pit", "stakes", "bones", "cage"],
			"entry": ["skull_post"]},
		"foes": "clan",
	},
	# An old barrow under the hills: grey-green stone, pale crystals, urns and broken pillars. Foes: beasts.
	"barrow": {
		"floor": Color(0.42, 0.44, 0.4), "wall": Color(0.4, 0.42, 0.42), "wall_high": Color(0.56, 0.6, 0.6),
		"top": Color(0.18, 0.2, 0.22), "light": Color(0.55, 0.85, 1.0), "glow": 1.6,
		"props": {"fight": ["pillar", "crystals", "bones"], "side": ["urns", "crystals"], "goal": ["pillar", "pillar", "crystals", "urns"],
			"entry": ["crystals"]},
		"foes": "beasts",
	},
}


static func get_theme(id: String) -> Dictionary:
	return THEMES.get(id, THEMES["barrow"])
