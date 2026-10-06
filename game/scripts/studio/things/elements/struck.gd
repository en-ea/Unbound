extends "res://scripts/studio/people/element.gd"
## A thing struck (graphics S4). The struck fact {from [x, z], force 0..1000, n}: a white flash and a shudder for each
## new blow (n), stronger with force. Fresh blows only: a reload replays nothing.
const ID := "struck"
const HOLDS := false
const GIVES := ""


func begin(port: Dictionary, strength: float, fact: Dictionary) -> Dictionary:
	var st := {"fact": fact, "k": clampf(float(fact.get("force", strength * 1000.0)) / 1000.0, 0.2, 1.0)}
	if not port.rehydrating:
		_post(port, st)
	return st


func step(port: Dictionary, st: Dictionary, _dt: float) -> bool:
	if not port.live.call(st.fact):
		return true
	return false


func end(port: Dictionary, _st: Dictionary) -> void:
	port.drop_pose.call(ID)


func _post(port: Dictionary, st: Dictionary) -> void:
	var n := int(st.fact.get("n", 1))
	port.pose.call(ID, {"flash": n, "shake": {"n": n, "force": st.k}})
