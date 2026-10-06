extends "res://scripts/studio/people/element.gd"
## What a fire leaves on a thing (graphics S4). The lasting scorched fact {level 0..1000} (strength when level is
## absent): soot first, then char from a third of the way. No effect of its own; burning shows the fire.
const ID := "scorched"
const HOLDS := false
const GIVES := ""


func begin(port: Dictionary, strength: float, fact: Dictionary) -> Dictionary:
	var st := {"fact": fact}
	_post(port, st, fact)
	return st


func step(port: Dictionary, st: Dictionary, _dt: float) -> bool:
	if not port.live.call(st.fact):
		return true
	var now: Dictionary = port.current.call(st.fact)
	_post(port, st, now if not now.is_empty() else st.fact)
	return false


func end(port: Dictionary, _st: Dictionary) -> void:
	port.drop_pose.call(ID)


func _post(port: Dictionary, _st: Dictionary, fact: Dictionary) -> void:
	var level := clampf(float(fact.get("level", fact.get("strength", 1000))) / 1000.0, 0.0, 1.0)
	port.pose.call(ID, {"surface": {"soot": clampf(level * 3.0, 0.0, 1.0), "char": clampf((level - 0.33) * 1.5, 0.0, 1.0)}})
