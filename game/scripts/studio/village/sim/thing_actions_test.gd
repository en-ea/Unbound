extends RefCounted
## Things answer his acts, headless, on a real village through Foundations' thing_facts (one writer, one clock): his fire
## sets a fence burning, it spreads to the bench, water puts it out, scorch stays, a shove breaks a crate, rain soaks,
## char weakens, a burning person lights a fence, repair mends, the same act twice is one act, and a save mid-fire
## resumes the fire.
##   godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/thing_actions_test
const T := preload("res://scripts/studio/village/sim/thing_actions.gd")
const TF := preload("res://scripts/studio/village/sim/thing_facts.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")


static func check(ok: bool, words: String) -> String:
	return ("PASS " if ok else "FAIL ") + words


static func _at(v, ms: int) -> void:
	v.runtime.now = ms / 500
	v.runtime.fraction = float(ms % 500) / 500.0


static func _act(v, roots: Dictionary, n: int, verb: String, id: String, ms: int, params := {}, ctx := {}) -> Dictionary:
	_at(v, ms)
	var c := {"distance_dm": 5}
	c.merge(ctx, true)
	return T.prepare(v, roots, {"action_id": "a%d" % n, "actor": "player:local", "target": id, "verb": verb, "parameters": params}, c)


## The one clock: thing_facts.advance at each due tick, the rules following what ended.
static func _run_to(v, carriers: Array, to: int) -> Array:
	var out := []
	while true:
		var due := mini(TF.next_due(v), to)
		if due < People.tick(v):
			due = People.tick(v)
		_at(v, due)
		out.append_array(T.follow(v, TF.advance(v), carriers))
		if due >= to:
			return out
	return out


static func _fresh():
	var v = Runtime.create(16838, {"anchored": true})
	v.thing_facts = {}
	return v


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var fence := T.id_of("fence", 3.0, -2.0)
	var bench := T.id_of("bench", 4.5, -2.5)
	var crate := T.id_of("crates", 40.0, 10.0)
	var far := T.id_of("rack", 20.0, 20.0)
	var carriers := [fence, bench, crate, far]
	out.append(check(fence == "fence@30,-20" and T.at_of(fence) == [3.0, -2.0] and T.is_thing(bench) and not T.is_thing("res:1:4"),
		"a thing's id is its kind and where it stands, in dm (%s)" % fence))
	var v = _fresh()
	var roots := {}
	out.append(check(not _act(v, roots, 1, "burn", fence, 0, {}, {"distance_dm": 80}).accepted, "fire out of reach does not catch"))
	var r := _act(v, roots, 2, "burn", fence, 0)
	out.append(check(r.accepted and T.has(v, fence, "burning") and T.has(v, fence, "scorched"), "his fire sets the fence burning"))
	var again := _act(v, roots, 2, "burn", fence, 0)
	out.append(check(again.get("duplicate", false) and TF.get_fact(v, fence, "burning").revision == 1, "the same act twice is one act"))
	var changes := _run_to(v, carriers, 3000)
	var spread := changes.filter(func(c: Dictionary) -> bool: return c.kind == "burning")
	out.append(check(T.has(v, bench, "burning") and spread.size() == 1 and spread[0].subject == bench and TF.get_fact(v, bench, "burning").deed == "a2"
		and not T.has(v, far, "burning"), "the fire spreads to the bench beside it (its cause the first act), not to the rack far off"))
	var lit := int(TF.get_fact(v, fence, "scorched").level)
	out.append(check(lit > 0, "the fence chars while it burns (%d)" % lit))
	# A save mid-fire resumes the fire.
	var copy = Codec.from_data(JSON.parse_string(JSON.stringify(Codec.to_data(v, false))))
	TF.at_load(copy)
	out.append(check(copy != null and T.has(copy, fence, "burning") and T.has(copy, bench, "burning") and int(TF.get_fact(copy, fence, "scorched").level) == lit,
		"a save mid-fire keeps both fires and the char"))
	_run_to(copy, carriers, 6000)
	out.append(check(int(TF.get_fact(copy, fence, "scorched").level) > lit and T.has(copy, fence, "burning"), "after the load the fire goes on charring (%d)" % int(TF.get_fact(copy, fence, "scorched").level)))
	out.append(check(not _act(v, roots, 3, "extinguish", fence, 3000, {"method": "water"}).accepted, "water without measured contact does nothing"))
	r = _act(v, roots, 4, "extinguish", fence, 3000, {"method": "water"}, {"water_contact": true})
	out.append(check(r.accepted and not T.has(v, fence, "burning") and T.has(v, fence, "soaked") and T.has(v, fence, "scorched"),
		"water puts the fence out; it is soaked and its scorch stays"))
	out.append(check(not _act(v, roots, 5, "burn", fence, 3100).accepted, "a soaked fence does not catch"))
	var scorch := int(TF.get_fact(v, fence, "scorched").level)
	_run_to(v, carriers, 30000)
	out.append(check(not T.has(v, fence, "soaked") and int(TF.get_fact(v, fence, "scorched").level) == scorch, "the fence dries; its scorch stays (%d)" % scorch))
	out.append(check(not T.has(v, bench, "burning") and int(TF.get_fact(v, bench, "scorched").level) > 0, "the bench burns out on its own, charred (%d)" % int(TF.get_fact(v, bench, "scorched").level)))
	out.append(check(not T.has(v, fence, "burning"), "the bench's fire does not return to the fence once out"))
	r = _act(v, roots, 6, "shove", crate, 30000, {"force": 200})
	out.append(check(r.accepted and T.has(v, crate, "struck") and not T.has(v, crate, "broken"), "a light shove jolts a crate"))
	r = _act(v, roots, 7, "shove", crate, 30100, {"force": 700})
	out.append(check(r.accepted and T.has(v, crate, "broken") and TF.get_fact(v, crate, "broken").by == "player:local" and TF.get_fact(v, crate, "struck").n == 2,
		"a hard shove breaks the crate"))
	_run_to(v, carriers, 40000)
	out.append(check(T.has(v, crate, "broken") and not T.has(v, crate, "struck"), "the blow fades; the crate stays broken"))
	out.append(check(not _act(v, roots, 8, "strike", crate, 40000, {"force": 900}).accepted, "a broken thing does not break again"))
	var tough := T.toughness(v, bench)
	out.append(check(tough < T.KINDS.bench.toughness, "char weakens a thing (bench %d of %d)" % [tough, T.KINDS.bench.toughness]))
	var kept = Codec.from_data(JSON.parse_string(JSON.stringify(Codec.to_data(v, false))))
	TF.at_load(kept)
	out.append(check(T.has(kept, crate, "broken") and T.has(kept, fence, "scorched") and int(TF.get_fact(kept, bench, "scorched").level) == int(TF.get_fact(v, bench, "scorched").level),
		"a save keeps the broken crate and the char"))
	# Burnt through.
	var v2 = _fresh()
	var r2 := {}
	_act(v2, r2, 1, "burn", far, 0, {"heat": 1000})
	_run_to(v2, [far], 13000)
	out.append(check(T.has(v2, far, "broken") and int(TF.get_fact(v2, far, "scorched").level) >= 1000 and not T.has(v2, far, "burning"), "a hot enough fire burns a thing through: broken"))
	out.append(check(not _act(v2, r2, 2, "burn", far, 14000).accepted, "what is burnt through does not catch again"))
	r = _act(v2, r2, 3, "repair", far, 15000)
	out.append(check(r.accepted and v2.thing_facts.get(far, {}).is_empty(), "repair mends it"))
	# Rain.
	var v3 = _fresh()
	var r3 := {}
	_act(v3, r3, 1, "burn", fence, 0)
	_at(v3, 1000)
	var soaked := T.rain(v3, r3, [fence, bench], "rain:1")
	out.append(check(soaked.size() == 2 and not T.has(v3, fence, "burning") and str(TF.get_fact(v3, fence, "soaked").method) == "rain", "rain puts out a fire and soaks what stands in it"))
	# A burning person against a fence.
	var v4 = _fresh()
	_at(v4, 500)
	var lit_by := T.exposed(v4, [{"at": [3.5, -2.0], "deed": "deed:man", "heat": 700}, {"at": [30.0, 30.0], "deed": "deed:far"}], [fence, far])
	out.append(check(lit_by.size() == 1 and T.has(v4, fence, "burning") and TF.get_fact(v4, fence, "burning").deed == "deed:man" and not T.has(v4, far, "burning"),
		"a burning person sets the fence beside them alight (its cause their fire)"))
	return out
