extends "res://scripts/studio/village/reaction.gd"
## The one left when a two-way talk ends because the other had to go: they watch them go, a nod or a wave, a moment on
## their own, and then about their day (never both off in the same breath).
const ANSWERS := ["seeoff"]


static func weight(_cue: Dictionary, _me: Dictionary) -> float:
	return 1.0


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.3 + 0.8 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["face", "subject"], ["wave"] if roll(cue, me, 2) < 0.5 else ["nod"],
		["say", line(cue, me, AFTER) if roll(cue, me, 3) < 0.3 else ""], ["wait", stand_on(cue, me, 7.0, 0.6, 1.0)]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 30.0


const AFTER := ["Mind how you go.", "See you, then.", "Don't be a stranger.", "Off you go."]
