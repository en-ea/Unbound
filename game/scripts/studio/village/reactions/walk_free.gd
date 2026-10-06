extends "res://scripts/studio/village/reaction.gd"
## The one let go (from the pillory, the stocks): off the boards, a breath - rubbing the wrists, a look round - and, with
## their kin come to them, a word; then home, slowly, the kin beside them (go_to_them.gd follows). Alone, a glance back
## at those who watched first.
const ANSWERS := ["freed:"]
const PRIORITY := 4          # (nothing small takes them from this)


static func weight(_cue: Dictionary, _me: Dictionary) -> float:
	return 1.0


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.2 + 0.6 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	var out: Array = [["clip", "Idle_No"], ["wait", 1.5 + 2.0 * roll(cue, me, 2)]]
	if not (me.get("kin_there", []) as Array).is_empty():
		out.append(["wait", 2.0])                                  # (the kin come up)
		out.append(["say", line(cue, me, WITH_KIN)])
	else:
		out.append(["face", "place"])
		out.append(["say", line(cue, me, ALONE) if roll(cue, me, 3) < 0.5 else ""])
	out.append(["home", "stroll"])
	return out


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 90.0


const WITH_KIN := ["Take me home.", "I'm all right. I'm all right.", "Don't. Just walk with me.", "Let's go."]
const ALONE := ["Enjoy that, did you?", "...", "Well. That's done.", "I'll not forget who threw."]
