extends "res://scripts/studio/village/reaction.gd"
## Those it went the way they wanted: a nod or a cheer, a word to whoever is beside them. The law-minded at a guilty
## verdict or a sentence served; friends at a release or an acquittal.
const ANSWERS := ["end:"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if has(cue, "died"):
		return 0.0
	var law := clampf((float(me.values.law) - 55.0) / 40.0, 0.0, 1.0)
	if has(cue, "guilty") or has(cue, "exiled"):
		return 1.4 * law + (0.8 if float(me.feeling) <= -20.0 else 0.0)
	if has(cue, "acquitted") or has(cue, "released") or has(cue, "rescued"):
		return 1.2 if float(me.feeling) >= 25.0 and not me.kin else 0.0
	return 0.0


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	var words: Array = JUST if has(cue, "guilty") or has(cue, "exiled") else GLAD
	return [["clip", "Yes"], ["say", line(cue, me, words)], ["nod"], ["wait", stand_on(cue, me, 8.0, 0.6, 3.0)],
		["go", "away", "walk", 0.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 30.0


const JUST := ["Justice done.", "That's the law, and right too.", "Good. Let that be a lesson.", "The elder judged well."]
const GLAD := ["Free! Good.", "I'm glad of it.", "Welcome back, %s!", "That's the end of that, thank God."]
