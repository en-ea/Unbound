extends "res://scripts/studio/people/element.gd"
## Carried (B6; visual by the animation specialist). The accepted carried fact {carrier, at} as a body borne along
## (Body places it by its carrier): on its back, knees drawn up, the head hanging back, turned a little onto its side,
## a shape a corpse keeps too (`keep`: death's stillness does not flatten it). Every other element goes on over it: a
## living body's breath and pain, a burning one's thrashing. When the fact goes the shape eases out where Body set it
## down and the posture under it (down, dead) or the body's own stance takes over; down gets up from there.
const ID := "carried"
const HOLDS := true
const GIVES := "load"
const G := preload("res://scripts/studio/people/gestures.gd")


func begin(port: Dictionary, _strength: float, fact: Dictionary) -> Dictionary:
	var st := {"fact": fact, "t": 0.0}
	_post(port, st)
	return st


func step(port: Dictionary, st: Dictionary, dt: float) -> bool:
	if not port.live.call(st.fact):
		return true
	st.t += dt
	_post(port, st)
	return false


func end(port: Dictionary, _st: Dictionary) -> void:
	port.drop_pose.call(ID)


func _post(port: Dictionary, st: Dictionary) -> void:
	port.pose.call(ID, G.timed({"posture": {"name": "carried", "clip": G.LIE_CLIP, "at": G.LIE_AT, "blend": 0.35},
		"knee_l": 0.55, "knee_r": 0.6, "head": Vector3(-0.35, 0.0, 0.0), "roll": 0.3, "keep": true, "fade": 0.4}, st.t))
