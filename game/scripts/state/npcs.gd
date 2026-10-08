class_name Npcs
extends RefCounted
## The villagers you can talk to: who they are, where they stand, how they look and what they say when
## they have no quest for you. Quests they give are in state/quests.gd (`giver`). The body is built by
## world/npc.gd from `look` (a CharacterLook: parts and colour indices, see character_look.gd).

const NPCS := {
	# --- the village's residents (state/residents.gd): a home, a trade, a day, their own goods ---
	"tomas": {
		"name": "Tomas", "title": "Woodcutter", "at": Vector2(-4.0, 1.5), "scale": Vector3(1.22, 1.06, 1.18),
		"look": {
			"parts": {"eyes": "happy", "brows": "thick", "mouth": "grin", "nose": "broad", "hair": "messy", "beard": "full",
				"head": "none", "top": "jerkin", "waist": "none", "chest": "strap", "shoulders": "none", "back": "none", "feet": "boots"},
			"colors": {"Skin": 3, "Hair": 2, "Main": 4, "Second": 6, "Cloth": 2, "Leather": 1},
		},
		"theme": {"bg": Color(0.09, 0.07, 0.05, 0.95), "accent": Color(0.95, 0.66, 0.36), "text": Color(1.0, 0.95, 0.86),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "wren"},
		"portrait": {"look_at": Vector3(0.05, 1.62, 0), "cam": Vector3(0.22, 1.78, 2.2), "fov": 34.0, "turn": -10.0},
		"route": [{"at": Vector2(0, 0), "work": "TreeChopping"}, {"at": Vector2(1.6, 0.8), "work": "TreeChopping"}],
		"greetings": ["Morning!", "Mind the chips.", "Hah! Good day for it.", "Need wood?"],
		"chatter": ["Swing from the hips, not the arms."],
		"resident": {"house": 0, "work": Vector2(-4.0, 1.5), "lunch": Vector2(-2.5, 20.5), "evening": Vector2(-6.2, 18.2),
			"goods": {"wood": 8, "pinewood": 2}, "makes": ["wood", "wood", "pinewood"], "likes": ["roast_meat", "stew"],
			"present": ["flint", "resin"], "present_line": "Here, take some %s. Found it splitting logs.",
			"loved": "Is that for me? You've just made a woodcutter very happy.", "thanks": "Ha, thank you kindly.",
			"goods_line": "Split it myself. Dry as a bone.",
			"friendly": ["Good to see you, friend.", "There's my favourite customer!"],
			"lines": {"work": ["Every house here has a bit of me in its walls. Well, my wood.", "The old oak by the pond? Nobody cuts that one. Nobody."],
				"lunch": ["Bread, cheese and a sit-down. Best part of the day."],
				"evening": ["Fire's the best reward for a day of chopping."],
				"home": ["Bit late for visiting, isn't it? Sit down, then. Kettle's on."]}},
	},
	"elsa": {
		"name": "Elsa", "title": "Cook", "at": Vector2(-3.4, 15.2), "scale": Vector3(1.08, 0.98, 1.1),
		"look": {
			"parts": {"eyes": "happy", "brows": "raised", "mouth": "grin", "nose": "button", "hair": "bun", "beard": "none",
				"head": "none", "top": "tunic", "waist": "apron", "chest": "none", "shoulders": "none", "back": "none", "feet": "shoes"},
			"colors": {"Skin": 1, "Hair": 5, "Main": 9, "Second": 2, "Cloth": 0, "Leather": 2},
		},
		"theme": {"bg": Color(0.1, 0.07, 0.06, 0.95), "accent": Color(1.0, 0.62, 0.48), "text": Color(1.0, 0.95, 0.9),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "seeker"},
		"portrait": {"look_at": Vector3(0.05, 1.56, 0), "cam": Vector3(0.22, 1.7, 2.1), "fov": 34.0, "turn": -10.0},
		"route": [{"at": Vector2(0, 0), "work": "Interact"}, {"at": Vector2(-1.4, 0.6), "work": "Farm_Harvest"}, {"at": Vector2(0.8, -0.8), "work": ""}],
		"greetings": ["Hungry?", "Smell that? That's supper.", "Hello, love!", "Wash your hands first."],
		"chatter": ["A pinch of salt fixes most things."],
		"resident": {"house": 2, "work": Vector2(-3.4, 15.2), "lunch": Vector2(-1.0, 15.0), "evening": Vector2(-3.0, 19.6),
			"goods": {"roast_meat": 2, "skewer": 2, "apple_tart": 1}, "makes": ["roast_meat", "skewer", "apple_tart"], "likes": ["flower", "apple"],
			"present": ["stew", "apple_tart"], "present_line": "And you're taking some %s home. No arguing.",
			"loved": "Oh, you shouldn't have! I'll put them by the window.", "thanks": "Aren't you sweet.",
			"goods_line": "Fresh off the fire. Eat it while it's hot.",
			"friendly": ["There you are, love!", "I saved you a bit, you know."],
			"lines": {"work": ["Nell! Stay where I can see you!", "Tomas eats like three men. I cook for four, to be safe."],
				"lunch": ["Sit, sit. Everybody eats at noon."],
				"evening": ["Nothing like the fire after the dishes are done."],
				"home": ["Shh, Nell's asleep. What is it, love?"]}},
	},
	"nell": {
		"name": "Nell", "title": "Elsa's daughter", "at": Vector2(1.5, 21.5), "scale": Vector3.ONE * 0.62,
		"look": {
			"parts": {"eyes": "bright", "brows": "raised", "mouth": "open", "nose": "button", "hair": "pigtails", "beard": "none",
				"head": "none", "top": "tunic", "waist": "none", "chest": "none", "shoulders": "none", "back": "none", "feet": "shoes"},
			"colors": {"Skin": 1, "Hair": 3, "Main": 6, "Second": 4, "Cloth": 3, "Leather": 2},
		},
		"theme": {"bg": Color(0.07, 0.08, 0.11, 0.95), "accent": Color(0.7, 0.85, 1.0), "text": Color(0.95, 0.97, 1.0),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "seeker"},
		"portrait": {"look_at": Vector3(0.0, 1.06, 0), "cam": Vector3(0.18, 1.14, 1.5), "fov": 34.0, "turn": -10.0},
		"walk_speed": 1.5,
		"route": [{"at": Vector2(0, 0), "work": ""}, {"at": Vector2(3.0, -2.0), "work": "Farm_Harvest"}, {"at": Vector2(-2.5, -3.0), "work": ""},
			{"at": Vector2(-1.0, 2.0), "work": "Farm_Harvest"}],
		"greetings": ["Hi!", "Wanna see a frog?", "You're tall.", "I'm not allowed past the fence."],
		"chatter": ["The windmill talks at night. Creak creak."],
		"resident": {"house": 2, "up": 0.3, "bed": 0.8, "work": Vector2(1.5, 21.5), "lunch": Vector2(-1.8, 14.6), "evening": Vector2(-4.2, 20.2),
			"goods": {"flower": 3, "apple": 2}, "makes": ["flower", "apple", "flower"], "likes": ["apple_tart", "apple"],
			"present": ["shard", "fang"], "present_line": "I found this %s! You can have it. It's a secret.",
			"loved": "For me?! Mum, look!", "thanks": "Thanks! I'll keep it forever. Or till supper.",
			"goods_line": "I picked them myself! You have to pay though. Mum says.",
			"friendly": ["It's you!", "Best friend!"],
			"lines": {"work": ["I'm playing hunters. You can be the boar.", "Tomas said there's a wolf as big as a horse. Is that true?"],
				"lunch": ["Mum makes the best skewers in the WORLD."],
				"evening": ["Tell me a story about the forest!"],
				"home": ["I'm supposed to be asleep..."]}},
	},
	# Tenants in the village houses you let (Lettings.TENANTS): they live inside, "region" keeps them out of the village.
	"tenant_odo": {
		"name": "Odo", "title": "Your tenant, an old sailor", "at": Vector2.ZERO, "region": "letting", "scale": Vector3(1.08, 1.0, 1.08),
		"look": {
			"parts": {"eyes": "narrow", "brows": "thick", "mouth": "grin", "nose": "broad", "hair": "short", "beard": "full",
				"head": "cap", "top": "coat", "waist": "none", "chest": "none", "shoulders": "none", "back": "none", "feet": "boots"},
			"colors": {"Skin": 2, "Hair": 7, "Main": 1, "Second": 0, "Cloth": 3, "Leather": 1},
		},
		"theme": {"bg": Color(0.06, 0.08, 0.11, 0.95), "accent": Color(0.6, 0.8, 0.95), "text": Color(0.95, 0.97, 1.0),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "morrow"},
		"portrait": {"look_at": Vector3(0.05, 1.62, 0), "cam": Vector3(0.22, 1.78, 2.2), "fov": 34.0, "turn": -10.0},
		"greetings": ["Ahoy, landlord!", "Dry land suits me.", "Hm? Ah, it's you."],
		"chatter": ["Forty years at sea, and now a hill. Funny old life."],
	},
	"tenant_mira": {
		"name": "Mira", "title": "Your tenant, a weaver", "at": Vector2.ZERO, "region": "letting", "scale": Vector3(0.95, 0.98, 0.95),
		"look": {
			"parts": {"eyes": "bright", "brows": "arched", "mouth": "open", "nose": "button", "hair": "bun", "beard": "none",
				"head": "none", "top": "tunic", "waist": "apron", "chest": "none", "shoulders": "none", "back": "none", "feet": "shoes"},
			"colors": {"Skin": 1, "Hair": 4, "Main": 9, "Second": 2, "Cloth": 5, "Leather": 2},
		},
		"theme": {"bg": Color(0.09, 0.07, 0.1, 0.95), "accent": Color(0.95, 0.7, 0.85), "text": Color(1.0, 0.96, 0.98),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "wren"},
		"portrait": {"look_at": Vector3(0.05, 1.55, 0), "cam": Vector3(0.22, 1.7, 2.1), "fov": 34.0, "turn": -10.0},
		"greetings": ["Oh! Come in, come in.", "Mind the threads.", "Hello, landlord!"],
		"chatter": ["The light in here is perfect for weaving."],
	},
	"tenant_fen": {
		"name": "Fen", "title": "Your tenant, a travelling scribe", "at": Vector2.ZERO, "region": "letting", "scale": Vector3(0.96, 1.04, 0.96),
		"look": {
			"parts": {"eyes": "happy", "brows": "raised", "mouth": "flat", "nose": "long", "hair": "messy", "beard": "stubble",
				"head": "none", "top": "coat", "waist": "none", "chest": "strap", "shoulders": "none", "back": "backpack", "feet": "boots"},
			"colors": {"Skin": 0, "Hair": 2, "Main": 5, "Second": 4, "Cloth": 0, "Leather": 0},
		},
		"theme": {"bg": Color(0.08, 0.08, 0.06, 0.95), "accent": Color(0.9, 0.85, 0.6), "text": Color(1.0, 0.98, 0.9),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "wren"},
		"portrait": {"look_at": Vector3(0.05, 1.62, 0), "cam": Vector3(0.22, 1.78, 2.2), "fov": 34.0, "turn": -10.0},
		"greetings": ["Ah, the landlord. Ink everywhere, sorry.", "Good day!", "Writing it all down."],
		"chatter": ["Every village has a story. This one has a few."],
	},
	"bram": {
		"name": "Bram", "title": "Miller", "at": Vector2(13.5, 7.5), "scale": Vector3(0.94, 1.1, 0.94),
		"look": {
			"parts": {"eyes": "narrow", "brows": "thick", "mouth": "flat", "nose": "long", "hair": "bun", "beard": "stubble",
				"head": "cap", "top": "tunic", "waist": "apron", "chest": "none", "shoulders": "none", "back": "none", "feet": "boots"},
			"colors": {"Skin": 2, "Hair": 7, "Main": 12, "Second": 3, "Cloth": 1, "Leather": 0},
		},
		"theme": {"bg": Color(0.08, 0.08, 0.07, 0.95), "accent": Color(0.92, 0.86, 0.6), "text": Color(1.0, 0.98, 0.9),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "morrow"},
		"portrait": {"look_at": Vector3(0.05, 1.7, 0), "cam": Vector3(0.22, 1.86, 2.1), "fov": 34.0, "turn": -10.0},
		"route": [{"at": Vector2(0, 0), "work": "Interact"}, {"at": Vector2(-2.0, 1.2), "work": "Farm_Harvest"}, {"at": Vector2(1.5, 1.0), "work": ""}],
		"greetings": ["Hm. Flour on your boots.", "Wind's good today.", "Afternoon.", "Mind the sails."],
		"chatter": ["The mill turns, the village eats."],
		"resident": {"house": 1, "work": Vector2(13.5, 7.5), "lunch": Vector2(2.2, 16.5), "evening": Vector2(-5.6, 15.8),
			"goods": {"apple": 5, "mushroom": 2}, "makes": ["apple", "apple", "mushroom"], "likes": ["cigarette", "tobacco"],
			"present": ["iron", "glowcap"], "present_line": "Take this %s. Fell out of a grain sack, if you'd believe it.",
			"loved": "Now that's a proper gift. Wren's leaf?", "thanks": "Hm. Thank you.",
			"goods_line": "Apples from behind the mill. Don't tell the boars.",
			"friendly": ["Ah. You.", "Good to see you, truly."],
			"lines": {"work": ["The sails need oiling. They always need oiling.", "Wind from the hill means rain by night."],
				"lunch": ["Elsa's cooking. Best thing in this village. Don't tell her I said so."],
				"evening": ["Quiet evening. Just how I like them."],
				"home": ["Door was open, was it? Well. Come in, then."]}},
	},
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
	# --- Saffra, the harbour town of Sunreach (the second land; world/sunreach.gd) ---
	"oduya": {
		"name": "Oduya", "title": "Harbourmaster of Saffra", "region": "sands", "at": Vector2(15.5, 56.0), "scale": Vector3(1.2, 1.08, 1.16),
		"look": {
			"parts": {"eyes": "narrow", "brows": "thick", "mouth": "smirk", "nose": "broad", "hair": "short", "beard": "short",
				"head": "bandana", "top": "coat", "waist": "none", "chest": "sash", "shoulders": "none", "back": "scarf", "feet": "boots"},
			"colors": {"Skin": 5, "Hair": 0, "Main": 8, "Second": 11, "Cloth": 4, "Leather": 1},
		},
		"theme": {"bg": Color(0.1, 0.07, 0.04, 0.95), "accent": Color(1.0, 0.72, 0.3), "text": Color(1.0, 0.96, 0.88),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "wren"},
		"portrait": {"look_at": Vector3(0.05, 1.62, 0), "cam": Vector3(0.22, 1.78, 2.2), "fov": 34.0, "turn": -10.0},
		"route": [{"at": Vector2(0, 0), "work": ""}, {"at": Vector2(-1.5, 2.5), "work": "Interact"}],
		"greetings": ["Another ship through the storm! Welcome to Saffra.", "Mind the ropes.", "Sun's kind today.", "Ha! Still in one piece?"],
		"chatter": ["You came through the Drowned Reach? And the old serpent let you pass? Then the sea likes you.",
			"The ship's yours whenever you want the mainland. She knows the way better than I do.",
			"Saffra was the first town the sun came back to after the Long Night. We've never let anyone forget it.",
			"North of the arch there's an oasis. Further, the mesas. Nobody goes into the mesas. Nobody sensible."],
	},
	"tamsa": {
		"name": "Tamsa", "title": "Spice seller", "region": "sands", "at": Vector2(1.5, 40.5), "scale": Vector3(0.94, 1.02, 0.94),
		"look": {
			"parts": {"eyes": "happy", "brows": "raised", "mouth": "grin", "nose": "button", "hair": "braid", "beard": "none",
				"head": "circlet", "top": "robe", "waist": "none", "chest": "sash", "shoulders": "none", "back": "none", "feet": "shoes"},
			"colors": {"Skin": 4, "Hair": 0, "Main": 3, "Second": 9, "Cloth": 1, "Leather": 2},
		},
		"theme": {"bg": Color(0.11, 0.06, 0.05, 0.95), "accent": Color(1.0, 0.5, 0.32), "text": Color(1.0, 0.94, 0.88),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "seeker"},
		"portrait": {"look_at": Vector3(0.05, 1.56, 0), "cam": Vector3(0.22, 1.7, 2.1), "fov": 34.0, "turn": -10.0},
		"route": [{"at": Vector2(0, 0), "work": "Interact"}, {"at": Vector2(1.2, -0.6), "work": ""}],
		"greetings": ["Smell that? Sunpepper!", "Mainlander! Your food must be so sad.", "Saffron, cumin, dragon-chilli!", "Buy something or sneeze, friend."],
		"chatter": ["Dragon-chilli grows only where the sand is hot enough to burn your feet. Worth it.",
			"My grandmother sailed to your mainland once. She said everything was green and nothing tasted of anything.",
			"The lighthouse never goes out. Ilyas swears the fire was lit by the sun itself."],
	},
	"ilyas": {
		"name": "Ilyas", "title": "Lighthouse keeper", "region": "sands", "at": Vector2(-27.0, 66.0), "scale": Vector3(0.9, 0.96, 0.9),
		"look": {
			"parts": {"eyes": "sleepy", "brows": "thick", "mouth": "flat", "nose": "long", "hair": "none", "beard": "braided",
				"head": "hood", "top": "robe", "waist": "none", "chest": "none", "shoulders": "none", "back": "none", "feet": "wraps"},
			"colors": {"Skin": 3, "Hair": 7, "Main": 6, "Second": 0, "Cloth": 0, "Leather": 0},
		},
		"theme": {"bg": Color(0.06, 0.07, 0.09, 0.95), "accent": Color(1.0, 0.82, 0.45), "text": Color(0.98, 0.95, 0.88),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "wren"},
		"portrait": {"look_at": Vector3(0.05, 1.5, 0), "cam": Vector3(0.22, 1.64, 2.1), "fov": 34.0, "turn": -10.0},
		"route": [{"at": Vector2(0, 0), "work": ""}, {"at": Vector2(2.0, -1.0), "work": ""}],
		"greetings": ["The light holds.", "Hm. You.", "Sit, if you like.", "Mind the steps."],
		"chatter": ["I saw your ship in the storm. I turned the mirror on that serpent myself. You're welcome.",
			"The serpent is older than the Long Night. It isn't evil. It's hungry, and it remembers.",
			"There are three lands, they say. Yours, ours, and one nobody comes back from to describe.",
			"When the sun went out, this fire didn't. Make of that what you will."],
	},
	"zeph": {
		"name": "Zeph", "title": "Dock runner", "region": "sands", "at": Vector2(9.0, 32.0), "scale": Vector3.ONE * 0.68,
		"look": {
			"parts": {"eyes": "bright", "brows": "raised", "mouth": "open", "nose": "button", "hair": "curly", "beard": "none",
				"head": "none", "top": "tunic", "waist": "none", "chest": "sash", "shoulders": "none", "back": "none", "feet": "wraps"},
			"colors": {"Skin": 5, "Hair": 0, "Main": 11, "Second": 3, "Cloth": 2, "Leather": 2},
		},
		"theme": {"bg": Color(0.05, 0.09, 0.1, 0.95), "accent": Color(0.4, 0.95, 0.9), "text": Color(0.94, 1.0, 1.0),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf", "voice": "seeker"},
		"portrait": {"look_at": Vector3(0.0, 1.12, 0), "cam": Vector3(0.18, 1.2, 1.55), "fov": 34.0, "turn": -10.0},
		"walk_speed": 1.4,
		"route": [{"at": Vector2(0, 0), "work": ""}, {"at": Vector2(3.0, 4.0), "work": ""}, {"at": Vector2(-2.5, 6.0), "work": ""}, {"at": Vector2(1.0, 9.0), "work": ""}],
		"greetings": ["Did you see the serpent? DID YOU?", "Race you to the pier!", "You talk funny. Mainland funny.", "Hi!"],
		"chatter": ["I'm going to be a captain. Oduya says I have to stop falling off the pier first.",
			"There's a hole under the arch where the sand sings at night. Swear on the sun.",
			"The jackals out past the oasis are clever. They wait till you're tired."],
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
	if id.begins_with("resident:"):   # studio: a simulated villager, made from the resident (studio/village/resident_talk.gd)
		return load("res://scripts/studio/village/resident_talk.gd").def(id)   # studio
	return NPCS[id]


## The body of a villager, built from their entry (used in the world by world/npc.gd and as the portrait
## in the talk screen). Not added to the tree yet.
static func make_visual(id: String) -> CharacterVisual:
	var def: Dictionary = get_def(id)   # studio: was NPCS[id]; the same for Enea's own, a made def for a resident
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
	var def: Dictionary = get_def(id)   # studio: was NPCS[id]
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
