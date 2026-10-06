extends "res://scripts/studio/village/reaction.gd"
## The default end: a last look, a word or a shake of the head by how they feel about it, now and then a glance back,
## and back to their day at their own moment (retires the crowd's leave in step with the rest: stage.gd _imply_leaves).
const ANSWERS := ["end:"]


static func weight(_cue: Dictionary, me: Dictionary) -> float:
	return 0.8 if me.age_group != "child" else 0.3


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	var out: Array = [["face", "subject" if int(cue.get("subject", -1)) >= 0 else "place"]]
	var f := float(me.feeling)
	if has(cue, "died") or has(cue, "exiled"):
		out.append(["clip", "Idle_No"] if roll(cue, me, 2) < 0.6 else ["nod"])
	elif f >= 20.0:
		out.append(["nod"])
	elif f <= -20.0:
		out.append(["clip", "Idle_No"])
	else:
		out.append(["clip", pick(cue, me, ["Yes", "Idle_No", "Idle_FoldArms"])])
	if roll(cue, me, 3) < 0.35:
		out.append(["say", line(cue, me, MUTTERS)])
	out.append(["wait", stand_on(cue, me, 14.0, 0.7, 3.0)])
	out.append(["go", "away", "walk", 0.0])
	if roll(cue, me, 4) < 0.4:
		out.append(["face", "place"])                     # a glance back
		out.append(["wait", 0.8 + 1.2 * roll(cue, me, 5)])
	return out


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 40.0


const MUTTERS := ["Well, that's done.", "Back to it, then.", "Poor %s.", "That'll be talked of tonight.",
	"I've seen worse.", "Let's hope that's the end of it.", "Not a day I'll forget.", "Come on, the day's not over."]
