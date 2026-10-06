extends "res://scripts/studio/village/reaction.gd"
## A death: some do not leave at once. They stand where they were, facing it, hands still, a long while - the ones who
## knew them a little, the steady ones - and go only when they are ready, slowly.
const ANSWERS := ["end:"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if not has(cue, "died") or me.age_group == "child":
		return 0.0
	return 0.5 + 0.6 * high(me, "piety") + 0.5 * high(me, "compassion") + (0.6 if float(me.feeling) >= 15.0 else 0.0) \
		- (0.5 if me.busy else 0.0)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["face", "place"], ["nod"], ["wait", stand_on(cue, me, 30.0, 0.5, 2.0)],
		["clip", "Idle_No"] if roll(cue, me, 2) < 0.5 else ["nod"], ["go", "away", "stroll", 0.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 120.0
