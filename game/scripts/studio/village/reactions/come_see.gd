extends "res://scripts/studio/village/reaction.gd"
## His kill brought into the village: children and the curious come running to see it, gape, and say so.
const ANSWERS := ["kill"]


static func weight(_cue: Dictionary, me: Dictionary) -> float:
	if me.busy and me.age_group == "adult":
		return 0.2
	return (2.4 if me.age_group == "child" else 0.4 + 1.2 * high(me, "alert") + 0.6 * high(me, "sociable"))


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.4 + 2.0 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	var run := "run" if me.age_group == "child" else "hurry"
	return [["face", "player"], ["near", "player", 3.0 + 1.5 * roll(cue, me, 2), run], ["face", "player"],
		["clip", "Yes" if me.age_group != "child" else "Jump"], ["say", line(cue, me, WOW)],
		["follow", "player", 6.0 + 8.0 * roll(cue, me, 3)]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 40.0


const WOW := ["Look at the size of it!", "Did you kill that yourself?", "Is it dead dead?", "A whole one!",
	"There'll be meat tonight!", "Mother! Come and see!"]
