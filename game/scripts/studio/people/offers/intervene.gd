extends "res://scripts/studio/people/offer.gd"
const ID := "intervene"
const ANSWERS := ["contact","threat"]
const ROLES := ["friend","helper"]
const PRIORITY := 4
func can(me: Dictionary, a: Dictionary) -> bool:
	return a.target != me.key and a.target != "unknown" and (me.concern >= 30 or (a.via == "told" and me.law >= 55)) and me.courage >= 35
func score(me: Dictionary, a: Dictionary) -> int:
	return 550+me.concern*3+me.courage + (150 if a.via == "told" else 0)
func steps(me: Dictionary, a: Dictionary) -> Array:
	var line := "Find a tree. It has no friends."
	if a.via == "told":
		line = "I left my supper for this. Someone had better still be alive."
	elif me.hits > 1:
		line = "One more, and you can explain it to the rope."
	return [{"op":"travel","target":a.target,"short":2.2,"pace":"hurry"},
		{"op":"face","target":a.identity.key},{"op":"say","text":line},{"op":"wait","seconds":5.0}]
func lasts(_me: Dictionary, _a: Dictionary) -> float:
	return 25.0
