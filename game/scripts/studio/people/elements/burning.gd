extends "res://scripts/studio/people/element.gd"
## On fire (B6; visual by the animation specialist). The accepted burning fact {until_tick, heat, ...} as a body, over
## whatever it is doing, never choosing escape or claiming movement: flames up the body, skin blackening as it burns
## and glowing like embers; upright the arms swat at the flames and the head is thrown back, on the ground it thrashes
## and rolls, held at the wrists its free spine, head and legs struggle (gestures.burning). A scream when it catches
## (fresh only: never on a reload), then PLACEHOLDER screams and wails every few active seconds. The fact's removal
## (doused, burned out, dead) stops it at once; doused and dead carry on from there.
const ID := "burning"
const HOLDS := false
const GIVES := "fire"
const G := preload("res://scripts/studio/people/gestures.gd")
const FRESH_MS := 800
var _n := 0


func begin(port: Dictionary, strength: float, fact: Dictionary) -> Dictionary:
	_n += 1
	var age := float(port.age_ms) / 1000.0
	var st := {"fact": fact, "k": clampf(strength, 0.3, 1.0), "t": 0.0, "age": age, "next": 1.6 + float(_n % 3) * 0.5}
	port.emit.call("fire", {"loud": 24.0})
	if not port.rehydrating and int(port.age_ms) < FRESH_MS:
		port.announce.call("cry", fact)
		port.vocal.call("scream", st.k)
	_post(port, st)
	return st


func step(port: Dictionary, st: Dictionary, dt: float) -> bool:
	if not port.live.call(st.fact):
		return true
	st.t += dt
	if st.t >= st.next:
		_n += 1
		st.next = st.t + 2.2 + float(_n % 4) * 0.45
		port.vocal.call("wail" if _n % 2 == 0 else "scream", st.k)
	_post(port, st)
	return false


func end(port: Dictionary, _st: Dictionary) -> void:
	port.drop_pose.call(ID)


func _post(port: Dictionary, st: Dictionary) -> void:
	var body: Node3D = port.body
	var mode := "upright"
	if body.has_method("hands_held") and body.hands_held():
		mode = "held"
	elif body.has_method("posture") and str(body.posture()) in G.LYING:
		mode = "ground"
	var burnt: float = st.age + st.t
	var f: Dictionary = G.burning(mode, st.k)
	f["surface"] = Vector2(clampf(0.15 + burnt / 10.0, 0.15, 0.85), 0.6 + 0.35 * st.k)
	f["fx"] = {"kind": "flames", "size": 0.9 + 0.5 * st.k}
	f["fade"] = 0.2
	port.pose.call(ID, G.timed(f, st.t))
