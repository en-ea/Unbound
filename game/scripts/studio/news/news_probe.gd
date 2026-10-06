extends Node
## Is the village lively where the player is, and does the news keep up? (plan VILLAGE-LIFE-AND-NEWS sections 8, 11)
##   godot --headless --fixed-fps 60 --path game -- --studio=village/live --news-probe=<real minutes> --test-save=<name>
## The player stands in the square (a real body, no input) while the game runs at SPEED; the probe watches what the
## village shows within SIGHT by day (07:00-21:00) and judges it as liveliness, not as "something happened":
##
##   quiet_gap_s        the longest stretch of daytime with nothing in view begun (real seconds); quiet_idle_s (a
##                      measure): the longest with nothing going on in view either (a long public act in view is not
##                      idle), and quiet_when: the game minutes the longest quiet began and ended
##   in_view_per_20     happenings begun in view per 20 real minutes of daytime: a staged scene (an incident, a hearing,
##                      a public act, a rite) or a happening (v.runtime.happenings); not a greeting in passing
##   people_median      people in a happening (the cast and those come to watch), the median; also by kind
##   top_share          the commonest kind's share of the happenings in view
##   outdoors_share     villagers whose day has them within NEAR of the player who are out of doors (drawn), by day
##   meetings_per_min   meetings in passing begun near the player (the light layer: a measure, not a gate)
##   board_per_20       new lines on the notice board per 20 minutes of play (news/village_news.gd); closest_lines_s
##                      the closest two came (real seconds); save_same: what the player knew survives a save exactly;
##                      board_box: the board's place on screen, clear of the hearts, the minimap and the thumb's area
##
## Prints NEWS GATES {json}, then NEWS PASS|FAIL <gate> for each gate (with --news-gates; without it the run is a
## baseline: the measures only), then NEWS complete. Quits with 0 only if every gate asked for passed.
##
## --news-meeting: a town meeting, watched from the square (sim/town_meeting.gd). At the start the village is made
## hungry (two houses in three emptied: the probe's doing, never the game's), so the next of the day's phases crosses
## the line and the elder calls a meeting; the run ends when it is over and prints NEWS MEETING {json}: when it was
## called and held, its outcome, the bell, the most people there, the speakers in their row, the board's lines. With
## --news-gates: NEWS PASS|FAIL for each of MEETING_GATES. With --test-save=<name> the village is saved just before
## the call (user://studio-test-<name>.json): a save near a crossing, for a look on a device.
const SPEED := 4.0
const SIGHT := 35.0          # metres: what the player can see happen
const NEAR := 30.0           # metres: whose doors the player stands among
const DAY_FROM := 420        # 07:00
const DAY_TO := 1260         # 21:00
const GATES := {"quiet_gap_s": 120.0, "in_view_per_20": 14.0, "kinds_in_view": 8, "people_median": 4.0, "top_share": 0.30,
	"board_per_20": 6.0, "board_most_per_20": 14.0, "closest_lines_s": 10.0, "outdoors_share": 0.7, "purpose_share": 0.8,
	"work_thing_share": 0.3, "walking_of_purposeful": 0.35}   # plan LIVELY-VILLAGE 2.1 (was VILLAGE-LIFE-AND-NEWS 8)
const CALENDAR := ["happening:market", "happening:service", "happening:moot"]   # on top of the targets: left out of them
const MEETING_GATES := {"people_most": 8, "speakers_in_row": 2}
const THUMB_TOP := 0.55          # share of the screen's height: below it, on the left half, is the joystick's thumb
const PHONE := Vector2(1560, 720)   # the S24 Ultra's screen in the game's units (1280x720 expanded to 19.5:9)
const LifeWatch := preload("res://scripts/studio/news/life_watch.gd")   # ends, purpose, village-scale, cost (plan
                                                                     # LIVELY-VILLAGE section 0)

var _minutes := 20.0
var _gates := false
var _t := 0.0                 # seconds of play (as a player at normal speed has them; the run goes SPEED times faster)
var _day_s := 0.0             # real seconds of daytime
var _started := false
var _seen := {}               # key -> {kind, at: real s, people, by_day}
var _last_begin := 0.0        # real seconds of daytime when something was last begun in view
var _quiet_most := 0.0
var _quiet_when := [0, 0]      # the game minutes the longest quiet stretch began and ended (where to look)
var _idle_since := 0.0         # real seconds of daytime when something was last going on in view
var _idle_most := 0.0
var _last_begin_minute := 0
var _outdoors := [0, 0]       # [drawn, all] near the player, sampled by day
var _sample_left := 0.0
var _meetings0 := -1
var _live: Node
var _frames := 0
var _next_note := 0.0
var _wall0 := Time.get_ticks_msec()
var _meeting := false          # --news-meeting
var _m := {}                   # what the meeting probe saw
var _board_seen: Array = []    # every line the board showed, in order (the meeting probe)
var _life: LifeWatch


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--news-probe="):
			_minutes = float(arg.trim_prefix("--news-probe="))
		elif arg == "--news-gates":
			_gates = true
		elif arg == "--news-meeting":
			_meeting = true
	seed(20261002)            # Enea's creatures draw from the engine's own random numbers
	print("NEWS probe ready: %.0f minutes" % _minutes)


func _process(delta: float) -> void:
	_live = get_tree().current_scene.get_node_or_null("VillageLive") if get_tree().current_scene != null else null
	if _live == null or VillageSession.village == null or _live.get("registry") == null:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not _started:
		_started = true
		Engine.time_scale = SPEED
		var sq: Vector2 = _live.registry.place("square")
		player.global_position = Vector3(sq.x + 2.0, player.global_position.y + 0.5, sq.y + 2.0)
		if _meeting:
			_make_hungry(VillageSession.village)
		return
	if player.has_method("heal_full"):
		player.call("heal_full")       # Enea's boars and wolves: a player standing still is not the village's business
	var real := delta               # (scaled by SPEED: seconds of play, as a player at normal speed would have had them)
	_t += real
	var v = VillageSession.village
	var minute := int(v.runtime.now) % 1440
	var by_day := minute >= DAY_FROM and minute < DAY_TO
	var eye := Vector2(player.global_position.x, player.global_position.z)
	if _life == null:
		_life = LifeWatch.new(_live)
	_life.step(v, _t, eye, minute, by_day)
	if _meetings0 < 0:
		_meetings0 = (_live.registry.meetings as Array).size()
	if by_day:
		_day_s += real
		if _day_s - _last_begin > _quiet_most:
			_quiet_most = _day_s - _last_begin
			_quiet_when = [_last_begin_minute, int(v.runtime.now)]
	_look(v, eye, by_day)
	if by_day:
		if _going_on(v, eye):
			_idle_since = _day_s
		_idle_most = maxf(_idle_most, _day_s - _idle_since)
	_sample_left -= real
	if by_day and _sample_left <= 0.0:
		_sample_left = 5.0
		_sample_outdoors(v, eye)
	_frames += 1
	if _t >= _next_note:
		_next_note += 60.0
		print("NEWS at %.0f s of play: game minute %d, frames %d, wall %.1f s" % [_t, int(v.runtime.now), _frames,
			(Time.get_ticks_msec() - _wall0) / 1000.0])
	if _meeting:
		_watch_meeting(v)
		return
	if _t >= _minutes * 60.0:
		_finish(v)


## Whatever has begun in view this frame: staged scenes (runtime events with a staging) and happenings.
func _look(v, eye: Vector2, by_day: bool) -> void:
	for e: Dictionary in v.runtime.events:
		var key := "event:%d" % int(e.id)
		if _seen.has(key) or e.phase != "active":
			continue
		var st: Dictionary = VillageSession.Runtime.staging(v, int(e.id))
		if st.is_empty():
			continue
		var at: Vector2 = _live.registry.place(str(st.get("place", "square")))
		if at.distance_to(eye) > SIGHT:
			continue
		var kind := "%s:%s" % [e.type, st.get("kind", "")]
		_begun(key, kind, (st.get("people", []) as Array).size(), by_day)
	# happenings the rules decided and the bodies played (residents.gd shown_happenings: presentation's own record)
	for h: Dictionary in _live.registry.get("shown_happenings"):
		var key := "happening:%d" % int(h.id)
		if _seen.has(key):
			_seen[key].people = maxi(int(_seen[key].people), int(h.people))
			continue
		if (h.at as Vector2).distance_to(eye) > SIGHT:
			continue
		_begun(key, "happening:%s" % h.kind, int(h.people), by_day)


## Something going on in view now: a staged scene active, or a happening being played.
func _going_on(v, eye: Vector2) -> bool:
	for e: Dictionary in v.runtime.events:
		if e.phase != "active":
			continue
		var st: Dictionary = VillageSession.Runtime.staging(v, int(e.id))
		if not st.is_empty() and (_live.registry.place(str(st.get("place", "square"))) as Vector2).distance_to(eye) <= SIGHT:
			return true
	for hid: int in _live.registry.runs:
		var run = _live.registry.runs[hid]
		if run.phase != "coming" and _live.registry._happening_at(v, run.record).distance_to(eye) <= SIGHT:
			return true
	return false


func _begun(key: String, kind: String, people: int, by_day: bool) -> void:
	_seen[key] = {"kind": kind, "at": _day_s, "people": people, "by_day": by_day}
	if by_day and _life != null:
		_life.begun(kind, _t)
	if by_day:
		_last_begin = _day_s
		_last_begin_minute = int(VillageSession.village.runtime.now)


func _sample_outdoors(v, eye: Vector2) -> void:
	if _life != null:
		_life.sample_purpose(v, eye)
	var reg = _live.registry
	for id: int in reg.bodies:
		var p = v.people[id]
		if not p.alive or not p.present:
			continue
		var m = reg._movers.get(id)
		if m == null or (m.pos as Vector2).distance_to(eye) > NEAR:
			continue
		_outdoors[1] += 1
		if (reg.bodies[id] as Node3D).visible and not m.indoors:
			_outdoors[0] += 1


func _finish(v) -> void:
	set_process(false)
	Engine.time_scale = 1.0
	var day_seen: Array = _seen.values().filter(func(s: Dictionary) -> bool: return s.by_day and not _calendar(str(s.kind)))
	var kinds := {}
	var people_by := {}
	var people: Array = []
	for s: Dictionary in day_seen:
		kinds[s.kind] = int(kinds.get(s.kind, 0)) + 1
		(people_by.get_or_add(s.kind, []) as Array).append(int(s.people))
		people.append(int(s.people))
	var top := 0
	for k: String in kinds:
		top = maxi(top, int(kinds[k]))
	var medians := {}
	for k: String in people_by:
		medians[k] = _median(people_by[k])
	var per20 := 20.0 * 60.0 / maxf(_day_s, 1.0)
	var g := {
		"real_minutes": snappedf(_t / 60.0, 0.1), "day_minutes": snappedf(_day_s / 60.0, 0.1),
		"quiet_gap_s": snappedf(maxf(_quiet_most, _day_s - _last_begin), 0.1), "quiet_when": _quiet_when,
		"quiet_idle_s": snappedf(_idle_most, 0.1),
		"in_view": day_seen.size(), "in_view_per_20": snappedf(day_seen.size() * per20, 0.1), "kinds_in_view": kinds.size(),
		"people_median": _median(people), "people_median_by_kind": medians, "kinds": kinds,
		"top_share": snappedf(float(top) / maxf(day_seen.size(), 1.0), 0.01),
		"outdoors_share": snappedf(float(_outdoors[0]) / maxf(_outdoors[1], 1.0), 0.01), "outdoors_samples": _outdoors[1],
		"meetings_per_min": snappedf(float((_live.registry.meetings as Array).size() - _meetings0) / maxf(_t / 60.0, 0.01), 0.1),
		"game_minutes": int(v.runtime.now),
		"decided": _decided(v),
		"kinds_per_20": _per_20(kinds, per20),
		"life": _life.report(_day_s) if _life != null else {},
		"cues": _cues(),
	}
	var news: Node = _live.get_node_or_null("VillageNews")
	if news != null:
		var mins: Array = news.line_minutes
		var closest := INF
		for i in range(1, mins.size()):
			closest = minf(closest, float(int(mins[i]) - int(mins[i - 1])) * 0.5)
		g["board_lines"] = int(news.lines)
		g["board_per_20"] = snappedf(float(news.lines) * 20.0 * 60.0 / maxf(_t, 1.0), 0.1)
		g["closest_lines_s"] = snappedf(closest, 0.1) if closest < INF else -1.0
		g["save_same"] = _save_same(news, g)
		g["board_box"] = _board_box()
		g["desk"] = (news.desk as Array).map(func(l: Dictionary) -> String: return "%s (%s)" % [l.headline, l.how])
	print("NEWS GATES " + JSON.stringify(g))
	var failed := 0
	if _gates:
		failed += _gate(float(g.quiet_gap_s) <= GATES.quiet_gap_s, "quiet_gap_s %.0f <= %.0f" % [g.quiet_gap_s, GATES.quiet_gap_s])
		failed += _gate(float(g.in_view_per_20) >= GATES.in_view_per_20, "in_view_per_20 %.1f >= %.0f (calendar kinds left out)" % [g.in_view_per_20, GATES.in_view_per_20])
		failed += _gate(int(g.kinds_in_view) >= GATES.kinds_in_view, "kinds_in_view %d >= %d" % [int(g.kinds_in_view), GATES.kinds_in_view])
		failed += _gate(float(g.people_median) >= GATES.people_median, "people_median %.1f >= %.0f" % [g.people_median, GATES.people_median])
		failed += _gate(float(g.top_share) <= GATES.top_share, "top_share %.2f <= %.2f" % [g.top_share, GATES.top_share])
		failed += _gate(float(g.get("board_per_20", 0.0)) >= GATES.board_per_20 and float(g.get("board_per_20", 0.0)) <= GATES.board_most_per_20,
			"board_per_20 %.1f in %.0f-%.0f" % [g.get("board_per_20", 0.0), GATES.board_per_20, GATES.board_most_per_20])
		failed += _gate(float(g.outdoors_share) >= GATES.outdoors_share, "outdoors_share %.2f >= %.2f" % [g.outdoors_share, GATES.outdoors_share])
		var life: Dictionary = g.life
		failed += _gate(float(life.get("purpose_share", 0.0)) >= GATES.purpose_share, "purpose_share %.2f >= %.2f" % [life.get("purpose_share", 0.0), GATES.purpose_share])
		failed += _gate(float(life.get("work_thing_share", 0.0)) >= GATES.work_thing_share, "work_thing_share %.2f >= %.2f (adults, 08:00-17:00)" % [life.get("work_thing_share", 0.0), GATES.work_thing_share])
		failed += _gate(float(life.get("walking_of_purposeful", 1.0)) <= GATES.walking_of_purposeful, "walking_of_purposeful %.2f <= %.2f" % [life.get("walking_of_purposeful", 1.0), GATES.walking_of_purposeful])
		failed += _gate(float(life.get("at_nothing_share", 1.0)) == 0.0, "at_nothing_share %.2f == 0 (farming, herding, eating at nothing)" % life.get("at_nothing_share", 1.0))
		var misses: Array = []
		var ends_n := 0
		for k: String in life.get("ends", {}):
			for row: Dictionary in life.ends[k].each:
				if int(row.members) < 3:
					continue
				ends_n += 1
				if not (row.missed as Array).is_empty():
					misses.append("%s(%d): %s" % [k, int(row.members), ", ".join(row.missed)])
		failed += _gate(misses.is_empty(), "every end meets its gates: %d ends, %d miss%s" % [ends_n, misses.size(), "" if misses.is_empty() else " - " + "; ".join(misses)])
		failed += _gate(float(g.get("closest_lines_s", -1.0)) < 0.0 or float(g.closest_lines_s) >= GATES.closest_lines_s,
			"closest_lines_s %.1f >= %.0f" % [g.get("closest_lines_s", -1.0), GATES.closest_lines_s])
		failed += _gate(g.get("save_same", false) == true, "save_same: what the player knew survives a save")
		failed += _gate(str(g.get("board_box", {}).get("clear", "")) == "yes", "board_box clear: %s" % str(g.get("board_box", {})))
	print("NEWS complete")
	get_tree().quit(0 if failed == 0 else 1)


# ---------- the meeting probe ----------

## Two houses in three emptied and their people hungry (as news_test.gd's hungry village): the next phase's pressures
## cross the line. Saved at once if a test save was named (a save near a crossing).
func _make_hungry(v) -> void:
	var Pressures = load("res://scripts/studio/village/sim/pressures.gd")
	Pressures.update(v)                                   # the levels as they stand (not news)
	var i := 0
	for hh in v.households:
		var mouths: int = Pressures._mouths(v, hh)
		if mouths == 0:
			continue
		hh.food = -6 * mouths if i % 3 != 2 else 25 * mouths
		i += 1
	for p in v.people:
		if p.alive and p.present and p.authored == "" and v.households[p.household].food < 0:
			p.hunger = 500
	_m = {"made_hungry_at": int(v.runtime.now)}
	var path := str(SaveGame.get("_path"))
	if path.begins_with("user://studio-test-"):         # (never the player's own save)
		SaveGame.save_game()
		var near := path.trim_suffix(".json") + "-near-crossing.json"
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(near))
		_m.save = ProjectSettings.globalize_path(near)   # (the autosave goes on writing the test save; this copy stays)


func _watch_meeting(v) -> void:
	var h: Dictionary = {}
	for r: Dictionary in v.runtime.get("happenings", []):
		if str(r.kind) == "meeting":
			h = r
	var news: Node = _live.get_node_or_null("VillageNews")
	if news != null:
		for line: Dictionary in news.desk:
			var said := "%s (%s)" % [line.headline, line.how]
			if not _board_seen.has(said):
				_board_seen.append(said)
	if h.is_empty():
		if _t > 240.0:
			_meeting_done(v, h)                  # no meeting called in four minutes of play
		return
	_m.called = int(h.called)
	_m.start = int(h.minute)
	_m.cause = str(h.cause)
	var run = _live.registry.runs.get(int(h.id))
	if run != null:
		_m.people_most = maxi(int(_m.get("people_most", 0)), int(run.people_seen))
		var in_row := 0
		for id: int in run._speakers:
			if (_live.registry._movers[id].pos as Vector2).distance_to(run._stand(id)) <= 1.6:
				in_row += 1
		_m.speakers_in_row = maxi(int(_m.get("speakers_in_row", 0)), in_row)
		var phases: Array = _m.get_or_add("phases", [])
		if phases.is_empty() or phases.back() != run.phase:
			phases.append(run.phase)
		if not str(run.ended).is_empty():
			_m.ended = str(run.ended)
	if int(v.runtime.now) >= int(h.ends) + 20:
		_meeting_done(v, h)


func _meeting_done(v, h: Dictionary) -> void:
	set_process(false)
	Engine.time_scale = 1.0
	_m.outcome = str(h.get("outcome", ""))
	_m.bell = _live.get("_rung").has(int(h.get("id", -1))) if not h.is_empty() else false
	_m.board = _board_seen
	_m.real_minutes = snappedf(_t / 60.0, 0.1)
	print("NEWS MEETING " + JSON.stringify(_m))
	var failed := 0
	if _gates:
		failed += _gate(not h.is_empty() and not _m.outcome.is_empty(), "a meeting called and decided (%s)" % _m.outcome)
		failed += _gate(_m.bell, "the bell rung for it")
		failed += _gate(int(_m.get("people_most", 0)) >= MEETING_GATES.people_most, "people_most %d >= %d" % [int(_m.get("people_most", 0)), MEETING_GATES.people_most])
		failed += _gate(int(_m.get("speakers_in_row", 0)) >= MEETING_GATES.speakers_in_row, "speakers_in_row %d >= %d" % [int(_m.get("speakers_in_row", 0)), MEETING_GATES.speakers_in_row])
		failed += _gate(_board_seen.any(func(s: String) -> bool: return s.begins_with("Town meeting")) and _board_seen.any(func(s: String) -> bool:
			return s.begins_with("The village agreed") or s.begins_with("A night watch") or s.begins_with("The meeting broke up")),
			"the board: the call and the outcome")
	print("NEWS complete")
	get_tree().quit(0 if failed == 0 else 1)


## The happenings the rules decided in the run, by kind, where from and how they ended.
func _decided(v) -> Dictionary:
	var out := {}
	for h: Dictionary in v.runtime.get("happenings", []):
		var key := "%s:%s:%s" % [h.kind, h.get("source", ""), str(h.path.back())]
		out[key] = int(out.get(key, 0)) + 1
	return out


## Saved and loaded (the village's own codec, through JSON as the save does), the news rebuilt from it knows the same.
func _save_same(news: Node, g: Dictionary) -> bool:
	var data = JSON.parse_string(JSON.stringify(VillageSession.to_data()))
	var copy = VillageSession.Save.from_data(data)
	if copy == null:
		return false
	var again: Node = load("res://scripts/studio/news/village_news.gd").new()
	again.restore(copy)
	var a: Dictionary = news.news.known_state()
	var b: Dictionary = again.news.known_state()
	var diff: Array = []
	if int(a.last_line) != int(b.last_line):
		diff.append("last_line %d / %d" % [a.last_line, b.last_line])
	for key: String in a.known:
		if JSON.stringify(a.known[key]) != JSON.stringify(b.known.get(key, {})):
			diff.append("known %s: %s / %s" % [key, JSON.stringify(a.known[key]), JSON.stringify(b.known.get(key, {}))])
	for key: String in b.known:
		if not a.known.has(key):
			diff.append("known %s only after loading" % key)
	for sid: int in news.news.known:
		var live_head := str(news.news.stories.get(sid, {}).get("headline", ""))
		var again_head := str(again.news.stories.get(sid, {}).get("headline", "(none)"))
		if live_head != again_head:
			var items: Array = (news.news.stories.get(sid, {}).get("items", []) as Array).map(func(it: Dictionary) -> String:
				return "%d@%d>%d" % [int(it.id), int(it.minute), int(again.news._of_item.get(int(it.id), -1))])
			diff.append("story %d (%s): \"%s\" / \"%s\"; items id@minute>story after loading: %s" % [sid,
				str(news.news.stories.get(sid, {}).get("key", "")), live_head, again_head, ", ".join(items)])
	again.free()
	if not diff.is_empty():
		g["save_diff"] = diff.slice(0, 4)
	return diff.is_empty()


## Where the board sits on the phone's screen (one line, as it opens on something new): inside the screen, under the
## tracker, clear of the hearts, the buffs, the minimap and the joystick's thumb (the left half below THUMB_TOP). The
## headless window is not the phone's, so the parts anchored top left are taken as they are and the minimap (top
## right) is placed from the phone's right edge. Open (three lines, by a tap) it is a measure: open_bottom_share.
func _board_box() -> Dictionary:
	var hud := get_tree().get_first_node_in_group("hud")
	var board: Control = hud.get_node_or_null("NewsBoard") if hud != null else null
	if board == null:
		return {"clear": "no board"}
	board.set("_folded", false)
	board.set("_open", false)
	board.call("_refresh")
	board.reset_size()
	var screen := Rect2(Vector2.ZERO, PHONE)
	var box := Rect2(board.position, board.get_combined_minimum_size())
	var clashes: Array = []
	if not screen.encloses(box):
		clashes.append("off screen")
	var parts := {}
	var hearts = hud.get("_hearts")
	if hearts is Control:
		var hp: Vector2 = hearts.get("_push")
		parts["hearts"] = Rect2(Vector2(66, 76) + hp, Vector2(int(hearts.get("_max")) * 34.0, 30.0))   # (ui/hearts.gd POS, GAP, SIZE)
	var map = hud.get("_map")
	if map is Control:
		parts["minimap"] = Rect2(Vector2(PHONE.x + (map as Control).offset_left, (map as Control).offset_top), (map as Control).size)
	for part: String in ["_tracker", "_buffs"]:
		var c = hud.get(part)
		if c is Control and (c as Control).visible:
			parts[part.trim_prefix("_")] = Rect2((c as Control).position, (c as Control).get_combined_minimum_size())
	for part: String in parts:
		if (parts[part] as Rect2).intersects(box):
			clashes.append(part)
	if box.position.x < screen.size.x * 0.5 and box.end.y > screen.size.y * THUMB_TOP:
		clashes.append("thumb")
	board.set("_open", true)
	board.call("_refresh")
	var open_end := board.position.y + board.get_combined_minimum_size().y
	board.set("_open", false)
	board.call("_refresh")
	return {"clear": "yes" if clashes.is_empty() else ",".join(clashes), "at": [int(box.position.x), int(box.position.y)],
		"size": [int(box.size.x), int(box.size.y)], "open_bottom_share": snappedf(open_end / screen.size.y, 0.01),
		"screen": [int(screen.size.x), int(screen.size.y)]}


func _gate(ok: bool, what: String) -> int:
	print(("NEWS PASS " if ok else "NEWS FAIL ") + what)
	return 0 if ok else 1


## What the village's reactions were cued by (village_reactions.gd): kind -> [cues, people reached]; and the reactions
## chosen, module -> times (a measure of what the village did, not a gate).
func _cues() -> Dictionary:
	var vr = _live.registry.get("village_reactions")
	if vr == null:
		return {}
	return {"by_kind": vr.counts, "chosen": vr.reacting.picked}


static func _per_20(kinds: Dictionary, per20: float) -> Dictionary:
	var out := {}
	for k: String in kinds:
		out[k] = snappedf(int(kinds[k]) * per20, 0.1)
	return out


static func _calendar(kind: String) -> bool:
	for k: String in CALENDAR:
		if kind.begins_with(k):
			return true
	return false


static func _median(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	var n := s.size()
	return float(s[n / 2]) if n % 2 == 1 else (float(s[n / 2 - 1]) + float(s[n / 2])) / 2.0
