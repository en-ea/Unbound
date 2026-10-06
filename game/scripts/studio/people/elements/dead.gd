extends "res://scripts/studio/people/element.gd"
## Dead (B6; visual by the animation specialist). The accepted dead fact as a body that is unmistakably gone: standing,
## the knees buckle and it collapses (Death01 scrubbed by this element's own active clock); already on the ground, it
## goes limp into the same last pose over most of a second. Then nothing moves: `still` masks every other element's
## motion (no breath, no tremble, no clutch, no flail; pose.gd turns the look off on the ground), whatever soot or smoke
## the burn left stays. Every death ends in the one pose, so a reload shows the same corpse at once. A last PLACEHOLDER
## groan, fresh only. Ends only if the fact goes.
const ID := "dead"
const HOLDS := true
const GIVES := "corpse"
const G := preload("res://scripts/studio/people/gestures.gd")
const FRESH_MS := 2400


func begin(port: Dictionary, _strength: float, fact: Dictionary) -> Dictionary:
	var body: Node3D = port.body
	var lying: bool = body.has_method("posture") and str(body.posture()) in G.LYING
	var fresh: bool = not port.rehydrating and int(port.age_ms) < FRESH_MS
	var st := {"fact": fact, "t": 0.0, "from": float(port.age_ms) / 1000.0 if fresh and not lying else G.DIE_TO,
		"blend": 0.8 if fresh and lying else 0.15}
	if fresh:
		port.vocal.call("groan", 0.35)
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
	var at: float = minf(st.from + st.t, G.DIE_TO)
	var f := {"posture": {"name": "dead", "clip": G.DIE_CLIP, "at": at, "blend": st.blend}}
	if at >= G.DIE_DOWN:
		f["still"] = true       # (while it collapses, the last of what it was doing may still show)
	port.pose.call(ID, G.timed(f, st.t))
