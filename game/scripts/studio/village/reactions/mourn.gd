extends "res://scripts/studio/village/reaction.gd"
## Kin at a death: to the place, down on their knees by it, a long while, then home slowly. The rules cast who does
## (decide): grief stays with them (stress), which mourning and condolences read later.
const ANSWERS := ["end:"]
const PRIORITY := 4


static func weight(cue: Dictionary, me: Dictionary) -> float:
	return 4.0 if has(cue, "died") and me.kin else 0.0


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.3 + 1.0 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["clip", "Hit_Chest"], ["say", line(cue, me, GRIEF)], ["near", "place", 2.0, "hurry"], ["face", "place"],
		["clip", "Fixing_Kneeling"], ["loop", "Fixing_Kneeling", 30.0 + 40.0 * roll(cue, me, 2)], ["home", "stroll"]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 120.0


## (rules) Every kin of the dead who was there; grief stays with them.
static func decide(v, cue: Dictionary, _k: int) -> Dictionary:
	var s := int(cue.get("subject", -1))
	if s < 0 or not has(cue, "died"):
		return {}
	var Village = load("res://scripts/studio/village/sim/village.gd")
	var cast: Array = []
	var effects: Array = []
	for id: int in cue.get("who", []):
		if id != s and v.people[id].alive and Village.is_kin(v, id, s):
			cast.append(id)
			effects.append(["stress", id, -1, 60])
	return {"cast": cast, "effects": effects}


const GRIEF := ["No... no, %s!", "%s!", "Why? Why %s?", "Not %s. Not like this."]
