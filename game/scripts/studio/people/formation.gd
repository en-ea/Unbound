extends RefCounted
## Where each member of a group stands (Pass 3, L5). Pure: points in, points out. Generic: it knows people and the
## shapes they make together, not villages.
##
##   Formation.circle(centre, n)            a conversation: n round a shared middle, everyone in view of everyone
##                                          (the "o-space" of Kendon's F-formation): a pair face to face, three a
##                                          triangle, more a ring, about a shoulder and a hand apart
##   Formation.assign(slots, at) -> order   who takes which slot: round the ring in the order they stand, turned
##                                          for the least walking, so nobody crosses another to get to theirs
##   Formation.side_by_side(at, heading, i) walking together: the i-th companion beside the first (left, right, ...)
##   Formation.ring(centre, n, k, bold, open)  onlookers round what they watch: the bold nearer, the timid further,
##                                          none in the open side (towards the camera, or the way out)
##   Formation.queue(head, back, k)         the k-th in a line, behind the head
##
##        o              pair  o  o         ring    . o . o .          side by side   o o o  ->
##     o  .  o                                    o           o
##        o                                       .   (what)   .
##                                                 (open side)

const SHOULDER := 0.72        # metres round the ring from one talker to the next (a shoulder and a hand)
const PAIR := 1.1             # metres between two talking face to face
const BESIDE := 0.7           # metres between companions walking side by side
const IN_LINE := 0.85         # metres from one in a queue to the next
const RING_NEAR := 2.2        # metres: the boldest onlooker this far from what they watch ...
const RING_FAR := 4.2         # ... the most timid this far
const RING_OPEN := 1.0        # radians either side of the open direction kept clear


## The radius of a conversation of n.
static func radius_for(n: int) -> float:
	if n <= 2:
		return PAIR * 0.5
	return maxf(SHOULDER * n / TAU, PAIR * 0.5 + 0.08 * (n - 2))


## n slots round `centre`, the first at angle `turn`.
static func circle(centre: Vector2, n: int, turn := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r := radius_for(n)
	for k in n:
		var a := turn + TAU * k / maxi(n, 1)
		out.append(centre + Vector2(cos(a), sin(a)) * r)
	return out


## The even ring round `centre` that people standing at `at` make with the least shuffling: each keeps their order
## round the middle, and the ring is turned to fit them (the mean of their angles off an even spacing). Place i is
## for the person at at[i]. A circle that keeps its shape this way does it by small steps, as people do, not by places
## handed out once.
static func fit(centre: Vector2, at: Array) -> PackedVector2Array:
	var n := at.size()
	var out := PackedVector2Array()
	out.resize(n)
	if n == 0:
		return out
	var by_angle: Array = []
	for i in n:
		var off: Vector2 = (at[i] as Vector2) - centre
		by_angle.append([atan2(off.y, off.x), i])
	by_angle.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var s := 0.0
	var c := 0.0
	for k in n:
		var o: float = float(by_angle[k][0]) - TAU * k / n
		s += sin(o)
		c += cos(o)
	var turn := atan2(s, c)
	var r := radius_for(n)
	for k in n:
		var a := turn + TAU * k / n
		out[int(by_angle[k][1])] = centre + Vector2(cos(a), sin(a)) * r
	return out


## Who takes which slot of a ring round `centre`: slot order[i] for the person at at[i]. People keep the order they
## stand in round the middle, and the ring is turned so the walk in all is least (n turnings tried: n is small).
static func assign(centre: Vector2, slots: PackedVector2Array, at: Array) -> PackedInt32Array:
	var n := at.size()
	var order := PackedInt32Array()
	order.resize(n)
	if n == 0:
		return order
	var by_angle: Array = []
	for i in n:
		var off: Vector2 = (at[i] as Vector2) - centre
		by_angle.append([atan2(off.y, off.x), i])
	by_angle.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var slot_angle: Array = []
	for k in slots.size():
		var off := slots[k] - centre
		slot_angle.append([atan2(off.y, off.x), k])
	slot_angle.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var best := INF
	var best_shift := 0
	for shift in slots.size():
		var walk := 0.0
		for j in n:
			var who: int = by_angle[j][1]
			var k: int = slot_angle[(j + shift) % slots.size()][1]
			walk += (at[who] as Vector2).distance_to(slots[k])
		if walk < best:
			best = walk
			best_shift = shift
	for j in n:
		order[by_angle[j][1]] = slot_angle[(j + best_shift) % slots.size()][1]
	return order


## Where the i-th companion walks (i = 0 the first: at `at`): beside them, alternating left and right.
static func side_by_side(at: Vector2, heading: Vector2, i: int) -> Vector2:
	if i == 0 or heading.length_squared() < 0.0001:
		return at
	var side := Vector2(-heading.y, heading.x).normalized()
	var step := (i + 1) / 2
	return at + side * BESIDE * step * (1.0 if i % 2 == 1 else -1.0)


## The k-th of n onlookers round `centre`, `bold` 0..1: the bold stand nearer. The ring leaves RING_OPEN either side of
## `open` empty (Vector2.ZERO: no open side).
static func ring(centre: Vector2, n: int, k: int, bold: float, open := Vector2.ZERO) -> Vector2:
	var r := lerpf(RING_FAR, RING_NEAR, clampf(bold, 0.0, 1.0))
	var span := TAU
	var start := 0.0
	if open != Vector2.ZERO:
		span = TAU - 2.0 * RING_OPEN
		start = atan2(open.y, open.x) + RING_OPEN
	var a := start + span * (k + 0.5) / maxi(n, 1)
	return centre + Vector2(cos(a), sin(a)) * r


## The k-th in a line behind `head` (k = 0 the head), the line going `back` (a direction).
static func queue(head: Vector2, back: Vector2, k: int) -> Vector2:
	return head + back.normalized() * IN_LINE * k
