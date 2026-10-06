extends "res://scripts/studio/village/reaction.gd"
## Leaving a circle: a word and a wave to those staying, then off to what their day wants (retires the instant leave:
## residents.gd's trip change). The circle answers with a nod (residents.gd gives it; they keep talking).
const ANSWERS := ["parting"]


static func weight(_cue: Dictionary, _me: Dictionary) -> float:
	return 1.0


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.1 + 0.4 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	var words: Array = EVENING if float(me.late) > 0.5 else DAY
	return [["face", "place"], ["say", line(cue, me, words)], ["wave"], ["wait", 0.8]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 6.0


const DAY := ["I'd best be off.", "Right, work calls.", "See you later, then.", "I'll leave you to it.", "Must go."]
const EVENING := ["Good night, all.", "Home for me.", "Sleep well.", "Until tomorrow.", "My bed's calling."]
