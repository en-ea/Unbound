extends RefCounted
## Enea's own characters (Wren, Brakk, Morrow, the Moss-Cap Seeker) as residents of the live village: the rules
## know them, so they can witness what happens near where they stand, report it to the house that was wronged,
## and remember the player. Their stories stay Enea's and are protected: they never commit a deed, are never
## a victim, a suspect, a scapegoat or a spouse, never grow old or die, and hold no village office. Their bodies,
## walks and talk stay his (world/npc.gd, state/npcs.gd, state/quests.gd); the village's own presentation never
## makes a body for them.
##
##   join(v)            once per live village (runtime.gd attach, and old saves on load): adds any missing
##   rebuild_places(v)  after a save is decoded: re-adds their spots as places, in the saved order, where the table
##                      has them now
##
## Who they are to the rules mirrors Enea's Npcs.NPCS (name, where they stand: "at" in metres). The rules cannot
## read Npcs itself (it pulls in the game's autoloads, which headless checks do not have); live.gd checks at
## runtime that this table and Npcs.NPCS still agree and says so if Enea moves someone.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")

## id -> [name, x metres, z metres, sex (0 man, 1 woman), age in years, role]
const PEOPLE := {
	"wren": ["Wren", -2.6, 18.0, 0, 52, "grower"],
	"morrow": ["Morrow", -1.5, 25.5, 0, 44, "wanderer"],
	"brakk": ["Brakk", -10.8, 7.2, 0, 60, "smith"],      # (moved clear of the smithy site: npcs.gd's studio line)
	"seeker": ["Moss-Cap", 11.5, -3.0, 1, 30, "seeker"],
}


static func join(v: S.Village) -> void:
	var known: Array = v.runtime.get_or_add("authored", [])
	var have := {}
	for entry: Dictionary in known:
		have[entry.id] = true
	for id: String in PEOPLE:
		if have.has(id):
			continue
		var row: Array = PEOPLE[id]
		var entry := {"id": id, "x": int(round(float(row[1]) * 10.0)), "z": int(round(float(row[2]) * 10.0))}
		known.append(entry)
		_add_spot(v, entry)
		_add_person(v, id, row)


static func rebuild_places(v: S.Village) -> void:
	for entry: Dictionary in v.runtime.get("authored", []):
		_add_spot(v, entry)


static func _add_spot(v: S.Village, entry: Dictionary) -> void:
	if v.place_ids.has("spot_" + entry.id):
		return
	var x := int(entry.x)
	var z := int(entry.z)
	if PEOPLE.has(entry.id):     # where the table has them now: a stand moved since a save (Brakk's, 2 Oct) follows
		x = int(round(float(PEOPLE[entry.id][1]) * 10.0))
		z = int(round(float(PEOPLE[entry.id][2]) * 10.0))
	Village._add_place(v, "spot_" + entry.id, x, z, true)


static func _add_person(v: S.Village, id: String, row: Array) -> void:
	# their own household (nothing in it to steal) in one lineage for the story's people
	var lineage := -1
	for l in v.lineages:
		if l.name == "of the story":
			lineage = l.id
	if lineage < 0:
		var l := S.Lineage.new()
		l.id = v.lineages.size()
		l.name = "of the story"
		v.lineages.append(l)
		lineage = l.id
	var h := S.Household.new()
	h.id = v.households.size()
	h.lineage = lineage
	h.home = "spot_" + id
	h.home_place = Village.place_id(v, h.home)
	h.food = 0
	h.geese = 0
	v.households.append(h)
	var pid := Village.add_person(v, h.id, int(row[3]), int(row[4]), -1, -1, {"name": str(row[0]), "quiet": true})
	var p := v.people[pid]
	p.authored = id
	p.role = str(row[5])
	p.plan = PackedInt32Array([0, Village.DAY, h.home_place])


static func is_authored(p: S.Person) -> bool:
	return p.authored != ""


## In the running game: does this table still match Enea's Npcs.NPCS? -> the differences (empty when it does).
static func drift(npcs: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in npcs:
		if not PEOPLE.has(id):
			out.append("%s is new in Npcs (not yet a resident)" % id)
			continue
		var at: Vector2 = npcs[id]["at"]
		var row: Array = PEOPLE[id]
		if absf(at.x - float(row[1])) > 0.5 or absf(at.y - float(row[2])) > 0.5:
			out.append("%s moved to %s" % [id, at])
	return out