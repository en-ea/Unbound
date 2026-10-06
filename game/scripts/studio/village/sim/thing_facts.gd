extends RefCounted
## Facts for things (desk 5 Oct, Hilmi: "Yes, fire & damage on things"): the state home and its save. Body decides what
## sets them and calls these functions from inside acceptance, the same route as people's body facts; Foundations owns
## where they live, their stable keys, their save and the image's coverage. Graphics S4 (render/thing_state.gd) reads them.
##
## Village.thing_facts {thing_id: {kind: row}}. thing_id is "<kind>@<x dm>,<z dm>", the carrier's kind (desk 5 Oct, 19:12).
## row {kind, deed, revision, since_tick, until_tick?, due_tick?, ...the kind's own fields}. due_tick: a rule's own next
## moment (a fire's scorch step, its spread), set by Body's rules; next_due sees it and advance reports it, the row kept:
##   burning  {heat, until_tick}        timed: erased by advance() when due
##   scorched {level}                   lasting
##   soaked   {method, until_tick}      timed
##   struck   {from, force, n}          short-lived: until_tick since_tick + STRUCK_MS when not given; never kept over a load
##   broken   {by}                      lasting
## Heat, level and force 0..1000; ticks are People.tick (active milliseconds). A thing with no facts has no entry.
## Every write names the field to the save image (touch_field), so a batch that names fields still compares it and the
## guard checks it exactly.
const People := preload("res://scripts/studio/village/sim/people.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const FIELD := "thing_facts"
const KINDS := {"burning": ["heat", "until_tick"], "scorched": ["level"], "soaked": ["method", "until_tick"],
	"struck": ["from", "force", "n"], "broken": ["by"]}
const LASTING := ["burning", "scorched", "soaked", "broken"]   # kept over a load (burning and soaked until their tick)
const TIMED := ["burning", "soaked", "struck"]
const STRUCK_MS := 1000
const MAX_THINGS := 4096


static func valid_id(thing_id: String) -> bool:
	var at := thing_id.rfind("@")
	if at <= 0 or thing_id.length() > 96:
		return false
	var xz := thing_id.substr(at + 1).split(",")
	return xz.size() == 2 and xz[0].is_valid_int() and xz[1].is_valid_int()


## The id of a thing at a world position (metres), as the scan names it.
static func id_at(kind: String, x: float, z: float) -> String:
	return "%s@%d,%d" % [kind, roundi(x * 10.0), roundi(z * 10.0)]


static func get_fact(v: S.Village, thing_id: String, kind: String) -> Dictionary:
	return v.thing_facts.get(thing_id, {}).get(kind, {})


## Sets one fact (inside acceptance). `fields` carries the kind's own fields; the row's revision counts its writes.
## Returns the row, or {} when the id, kind or fields are not the agreed shape (nothing is written then).
static func put(v: S.Village, thing_id: String, kind: String, deed: String, fields: Dictionary) -> Dictionary:
	if not valid_id(thing_id) or not KINDS.has(kind) or deed.is_empty():
		return {}
	if not v.thing_facts.has(thing_id) and v.thing_facts.size() >= MAX_THINGS:
		return {}
	var now := People.tick(v)
	var row := fields.duplicate(true)
	if kind == "struck" and not row.has("until_tick"):
		row.until_tick = now + STRUCK_MS
	for key: String in KINDS[kind]:
		if not row.has(key):
			return {}
	VillageImage.touch_field(FIELD)
	var facts: Dictionary = v.thing_facts.get_or_add(thing_id, {})
	var before: Dictionary = facts.get(kind, {})
	row.merge({"kind": kind, "deed": deed, "revision": int(before.get("revision", 0)) + 1, "since_tick": now}, true)
	facts[kind] = row
	return row


## Ends one fact (inside acceptance); false when there was none.
static func clear(v: S.Village, thing_id: String, kind: String) -> bool:
	var facts: Dictionary = v.thing_facts.get(thing_id, {})
	if not facts.has(kind):
		return false
	VillageImage.touch_field(FIELD)
	facts.erase(kind)
	if facts.is_empty():
		v.thing_facts.erase(thing_id)
	return true


## The earliest tick a timed fact ends or a row's due_tick comes; max int when none waits.
static func next_due(v: S.Village) -> int:
	var due := 9223372036854775807
	for thing_id: String in v.thing_facts:
		var facts: Dictionary = v.thing_facts[thing_id]
		for kind: String in facts:
			var row: Dictionary = facts[kind]
			if TIMED.has(kind):
				due = mini(due, int(row.until_tick))
			if row.has("due_tick"):
				due = mini(due, int(row.due_tick))
	return due


## Erases the timed facts that are due (inside acceptance, in the batch that advances the clock). Returns
## [{thing, kind, row, ended}] for each one ended (ended true) so Body's rules can follow on (burning ended -> scorched),
## and for each kept row whose due_tick has come (ended false): the rule then moves or clears its due_tick with put().
static func advance(v: S.Village) -> Array:
	var out := []
	if next_due(v) > People.tick(v):
		return out
	var now := People.tick(v)
	for thing_id: String in v.thing_facts.keys():
		var facts: Dictionary = v.thing_facts[thing_id]
		for kind: String in facts.keys():
			var row: Dictionary = facts[kind]
			if TIMED.has(kind) and now >= int(row.until_tick):
				out.append({"thing": thing_id, "kind": kind, "row": row, "ended": true})
				clear(v, thing_id, kind)
			elif row.has("due_tick") and now >= int(row.due_tick):
				out.append({"thing": thing_id, "kind": kind, "row": row, "ended": false})
	return out


## At load, before the image binds: drops what a load never keeps (struck; a row not in the agreed shape) and returns
## how many rows went. Disk may still hold them until the next save; the image is bound to the village as loaded.
static func at_load(v: S.Village) -> int:
	var dropped := 0
	for thing_id: Variant in v.thing_facts.keys():
		var facts: Variant = v.thing_facts[thing_id]
		if not thing_id is String or not valid_id(thing_id) or not facts is Dictionary:
			v.thing_facts.erase(thing_id)
			dropped += 1
			continue
		for kind: Variant in (facts as Dictionary).keys():
			var row: Variant = facts[kind]
			var keep: bool = kind is String and LASTING.has(kind) and row is Dictionary and row.get("kind") == kind
			if keep:
				for key: String in KINDS[kind] + ["deed", "revision", "since_tick"]:
					keep = keep and row.has(key)
			if not keep:
				facts.erase(kind)
				dropped += 1
		if (facts as Dictionary).is_empty():
			v.thing_facts.erase(thing_id)
	return dropped
