extends "res://scripts/studio/village/reaction.gd"
## Those who dislike the one it was done to, and have little pity or a short fuse, jeer: a thrust of the hand and a
## taunt, then off. The rules cast who does (decide): the one jeered at remembers it.
const ANSWERS := ["end:"]
const PRIORITY := 4


static func weight(cue: Dictionary, me: Dictionary) -> float:
	if int(cue.get("subject", -1)) < 0 or has(cue, "died") or me.kin or float(me.feeling) > -25.0:
		return 0.0
	return 0.6 + 1.2 * low(me, "compassion") + 0.8 * high(me, "temper") + (0.6 if me.age_group == "child" else 0.0)


static func delay(cue: Dictionary, me: Dictionary) -> float:
	return 0.5 + 2.0 * roll(cue, me, 1)


static func steps(cue: Dictionary, me: Dictionary) -> Array:
	return [["face", "subject"], ["clip", "Spell_Simple_Shoot"], ["say", line(cue, me, TAUNTS)], ["wait", stand_on(cue, me, 4.0, 0.5, 2.5)],
		["clip", "Yes" if roll(cue, me, 2) < 0.5 else "Idle_FoldArms"], ["go", "away", "walk", 0.0]]


static func lasts(_cue: Dictionary, _me: Dictionary) -> float:
	return 30.0


## (rules) Two at most of those there who dislike them (-30 or less) and have little pity (compassion under 45) or a
## temper (65 or more).
static func decide(v, cue: Dictionary, _k: int) -> Dictionary:
	var s := int(cue.get("subject", -1))
	if s < 0 or has(cue, "died"):
		return {}
	var Village = load("res://scripts/studio/village/sim/village.gd")
	var C = load("res://scripts/studio/village/sim/content.gd")
	var ranked: Array = []
	for id: int in cue.get("who", []):
		if id == s or not v.people[id].alive or Village.is_kin(v, id, s):
			continue
		var f: int = Village.opinion(v, id, s)
		var t: PackedInt32Array = v.people[id].traits
		if f <= -30 and (t[C.COMPASSION] < 45 or t[C.TEMPER] >= 65):
			ranked.append([f, id])
	ranked.sort()
	var cast: Array = []
	var effects: Array = []
	for r: Array in ranked.slice(0, 2):
		cast.append(int(r[1]))
		effects.append(["opinion", s, int(r[1]), -10])      # the one jeered at remembers who
	return {"cast": cast, "effects": effects}


const TAUNTS := ["Serves you right, %s!", "Thief!", "Not so proud now, %s!", "Back in there soon, I'll wager!",
	"Remember this, %s!", "Shame on your house!", "We all saw, %s!"]
