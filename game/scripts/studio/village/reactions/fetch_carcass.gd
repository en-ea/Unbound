extends "res://scripts/studio/village/reaction.gd"
## A carcass left lying by the village: the one who came for it walks over, kneels to it, takes it, and goes home with
## it (cues/carcass_left.gd; the taking is the director's "do": world/carcass.gd's vanish, seen to happen).
const ANSWERS := ["carcass"]


static func weight(_cue: Dictionary, me: Dictionary) -> float:
	return 0.0 if me.age_group == "child" else 1.0


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.5 + 1.5 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["face", "node"], ["say", line(cue, me, FIND) if roll(cue, me, 2) < 0.6 else ""], ["near", "node", 1.1, "walk"],
		["face", "node"], ["clip", "Fixing_Kneeling"], ["do", "take"], ["loop", "Fixing_Kneeling", 1.5], ["home", "walk"]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 70.0


const FIND := ["Shame to waste that.", "Left it, has he? Well.", "That'll feed us a week.", "Nobody wants it? I do.",
	"Before the crows have it all."]
