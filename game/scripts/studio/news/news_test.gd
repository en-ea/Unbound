extends RefCounted
## Headless tests for village life and news (plan VILLAGE-LIFE-AND-NEWS): the rules' happenings (sim/happenings.gd) and
## the stories and their desk (news/stories.gd). Pure, milliseconds:
##   godot --headless --path game --script res://scripts/studio/run.gd -- news/news_test
## Each case prints PASS or FAIL with what it measured.
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Happenings := preload("res://scripts/studio/village/sim/happenings.gd")
const WorldActions := preload("res://scripts/studio/village/sim/world_actions.gd")
const Pressures := preload("res://scripts/studio/village/sim/pressures.gd")
const TownMeeting := preload("res://scripts/studio/village/sim/town_meeting.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")
const Stories := preload("res://scripts/studio/news/stories.gd")
const UnboundNews := preload("res://scripts/studio/news/unbound_news.gd")
const Director := preload("res://scripts/studio/village/sim/director.gd")


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	out.append_array(_argue_once())
	out.append_array(_step_in())
	out.append_array(_paths_follow_the_rules())
	out.append_array(_same_twice())
	out.append_array(_chronicle_untouched())
	out.append_array(_threads())
	out.append_array(_pacing())
	out.append_array(_restore())
	out.append_array(_headlines())
	out.append_array(_deed_on_the_clock())
	out.append_array(_levels())
	out.append_array(_meeting_called())
	out.append_array(_meeting_decides())
	out.append_array(_meeting_news())
	out.append_array(_pressures_saved())
	out.append_array(_director_through_a_long_act())
	out.append_array(_ends_flag_the_machine())
	out.append_array(_ends_flag_jittered_conveyors())
	out.append_array(_real_ends_flagged())
	out.append_array(_ends_pass_people())
	out.append_array(_drifting_off_is_not_reacting())
	return out


static func _check(ok: bool, what: String) -> String:
	return ("PASS " if ok else "FAIL ") + what


## A live village with two grown residents who dislike each other, at mid-morning.
static func _village(seed := 7) -> Array:
	var v = Runtime.create(seed)
	Runtime.advance(v, int(v.runtime.now) + 120)
	var grown: Array[int] = []
	for p in v.people:
		if p.alive and p.present and p.authored == "" and Village.age_of(v, p) >= 20:
			grown.append(p.id)
	var a: int = grown[0]
	var b: int = grown[1]
	Village.set_opinion(v, a, b, -50)
	Village.set_opinion(v, b, a, -45)
	return [v, a, b]


static func _ask(v, verb: String, target: int, params: Dictionary, tag := "") -> Dictionary:
	var req := {"action_id": "%s:%d:%d%s" % [verb, target, int(v.runtime.now), tag], "player_id": "player:local",
		"village_id": v.runtime.village, "logical_time": v.runtime.now, "verb": verb, "target": target, "parameters": params}
	return WorldActions.act(v, req, {"distance_dm": 20})


## A meeting's quarrel through the request path: the rules' quarrel applies its -8 once; the pair cannot argue again
## that day; each keeps clear of the other; a repeat of the same request is the first receipt, not a second argument.
static func _argue_once() -> PackedStringArray:
	var t: Array = _village()
	var v = t[0]
	var a: int = t[1]
	var b: int = t[2]
	var before := Village.opinion(v, a, b)
	var first := _ask(v, "argue", a, {"other": b, "at": [0, 0], "near": []})
	var after := Village.opinion(v, a, b)
	var again := _ask(v, "argue", a, {"other": b, "at": [0, 0], "near": []})          # the same request again
	var other_day := _ask(v, "argue", b, {"other": a, "at": [0, 0], "near": []}, "x")   # a new request, the same day
	var h: Dictionary = v.runtime.happenings[0] if not v.runtime.happenings.is_empty() else {}
	var blows: bool = not h.is_empty() and "blows" in h.path
	var ok: bool = first.get("accepted", false) and again.get("duplicate", false) and not other_day.get("accepted", false) \
		and v.runtime.happenings.size() == 1 and Happenings.wary(v, a, b) and Happenings.wary(v, b, a) \
		and (after == before - 8 or blows) and str(h.path[0]) == "words"
	return PackedStringArray([_check(ok, "argue: accepted once (%s), opinion %d -> %d, repeat a duplicate, a second refused (%s), both wary, path %s"
		% [str(first.get("accepted")), before, after, str(other_day.get("reason", "")), str(h.get("path", []))])])


## The player steps in while it lasts: parted, by the player; both remember it; it is logged; not twice.
static func _step_in() -> PackedStringArray:
	var t: Array = _village(11)
	var v = t[0]
	var a: int = t[1]
	var b: int = t[2]
	var r := _ask(v, "argue", a, {"other": b, "at": [0, 0], "near": []})
	if not r.get("accepted", false):
		return PackedStringArray([_check(false, "step in: no argument to step into (%s)" % str(r))])
	var hid := int(r.happening)
	var h: Dictionary = v.runtime.happenings[0]
	if "blows" in h.path:
		var no := _ask(v, "step_in", a, {"happening": hid})
		return PackedStringArray([_check(not no.get("accepted", false), "step in: refused once blows are coming (%s)" % str(no.get("reason", "")))])
	var events: int = v.events.size()
	var s := _ask(v, "step_in", a, {"happening": hid})
	var twice := _ask(v, "step_in", b, {"happening": hid}, "y")
	var known: Dictionary = v.runtime.acquaintance.get(str(a), {})
	var ok: bool = s.get("accepted", false) and h.path.back() == "parted" and int(h.peacemaker) == Happenings.PLAYER \
		and v.events.size() == events + 1 and v.events.back().type == "parted" and (known.get("memories", []) as Array).has("parted_by_you") \
		and not twice.get("accepted", false)
	return PackedStringArray([_check(ok, "step in: parted by the player (path %s), logged, remembered, not twice (%s)"
		% [str(h.path), str(twice.get("reason", ""))])])


## Blows are the rules' own draw (crime.gd); heat and a peacemaker come from temper, dislike and who is there.
static func _paths_follow_the_rules() -> PackedStringArray:
	var seen := {}
	var parted_by_kind := 0
	var blows_with_crime := 0
	for seed in range(20, 60):
		var t: Array = _village(seed)
		var v = t[0]
		var a: int = t[1]
		var b: int = t[2]
		var near: Array = []
		for p in v.people:
			if p.alive and p.present and p.id != a and p.id != b and p.authored == "" and Village.age_of(v, p) >= 20:
				near.append(p.id)
		Village.set_opinion(v, a, b, -40 - seed % 50)
		var r := _ask(v, "argue", a, {"other": b, "at": [0, 0], "near": near.slice(0, 5)})
		if not r.get("accepted", false):
			continue
		var h: Dictionary = v.runtime.happenings[0]
		seen[str(h.path.back())] = int(seen.get(str(h.path.back()), 0)) + 1
		if h.path.back() == "parted" and near.has(int(h.peacemaker)):
			parted_by_kind += 1
		if h.path.back() == "blows" and int(h.crime) >= 0:
			blows_with_crime += 1
	var ok: bool = seen.size() >= 3 and parted_by_kind == int(seen.get("parted", 0)) and blows_with_crime == int(seen.get("blows", 0))
	return PackedStringArray([_check(ok, "paths: at least three endings across 40 villages (%s); every peacemaker was there; every blow a crime" % str(seen))])


## The same village, the same requests: the same happening, to the last field (keyed, no chance).
static func _same_twice() -> PackedStringArray:
	var records: Array = []
	for _i in 2:
		var t: Array = _village(31)
		_ask(t[0], "argue", t[1], {"other": t[2], "at": [10, 20], "near": [3, 4, 5]})
		records.append(JSON.stringify(t[0].runtime.happenings))
	return PackedStringArray([_check(records[0] == records[1] and records[0] != "[]", "the same requests, the same happening (keyed)")])


## The chronicle (step_day) never makes a happening, a stance or the new events.
static func _chronicle_untouched() -> PackedStringArray:
	var V = Village.create_village(5, {"pace": 10})
	for _d in 40:
		Village.step_day(V)
	var odd := 0
	for e in V.events:
		if e.type in ["parted", "meeting", "pressure"]:
			odd += 1
	return PackedStringArray([_check(odd == 0 and V.runtime.is_empty(), "the chronicle: no happenings, no new events (%d), no runtime" % odd)])


## Items join a story by key or by cause; an unrelated one starts its own.
static func _threads() -> PackedStringArray:
	var n := Stories.new()
	var s1 := n.add({"id": 10, "causes": [], "key": "crime:1", "kind": "crime", "severity": 2, "minute": 100, "headline": "Theft"})
	var s2 := n.add({"id": 12, "causes": [10], "key": "", "kind": "crime", "severity": 1, "minute": 200, "headline": "They say Bram"})
	var s3 := n.add({"id": 14, "causes": [], "key": "crime:1", "kind": "crime", "severity": 3, "minute": 300, "headline": "Bram accused"})
	var s4 := n.add({"id": 15, "causes": [], "key": "", "kind": "death", "severity": 2, "minute": 310, "headline": "Wren has died"})
	var st: Dictionary = n.stories[s1]
	var ok: bool = s1 == 10 and s2 == 10 and s3 == 10 and s4 == 15 and st.items.size() == 3 and int(st.severity) == 3 and st.headline == "Bram accused"
	return PackedStringArray([_check(ok, "threads: a theft, its rumour and its accusation one story (severity %d, %s); a death its own" % [int(st.severity), st.headline])])


## One new line at a time: the second waits its gap; a grave one goes first and sooner; old news leaves the desk.
static func _pacing() -> PackedStringArray:
	var n := Stories.new()
	n.add({"id": 1, "kind": "argument", "severity": 1, "minute": 1000, "headline": "An argument", "how": "seen"})
	n.add({"id": 2, "kind": "feast", "severity": 2, "minute": 1000, "headline": "A wedding", "how": "announced"})
	var at_once := n.desk(1000)
	var soon := n.desk(1010)
	var later := n.desk(1000 + Stories.GAP)
	n.add({"id": 3, "kind": "death", "severity": 4, "minute": 1030, "headline": "Murder", "how": "heard"})
	n.add({"id": 4, "kind": "argument", "severity": 1, "minute": 1030, "headline": "Another argument", "how": "seen"})
	var grave := n.desk(1000 + Stories.GAP + Stories.GRAVE_GAP)
	var gone := n.desk(1000 + Stories.GAP + Stories.SHOWN_FOR + 100)
	var ok: bool = at_once.size() == 1 and at_once[0].headline == "A wedding" and soon.size() == 1 and later.size() == 2 \
		and grave.size() == 3 and grave[0].headline == "Murder" and gone.size() <= 2
	return PackedStringArray([_check(ok, "pacing: one at a time (%d, %d, %d), the worthier first (%s), grave first (%s), old news leaves (%d)"
		% [at_once.size(), soon.size(), later.size(), at_once[0].headline if not at_once.is_empty() else "-",
			grave[0].headline if not grave.is_empty() else "-", gone.size()])])


## What the player knew survives a save: restored, the stories rebuilt from the same items say the same, and nothing is
## new again.
static func _restore() -> PackedStringArray:
	var items: Array = [
		{"id": 1, "kind": "argument", "severity": 1, "minute": 1000, "headline": "An argument"},
		{"id": 2, "causes": [1], "kind": "argument", "severity": 1, "minute": 1004, "headline": "Wren parted them"},
		{"id": 3, "kind": "feast", "severity": 2, "minute": 1010, "headline": "A wedding"},
	]
	var n := Stories.new()
	for it: Dictionary in items:
		var copy := it.duplicate()
		copy.how = "seen" if int(it.id) != 3 else ""
		n.add(copy)
	n.desk(1100)
	n.read(1)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(n.known_state()))
	var m := Stories.new()
	m.restore_known(saved)
	m.rebuilding = true
	for it: Dictionary in items:
		m.add(it.duplicate())
	m.rebuilding = false
	var a := JSON.stringify(n.desk(1200))
	var b := JSON.stringify(m.desk(1200))
	return PackedStringArray([_check(a == b and m.waiting() == 0, "restore: the same desk after a save (%s), nothing queued again" % b.substr(0, 90))])


## Every kind of event the news knows has a headline, short and without digits (the village's voice).
static func _headlines() -> PackedStringArray:
	var v = Runtime.create(9)
	for _d in 20:
		Runtime.advance(v, Runtime.next_dawn(v))
	var bad: Array = []
	var by_type := {}
	for item: Dictionary in UnboundNews.items(v, 0):
		by_type[item.type] = int(by_type.get(item.type, 0)) + 1
		var h: String = item.headline
		if h.length() > 64 or h.is_empty() or h.contains("%") or RegEx.create_from_string("[0-9]").search(h) != null:
			bad.append("%s: %s" % [item.type, h])
	return PackedStringArray([_check(bad.is_empty() and by_type.size() >= 3, "headlines: %d kinds of event over 20 days, all short and plain %s"
		% [by_type.size(), str(bad.slice(0, 3))])])


# ---------- pressures and the town meeting (sim/pressures.gd, sim/town_meeting.gd) ----------

## Levels move with hysteresis: up at UP, down only below DOWN (no flicker at the line).
static func _levels() -> PackedStringArray:
	var ok: bool = Pressures._level_for(420, 0) == 1 and Pressures._level_for(320, 1) == 1 and Pressures._level_for(290, 1) == 0 \
		and Pressures._level_for(700, 0) == 2 and Pressures._level_for(560, 2) == 2 and Pressures._level_for(500, 2) == 1 \
		and Pressures._level_for(100, 2) == 0
	return PackedStringArray([_check(ok, "levels: up at %s, down below %s, no flicker between" % [str(Pressures.UP), str(Pressures.DOWN)])])


## A live village made hungry: two houses in three emptied, the rest full (hunger and inequality), at mid-morning.
static func _hungry_village(seed := 5) -> Object:
	var v = Runtime.create(seed)
	Runtime.advance(v, int(v.runtime.now) + 60)
	Pressures.update(v)                                 # the levels as they stand (not news)
	var i := 0
	for hh in v.households:
		var mouths := Pressures._mouths(v, hh)
		if mouths == 0:
			continue
		hh.food = -6 * mouths if i % 3 != 2 else 25 * mouths
		i += 1
	for p in v.people:
		if p.alive and p.present and p.authored == "" and v.households[p.household].food < 0:
			p.hunger = 500
	return v


## Hunger going high is a crossing logged, and calls a meeting at the square some hours ahead: the aggrieved, the
## full house and the elder, three apart; a second call within EVERY_DAYS is refused.
static func _meeting_called() -> PackedStringArray:
	var v = _hungry_village()
	var before: int = v.events.size()
	var moved: Array = Pressures.update(v)
	var crossings: Array = []
	for e in v.events.slice(before):
		if e.type == "pressure":
			crossings.append("%s%d" % [e.data.pressure, int(e.data.level)])
	var h: Dictionary = {}
	for r: Dictionary in v.runtime.happenings:
		if str(r.kind) == "meeting":
			h = r
	var again := TownMeeting.call_for(v, "inequality", -1)
	var ok: bool = not moved.is_empty() and not h.is_empty() and int(h.minute) - int(h.called) >= TownMeeting.AHEAD \
		and int(h.place) == int(v.pl_square) and int(h.a) != int(h.b) and int(h.a) != int(h.elder) and int(h.b) != int(h.elder) \
		and again.is_empty() and str(h.outcome).is_empty() and int(h.decide_at) > int(h.minute)
	return PackedStringArray([_check(ok, "meeting called: crossings %s, at minute %d (called %d), speakers %d %d elder %d, a second refused (%s)"
		% [str(crossings), int(h.get("minute", -1)), int(h.get("called", -1)), int(h.get("a", -1)), int(h.get("b", -1)),
			int(h.get("elder", -1)), str(again.is_empty())])])


## At its minute the rules decide, once: share grain (food moves from full to empty, none made or lost, the emptiest
## gets more, inequality falls), a night watch (fear falls, the watch is set) or nothing (they part angrier, wary of
## each other); logged; not decided twice. Hungry villages and frightened ones, several seeds: at least two outcomes.
static func _meeting_decides() -> PackedStringArray:
	var parts: Array = []
	var all_ok := true
	var outcomes := {}
	for case: Array in [[5, "hunger"], [6, "hunger"], [8, "hunger"], [9, "hunger"], [3, "fear"], [4, "fear"], [10, "fear"], [13, "fear"],
			[7, "hard hearts"]]:
		var v = _afraid_village(int(case[0])) if case[1] == "fear" else _hungry_village(int(case[0]))
		if case[1] == "hard hearts":
			for p in v.people:
				p.values[Village.C.V_MERCY] = 0       # no mercy anywhere, greed everywhere: the meeting gives nothing
				p.traits[Village.C.GREED] = 100
		Pressures.update(v)
		var h: Dictionary = {}
		for r: Dictionary in v.runtime.happenings:
			if str(r.kind) == "meeting":
				h = r
		if h.is_empty():
			continue
		var total_before := 0
		var least_before := 1000000
		for hh in v.households:
			if Pressures._mouths(v, hh) > 0:
				total_before += hh.food
				least_before = mini(least_before, hh.food / Pressures._mouths(v, hh))
		var unequal_before := Pressures._inequality(v)
		var fear_before: int = v.fear
		var a := int(h.a)
		var b := int(h.b)
		var opinion_before := Village.opinion(v, a, b)
		Runtime.advance(v, int(h.decide_at))
		var fear_at_decision: int = v.fear
		var total_after := 0
		var least_after := 1000000
		for hh in v.households:
			if Pressures._mouths(v, hh) > 0:
				total_after += hh.food
				least_after = mini(least_after, hh.food / Pressures._mouths(v, hh))
		var outcome := str(h.outcome)
		var logged := 0
		for e in v.events:
			if e.type == "meeting" and str(e.data.get("phase", "")) == "decided" and int(e.data.get("happening", -1)) == int(h.id):
				logged += 1
		Runtime.advance(v, int(h.decide_at) + 30)
		var logged_later := 0
		for e in v.events:
			if e.type == "meeting" and str(e.data.get("phase", "")) == "decided" and int(e.data.get("happening", -1)) == int(h.id):
				logged_later += 1
		var ok := logged == 1 and logged_later == 1 and outcome in ["share", "watch", "nothing"] and TownMeeting.next_due(v) < 0
		match outcome:
			"share": ok = ok and least_after > least_before and total_after == total_before and Pressures._inequality(v) < unequal_before
			"watch": ok = ok and TownMeeting.watched(v) and fear_at_decision < fear_before
			"nothing": ok = ok and Village.opinion(v, a, b) < opinion_before and Happenings.wary(v, a, b)
		all_ok = all_ok and ok
		if not ok:
			parts.append("FAILED %s (seed %d, %s): logged %d then %d, food %d -> %d, the emptiest %d -> %d, fear %d -> %d, watched %s"
				% [outcome, int(case[0]), case[1], logged, logged_later, total_before, total_after, least_before, least_after,
					fear_before, fear_at_decision, str(TownMeeting.watched(v))])
		elif not outcomes.has(outcome):
			parts.append("%s (seed %d, %s): food %d -> %d, the emptiest a mouth %d -> %d, fear %d -> %d" % [outcome, int(case[0]), case[1],
				total_before, total_after, least_before, least_after, fear_before, fear_at_decision])
		outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
	all_ok = all_ok and outcomes.size() >= 2
	return PackedStringArray([_check(all_ok, "meeting decides once, each outcome as it should %s: %s" % [str(outcomes), " | ".join(parts)])])


## A live village gripped by fear (an omen's worth), fed as it is.
static func _afraid_village(seed: int) -> Object:
	var v = Runtime.create(seed)
	Runtime.advance(v, int(v.runtime.now) + 60)
	Pressures.update(v)
	v.fear = 900
	return v


## The news reads it: the call is announced (a player anywhere in the village knows), one story with its decision.
static func _meeting_news() -> PackedStringArray:
	var v = _hungry_village()
	var from: int = v.events.size()
	Pressures.update(v)
	var h: Dictionary = {}
	for r: Dictionary in v.runtime.happenings:
		if str(r.kind) == "meeting":
			h = r
	if h.is_empty():
		return PackedStringArray([_check(false, "meeting news: no meeting called")])
	Runtime.advance(v, int(h.decide_at) + 1)
	var n := Stories.new()
	var heads: Array = []
	var called_how := ""
	for item: Dictionary in UnboundNews.items(v, from):
		item.how = UnboundNews.how(item, Vector2(10000, 10000), true)
		if str(item.type) == "meeting" and str(item.phase) == "meeting" and called_how.is_empty():
			called_how = str(item.how)
		heads.append(str(item.headline))
		n.add(item)
	var meeting_stories := 0
	for sid: int in n.stories:
		if str(n.stories[sid].kind) == "meeting":
			meeting_stories += 1
	var ok: bool = called_how == "announced" and meeting_stories == 1 and heads.any(func(s: String) -> bool: return s.begins_with("Town meeting at the square"))
	return PackedStringArray([_check(ok, "meeting news: called %s, %d meeting story, lines %s" % [called_how, meeting_stories, str(heads)])])


## What the pressures and the meeting keep survives a save exactly (the village's own codec, through JSON).
static func _pressures_saved() -> PackedStringArray:
	var v = _hungry_village()
	Pressures.update(v)
	var data = JSON.parse_string(JSON.stringify(Save.to_data(v)))
	var copy = Save.from_data(data)
	var same: bool = copy != null
	var diff := ""
	for key: String in ["pressures", "town", "happenings", "stances"]:
		if same and JSON.stringify(copy.runtime.get(key)) != JSON.stringify(v.runtime.get(key)):
			same = false
			diff = key
	var minutes_kept: bool = copy != null and copy.events[copy.events.size() - 1].minute == v.events[v.events.size() - 1].minute \
		and v.events[v.events.size() - 1].minute >= 0
	return PackedStringArray([_check(same and minutes_kept, "pressures saved: levels, the meeting, stances the same after a save%s; event minutes kept (%s)"
		% [" (" + diff + " differs)" if not diff.is_empty() else "", str(minutes_kept)])])


## A deed's argument on a later day (Incidents.show: an intent's minute is the day's): its record on the game's clock,
## the day's cap and the stance until that day ends.
static func _deed_on_the_clock() -> PackedStringArray:
	var t: Array = _village(13)
	var v = t[0]
	var a: int = t[1]
	var b: int = t[2]
	Runtime.advance(v, int(v.runtime.now) + 2 * 1440)
	var now := int(v.runtime.now)
	var it := {"kind": "quarrel", "actor": a, "other": b, "place": int(v.pl_square), "minute": now % 1440}
	var h := Happenings.from_deed(v, it, {"done": true})
	var ok: bool = not h.is_empty() and int(h.minute) == now and int(h.phases[0][1]) == now and int(h.ends) > now 		and Happenings.argued_today(v, a, b) and Happenings.wary(v, a, b) and int(v.runtime.stances["%d>%d" % [a, b]]) == (now / 1440 + 1) * 1440
	return PackedStringArray([_check(ok, "a deed's argument on day %d: at minute %d (now %d), ends %d, argued today %s, wary %s"
		% [now / 1440, int(h.get("minute", -1)), now, int(h.get("ends", -1)), str(Happenings.argued_today(v, a, b)), str(Happenings.wary(v, a, b))])])


## The director's quiet counts from a scene's start (plan LIVELY-VILLAGE 5.1): while a public act stands for hours near
## the player, the village still brings small scenes after its quiet. Before the fix, re-activating the act every step
## renewed the quiet every minute and nothing was brought until the act was over.
static func _director_through_a_long_act() -> PackedStringArray:
	var v = null
	var act := {}
	for seed: int in [Save.HOME_SEED, 2, 6, 3, 4, 5]:     # (the first village with a pillory or stocks in 60 days)
		v = Runtime.create(seed)
		for _i in 60:
			Runtime.advance(v, Runtime.next_dawn(v))
			for pending in v.pending:
				if pending.kind in ["pillory", "stocks"]:
					act = Runtime.event_by_id(v, pending.staging)
					break
			if not act.is_empty():
				break
		if not act.is_empty():
			break
	if act.is_empty():
		return PackedStringArray([_check(false, "a pillory or stocks within 60 days in one of six villages (none found)")])
	var sq: int = v.pl_square
	Runtime.set_player(v, true, v.place_x[sq], v.place_z[sq])
	Runtime.advance(v, maxi(int(v.runtime.now), int(act.from)))
	var start := int(v.runtime.now)
	var until := mini(int(act.deadline), start + 720)
	var brought := 0
	var first := -1
	var intents_seen := {}
	for it: Dictionary in v.intents:             # (brought before it began: not what is measured)
		intents_seen["%s:%d:%d" % [str(it.kind), int(it.get("actor", -1)), int(it.minute)]] = true
	while int(v.runtime.now) < until:
		Runtime.advance(v, int(v.runtime.now) + 1)
		for it: Dictionary in v.intents:
			var key := "%s:%d:%d" % [str(it.kind), int(it.get("actor", -1)), int(it.minute)]
			if it.get("near", false) and not intents_seen.has(key):
				intents_seen[key] = true
				brought += 1
				if first < 0:
					first = int(v.runtime.now) - start
	return PackedStringArray([
		_check(until - start >= 300, "the act stands long enough to test (%d game minutes)" % (until - start)),
		_check(brought >= 1 and first <= Director.QUIET + Director.ATTENTION_EVERY + Director.LEAD + 5,
			"while it stands, the director brings scenes near the player: %d, the first %d game minutes after it began (its quiet is %d, it looks every %d)"
			% [brought, first, Director.QUIET, Director.ATTENTION_EVERY]),
	])



# ---------- the end measures, validated before use (plan LIVELY-VILLAGE 3.0; the review's rounds 1 and 2) ----------

## A synthetic end: `lefts` [seconds after the end (-1: stayed), household]; `moves` the first moves; people on a
## ring round the middle, leaving outward (each at their own angle).
static func _end_of(kind: String, lefts: Array, moves: Array, watch := 150.0) -> Dictionary:
	var members := {}
	for i in lefts.size():
		var out := Vector2.from_angle(TAU * float(i) / lefts.size())
		members[i] = {"moved": float(moves[i]), "left": float(lefts[i][0]), "house": int(lefts[i][1]),
			"at_left": out * 10.0, "own": {}}
	return {"kind": kind, "members": members, "watch": watch}


static func _departure_misses(row: Dictionary) -> Array:
	return (row.missed as Array).filter(func(m: String) -> bool:
		return m.begins_with("exodus") or m.begins_with("gap cv") or m.begins_with("first moves") or m.begins_with("last after"))


## The machines the old measure missed must be flagged: the pillory's conveyor (one leaving every half second), a slow
## conveyor (one every 1.5 s: no burst, still a machine) and the old evening (80 people gone within 7 s).
static func _ends_flag_the_machine() -> PackedStringArray:
	var LifeWatch = load("res://scripts/studio/news/life_watch.gd")
	var conveyor: Array = []
	var slow: Array = []
	var moves: Array = []
	for i in 20:
		conveyor.append([0.5 * i, i])
		slow.append([1.5 * i, i])
		moves.append(0.1 * i)
	var fast_row: Dictionary = LifeWatch.end_row(_end_of("public:pillory:released", conveyor, moves))
	var slow_row: Dictionary = LifeWatch.end_row(_end_of("public:pillory:released", slow, moves))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var evening: Array = []
	var ev_moves: Array = []
	for i in 80:
		var t := rng.randf_range(0.0, 7.0)
		evening.append([t, i / 3])
		ev_moves.append(maxf(0.0, t - 1.0))
	var ev_row: Dictionary = LifeWatch.end_row(_end_of("evening:stretch", evening, ev_moves, 260.0))
	return PackedStringArray([
		_check("exodus" in fast_row.missed and float(fast_row.gap_cv) < 0.6,
			"the pillory's conveyor (20, one every 0.5 s) flagged: %s" % str(fast_row.missed)),
		_check(not slow_row.exodus and float(slow_row.gap_cv) < 0.6 and not _departure_misses(slow_row).is_empty(),
			"a slow conveyor (one every 1.5 s) flagged by its regularity alone: exodus %s, cv %.2f, %s"
			% [str(slow_row.exodus), float(slow_row.gap_cv), str(slow_row.missed)]),
		_check(not _departure_misses(ev_row).is_empty(), "the old evening (80 within 7 s) flagged: worst burst %d units, %s"
			% [int(ev_row.worst_burst), str(ev_row.missed)]),
	])


## People must pass: households leaving together, log-normal delays (most soon, a few late, a long tail), a knot of
## three staying past the watch; five draws each, a scene's crowd and an evening.
static func _ends_pass_people() -> PackedStringArray:
	var LifeWatch = load("res://scripts/studio/news/life_watch.gd")
	var out := PackedStringArray()
	# kind, people, households, median s, sigma, a knot staying, watch
	for what: Array in [["public:pillory:released", 22, 8, 14.0, 0.9, 3, 150.0], ["evening:stretch", 40, 14, 50.0, 0.8, 0, 260.0]]:
		var bad: Array = []
		var cvs: Array = []
		for draw in 5:
			var rng := RandomNumberGenerator.new()
			rng.seed = 100 + draw
			var n := int(what[1])
			var houses := int(what[2])
			var at_house: Array = []
			for h in houses:
				at_house.append(float(what[3]) * exp(float(what[4]) * rng.randfn(0.0, 1.0)))
			var lefts: Array = []
			var moves: Array = []
			for i in n:
				var h := i % houses
				var t := float(at_house[h]) + rng.randf_range(0.0, 2.0)
				if i >= n - int(what[5]):
					lefts.append([-1.0, 100 + i])          # the knot that stays
				else:
					lefts.append([t, h])
				moves.append(maxf(0.2, t * rng.randf_range(0.2, 0.7)))
			var row: Dictionary = LifeWatch.end_row(_end_of(str(what[0]), lefts, moves, float(what[6])))
			cvs.append(row.gap_cv)
			if not _departure_misses(row).is_empty():
				bad.append(_departure_misses(row))
		out.append(_check(bad.is_empty(), "%s like people (%d in %d households, log-normal, median %d s): passes 5 of 5 (cv %s)%s"
			% [what[0], what[1], what[2], int(what[3]), str(cvs), "" if bad.is_empty() else " missed " + str(bad)]))
	return out


## Drifting back is not a reaction (review round 2, MUST 2): a crowd that only walks off - at their own moments, some
## past the subject, two hurrying, a circle talking among itself - scores 0.1 or less; and the real ones are seen: a
## kin going to them, a cheer, a child running off, someone backing away facing them.
static func _drifting_off_is_not_reacting() -> PackedStringArray:
	var LifeWatch = load("res://scripts/studio/news/life_watch.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var subject := Vector2.ZERO
	# each: start, direction, m/s, sets off at, owner, talks (lines and nods), clip, stops this near the subject, backs
	var drift: Array = []
	for i in 20:
		var at := Vector2.from_angle(TAU * i / 20.0) * rng.randf_range(3.0, 6.0)
		var p := {"at": at, "dir": at.normalized().rotated(rng.randf_range(-1.0, 1.0)), "speed": rng.randf_range(1.15, 1.5),
			"off": rng.randf_range(0.5, 8.0), "owner": "", "talks": false, "clip": "Walk", "stop": -1.0, "backs": false}
		if i < 4:
			p.dir = (-at.normalized()).rotated(rng.randf_range(-0.2, 0.2))   # home lies past the subject
		elif i < 6:
			p.speed = rng.randf_range(1.6, 1.75)                             # the busy hurry back
		elif i < 9:
			p.owner = "society"                                              # a circle, talking among itself
			p.talks = true
			p.speed = 0.0
			p.clip = "Idle"
		drift.append(p)
	var real: Array = [
		{"at": Vector2(8, 0), "dir": Vector2(-1, 0), "speed": 1.3, "off": 1.0, "owner": "reaction", "talks": false, "clip": "Walk", "stop": 1.5, "backs": false},
		{"at": Vector2(0, 5), "dir": Vector2.ZERO, "speed": 0.0, "off": 2.0, "owner": "stage", "talks": false, "clip": "Yes", "stop": -1.0, "backs": false},
		{"at": Vector2(-4, 0), "dir": Vector2(-1, 0), "speed": 3.2, "off": 1.0, "owner": "", "talks": false, "clip": "Jog_Fwd", "stop": -1.0, "backs": false},
		{"at": Vector2(0, -4), "dir": Vector2(0, -1), "speed": 0.8, "off": 1.5, "owner": "reaction", "talks": false, "clip": "Walk", "stop": -1.0, "backs": true},
	]
	var d := _score(LifeWatch, drift, subject)
	var r := _score(LifeWatch, real, subject)
	return PackedStringArray([
		_check(float(d[0]) <= 0.1, "a crowd that only drifts off reacts %.2f (%s): 0.1 or less" % [float(d[0]), str(d[1])]),
		_check(float(r[0]) == 1.0 and (r[1] as Dictionary).has_all(["toward", "Yes", "away"]),
			"real reactions are seen: %.2f, %s" % [float(r[0]), str(r[1])]),
	])


## Walks `people` for 30 s at 10 frames a second through LifeWatch.own_acts -> [share reacting, {kind: count}].
static func _score(LifeWatch, people: Array, subject: Vector2) -> Array:
	var any := 0
	var kinds := {}
	for p: Dictionary in people:
		var pos: Vector2 = p.at
		var d0 := pos.distance_to(subject)
		var own := {}
		for f in 300:
			var t := f * 0.1
			var moving: bool = t >= float(p.off) and float(p.speed) > 0.0
			if moving and float(p.stop) > 0.0 and pos.distance_to(subject) <= float(p.stop):
				moving = false
			var vel: Vector2 = (p.dir as Vector2) * float(p.speed) if moving else Vector2.ZERO
			var forward: Vector2 = (p.dir as Vector2) if moving and not p.backs else (subject - pos).normalized()
			var clip: String = str(p.clip) if t >= float(p.off) else "Idle"
			if not moving and clip.begins_with("Walk"):
				clip = "Idle"
			for o: String in LifeWatch.own_acts({"since": t, "clip": clip, "clip0": "Idle", "owner": p.owner,
					"nod": p.talks and fmod(t, 4.0) < 0.5, "wave": false, "line": p.talks and fmod(t, 6.0) < 2.0,
					"pos": pos, "vel": vel, "forward": forward, "subject": subject, "d0": d0}):
				own[o] = true
			pos += vel * 0.1
		if not own.is_empty():
			any += 1
		for o: String in own:
			kinds[o] = int(kinds.get(o, 0)) + 1
	return [float(any) / people.size(), kinds]


## The reviewer's condition for CV 0.5 (round 3): conveyors with a little jitter (1.5 s apart +-0.5 s) are still flagged,
## at 8, 12 and 20 units, every draw.
static func _ends_flag_jittered_conveyors() -> PackedStringArray:
	var LifeWatch = load("res://scripts/studio/news/life_watch.gd")
	var missed: Array = []
	var cvs: Array = []
	for n: int in [8, 12, 20]:
		for draw in 20:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + n * 100 + draw
			var lefts: Array = []
			var moves: Array = []
			for i in n:
				lefts.append([maxf(0.0, 1.5 * i + rng.randf_range(-0.5, 0.5)), i])
				moves.append(rng.randf_range(0.0, 8.0))
			var row: Dictionary = LifeWatch.end_row(_end_of("happening:argument:apart", lefts, moves))
			cvs.append(row.gap_cv)
			if _departure_misses(row).is_empty():
				missed.append("%d units, draw %d: cv %.2f, spread %.1f" % [n, draw, float(row.gap_cv), float(row.spread_s)])
	cvs.sort()
	return PackedStringArray([_check(missed.is_empty(), "jittered conveyors (1.5 s +-0.5 s; 8, 12, 20 units; 20 draws each) all flagged: cv at most %.2f%s"
		% [float(cvs[-1]), "" if missed.is_empty() else ", NOT flagged: " + str(missed)])])


## Real ends, recorded by the news probe and replayed through the same measure: each still flagged by what the review
## asked of it (round 3): the pillory before the reactions by its freeze or the reactions it lacks, the old evening and
## the old pillory by exodus, gap CV or spread. fixtures/real_ends.json says where each was recorded.
static func _real_ends_flagged() -> PackedStringArray:
	var LifeWatch = load("res://scripts/studio/news/life_watch.gd")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/studio/news/fixtures/real_ends.json"))
	var out := PackedStringArray()
	if data == null:
		return PackedStringArray([_check(false, "real ends: fixtures/real_ends.json unreadable")])
	for f: Dictionary in data.ends:
		var extra := {"kin_present": int(f.get("kin_present", 0)), "kin_reached": bool(f.get("kin_reached", false))}
		var row: Dictionary = LifeWatch.end_row(LifeWatch.end_from_raw(str(f.kind), f.raw, float(f.watch), extra))
		var musts := str(f.must).split("|")
		var hit: Array = (row.missed as Array).filter(func(m: String) -> bool:
			return Array(musts).any(func(k: String) -> bool: return m.begins_with(k)))
		out.append(_check(not hit.is_empty(), "%s (%d people): flagged by %s; all it misses %s"
			% [str(f.what).get_slice(" (", 0), int(row.members), str(hit), str(row.missed)]))
	return out
