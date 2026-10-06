extends RefCounted
## The one thumb area's tap, as a rule over what is in reach (pure, headless). physical_input.gd gathers the facts; this
## decides which act a tap is, once, for both schemes (the act area's tap and the discs' Hand).
##
##   facts: {slot: context}   the contexts in reach this frame, by slot (absent: not there)
##     erupt            burrowed: come up                       } urgent: a tap always does these first,
##     extinguish       a burning person in reach: put it out   } before any pick-up, talk or station
##     get_off          riding: get off                         }
##     takedown         a downed foe the fighter would finish   }
##     village_station  a village action spot (free the pilloried)
##     station          a station or someone to talk to
##     lower            carrying a carcass: set it down
##     gather           something to gather
##   gripping            grip()'s context: a load to lower, a downed person to lift, a carcass to lift, or "empty"
##
##   tap order   urgent > picking up or setting down > village action > talk and stations > gathering > Use
##   flick/push  strike and shove are the stroke's, never the tap's; while carrying, a flick does not strike
##               (Enea's haul: "no fighting"), a push still shoves
const URGENT := ["erupt", "extinguish", "get_off", "takedown"]
const USE_ORDER := ["erupt", "extinguish", "get_off", "takedown", "village_station", "station", "lower", "gather"]
const EMPTY := {"kind": "empty", "verb": "Use"}


## What a tap on the old Hand disc (and the act area, when it grips nothing) does: the first slot present in order.
static func use_of(facts: Dictionary) -> Dictionary:
	for slot: String in USE_ORDER:
		if facts.has(slot):
			return facts[slot]
	return EMPTY


## The act area's tap: {"tap": "use"|"grip", "context", "slot"}.
static func tap(facts: Dictionary, gripping: Dictionary) -> Dictionary:
	var slot := ""
	for s: String in USE_ORDER:
		if facts.has(s):
			slot = s
			break
	if slot in URGENT or str(gripping.get("kind", "empty")) == "empty" or _cart_load(facts):
		return {"tap": "use", "context": use_of(facts), "slot": slot if slot != "" else "empty"}
	return {"tap": "grip", "context": gripping, "slot": "grip"}


## merge-fix: at the ox cart with a load, the tap puts it in the bed (or takes one out) rather than setting it down.
static func _cart_load(facts: Dictionary) -> bool:
	return str(facts.get("station", {}).get("verb", "")) in ["Load", "Take out"]


## Whether a released flick strikes while this load is carried (a carcass dragged, a person on the shoulders): no.
static func strikes_while(load: String) -> bool:
	return load == ""


## The hint's words for the stroke, honest about the load: "<tap verb> / flick strike / push shove".
static func hint(tap_verb: String, load: String) -> String:
	return tap_verb + (" / flick strike / push shove" if strikes_while(load) else " / push shove")
