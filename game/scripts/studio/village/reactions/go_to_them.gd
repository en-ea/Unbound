extends "res://scripts/studio/village/reaction.gd"
## Kin and friends go to the one it was done to: hurry to them, a word of comfort, and walk them home. The rules cast
## who does (decide): their feeling for them warms, and the one comforted is eased.
const ANSWERS := ["end:"]
const PRIORITY := 4


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if not _alive(cue) or int(cue.get("subject", -1)) < 0:
		return 0.0
	if me.kin:
		return 3.0
	return 1.6 if float(me.feeling) >= 40.0 else 0.0


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.4 + 1.2 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	var words := line(cue, me, KIN if me.kin else FRIEND)
	return [["near", "subject", 1.6, "hurry"], ["say", words], ["nod"], ["follow", "subject", 20.0 + 15.0 * roll(cue, me, 2)]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 70.0


## (rules) Kin, then friends, of the one it was done to who were there: two at most, the closest first.
static func decide(v, cue: Dictionary, _k: int) -> Dictionary:
	var s := int(cue.get("subject", -1))
	if s < 0 or not _alive(cue):
		return {}
	var Village = load("res://scripts/studio/village/sim/village.gd")
	var ranked: Array = []
	for id: int in cue.get("who", []):
		if id == s or not v.people[id].alive:
			continue
		var f: int = Village.opinion(v, id, s)
		if Village.is_kin(v, id, s) or f >= 40:
			ranked.append([-(f + (100 if Village.is_kin(v, id, s) else 0)), id])
	ranked.sort()
	var cast: Array = []
	var effects: Array = []
	for r: Array in ranked.slice(0, 2):
		cast.append(int(r[1]))
		effects.append(["opinion", int(r[1]), s, 6])        # it brings them closer
		effects.append(["opinion", s, int(r[1]), 8])
		effects.append(["stress", s, -1, -20])              # and eases the one comforted
	return {"cast": cast, "effects": effects}


static func _alive(cue: Dictionary) -> bool:
	return bool(cue.get("alive", true)) and not has(cue, "died") and not has(cue, "exiled")


const KIN := ["Come on, %s. Home.", "It's over now, %s. Lean on me.", "Let's get you home, %s.",
	"Don't look at them. Come.", "You're coming home with me."]
const FRIEND := ["%s! Are you hurt?", "I'm here, %s. Come on.", "Walk with me, %s.", "Don't mind them, %s."]
