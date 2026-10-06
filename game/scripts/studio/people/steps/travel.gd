extends "res://scripts/studio/people/step.gd"
const ID := "travel"
func begin(_port: Dictionary, _step: Dictionary) -> Dictionary:
	return {"aim":0.0}
func update(port: Dictionary, step: Dictionary, st: Dictionary, dt: float) -> bool:
	var at: Vector2 = port.at.call(step.target)
	if at == Vector2.INF:
		return false
	if port.mover.pos.distance_to(at) <= float(step.get("short",1.0)):
		port.mover.hold(port.mover.pos,at)
		return true
	st.aim -= dt
	if st.aim <= 0.0:
		st.aim = 0.7
		port.mover.go(port.route.call(port.mover.pos,at),INF,str(step.get("pace","walk")))
	return false
