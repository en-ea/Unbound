extends "res://scripts/studio/village/reaction.gd"
## An enemy in the village: the timid and the near run for their door, a cry on the way.
const ANSWERS := ["enemy"]


static func weight(_cue: Dictionary, me: Dictionary) -> float:
	var near := 1.0 - clampf(float(me.distance) / 25.0, 0.0, 1.0)
	return 0.6 + 1.6 * low(me, "bold") + 1.2 * near + (0.8 if me.age_group != "adult" else 0.0)


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.2 + 1.0 * roll(cue, me, 1) + float(me.distance) * 0.04


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["face", "enemy"], ["clip", "Hit_Chest"], ["say", line(cue, me, CRIES) if roll(cue, me, 2) < 0.6 else ""],
		["home", "run"]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 45.0


const CRIES := ["A wolf! A wolf in the village!", "Run! Inside!", "Get inside!", "It's coming this way!", "Help!"]
