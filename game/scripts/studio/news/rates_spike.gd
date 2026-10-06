extends RefCounted
## How often the live village's rules make each kind of thing happen with the player in the village (plan
## LIVELY-VILLAGE section 0: the baselines; section 2.1: the census's gates). Pure rules, no bodies: SEEDS villages,
## DAYS game days each, advanced a game minute at a time as the live game advances them (session.gd), the player
## standing in the square. A game day is 12 real minutes, so 20 minutes of play is 1.67 game days.
##   godot --headless --path game --script res://scripts/studio/run.gd -- news/rates_spike
## Prints RATES <json> for each village, then RATES ALL <json>: per 20 minutes of play, each staged kind (an act the
## stage plays: a public act, a hearing, a rite, an incident), each happening kind, each event type; and for the
## village-scale ones (a public act, a hearing, a rite, a town meeting, and any kind named in VILLAGE), caused apart
## from the calendar (CALENDAR: the market, the service, the moot): the rate, the wait from each quarter hour of
## daytime play to the next caused one (minutes of play: p50, p80; the share within a 22-minute session), the
## longest drought (any kind, the nights in), the town meeting's rate and its longest gap. Then GATE lines: section
## 2.1's census targets, each village (read, not the job's verdict: the census itself is a measure).
## Only what the rules decide shows here: meetings in passing turned arguments (the bodies' request) do not.
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")
const SEEDS := [-1, 2, 3, 4, 5, 6]    # -1: the home village (save.gd HOME_SEED)
const DAYS := 20
const SESSION := 22.0               # minutes of play: Hilmi's session of 1 Oct
const VILLAGE := ["public", "hearing", "rite", "happening:meeting", "happening:feast", "happening:mourning",
	"happening:death_found", "happening:hue_and_cry", "happening:fire", "happening:funeral", "happening:enemy",
	"happening:market", "happening:service", "happening:moot"]
const CALENDAR := ["happening:market", "happening:service", "happening:moot"]
const PLAY_MIN := 0.5 / 60.0        # minutes of play a game minute


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var all_staged := {}
	var all_happenings := {}
	var all_events := {}
	var waits: Array = []
	var rows: Array = []
	var days_all := 0.0
	var t0 := Time.get_ticks_msec()
	for seed: int in SEEDS:
		var r := _one(Save.HOME_SEED if seed < 0 else seed)
		out.append("RATES %s" % JSON.stringify(r.row))
		rows.append(r.row)
		days_all += float(r.days)
		for k: String in r.staged:
			all_staged[k] = int(all_staged.get(k, 0)) + int(r.staged[k])
		for k: String in r.happenings:
			all_happenings[k] = int(all_happenings.get(k, 0)) + int(r.happenings[k])
		for k: String in r.events:
			all_events[k] = int(all_events.get(k, 0)) + int(r.events[k])
		waits.append_array(r.waits)
	waits.sort()
	var per20 := 20.0 / 12.0 / maxf(days_all, 1.0)
	out.append("RATES ALL %s" % JSON.stringify({"villages": SEEDS.size(), "game_days": days_all,
		"staged_per_20": _scale(all_staged, per20), "happenings_per_20": _scale(all_happenings, per20),
		"events_per_20": _scale(all_events, per20),
		"caused_wait_p50_min": _q(waits, 0.5), "caused_wait_p80_min": _q(waits, 0.8),
		"caused_in_a_session": _share_within(waits, SESSION),
		"wall_s": snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)}))
	out.append_array(gates(rows))
	out.append("PASS rates measured (a census, not a gate)")
	return out


## Section 2.1's census targets, each village: GATE ok|miss <what> <measured>.
static func gates(rows: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var mean := 0.0
	for row: Dictionary in rows:
		mean += float(row.caused_per_20) / rows.size()
		var s := "seed %d:" % int(row.seed)
		out.append(_gate(float(row.caused_per_20) >= 0.8, "%s caused village-scale per 20 min %.2f (0.8 or more)" % [s, float(row.caused_per_20)]))
		out.append(_gate(float(row.caused_sessions) >= 0.6, "%s sessions with a caused one %.2f (0.6 or more)" % [s, float(row.caused_sessions)]))
		out.append(_gate(float(row.caused_wait_p50) <= 14.0 and float(row.caused_wait_p80) <= 30.0,
			"%s caused wait p50 %.1f, p80 %.1f min (14 and 30 or less)" % [s, float(row.caused_wait_p50), float(row.caused_wait_p80)]))
		out.append(_gate(float(row.all_per_20) <= 2.5 and float(row.all_sessions) >= 0.75,
			"%s all village-scale per 20 min %.2f (2.5 or less), sessions %.2f (0.75 or more)" % [s, float(row.all_per_20), float(row.all_sessions)]))
		out.append(_gate(float(row.meeting_per_20) >= 0.3, "%s town meetings per 20 min %.2f (0.3 or more)" % [s, float(row.meeting_per_20)]))
		out.append(_gate(float(row.drought_min) < 100.0, "%s longest drought %.1f min of play (under 100); the meetings' longest gap %.1f"
			% [s, float(row.drought_min), float(row.meeting_gap_min)]))
	out.append(_gate(mean >= 1.0, "mean caused village-scale per 20 min %.2f (1.0 or more)" % mean))
	return out


static func _gate(ok: bool, what: String) -> String:
	return ("GATE ok   " if ok else "GATE miss ") + what


static func _one(seed: int) -> Dictionary:
	var v = Runtime.create(seed)
	var sq: int = v.pl_square
	Runtime.set_player(v, true, v.place_x[sq], v.place_z[sq])
	var start := int(v.runtime.now)
	var end := start + DAYS * 1440
	var ev0: int = v.events.size()
	var staged := {}
	var happenings := {}
	var counted := {}
	var village_at: Array = []        # [game minute, kind]
	while int(v.runtime.now) < end:
		Runtime.advance(v, int(v.runtime.now) + 1)
		var now := int(v.runtime.now)
		for e: Dictionary in v.runtime.events:
			if counted.has("e%d" % int(e.id)) or e.phase != "active":
				continue
			counted["e%d" % int(e.id)] = true
			var st: Dictionary = Runtime.staging(v, int(e.id))
			var kind := "%s:%s" % [e.type, str(st.get("kind", ""))]
			staged[kind] = int(staged.get(kind, 0)) + 1
			if _village(kind):
				village_at.append([now, kind])
		for h: Dictionary in v.runtime.get("happenings", []):
			if counted.has("h%d" % int(h.id)) or now < int(h.phases[0][1]):
				continue
			counted["h%d" % int(h.id)] = true
			var kind := "happening:%s" % str(h.kind)
			happenings[kind] = int(happenings.get(kind, 0)) + 1
			if _village(kind):
				village_at.append([int(h.phases[0][1]), kind])
	var events := {}
	for i in range(ev0, v.events.size()):
		events[v.events[i].type] = int(events.get(v.events[i].type, 0)) + 1
	village_at.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var caused: Array = village_at.filter(func(x: Array) -> bool: return not _calendar(str(x[1]))).map(func(x: Array) -> int: return int(x[0]))
	var all: Array = village_at.map(func(x: Array) -> int: return int(x[0]))
	var meetings: Array = village_at.filter(func(x: Array) -> bool: return str(x[1]).begins_with("happening:meeting")) \
		.map(func(x: Array) -> int: return int(x[0]))
	var waits := _waits(caused, start, end)
	var waits_all := _waits(all, start, end)
	var days := float(end - start) / 1440.0
	var per20 := 20.0 / 12.0 / days
	var sorted := waits.duplicate()
	sorted.sort()
	return {"days": days, "staged": staged, "happenings": happenings, "events": events, "waits": waits,
		"row": {"seed": seed, "days": days, "staged": staged, "happenings": happenings, "village_events": all.size(),
			"caused_per_20": snappedf(caused.size() * per20, 0.01), "all_per_20": snappedf(all.size() * per20, 0.01),
			"caused_sessions": _share_within(waits, SESSION), "all_sessions": _share_within(waits_all, SESSION),
			"caused_wait_p50": _q(sorted, 0.5), "caused_wait_p80": _q(sorted, 0.8),
			"meeting_per_20": snappedf(meetings.size() * per20, 0.01),
			"drought_min": _longest_gap(all, start, end), "meeting_gap_min": _longest_gap(meetings, start, end)}}


## The wait from each quarter hour of daytime play (07:00-21:00) to the next of `at` (game minutes, sorted), in minutes
## of play; none before the run's end: the rest of the run (a lower bound).
static func _waits(at: Array, start: int, end: int) -> Array:
	var out: Array = []
	var i := 0
	for m in range(start, end, 15):
		if m % 1440 < 420 or m % 1440 >= 1260:
			continue
		while i < at.size() and int(at[i]) < m:
			i += 1
		out.append(((int(at[i]) if i < at.size() else end) - m) * PLAY_MIN)
	return out


## The longest stretch with none of `at`, in minutes of play, the run's start and end included (lower bounds).
static func _longest_gap(at: Array, start: int, end: int) -> float:
	var last := start
	var worst := 0
	for t: int in at:
		worst = maxi(worst, t - last)
		last = t
	worst = maxi(worst, end - last)
	return snappedf(worst * PLAY_MIN, 0.1)


static func _share_within(waits: Array, limit: float) -> float:
	return snappedf(float(waits.filter(func(w: float) -> bool: return w <= limit).size()) / maxf(waits.size(), 1.0), 0.01)


static func _q(sorted: Array, q: float) -> float:
	return snappedf(float(sorted[mini(sorted.size() - 1, int(q * sorted.size()))]), 0.1) if not sorted.is_empty() else -1.0


static func _calendar(kind: String) -> bool:
	for k: String in CALENDAR:
		if kind.begins_with(k):
			return true
	return false


static func _village(kind: String) -> bool:
	for k: String in VILLAGE:
		if kind.begins_with(k):
			return true
	return false


static func _scale(d: Dictionary, f: float) -> Dictionary:
	var out := {}
	for k: String in d:
		out[k] = snappedf(int(d[k]) * f, 0.01)
	return out
