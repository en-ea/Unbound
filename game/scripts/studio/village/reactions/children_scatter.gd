extends "res://scripts/studio/village/reaction.gd"
## Children: off at a run as soon as it is over, in twos and threes (a chase), or to a parent who was there.
const ANSWERS := ["end:"]


static func weight(_cue: Dictionary, me: Dictionary) -> float:
	return 2.5 if me.age_group == "child" else 0.0


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.4 + 3.5 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	var parent := int(me.parent_there)
	if parent >= 0 and (has(cue, "died") or roll(cue, me, 2) < 0.5):
		return [["clip", "Jump" if not has(cue, "died") else "Idle_No"], ["near", parent, 1.2, "jog"], ["face", parent],
			["wait", 6.0 + 6.0 * roll(cue, me, 3)]]
	if has(cue, "died"):
		return [["clip", "Hit_Head"], ["go", "home", "run"]]
	return [["clip", pick(cue, me, ["Jump", "Dance", "Yes"])], ["say", line(cue, me, SHOUTS) if roll(cue, me, 4) < 0.5 else ""],
		["go", "away", "run", 0.0], ["clip", "Jump"]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 30.0


const SHOUTS := ["Race you!", "Did you see?", "Catch me!", "I'm telling Mother!", "Come on!"]
