extends "res://scripts/studio/people/offer.gd"
## A tenant talks about their landlord (Mind's port, the creative unit, desk 6 Oct): one who feels strongly about the
## player walks to a neighbour and tells them what the player did (the report step: the neighbour learns it as told,
## at retelling strength). It answers no observation, so the chooser never picks it; port_routine.gd writes it, at
## most once a day for each tenant, only while the mind is idle, and any reaction replaces it.
const ID := "tell"
const ANSWERS := ["tell"]
const ROLES := ["tenant"]
const PRIORITY := -90
func can(_me: Dictionary, a: Dictionary) -> bool:
	return str(a.get("kind","")) == "tell"
## a {kind "tell", listener (actor key), account (the tenant's own account of the deed)}
func steps(_me: Dictionary, a: Dictionary) -> Array:
	return [{"op":"travel","target":str(a.listener),"pace":"walk","short":2.0},
		{"op":"report","target":str(a.listener),"account":(a.account as Dictionary).duplicate(true)},
		{"op":"wait","seconds":2.0}]
func lasts(_me: Dictionary, _a: Dictionary) -> float:
	return 40.0
