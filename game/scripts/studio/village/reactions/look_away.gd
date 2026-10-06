extends "res://scripts/studio/village/reaction.gd"
## The tender-hearted turn away from a hard end: a shake of the head, the back turned, and off early.
const ANSWERS := ["end:"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if not (has(cue, "died") or has(cue, "exiled") or has(cue, "guilty") or has(cue, "pillory") or has(cue, "stocks")):
		return 0.0
	return 1.8 * high(me, "compassion") + (0.5 if float(me.feeling) >= 20.0 else 0.0)


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.5 + 2.5 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["clip", "Idle_No"], ["say", line(cue, me, WORDS) if roll(cue, me, 2) < 0.4 else ""], ["face", "away"],
		["wait", stand_on(cue, me, 5.0, 0.5, 2.5)], ["go", "away", "walk", 0.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 25.0


const WORDS := ["I can't watch this.", "Too hard. Too hard.", "There was no need.", "God forgive us."]
