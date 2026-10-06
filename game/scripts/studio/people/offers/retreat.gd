extends "res://scripts/studio/people/offer.gd"
const ID := "retreat"
const ANSWERS := ["contact","threat"]
const ROLES := ["hurt victim"]
const PRIORITY := 5
func can(me: Dictionary, a: Dictionary) -> bool:
	return a.target == me.key and (me.pain >= 850 or (me.hits > 1 and me.courage < 55))
func score(me: Dictionary, _a: Dictionary) -> int:
	return 900+me.pain/4
func steps(_me: Dictionary, a: Dictionary) -> Array:
	return [{"op":"say","text":"Keep the apology. I need the distance."},
		{"op":"travel","target":"home","short":1.0,"pace":"hurry"},
		{"op":"face","target":a.identity.key},{"op":"wait","seconds":3.0}]
func lasts(_me: Dictionary, _a: Dictionary) -> float:
	return 40.0
