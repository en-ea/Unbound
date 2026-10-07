extends "res://scripts/studio/people/element.gd"
## Held in a sphere of water (studio: water class, the Tidecaller's Drown). The accepted suspended fact
## {until_tick, drown?} as a body: lifted off the ground inside the water, legs kicking and arms clawing at it, gasping;
## the struggle weakens as the air runs out. The slam that ends it is its own accepted act (down, hurt); a drowning is
## the death path's dead fact. Holds the body still while held (constraint "element:suspended").
## Presentation only. The sphere is shown while the fact lives, on a reload too; the first gasp is fresh only.
## Poses are placeholders until the animation thread makes its own.
const ID := "suspended"
const HOLDS := true
const GIVES := "struggle"
const G := preload("res://scripts/studio/people/gestures.gd")
const FRESH_MS := 800
const LIFT := 1.6               # metres off the ground
const RISE := 0.5               # seconds to rise


func begin(port: Dictionary, strength: float, fact: Dictionary) -> Dictionary:
	var st := {"fact": fact, "k": clampf(strength, 0.3, 1.0), "t": float(port.age_ms) / 1000.0, "next": 1.2, "sphere": null}
	port.mover.constraints["element:suspended"] = {"move": false}
	port.mover.vel = Vector2.ZERO
	port.mover.hold(port.mover.pos, Vector2.INF)
	if port.body is Node3D:
		st.sphere = WaterFX.sphere(port.body, Vector3(0, LIFT + 0.9, 0), 1.15)
	if not port.rehydrating and int(port.age_ms) < FRESH_MS:
		port.announce.call("cry", fact)
		port.vocal.call("gasp", 1.0)
	_post(port, st)
	return st


func step(port: Dictionary, st: Dictionary, dt: float) -> bool:
	if not port.live.call(st.fact):
		return true
	st.t += dt
	if st.t >= st.next:
		st.next = st.t + 1.4
		port.vocal.call("gasp", st.k * 0.6)
		WaterFX.bubble_burst(st.sphere)
	_post(port, st)
	return false


func end(port: Dictionary, st: Dictionary) -> void:
	port.drop_pose.call(ID)
	port.mover.constraints.erase("element:suspended")
	port.mover.hold(port.mover.pos, Vector2.INF)
	if is_instance_valid(st.get("sphere")):
		WaterFX.burst_sphere(st.sphere)


func _post(port: Dictionary, st: Dictionary) -> void:
	var left := 1.0
	if st.fact.has("until_tick"):
		var span := maxf(1.0, float(int(st.fact.until_tick) - int(st.fact.get("since_tick", st.fact.until_tick - 5000))))
		left = clampf(float(int(st.fact.until_tick) - int(port.tick)) / span, 0.0, 1.0)
	var lift := LIFT * clampf(st.t / RISE, 0.0, 1.0)
	var f := {"writhe": 0.5 + 0.4 * left, "flail": 0.4 + 0.5 * left, "head": Vector3(-0.35, 0.0, 0.0),
		"spine": Vector3(-0.15, 0.0, 0.0), "breath": Vector2(2.2, 0.05 * left), "fade": 0.2,
		"apply": func(_pose: Variant, skeleton: Skeleton3D, weight: float, _s: float) -> void:
			var bone := skeleton.find_bone("root")
			if bone < 0:
				bone = skeleton.find_bone("pelvis")
			if bone < 0:
				return
			var up := lift * weight / maxf(0.001, skeleton.global_basis.get_scale().y)
			skeleton.set_bone_pose_position(bone, skeleton.get_bone_pose_position(bone) + Vector3(0, up, 0))}
	port.pose.call(ID, G.timed(f, st.t))
