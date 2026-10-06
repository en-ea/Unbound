extends "res://scripts/studio/people/offer.gd"
const ID := "protest"
const ANSWERS := ["contact","threat","gift"]
const ROLES := ["victim"]
const PRIORITY := 2
func can(me: Dictionary, a: Dictionary) -> bool:
	return a.target == me.key and a.evidence.get("act","") != "gift" and me.pain < 850
func score(me: Dictionary, _a: Dictionary) -> int:
	return 500 + me.anger / 3
func steps(me: Dictionary, a: Dictionary) -> Array:
	var line := "Was that your argument? It has terrible manners."
	if me.hits > 1:
		line = "Again? At least the pillory only hits me once."
	return [{"op":"face","target":a.identity.key},{"op":"say","text":line},
		{"op":"wait","seconds":2.5},{"op":"say","text":"I will remember your hands."},{"op":"wait","seconds":2.0}]
