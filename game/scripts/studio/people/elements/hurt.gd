extends "res://scripts/studio/people/element.gd"
## Hurt (B6/B8; visual by the animation specialist). The accepted hurt fact {strength = hurt x 10, where} as a lasting
## condition over everything else: a hand to the hurt place (gestures.clutch), a heavier breath, and from a hurt leg or
## strength 0.6 a limp (the derived Walk_Limp) held to a limping pace (constraint "element:hurt"). Burns blacken the skin
## for good and a badly burned body smokes for SMOKE seconds after its last burn (a burned corpse too: its stillness
## masks the clutch, not the soot). Each new revision eases from the last; a reload shows it at once. No cry: the blow,
## fall and fire that hurt them cry for themselves.
const ID := "hurt"
const HOLDS := false
const GIVES := "injury"
const G := preload("res://scripts/studio/people/gestures.gd")
const SMOKE := 12.0
const LIMP_FROM := 0.6


func begin(port: Dictionary, strength: float, fact: Dictionary) -> Dictionary:
	var k := clampf(strength, 0.0, 1.0)
	var where := str(fact.get("where", "chest"))
	var st := {"fact": fact, "k": k, "where": where, "t": float(port.age_ms) / 1000.0,
		"limp": where == "leg" or k >= LIMP_FROM, "fade": 0.0 if port.rehydrating else 0.5}
	if st.limp:
		port.mover.constraints["element:hurt"] = {"pace": lerpf(1.25, 0.75, k)}
	_post(port, st)
	return st


func step(port: Dictionary, st: Dictionary, dt: float) -> bool:
	if not port.live.call(st.fact):
		return true
	st.t += dt
	st.fade = 0.5               # (shown at once on a reload, it still eases out when it heals)
	_post(port, st)
	return false


func end(port: Dictionary, _st: Dictionary) -> void:
	port.drop_pose.call(ID)
	port.mover.constraints.erase("element:hurt")


func _post(port: Dictionary, st: Dictionary) -> void:
	var k: float = st.k
	var f: Dictionary = G.clutch(st.where, k)
	f["weight"] = clampf((k - 0.1) / 0.5, 0.0, 1.0)
	f["fade"] = st.fade
	if st.limp:
		f["gait"] = "limp"
	if st.where == "burn":
		f["surface"] = Vector2(0.35 + 0.6 * k, 0.0)
		if k >= 0.5 and st.t < SMOKE:
			f["fx"] = {"kind": "smoke", "size": 0.6 + 0.4 * k}
	port.pose.call(ID, G.timed(f, st.t))
