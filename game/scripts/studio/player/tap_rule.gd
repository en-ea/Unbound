extends RefCounted
## The one thumb area's tap, as a rule over what is in reach (pure, headless). physical_input.gd gathers the facts; this
## decides which act a tap is, once, for both schemes (the act area's tap and the discs' Hand).
##
##   facts: {slot: context}   the contexts in reach this frame, by slot (absent: not there)
##     erupt            burrowed: come up                       } urgent: a tap always does these first,
##     extinguish       a burning person in reach: put it out   } before any pick-up, talk or station
##     get_off          riding: get off                         }
##     (takedown        C1 unit 2: no longer a tap; holding Heavy is the severe act - hands.gd, physical_input.severe)
##     village_station  a village action spot (free the pilloried)
##     station          a station or someone to talk to
##     lower            carrying a carcass: set it down
##     gather           something to gather
##     fight            a foe in reach (C1: his Attack's light swing; with nothing at all the swing goes at the air)
##   gripping            grip()'s context: a load to lower, a downed person to lift, a carcass to lift, or "empty"
##
##   tap order   urgent > picking up or setting down > village action > talk and stations > gathering > Use
##   flick/push  strike and shove are the stroke's, never the tap's; while carrying, a flick does not strike
##               (Enea's haul: "no fighting"), a push still shoves
const Gesture := preload("res://scripts/studio/player/gesture.gd") # merge-fix: the hint follows how strokes pick acts
const URGENT := ["erupt", "extinguish", "get_off"]
const USE_ORDER := ["erupt", "extinguish", "get_off", "village_station", "station", "lower", "gather", "fight"]
const EMPTY := {"kind": "empty", "verb": "Use"}
## C1 (desk, 6 Oct): of the things in reach - stations, people to talk to, something to gather, a foe - the tap takes
## the one he faces: the nearest inside the facing cone (or within TOUCHING, whatever way he faces); with none ahead,
## the nearest. On a near tie (NEAR_TIE metres) a person outranks a fixed station. Gathering stays the background act
## (talk and stations came before it, as in his act()): a tree or bush is chosen only when nothing else is there to
## choose. The urgent slots above stay first.
const CONE := 0.5 # cos 60 deg either side of facing
const TOUCHING := 0.6
const NEAR_TIE := 0.5


## rows: [{"slot", "context", "at": Vector2 from him to it, "person": bool}]; forward: his facing (x, z). Returns the
## chosen row, or {} when there are none.
static func pick(rows: Array, forward: Vector2) -> Dictionary:
	var ahead := rows.filter(func(r: Dictionary) -> bool:
		var to: Vector2 = r.at
		return to.length() <= TOUCHING or to.normalized().dot(forward.normalized()) >= CONE)
	var pool: Array = ahead if not ahead.is_empty() else rows
	if pool.any(func(r: Dictionary) -> bool: return str(r.slot) != "gather"):
		pool = pool.filter(func(r: Dictionary) -> bool: return str(r.slot) != "gather")
	var best := {}
	for r: Dictionary in pool:
		if best.is_empty() or (r.at as Vector2).length() < (best.at as Vector2).length():
			best = r
	if best.is_empty() or bool(best.get("person", false)):
		return best
	for r: Dictionary in pool:
		if bool(r.get("person", false)) and (r.at as Vector2).length() - (best.at as Vector2).length() <= NEAR_TIE:
			if not bool(best.get("person", false)) or (r.at as Vector2).length() < (best.at as Vector2).length():
				best = r
	return best


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
	if not (Gesture.by_direction and Settings.thumb_controls): # merge-fix: his thumb area, by direction (C1's buttons: as before)
		return tap_verb + (" / flick strike / push shove" if strikes_while(load) else " / push shove")
	return "Tap: " + tap_verb # the directions are marked round the thumb area itself
