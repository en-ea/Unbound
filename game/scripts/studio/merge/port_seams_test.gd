extends RefCounted
## The Foundations seams for Mind's port of Enea's residents and tenants (desk, 6 Oct), headless:
##   godot --headless --path game --script res://scripts/studio/run.gd -- merge/port_seams_test --port-residents=on
## The join (sim/ported.gd, behind its switch; Mind's stance upgrade follows it): his seven as ordinary people in his houses, Nell
## with her mother Elsa, none authored, kept through a save, never twice. The rule (sim/ported.gd held): only the authored are
## out of the life-course drivers; his seven join the full village life (Hilmi, 6 Oct), and each of them keeps the house his
## world gives them through a marriage. The drift (sim/authored.gd): his out-of-region
## characters read "another region", his residents and tenants are not reported. The anchors (village/sites.gd):
## each of his day places clear of his buildings. The gift act is checked live (port_gift_check.gd).
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const Ported := preload("res://scripts/studio/village/sim/ported.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Authored := preload("res://scripts/studio/village/sim/authored.gd")
const Sites := preload("res://scripts/studio/village/sites.gd")
const Houses := preload("res://scripts/world/village.gd")


static func check(out: PackedStringArray, ok: bool, text: String) -> void:
	out.append(("PASS" if ok else "FAIL") + " port-seams " + text)


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	check(out, Ported.enabled(), "the switch is on for this run (--port-residents=on)")
	var v := Runtime.create(7)
	Runtime.attach(v, 432)
	var ids := {}
	for id: String in Ported.PEOPLE:
		ids[id] = Ported.person_of(v, id)
	var all_in: bool = ids.values().all(func(i: int) -> bool: return i >= 0)
	check(out, all_in and ids.size() == 7, "his seven join as people (%s)" % str(ids))
	if not all_in:
		return out
	var homes_ok := true
	for id: String in Ported.PEOPLE:
		var p = v.people[ids[id]]
		var want: String = Ported.HOUSE_HOME[int(Ported.PEOPLE[id][4])]
		homes_ok = homes_ok and v.households[p.household].home == want and p.authored == "" and p.name == Ported.PEOPLE[id][0]
	check(out, homes_ok, "each lives in his house (cottage, cabin, round, hill, lodge, loaf), by his name, not authored")
	var nell = v.people[ids["nell"]]
	check(out, nell.mother == ids["elsa"] and nell.household == v.people[ids["elsa"]].household, "Nell lives with her mother Elsa")
	var n := v.people.size()
	var back := Codec.from_data(JSON.parse_string(JSON.stringify(Codec.to_data(v, true))))
	Ported.join(back)
	check(out, back != null and back.people.size() == n and Ported.person_of(back, "tomas") == ids["tomas"], "kept through a save; joining again adds no one")
	# The rule: only the authored are held; his seven live the village's life (Hilmi, 6 Oct).
	var authored := v.people.filter(func(p) -> bool: return p.authored != "")
	var held_ok: bool = not authored.is_empty() and authored.all(func(p) -> bool: return Ported.held(v, p)) \
		and ids.values().all(func(i: int) -> bool: return not Ported.held(v, v.people[i]))
	v.people[ids["tomas"]].born = -80 * Village.YEAR     # the oldest man of the village
	Village.elect_authorities(v)
	var elected: bool = v.authority == ids["tomas"] or v.people[ids["tomas"]].role == "elder"
	# Marriages over a season: a tenant who marries keeps the house he lets them; two tenants never marry each other.
	var homes := {}
	for id: String in Ported.PEOPLE:
		homes[id] = v.people[ids[id]].household
	for _d in 120:
		v.day += 1
		Village.marriages(v)
	var tenants_home := true
	var wed := []
	for id: String in homes:
		var t = v.people[ids[id]]
		tenants_home = tenants_home and t.household == homes[id]
		if t.spouse >= 0:
			wed.append(id)
			tenants_home = tenants_home and v.people[t.spouse].household == t.household and not Ported.keeps_house(v, t.spouse)
	check(out, held_ok and elected and tenants_home,
		"the rule: only the authored are held; his Tomas can be elder; his seven keep their houses through a marriage (wed: %s)" % str(wed))
	# Drift: his characters elsewhere stay his; his residents and tenants are people now.
	var npcs := {"hesk": {"region": "forest", "at": Vector2(-24.5, 12.5)}, "tomas": {"at": Vector2(-4, 1.5)},
		"tenant_odo": {"region": "letting", "at": Vector2.ZERO}, "wren": {"at": Vector2(-2.6, 18.0)}, "newcomer": {"at": Vector2(1, 1)}}
	var lines := Authored.drift(npcs)
	check(out, lines.size() == 2 and lines[0].contains("hesk is in another region") and lines[1].contains("newcomer is new"),
		"drift: Hesk is in another region, his residents and tenants are not reported, a newcomer still is (%s)" % str(lines))
	# Anchors: each day place clear of his buildings.
	var tomas := {"house": 0, "work": Vector2(-4.0, 1.5), "lunch": Vector2(-2.5, 20.5), "evening": Vector2(-6.2, 18.2)}
	var a := Sites.anchors(tomas)
	var clear := true
	for part: String in ["work", "lunch", "evening"]:
		clear = clear and Sites.clear_of_buildings(a[part]) == a[part]
	check(out, a.home == Houses.door_of(0) and clear, "Tomas's day places: home at his door, work, lunch and evening on clear ground (%s)" % str(a))
	return out
