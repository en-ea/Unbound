extends RefCounted
## E/B6 pure gesture lifecycle. Origin role and pointer never change. Target is captured by the adapter
## at preparation, not searched at landing. Return inside the inner radius cancels before commitment.
## Role "act" (B3 slice 1): one thumb area, the motion picks the act. Still tap = use, still hold = guard,
## a fast flick = strike, a slow push = shove. Decided once, when the stroke arms.
## Slice 2: a flick's speed is its force (300 lazy .. 1000 sharp); from HEAVY_FORCE it is the heavy blow.
const TRAVEL := 28.0
const RETURN := 14.0
const HOLD := 0.28
const HEAVY := 0.48
const FLICK := 450.0 # Unit-scaled px/s over the last WINDOW before arming: above is a flick, below a push.
const WINDOW := 0.1
const SHARP := 2400.0 # Unit px/s at which a flick reaches full force.
const FORCE_MIN := 300
const FORCE_MAX := 1000
const HEAVY_FORCE := 750 # people_actions: force >= 750 knocks down.
var finger := -1
var role := ""
var origin := Vector2.ZERO
var offset := Vector2.ZERO
var age := 0.0
var prepared_age := 0.0
var intent := ""
var armed := false
var cancelled := false
var scale := 1.0
var target := {}
var speed := 0.0 # Arming speed, unit-scaled px/s (act role).
var _trail: Array[Vector3] = [] # (age, offset.x, offset.y) samples for the arming speed.
func begin(pointer: int, mode: String, at: Vector2, viewport: Vector2, captured: Dictionary) -> void:
	finger=pointer
	role=mode
	origin=at
	offset=Vector2.ZERO
	age=0
	prepared_age=0
	armed=false
	cancelled=false
	scale=clampf(minf(viewport.x,viewport.y)/720.0,0.65,2.0)
	target=captured.duplicate()
	speed=0.0
	_trail=[Vector3.ZERO]
	intent="use" if mode in ["hand","act"] else "dodge" if mode=="feet" else mode
func drag(pointer: int, at: Vector2, relative: Vector2) -> bool:
	if pointer!=finger or relative.length()>200.0*scale:
		return false
	offset=at-origin
	_trail.append(Vector3(age,offset.x,offset.y))
	if cancelled:
		return true
	if armed and offset.length()<RETURN*scale:
		cancelled=true
	elif offset.length()>=TRAVEL*scale and intent not in ["guard","crouch"]:
		if not armed:
			prepared_age=age
			if role=="act":
				speed=arming_speed()
				intent="shove" if speed<FLICK else "heavy" if flick_force()>=HEAVY_FORCE else "strike"
		armed=true
		if role=="hand" and intent!="heavy":
			intent="strike"
	return true
## The blow's force from the arming speed (act role); 0 for a push.
func flick_force() -> int:
	if speed<FLICK:
		return 0
	return roundi(lerpf(FORCE_MIN,FORCE_MAX,clampf((speed-FLICK)/(SHARP-FLICK),0,1)))
## Speed of the motion that armed the stroke, per second and per unit: segments ending in the last WINDOW.
## A moving finger reports every frame, so a gap longer than 1/30 s is a rest, not slow motion.
func arming_speed() -> float:
	var last: Vector3=_trail[-1]
	var travelled := 0.0
	var spent := 0.0
	for i in range(_trail.size()-1,0,-1):
		var b: Vector3=_trail[i]
		var a: Vector3=_trail[i-1]
		if last.x-b.x>WINDOW:
			break
		travelled+=Vector2(b.y-a.y,b.z-a.z).length()/scale
		spent+=clampf(b.x-a.x,1.0/120.0,1.0/30.0)
	return travelled/maxf(spent,1.0/120.0)
func tick(dt: float) -> void:
	age+=maxf(0,dt)
	if cancelled:
		return
	if role in ["hand","act"] and not armed and age>=HOLD:
		intent="guard"
	elif role=="hand" and armed and age-prepared_age>=HEAVY:
		intent="heavy"
	elif role=="feet" and not armed and age>=HOLD:
		intent="crouch"
func release(pointer: int) -> String:
	if pointer!=finger:
		return ""
	finger=-1
	if cancelled:
		return "cancel"
	if role=="feet" and not armed:
		return "crouch" if intent=="crouch" else "cancel"
	if role in ["hand","act"] and intent=="use" and offset.length()>RETURN*scale:
		return "cancel"
	if role not in ["hand","feet","act"] and not armed:
		return "cancel"
	return intent
func cancel() -> void:
	cancelled=true
	finger=-1
