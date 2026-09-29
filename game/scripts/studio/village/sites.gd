extends RefCounted
## The meadow village's named places, shared by the village simulation (which decides who goes where) and
## the stage (which walks bodies there). Positions are metres on the ground plane (x, z); height comes from
## WorldShape.height_at. Homes follow Enea's houses in world/village.gd (HOUSES); the public places are
## the studio's, chosen to sit on open ground near the path. A site can hold a crowd in rings of slots.
## Contract for the night-1 work (plan/NIGHT-1-PLAN in the studio): add places, don't move existing ones.

const HOMES := {
	"cottage": Vector2(-5.5, 11.5), "cabin": Vector2(10.5, 13.0), "round": Vector2(-9.0, 23.0),
	"hill": Vector2(9.0, 22.0), "lodge": Vector2(-6.0, 31.0), "loaf": Vector2(-13.0, 2.0),
}
## Doorsteps: where villagers leave and enter a home (a step in front of the house, towards the path).
const DOORS := {
	"cottage": Vector2(-3.2, 12.6), "cabin": Vector2(8.0, 14.0), "round": Vector2(-6.4, 23.4),
	"hill": Vector2(5.8, 22.4), "lodge": Vector2(-3.2, 30.0), "loaf": Vector2(-10.2, 3.6),
}
## Public places. "focus" is what a crowd faces; rings of slots are laid out around it.
const PLACES := {
	"square": {"at": Vector2(1.5, 18.0), "focus": Vector2(1.5, 18.0)},       # the open ground by the merchant
	"pillory": {"at": Vector2(-0.5, 17.0), "focus": Vector2(-0.5, 17.0)},    # stands in the square
	"gallows": {"at": Vector2(1.0, 7.0), "focus": Vector2(1.0, 7.0)},        # north end, by the path
	"stake": {"at": Vector2(4.0, -5.0), "focus": Vector2(4.0, -5.0)},        # outside the village, open field
	"shrine": {"at": Vector2(-11.0, 14.0), "focus": Vector2(-11.0, 14.0)},
	"well": {"at": Vector2(4.0, 25.0), "focus": Vector2(4.0, 25.0)},
	"mill": {"at": Vector2(12.0, 6.0), "focus": Vector2(14.0, 3.0)},         # work: the windmill
	"field": {"at": Vector2(-14.0, 20.0), "focus": Vector2(-14.0, 20.0)},    # work: crops west of the village
	"merchant": {"at": Vector2(4.4, 16.6), "focus": Vector2(5.4, 16.0)},
	"gate_south": {"at": Vector2(2.0, 40.0), "focus": Vector2(2.0, 48.0)},   # the road out (exile)
}
const RING_STEP := 1.4       # metres between rings
const FIRST_RING := 2.6      # metres from the focus to the first ring
const SLOT_GAP := 1.1        # metres between neighbours on a ring
## Watching crowds (arc): the side left open is the one the game's camera looks from. The camera never
## turns (follow_camera.gd): it sits south of the player and looks north, so the open side is +z (south).
const ARC_OPEN_TOWARDS := Vector2(0.0, 1.0)
const ARC_OPEN := 55.0       # degrees either side of ARC_OPEN_TOWARDS with nobody in them
## Places whose device needs more room than FIRST_RING before the first row (the gallows' steps, the fire).
const ARC_FIRST := {"gallows": 3.8, "stake": 3.4}
## Gatherings with no middle (a festival): small circles of people facing each other, the circles in
## rows of arcs like a watching crowd (open to the camera), CLUSTER_GAP apart.
const CLUSTER_SIZE := 5
const CLUSTER_RADIUS := 0.85 # metres from a circle's middle to its people
const CLUSTER_GAP := 1.8     # metres between neighbouring circles' people
const CLUSTER_RING := 3.4    # metres from the place to the first row of circles
const CLUSTER_RING_STEP := 3.3


## The ground position (x, z) of a site id: a home, a door or a public place.
static func at(site: String) -> Vector2:
	if PLACES.has(site):
		return PLACES[site]["at"]
	if DOORS.has(site):
		return DOORS[site]
	return HOMES.get(site, Vector2.ZERO)


## Crowd slot `n` around a place's focus: ring by ring, outward, each ring filled evenly. Deterministic, so
## the simulation and the stage agree on who stands where (slots are handed out in id order).
static func slot(place: String, n: int) -> Vector2:
	var focus: Vector2 = PLACES[place]["focus"] if PLACES.has(place) else at(place)
	var ring := 0
	var first := 0
	while true:
		var r := FIRST_RING + ring * RING_STEP
		var count := maxi(6, int(TAU * r / SLOT_GAP))
		if n < first + count:
			var a := TAU * float(n - first) / count + ring * 0.35
			return focus + Vector2(cos(a), sin(a)) * r
		first += count
		ring += 1
	return focus


## Crowd slot `n` for watching something at a place (a device, a trial): rows of arcs round the place
## (at(place)), everyone facing it, leaving ARC_OPEN either side of the camera's side empty so the crowd
## frames the act instead of hiding it - a horseshoe open to the camera:
##
##            . . . . . . .          row 1 (RING_STEP further out)
##          .  o o o o o o  .        row 0 (ARC_FIRST or FIRST_RING out)
##         .  o     X     o  .       X the place
##          .  o         o  .
##                               <- open (ARC_OPEN either side of +z): the camera looks in from here
##
## Row by row outward; within a row the slots go ends first (nearest the open side), then halving the
## gaps, so a small crowd still spreads round the whole horseshoe. Deterministic, like slot().
static func arc(place: String, n: int) -> Vector2:
	var centre := at(place)
	var r0: float = ARC_FIRST.get(place, FIRST_RING)
	var open := deg_to_rad(ARC_OPEN)
	var span := TAU - 2.0 * open
	var facing := atan2(ARC_OPEN_TOWARDS.x, ARC_OPEN_TOWARDS.y)
	var first := 0
	var row := 0
	while true:
		var r := r0 + row * RING_STEP
		var count := maxi(3, int(span * r / SLOT_GAP))
		if n < first + count:
			var a := facing + open + span * (_spread(n - first, count) + 0.5) / count
			return centre + Vector2(sin(a), cos(a)) * r
		first += count
		row += 1
	return centre


## The i-th position (of `count` along a row) to fill: both ends, then the middle, then the middles of
## the halves, and so on (breadth first), so any first few are spread along the whole row.
static func _spread(i: int, count: int) -> int:
	if i <= 0 or count <= 1:
		return 0
	if i == 1:
		return count - 1
	var found := 2
	var spans: Array[Vector2i] = [Vector2i(0, count - 1)]
	var next := 0
	while next < spans.size():
		var s := spans[next]
		next += 1
		var mid := (s.x + s.y) / 2
		if mid == s.x:
			continue
		if found == i:
			return mid
		found += 1
		spans.append(Vector2i(s.x, mid))
		spans.append(Vector2i(mid, s.y))
	return mini(i, count - 1)


## Slot `n` of a gathering with no middle (a festival): circles of CLUSTER_SIZE people round the place,
## each person facing their circle's middle (cluster_middle). Deterministic, like slot().
static func cluster(place: String, n: int) -> Vector2:
	var k := n % CLUSTER_SIZE
	var a := TAU * k / CLUSTER_SIZE + (n / CLUSTER_SIZE) * 0.7
	return cluster_middle(place, n) + Vector2(sin(a), cos(a)) * CLUSTER_RADIUS


## The middle of the circle slot `n` belongs to (what its person faces): circles fill rows of arcs round
## the place, ends first, leaving the camera's side open (as arc()).
static func cluster_middle(place: String, n: int) -> Vector2:
	var centre := at(place)
	var c := n / CLUSTER_SIZE
	var open := deg_to_rad(ARC_OPEN)
	var span := TAU - 2.0 * open
	var facing := atan2(ARC_OPEN_TOWARDS.x, ARC_OPEN_TOWARDS.y)
	var row := 0
	var first := 0
	while true:
		var r := CLUSTER_RING + row * CLUSTER_RING_STEP
		var count := maxi(2, int(span * r / (CLUSTER_RADIUS * 2.0 + CLUSTER_GAP)))
		if c < first + count:
			var a := facing + open + span * (_spread(c - first, count) + 0.5) / count
			return centre + Vector2(sin(a), cos(a)) * r
		first += count
		row += 1
	return centre
