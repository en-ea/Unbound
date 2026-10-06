extends "res://scripts/studio/village/reaction.gd"
## Something frightening near (an enemy, a fight): back off to a safe distance, still watching it. A beast only going
## about its business (a boar rooting by the houses): a step or two back, a look, a word, and on with the day.
const ANSWERS := ["enemy", "alarm", "beast"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if str(cue.kind).begins_with("beast"):
		return 1.0
	return 0.9 + 0.6 * high(me, "alert") - 0.6 * high(me, "bold")


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.3 + (2.5 if str(cue.kind).begins_with("beast") else 1.2) * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	var at := "node" if cue.get("node") != null else "place"
	if str(cue.kind).begins_with("beast"):
		return [["face", at], ["back", at, 1.2 + 1.5 * roll(cue, me, 2)], ["say", line(cue, me, BEAST) if roll(cue, me, 4) < 0.4 else ""],
			["wait", 2.0 + 4.0 * roll(cue, me, 3)]]
	return [["face", at], ["back", at, 2.5 + 2.0 * roll(cue, me, 2)], ["face", at], ["wait", 5.0 + 6.0 * roll(cue, me, 3)],
		["clip", "Idle_No"]]


const BEAST := ["Shoo! Go on!", "Mind the boar.", "That one's after the turnips again.", "Leave it be, it'll wander off.",
	"Someone fetch the hunter."]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 30.0
