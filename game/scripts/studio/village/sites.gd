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
