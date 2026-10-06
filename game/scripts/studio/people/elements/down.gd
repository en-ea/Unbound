extends "res://scripts/studio/people/element.gd"
## Knocked down (B6; visual by the animation specialist). The accepted down fact {until_tick, strength = force, from,
## at} as a body: it turns to face where the force came from and falls back from it (Hit_Knockback scrubbed by this
## element's own active clock; the visual rig turns to face it as it goes), lies on its back breathing hard with a
## knee drawn up, and once the fact ends gets up
## (LayToIdle on from sitting up, slowed through the squat by Mind's pain hint). A carried body does not get up until
## it is set down; a dead one never does.
##   begun fresh (the fact under FRESH_MS old): the fall is announced (a real transition), cried and heard
##   rehydrated (a reload, coming into view): already lying, silent - no fall, no cry, no announcement replayed
##   begun late otherwise (its block lifted: let out of the stocks): it falls, silently
##   begun on the ground already (a new revision while lying): lies on, silent
##   blocked (held upright: the stocks): no fall, no posture, no cry; the body sags in its holds for a moment
## Holds the body still while down (constraint "element:down"); clears only its own layer and constraint.
const ID := "down"
const HOLDS := true
const GIVES := "fall"
const G := preload("res://scripts/studio/people/gestures.gd")
const FRESH_MS := 1000
const SAG := 0.7            # seconds a held body sags


func begin(port: Dictionary, strength: float, fact: Dictionary) -> Dictionary:
	var st := {"fact": fact, "k": clampf(strength, 0.0, 1.0), "t": 0.0, "phase": "fall", "rise": 0.0, "blocked": false,
		"toward": Vector3.ZERO}
	if not port.mover.can_posture("down"):
		st.blocked = true
		st.phase = "sag"
		_post(port, st)
		return st
	port.mover.constraints["element:down"] = {"move": false}
	port.mover.vel = Vector2.ZERO
	var src: Vector3 = G.toward(port.body, fact.get("from", []))
	st.toward = src
	port.mover.hold(port.mover.pos, Vector2(port.mover.pos.x + src.x, port.mover.pos.y + src.z) if src != Vector3.ZERO else Vector2.INF)
	var fresh: bool = not port.rehydrating and int(port.age_ms) < FRESH_MS
	var lying: bool = port.body.has_method("posture") and str(port.body.posture()) in G.LYING
	if port.rehydrating or lying:
		st.phase = "lie"
	elif fresh:
		st.t = minf(float(port.age_ms) / 1000.0, G.FALL_TO - G.FALL_FROM)
		port.announce.call("fall", fact, true)
		port.announce.call("cry", fact)
		port.vocal.call("cry", st.k)
		port.emit.call("fall", {"loud": 12.0})
	_post(port, st)
	return st


func step(port: Dictionary, st: Dictionary, dt: float) -> bool:
	st.t += dt
	if st.blocked:
		if st.t >= SAG:
			return true
		_post(port, st)
		return false
	port.mover.vel = Vector2.ZERO
	var shown := str(port.body.posture()) if port.body.has_method("posture") else ""
	if shown == "dead":
		return true                     # (a corpse never gets up: dead's posture is over this one already)
	match st.phase:
		"fall":
			if st.t >= G.FALL_TO - G.FALL_FROM:
				st.phase = "lie"
		"lie":
			if not port.live.call(st.fact):
				if shown != "carried":          # (carried: lies on until set down, then gets up where it was left)
					st.phase = "rise"
		"rise":
			var at: float = G.RISE_FROM + st.rise
			var pain: float = G.unit((port.hints as Dictionary).get("pain", 0.0))
			st.rise += dt * (1.0 - 0.5 * pain if at >= G.SQUAT.x and at <= G.SQUAT.y else 1.0)
			if G.RISE_FROM + st.rise >= G.RISE_TO:
				return true
	_post(port, st)
	return false


func end(port: Dictionary, st: Dictionary) -> void:
	port.drop_pose.call(ID)
	if st.get("blocked", false):
		return
	port.mover.constraints.erase("element:down")
	port.mover.hold(port.mover.pos, Vector2.INF)


func _post(port: Dictionary, st: Dictionary) -> void:
	var f := {}
	match st.phase:
		"sag":
			f = {"knee_l": 0.3, "knee_r": 0.25, "spine": Vector3(0.3, 0.0, 0.05), "head": Vector3(0.35, 0.0, 0.0),
				"weight": sin(clampf(st.t / SAG, 0.0, 1.0) * PI) * st.k, "fade": 0.1}
		"fall":
			f = {"posture": {"name": "down", "clip": G.FALL_CLIP, "at": G.FALL_FROM + st.t, "blend": 0.1, "toward": st.toward}}
		"lie":
			f = G.lying(st.k)
			f["posture"] = {"name": "down", "clip": G.LIE_CLIP, "at": G.LIE_AT, "blend": 0.25}
			f["fade"] = 0.6
		"rise":
			f = {"posture": {"name": "down", "clip": G.LIE_CLIP, "at": minf(G.RISE_FROM + st.rise, G.RISE_TO), "blend": 0.15},
				"fade": 0.4}
	port.pose.call(ID, G.timed(f, st.t))
