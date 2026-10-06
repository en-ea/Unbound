extends "res://scripts/studio/people/offer.gd"
## Helper's own concern/courage competes through the existing chooser, with real travel/use.
const ID := "help_fire"
const ANSWERS := ["fire","burning"]
const ROLES := ["concerned helper"]
const PRIORITY := 6
func can(me: Dictionary,a: Dictionary) -> bool:
	return a.target!="unknown" and a.target!=me.key and int(me.get("concern",0))>=30 and int(me.get("courage",0))>=25 and int(me.get("fear",0))<850
func score(me: Dictionary,_a: Dictionary) -> int:
	return 800+int(me.get("concern",0))
func steps(_me: Dictionary,a: Dictionary) -> Array:
	return [{"op":"travel","target":a.target,"pace":"run","short":1.0},
		{"op":"use","verb":"extinguish","target":a.target,"method":"beat","cause_id":a.deed},
		{"op":"wait","seconds":1.0}]
func lasts(_me: Dictionary,_a: Dictionary) -> float:
	return 25.0
