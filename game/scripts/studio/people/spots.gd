extends RefCounted
## Good places to stand (Pass 3: Hilmi asked for "algo adjusted spots that aren't in awkward positions"). Where people
## take up their spots at a gathering, so that nobody stands in a wall or a tree, on a doorstep, behind a wall from what
## they came to see, on top of anyone, or with their back to it. Generic: it knows points, what is looked at and two
## tests the director gives it, not villages.
##
##   var g := Spots.Gathering.new(focus, standable, sees)
##       standable: (Vector2) -> bool          can a body stand here with ROOM round it (walls, props, water: the
##                                             director's world; asked once per candidate, when the gathering is made)
##       sees:      (Vector2, Vector2) -> bool  nothing solid between two points
##   g.open = func(p, dir) -> bool            optional: room in front of a spot, facing the focus (nobody nose to a wall
##                                           of what they came to see: a mill, a house)
##   g.keep_clear.append([point, radius])     doorsteps, ways in: nobody stands there
##   g.claim(who, from) -> Vector2            the best free spot for someone arriving from `from`
##   g.release(who)
##   g.may_leave(who, toward) -> bool       leaving: nobody still standing is in their way out (so a crowd empties from
##                                           the outside in, and nobody threads through the standing); then release(who)
##
## Spots are claimed on arrival, not when the trip is planned: those there first stand nearest, and later ones fill in
## behind them on their own side. A spot's cost, the lowest wins:
##
##   ring       how far out it is (the front fills first)                      INWARD per metre past the first ring
##   side       how far round it is from where they come from                  SIDE per radian (no walking round)
##   through    standing people the way in passes within a body's width         THROUGH each (never through the crowd)
##
##            . . . . . .          candidates: rings ~GAP apart, each spot nudged a little (keyed) so a crowd is not a
##          . . o o o . . .        drawing; the ones that are not standable with a body's room round them, on a
##         . . o  F  o . . .       doorstep, or out of sight of F are dropped once, when the gathering is made
##          . . . o . . .  <- someone arriving from here takes the nearest free ring on this side
##
## Cost: the candidates are made once per place (a few dozen standable tests); a claim is O(candidates x claimed).

const GAP := 1.05             # metres between neighbouring spots (two bodies and a little room)
const ROOM := 0.32            # metres of standable ground needed round a spot's centre (a body and a hand's width)
const INWARD := 0.9           # cost per metre further out
const SIDE := 1.1             # cost per radian round from the side they come from
const THROUGH := 3.0          # cost per standing person the way in would pass
const PASS := 0.55            # metres: a way passes someone this close
const JITTER := 0.16          # metres: how far a spot is nudged off its ring
const WAY_OUT := 3.0          # metres of the way out that must be clear of anyone standing


class Gathering:
	var focus: Vector2
	var first := 2.2          # metres from the focus to the first ring
	var rings := 5
	var keep_clear: Array = []          # [[Vector2, radius], ...]
	var open := Callable()              # (Vector2, Vector2) -> bool: room in front of a spot, that way
	var _standable: Callable
	var _sees: Callable
	var _spots := PackedVector2Array()  # the candidates (made on the first claim)
	var _ring := PackedFloat32Array()   # each one's distance from the focus
	var _taken := {}                    # spot index -> who
	var _of := {}                       # who -> spot index
	var _made := false

	func _init(at: Vector2, standable: Callable, sees := Callable(), first_ring := 2.2, ring_count := 5) -> void:
		focus = at
		_standable = standable
		_sees = sees
		first = first_ring
		rings = ring_count

	## The best free spot for `who`, arriving from `from` (their own spot again if they hold one).
	func claim(who: int, from: Vector2) -> Vector2:
		if _of.has(who):
			return _spots[_of[who]]
		_make()
		var best := -1
		var best_cost := INF
		var side := from - focus
		var side_angle := atan2(side.y, side.x) if side.length_squared() > 0.01 else 0.0
		for i in _spots.size():
			if _taken.has(i):
				continue
			var p := _spots[i]
			var off := p - focus
			var cost := INWARD * (_ring[i] - first)
			if side.length_squared() > 0.01:
				cost += SIDE * absf(angle_difference(side_angle, atan2(off.y, off.x)))
			if cost >= best_cost:
				continue
			for j: int in _taken:
				if Geometry2D.get_closest_point_to_segment(_spots[j], from, p).distance_squared_to(_spots[j]) < PASS * PASS:
					cost += THROUGH
					if cost >= best_cost:
						break
			if cost < best_cost:
				best_cost = cost
				best = i
		if best < 0:
			return focus + (side.normalized() if side.length_squared() > 0.01 else Vector2(0.0, 1.0)) * (first + rings * GAP)
		_taken[best] = who
		_of[who] = best
		return _spots[best]

	func release(who: int) -> void:
		if _of.has(who):
			_taken.erase(_of[who])
			_of.erase(who)

	## Whether `who` can leave their spot towards `toward` without passing within PASS of anyone still standing on
	## theirs (the first WAY_OUT metres).
	func may_leave(who: int, toward: Vector2) -> bool:
		if not _of.has(who):
			return true
		var from := _spots[_of[who]]
		var to := toward
		if from.distance_to(to) > WAY_OUT:
			to = from + (to - from).normalized() * WAY_OUT
		for j: int in _taken:
			if _taken[j] != who and Geometry2D.get_closest_point_to_segment(_spots[j], from, to).distance_squared_to(_spots[j]) < PASS * PASS:
				return false
		return true

	func holds(who: int) -> bool:
		return _of.has(who)

	## How many spots there are at all (a measure, and for probes).
	func size() -> int:
		_make()
		return _spots.size()

	func _make() -> void:
		if _made:
			return
		_made = true
		for k in rings:
			var r := first + k * GAP
			var count := maxi(6, int(TAU * r / GAP))
			var turn := k * 0.37
			for n in count:
				var a := turn + TAU * n / count
				var nudge := Vector2(noise(k * 997 + n, 1) - 0.5, noise(k * 997 + n, 2) - 0.5) * 2.0 * JITTER
				var p := focus + Vector2(cos(a), sin(a)) * r + nudge
				if _good(p):
					_spots.append(p)
					_ring.append(p.distance_to(focus))

	## A keyed number in [0, 1).
	static func noise(key: int, salt: int) -> float:
		return float(posmod(hash(key * 7919 + salt * 104729), 100000)) / 100000.0

	## Standable with room round it, off every doorstep, and in sight of the focus.
	func _good(p: Vector2) -> bool:
		for c: Array in keep_clear:
			if p.distance_to(c[0]) < float(c[1]):
				return false
		if _standable.is_valid() and not _standable.call(p):
			return false
		if _sees.is_valid() and not _sees.call(p, focus):
			return false
		if open.is_valid() and not open.call(p, focus - p):
			return false
		return true


static func _noise(key: int, salt: int) -> float:
	return Gathering.noise(key, salt)
