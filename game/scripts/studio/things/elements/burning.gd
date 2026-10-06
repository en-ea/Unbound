extends "res://scripts/studio/people/element.gd"
## A thing on fire (graphics S4). The burning fact {heat 1..1000, until_tick}: the people's flames over the whole piece,
## soot creeping over it from the first moment and char eating in after a few seconds, the char's cracks glowing as
## embers. How long it has burned is the fact's age, so a reload shows it as burned as it was. Ends with the fact
## (burned out or soaked); what it leaves is the scorched fact's.
const ID := "burning"
const HOLDS := false
const GIVES := "fire"


func begin(port: Dictionary, strength: float, fact: Dictionary) -> Dictionary:
	var st := {"fact": fact, "k": clampf(strength, 0.3, 1.0), "t": float(port.age_ms) / 1000.0}
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
	var t: float = st.t
	port.pose.call(ID, {
		"surface": {"soot": clampf(0.3 + t / 5.0, 0.3, 1.0), "char": clampf((t - 3.0) / 9.0, 0.0, 0.85),
			"ember": 0.55 + 0.45 * float(st.k)},
		"fx": {"kind": "flames", "size": 0.8 + 0.5 * float(st.k)}})
