extends RefCounted
## What a dungeon is about. A template says how big it is and what goes in each kind of room; the layout
## (layout.gd) gives the rooms, the theme (themes.gd) the look and the foes. Any template in any theme.
##   path: rooms on the main path (the last is the goal)   sides: side rooms off it
##   fight: foes per fight room [least, most]   goal: what waits at the end (dungeon.gd _fill_goal)
##   side: what a side room holds   title: the banner's second line ({who}: the captive's name)

const TEMPLATES := {
	# Someone has been taken: fight down to them, free them, get them out.
	"rescue": {"path": 4, "sides": 1, "fight": [2, 3], "goal": "captive", "side": "chest",
		"title": "Save {who}", "done": "{who} is free! They run for the light."},
	# A hoard with something guarding it.
	"hoard": {"path": 3, "sides": 2, "fight": [2, 3], "goal": "hoard", "side": "chest",
		"title": "Something guards a hoard down here", "done": "The hoard is yours."},
}


static func get_template(id: String) -> Dictionary:
	return TEMPLATES.get(id, TEMPLATES["hoard"])
