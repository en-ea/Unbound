extends RefCounted
## What a reaction may know of a person answering a cue (plan LIVELY-VILLAGE 3.1: `me`), read from the rules' state
## through their own helpers and never written. reaction.gd lists the fields.
##
##   ReactionFacts.of(v, id, cue, at) -> Dictionary      at: where the body stands (Vector2)
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")

## Verbs that are work waiting (someone at them goes back soon).
const WORK := ["farming", "woodcutting", "milling", "smithing", "herding", "gathering", "fetching_water", "trading",
	"hunting", "baking", "building"]
const FRIEND := 40           # a feeling this warm is a friend


static func of(v: S.Village, id: int, cue: Dictionary, at: Vector2) -> Dictionary:
	var p := v.people[id]
	var age := Village.age_of(v, p)
	var t := p.traits
	var subject := int(cue.get("subject", -1))
	var other := int(cue.get("other", -1))
	var act := View.activity(v, id)
	var minute := int(v.runtime.now) % 1440 if not v.runtime.is_empty() else 720
	var children: Array = []
	var friends: Array = []
	var parent := -1
	var kin: Array = []
	for o: int in cue.get("who", []):
		if o == id or o < 0 or o >= v.people.size():
			continue
		var q := v.people[o]
		if Village.is_kin(v, id, o):
			kin.append(o)
		if q.father == id or q.mother == id:
			children.append(o)
		elif p.father == o or p.mother == o:
			parent = o
		elif Village.opinion(v, id, o) >= FRIEND:
			friends.append(o)
	return {
		"id": id, "name": p.name, "sex": p.sex, "role": p.role, "household": p.household,
		"age_group": "child" if age < 14 else "elder" if age >= 60 else "adult",
		"traits": {"bold": t[C.BOLD], "piety": t[C.PIETY], "greed": t[C.GREED], "compassion": t[C.COMPASSION],
			"honesty": t[C.HONESTY], "temper": t[C.TEMPER], "alert": t[C.ALERT], "sociable": t[C.SOCIABLE]},
		"values": {"law": p.values[C.V_LAW] if p.values.size() > C.V_MERCY else 50,
			"mercy": p.values[C.V_MERCY] if p.values.size() > C.V_MERCY else 50,
			"faith": p.values[C.V_FAITH] if p.values.size() > C.V_MERCY else 50},
		"kin": subject >= 0 and subject != id and Village.is_kin(v, id, subject),
		"feeling": Village.opinion(v, id, subject) if subject >= 0 and subject != id else 0,
		"feeling_other": Village.opinion(v, id, other) if other >= 0 and other != id else 0,
		"feeling_player": int(View.toward_player(v, id).feeling),
		"mood": View.mood(v, id),
		"busy": str(act.get("verb", "")) in WORK,
		"late": clampf(float(minute - 1020) / 240.0, 0.0, 1.0),
		"distance": at.distance_to(cue.get("place", at)),
		"parent_there": parent, "children_there": children, "friends_there": friends, "kin_there": kin,
		"authority": id == v.authority, "priest": id == v.priest,
		"cast": "",
	}
