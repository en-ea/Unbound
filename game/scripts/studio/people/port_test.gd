extends RefCounted
## Mind port, unit 1: Enea's seven meadow residents and tenants, joined by Foundations (sim/ported.gd), hold his saved
## liking as the stance's gift tally once (port_stance.gd), and gifts and harm move what his rules will read.
## Rules level, no bodies.
##   godot --headless --path game --script res://scripts/studio/run.gd -- people/port_test --port-residents=on
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const P := preload("res://scripts/studio/people/perception.gd")
const Ported := preload("res://scripts/studio/people/port_stance.gd")
const Join := preload("res://scripts/studio/village/sim/ported.gd")
const Rent := preload("res://scripts/studio/people/rent.gd")
const ThingFacts := preload("res://scripts/studio/village/sim/thing_facts.gd")
const Temperament := preload("res://scripts/studio/people/temperament.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const Gift := preload("res://scripts/studio/people/sources/gift.gd")
const PLAYER := "player:local"


static func check(out: PackedStringArray, ok: bool, description: String) -> void:
	out.append(("PASS" if ok else "FAIL") + " port " + description)


## The player's act on a villager, as the one it touched feels it (or a witness sees it).
static func felt(v, observer: String, target: String, record: Dictionary, deed: String, seen := false) -> Dictionary:
	record.deed = deed
	record.tick = People.tick(v)
	var sensor := {"seen_event": true, "seen_actor": true, "seen_subject": true, "tick": People.tick(v), "captured_tick": People.tick(v),
		"occurred_tick": People.tick(v), "due": People.tick(v), "gain": 1.0, "subject_identity": {"key": target, "name": "them"}}
	if seen:
		sensor.seen = true
	return P.account(observer, record, sensor, {"key": PLAYER, "name": "you"}, deed + ":" + observer)


static func gift(v, pid: int, deed: String, worth: int, observer := "") -> Dictionary:
	var target := People.key(v, pid)
	var fields := {"item": "apple", "count": 1}
	if worth >= 0:
		fields.worth = worth
	return felt(v, target if observer.is_empty() else observer, target, Gift.new().make(PLAYER, target, [0.0, 0.0], fields), deed)


static func strike(v, pid: int, deed: String) -> Dictionary:
	var target := People.key(v, pid)
	var record := {"kind": "contact", "source": PLAYER, "actor": PLAYER, "target": target, "subject": target, "at": [0.0, 0.0],
		"strength": 480, "evidence": {"act": "strike"}, "features": {"harm": 480, "threat": 480, "novelty": 200}}
	return felt(v, target, target, record, deed)


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	# His save as the game loads it, before the village (save_game.gd): the join then upgrades from it (the real path).
	var saved := {"tomas": 3, "elsa": 0, "nell": 1, "bram": 7}       # his saved Residents.liking
	var tree := Engine.get_main_loop() as SceneTree
	var residents: Node = tree.root.get_node("Residents")
	var lettings: Node = tree.root.get_node("Lettings")
	for id: String in saved:
		residents.liking[id] = saved[id]
	lettings.owned = {3: 1}                                          # he owns Hill House: Odo lives there
	var v: Runtime.S.Village = Runtime.create(16838, {"anchored": true})
	var tomas: Object = Ported.person(v, "tomas")
	var elsa: Object = Ported.person(v, "elsa")
	var all_ported := Join.PEOPLE.keys().all(func(id: String) -> bool:
		var p: Object = Ported.person(v, id)
		return p != null and p.authored == "" and p.alive and p.mind.temperament in ["common", "gruff", "weary"])
	check(out, Join.enabled() and all_ported and v.runtime.port_liking.size() == 7,
		"the seven are ordinary villagers with a mind each (Foundations' join, switch on), upgraded at the join")
	check(out, not Ported.person(v, "tenant_odo").present and not Ported.person(v, "tenant_mira").present and not Ported.person(v, "tenant_fen").present
		and not Ported.family(v, 3).is_empty() and Ported.person(v, "hesk") == null and Ported.person(v, "wren") == null,
		"his tenants stay away, his house owned or not (merge-fix: the house's village family are its tenants, %d in Hill House); hesk and the authored are not ported" % Ported.family(v, 3).size())
	# The save upgrade: his liking L is read back as L exactly, and nothing else is invented.
	var exact := saved.keys().all(func(id: String) -> bool: return Ported.liking(v, id) == int(saved[id]))
	var invented := Join.PEOPLE.keys().any(func(id: String) -> bool:
		var m: Object = Ported.person(v, id).mind
		return not m.known.is_empty() or not m.appraised.is_empty() or not m.episodes.is_empty() or not m.pending.is_empty())
	check(out, exact and not invented and not elsa.mind.stances.has(PLAYER) and Ported.gifts(v, "bram") == 7
		and Ported.toward_player(v, "bram").feeling == 0,
		"saved liking becomes the stance's gift tally once: liking equal before and after, no memory, receipt or deed invented")
	var count := v.people.size()
	check(out, Ported.upgrade(v, {"tomas": 99}) == 0 and v.people.size() == count and Ported.liking(v, "tomas") == 3
		and v.runtime.port_liking.size() == 7,
		"the upgrade is once per resident: runtime.port_liking stops a second conversion (his liking field is frozen)")
	# The codec keeps the people, the marker and the tally.
	var loaded = Codec.from_data(Codec.to_data(v, false))
	check(out, loaded != null and loaded.people.size() == count and loaded.runtime.port_liking == v.runtime.port_liking and loaded.runtime.ported == v.runtime.ported
		and saved.keys().all(func(id: String) -> bool: return Ported.liking(loaded, id) == int(saved[id]))
		and not Ported.person(loaded, "tenant_mira").present and People.invalid(loaded) == "",
		"a save round trip keeps the seven, the marker, presence and every liking")
	# A gift through acceptance's learn: the one handed it counts it once; a witness counts nothing.
	var t := int(tomas.id)
	People.learn(v, gift(v, t, "deed:g1", 2), null, false)
	var after_one := Ported.liking(v, "tomas")
	People.learn(v, gift(v, t, "deed:g1", 2), null, false)
	var witness := int(Ported.person(v, "bram").id)
	People.learn(v, felt(v, People.key(v, witness), People.key(v, t), Gift.new().make(PLAYER, People.key(v, t), [0.0, 0.0],
		{"item": "apple", "count": 1, "worth": 2}), "deed:g1", true), null, false)
	People.learn(v, gift(v, t, "deed:g2", 1), null, false)
	check(out, after_one == 5 and Ported.gifts(v, "tomas") == 6 and Ported.liking(v, "tomas") == 6 and Ported.gifts(v, "bram") == 7
		and Ported.toward_player(v, "tomas").trust > 0,
		"a loved gift adds 2 and another 1, once per deed; trust still comes from appraisal; a witness's tally is unchanged (tomas %d)" % Ported.liking(v, "tomas"))
	# Harm lowers what his rules read; the tally itself is never taken away.
	var b := int(Ported.person(v, "bram").id)
	People.learn(v, strike(v, b, "deed:s1"), null, false)
	var row := Ported.toward_player(v, "bram")
	check(out, int(row.feeling) < 0 and row.gifts == 7 and row.hits == 1 and Ported.liking(v, "bram") == maxi(0, 7 + int(row.feeling) / 100)
		and Ported.liking(v, "bram") < 7,
		"a blow sours the stance and lowers liking (feeling %d -> liking %d), the gift tally kept" % [row.feeling, Ported.liking(v, "bram")])
	# An ordinary villager's gift (no worth) leaves the stance shape as it was.
	var other := -1
	for p in v.people:
		if p.alive and p.present and p.authored == "" and not v.runtime.ported.any(func(e: Dictionary) -> bool: return int(e.person) == p.id) and Village.age_of(v, p) >= 18:
			other = p.id
			break
	People.learn(v, gift(v, other, "deed:g3", -1), null, false)
	check(out, other >= 0 and v.people[other].mind.stances.has(PLAYER) and not v.people[other].mind.stances[PLAYER].has("gifts")
		and not v.people[other].mind.appraised["deed:g3:" + People.key(v, other)].has("gifted"),
		"an unported villager's gift adds no tally and no receipt field (existing records unchanged)")
	# His tenants stay away whatever is owned; a family that moves out is away until its day, and only those it took.
	Ported.sync_presence(v, {3: 1, 4: 2, 6: 1})
	var his_away := not Ported.person(v, "tenant_mira").present and not Ported.person(v, "tenant_odo").present and not Ported.person(v, "tenant_fen").present
	var hill_family: Array = Ported.family(v, 3)
	var took: Array = hill_family.slice(0, maxi(1, hill_family.size() - 1))   # (one stayed behind, as one out at the time would)
	v.runtime.get_or_add("port_left", {})["house:3"] = {"back": v.day + 3, "pids": took}
	Ported.sync_families(v)
	var gone := took.all(func(pid: int) -> bool: return not v.people[pid].present)
	var stayed := hill_family.size() < 2 or v.people[hill_family.back()].present
	var paid_away := Rent.pays(v, 3)
	v.runtime.port_left["house:3"].back = v.day
	Ported.sync_families(v)
	var back := took.all(func(pid: int) -> bool: return v.people[pid].present)
	v.runtime.port_left.erase("house:3")
	check(out, his_away and gone and stayed and not paid_away and back and Rent.pays(v, 3),
		"his tenants stay away; a family that moves out takes only its own away, pays nothing while gone, and comes back on its day")
	# The rent rule: his contentment, moved by the family's mean feeling toward the player and by harm to the home.
	var grown: Array = Ported.family(v, 3).filter(func(pid: int) -> bool: return Village.age_of(v, v.people[pid]) >= 14)
	var hill := Vector2(12.5, 26.5)
	var calm := Rent.mood(v, 3, hill, 70)
	People.learn(v, strike(v, int(grown[0]), "deed:s2"), null, false)
	var feeling := Rent.feeling(v, 3)
	var struck_one := int(People.stance_view(v.people[grown[0]].mind, People.tick(v), [PLAYER]).get(PLAYER, {}).get("feeling", 0))
	var soured := Rent.mood(v, 3, hill, 70)
	ThingFacts.put(v, ThingFacts.id_at("house", hill.x, hill.y), "broken", "deed:b1", {"by": PLAYER})
	var broken := Rent.mood(v, 3, hill, 70)
	ThingFacts.put(v, ThingFacts.id_at("house", hill.x, hill.y), "burning", "deed:f1", {"heat": 600, "until_tick": People.tick(v) + 5000})
	var burning := Rent.mood(v, 3, hill, 70)
	check(out, calm == 70 and feeling < 0 and feeling == struck_one / grown.size() and soured == 70 + feeling / 10 and broken == soured - 25
		and burning == maxi(0, soured - 40) and Rent.mood(v, 3, hill, 5) == 0 and Rent.pays(v, 3),
		"rent mood: contentment 70, one of the %d grown of the family struck (%d, the family's mean %d) -> %d, a broken home -25 -> %d, burning -40 -> %d, never below 0" % [grown.size(), struck_one, feeling, soured, broken, burning])
	Ported.upgrade(v, {})
	check(out, tomas.role == "woodcutter" and Ported.person(v, "bram").role == "miller" and elsa.role == "merchant"
		and Ported.person(v, "tenant_odo").role == "gatherer",
		"the rules' roles from his titles (desk 03:10): woodcutter, miller, merchant, gatherer")
	# Who they are (the creative unit): traits, temperaments and ties, written once with the upgrade.
	var bram: Object = Ported.person(v, "bram")
	var odo_p: Object = Ported.person(v, "tenant_odo")
	var friends := 0
	for q in v.people:
		if q.role == "woodcutter" and q.id != tomas.id and Village.opinion(v, tomas.id, q.id) == 60 and Village.opinion(v, q.id, tomas.id) == 60:
			friends += 1
	check(out, tomas.mind.temperament == "gruff" and odo_p.mind.temperament == "gruff" and bram.mind.temperament == "weary"
		and elsa.mind.temperament == "common" and tomas.traits[C.BOLD] == 78 and tomas.traits[C.TEMPER] == 74 and bram.traits[C.ALERT] == 30
		and v.runtime.port_who.size() == 7,
		"who they are: Tomas and Odo gruff, Bram weary, traits from his descriptions (Tomas bold 78, temper 74; Bram alert 30)")
	check(out, Village.opinion(v, bram.id, tomas.id) == 60 and Village.opinion(v, tomas.id, bram.id) == 60 and friends == 1,
		"ties: Bram and Tomas old friends, Tomas the friend of a village woodcutter")
	var me := {"courage": 78, "temper": 74, "alert": 45, "safety": 500, "hits": 0, "concern": 0}
	var common := Temperament.resolve(me, "common")
	var gruff := Temperament.resolve(me, "gruff")
	var weary := Temperament.resolve(me, "weary")
	check(out, int(gruff.fear_gain) < int(common.fear_gain) and int(gruff.anger_gain) > int(common.anger_gain)
		and int(gruff.resentment_rate) < int(common.resentment_rate) and int(weary.anger_gain) < int(common.anger_gain)
		and int(weary.anger_rate) < int(common.anger_rate),
		"the gruff fear less, anger more and hold a grudge longer; the weary anger less and let it go slower (fear gain %d/%d, anger rate %d/%d)" % [gruff.fear_gain, common.fear_gain, weary.anger_rate, common.anger_rate])
	return out
