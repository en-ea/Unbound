extends RefCounted
## Enea's residents and tenants as people of the live village (Mind's port, plan/MIND-PORT-PLAN-2026-10-06.md). By
## ownership (desk, 6 Oct): village membership is Foundations' (this file), their stance is Mind's
## (people/port_stance.gd). Unlike authored.gd's story characters they are ordinary people: they can be struck, shoved,
## helped and given gifts like anyone, and they live in his houses (his house index -> the village's home of that
## model, world/village.gd HOUSES). His own data (state/residents.gd, state/lettings.gd, their words, goods and rent)
## stays his; Mind's adapter reads these records.
##
##   join(v)            once per live village (runtime.gd attach, and old saves on load), while the switch is on:
##                      adds any of the seven still missing, each in its own household (Nell with her mother Elsa),
##                      then Mind's upgrade (his saved liking -> the stance, once per resident) and tenant presence.
##                      His Residents and Lettings load before the village (save_game.gd), so both read his save.
##   person_of(v, id)   his id -> the person's index (-1 when not joined); marker runtime.ported [{id, person}]
##   held(v, p)         the one rule the life-course drivers read (marriage, elder and priest, natural death, the
##                      culprit and the cases filed): Enea's authored characters (Wren, Brakk) only. His seven join
##                      the full village life (Hilmi, 6 Oct: "be creative with eneas villagers, apparently he
##                      doesn't care too much about them"); Nell stays protected as a child by the rules' own ages.
##   keeps_house(v, pid) one of his seven: they keep the house his world gives them (his doors, shops and lettings),
##                      so a marriage brings the spouse to them, and two of his seven do not marry each other.
##   enabled()          the switch: project setting studio/people/port_enea_residents (off when absent), or the dev
##                      argument --port-residents=on|off. Off: nothing joins, so his npc.gd bodies stay the only ones
##                      until Mind's port routes their presentation; Mind turns it on with the port.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const PORT_STANCE := "res://scripts/studio/people/port_stance.gd"   # loaded when used (it preloads this file)
const SETTING := "studio/people/port_enea_residents"
## id -> [name, sex (0 man, 1 woman), age in years, his trade (for Mind; the village's role comes from its own rules),
## his house index, mother's id or ""]. Names and houses are his
## (state/npcs.gd: "resident" house; Lettings.TENANTS); sex and age are the studio's reading of his titles and looks,
## a proposal Mind may change.
const PEOPLE := {
	"tomas": ["Tomas", 0, 38, "woodcutter", 0, ""],
	"bram": ["Bram", 0, 45, "miller", 1, ""],
	"elsa": ["Elsa", 1, 34, "cook", 2, ""],
	"nell": ["Nell", 1, 9, "child", 2, "elsa"],
	"tenant_odo": ["Odo", 0, 66, "tenant", 3, ""],
	"tenant_mira": ["Mira", 1, 29, "tenant", 4, ""],
	"tenant_fen": ["Fen", 0, 31, "tenant", 6, ""],
}
## His house index -> the village home it is (the model's name: house_cottage.glb -> "cottage").
const HOUSE_HOME := {0: "cottage", 1: "cabin", 2: "round", 3: "hill", 4: "lodge", 6: "loaf"}


static func enabled() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--port-residents=on":
			return true
		if arg == "--port-residents=off":
			return false
	return bool(ProjectSettings.get_setting(SETTING, false))


static func join(v: S.Village) -> void:
	if not enabled() or v.runtime.is_empty():
		return
	var known: Array = v.runtime.get_or_add("ported", [])     # [{id: his id, person: index}]
	for id: String in PEOPLE:
		if person_of(v, id) >= 0:
			continue
		var row: Array = PEOPLE[id]
		var home: String = HOUSE_HOME[int(row[4])]
		var mother := person_of(v, str(row[5])) if str(row[5]) != "" else -1
		var household := v.people[mother].household if mother >= 0 else _household(v, home)
		var pid := Village.add_person(v, household, int(row[1]), int(row[2]), -1, mother, {"name": str(row[0]), "quiet": true})
		v.people[pid].plan = PackedInt32Array([0, Village.DAY, v.households[household].home_place])
		known.append({"id": id, "person": pid})
	var stance: Script = load(PORT_STANCE)
	stance.upgrade(v)          # Mind: his saved liking becomes the stance once per resident (runtime.port_liking)
	stance.sync_presence(v)    # Mind: a tenant is present only while his house is let (runtime.port_unhoused)


static func _household(v: S.Village, home: String) -> int:
	var h := S.Household.new()
	h.id = v.households.size()
	var l := S.Lineage.new()                  # each of his households is its own family to the rules
	l.id = v.lineages.size()
	l.name = "of " + home
	l.age = v.age
	v.lineages.append(l)
	h.lineage = l.id
	h.home = home
	h.home_place = Village.place_id(v, home)
	h.food = 40
	h.geese = 0
	v.households.append(h)
	return h.id


static func person_of(v: S.Village, id: String) -> int:
	if v == null or v.runtime.is_empty():
		return -1
	for entry: Dictionary in v.runtime.get("ported", []):
		if str(entry.id) == id:
			return int(entry.person)
	return -1


static func is_ported(id: String) -> bool:
	return PEOPLE.has(id)


static func held(_v: S.Village, p: S.Person) -> bool:
	return p.authored != ""


static func keeps_house(v: S.Village, pid: int) -> bool:
	if v.runtime.is_empty():
		return false
	for entry: Dictionary in v.runtime.get("ported", []):
		if int(entry.person) == pid:
			return true
	return false
