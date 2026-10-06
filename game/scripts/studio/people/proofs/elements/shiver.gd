extends "res://scripts/studio/people/element.gd"
const ID := "shiver"
const HOLDS := false
const GIVES := "shiver"
func begin(port: Dictionary, strength: float, _fact: Dictionary) -> Dictionary:
	port.emit.call("shiver",{"strength":strength})
	return {"age":0.0}
func step(_port: Dictionary, st: Dictionary, dt: float) -> bool:
	st.age += dt
	return st.age>=0.1
