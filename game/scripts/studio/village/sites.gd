extends RefCounted
## The meadow village's named places, shared by the village simulation (which decides who goes where) and
## the stage (which walks bodies there). Positions are metres on the ground plane (x, z); height comes from
## WorldShape.height_at. Homes, doors and pens are read from Enea's houses in world/village.gd (HOUSES); the public
## places are the studio's, kept clear of his buildings. A site can hold a crowd in rings of slots.
## Contract for the night-1 work (plan/NIGHT-1-PLAN in the studio): add places, don't move existing ones.

const Houses := preload("res://scripts/world/village.gd")
## merge-enea (6 Oct, Hilmi's revision 6: "his layout wins"): homes, doors, pens, the mill and the merchant are read
## from Enea's own buildings (world/village.gd HOUSES, door_of, MERCHANT_AT), so wherever he puts a house the
## village follows. A home is named after its model (house_cottage.glb -> "cottage").
static var HOMES := _homes()
## Doorsteps: his own door_of (the house's front, turned to the green, plus a step).
static var DOORS := _doors()
## Each home's pen (the sim's pen_<home>): beside the house, on the side away from his letting sign.
static var PENS := _pens()
## Public places. "focus" is what a crowd faces; rings of slots are laid out around it. The studio's own places
## (the pillory, gallows, stake, shrine, well, field, the road out) keep their spots unless one of his buildings
## now stands there: then it moves straight out of the building to clear ground (CLEAR metres from its walls).
## The mill and the merchant follow his windmill and his merchant.
const OWN_PLACES := {
	"square": {"at": Vector2(1.5, 18.0), "focus": Vector2(1.5, 18.0)},       # the open ground by the merchant
	"pillory": {"at": Vector2(-0.5, 17.0), "focus": Vector2(-0.5, 17.0)},    # stands in the square
	"gallows": {"at": Vector2(1.0, 7.0), "focus": Vector2(1.0, 7.0)},        # north end, by the path
	"stake": {"at": Vector2(4.0, -5.0), "focus": Vector2(4.0, -5.0)},        # outside the village, open field
	"shrine": {"at": Vector2(-11.0, 14.0), "focus": Vector2(-11.0, 14.0)},
	"well": {"at": Vector2(4.0, 25.0), "focus": Vector2(4.0, 25.0)},
	"field": {"at": Vector2(-14.0, 20.0), "focus": Vector2(-14.0, 20.0)},    # work: crops west of the village
	"gate_south": {"at": Vector2(2.0, 40.0), "focus": Vector2(2.0, 48.0)},   # the road out (exile)
}
const CLEAR := 1.5
static var PLACES := _places()


static func _home_name(model: String) -> String:
	return model.get_file().get_basename().trim_prefix("house_")


static func _homes() -> Dictionary:
	var out := {}
	for h: Dictionary in Houses.HOUSES:
		if String(h["model"]).get_file().begins_with("house_"):
			out[_home_name(h["model"])] = h["at"]
	return out


static func _doors() -> Dictionary:
	var out := {}
	for i in Houses.HOUSES.size():
		if String(Houses.HOUSES[i]["model"]).get_file().begins_with("house_"):
			out[_home_name(Houses.HOUSES[i]["model"])] = Houses.door_of(i)
	return out


static func _pens() -> Dictionary:
	var out := {}
	for i in Houses.HOUSES.size():
		var h: Dictionary = Houses.HOUSES[i]
		if not String(h["model"]).get_file().begins_with("house_"):
			continue
		var to_green: Vector2 = (Houses.GREEN - h["at"]).normalized()
		out["pen_" + _home_name(h["model"])] = Houses.door_of(i) - to_green.orthogonal() * (h["size"].x * 0.5 + 1.6) - to_green * 1.2
	return out


## A point inside (or within CLEAR of) one of his buildings, moved straight out to clear ground.
static func clear_of_buildings(p: Vector2) -> Vector2:
	for h: Dictionary in Houses.HOUSES:
		var at: Vector2 = h["at"]
		var reach: float = maxf(h["size"].x, h["size"].z) * 0.5 + CLEAR
		var d := p.distance_to(at)
		if d < reach:
			var away := (p - at).normalized() if d > 0.01 else (Houses.GREEN - at).normalized()
			p = at + away * reach
	return p


static func _places() -> Dictionary:
	var out := {}
	for k: String in OWN_PLACES:
		var at := clear_of_buildings(OWN_PLACES[k]["at"])
		var shift: Vector2 = at - OWN_PLACES[k]["at"]
		out[k] = {"at": at, "focus": OWN_PLACES[k]["focus"] + shift}
	for i in Houses.HOUSES.size():
		if String(Houses.HOUSES[i]["model"]).get_file() == "windmill.glb": # work: his windmill, at its door
			out["mill"] = {"at": Houses.door_of(i), "focus": Houses.HOUSES[i]["at"]}
	out["merchant"] = {"at": Houses.MERCHANT_AT + Vector2(-1.0, 0.6), "focus": Houses.MERCHANT_AT}
	return out
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
	if PENS.has(site):
		return PENS[site]
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
