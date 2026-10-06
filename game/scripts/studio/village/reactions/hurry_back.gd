extends "res://scripts/studio/village/reaction.gd"
## Work waiting: a nod and straight back to it, hurrying (the first to go, and not all at once).
const ANSWERS := ["end:"]


static func weight(_cue: Dictionary, me: Dictionary) -> float:
	if me.age_group == "child":
		return 0.0
	return (1.4 if me.busy else 0.2) + 0.8 * float(me.late)


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.3 + 1.5 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["nod"], ["say", line(cue, me, LINES) if roll(cue, me, 2) < 0.4 else ""],
		["wait", stand_on(cue, me, 3.0, 0.5, 1.0)], ["go", "away", "hurry", 0.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 20.0


const LINES := ["The field won't wait.", "I'm late as it is.", "Back to work.", "Enough standing about."]
