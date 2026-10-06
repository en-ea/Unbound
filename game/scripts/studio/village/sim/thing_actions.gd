extends RefCounted
## Things answer his acts (Body, world-things): a fence, a bench, a camp's crates and rack burn, char, soak, take blows
## and break, and stay so. The rules only: Foundations' thing_facts.gd is the one writer of Village.thing_facts (put,
## clear) and the one clock (advance, next_due). Acts come through people_bridge.accept (contact.gd), the same checked
## door as people's; render/thing_state.gd draws the facts.
##
##   id      "<kind>@<x dm>,<z dm>"    (the carrier's kind and where it stands; the same on every load)
##   burning {heat, until_tick, due_tick, lit_tick, spread}  the fire lasts to until_tick; due_tick is its next step
##            (char, spread), which thing_facts.advance reports with the row kept, and follow() moves on
##   scorched {level}       lasting; 1000 is burnt through: broken
##   soaked   {method, until_tick}  water or rain: puts out burning, then dries; a soaked thing does not catch
##   struck   {from, force, n}      short; a blow or shove whose force beats the toughness left breaks it
##   broken   {by}                  lasting; repair removes it
##
##   verbs    burn, extinguish {method water|rain|beat}, strike {force}, shove {force}, repair
const TF := preload("res://scripts/studio/village/sim/thing_facts.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const KINDS := {"fence": {"toughness": 450}, "bench": {"toughness": 600}, "crates": {"toughness": 350}, "rack": {"toughness": 500}}
const VERBS := ["burn", "extinguish", "strike", "shove", "repair"]
const BURN_FOR := 14000          # ms a fire lasts on its own
const HEAT := 600                # a fresh fire's heat
const STEP := 1000               # ms between char steps while it burns
const SCORCH_RATE := 12000       # ms * heat per 1000 of scorch: a full burn at 600 chars about 700
const SPREAD_AFTER := 2500       # ms a thing burns before it reaches a neighbour
const SPREAD_DM := 25            # how near a neighbour must stand (dm)
const REACH_DM := 30             # contact reach for a hand or a burning body (dm)
const SOAK_FOR := 20000          # ms a soaked thing stays wet
const STRUCK_FOR := 1200         # ms a blow shows


static func handles(verb: String) -> bool:
	return verb in VERBS


static func is_thing(target: String) -> bool:
	return target.contains("@") and KINDS.has(target.get_slice("@", 0)) and TF.valid_id(target)


static func kind_of(id: String) -> String:
	return id.get_slice("@", 0)


## Where a thing stands, read from its id, in metres [x, z].
static func at_of(id: String) -> Array:
	var p := id.get_slice("@", 1).split(",")
	return [float(p[0]) / 10.0, float(p[1]) / 10.0] if p.size() == 2 else [0.0, 0.0]


static func id_of(kind: String, x: float, z: float) -> String:
	return TF.id_at(kind, x, z)


static func rejected(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}


static func has(v: S.Village, id: String, kind: String) -> bool:
	return not TF.get_fact(v, id, kind).is_empty()


static func burnt_through(v: S.Village, id: String) -> bool:
	return has(v, id, "broken") and int(TF.get_fact(v, id, "scorched").get("level", 0)) >= 1000


## Whether fire can take hold of it now.
static func catches(v: S.Village, id: String) -> bool:
	return not has(v, id, "burning") and not has(v, id, "soaked") and not burnt_through(v, id)


## The toughness left: char weakens a thing.
static func toughness(v: S.Village, id: String) -> int:
	var base := int(KINDS.get(kind_of(id), {}).get("toughness", 500))
	var level := int(TF.get_fact(v, id, "scorched").get("level", 0))
	return base * (1000 - clampi(level, 0, 1000)) / 1000


## One act on a thing, inside acceptance. request: {action_id, actor, target, verb, parameters}; context: {distance_dm,
## reach_dm, water_contact}. roots holds each accepted act by action_id (the same press twice is the first receipt).
static func prepare(v: S.Village, roots: Dictionary, request: Dictionary, context: Dictionary) -> Dictionary:
	var action := str(request.get("action_id", ""))
	if action.is_empty() or action.length() > 160:
		return rejected("invalid action")
	if roots.has(action):
		var previous: Dictionary = roots[action].receipt.duplicate(true)
		previous.duplicate = true
		return previous
	var id := str(request.get("target", ""))
	var verb := str(request.get("verb", ""))
	var actor := str(request.get("actor", ""))
	var params: Dictionary = request.get("parameters", {})
	var now := People.tick(v)
	var distance := float(context.get("distance_dm", INF))
	if not is_thing(id):
		return rejected("no thing there")
	if not handles(verb) or actor.is_empty() or not is_finite(distance) or distance < 0 \
			or distance > clampf(float(context.get("reach_dm", REACH_DM)), 0, 120):
		return rejected("out of reach")
	var changed: Array = []
	match verb:
		"burn":
			if burnt_through(v, id):
				return rejected("burnt through")
			if has(v, id, "soaked"):
				return rejected("wet")
			if has(v, id, "burning"):
				return rejected("already burning")
			ignite(v, id, action, int(params.get("heat", HEAT)))
			changed = ["burning", "scorched"]
		"extinguish":
			var method := str(params.get("method", ""))
			if method in ["water", "rain"] and not context.get("water_contact", false):
				return rejected("no measured water contact")
			if method == "beat":
				if not has(v, id, "burning"):
					return rejected("no flames")
				_char(v, id, now)
				TF.clear(v, id, "burning")
				changed = ["burning"]
			elif method in ["water", "rain"]:
				var put_out := has(v, id, "burning")
				if put_out:
					_char(v, id, now)
					TF.clear(v, id, "burning")
				TF.put(v, id, "soaked", action, {"method": method, "until_tick": now + SOAK_FOR, "strength": 1000})
				changed = ["burning", "soaked"] if put_out else ["soaked"]
			else:
				return rejected("no method")
		"strike", "shove":
			if has(v, id, "broken"):
				return rejected("already broken")
			var force := clampi(int(params.get("force", 500)), 0, 1000)
			var n := int(TF.get_fact(v, id, "struck").get("n", 0)) + 1
			TF.put(v, id, "struck", action, {"from": actor, "force": force, "n": n, "until_tick": now + STRUCK_FOR, "strength": force})
			changed = ["struck"]
			if force > toughness(v, id):
				TF.put(v, id, "broken", action, {"by": actor})
				changed.append("broken")
		"repair":
			if not has(v, id, "broken"):
				return rejected("not broken")
			TF.clear(v, id, "broken")
			TF.clear(v, id, "scorched")
			changed = ["broken", "scorched"]
	var result := {"accepted": true, "verb": verb, "target": id, "action_id": action, "changed": changed,
		"facts": v.thing_facts.get(id, {}).duplicate(true), "event_ref": "thing:" + action.sha256_text().substr(0, 24)}
	roots[action] = {"actor": actor, "target": id, "verb": verb, "tick": now, "receipt": result.duplicate(true)}
	return result


## Sets a thing alight (deed: the fire's cause, kept through spread).
static func ignite(v: S.Village, id: String, deed: String, heat: int) -> void:
	var now := People.tick(v)
	var h := clampi(heat, 1, 1000)
	TF.put(v, id, "burning", deed, {"heat": h, "until_tick": now + BURN_FOR, "due_tick": now + mini(STEP, SPREAD_AFTER),
		"lit_tick": now, "scorch_tick": now, "spread": false, "strength": h})
	if not has(v, id, "scorched"):
		TF.put(v, id, "scorched", deed, {"level": 0, "strength": 0})


## Char raised for the burning from its last step up to now. Breaks it when it burns through; true then.
static func _char(v: S.Village, id: String, now: int, burn := {}) -> bool:
	if burn.is_empty():
		burn = TF.get_fact(v, id, "burning")
	if burn.is_empty():
		return false
	var end := mini(now, int(burn.until_tick))
	var rise := maxi(0, end - int(burn.get("scorch_tick", burn.since_tick))) * int(burn.heat) / SCORCH_RATE
	var scorch := TF.get_fact(v, id, "scorched")
	var level := mini(1000, int(scorch.get("level", 0)) + rise)
	if rise > 0:
		TF.put(v, id, "scorched", str(burn.deed), {"level": level, "strength": level})
	if level >= 1000 and not has(v, id, "broken"):
		TF.put(v, id, "broken", str(burn.deed), {"by": "fire"})
		return true
	return false


## The rules that follow from timed facts ending (thing_facts.advance's list), inside the batch that ended them: a
## fire's step raises the char, reaches its neighbours once, and lights again until it burns out or through.
## carriers: every thing id standing (spread reaches those with no facts yet). Returns the changes it made.
static func follow(v: S.Village, ended: Array, carriers: Array) -> Array:
	var out := []
	var now := People.tick(v)
	for e: Dictionary in ended:
		if str(e.kind) != "burning":
			continue
		var id := str(e.thing)
		var burn: Dictionary = e.row
		var deed := str(burn.deed)
		var through := _char(v, id, now, burn)
		if through:
			out.append({"kind": "broken", "subject": id, "cause_id": deed})
		var spread := bool(burn.get("spread", false))
		if not spread and now >= int(burn.lit_tick) + SPREAD_AFTER:
			spread = true
			for other: String in neighbours(id, carriers, v):
				if catches(v, other):
					ignite(v, other, deed, int(burn.heat) * 9 / 10)
					out.append({"kind": "burning", "subject": other, "cause_id": deed})
		if e.get("ended", true) or through:
			TF.clear(v, id, "burning")
			out.append({"kind": "burnt_out", "subject": id, "cause_id": deed})
			continue
		var next := now + STEP
		if not spread:
			next = mini(next, int(burn.lit_tick) + SPREAD_AFTER)
		var row := burn.duplicate(true)
		for k: String in ["kind", "deed", "revision", "since_tick", "due_tick"]:
			row.erase(k)
		row.merge({"scorch_tick": now, "spread": spread}, true)
		if next < int(burn.until_tick):
			row.due_tick = next
		TF.put(v, id, "burning", deed, row)
	return out


static func neighbours(id: String, carriers: Array, v: S.Village) -> Array:
	var here: Array = at_of(id)
	var out := []
	for other: String in carriers + v.thing_facts.keys():
		if other == id or out.has(other) or not is_thing(other):
			continue
		var there: Array = at_of(other)
		if Vector2(here[0], here[1]).distance_to(Vector2(there[0], there[1])) * 10.0 <= SPREAD_DM:
			out.append(other)
	out.sort()
	return out


## Burning people set the things they stand against alight. fires: [{at [x, z], deed, heat}] (a person's burning fact).
static func exposed(v: S.Village, fires: Array, carriers: Array) -> Array:
	var out := []
	for f: Dictionary in fires:
		var here := Vector2(float(f.at[0]), float(f.at[1]))
		for id: String in carriers:
			var there: Array = at_of(id)
			if here.distance_to(Vector2(there[0], there[1])) * 10.0 <= REACH_DM and catches(v, id):
				ignite(v, id, str(f.deed), int(f.get("heat", HEAT)) * 9 / 10)
				out.append({"kind": "burning", "subject": id, "cause_id": str(f.deed)})
	return out


## Whether any burning person stands against a thing that would catch (a cheap check before a batch).
static func reaches(v: S.Village, fires: Array, carriers: Array) -> bool:
	for f: Dictionary in fires:
		for id: String in carriers:
			var there: Array = at_of(id)
			if Vector2(float(f.at[0]), float(f.at[1])).distance_to(Vector2(there[0], there[1])) * 10.0 <= REACH_DM and catches(v, id):
				return true
	return false


## Rain on every thing standing out of doors: soaks them (and puts out fires).
static func rain(v: S.Village, roots: Dictionary, carriers: Array, deed: String) -> Array:
	var out := []
	for id: String in carriers:
		var r := prepare(v, roots, {"action_id": "%s:%s" % [deed, id], "actor": "weather", "target": id, "verb": "extinguish",
			"parameters": {"method": "rain"}}, {"distance_dm": 0, "water_contact": true})
		if r.accepted:
			out.append(id)
	return out
