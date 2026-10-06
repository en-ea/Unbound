extends "res://scripts/studio/village/reaction.gd"
## It went against them: a shake of the head, a mutter, a glare at whoever decided it, and off in a mood.
const ANSWERS := ["end:"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if has(cue, "died"):
		return 0.0
	var mercy := clampf((float(me.values.mercy) - 55.0) / 40.0, 0.0, 1.0)
	if has(cue, "guilty") or has(cue, "exiled") or has(cue, "pillory") or has(cue, "stocks"):
		return 1.2 * mercy + (1.0 if float(me.feeling) >= 30.0 and not me.kin else 0.0) + 0.4 * high(me, "temper")
	if has(cue, "acquitted") or has(cue, "rescued"):
		return 1.2 if float(me.feeling) <= -25.0 else 0.0
	return 0.0


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	var at := "other" if int(cue.get("other", -1)) >= 0 else "place"
	return [["clip", "Idle_No"], ["face", at], ["say", line(cue, me, MUTTER)], ["wait", stand_on(cue, me, 7.0, 0.6, 3.0)],
		["go", "away", "walk", 0.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 30.0


const MUTTER := ["That wasn't right.", "Too harsh by half.", "The elder's gone soft.", "This isn't over.",
	"Some justice.", "Mark my words, we'll regret this."]
