extends RefCounted
## Creatures going round what stands in their way (plan LIVELY-VILLAGE 1.2; his note 233349: "enemies get stuck in and
## under structures so much, its not good."). Game-agnostic: any CharacterBody3D that turns a wish (the velocity it
## wants) into motion asks here first, in one line before it moves:
##
##   want = SteerAround.steer(self, want, delta, committed)
##
## committed: a lunge, a charge, an attack's step - the wish is kept as it is (a strike is never steered). Otherwise:
##
##   feelers   three rays at knee height along the wish - from its middle and from each shoulder (its collider's
##             half-width), as long as a second of its travel (at least FEEL_MIN; never past a goal it was given, see
##             reachable) - so a wall it would only graze counts too. When something standing blocks them (not the
##             ground: a hit whose normal points up is a slope; not another body that moves), two more 35 degrees to
##             each side pick the freer side, and the wish turns that way (more the nearer the block); the side is kept
##             KEEP_S, so it does not dither at a corner
##   pressed   on a wall and making under PRESSED_SHARE of its wish for PRESSED_S: it follows the wall (along the
##             wall's own line, the side nearer its wish) until the way it wants is clear again, DETOUR_S at most
##   stuck     wanting to move but making under STUCK_M of progress in STUCK_S (a corner the rays did not see): the
##             same, along the kept side
##   blocked   blocked_for(body): seconds it has been held from its wish (blocked ahead, pressed or stuck, falling back
##             as the way clears)
##   give up   goal = SteerAround.reachable(self, pick()): for a caller that picks its goal again and again (a wolf
##             its meal, every 1.5 s): a goal it has come no PROGRESS_M nearer in GIVE_UP_S is dropped, and left
##             alone GIVEN_UP_S (going round a house it still gains on it; pressed at a wall or circling it does not).
##             The goal it keeps also bounds the feelers: a wall behind a meal is not in the way to it
##
## Its memory rides on the body (metadata "steer_around"): no node, no registry. Cost: three rays a frame while moving,
## six more when blocked.
const FEEL_MIN := 1.4        # metres: the shortest feeler
const FEEL_ANGLE := 0.61     # radians (35 degrees): the side feelers
const KNEE := 0.5            # metres above its feet the feelers run (under a roof's eave, over a kerb)
const KEEP_S := 1.0          # seconds a chosen side is kept
const PRESSED_S := 0.3       # seconds on a wall ...
const PRESSED_SHARE := 0.3   # ... making under this share of its wished speed: it follows the wall
const STUCK_M := 0.3         # metres of progress ...
const STUCK_S := 1.0         # ... in this long, or it is stuck
const DETOUR_S := 1.5        # seconds along the wall at most
const GROUND := 0.6          # a hit whose normal's up part is over this is the ground's slope, not a wall
const GIVE_UP_S := 4.5       # seconds with no PROGRESS_M gained on a goal before it is dropped (a 1.5 s pick: in 6 s)
const PROGRESS_M := 1.0
const GIVEN_UP_S := 30.0     # seconds a dropped goal is left alone
const META := "steer_around"
const Prof := preload("res://scripts/studio/people/prof.gd")


static func steer(body: CharacterBody3D, want: Vector3, delta: float, committed := false) -> Vector3:
	var t := Prof.now()
	var out := _steer(body, want, delta, committed)
	Prof.add("animals.steer_around", t)
	return out


static func _steer(body: CharacterBody3D, want: Vector3, delta: float, committed := false) -> Vector3:
	var m := _memory(body)
	m.clock = float(m.clock) + delta
	var flat := Vector3(want.x, 0.0, want.z)
	var speed := flat.length()
	if committed or speed < 0.2:
		m.detour = 0.0
		m.pressed = 0.0
		m.t = 0.0
		m.from = body.global_position
		m.blocked = maxf(float(m.blocked) - delta, 0.0)
		return want
	var dir := flat / speed
	m.keep = maxf(float(m.keep) - delta, 0.0)
	var space := body.get_world_3d().direct_space_state
	var eye := body.global_position + Vector3.UP * KNEE
	var reach := maxf(FEEL_MIN, speed)
	var goal: Variant = m.goal
	if is_instance_valid(goal) and goal is Node3D:          # (not past the goal it is going to)
		var to: Vector3 = (goal as Node3D).global_position - body.global_position
		to.y = 0.0
		if to.length() > 0.01 and to.normalized().dot(dir) > 0.7:
			reach = minf(reach, to.length())
	# pressed on a wall, or no progress: it follows the wall
	var real := Vector2(body.velocity.x, body.velocity.z).length()
	m.pressed = float(m.pressed) + delta if body.is_on_wall() and real < speed * PRESSED_SHARE else 0.0
	m.t = float(m.t) + delta
	var stuck := false
	if float(m.t) >= STUCK_S:
		var from: Vector3 = m.from
		stuck = Vector2(body.global_position.x - from.x, body.global_position.z - from.z).length() < STUCK_M
		m.t = 0.0
		m.from = body.global_position
	if float(m.detour) <= 0.0 and (float(m.pressed) >= PRESSED_S or stuck):
		m.detour = DETOUR_S
		if body.is_on_wall():
			var n := body.get_wall_normal()
			m.side = 1 if Vector3(-n.z, 0.0, n.x).dot(dir) >= 0.0 else -1
		elif int(m.side) == 0:
			m.side = 1 if body.get_instance_id() % 2 == 0 else -1
		m.keep = KEEP_S
	if float(m.detour) > 0.0:
		m.detour = float(m.detour) - delta
		m.blocked = float(m.blocked) + delta
		if not body.is_on_wall() and _ahead(space, eye, dir, reach, body) >= reach:
			m.detour = 0.0                           # (round the corner: the way it wants is clear)
			return want
		var along := dir.rotated(Vector3.UP, PI * 0.5 * int(m.side))
		if body.is_on_wall():                        # along the wall's own line, a little off it (not grinding)
			var n := body.get_wall_normal()
			along = (Vector3(-n.z, 0.0, n.x) * int(m.side) + Vector3(n.x, 0.0, n.z) * 0.15).normalized()
		elif _free(space, eye, along, FEEL_MIN, body) < FEEL_MIN * 0.5:
			m.side = -int(m.side)                    # (a corner: the other way along it)
			along = dir.rotated(Vector3.UP, PI * 0.5 * int(m.side))
		return Vector3(along.x * speed, want.y, along.z * speed)
	var ahead := _ahead(space, eye, dir, reach, body)
	if ahead >= reach:
		m.blocked = maxf(float(m.blocked) - delta * 2.0, 0.0)
		return want
	m.blocked = float(m.blocked) + delta
	if float(m.keep) <= 0.0 or int(m.side) == 0:
		var left := _ahead(space, eye, dir.rotated(Vector3.UP, FEEL_ANGLE), reach, body)
		var right := _ahead(space, eye, dir.rotated(Vector3.UP, -FEEL_ANGLE), reach, body)
		m.side = 1 if left >= right else -1
		m.keep = KEEP_S
	var near := 1.0 - clampf(ahead / reach, 0.0, 1.0)
	var turned := dir.rotated(Vector3.UP, int(m.side) * lerpf(FEEL_ANGLE, PI * 0.5, near))
	return Vector3(turned.x * speed, want.y, turned.z * speed)


## `goal`, or null when the body has come no PROGRESS_M nearer it in GIVE_UP_S (then it is left alone GIVEN_UP_S). The
## goal kept bounds the feelers while the wish points at it.
static func reachable(body: CharacterBody3D, goal: Node) -> Node:
	var m := _memory(body)
	if goal == null or not goal is Node3D:
		m.goal = null
		return null
	var dropped: Dictionary = m.dropped
	var key := goal.get_instance_id()
	if float(dropped.get(key, -1.0)) > float(m.clock):
		m.goal = null
		return null
	var d := Vector2((goal as Node3D).global_position.x - body.global_position.x, (goal as Node3D).global_position.z - body.global_position.z).length()
	if not is_instance_valid(m.goal) or m.goal != goal:
		m.best = d                                   # (a new goal: its distance now, from now)
		m.best_at = float(m.clock)
	elif d <= float(m.best) - PROGRESS_M:
		m.best = d
		m.best_at = float(m.clock)
	elif float(m.clock) - float(m.best_at) >= GIVE_UP_S:
		dropped[key] = float(m.clock) + GIVEN_UP_S
		m.goal = null
		return null
	m.goal = goal
	return goal


## Seconds the body has been held from its wish (0: its way is clear).
static func blocked_for(body: Node) -> float:
	return float((body.get_meta(META) as Dictionary).blocked) if body.has_meta(META) else 0.0


static func _memory(body: CharacterBody3D) -> Dictionary:
	if not body.has_meta(META):
		body.set_meta(META, {"side": 0, "keep": 0.0, "from": body.global_position, "t": 0.0, "detour": 0.0, "blocked": 0.0,
			"pressed": 0.0, "clock": 0.0, "dropped": {}, "goal": null, "best": 0.0, "best_at": 0.0, "half": _half_width(body)})
	return body.get_meta(META)


## Its collider's half-width across its facing (a box's x, a capsule's or a sphere's radius), metres.
static func _half_width(body: CharacterBody3D) -> float:
	for c: Node in body.get_children():
		var cs := c as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		if cs.shape is BoxShape3D:
			return (cs.shape as BoxShape3D).size.x * 0.5 * cs.scale.x
		if cs.shape is CapsuleShape3D:
			return (cs.shape as CapsuleShape3D).radius * cs.scale.x
		if cs.shape is SphereShape3D:
			return (cs.shape as SphereShape3D).radius * cs.scale.x
	return 0.3


## Metres free along `dir` for the whole body: the least of the rays from its middle and its two shoulders.
static func _ahead(space: PhysicsDirectSpaceState3D, eye: Vector3, dir: Vector3, reach: float, body: CharacterBody3D) -> float:
	var side := Vector3(-dir.z, 0.0, dir.x) * float((body.get_meta(META) as Dictionary).half)
	return minf(_free(space, eye, dir, reach, body), minf(_free(space, eye + side, dir, reach, body), _free(space, eye - side, dir, reach, body)))


## Metres free along `dir` up to `reach` (the whole reach when nothing standing is in the way).
static func _free(space: PhysicsDirectSpaceState3D, eye: Vector3, dir: Vector3, reach: float, body: CharacterBody3D) -> float:
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * reach, body.collision_mask, [body.get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y > GROUND or hit.collider is CharacterBody3D:
		return reach
	return eye.distance_to(hit.position)
