extends "res://scripts/studio/people/offer.gd"
## A ported resident's day (Mind's port, plan MIND-PORT-PLAN-2026-10-06): walk to Enea's anchor for the hour (his
## work spot, the green at lunch, the fire in the evening) and stay there. It answers no observation: nothing a
## villager perceives has the kind "routine", so the chooser never picks it, and every reaction outranks it by
## replacing the plan. port_routine.gd writes it, through acceptance, only while the mind has no ongoing plan.
const ID := "routine"
const ANSWERS := ["routine"]
const ROLES := ["resident"]
const PRIORITY := -100
func can(_me: Dictionary, a: Dictionary) -> bool:
	return str(a.get("kind","")) == "routine"
func score(_me: Dictionary, _a: Dictionary) -> int:
	return 0
func effects(_me: Dictionary, a: Dictionary) -> Dictionary:
	return {"act":str(a.get("act",""))}
## a {kind "routine", act, at [x, z] metres}: go there at a walk, then stay until the plan's hour ends.
func steps(_me: Dictionary, a: Dictionary) -> Array:
	return [{"op":"travel","target":Array(a.at).duplicate(),"pace":"walk","short":0.8},{"op":"wait","seconds":100000.0}]
