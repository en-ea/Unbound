extends "res://scripts/studio/people/element.gd"
## A blow landing (B6; visual by the animation specialist). By the contact's force 0..1:
##   under BRUSH   the upper body rocks away from it and whatever they were doing goes on;
##   to FELLS      the feet plant (Hit_Chest, Hit_Head when harder), the upper body is thrown, a white flash, a grunt,
##                 the arms go out for balance as it grows, then Body's stagger walks the backing steps (facing the
##                 blow, away from it; nothing when they cannot move: held, lying);
##   from FELLS    only the throw, flash and grunt: the accepted down fact falls them (people_actions: force >= 750).
## Played by Body at a checked contact (residents.play_contact): never saved, so never rehydrated or replayed.
const ID := "impact"
const HOLDS := false
const GIVES := "blow"
const G := preload("res://scripts/studio/people/gestures.gd")
const BRUSH := 0.3
const FELLS := 0.75
var _n := 0                 # this body's blows so far: each throw, flash and clip plays once


func begin(port: Dictionary, strength: float, fact: Dictionary) -> Dictionary:
	_n += 1
	var body: Node3D = port.body
	var k := clampf(strength, 0.0, 1.0)
	var from: Vector3 = fact.get("from", Vector3.ZERO)
	from.y = 0.0
	from = from.normalized() if from.length_squared() > 0.0001 else body.global_basis.z.normalized()
	var f := {"kick": {"from": from, "force": maxf(k, 0.15), "n": _n}, "fade": 0.25}
	if k < BRUSH:
		f["shoulders"] = 0.1 * k / BRUSH
	else:
		f["flash"] = _n
		if k < FELLS:
			f["action"] = {"clip": G.HIT_HEAD if k >= 0.55 else G.HIT_CHEST, "n": _n}
		if k >= 0.5:
			f["reach_l"] = {"bone": "", "at": Vector3(0.55, 1.2, 0.0), "pole": Vector3(0.5, -0.3, -0.5)}
			f["reach_r"] = {"bone": "", "at": Vector3(-0.55, 1.2, 0.0), "pole": Vector3(-0.5, -0.3, -0.5)}
			f["weight"] = clampf((k - 0.4) * 2.0, 0.3, 1.0)
	port.pose.call(ID, G.timed(f, 0.0))
	port.emit.call("blow", {"loud": 18.0, "strength": k})
	if not port.rehydrating:
		if k >= BRUSH:
			port.vocal.call("grunt", k)
		if k >= BRUSH and k < FELLS:
			port.mover.stagger(Vector2(-from.x, -from.z), lerpf(0.25, 1.0, (k - BRUSH) / (FELLS - BRUSH)), 0.2, 0.5)
	return {"t": 0.0, "left": 0.35 if k < BRUSH else 0.7, "f": f}


func step(port: Dictionary, st: Dictionary, dt: float) -> bool:
	st.t += dt
	if st.t >= st.left:
		return true
	port.pose.call(ID, G.timed(st.f, st.t))
	return false


func end(port: Dictionary, _st: Dictionary) -> void:
	port.drop_pose.call(ID)
