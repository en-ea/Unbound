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
## A human's time, not an instant (desk 6 Oct: a helper beside a freshly lit villager put the flames out in the same
## moment, before any harm, 12 of 12 Flame Dashes): a beat to take it in and start forward (the slower the less alert),
## then the run, then beating at the flames for a while before they are out. Fire catches and hurts first; a helper
## already beside them still needs the beating time.
const TAKE_IN_S := 0.3          # at alertness 100; up to 0.6 s at 0
const BEATING_S := 1.2          # beating the flames out with hands and cloth
func steps(me: Dictionary,a: Dictionary) -> Array:
	var take_in := TAKE_IN_S+0.3*float(100-clampi(int(me.get("alert",50)),0,100))/100.0
	return [{"op":"wait","seconds":take_in},
		{"op":"travel","target":a.target,"pace":"run","short":1.0},
		{"op":"wait","seconds":BEATING_S},
		{"op":"use","verb":"extinguish","target":a.target,"method":"beat","cause_id":a.deed},
		{"op":"wait","seconds":1.0}]
func lasts(_me: Dictionary,_a: Dictionary) -> float:
	return 25.0
