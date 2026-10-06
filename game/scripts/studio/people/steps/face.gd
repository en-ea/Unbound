extends "res://scripts/studio/people/step.gd"
const ID := "face"
func begin(port: Dictionary, step: Dictionary) -> Dictionary:
	var at: Vector2 = port.at.call(step.target)
	port.mover.hold(port.mover.pos,at)
	return {"age":0.0}
func update(_port: Dictionary, _step: Dictionary, st: Dictionary, dt: float) -> bool:
	st.age += dt
	return st.age>=0.45
