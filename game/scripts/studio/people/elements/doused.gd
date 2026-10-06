extends "res://scripts/studio/people/element.gd"
## The fire out (B6; visual by the animation specialist). The accepted doused fact {cause_id, until_tick, method:
## water | beat | smother | burned_out} as a body: a gasp - head thrown back, chest heaving, shoulders up - then doubled
## over with the hands at the face, breath slowing; the embers die in a second and a half, the soot stays (the burn's
## hurt fact keeps it after this ends). Water hisses up as steam, the rest leave smoke; burned out on its own, the body
## sags spent. Announced and gasped fresh only, never on a reload. Ends with the fact.
const ID := "doused"
const HOLDS := false
const GIVES := "relief"
const G := preload("res://scripts/studio/people/gestures.gd")
const FRESH_MS := 800
const GASP := 0.6           # seconds of the first gasp


func begin(port: Dictionary, strength: float, fact: Dictionary) -> Dictionary:
	var st := {"fact": fact, "k": clampf(strength, 0.3, 1.0), "t": float(port.age_ms) / 1000.0,
		"method": str(fact.get("method", "water"))}
	if not port.rehydrating and int(port.age_ms) < FRESH_MS:
		port.announce.call("doused", fact)
		port.vocal.call("gasp", 0.8)
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
	var f := {}
	if st.method == "burned_out":
		f = {"knee_l": 0.2, "knee_r": 0.2, "spine": Vector3(0.4, 0.0, 0.0), "head": Vector3(0.4, 0.0, 0.0),
			"shoulders": -0.05, "breath": Vector2(1.1, 0.05)}
	elif t < GASP:
		f = {"head": Vector3(-0.3, 0.0, 0.0), "spine": Vector3(-0.12, 0.0, 0.0), "shoulders": 0.16, "breath": Vector2(1.6, 0.07)}
	else:
		f = {"head": Vector3(0.35, 0.0, 0.0), "spine": Vector3(0.3, 0.0, 0.0), "shoulders": 0.1,
			"breath": Vector2(lerpf(1.4, 0.8, clampf((t - GASP) / 2.0, 0.0, 1.0)), 0.06),
			"reach_l": {"bone": "spine_03", "at": Vector3(0.12, 0.3, 0.32), "priority": 2},
			"reach_r": {"bone": "spine_03", "at": Vector3(-0.12, 0.3, 0.32), "priority": 2}}      # (over the burn clutch)
	f["surface"] = Vector2(0.7 * st.k, 0.5 * clampf(1.0 - t / 1.5, 0.0, 1.0))
	var steam: bool = st.method == "water"
	if t < (1.6 if steam else 2.5):
		f["fx"] = {"kind": "steam" if steam else "smoke", "size": 0.8 + 0.4 * st.k}
	f["fade"] = 0.3
	port.pose.call(ID, G.timed(f, t))
