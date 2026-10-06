extends RefCounted
## The phased day in the live village (Pass 2, L1 and L2), checked headless:
## run.gd -- village/sim/phased_test
##   - a theft does not happen under the player's eyes (and does when no one is there)
##   - a deed done in view leaves the player a clue of their own
##   - after a quiet stretch with the player present, something is brought near and staged
##   - scenes are staged only while the player is in the village
##   - a fight waits a day for the player (once)
##   - sixty days with the player in the square: no errors, some scenes, the day closes every night
const S := preload("res://scripts/studio/village/sim/state.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Crime := preload("res://scripts/studio/village/sim/crime.gd")

static var _out := PackedStringArray()
static var _fails := 0


static func _check(ok: bool, what: String) -> void:
	_out.append(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


static func _theft_fixture(seed: int) -> Array:
	var v := Runtime.create(seed)
	# a thief with a pen to rob: the first adult of one household, the next household's pen
	var thief := -1
	for p in v.people:
		if p.alive and p.present and Village.age_of(v, p) >= 18 and not p.locked:
			thief = p.id
			break
	var target := -1
	for h in v.households:
		if h.id != v.people[thief].household and h.lineage != v.people[thief].lineage:
			target = h.id
			break
	v.households[target].geese = 3
	var pen := Village.place_id(v, "pen_" + v.households[target].home)
	var minute := int(v.runtime.now) % 1440 + 30
	var it := {"kind": "theft", "actor": thief, "minute": minute, "k": 12345, "target": target, "place": pen, "allow": 9, "tries": 2}
	return [v, it, pen]


static func report() -> PackedStringArray:
	_out = PackedStringArray()
	_fails = 0
	# 1. eyes: the same planned theft, once with the player at the pen and once with no one there
	for watched in [true, false]:
		var fx := _theft_fixture(21)
		var v: S.Village = fx[0]
		var it: Dictionary = fx[1]
		var pen: int = fx[2]
		it.allow = 1   # a careful thief (only one pair of eyes tolerated)
		for p in v.people:   # clear the pen of other eyes: everyone else far off
			if p.id != int(it.actor):
				p.plan = PackedInt32Array([0, 1440, Village.place_id(v, "far_woods")])
		Runtime.set_player(v, watched, v.place_x[pen], v.place_z[pen])
		var result := Crime.run_intent(v, it)
		if watched:
			_check(result.get("abandoned", false) and result.get("watched", false), "a careful thief turns away under the player's eyes")
		else:
			_check(result.get("done", false), "the same theft is done when no one is there")
	# 2. a bold thief in plain view: done, and the player saw it
	var fx2 := _theft_fixture(22)
	var v2: S.Village = fx2[0]
	var it2: Dictionary = fx2[1]
	it2.allow = 99   # a desperate thief who does not care who sees
	Runtime.set_player(v2, true, v2.place_x[fx2[2]], v2.place_z[fx2[2]])
	var r2 := Crime.run_intent(v2, it2)
	var clue := false
	for c: Dictionary in v2.runtime.players.get("player:local", {}).get("knowledge", []):
		if c.via == "seen" and int(c.culprit) == int(it2.actor):
			clue = true
	_check(r2.get("done", false) and clue, "a deed done in view leaves the player a clue of their own")
	# 3 and 4. attention and staging: the player in the square for two days; then away for two days
	var v3 := Runtime.create(23)
	var square := v3.pl_square
	Runtime.set_player(v3, true, v3.place_x[square], v3.place_z[square])
	v3.runtime.quiet_since = int(v3.runtime.now) - 1000
	var staged_before := v3.staging_count
	var brought := 0
	for i in 2:
		var target := Runtime.next_dawn(v3)
		while int(v3.runtime.now) < target:
			Runtime.advance(v3, mini(target, int(v3.runtime.now) + 30))
			for it: Dictionary in v3.intents:
				if it.get("near", false) and not it.get("_counted", false):
					it._counted = true
					brought += 1
	var incident_stagings := 0
	for st: Dictionary in v3.stagings:
		if int(st.id) >= staged_before and st.kind in ["theft", "quarrel", "kindness"]:
			incident_stagings += 1
	_check(brought > 0, "with the player present, something was brought near (%d in two days)" % brought)
	_check(incident_stagings > 0, "and scenes were staged for the player (%d)" % incident_stagings)
	Runtime.set_player(v3, false, 0, 0)
	var away_before := v3.staging_count
	var away_scenes := 0
	for i in 2:
		Runtime.advance(v3, Runtime.next_dawn(v3))
	for st: Dictionary in v3.stagings:
		if int(st.id) >= away_before and st.kind in ["theft", "quarrel", "kindness"]:
			away_scenes += 1
	_check(away_scenes == 0, "no scenes are staged while the player is away")
	# 5. a fight waits a day for the player, once
	var v5 := Runtime.create(24)
	Runtime.advance(v5, Runtime.next_dawn(v5))
	var a := -1
	var b := -1
	for p in v5.people:
		if p.alive and p.present and Village.age_of(v5, p) >= 18:
			if a < 0:
				a = p.id
			elif b < 0 and p.household != v5.people[a].household:
				b = p.id
	var brawl := {"kind": "brawl", "actor": a, "other": b, "minute": 1300, "k": 777, "place": v5.pl_square}
	Village.add_intent(v5, brawl)
	Runtime.advance(v5, Runtime.next_dawn(v5) - 60)
	_check(brawl.get("held", false) and v5.intents_next.has(brawl), "a fight waits a day while the player is away")
	# 6. sixty days with the player in the square
	var v6 := Runtime.create(25)
	Runtime.set_player(v6, true, v6.place_x[v6.pl_square], v6.place_z[v6.pl_square])
	var start_day := v6.day
	var scenes := 0
	var from := v6.staging_count
	for i in 60:
		Runtime.advance(v6, Runtime.next_dawn(v6))
	for st: Dictionary in v6.stagings:
		if int(st.id) >= from and st.kind in ["theft", "quarrel", "kindness"]:
			scenes += 1
	_check(v6.day == start_day + 60 and v6.phases.size() > 0, "sixty days pass, one opening and one close each (day %d)" % v6.day)
	_check(scenes >= 10, "sixty days in the square show %d small scenes" % scenes)
	_out.append("PHASED: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	return _out