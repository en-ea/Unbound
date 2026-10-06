extends RefCounted
## Anticipatory steering for people on foot (Pass 3, PA-1: PEOPLE-ARCHITECTURE.md B1 and B2). Pure: positions and
## velocities in, positions and velocities out. Presentation only: nothing here is saved, and the rules never read it.
##
## Avoidance is by time to collision, after Guy and Karamouzas (Game AI Pro 2, chapter 19). Their model follows the
## power law measured on real pedestrians (Karamouzas, Skinner and Guy, Physical Review Letters 113, 2014): people
## react to how soon they would meet someone, not to how near they are, so they swerve early and gently.
##
##   each walker:   F = (want - v) / relax                          towards the speed and way it wants to go (relax:
##                                                                   RELAX, shorter while they start or stop on purpose)
##                    + for each neighbour it can see, on course to meet within its horizon h, t seconds from now:
##                      F += away from where the two would meet * (h - t) / t          (at most PUSH_CAP)
##                    + inside the room it likes to keep (`space`): a gentle push apart, gentler from someone it is
##                      not closing on (walking along together, or passing someone who stands): a stream keeps less room
##                  v += F dt (no faster than its own acceleration and top speed); x += v dt
##   someone standing: does not drift with the pushes; they are kept as pressure (`avoid`) for the mover to answer with
##                  a deliberate step, and walkers go round them
##   together:      people in one conversation, or walking as companions (`group`), keep no room from each other,
##                  only clear of touching
##   walls:         near a wall (`walls`, within WALL_NEAR), a walker's wish is turned along it at its own speed
##                  (more turned the closer they are: people turn along a wall, they do not brake at it) and the push
##                  into it is dropped, and a gentle push keeps them off it: they brush past a corner, never into it
##                  (the hard pass that puts anyone found inside a wall back out is then a last resort)
##   then:          discs that still overlap are pushed apart (a walker gives way to someone standing, two standing
##                  share it; the player and Enea's animals never give), and nobody is left inside a house
##   a SPACE:       the room in the middle of a conversation (its o-space, after Kendon's F-formations): a disc nobody
##                  but its own people walks into (they go round a group talking, never through it); it never moves,
##                  never pushes anyone standing, and its own people (`group`) do not feel it
##
## Each person is a disc: `body` is hard (never overlapped), `space` is soft (how much room they like). Their horizon
## is their character: a short one cuts close at the last moment, a long one gives way early.

const RELAX := 0.5            # seconds to settle onto the wanted velocity (the chapter's goal force, k = 2)
const TURN_GRIP := 2.0        # across their way people change velocity this much more firmly than along it (they
                              # turn sharper than they speed up or slow down; a turn is not a change of speed)
const PUSH_CAP := 12.0        # m/s2: the most one neighbour pushes (an imminent meeting would be infinite)
const SPACE_PUSH := 2.0       # m/s2 at the edge of a body, from someone inside the room they like to keep ...
const ALONGSIDE := 0.35       # ... this share of it from someone they are not closing on
const CLOSING := 0.6          # m/s of closing speed at which the room counts in full
const KEEP_RIGHT := 0.35      # head-on, each steps a little to their own right, so two never stall nose to nose
const SEE_BEHIND := -0.17     # cos 100 degrees: a neighbour further round than this is not seen ...
const FEEL := 0.6             # ... unless this close (metres between bodies): felt, not seen
const STAND_HORIZON := 0.8    # seconds: someone holding a spot only gives way to a meeting this close
const STAND_GIVE := 0.6       # ... and less readily than a walker
const STAND_YIELD := 0.05     # share of an overlap with a walker that someone standing takes (the walker goes round)
const SHOVED_MOST := 1.4      # m/s: someone pressed by a body that will not give (the player, a creature) is moved no
                              # faster than a quick step aside; the rest is the presser's to take (the player's collider)
const WALL_NEAR := 0.2        # metres from a wall: a walker's way and push into it are turned along it (the ways keep
                              # a body's width off walls: only someone brushing one is touched)
const WALL_PUSH := 2.0        # m/s2 off a wall at its face (none at WALL_NEAR)
const CELL := 5.0             # metres: the neighbour grid (nobody further than this is considered)
const Nearby := preload("res://scripts/studio/people/nearby.gd")
const SLOP := 0.002           # metres of overlap left alone (pushing out exactly invites jitter)

## What an agent is.
const WALKER := 0             # steers to the velocity it wants, and avoids
const STANDING := 1           # holds a spot (`want` draws it back); gives way only to an imminent meeting
const OTHER := 2              # the player, an animal, one of Enea's characters: moved by someone else, only avoided
const SPACE := 3              # the middle of a conversation: walked round by everyone but its own people

const _EMPTY: Array = []


class Agents:
	var pos := PackedVector2Array()
	var vel := PackedVector2Array()
	var want := PackedVector2Array()       # the velocity each would like (the mover sets it every frame)
	var body := PackedFloat32Array()       # hard radius, metres
	var space := PackedFloat32Array()      # soft room they like to keep, metres past the two bodies
	var horizon := PackedFloat32Array()    # seconds ahead they look
	var accel := PackedFloat32Array()      # m/s2: how fast they can change velocity
	var top := PackedFloat32Array()        # m/s: never faster
	var relax := PackedFloat32Array()      # seconds to settle onto the wanted velocity
	var kind := PackedByteArray()
	var group := PackedInt32Array()        # people together (a conversation, companions): 0 none; the same non-zero
	                                       # number: they keep no room from each other, only clear of touching
	var avoid := PackedVector2Array()      # the push from neighbours, last worked out (kept between steps)
	var threat := PackedVector2Array()     # standing: the velocity of whoever presses on them most (ZERO: nobody)
	var regard: Array[Dictionary] = []    # current visible neighbour row -> preferred centre distance (S5)
	var door := PackedByteArray()          # 1: walking in at a door close by (the wall there is where they are going)
	var size := 0
	var steps := 0

	func add(at: Vector2, radius: float, room: float, look_ahead: float, acceleration: float, max_speed: float, what: int,
			settle := RELAX) -> int:
		pos.append(at)
		vel.append(Vector2.ZERO)
		threat.append(Vector2.ZERO)
		regard.append({})
		door.append(0)
		want.append(Vector2.ZERO)
		avoid.append(Vector2.ZERO)
		body.append(radius)
		space.append(room)
		horizon.append(look_ahead)
		accel.append(acceleration)
		top.append(max_speed)
		relax.append(settle)
		kind.append(what)
		group.append(0)
		size += 1
		return size - 1


## Seconds until two discs touch if both keep their velocities: 0 if they already do, INF if they never will.
## w: the other's position minus mine; v: my velocity minus theirs; r: the two radii together.
static func ttc(w: Vector2, v: Vector2, r: float) -> float:
	var c := w.dot(w) - r * r
	if c < 0.0:
		return 0.0
	var a := v.dot(v)
	if a < 0.000001:
		return INF
	var b := w.dot(v)
	var discr := b * b - a * c
	if discr <= 0.0:
		return INF
	var t := (b - sqrt(discr)) / a
	return t if t >= 0.0 else INF


## The neighbour grid: cell key -> the agents in it. Rebuilt every step (a crowd near the player is a few dozen).
static func grid_of(ag: Agents) -> Dictionary:
	return Nearby.grid(ag.pos, ag.size)


## One step for everyone: forces, motion, then the hard pass. `blocks`: houses and the like, already grown by a
## body's radius (stage.gd's routing blocks). `every`: the push from neighbours is worked out for one agent in
## `every` per step, in turn (people re-judge a few times a second; the goal force and the motion are every step).
## Returns how many overlaps the hard pass had to undo (a measure: a well-tuned crowd needs few).
static func step(ag: Agents, dt: float, blocks: Array[Rect2] = [], every := 1, walls: Array[Rect2] = [], shared := {}) -> int:
	var n := ag.size
	if n == 0 or dt <= 0.0:
		return 0
	var grid: Dictionary = shared if not shared.is_empty() else grid_of(ag)
	ag.steps += 1
	for i in n:
		var what := ag.kind[i]
		if what < OTHER and (i + ag.steps) % every == 0:
			ag.avoid[i] = _avoid(ag, i, what, grid)
	for i in n:
		if ag.kind[i] >= OTHER:
			continue
		var v := ag.vel[i]
		var push := ag.avoid[i] if ag.kind[i] == WALKER else Vector2.ZERO     # standing: pressure, not drift
		var wish := ag.want[i]
		if not walls.is_empty() and ag.kind[i] == WALKER:
			var wall := _wall(ag.pos[i], walls)
			if wall.z < WALL_NEAR:
				var nw := Vector2(wall.x, wall.y)
				push -= nw * minf(push.dot(nw), 0.0)     # the crowd never shoves anyone into a wall (one going in at a
				if not ag.door[i]:                       # door too: a shove into the wall by it stops them dead)
					var near := (WALL_NEAR - wall.z) / WALL_NEAR
					var keen := wish.length()
					var along := wish - nw * minf(wish.dot(nw), 0.0) * clampf(near * 2.0, 0.0, 1.0)
					if along.length_squared() > 0.0001:
						wish = along.normalized() * keen     # along the wall, not into it, at their own speed
					push += nw * WALL_PUSH * near
		var dv := ((wish - v) / ag.relax[i] + push) * dt
		var most := ag.accel[i] * dt
		var speed := v.length()
		if speed > 0.1:                  # along the way: their acceleration; across it (turning): TURN_GRIP times it
			var ahead := v / speed
			var along := clampf(dv.dot(ahead), -most, most)
			var turned := v + ahead * along + (dv - ahead * dv.dot(ahead)).limit_length(most * TURN_GRIP)
			var next := clampf(turned.length(), speed - most, speed + most)   # (a firm turn never adds speed)
			dv = turned.normalized() * next - v if turned.length_squared() > 0.000001 else -v
		elif dv.length_squared() > most * most:
			dv = dv.normalized() * most
		v += dv
		var top := ag.top[i]
		if v.length_squared() > top * top:
			v = v.normalized() * top
		ag.pos[i] += (ag.vel[i] + v) * 0.5 * dt        # the frame's average speed (a long frame is not a jump)
		ag.vel[i] = v
	var undone := _separate(ag, grid, SHOVED_MOST * dt)
	if not blocks.is_empty():
		_out_of(ag, blocks)
	return undone


## The push on one agent from the neighbours it can see or feel (the goal force is added every step in `step`).
static func _avoid(ag: Agents, i: int, what: int, grid: Dictionary) -> Vector2:
	var x := ag.pos[i]
	var v := ag.vel[i]
	var f := Vector2.ZERO
	var speed := v.length()
	var heading := v / speed if speed > 0.05 else ag.want[i].normalized()
	var h := ag.horizon[i] if what == WALKER else minf(ag.horizon[i], STAND_HORIZON)
	var gain := 1.0 if what == WALKER else STAND_GIVE
	var cx := floori(x.x / CELL)
	var cz := floori(x.y / CELL)
	var strongest := 0.0
	ag.threat[i] = Vector2.ZERO
	for gx in range(cx - 1, cx + 2):
		for gz in range(cz - 1, cz + 2):
			for j: int in grid.get(gx * 100003 + gz, _EMPTY):
				if j == i:
					continue
				var personal := float(ag.regard[i].get(j,0.0))
				if what == STANDING and (ag.kind[j] == SPACE or (personal<=0.0 and (ag.kind[j] == STANDING or (ag.group[i] != 0 and ag.group[i] == ag.group[j])))):
					continue                       # spots are planned apart (formations); only movers make them give way,
					                               # and not their own company getting into place round them
				if ag.kind[j] == SPACE and ag.group[i] != 0 and ag.group[i] == ag.group[j]:
					continue                       # (their own conversation's middle: theirs to cross)
				var w := ag.pos[j] - x
				var d2 := w.length_squared()
				if d2 > CELL * CELL:
					continue
				var d := sqrt(d2)
				var hard := ag.body[i] + ag.body[j]
				if d - hard > FEEL and heading != Vector2.ZERO and w.dot(heading) < SEE_BEHIND * d:
					continue                       # behind them, and not close enough to feel
				var together := personal<=0.0 and ag.group[i] != 0 and ag.group[i] == ag.group[j]
				var soft := maxf(hard,personal) if personal>0.0 else hard + (ag.space[i] if not together else 0.0)
				var r := soft
				if d < soft:
					if d > 0.0001 and (what == WALKER or personal>0.0):
						var closing := maxf((v - ag.vel[j]).dot(w / d), 0.0)
						var room := 1.0 if personal>0.0 else ALONGSIDE + (1.0 - ALONGSIDE) * clampf(closing / CLOSING, 0.0, 1.0)
						f -= (w / d) * SPACE_PUSH * room * (soft - d) / maxf(soft-hard, 0.05)
					r = hard                       # already within their room: still steer clear of touching
				var rel := v - ag.vel[j]
				var t := ttc(w, rel, r)
				if t > h:
					continue
				var away := -w + rel * t                 # (x + v t) - (xj + vj t): from where they would meet, to me
				var length := away.length()
				if length < 0.0001:
					continue
				var closing := rel.length()
				if closing > 0.05:                       # nearly nose to nose: step to your own right, as the other will
					var head_on := clampf((-away.dot(rel) / (length * closing) - 0.7) / 0.3, 0.0, 1.0)
					away += Vector2(-heading.y, heading.x) * length * KEEP_RIGHT * head_on
					length = away.length()
				var push := minf((h - t) / (t + 0.001), PUSH_CAP)
				f += (away / length) * push * gain
				if what == STANDING and push > strongest:
					strongest = push
					ag.threat[i] = ag.vel[j]
	return f


## The hard pass: overlapping bodies are pushed apart along the line between them, each by how much it gives
## (a walker 1, someone holding a spot 0.3, the player or an animal 0). One pressed by a body that gives nothing moves
## at most `shoved_most` a step (a quick step aside), never flung at the presser's speed. Returns how many pairs it moved.
static func _separate(ag: Agents, grid: Dictionary, shoved_most := INF) -> int:
	var moved := 0
	for i in ag.size:
		var ki := ag.kind[i]
		var x := ag.pos[i]
		var cx := floori(x.x / CELL)
		var cz := floori(x.y / CELL)
		for gx in range(cx - 1, cx + 2):
			for gz in range(cz - 1, cz + 2):
				for j: int in grid.get(gx * 100003 + gz, _EMPTY):
					if j <= i:
						continue
					var kj := ag.kind[j]
					var gi := _give(ki, kj)
					var gj := _give(kj, ki)
					if gi + gj <= 0.0 or ((ki == SPACE or kj == SPACE) and (ki == STANDING or kj == STANDING \
							or (ag.group[i] != 0 and ag.group[i] == ag.group[j]))):
						continue                   # (a conversation's middle moves only those walking in who are not its own)
					var w := ag.pos[j] - ag.pos[i]
					var hard := ag.body[i] + ag.body[j]
					var d2 := w.length_squared()
					if d2 >= hard * hard:
						continue
					var d := sqrt(d2)
					var over := hard - d
					if over < SLOP:
						continue
					var normal := w / d if d > 0.0001 else Vector2(1.0, 0.0).rotated(float(i * 7 + j) * 0.9)
					var si := over * gi / (gi + gj)
					var sj := over * gj / (gi + gj)
					if gj == 0.0:                  # pressed by one who will not give: a step's worth, never flung
						si = minf(si, shoved_most)
					if gi == 0.0:
						sj = minf(sj, shoved_most)
					ag.pos[i] -= normal * si
					ag.pos[j] += normal * sj
					moved += 1
	return moved


## Nobody ends a step inside a block: pushed out the nearest side, and their way turned along the wall at the same
## speed (they slide along it, as a person brushing a corner does; never stopped dead, which reads as a snap).
static func _out_of(ag: Agents, blocks: Array[Rect2]) -> void:
	for i in ag.size:
		if ag.kind[i] >= OTHER:
			continue
		var p := ag.pos[i]
		for r in blocks:
			if not r.has_point(p):
				continue
			var left := p.x - r.position.x
			var right := r.end.x - p.x
			var top := p.y - r.position.y
			var bottom := r.end.y - p.y
			var m := minf(minf(left, right), minf(top, bottom))
			var v := ag.vel[i]
			if m == left:
				p.x = r.position.x
				v.x = minf(v.x, 0.0)
			elif m == right:
				p.x = r.end.x
				v.x = maxf(v.x, 0.0)
			elif m == top:
				p.y = r.position.y
				v.y = minf(v.y, 0.0)
			else:
				p.y = r.end.y
				v.y = maxf(v.y, 0.0)
			var speed := ag.vel[i].length()
			ag.vel[i] = v.normalized() * speed if v.length_squared() > 0.0001 else Vector2.ZERO
		ag.pos[i] = p


## The nearest wall to p: (outward normal x, y, distance); distance INF with none within WALL_NEAR. Inside one: its
## nearest face, distance 0.
static func _wall(p: Vector2, walls: Array[Rect2]) -> Vector3:
	var best := Vector3(0.0, 0.0, INF)
	for r in walls:
		if p.x < r.position.x - WALL_NEAR or p.x > r.end.x + WALL_NEAR or p.y < r.position.y - WALL_NEAR or p.y > r.end.y + WALL_NEAR:
			continue
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var d := p.distance_to(q)
		if d < 0.0001:                   # inside: out the nearest face
			var faces := [[p.x - r.position.x, Vector2(-1, 0)], [r.end.x - p.x, Vector2(1, 0)],
				[p.y - r.position.y, Vector2(0, -1)], [r.end.y - p.y, Vector2(0, 1)]]
			faces.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			return Vector3(faces[0][1].x, faces[0][1].y, 0.0)
		if d < best.z:
			var n := (p - q) / d
			best = Vector3(n.x, n.y, d)
	return best


## Whether a straight walk a-b keeps `pad` metres off every wall.
static func sees(a: Vector2, b: Vector2, walls: Array[Rect2], pad: float) -> bool:
	for r in walls:
		if _crosses(a, b, r.grow(pad)):
			return false
	return true


## Whether the segment a-b passes through the inside of r (slab test).
static func _crosses(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis in 2:
		var p := a[axis]
		var v := d[axis]
		var lo := r.position[axis]
		var hi := r.end[axis]
		if absf(v) < 0.000001:
			if p <= lo or p >= hi:
				return false
		else:
			var ta := (lo - p) / v
			var tb := (hi - p) / v
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 >= t1:
				return false
	return true


## How much of an overlap `what` takes, pressed by `them`.
static func _give(what: int, them: int) -> float:
	if what == WALKER:
		return 1.0
	if what == STANDING:
		return STAND_YIELD if them == WALKER else 0.3
	return 0.0


static func _key(gx: int, gz: int) -> int:
	return gx * 100003 + gz
