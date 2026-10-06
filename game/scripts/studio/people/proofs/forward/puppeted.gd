extends "res://scripts/studio/people/modifier.gd"
## One-file forward rule: an instruction carries the controller actor and keyed order; appraisal remains the body's.
const ID := "puppeted"
func choose(_me: Dictionary, _a: Dictionary, row: Dictionary) -> Dictionary:
	var order: Dictionary = row.get("order",{})
	if order.get("actor","") != row.get("controller","") or str(order.get("key","")).is_empty():
		return {}
	return {"offer":str(order.offer),"controller":str(row.controller),"order":str(order.key)}
static func prove(v, target: int, account: Dictionary) -> bool:
	var People := preload("res://scripts/studio/village/sim/people.gd")
	var Codec := preload("res://scripts/studio/village/sim/save.gd")
	var m = v.people[target].mind
	var actor := "actor:hidden-fourth"
	m.modifiers.append({"id":"puppeted","controller":actor,"order":{"actor":actor,"key":"order:1","offer":"settle"}})
	var me := People.profile(v,People.key(v,target),account)
	var choice := preload("res://scripts/studio/people/chooser.gd").new("res://scripts/studio/people/offers/","res://scripts/studio/people/proofs/forward/").pick(me,account)
	if choice.get("offer","") != "settle":
		return false
	People.learn(v,account,preload("res://scripts/studio/people/chooser.gd").new("res://scripts/studio/people/offers/","res://scripts/studio/people/proofs/forward/"))
	if m.plan.offer!="settle":
		return false
	var remembered: int = m.known.size()
	m.modifiers.clear()
	var restored = Codec.from_data(Codec.to_data(v,false))
	return remembered==1 and restored.people[target].mind.known.has(str(account.key)) and restored.people[target].mind.modifiers.is_empty()
