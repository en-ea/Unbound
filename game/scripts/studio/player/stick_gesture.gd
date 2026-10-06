extends RefCounted
## B3 slice 3 (B6/E): the left thumb owns the feet. A pure classifier for the one stick finger, fed by marked
## lines in Enea's joystick.gd; the stick still walks, and its rim dwell still sprints.
## - a fresh quick flick, lifted within DODGE_LIFE, dodges the way it went;
## - a still tap on the stick's base crouches, or stands from a crouch;
## - anything held longer is walking. A quick reversal while walking only turns (the sharp-turn case), never dodges.
## Distances are unit px (viewport px / unit), as in gesture.gd, so the same thumb motion reads the same on any phone.
const TAP_TRAVEL := 14.0
const TAP_LIFE := 0.25
const DODGE_LIFE := 0.2 # merge-fix: was 0.3 (a short walk read as a flick and rolled)
const DODGE_REACH := 48.0 # Unit px from where the thumb landed: 0.6 of the stick's 80 px radius.
const FLICK := 800.0 # merge-fix: was 450. Unit px/s over the last WINDOW when the reach is crossed: gesture.gd's flick line.
const WINDOW := 0.1
var finger := -1
var origin := Vector2.ZERO
var far := Vector2.ZERO # The furthest offset reached: the dodge's direction.
var travel := 0.0 # Largest distance from the landing point, unit px.
var age := 0.0
var scale := 1.0
var speed := 0.0 # Speed when DODGE_REACH was first crossed; 0 if never.
var _trail: Array[Vector3] = []
func begin(pointer: int, at: Vector2, viewport: Vector2) -> void:
	finger=pointer
	origin=at
	far=Vector2.ZERO
	travel=0.0
	age=0.0
	speed=0.0
	scale=clampf(minf(viewport.x,viewport.y)/720.0,0.65,2.0)
	_trail=[Vector3.ZERO]
func drag(pointer: int, at: Vector2) -> void:
	if pointer!=finger:
		return
	var offset := at-origin
	_trail.append(Vector3(age,offset.x,offset.y))
	var reach := offset.length()/scale
	if reach>travel:
		travel=reach
		far=offset
	if speed==0.0 and reach>=DODGE_REACH:
		speed=_speed()
func tick(dt: float) -> void:
	if finger>=0:
		age+=maxf(0,dt)
## On lift: {"verb":"dodge","offset":far}, {"verb":"crouch"}, or {} (it was walking, turning or nothing).
func release(pointer: int) -> Dictionary:
	if pointer!=finger:
		return {}
	finger=-1
	if age<=TAP_LIFE and travel<TAP_TRAVEL:
		return {"verb":"crouch"}
	if age<=DODGE_LIFE and speed>=FLICK:
		return {"verb":"dodge","offset":far}
	return {}
func cancel() -> void:
	finger=-1
## gesture.gd's arming speed: segments ending in the last WINDOW; a gap over 1/30 s counts as a rest.
func _speed() -> float:
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
