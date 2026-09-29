class_name Npcs
extends RefCounted
## The villagers you can talk to: who they are, where they stand, how they look and what they say when
## they have no quest for you. Quests they give are in state/quests.gd (`giver`). The body is built by
## world/npc.gd from `look` (a CharacterLook: parts and colour indices, see character_look.gd).

const NPCS := {
	"wren": {
		"name": "Wren", "title": "Tobacco grower", "at": Vector2(-2.6, 18.0), "scale": Vector3(0.84, 1.14, 0.84),
		"look": {
			"parts": {"eyes": "narrow", "brows": "stern", "mouth": "flat", "nose": "long", "hair": "messy", "beard": "stubble",
				"head": "sunhat", "top": "tunic", "waist": "none", "chest": "none", "shoulders": "none", "back": "leafcloak", "feet": "shoes"},
			"colors": {"Skin": 3, "Hair": 8, "Main": 13, "Second": 6, "Cloth": 1, "Leather": 0},
		},
		"theme": {"bg": Color(0.08, 0.11, 0.07, 0.95), "accent": Color(0.96, 0.74, 0.32), "text": Color(1.0, 0.96, 0.84),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "wren"},
		"portrait": {"look_at": Vector3(0.05, 1.74, 0), "cam": Vector3(0.22, 1.92, 2.05), "fov": 34.0, "turn": -10.0},
		"smokes": true,
		"prop": "shears", "prop_scale": 1.3, "two_hands": true,
		# A daily round: spots to walk between (metres from where he stands), and what he does at each.
		"route": [{"at": Vector2(0, 0), "work": "Farm_Harvest"}, {"at": Vector2(-3.0, 0.8), "work": "Farm_Watering"},
			{"at": Vector2(-1.8, -1.6), "work": "Farm_PlantSeed"}, {"at": Vector2(1.4, -0.6), "work": ""}],
		"greetings": ["Hm.", "Mind the stalks.", "Good leaf this year.", "Sun's fine. Smoke's better."],
		"chatter": ["The first leaf of the season is the sweetest. Don't tell the others.",
			"A slow smoke and a long look at the hills. That's all a day needs.",
			"Wild leaf, they call it. Nothing wild about it. I planted every one.",
			"Boars leave the plants alone. Wolves too. It's the rabbits I can't forgive."],
	},
	"morrow": {
		"name": "Morrow", "title": "Wanderer", "at": Vector2(-1.5, 25.5), "scale": Vector3(0.96, 1.3, 0.96),
		"body": "res://assets/characters/morrow.glb",
		"theme": {"bg": Color(0.06, 0.06, 0.09, 0.95), "accent": Color(0.86, 0.8, 0.66), "text": Color(0.93, 0.91, 0.86),
			"font": "res://assets/fonts/Cinzel-Variable.ttf", "name_font": "res://assets/fonts/Cinzel-Variable.ttf", "voice": "morrow"},
		"portrait": {"look_at": Vector3(0, 2.02, 0), "cam": Vector3(0.3, 2.12, 1.6), "fov": 34.0, "turn": -8.0},
		"prop": "skull_staff", "walk_speed": 0.75,
		"route": [{"at": Vector2(0, 0), "work": ""}, {"at": Vector2(2.5, 1.5), "work": ""}, {"at": Vector2(-1.5, 2.0), "work": ""}],
		"greetings": ["...", "Hm.", "You see me.", "The wind turned."],
		"chatter": ["Everything that falls is gathered in the end. I only walk ahead of it.",
			"The birds knew the old roads. I follow what they left behind.",
			"Keep your lantern lit past the stones. Not everything out there is asleep.",
			"I was here before the village. I will be here after the rain."],
	},
	"brakk": {
		"name": "Brakk", "title": "Blacksmith", "at": Vector2(-13.5, 11.0), "scale": Vector3.ONE * 1.6,
		"body": "res://assets/characters/golem.glb",
		"theme": {"bg": Color(0.1, 0.09, 0.11, 0.95), "accent": Color(1.0, 0.52, 0.16), "text": Color(1.0, 0.94, 0.86),
			"font": "res://assets/fonts/Cinzel-Variable.ttf", "name_font": "res://assets/fonts/Cinzel-Variable.ttf", "voice": "brakk"},
		"portrait": {"look_at": Vector3(0, 2.05, 0), "cam": Vector3(0.35, 2.35, 3.3), "fov": 34.0, "turn": -6.0},
		"prop": "golem_hammer", "prop_grip": Vector3(0, 0, 0),
		"scenery": [{"model": "anvil", "at": Vector2(-1.7, 0.4), "turn": 90.0, "scale": 1.15}],
		"route": [{"at": Vector2(0, 0), "work": "TreeChopping"}],
		"work_sound": "res://assets/kenney_impact/impactMining_001.ogg",
		"greetings": ["Hrm.", "Stone remembers.", "Iron wants patience.", "*grunt*"],
		"chatter": ["Fire, iron, patience. That is all a smith is.",
			"The village needs a real smithy. This anvil has waited long enough.",
			"I was carved from the hill before this one. The iron there still sings.",
			"Bring me ore and I will make it into something that lasts."],
	},
}


static func get_def(id: String) -> Dictionary:
	return NPCS[id]


## The body of a villager, built from their entry (used in the world by world/npc.gd and as the portrait
## in the talk screen). Not added to the tree yet.
static func make_visual(id: String) -> CharacterVisual:
	var def: Dictionary = NPCS[id]
	var visual := CharacterVisual.new()
	var look := CharacterLook.new()
	var made: Dictionary = def.get("look", {"parts": {}, "colors": {}})
	for slot: String in made["parts"]:
		look.parts[slot] = made["parts"][slot]
	for slot: String in made["colors"]:
		look.colors[slot] = made["colors"][slot]
	visual.hero_look = look
	visual.body_model = def.get("body", "")
	visual.is_player_look = false
	return visual


## After the visual is in the tree: scale, shoulders, and what they hold or smoke.
static func dress_visual(id: String, visual: CharacterVisual, portrait := false) -> void:
	var def: Dictionary = NPCS[id]
	visual.scale = def["scale"]
	if def.has("shoulders"):
		visual.widen_shoulders(def["shoulders"])
	if def.has("prop"):
		var prop := visual.hold_prop(def["prop"], def.get("prop_grip", Vector3.ZERO), Vector3(0, 0.05, 0.0))
		prop.scale = Vector3.ONE * def.get("prop_scale", 1.0)
		if def.get("two_hands", false):          # held low in both hands except while working
			visual.hold_two_handed(def["prop"], def.get("prop_scale", 1.0), prop)
	if def.get("smokes", false):
		var smoke := Smoking.new()
		smoke.visual = visual
		smoke.puff_scale = 0.45
		smoke.smoke_on = not portrait          # soft smoke does not blend well on a transparent portrait
		visual.add_child(smoke)
		smoke.start_endless()
