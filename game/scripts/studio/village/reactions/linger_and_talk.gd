extends "res://scripts/studio/village/reaction.gd"
## The curious and the sociable stay on: a knot of two to four near the place, talking it over, leaving one by one.
const ANSWERS := ["end:"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if me.age_group == "child" or (cue.get("who", []) as Array).size() < 4:
		return 0.0
	return maxf(0.0, 0.3 + 1.2 * high(me, "sociable") + 0.6 * high(me, "alert") - (0.8 if me.busy else 0.0) - 0.6 * float(me.late))


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 1.5 + 5.0 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["face", "subject" if int(cue.get("subject", -1)) >= 0 else "place"], ["clip", "Idle_Talking"],
		["say", line(cue, me, opening(cue))], ["knot", 25.0 + 45.0 * roll(cue, me, 2)], ["nod"]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 100.0


static func opening(cue: Dictionary) -> Array:
	if has(cue, "died"):
		return ["I never thought they'd go through with it.", "God rest %s.", "Did you see the elder's face?"]
	if has(cue, "rescued"):
		return ["Did you see who freed %s?", "The elder won't stand for that.", "Somebody had to."]
	if has(cue, "released") or has(cue, "acquitted"):
		return ["Well, %s's paid for it.", "A day in the stocks never killed anyone.", "Will %s learn, you think?",
			"Hard to watch, that.", "I'd have let %s off."]
	if has(cue, "guilty") or has(cue, "exiled"):
		return ["Guilty. I knew it.", "I'd not have believed it of %s.", "What becomes of the family now?"]
	return ["What do you make of that?", "Well, there's something to talk about.", "Did you hear what was said?"]
