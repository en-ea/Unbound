extends "res://scripts/studio/village/reaction.gd"
## The pious stay to pray after a death or a rite: a bow, then hands together facing the place a while.
const ANSWERS := ["end:"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if not (has(cue, "died") or has(cue, "rite")):
		return 0.0
	return 2.0 * high(me, "piety") + (0.8 if me.priest else 0.0)


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 1.0 + 3.0 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["face", "place"], ["nod"], ["say", line(cue, me, PRAYERS) if roll(cue, me, 2) < 0.5 else ""],
		["loop", "Spell_Simple_Idle", 18.0 + 30.0 * roll(cue, me, 3)], ["nod"], ["go", "away", "stroll", 0.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 45.0


const PRAYERS := ["Rest now.", "Keep %s, and keep us.", "May the earth be kind.", "Forgive us."]
