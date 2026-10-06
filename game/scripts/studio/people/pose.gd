extends SkeletonModifier3D
## Every procedural motion over whatever the body plays, in ONE controller per body (Pass 3 L6/L7; people B5/B6/B8).
## Made on first use and dropped when it has nothing to show (villager_body.pose()): a skeleton with a modifier re-poses
## every frame, so far and still bodies carry none.
##
##   look     the head turns to a point, the neck and chest with it (LOOK_SHARE), within a neck's reach, eased by a
##            critically damped spring. A frightened body running glances back past the neck's reach (the spine turns).
##            Lying bodies do not look: their head belongs to their element's layer.
##   flinch   a damped spring the upper body is thrown by on a blow, away from where it came from; blows add up
##   nod      a small dip of the head or two;  wave  the right hand up beside the head, waving (a reach layer)
##   expression(hints)   S5 from Mind (people/... sim/people.gd expression): fear, anger, pain, interest, alertness,
##            tension and style {show, steady, lean}. Equal fear reads differently: a timid body (show high, steady
##            low) contracts, hunches, trembles and glances about; a bold one (steady high) goes still, chest up, gaze
##            locked, fists closed. Anger leans in and closes the hands. Alertness readies the body (chest and chin
##            up, shoulders set) and quickens the look; interest leans in to what it watches, the head tilted. Hints
##            never choose a clip, a place or a helper.
##            Legacy hints ({tension, pain} only) keep the old slight hunch.
##   set_layer(key, params, weight := 1.0, fade := 0.2) / clear_layer(key, fade := 0.25) / has_layer(key)
##            an element's named contribution. Elements set and clear ONLY their own keys; each eases in and out, and
##            clearing one leaves every other contribution as it was. params, all optional:
##              spine: Vector3(pitch forward+, roll to its left+, yaw to its left+) radians over spine_01-03
##              head: Vector3(pitch chin-down+, roll, yaw) radians over neck and head (lying: pitch lifts the head)
##              shoulders: float   radians each shoulder rises
##              reach_l / reach_r: {bone: String ("" = the body's root), at: Vector3 metres from it in the body's axes
##                       (+z forward, +x its left), pole?: Vector3 the elbow's way out, priority?: int (higher wins later)}
##              fist / fist_l / fist_r: float 0..1   fingers curled
##              breath: Vector2(Hz, radians)   tremble: float radians   flail: float 0..1 (both arms swat at the body)
##              roll: float radians   the whole body about its own length, at the pelvis (rolling on the ground)
##              writhe: float radians   thrashing: the pelvis rolls, the spine twists, the head tosses, the legs kick
##                       (on the ground, or held in the stocks)
##              knee_l / knee_r: float 0..1   a leg drawn up
##              apply: Callable(pose, skeleton, weight, seconds)   an element's own motion, after the spine
##            Arms held at the wrists (villager_body.hold_hands: a pillory) are never reached: the hold is the last
##            modifier on the skeleton, so restrained bodies struggle with what is free (spine, head, legs).
##   animating() -> bool   springs, fades or continuous layers in motion (a stepped far body advances every frame then)
##   idle() -> bool        nothing at all to show: the owner may drop the modifier
##
## Generic: a skeleton with the UAL rig's bones (spine_01-03, neck_01, Head, clavicle/upperarm/lowerarm/hand, the
## finger chains, pelvis, thigh/calf). Presentation only: nothing here is saved or decides anything.

const SPINE := ["spine_01", "spine_02", "spine_03"]
const SPINE_SHARE := [0.3, 0.35, 0.35]
const LOOK_BONES := ["spine_03", "neck_01", "Head"]
const LOOK_SHARE := [0.18, 0.37, 0.45]        # of the look each bone turns (they add up the chain)
const FLINCH_BONES := ["spine_01", "spine_02", "spine_03", "neck_01", "Head"]
const FLINCH_SHARE := [0.2, 0.2, 0.2, 0.2, 0.2]
const HEAD_BONES := ["neck_01", "Head"]
const HEAD_SHARE := [0.4, 0.6]
const ARMS := {"l": ["upperarm_l", "lowerarm_l", "hand_l"], "r": ["upperarm_r", "lowerarm_r", "hand_r"]}
const CLAVICLES := {"l": "clavicle_l", "r": "clavicle_r"}
const LEGS := {"l": ["thigh_l", "calf_l"], "r": ["thigh_r", "calf_r"]}
const FINGERS := ["index", "middle", "ring", "pinky"]
const FIST_AXIS := Vector3(1, 0, 0)           # a finger's knuckle line in its own frame (UAL: bone along +y, palm -z)
const FIST_CURL := [0.9, 1.25, 0.9]           # radians at full curl, knuckle to tip
const YAW_MAX := 1.3          # radians either side (75 degrees): further round, the body must turn
const GLANCE_MAX := 2.3       # radians a fleeing glance turns, the spine taking what the neck cannot
const PITCH_UP := 0.45        # radians up ...
const PITCH_DOWN := 0.5       # ... and down
const LOOK_HZ := 1.6          # the look spring's natural frequency (a head turn takes about a third of a second)
const FLINCH_HZ := 3.2        # the flinch spring's (a rock back and forth in about a third of a second)
const FLINCH_DAMP := 0.32     # its damping ratio: a visible rock, then still
const FLINCH_KICK := 11.0     # rad/s given by a blow of force 1 (about 25 degrees of throw)
const FLINCH_JOLT := 0.2      # radians a blow of force 1 moves them at once (the throw carries on from there)
const FLINCH_MAX := 0.7       # radians of throw at most
const NOD_DEPTH := 0.2        # radians a nod dips the head
const NOD_RATE := 3.2         # nods a second
const HEAD_HEIGHT := 1.6      # metres above the body's root where the eyes are (a child's body is scaled)
const FEEL_RATE := 1.5        # how fast expression channels follow their hints (a second or so to settle)
const FLAIL_HZ := 2.1         # swats a second per arm while burning
const LYING := ["down", "dead", "carried"]    # villager_body postures with the body on the ground

var body: Node3D              # the character's root (its posture, hands and speed are read from it)
var turn := 0.0               # radians the drawn body is turned from the root's facing (villager_body turns its rig
                              # to face a blow as it falls, while the root keeps Body's facing): the body's own frame
var weight := 0.0             # how much of the look shows (eases in and out)
var _target := Vector3.INF
var _yaw := 0.0               # the look now, in the body's frame
var _pitch := 0.0
var _yaw_v := 0.0
var _pitch_v := 0.0
var _throw := Vector2.ZERO    # the flinch now: x side tilt, y back tilt (radians)
var _throw_v := Vector2.ZERO
var _twist := 0.0             # and a turn of the head away
var _twist_v := 0.0
var _nod_t := 0.0             # seconds of nodding left
var _wave_t := 0.0            # seconds of waving left
var _wave_phase := 0.0
var _time := 0.0
var _layers := {}             # key -> {p: params, w: weight now, to: target weight, rate: per second, end: bool}
var _feel := {}               # expression channel -> eased value
var _feel_want := {}
var _legacy := true           # hints had no fear/anger channels: only the old hunch from tension
var _glance := 0.0            # seconds left of a glance back
var _glance_next := 1.0
var _saccade := Vector2.ZERO  # a timid body's small darting look offset
var _saccade_next := 0.0
var _bones := {}              # name -> index


## Looks at a world point (INF: ahead again).
func look_at_point(point: Vector3) -> void:
	_target = point


func flinch(from: Vector3, force: float) -> void:
	if body == null:
		return
	var local := _basis().orthonormalized().inverse() * from
	var d := Vector2(local.x, local.z)
	if d.length_squared() < 0.0001:
		d = Vector2(0.0, 1.0)
	d = d.normalized()
	# thrown away from it: a blow from the front (+z) tips them back, from their left (+x) to their right
	var k := clampf(force, 0.1, 1.0)
	var side := -signf(d.x if absf(d.x) > 0.2 else 1.0)
	_throw += Vector2(-d.x, d.y) * FLINCH_JOLT * k           # a blow moves them at once (the very next frame shows it) ...
	_twist += side * FLINCH_JOLT * 0.5 * k
	_throw_v += Vector2(-d.x, d.y) * FLINCH_KICK * k         # ... and throws them on, to rock back
	_twist_v += side * FLINCH_KICK * 0.5 * k


func nod(times := 2) -> void:
	_nod_t = maxf(_nod_t, float(times) / NOD_RATE)


func wave(seconds := 1.6) -> void:
	_wave_t = maxf(_wave_t, seconds)


## S5 hints. Values may come as 0..1 or as saved 0..1000 strengths; both are read as 0..1.
func expression(hints: Dictionary) -> void:
	_legacy = not (hints.has("fear") or hints.has("anger"))
	var style: Dictionary = hints.get("style", {})
	for channel: String in ["fear", "anger", "pain", "interest", "alertness", "tension"]:
		_feel_want[channel] = _unit(hints.get(channel, 0.0))
	_feel_want["show"] = _unit(style.get("show", 0.5))
	_feel_want["steady"] = _unit(style.get("steady", 0.5))
	var lean := float(style.get("lean", 0.0))
	_feel_want["lean"] = clampf(lean / 1000.0 if absf(lean) > 1.0 else lean, -1.0, 1.0)


static func _unit(value: Variant) -> float:
	var v := float(value)
	return clampf(v / 1000.0 if v > 1.0 else v, 0.0, 1.0)


func set_layer(key: String, params: Dictionary, to := 1.0, fade := 0.2) -> void:
	var layer: Dictionary = _layers.get(key, {})
	if layer.is_empty():
		layer = {"w": 0.0}
		_layers[key] = layer
	layer.p = params
	layer.to = clampf(to, 0.0, 1.0)
	layer.rate = 1.0 / maxf(fade, 0.01)
	layer.end = false


func clear_layer(key: String, fade := 0.25) -> void:
	if not _layers.has(key):
		return
	var layer: Dictionary = _layers[key]
	layer.to = 0.0
	layer.rate = 1.0 / maxf(fade, 0.01)
	layer.end = true


func has_layer(key: String) -> bool:
	return _layers.has(key) and not bool(_layers[key].end)


func _f(channel: String) -> float:
	return float(_feel.get(channel, 0.0))


func _moving() -> float:
	return float(body.get("moving_speed")) if body != null and body.get("moving_speed") != null else 0.0


## The body's own frame: the root's, turned by `turn`.
func _basis() -> Basis:
	return body.global_basis * Basis(Vector3.UP, turn) if turn != 0.0 else body.global_basis


func _lying() -> bool:
	return body != null and body.has_method("posture") and str(body.posture()) in LYING


func _arms_held() -> bool:
	return body != null and body.has_method("hands_held") and body.hands_held()


## Springs, fades or continuous layers in motion.
func animating() -> bool:
	if _throw.length() > 0.005 or _throw_v.length() > 0.05 or absf(_twist) > 0.005 or _nod_t > 0.0 or _wave_t > 0.0:
		return true
	if absf(_yaw_v) > 0.01 or absf(_pitch_v) > 0.01 or _glance > 0.0:
		return true
	for layer: Dictionary in _layers.values():
		var p: Dictionary = layer.p
		if not is_equal_approx(float(layer.w), float(layer.to)):
			return true
		if p.has("tremble") or p.has("flail") or p.has("writhe") or p.has("breath") or p.has("apply"):
			return true
	for channel: String in _feel_want:
		if absf(float(_feel_want[channel]) - _f(channel)) > 0.01:
			return true
	return _f("fear") > 0.2 or _f("anger") > 0.2 or _f("pain") > 0.2     # breathing and tremble move all the time


## Nothing to show: no look, no rock, no nod, no wave, no layer, no feeling.
func idle() -> bool:
	if not _layers.is_empty() or _target != Vector3.INF or weight >= 0.01 or absf(_yaw) >= 0.01 or absf(_pitch) >= 0.01:
		return false
	if _throw.length() >= 0.005 or _throw_v.length() >= 0.05 or absf(_twist) >= 0.005 or _nod_t > 0.0 or _wave_t > 0.0:
		return false
	for channel: String in _feel:
		if float(_feel[channel]) >= 0.01 and channel not in ["show", "steady", "lean"]:
			return false
	for channel: String in _feel_want:
		if float(_feel_want[channel]) >= 0.01 and channel not in ["show", "steady", "lean"]:
			return false
	return true


## The springs, fades and timers move (every frame, from the body's own _process).
func step(delta: float) -> void:
	_time += delta
	for channel: String in _feel_want:
		_feel[channel] = move_toward(_f(channel), float(_feel_want[channel]), delta * FEEL_RATE)
	for key: String in _layers.keys():
		var layer: Dictionary = _layers[key]
		layer.w = move_toward(float(layer.w), float(layer.to), delta * float(layer.rate))
		if bool(layer.end) and float(layer.w) <= 0.0:
			_layers.erase(key)
	if _wave_t > 0.0:
		_wave_t -= delta
		_wave_phase += delta
		var up := clampf(minf(_wave_phase, _wave_t) * 5.0, 0.0, 1.0)      # up in a fifth of a second, down at the end
		var side := sin(_wave_phase * 2.4 * TAU) * 0.12
		set_layer("pose:wave", {"reach_r": {"bone": "", "at": Vector3(-0.32 + side, 1.75, 0.18), "pole": Vector3(-1.0, -0.2, -0.4),
			"priority": 5}}, up, 0.05)
	elif _layers.has("pose:wave"):
		clear_layer("pose:wave", 0.15)
		_wave_phase = 0.0
	delta = minf(delta, 0.05)
	var contract := _contract()
	var lying := _lying()
	# a fleeing glance back: running, afraid, the feared one behind
	var moving := _moving()
	if _glance > 0.0:
		_glance -= delta
	elif _f("fear") > 0.45 and moving > 2.4 and _target != Vector3.INF and not lying:
		_glance_next -= delta
		if _glance_next <= 0.0:
			_glance = 0.45
			_glance_next = 1.2 + 1.0 * (0.5 + 0.5 * sin(_time * 7.31))
	if contract > 0.3:
		_saccade_next -= delta
		if _saccade_next <= 0.0:
			_saccade = Vector2(sin(_time * 13.7) * 0.28, sin(_time * 9.1 + 1.0) * 0.08) * contract
			_saccade_next = 0.35 + 0.5 * (0.5 + 0.5 * sin(_time * 5.3))
	else:
		_saccade = Vector2.ZERO
	# the look: where it should be, within reach, then the spring towards it
	var want_yaw := 0.0
	var want_pitch := 0.0
	var want_weight := 0.0
	if _target != Vector3.INF and body != null and not lying:
		var eye := body.global_position + _basis().y.normalized() * HEAD_HEIGHT * body.scale.y
		var local := _basis().orthonormalized().inverse() * (_target - eye)
		var flat := Vector2(local.x, local.z).length()
		var yaw := atan2(local.x, local.z)
		var reach := GLANCE_MAX if _glance > 0.0 else YAW_MAX
		if absf(yaw) <= reach + 0.4:                   # (a little past the reach: as far as the neck goes)
			want_yaw = clampf(yaw, -reach, reach) + _saccade.x
			want_pitch = clampf(atan2(local.y, maxf(flat, 0.01)) + _saccade.y, -PITCH_DOWN, PITCH_UP)
			want_weight = 1.0
	weight = move_toward(weight, want_weight, delta * (2.0 + 3.0 * _f("interest")))      # interest holds the eyes on it
	var w := TAU * LOOK_HZ * (1.0 + 0.8 * _f("steady") * maxf(_f("fear"), _f("anger"))) \
		* (0.75 + 0.5 * _f("alertness"))              # a steady body locks on; an alert one turns quicker, a dull one lags
	_yaw_v += (-w * w * (_yaw - want_yaw) - 2.0 * w * _yaw_v) * delta
	_pitch_v += (-w * w * (_pitch - want_pitch) - 2.0 * w * _pitch_v) * delta
	_yaw += _yaw_v * delta
	_pitch += _pitch_v * delta
	# the flinch: a damped spring back to upright
	var f := TAU * FLINCH_HZ
	_throw_v += (-f * f * _throw - 2.0 * FLINCH_DAMP * f * _throw_v) * delta
	_throw += _throw_v * delta
	_throw = _throw.limit_length(FLINCH_MAX)
	_twist_v += (-f * f * _twist - 2.0 * FLINCH_DAMP * f * _twist_v) * delta
	_twist = clampf(_twist + _twist_v * delta, -FLINCH_MAX, FLINCH_MAX)
	_nod_t = maxf(_nod_t - delta, 0.0)


func _contract() -> float:
	return 0.0 if _legacy else contraction(_f("fear"), _f("show"), _f("steady"))


## How much a frightened body draws in (0..1): fear, shown by a timid temperament, held still by a steady one. The same
## fear in a bold body (steady high, show low) stays under a third of it.
static func contraction(fear: float, show: float, steady: float) -> float:
	return fear * (0.35 + 0.65 * show) * (1.0 - 0.6 * steady)


static func _noise(t: float, salt: float) -> float:
	return sin(t * 7.3 + salt) * 0.5 + sin(t * 11.9 + salt * 2.1) * 0.3 + sin(t * 17.3 + salt * 0.7) * 0.2


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or body == null:
		return
	if _bones.is_empty():
		_find_bones(sk)
	var to_sk := sk.global_basis.orthonormalized().inverse() * _basis().orthonormalized()
	var to_sk_xf := sk.global_transform.affine_inverse() * Transform3D(_basis(), body.global_position)
	var up := (to_sk * Vector3.UP).normalized()
	var right := (to_sk * Vector3.RIGHT).normalized()      # (the body's +x: its own left)
	var forward := (to_sk * Vector3.BACK).normalized()     # (Godot's +z: the body's forward)
	var lying := _lying()
	# gather: expression, then every layer by its weight
	var spine := Vector3.ZERO
	var head := Vector3.ZERO
	var shoulders := 0.0
	var tremble := 0.0
	var fist := {"l": 0.0, "r": 0.0}
	var breath_hz := 0.0
	var breath_depth := 0.0
	var roll := 0.0
	var knees := {"l": 0.0, "r": 0.0}
	var flail := 0.0
	var writhe := 0.0
	var reaches := {"l": [], "r": []}
	var customs: Array = []
	if lying:
		pass                    # (a body on the ground: its element's layers hold the spine and head)
	elif _legacy:
		spine.x += _f("tension") * 0.1
	else:
		var contract := _contract()
		var fear := _f("fear")
		var anger := _f("anger")
		var pain := _f("pain")
		var steady := _f("steady")
		var show := _f("show")
		var lean := _f("lean")
		var brace := maxf(fear, anger) * steady
		spine.x += 0.3 * contract - 0.1 * brace + 0.14 * anger * maxf(lean, 0.0) * (0.4 + 0.6 * show) \
			- 0.1 * maxf(-lean, 0.0) * fear + 0.08 * pain
		shoulders += 0.22 * contract + 0.06 * pain
		var alert := _f("alertness")
		var interest := _f("interest") * weight       # (interest shows only while it looks at something)
		spine.x += 0.08 * interest - 0.06 * alert
		head.x -= 0.05 * alert
		head.y += 0.12 * interest * (1.0 if _yaw >= 0.0 else -1.0)
		shoulders += 0.03 * alert
		head.x += 0.2 * contract - 0.08 * brace * (1.0 - anger) + 0.06 * anger
		head.y += 0.12 * pain * sin(_time * 0.9)
		tremble += 0.035 * contract * show
		var closed := maxf(anger * (0.4 + 0.6 * show), brace * 0.6)
		fist.l = closed
		fist.r = closed
		var arousal := maxf(maxf(fear, anger), pain)
		breath_hz = 0.25 + 0.55 * arousal
		breath_depth = 0.012 + 0.02 * arousal
		var moving := _moving()
		if contract > 0.05 and moving < 0.3:          # standing frightened: the hands come in to the chest
			for side: String in ["l", "r"]:
				var s := 1.0 if side == "l" else -1.0
				reaches[side].append({"bone": "spine_03", "at": Vector3(0.07 * s, -0.04, 0.2), "w": 0.6 * contract, "priority": -1})
		elif contract > 0.45 and moving > 2.4:        # running in a panic: the arms thrown up, flapping
			var panic := clampf((contract - 0.45) * 3.0, 0.0, 1.0)
			for side: String in ["l", "r"]:
				var s := 1.0 if side == "l" else -1.0
				var flap := sin(_time * 9.0 + (0.0 if side == "l" else 1.7)) * 0.08
				reaches[side].append({"bone": "spine_03", "at": Vector3(0.24 * s, 0.5 + flap, 0.06), "w": panic,
					"pole": Vector3(s, 0.1, -0.3), "priority": -1})
			head.x -= 0.15 * panic
	for layer: Dictionary in _layers.values():
		var lw := float(layer.w)
		if lw <= 0.0:
			continue
		var p: Dictionary = layer.p
		spine += (p.get("spine", Vector3.ZERO) as Vector3) * lw
		head += (p.get("head", Vector3.ZERO) as Vector3) * lw
		shoulders += float(p.get("shoulders", 0.0)) * lw
		tremble += float(p.get("tremble", 0.0)) * lw
		roll += float(p.get("roll", 0.0)) * lw
		flail = maxf(flail, float(p.get("flail", 0.0)) * lw)
		writhe = maxf(writhe, float(p.get("writhe", 0.0)) * lw)
		for side: String in ["l", "r"]:
			fist[side] = maxf(float(fist[side]), maxf(float(p.get("fist", 0.0)), float(p.get("fist_" + side, 0.0))) * lw)
			knees[side] = maxf(float(knees[side]), float(p.get("knee_" + side, 0.0)) * lw)
			if p.has("reach_" + side):
				var r: Dictionary = (p["reach_" + side] as Dictionary).duplicate()
				r.w = lw
				reaches[side].append(r)
		if p.has("breath"):
			var b: Vector2 = p.breath
			breath_hz = maxf(breath_hz, b.x)
			breath_depth = maxf(breath_depth, b.y * lw)
		if p.has("apply"):
			customs.append([p.apply, lw])
	if writhe > 0.001:
		roll += writhe * sin(_time * 2.6)
		spine.z += writhe * 0.6 * sin(_time * 1.9 + 0.7)
		head.z += writhe * 0.5 * sin(_time * 2.3 + 1.3)
		head.x += writhe * 0.25 * sin(_time * 3.1)
		knees.l = maxf(float(knees.l), writhe * (0.5 + 0.5 * sin(_time * 3.4)))
		knees.r = maxf(float(knees.r), writhe * (0.5 + 0.5 * sin(_time * 3.4 + 2.2)))
	# the whole body about its length (on the ground), then the legs
	var pelvis: int = _bones.get("pelvis", -1)
	if absf(roll) > 0.001 and pelvis >= 0:
		_turn(sk, pelvis, Basis(forward, roll))
	for side: String in ["l", "r"]:
		var k := float(knees[side])
		if k > 0.001:
			var ids: Array = _bones["legs_" + side]
			if ids[0] >= 0 and ids[1] >= 0:
				_turn(sk, ids[0], Basis(right, -1.1 * k))
				_turn(sk, ids[1], Basis(right, 1.6 * k))
	# the spine: the flinch's throw, expression and layers, breathing and trembling
	var breathe := sin(_time * TAU * breath_hz) * breath_depth if breath_hz > 0.0 else 0.0
	var shake := Vector3(_noise(_time * 1.3, 0.0), _noise(_time * 1.3, 3.0), _noise(_time * 1.3, 5.0)) * tremble
	var flail_twist := 0.18 * flail * sin(_time * FLAIL_HZ * TAU * 0.5)
	var glance_spine := 0.0
	if absf(_yaw) > YAW_MAX:
		glance_spine = (_yaw - clampf(_yaw, -YAW_MAX, YAW_MAX)) * weight
	for i in FLINCH_BONES.size():
		var bone: int = _bones.get(FLINCH_BONES[i], -1)
		if bone < 0:
			continue
		var share: float = FLINCH_SHARE[i]
		var r := Basis(right, -_throw.y * share) * Basis(forward, _throw.x * share)
		if i < SPINE.size():
			var s: float = SPINE_SHARE[i]
			r = Basis(up, (spine.z + shake.z + flail_twist + glance_spine * 0.5) * s) * Basis(forward, (spine.y + shake.y) * s) \
				* Basis(right, (spine.x + shake.x - breathe * 0.6) * s) * r
		if FLINCH_BONES[i] == "Head":
			r = Basis(up, _twist) * r
		_turn(sk, bone, r)
	for c: Array in customs:
		(c[0] as Callable).call(self, sk, float(c[1]), _time)
	# shoulders rise (each about the body's forward axis, outward side up), with the breath
	for side: String in ["l", "r"]:
		var clav: int = _bones.get("clav_" + side, -1)
		var lift := shoulders + breathe * 0.4
		if clav >= 0 and absf(lift) > 0.0005:
			_turn(sk, clav, Basis(forward, lift if side == "l" else -lift))
	# the head: its layer, the look, a nod, a tremble
	var nod := sin(_nod_t * NOD_RATE * TAU) * NOD_DEPTH * minf(_nod_t * 4.0, 1.0) if _nod_t > 0.0 else 0.0
	var flail_head := Vector3(-0.2 * flail, 0.0, 0.25 * flail * sin(_time * FLAIL_HZ * TAU * 0.7))
	var h := head + flail_head + shake * 0.8
	var looking := not lying and (weight > 0.001 or absf(_yaw) > 0.001 or absf(_pitch) > 0.001)
	for i in LOOK_BONES.size():
		var bone: int = _bones.get(LOOK_BONES[i], -1)
		if bone < 0:
			continue
		var r := Basis.IDENTITY
		if looking:
			var share: float = LOOK_SHARE[i]
			var yaw := clampf(_yaw, -YAW_MAX, YAW_MAX)
			r = Basis(up, yaw * share * weight) * Basis(right, -_pitch * share * weight)
		var hi := HEAD_BONES.find(LOOK_BONES[i])
		if hi >= 0:
			var hs: float = HEAD_SHARE[hi]
			r = r * Basis(up, h.z * hs) * Basis(forward, h.y * hs) * Basis(right, h.x * hs)
		if LOOK_BONES[i] == "Head" and nod != 0.0:
			r = r * Basis(right, absf(nod))
		if r != Basis.IDENTITY:
			_turn(sk, bone, r)
	# the arms: flailing, then reaches by priority (never against a hold at the wrists)
	if not _arms_held():
		for side: String in ["l", "r"]:
			var s := 1.0 if side == "l" else -1.0
			if flail > 0.01:
				var t := _time * FLAIL_HZ * TAU + (0.0 if side == "l" else 2.5)
				reaches[side].append({"bone": "spine_03", "w": flail, "priority": 1,
					"at": Vector3(s * (0.16 + 0.16 * sin(t * 1.3)), 0.12 + 0.26 * sin(t), 0.2 + 0.14 * cos(t * 0.7))})
			var list: Array = reaches[side]
			if list.is_empty():
				continue
			list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("priority", 0)) < int(b.get("priority", 0)))
			var ids: Array = _bones["arm_" + side]
			if -1 in ids:
				continue
			for r: Dictionary in list:
				var target := _target_of(sk, to_sk_xf, r)
				var pole: Vector3 = to_sk * (r.get("pole", Vector3(s * 0.9, -0.7, -0.4)) as Vector3).normalized()
				_reach(sk, ids, target, pole, clampf(float(r.w), 0.0, 1.0))
	# the hands close
	for side: String in ["l", "r"]:
		var c := float(fist[side])
		if c > 0.01:
			for chain: Array in _bones["fingers_" + side]:
				for k in chain.size():
					if chain[k] >= 0:
						var pose := sk.get_bone_global_pose(chain[k])
						var axis := (pose.basis * FIST_AXIS).normalized()
						pose.basis = Basis(axis, -FIST_CURL[k] * c) * pose.basis
						sk.set_bone_global_pose(chain[k], pose)


func _find_bones(sk: Skeleton3D) -> void:
	for b: String in FLINCH_BONES + LOOK_BONES + ["pelvis"]:
		_bones[b] = sk.find_bone(b)
	if int(_bones.get("neck_01", -1)) < 0:
		_bones["neck_01"] = sk.find_bone("neck")
	for side: String in ["l", "r"]:
		_bones["arm_" + side] = (ARMS[side] as Array).map(func(b: String) -> int: return sk.find_bone(b))
		_bones["clav_" + side] = sk.find_bone(CLAVICLES[side])
		_bones["legs_" + side] = (LEGS[side] as Array).map(func(b: String) -> int: return sk.find_bone(b))
		var chains: Array = []
		for finger: String in FINGERS:
			chains.append([1, 2, 3].map(func(k: int) -> int: return sk.find_bone("%s_%02d_%s" % [finger, k, side])))
		_bones["fingers_" + side] = chains


## A reach's target in the skeleton's space: metres from a bone (or the body's root) along the body's own axes.
func _target_of(sk: Skeleton3D, to_sk_xf: Transform3D, r: Dictionary) -> Vector3:
	var at: Vector3 = r.get("at", Vector3.ZERO)
	var bone_name := str(r.get("bone", ""))
	if bone_name == "":
		return to_sk_xf * at
	if not _bones.has(bone_name):
		_bones[bone_name] = sk.find_bone(bone_name)
	var bone: int = _bones[bone_name]
	if bone < 0:
		return to_sk_xf * at
	return sk.get_bone_global_pose(bone).origin + to_sk_xf.basis * at


## Two-bone reach: the upper arm and forearm bend so the wrist comes to `target`, blended by `w` (the elbow toward
## `pole`). The hand keeps the forearm's turn.
static func _reach(sk: Skeleton3D, ids: Array, target: Vector3, pole: Vector3, w: float) -> void:
	if w <= 0.001:
		return
	var up_t: Transform3D = sk.get_bone_global_pose(ids[0])
	var lo_t: Transform3D = sk.get_bone_global_pose(ids[1])
	var wr_t: Transform3D = sk.get_bone_global_pose(ids[2])
	var s := up_t.origin
	target = wr_t.origin.lerp(target, w)
	var a := (lo_t.origin - s).length()
	var b := (wr_t.origin - lo_t.origin).length()
	var d := target - s
	if a < 0.001 or b < 0.001 or d.length() < 0.001:
		return
	var dist := clampf(d.length(), 0.01, a + b - 0.001)
	var dir := d.normalized()
	var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var side := pole - dir * pole.dot(dir)
	if side.length_squared() < 0.000001:
		return
	side = side.normalized()
	var elbow := s + (dir * cos_a + side * sqrt(1.0 - cos_a * cos_a)) * a
	var turn1 := Quaternion((lo_t.origin - s).normalized(), (elbow - s).normalized())
	sk.set_bone_global_pose(ids[0], Transform3D(Basis(turn1) * up_t.basis, s))
	lo_t = sk.get_bone_global_pose(ids[1])
	wr_t = sk.get_bone_global_pose(ids[2])
	var turn2 := Quaternion((wr_t.origin - lo_t.origin).normalized(), (target - lo_t.origin).normalized())
	sk.set_bone_global_pose(ids[1], Transform3D(Basis(turn2) * lo_t.basis, lo_t.origin))


## Turns a bone about its own origin by `r` (skeleton space); its children go with it.
static func _turn(sk: Skeleton3D, bone: int, r: Basis) -> void:
	var pose := sk.get_bone_global_pose(bone)
	pose.basis = r * pose.basis
	sk.set_bone_global_pose(bone, pose)
