extends "res://scripts/studio/people/element.gd"
## A thing broken (graphics S4). The lasting broken fact {by}: the piece is gone and its debris lies where it stood,
## charred as far as the thing was. Repair (the fact removed) puts it back.
const ID := "broken"
const HOLDS := false
const GIVES := ""


func begin(port: Dictionary, _strength: float, fact: Dictionary) -> Dictionary:
	port.pose.call(ID, {"broken": true})
	return {"fact": fact}


func step(port: Dictionary, st: Dictionary, _dt: float) -> bool:
	return not port.live.call(st.fact)


func end(port: Dictionary, _st: Dictionary) -> void:
	port.drop_pose.call(ID)
