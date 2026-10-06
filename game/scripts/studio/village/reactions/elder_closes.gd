extends "res://scripts/studio/village/reaction.gd"
## The one who presided (the elder, the priest) closes it: a word to those there, a nod, and off with some dignity.
const ANSWERS := ["end:"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	return 5.0 if (me.authority or me.priest) and int(cue.get("other", -1)) == int(me.id) else (2.0 if me.authority else 0.0)


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 1.0 + 2.0 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["face", "place"], ["clip", "Idle_Rail_Call"], ["say", line(cue, me, CLOSING)], ["nod"],
		["wait", stand_on(cue, me, 12.0, 0.5, 4.0)], ["go", "away", "stroll", 0.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 40.0


const CLOSING := ["It is done. Go about your day.", "Let this be remembered.", "Back to your work, all of you.",
	"Enough. The village has its answer."]
