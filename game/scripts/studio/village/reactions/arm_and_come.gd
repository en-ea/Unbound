extends "res://scripts/studio/village/reaction.gd"
## An enemy in the village: the bold grown men and women call out, come towards it at a jog and stand their ground a
## few metres off, shouting to drive it away.
const ANSWERS := ["enemy"]


static func weight(_cue: Dictionary, me: Dictionary) -> float:
	if me.age_group != "adult":
		return 0.0
	return 2.4 * high(me, "bold") + (0.6 if me.role in ["hunter", "smith", "woodcutter", "herder"] else 0.0)


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.5 + 1.5 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["clip", "Idle_Rail_Call"], ["say", line(cue, me, SHOUTS)], ["near", "enemy", 5.0, "jog"], ["face", "enemy"],
		["clip", "Spell_Simple_Shoot"], ["say", line(cue, me, DRIVE, 17)], ["wait", 3.0 + 3.0 * roll(cue, me, 2)],
		["clip", "Spell_Simple_Shoot"], ["wait", 2.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 40.0


const SHOUTS := ["To me! There's a beast!", "Grab a stick, it's at the houses!", "Wolf! With me!"]
const DRIVE := ["Hyah! Get out of it!", "Go on! Away with you!", "Back to the woods!", "Shoo! Hyah!"]
