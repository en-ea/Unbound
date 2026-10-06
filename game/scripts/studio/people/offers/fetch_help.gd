extends "res://scripts/studio/people/offer.gd"
const ID := "fetch_help"
const ANSWERS := ["contact","threat"]
const ROLES := ["timid witness"]
const PRIORITY := 3
func can(me: Dictionary, a: Dictionary) -> bool:
	return a.target != me.key and a.target != "unknown" and me.courage < 40 and not str(me.helper).is_empty() and a.via != "told"
func score(me: Dictionary, _a: Dictionary) -> int:
	return 650 + me.fear / 3
func steps(me: Dictionary, a: Dictionary) -> Array:
	return [{"op":"say","text":"I will fetch someone with a sturdier conscience."},
		{"op":"travel","target":me.helper,"short":2.4,"pace":"run"},
		{"op":"report","target":me.helper,"account":a.duplicate(true)},
		{"op":"travel","target":a.target,"short":4.0,"pace":"hurry"},
		{"op":"say","text":"Here. I brought a witness to my cowardice."},{"op":"wait","seconds":2.0}]
func lasts(_me: Dictionary, _a: Dictionary) -> float:
	return 60.0
