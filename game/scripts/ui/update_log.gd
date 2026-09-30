class_name UpdateLog
extends Control
## "Update log": what changed in each test build, newest first, so the owner can see on the phone what
## has landed. Opened from the title screen and from Settings. Add an entry at the top of ENTRIES with
## every published update.

const ENTRIES := [
	{"when": "30 Sep", "title": "Controls, quests, Cinderburst", "lines": [
		"Buttons stay put now: Attack, Heavy, Parry, Roll and Sneak are always in the same spots (no more waiting for them to pop up). Attack always works, even swinging at the air.",
		"Settings > Buttons > Compact: hides Heavy and Parry. Flick Attack up for a Heavy, left to Parry.",
		"Your sword rides on your back and comes out in a fight, then goes back a few seconds after. Settings > Sword > Always in hand keeps it out.",
		"New Pyromancer ability, Cinderburst (14 s): a ring of fire sets everyone round you alight. Anyone already burning explodes, spreads the fire, and sends a spark back that heals you. Set them burning with Flame Dash or Meteor first, then pop them.",
		"Quests: the tracker says STORY or JOB, how far to go, and a golden beam plus a gold diamond on the minimap show the way (to the gate first if it's in another region). The – button folds it small.",
		"Tap the tracker (or Menu > Quests) for the quest log: what each quest is about, the steps so far, and which one to follow.",
		"Bag: Drop (and Drop all) for any item. Quest items can't be dropped.",
		"Sneaking is quiet now: soft, slow, muffled steps.",
	]},
	{"when": "30 Sep", "title": "The story begins: the shrine and the Pyromancer", "lines": [
		"Top-left says 'A Strange Hum': the standing stones on the meadow hill are humming. Walk up to them.",
		"The shrine wakes: a pillar of light, a deep chord, a few words, then the class screen. The Pyromancer is open; the other three paths are sealed until later in the story.",
		"Flame Dash (5 s): burst through enemies in a streak of fire. You can't be hit mid-dash (time it as a blow lands for a perfect dodge too). Everything you pass through catches fire, and the ground behind you burns.",
		"Meteor (12 s): a glowing ring marks the nearest enemy, then a burning star crashes down. Huge damage, throws them back, breaks shield guards, and leaves the ground on fire.",
		"Burning enemies take damage over time (orange numbers).",
		"The ability buttons sit above Heavy, and their rings refill as they cool down. Menu > Class shows your path again.",
		"Quick test: Settings > Codes > Paladin > 'Become Pyromancer' (or 'Reset story (shrine)' to see the shrine wake again).",
	]},
	{"when": "30 Sep", "title": "Morrow's job: The Black Seal", "lines": [
		"Morrow (by the spawn, with the skull staff) has a dark job for you: kill Varek, leader of the Red Hand bandits, and bring back the black seal he wears. For Morrow. Not the trader.",
		"Reward: coins and an Epic sword. His last words about the seal are worth reading.",
	]},
	{"when": "30 Sep", "title": "The Red Hand bandits", "lines": [
		"A bandit camp in the east of the Whispering Wood (look for the red dots on the minimap, and 'Red Hand Camp'): a stake wall with a gate on the west and a gap at the back, tents, a lookout, and 7 bandits plus their leader Varek.",
		"Cutthroats: swords, 2 to 3 hit combos, they block some hits from the front and strike back if you keep swinging into their guard.",
		"Shield bandits block everything from the front. Get behind them, or break the guard with a Heavy blow.",
		"Archers keep their distance and shoot. Each shot has a glint first: roll through it or parry it. They back off if you close in.",
		"Only 2 bandits attack at once. The others circle round behind you, so keep moving.",
		"Varek: a duelist with long combos and a dashing lunge. He reads button-mashers and parries them. At half health he roars, calls the whole camp, and gets faster. Boss music.",
		"Bandits drop coins and Red Hand Rags (the trader buys them), and sometimes gear. The dead come back if you stay away long enough.",
		"Test them one at a time in the Build lab (Bandit, Shield bandit, Bandit archer, Varek).",
	]},
	{"when": "30 Sep", "title": "Sneaking", "lines": [
		"New Sneak button (C on a keyboard): crouch and creep. It's slower, and bandits only see you from close up. Sprinting stands you up.",
		"Bandits see in a cone in front of them, not through walls or tents, and less far at night. They hear you run, sprint or fight.",
		"A '?' over a bandit's head fills up while they notice you. At '!' they shout and the camp comes.",
		"Get close behind an unaware bandit and the action button says Takedown: one quiet blow. On Varek it takes half his health and wakes him.",
		"A bandit who sees a body comes to look. Pick your order.",
	]},
	{"when": "30 Sep", "title": "Parry and perfect dodge", "lines": [
		"New Parry button in fights (R on a keyboard). Press it just as a blow lands (the glint is your cue): PARRY! The enemy is knocked off balance and stunned, and your next hit is a double-damage counter.",
		"Press it too early or late and you still block, but it costs stamina and shoves you back. Run out of stamina and your guard breaks.",
		"Perfect dodge: roll at the very last moment before a hit lands and time slows down (blue tint). Your next hit is a double-damage counter.",
		"Stunned enemies take double damage from every hit.",
		"Enemies no longer give up their attack when you roll or blink after a hit. They keep coming, so fights are harder.",
	]},
	{"when": "30 Sep", "title": "Fights feel better", "lines": [
		"No more slow-mo walking after you swing: a swing only holds you until the blow lands. Push the stick after that and you move at full speed straight away.",
		"Damage numbers pop up on every hit. Critical hits are big and gold, with a sharp ring.",
		"Kills land with a deep boom and a harder shake. The last enemy of a fight goes down in a moment of slow motion.",
		"Level-ups get a big LEVEL UP banner, a fanfare and a burst of gold sparks around you.",
	]},
	{"when": "30 Sep", "title": "Loot shines", "lines": [
		"Rare, Epic, Legendary and Mythic gear lands with a flash and a ring of sparks in its colour, plus a chime.",
		"Legendary and Mythic shake the ground and shout their rarity.",
		"Chests with gear inside burst open in that gear's colour.",
	]},
	{"when": "30 Sep", "title": "Music", "lines": [
		"The game has music now: a gentle folk tune in the village, a calm one out in the meadow, a mysterious one in the Whispering Wood.",
		"When an enemy comes for you it switches to a fight tune, then drifts back once you're safe (a boss tune is ready for bosses).",
		"Quieter at night and indoors. Settings has a Music on/off switch.",
		"All tracks are free public-domain (CC0) music.",
	]},
	{"when": "30 Sep", "title": "Update log", "lines": [
		"This screen. Every test build adds what changed at the top.",
	]},
]


static func open(parent: Node) -> void:
	parent.add_child(UpdateLog.new())


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 600)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	UIStyle.label(column, "Update log", 30)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	scroll.add_child(list)
	for e: Dictionary in ENTRIES:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		list.add_child(head)
		var t := UIStyle.label(head, e["title"], 24)
		t.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
		UIStyle.label(head, e["when"], 18, true)
		for line: String in e["lines"]:
			var l := UIStyle.label(list, "•  " + line, 19)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(700, 0)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	UIStyle.button(footer, "Close", Vector2(140, 50)).pressed.connect(queue_free)
