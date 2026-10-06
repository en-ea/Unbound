extends "res://scripts/studio/village/reaction.gd"
## The player freed someone: their kin and friends come to the player, thank them, and nod.
const ANSWERS := ["end:"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if not (has(cue, "rescued") or has(cue, "spared")):
		return 0.0
	return 3.0 if me.kin else (1.8 if float(me.feeling) >= 40.0 else 0.0)


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.5 + 2.0 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["near", "player", 1.8, "hurry"], ["face", "player"], ["say", line(cue, me, THANKS)], ["nod"], ["wait", 1.5],
		["wave"], ["go", "away", "walk", 0.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 40.0


const THANKS := ["Thank you. Thank you for %s.", "You didn't have to. Bless you.", "We won't forget this.",
	"Our house owes you, stranger."]
