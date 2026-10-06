extends "res://scripts/studio/village/reaction.gd"
## A death seen close: a flinch at their own moment, a step back, a hand over the mouth (retires the crowd's flinch
## in step: stage.gd _crowd_flinches).
const ANSWERS := ["end:"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if not has(cue, "died"):
		return 0.0
	return 1.5 - minf(float(me.distance) / 10.0, 1.2)


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.2 + 1.4 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["clip", pick(cue, me, ["Hit_Chest", "Hit_Head"])], ["back", "place", 0.9], ["wait", stand_on(cue, me, 12.0, 0.8, 3.0)],
		["clip", "Idle_No"], ["go", "away", "walk", 0.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 30.0
