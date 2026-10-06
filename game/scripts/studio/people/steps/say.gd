extends "res://scripts/studio/people/step.gd"
const ID := "say"
func begin(_port: Dictionary, _step: Dictionary) -> Dictionary:
	return {"spoken":false}
func update(port: Dictionary, step: Dictionary, st: Dictionary, _dt: float) -> bool:
	if not st.spoken:
		st.spoken = bool(port.say.call(str(step.text)))
	return st.spoken
