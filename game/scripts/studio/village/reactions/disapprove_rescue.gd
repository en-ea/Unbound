extends "res://scripts/studio/village/reaction.gd"
## The player freed someone the village punished: the law-minded and the freed one's enemies turn on the player with
## a shake of the head and a word (retires the stage's turn of the nearest: stage.gd TURN_NO).
const ANSWERS := ["end:"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if not (has(cue, "rescued") or has(cue, "spared")) or me.kin:
		return 0.0
	var law := clampf((float(me.values.law) - 50.0) / 40.0, 0.0, 1.0)
	return 1.6 * law + (1.0 if float(me.feeling) <= -20.0 else 0.0) + (0.6 if float(me.feeling_player) < 0.0 else 0.0)


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.3 + 1.5 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["face", "player"], ["clip", "Idle_No"], ["say", line(cue, me, WORDS)], ["wait", stand_on(cue, me, 7.0, 0.5, 3.0)],
		["go", "away", "walk", 0.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 30.0


const WORDS := ["Who asked you to meddle?", "That was the elder's judgement, stranger.", "You'll answer for that.",
	"Outsiders. No respect for the law.", "Now %s will think it can be done."]
