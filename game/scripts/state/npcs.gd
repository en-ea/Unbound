class_name Npcs
extends RefCounted
## The villagers you can talk to: who they are, where they stand, how they look and what they say when
## they have no quest for you. Quests they give are in state/quests.gd (`giver`). The body is built by
## world/npc.gd from `look` (a CharacterLook: parts and colour indices, see character_look.gd).

const NPCS := {
	"hesk": {
		"name": "Hesk", "title": "Innkeeper of Fernhollow", "region": "forest", "at": Vector2(-24.5, 12.5), "scale": Vector3(1.24, 1.0, 1.24),
		"look": {
			"parts": {"eyes": "happy", "brows": "thick", "mouth": "grin", "nose": "broad", "hair": "bun", "beard": "full",
				"head": "none", "top": "jerkin", "waist": "apron", "chest": "none", "shoulders": "none", "back": "none", "feet": "boots"},
			"colors": {"Skin": 2, "Hair": 4, "Main": 7, "Second": 3, "Cloth": 2, "Leather": 1},
		},
		"theme": {"bg": Color(0.09, 0.08, 0.06, 0.95), "accent": Color(1.0, 0.7, 0.36), "text": Color(1.0, 0.95, 0.85),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "wren"},
		"portrait": {"look_at": Vector3(0.05, 1.58, 0), "cam": Vector3(0.22, 1.74, 2.2), "fov": 34.0, "turn": -10.0},
		"route": [{"at": Vector2(0, 0), "work": ""}, {"at": Vector2(-2.0, 1.2), "work": "Interact"}, {"at": Vector2(1.2, 1.8), "work": ""}],
		"greetings": ["Welcome to Fernhollow!", "Warm yourself by the fire.", "Mind the roots, love.", "Ha! Another wanderer."],
		"chatter": ["My gran said the Long Night came through here first. The old stumps kept us warm till the sun came back.",
			"Every house here was a tree once. We only asked them to keep growing a different way.",
			"There's a cave past the south-west rocks. Glimmerdeep. Shines like the stars fell in. Wolves, though.",
			"Pip's out picking mushrooms again. That child knows the wood better than I do.",
			"Fish from the pond, grilled on the fire. That's supper. That's every supper."],
	},
	"pip": {
		"name": "Pip", "title": "Mushroom forager", "region": "forest", "at": Vector2(-33.0, 21.0), "scale": Vector3.ONE * 0.66,
		"look": {
			"parts": {"eyes": "bright", "brows": "raised", "mouth": "open", "nose": "button", "hair": "pigtails", "beard": "none",
				"head": "cap", "top": "tunic", "waist": "none", "chest": "strap", "shoulders": "none", "back": "backpack", "feet": "wraps"},
			"colors": {"Skin": 1, "Hair": 6, "Main": 10, "Second": 5, "Cloth": 3, "Leather": 2},
		},
		"theme": {"bg": Color(0.07, 0.1, 0.07, 0.95), "accent": Color(0.6, 0.95, 0.6), "text": Color(0.95, 1.0, 0.92),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "seeker"},
		"portrait": {"look_at": Vector3(0.0, 1.12, 0), "cam": Vector3(0.18, 1.2, 1.55), "fov": 34.0, "turn": -10.0},
		"walk_speed": 1.2,
		"route": [{"at": Vector2(0, 0), "work": "Farm_Harvest"}, {"at": Vector2(2.5, -1.5), "work": "Farm_Harvest"},
			{"at": Vector2(-1.5, -3.0), "work": ""}, {"at": Vector2(1.0, 2.0), "work": "Farm_Harvest"}],
		"greetings": ["Hi! Hi!", "Shh, the mushrooms are listening.", "Found one!", "Are you a hero? You look like one. Sort of."],
		"chatter": ["Red caps you can eat. Glowing ones you can eat but then you glow. That's the rule.",
			"I saw a white fish in the pond at night. Hesk says I dreamed it. I didn't.",
			"The big toadstool is my house! Well. Hesk's sister's. But I sleep in the top bit.",
			"Don't go in the cave without a light. Or do. But tell me what's in there after."],
	},
	"wren": {
		"name": "Wren", "title": "Tobacco grower", "at": Vector2(-19.0, 21.0), "scale": Vector3(0.84, 1.14, 0.84),
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
		"name": "Morrow", "title": "Wanderer", "at": Vector2(-1.5, 21.0), "scale": Vector3(0.96, 1.3, 0.96),
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
		"name": "Brakk", "title": "Blacksmith", "at": Vector2(-15.5, 12.5), "scale": Vector3.ONE * 1.6,
		"body": "res://assets/characters/golem.glb",
		"theme": {"bg": Color(0.1, 0.09, 0.11, 0.95), "accent": Color(1.0, 0.52, 0.16), "text": Color(1.0, 0.94, 0.86),
			"font": "res://assets/fonts/Cinzel-Variable.ttf", "name_font": "res://assets/fonts/Cinzel-Variable.ttf", "voice": "brakk"},
		"portrait": {"look_at": Vector3(0, 2.4, 0), "cam": Vector3(0.35, 2.75, 3.3), "fov": 34.0, "turn": -6.0},
		"prop": "golem_hammer", "prop_grip": Vector3(0, 0, 0), "prop_scale": 0.85,
		"carry": {"item": "anvil", "bone": "hand_l", "at": Vector3(0.0, 0.25, 0.0), "turn": Vector3(90, 0, 0), "scale": 0.7},
		"scenery": [{"model": "anvil", "at": Vector2(-1.7, 0.4), "turn": 90.0, "scale": 1.15}],
		"route": [{"at": Vector2(0, 0), "work": "TreeChopping"}],
		"work_sound": "res://assets/kenney_impact/impactMining_001.ogg",
		"greetings": ["Hrm.", "Stone remembers.", "Iron wants patience.", "*grunt*"],
		"chatter": ["Fire, iron, patience. That is all a smith is.",
			"The village needs a real smithy. This anvil has waited long enough.",
			"I was carved from the hill before this one. The iron there still sings.",
			"Bring me ore and I will make it into something that lasts."],
	},
	"seeker": {
		"name": "Moss-Cap", "title": "Seeker", "at": Vector2(11.5, -3.0), "scale": Vector3.ONE * 0.56,
		"body": "res://assets/characters/seeker.glb",
		"theme": {"bg": Color(0.05, 0.09, 0.08, 0.95), "accent": Color(0.66, 0.88, 1.0), "text": Color(0.9, 0.97, 1.0),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "seeker"},
		"portrait": {"look_at": Vector3(0, 0.98, 0), "cam": Vector3(0.15, 1.08, 1.25), "fov": 34.0, "turn": -10.0},
		"walk_speed": 0.8,
		# A shy spirit by the pond, searching the grass for lost things.
		"route": [{"at": Vector2(0, 0), "work": "Farm_Harvest"}, {"at": Vector2(-2.0, -1.8), "work": "Fixing_Kneeling"},
			{"at": Vector2(-1.2, 1.8), "work": ""}, {"at": Vector2(1.0, -0.5), "work": "Farm_Harvest"}],
		"greetings": ["Oh!", "...hi.", "Shh. Listening.", "*chirp*"],
		"chatter": ["I find lost things. Buttons, keys, the song a bird forgot. Mostly I put them back.",
			"Lost things hum. There is an old stone arch west of here, near the hill. Something hums under it.",
			"Past the pond, where the sun comes up, another arch. Shiny things like old stones.",
			"Far away where the land gets wild, north and west, something is humming very quietly. Very old.",
			"You walk loudly. It's all right. The mushrooms don't mind."],
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


## After the visual is in the tree: scale, shoulders, and what they hold or smoke. `carry` (a second prop,
## like Brakk's anvil under his arm) only shows in the build lab.
static func dress_visual(id: String, visual: CharacterVisual, portrait := false, in_world := false) -> void:
	var def: Dictionary = NPCS[id]
	visual.scale = def["scale"]
	if def.has("shoulders"):
		visual.widen_shoulders(def["shoulders"])
	if def.has("prop"):
		var prop := visual.hold_prop(def["prop"], def.get("prop_grip", Vector3.ZERO), Vector3(0, 0.05, 0.0))
		prop.scale = Vector3.ONE * def.get("prop_scale", 1.0)
		if def.get("two_hands", false):          # held low in both hands except while working
			visual.hold_two_handed(def["prop"], def.get("prop_scale", 1.0), prop)
	if def.has("carry") and not in_world and not portrait:
		var c: Dictionary = def["carry"]
		var carried := visual.hold_prop(c["item"], c["turn"], c["at"], c["bone"])
		carried.scale = Vector3.ONE * c.get("scale", 1.0)
	if def.get("smokes", false):
		var smoke := Smoking.new()
		smoke.visual = visual
		smoke.puff_scale = 0.45
		smoke.smoke_on = not portrait          # soft smoke does not blend well on a transparent portrait
		visual.add_child(smoke)
		smoke.start_endless()
