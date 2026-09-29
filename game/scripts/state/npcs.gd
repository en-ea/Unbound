class_name Npcs
extends RefCounted
## The villagers you can talk to: who they are, where they stand, how they look and what they say when
## they have no quest for you. Quests they give are in state/quests.gd (`giver`). The body is built by
## world/npc.gd from `look` (a CharacterLook: parts and colour indices, see character_look.gd).

const NPCS := {
	"wren": {
		"name": "Wren", "title": "Tobacco grower", "at": Vector2(-2.6, 18.0), "scale": Vector3(0.9, 1.1, 0.9),
		"look": {
			"parts": {"eyes": "narrow", "brows": "stern", "mouth": "flat", "nose": "long", "hair": "messy", "beard": "stubble",
				"head": "sunhat", "top": "tunic", "waist": "none", "chest": "none", "shoulders": "none", "back": "leafcloak", "feet": "shoes"},
			"colors": {"Skin": 3, "Hair": 1, "Main": 13, "Second": 6, "Cloth": 1, "Leather": 0},
		},
		"prop": "shears",
		"greetings": ["Hm.", "Mind the stalks.", "Good leaf this year.", "Sun's fine. Smoke's better."],
		"chatter": ["The first leaf of the season is the sweetest. Don't tell the others.",
			"A slow smoke and a long look at the hills. That's all a day needs.",
			"Wild leaf, they call it. Nothing wild about it. I planted every one.",
			"Boars leave the plants alone. Wolves too. It's the rabbits I can't forgive."],
	},
}


static func get_def(id: String) -> Dictionary:
	return NPCS[id]
