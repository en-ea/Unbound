extends "res://scripts/studio/people/element.gd"
## A thing soaked (graphics S4). The soaked fact {method: water | rain, until_tick}: darker, cooler and glossy, drying
## over its last DRY seconds. Freshly soaked while it burns or smoulders (a douse), steam rises for a moment; never on
## a reload.
const ID := "soaked"
const HOLDS := false
const GIVES := "relief"
const DRY := 20.0
const STEAM := 1.6


func begin(port: Dictionary, _strength: float, fact: Dictionary) -> Dictionary:
	var hot: bool = port.has.call("burning") or port.has.call("scorched")
	var st := {"fact": fact, "t": float(port.age_ms) / 1000.0, "steam": hot and not port.rehydrating}
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
	var fact: Dictionary = st.fact
	var wet := 1.0
	if fact.has("until_tick"):
		wet = clampf(float(int(fact.until_tick) - int(port.tick)) / (DRY * 1000.0), 0.0, 1.0)
	var f := {"surface": {"wet": wet}}
	if st.steam and float(st.t) < STEAM:
		f["fx"] = {"kind": "steam", "size": 1.2}
	port.pose.call(ID, f)
