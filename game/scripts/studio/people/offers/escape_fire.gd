extends "res://scripts/studio/people/offer.gd"
const ID := "escape_fire"
const ANSWERS := ["fire","burning"]
const ROLES := ["burning victim"]
const PRIORITY := 6
func can(me: Dictionary,a: Dictionary) -> bool:
	return own_fire(me,a) and not (a.get("affordances",{}).get("water",{}) as Dictionary).is_empty()
## Water near is the surest way out; water far is a run through your own fire (6 Oct port probe: Tomas ran for a far
## well alight and died on the way), so beat_out (1150) outranks it beyond NEAR_WATER metres.
const NEAR_WATER := 8.0
func score(_me: Dictionary,a: Dictionary) -> int:
	return 1200 if float(a.get("affordances",{}).get("water",{}).get("distance",0.0))<=NEAR_WATER else 1100   # (no measured distance: as before, the water wins)
func steps(me: Dictionary,a: Dictionary) -> Array:
	var water: Dictionary=a.affordances.water
	return [{"op":"say","text":"I was saving that skin for winter."},
		{"op":"travel","target":water.key,"pace":"run","short":0.3},
		{"op":"use","verb":"extinguish","target":me.key,"method":"water","cause_id":a.deed,"affordance":water.key},
		{"op":"wait","seconds":1.0}]
func lasts(_me: Dictionary,_a: Dictionary) -> float:
	return 20.0

## Is it my own burning? The account is about me, or I felt it: a fire that spread to me from someone I saw catch it
## carries that first ignition's deed, so it joins my account of their fire (target them) as a felt facet (6 Oct probe:
## Tomas, alight from his friend's flames, never answered his own).
static func own_fire(me: Dictionary,a: Dictionary) -> bool:
	if a.target==me.key and a.evidence.get("act","") in ["burn","burning"]:
		return true
	for f: Dictionary in a.get("facets",{}).values():
		var e: Dictionary=f.get("evidence",{})
		if str(f.get("via",""))=="felt" and (str(e.get("act","")) in ["burn","burning"] or str(e.get("condition",""))=="burning"):
			return true
	return false
