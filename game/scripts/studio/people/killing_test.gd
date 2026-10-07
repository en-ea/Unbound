extends RefCounted
## A witnessed killing (Foundations' "finish" verb: hold Heavy on a downed person, 6 Oct) as Mind appraises it: the
## gravest harm a hand does - fear, and a stance against the killer beyond any blow - and the corpse notice that
## follows (the dead fact, the same deed) joins the same account, so nothing is counted twice.
##   godot --headless --path game --script res://scripts/studio/run.gd -- people/killing_test
const F := preload("res://scripts/studio/people/foundation_state_test.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const P := preload("res://scripts/studio/people/perception.gd")
const Affect := preload("res://scripts/studio/people/affect.gd")
const Contact := preload("res://scripts/studio/people/sources/contact.gd")
const Settle := preload("res://scripts/studio/people/offers/settle.gd")
const BeatOut := preload("res://scripts/studio/people/offers/beat_out.gd")
const Fire := preload("res://scripts/studio/people/sources/fire.gd")
const Burning := preload("res://scripts/studio/people/sources/burning.gd")
const HelpFire := preload("res://scripts/studio/people/offers/help_fire.gd")
const Help := preload("res://scripts/studio/people/sources/help.gd")
const Death := preload("res://scripts/studio/people/sources/death.gd")
const PLAYER := "player:local"


static func check(out: PackedStringArray, ok: bool, description: String) -> void:
	out.append(("PASS" if ok else "FAIL") + " killing " + description)


static func seen(v, observer: String, record: Dictionary, deed: String, target: String, aftermath := false) -> Dictionary:
	record.deed = deed
	record.tick = People.tick(v)
	var sensor := {"seen_event": true, "seen_actor": true, "seen_subject": true, "tick": People.tick(v), "captured_tick": People.tick(v),
		"occurred_tick": People.tick(v), "due": People.tick(v), "gain": 1.0, "subject_identity": {"key": target, "name": "them"}}
	if aftermath:
		sensor.aftermath = true
	return P.account(observer, record, sensor, {"key": PLAYER, "name": "you"}, deed + ":" + observer)


static func adults(v, n: int) -> Array:
	var out := []
	for p in v.people:
		if p.alive and p.present and p.authored == "" and preload("res://scripts/studio/village/sim/village.gd").age_of(v, p) >= 18:
			out.append(p.id)
			if out.size() == n:
				break
	return out


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var v = F.fixture()
	var ids := adults(v, 3)
	var victim := People.key(v, ids[0])
	var witness := People.key(v, ids[1])
	var other := People.key(v, ids[2])
	# The killing, seen.
	var killing := seen(v, witness, Contact.new().make(PLAYER, victim, [0.0, 0.0], {"act": "finish"}), "deed:kill", victim)
	People.learn(v, killing, null, false)
	var m = v.people[ids[1]].mind
	var row: Dictionary = People.stance_view(m, People.tick(v), [PLAYER]).get(PLAYER, {})
	var fear := int(Affect.project(m, People.tick(v)).fear)
	check(out, killing.features.harm == 1000 and int(row.get("hits", 0)) == 1 and int(row.resentment) >= 600 and int(row.wary) >= 600 and fear >= 700,
		"a seen killing is the gravest harm: fear %d, resentment %d, wary %d, trust %d, feeling %d" % [fear, row.resentment, row.wary, row.trust, row.feeling])
	# The corpse, seen after: the dead fact carries the same deed, so it joins that account.
	var before: Dictionary = row.duplicate(true)
	var corpse := seen(v, witness, Death.new().make(victim, victim, [0.0, 0.0], {}), "deed:kill", victim, true)
	People.learn(v, corpse, null, false)
	row = People.stance_view(m, People.tick(v), [PLAYER]).get(PLAYER, {})
	check(out, m.appraised.size() == 1 and m.known.size() == 1 and int(row.hits) == 1 and int(row.resentment) == int(before.resentment)
		and int(row.wary) == int(before.wary) and m.known["deed:kill:" + witness].facets.has("condition:dead"),
		"the corpse notice joins the same account: one receipt, one hit, no second stance (resentment %d -> %d)" % [before.resentment, row.resentment])
	# A heavy blow, for scale: a killing weighs far more.
	var blow := seen(v, other, Contact.new().make(PLAYER, victim, [0.0, 0.0], {"act": "strike", "damage": 5, "heavy": true}), "deed:blow", victim)
	People.learn(v, blow, null, false)
	var struck: Dictionary = People.stance_view(v.people[ids[2]].mind, People.tick(v), [PLAYER]).get(PLAYER, {})
	check(out, int(struck.resentment) * 2 < int(before.resentment) and int(struck.feeling) > int(before.feeling),
		"a heavy blow is far less (resentment %d against %d, feeling %d against %d)" % [struck.resentment, before.resentment, struck.feeling, before.feeling])
	# A corpse alone names no killer.
	var fresh = F.fixture()
	var lone := adults(fresh, 2)
	var found := seen(fresh, People.key(fresh, lone[1]), Death.new().make(People.key(fresh, lone[0]), People.key(fresh, lone[0]), [0.0, 0.0], {}),
		"deed:found", People.key(fresh, lone[0]), true)
	People.learn(fresh, found, null, false)
	check(out, not fresh.people[lone[1]].mind.stances.has(PLAYER) and int(Affect.project(fresh.people[lone[1]].mind, People.tick(fresh)).fear) > 0,
		"a body found alone frightens and names no killer")
	# The Tidecaller (desk 06:10): a hold to drown is a killing; the drowned body joins the same account.
	var w = F.fixture()
	var six := adults(w, 6)
	var drowned := People.key(w, six[0])
	var by_pool := People.key(w, six[1])
	People.learn(w, seen(w, by_pool, Contact.new().make(PLAYER, drowned, [0.0, 0.0], {"act": "hold", "drown": true}), "deed:drown", drowned), null, false)
	People.learn(w, seen(w, by_pool, Death.new().make(drowned, drowned, [0.0, 0.0], {}), "deed:drown", drowned, true), null, false)
	var dm = w.people[six[1]].mind
	var drow: Dictionary = People.stance_view(dm, People.tick(w), [PLAYER]).get(PLAYER, {})
	check(out, dm.appraised.size() == 1 and int(drow.hits) == 1 and int(drow.resentment) >= 700 and int(drow.wary) >= 700 and int(Affect.project(dm, People.tick(w)).fear) >= 700,
		"a seen drowning is a killing: one account with the body, resentment %d, wary %d, fear %d" % [drow.resentment, drow.wary, Affect.project(dm, People.tick(w)).fear])
	# A hold without drowning, and ice: assaults, a blow's weight.
	var held_by := People.key(w, six[2])
	People.learn(w, seen(w, held_by, Contact.new().make(PLAYER, People.key(w, six[0]), [0.0, 0.0], {"act": "hold"}), "deed:hold", People.key(w, six[0])), null, false)
	var froze_by := People.key(w, six[3])
	People.learn(w, seen(w, froze_by, Contact.new().make(PLAYER, People.key(w, six[0]), [0.0, 0.0], {"act": "freeze"}), "deed:freeze", People.key(w, six[0])), null, false)
	var hold_row: Dictionary = People.stance_view(w.people[six[2]].mind, People.tick(w), [PLAYER]).get(PLAYER, {})
	var ice_row: Dictionary = People.stance_view(w.people[six[3]].mind, People.tick(w), [PLAYER]).get(PLAYER, {})
	check(out, int(hold_row.get("hits", 0)) == 1 and int(hold_row.resentment) > 100 and int(hold_row.resentment) < 700
		and int(ice_row.get("hits", 0)) == 1 and int(ice_row.resentment) > 100 and int(ice_row.resentment) < 700,
		"a seen hold and a seen freeze are assaults, a blow's weight (resentment %d and %d)" % [hold_row.resentment, ice_row.resentment])
	# A soaking, and rain that puts out a fire: not harm.
	var wet_by := People.key(w, six[4])
	People.learn(w, seen(w, wet_by, Contact.new().make(PLAYER, People.key(w, six[0]), [0.0, 0.0], {"act": "wet"}), "deed:wet", People.key(w, six[0])), null, false)
	var rained := People.key(w, six[5])
	People.learn(w, seen(w, rained, Help.new().make(PLAYER, rained, [0.0, 0.0], {"method": "rain"}), "deed:rain", rained), null, false)
	var wet_row: Dictionary = People.stance_view(w.people[six[4]].mind, People.tick(w), [PLAYER]).get(PLAYER, {})
	var rain_row: Dictionary = People.stance_view(w.people[six[5]].mind, People.tick(w), [PLAYER]).get(PLAYER, {})
	check(out, int(wet_row.get("hits", 0)) == 0 and int(wet_row.get("resentment", 0)) == 0 and int(rain_row.get("hits", 0)) == 0 and int(rain_row.get("trust", 0)) > 0,
		"a soaking is no harm, and rain that puts out your fire is help (trust %d)" % int(rain_row.get("trust", 0)))
	# What only carries to the ear is voiced as what it was: a killing a scream, water a splash, a bolt thunder; only
	# blows are a scuffle (desk 06:18, 06:20).
	var said := {}
	for heard_row: Array in [["finish", {"act": "finish"}], ["drown", {"act": "hold", "drown": true}], ["wet", {"act": "wet"}],
			["bolt", {"act": "strike", "source": "lightning"}], ["blow", {"act": "strike"}]]:
		var record: Dictionary = Contact.new().make(PLAYER, drowned, [0.0, 0.0], heard_row[1])
		record.deed = "deed:heard:" + str(heard_row[0])
		var ear := P.account(by_pool, record, {"heard": true, "carry": 0.6, "tick": People.tick(w), "due": People.tick(w)}, {"key": PLAYER, "name": "you"}, record.deed + ":" + by_pool)
		said[heard_row[0]] = str(Settle.new().steps({"hits": 0}, ear)[1].text)
	check(out, said.finish.begins_with("That scream") and said.drown.begins_with("That scream") and said.wet.begins_with("What was that splashing")
		and said.bolt.begins_with("Thunder") and said.blow == "Someone is arguing with their fists.",
		"heard, a killing is a scream, a soaking a splash, a bolt thunder, and only a blow a scuffle (%s)" % str(said))
	# A helper the fire spread to: he saw his friend catch fire, then felt the same fire (its deed) on himself. His own
	# flames must still be his to answer (beat_out), though the account is about his friend.
	var helper := People.key(w, six[2])
	var friend_key := People.key(w, six[3])
	People.learn(w, seen(w, helper, Fire.new().make(PLAYER, friend_key, [0.0, 0.0], {"heat": 600}), "deed:spread", friend_key), null, false)
	var on_me: Dictionary = Burning.new().make("", helper, [0.0, 0.0], {"heat": 600})
	on_me.deed = "deed:spread"
	on_me.tick = People.tick(w)
	People.learn(w, P.account(helper, on_me, {"seen": true, "gain": 1.0, "tick": People.tick(w), "due": People.tick(w)}, {"key": "unknown"}, "deed:spread:" + helper), null, false)
	var merged: Dictionary = w.people[six[2]].mind.known.get("deed:spread:" + helper, {})
	check(out, not merged.is_empty() and BeatOut.own_fire({"key": helper}, merged) and BeatOut.new().can({"key": helper}, merged),
		"a helper alight from his friend's fire answers his own flames (the account's target %s, felt facet %s)" % [str(merged.get("target", "")), str(merged.get("facets", {}).keys())])
	# A helper takes in the fire, runs, and beats at the flames for a while before they are out: never in the same
	# moment as the lighting (desk 6 Oct: 12 of 12 Flame Dashes put out before any harm).
	var steps: Array = HelpFire.new().steps({"alert": 50}, {"target": friend_key, "deed": "deed:lit"})
	var before_use := 0.0
	for step: Dictionary in steps:
		if str(step.op) == "use":
			break
		if str(step.op) == "wait":
			before_use += float(step.seconds)
	var alert_steps: Array = HelpFire.new().steps({"alert": 100}, {"target": friend_key, "deed": "deed:lit"})
	var own: Array = BeatOut.new().steps({"key": helper}, {"deed": "deed:lit"})
	check(out, str(steps[0].op) == "wait" and before_use >= 1.5 and str(own[0].op) == "wait" and float(own[0].seconds) >= 0.8 and float(alert_steps[0].seconds) < float(steps[0].seconds),
		"a helper takes in the fire (%.2f s, less when alert) and beats at it before it is out (%.1f s before the use); beating out your own takes %.1f s" % [float(steps[0].seconds), before_use, float(own[0].seconds)])
	# A star over a crowd (people_bridge saturation): what a witness did not take in one by one comes as one summary
	# account, "many fell there" (evidence.many, count). It reads as mass harm, as grave as a killing, not one more burn.
	var crowd = F.fixture()
	var three := adults(crowd, 3)
	var one_burn := seen(crowd, People.key(crowd, three[1]), Fire.new().make(PLAYER, People.key(crowd, three[0]), [0.0, 0.0], {"heat": 750}), "deed:star:a", People.key(crowd, three[0]))
	People.learn(crowd, one_burn, null, false)
	var many_record := Fire.new().make(PLAYER, People.key(crowd, three[0]), [0.0, 0.0], {"heat": 750})
	many_record.evidence.many = true
	many_record.evidence.count = 9
	var many := seen(crowd, People.key(crowd, three[2]), many_record, "deed:star:b", People.key(crowd, three[0]))
	People.learn(crowd, many, null, false)
	var single: Dictionary = People.stance_view(crowd.people[three[1]].mind, People.tick(crowd), [PLAYER]).get(PLAYER, {})
	var mass: Dictionary = People.stance_view(crowd.people[three[2]].mind, People.tick(crowd), [PLAYER]).get(PLAYER, {})
	check(out, int(mass.get("wary", 0)) >= 600 and int(mass.get("resentment", 0)) >= 600 and int(single.get("resentment", 0)) * 2 < int(mass.get("resentment", 0)),
		"\"many fell there\" (a summary of 9) reads as mass harm: wary %d, resentment %d, trust %d - one burn seen: wary %d, resentment %d" % [int(mass.get("wary", 0)),
		int(mass.get("resentment", 0)), int(mass.get("trust", 0)), int(single.get("wary", 0)), int(single.get("resentment", 0))])
	# The aftermath's summary (f317375, "many were helped") carries the same many/count: a rescue never reads as harm.
	var aid_record := Help.new().make(PLAYER, People.key(crowd, three[0]), [0.0, 0.0], {"method": "beat"})
	aid_record.evidence.many = true
	aid_record.evidence.count = 5
	var aid_watcher = F.fixture()
	var two := adults(aid_watcher, 2)
	People.learn(aid_watcher, seen(aid_watcher, People.key(aid_watcher, two[1]), aid_record, "deed:aid", People.key(aid_watcher, two[0])), null, false)
	var aided: Dictionary = People.stance_view(aid_watcher.people[two[1]].mind, People.tick(aid_watcher), [PLAYER]).get(PLAYER, {})
	var meaning := str(aid_watcher.people[two[1]].mind.appraised.get("deed:aid:" + People.key(aid_watcher, two[1]), {}).get("meaning", {}).get("name", ""))
	check(out, int(aided.get("wary", 0)) <= 0 and int(aided.get("resentment", 0)) <= 0 and int(aided.get("trust", 0)) > 0 and meaning == "received help",
		"\"many were helped\" (a help summary of 5) reads as help, never harm: wary %d, resentment %d, trust %d, obligation %d, meaning %s" % [int(aided.get("wary", 0)),
		int(aided.get("resentment", 0)), int(aided.get("trust", 0)), int(aided.get("obligation", 0)), meaning])
	return out
