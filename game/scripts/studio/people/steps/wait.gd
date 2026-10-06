extends "res://scripts/studio/people/step.gd"
const ID := "wait"
func begin(port: Dictionary, _step: Dictionary) -> Dictionary:
	port.mover.hold(port.mover.pos,port.mover.face_at)
	return {"age":0.0}
func update(_port: Dictionary, step: Dictionary, st: Dictionary, dt: float) -> bool:
	st.age += dt
	return st.age>=float(step.get("seconds",1.0))
