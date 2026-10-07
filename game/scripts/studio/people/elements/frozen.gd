extends "res://scripts/studio/people/element.gd"
## Stopped in ice (studio: water class, the Tidecaller's Rime Wave on someone wet). The accepted frozen fact
## {until_tick} as a body: a shell of ice round it, the body rigid, a shiver, no step and no act while it lasts
## (constraint "element:frozen"). The shatter is the blow that lands on it, its own accepted act.
## Presentation only; the shell is shown while the fact lives, on a reload too. The pose is a placeholder until the
## animation thread makes its own.
const ID := "frozen"
const HOLDS := true
const GIVES := "stillness"
const G := preload("res://scripts/studio/people/gestures.gd")


func begin(port: Dictionary, strength: float, fact: Dictionary) -> Dictionary:
	var st := {"fact": fact, "k": clampf(strength, 0.3, 1.0), "t": float(port.age_ms) / 1000.0, "shell": null}
	port.mover.constraints["element:frozen"] = {"move": false}
	port.mover.vel = Vector2.ZERO
	port.mover.hold(port.mover.pos, Vector2.INF)
	if port.body is Node3D:
		st.shell = WaterFX.ice(port.body)
	_post(port, st)
	return st


func step(port: Dictionary, st: Dictionary, dt: float) -> bool:
	if not port.live.call(st.fact):
		return true
	st.t += dt
	_post(port, st)
	return false


func end(port: Dictionary, st: Dictionary) -> void:
	port.drop_pose.call(ID)
	port.mover.constraints.erase("element:frozen")
	port.mover.hold(port.mover.pos, Vector2.INF)
	if is_instance_valid(st.get("shell")):
		WaterFX.shatter((st.shell as Node3D).get_tree().current_scene, (st.shell as Node3D).global_position)
		st.shell.queue_free()


func _post(port: Dictionary, st: Dictionary) -> void:
	var f := {"spine": Vector3(-0.05, 0.0, 0.0), "shoulders": 0.18, "fist": 0.7, "tremble": 0.015, "breath": Vector2(0.4, 0.01),
		"fade": 0.1}
	port.pose.call(ID, G.timed(f, st.t))
