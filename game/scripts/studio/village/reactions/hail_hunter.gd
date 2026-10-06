extends "res://scripts/studio/village/reaction.gd"
## His kill brought into the village: those whose trade knows game (a hunter, a herder whose flock it threatened) stop,
## turn, and call out to him; the rest look up from their work a moment.
const ANSWERS := ["kill"]


static func weight(_cue: Dictionary, me: Dictionary) -> float:
	if me.age_group == "child":
		return 0.0
	return (2.0 if me.role in ["hunter", "herder"] else 0.6) + (0.8 if float(me.feeling_player) >= 20.0 else 0.0)


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.3 + 1.8 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	if me.role in ["hunter", "herder"] or roll(cue, me, 2) < 0.4:
		return [["face", "player"], ["wave"], ["say", line(cue, me, HAIL)], ["wait", 2.0 + 2.0 * roll(cue, me, 3)]]
	return [["face", "player"], ["nod"], ["wait", 1.5 + 2.0 * roll(cue, me, 3)]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 15.0


const HAIL := ["Good hunting!", "That one won't take any more lambs.", "Take it to the butcher, he'll pay well.",
	"Clean kill, that.", "Heavy, is it? You've earned your supper."]
