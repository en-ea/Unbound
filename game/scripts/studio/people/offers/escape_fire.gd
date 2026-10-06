extends "res://scripts/studio/people/offer.gd"
const ID := "escape_fire"
const ANSWERS := ["fire","burning"]
const ROLES := ["burning victim"]
const PRIORITY := 6
func can(me: Dictionary,a: Dictionary) -> bool:
	return a.target==me.key and a.evidence.get("act","") in ["burn","burning"] and not (a.get("affordances",{}).get("water",{}) as Dictionary).is_empty()
func score(_me: Dictionary,_a: Dictionary) -> int:
	return 1200
func steps(me: Dictionary,a: Dictionary) -> Array:
	var water: Dictionary=a.affordances.water
	return [{"op":"say","text":"I was saving that skin for winter."},
		{"op":"travel","target":water.key,"pace":"run","short":0.3},
		{"op":"use","verb":"extinguish","target":me.key,"method":"water","cause_id":a.deed,"affordance":water.key},
		{"op":"wait","seconds":1.0}]
func lasts(_me: Dictionary,_a: Dictionary) -> float:
	return 20.0
