extends "res://scripts/studio/people/element.gd"
## The animation specialist's one-file proof (B6/B8): a visual element is one file, and it composes. A wince is a sharp
## pain beat - the body curls round its middle, the head drops, the hands close, a gasp - over whatever else is playing
## (a held posture, a gait, other elements' layers). It posts only its own named layer through Body's port and drops it
## at the end, leaving the body as it found it. Lives in proofs/: the proof runner discovers it, the game's never does
## (people/animation_checks.gd).
const ID := "wince"
const HOLDS := false
const GIVES := "wince"


func begin(port: Dictionary, strength: float, _fact: Dictionary) -> Dictionary:
	var st := {"t": 0.0, "left": 0.25 + 0.5 * strength, "f": {"spine": Vector3(0.35, 0.0, 0.08) * strength,
		"head": Vector3(0.25, 0.0, 0.0) * strength, "shoulders": 0.12 * strength, "fist": strength,
		"breath": Vector2(1.6, 0.03), "fade": 0.08}}
	port.pose.call(ID, _timed(st))
	port.vocal.call("gasp", strength)
	port.emit.call("wince", {"strength": strength})
	return st


func step(port: Dictionary, st: Dictionary, dt: float) -> bool:
	st.t += dt
	if st.t >= st.left:
		return true
	port.pose.call(ID, _timed(st))
	return false


func end(port: Dictionary, _st: Dictionary) -> void:
	port.drop_pose.call(ID)


static func _timed(st: Dictionary) -> Dictionary:
	var f: Dictionary = (st.f as Dictionary).duplicate()
	f["clock"] = st.t
	return f
