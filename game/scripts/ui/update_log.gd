class_name UpdateLog
extends Control
## "Update log": what changed in each test build, newest first, so the owner can see on the phone what
## has landed. Opened from the title screen and from Settings. Add an entry at the top of ENTRIES with
## every published update.

const ENTRIES := [
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
