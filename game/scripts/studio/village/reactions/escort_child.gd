extends "res://scripts/studio/village/reaction.gd"
## A hard end with a child of theirs there: a parent goes to the child and takes them home.
const ANSWERS := ["end:", "enemy"]


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if (me.children_there as Array).is_empty() or me.age_group == "child":
		return 0.0
	if str(cue.kind).begins_with("enemy"):
		return 3.0
	return 2.2 if has(cue, "died") or has(cue, "burning") or has(cue, "hanging") else 0.3


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.3 + 1.2 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	var child: int = (me.children_there as Array)[0]
	var pace := "run" if str(cue.kind).begins_with("enemy") else "hurry"
	return [["near", child, 1.2, pace], ["say", line(cue, me, WORDS)], ["home", "jog" if pace == "run" else "walk"]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 60.0


const WORDS := ["Come here. We're going home.", "Don't look. Come.", "Inside, now!", "Hold my hand."]
