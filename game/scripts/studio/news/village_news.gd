extends Node
## The village's news, live (plan VILLAGE-LIFE-AND-NEWS section 5, #10). Once a game minute it reads what the rules
## logged and the happenings' phases, threads them into stories (news/stories.gd), and decides how the player knows of
## each (news/unbound_news.gd): seen or heard from where they stand, announced by the bell, or by word later. What the
## player knows is kept in the save (v.runtime.news: only that; the stories are rebuilt from the log on load). The
## notice board (news/board.gd) shows the desk; when word of a crime reaches the player it becomes a weak clue in the
## rules' own record of what they know (world_actions.gd learn), so news can be acted on at a hearing.
const Stories := preload("res://scripts/studio/news/stories.gd")
const UnboundNews := preload("res://scripts/studio/news/unbound_news.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const WorldActions := preload("res://scripts/studio/village/sim/world_actions.gd")

signal changed                  # the desk changed (the board redraws)

const EVERY := 0.5              # seconds between looks (a game minute)
const NEAR := 40.0              # metres: a story still going on this near counts for more

var news := Stories.new()
var desk: Array = []            # what the board shows now (stories.gd desk)
var lines := 0                  # new lines put on the desk (a measure: the news probe)
var line_minutes: Array[int] = []   # the game minute of each (a measure: never two within the desk's gap)
var _cursor := 0
var _phase_seen := {}           # phase item id -> true
var _word := {}                 # story id -> the game minute word of it reaches the player
var _left := 0.0
var _shown := {}                # story id -> the update it was last shown at (to count new lines)
var _player: Node3D


func _ready() -> void:
	add_to_group("news")                  # the notice board and the edge cues find their source here
	_player = get_tree().get_first_node_in_group("player")
	if VillageSession.village != null:
		restore(VillageSession.village)


## From the save: what the player knew, and the stories rebuilt from the log (nothing is new again).
func restore(v) -> void:
	news = Stories.new()
	var saved: Dictionary = v.runtime.get("news", {})
	news.restore_known(saved)
	_word.clear()
	for key: String in saved.get("word", {}):
		_word[int(key)] = int(saved.word[key])
	var now := int(v.runtime.now)
	# in the order they came live: by minute, a minute's events before the phases begun in it (look() takes them so)
	var all: Array = []
	for item: Dictionary in UnboundNews.items(v, 0):
		all.append([int(item.minute), 0, int(item.id), item])
	for h: Dictionary in View.happenings(v):
		for item: Dictionary in UnboundNews.phase_items(v, h, now):
			all.append([int(item.minute), 1, int(item.id), item])
			_phase_seen[int(item.id)] = true
	all.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] or (x[0] == y[0] and (x[1] < y[1] or (x[1] == y[1] and x[2] < y[2]))))
	news.rebuilding = true
	for row: Array in all:
		news.add(row[3])
	news.rebuilding = false
	_cursor = View.event_count(v)
	for sid: int in news.known:
		_shown[sid] = int(news.known[sid].shown)
	desk = news.desk(now, _worth)


func _process(delta: float) -> void:
	var v = VillageSession.village
	if v == null:
		return
	_left -= delta
	if _left > 0.0:
		return
	_left = EVERY
	look(v)


## One look: new events and phases in, word that has reached the player, the desk.
func look(v) -> void:
	var now := int(v.runtime.now)
	var present: bool = v.runtime.get("player", {}).get("present", false)
	var eye := Vector2(_player.global_position.x, _player.global_position.z) if _player != null else Vector2.INF
	for item: Dictionary in UnboundNews.items(v, _cursor):
		_take(v, item, eye, present, now)
	_cursor = View.event_count(v)
	for h: Dictionary in View.happenings(v):
		for item: Dictionary in UnboundNews.phase_items(v, h, now):
			if not _phase_seen.has(int(item.id)):
				_phase_seen[int(item.id)] = true
				_take(v, item, eye, present, now)
	if present:
		for sid: int in _word.keys():
			if now >= int(_word[sid]):
				_word.erase(sid)
				if not news.known.has(sid):
					news.know(sid, "word", now)
					_learn(v, sid)
	var before := JSON.stringify(desk)
	desk = news.desk(now, _worth)
	for line: Dictionary in desk:
		var sid := int(line.story)
		var shown := int(news.known[sid].shown)
		if int(_shown.get(sid, -1)) != shown:
			_shown[sid] = shown
			lines += 1
			line_minutes.append(now)
	var saved := news.known_state()
	var word := {}
	for sid: int in _word:
		word[str(sid)] = int(_word[sid])
	saved["word"] = word
	v.runtime["news"] = saved
	if JSON.stringify(desk) != before:
		changed.emit()


func _take(v, item: Dictionary, eye: Vector2, present: bool, now: int) -> void:
	item.how = UnboundNews.how(item, eye, present)
	var sid := news.add(item)
	if item.how.is_empty():
		var after := UnboundNews.word_after(item)
		if after >= 0 and not news.known.has(sid) and not _word.has(sid):
			_word[sid] = now + after
	elif str(item.key).begins_with("crime:"):
		_learn(v, sid)


## Word (or the bell) of a crime: what people are saying becomes a weak clue the player holds (it may name the wrong one).
func _learn(v, sid: int) -> void:
	var story: Dictionary = news.stories.get(sid, {})
	var key := str(story.get("key", ""))
	if not key.begins_with("crime:") or str(news.known.get(sid, {}).get("how", "")) == "seen":
		return                               # (what the player saw is already theirs: crime.gd player_witness)
	var crime := int(key.trim_prefix("crime:"))
	var said := View.said_culprit(v, crime)
	if said < 0:
		return
	var req := {"action_id": "learn:%d:%d" % [crime, said], "player_id": "player:local", "village_id": v.runtime.village,
		"logical_time": v.runtime.now, "verb": "learn", "target": said, "parameters": {"crime": crime}}
	WorldActions.act(v, req, {"distance_dm": 0})


## The game's weight for a story: going on and near, more; someone the player has met in it, more.
func _worth(story: Dictionary) -> float:
	var w := 1.0
	var v = VillageSession.village
	if _player != null and int(story.until) > int(v.runtime.now) and (story.at as Vector2) != Vector2.INF:
		if (story.at as Vector2).distance_to(Vector2(_player.global_position.x, _player.global_position.z)) <= NEAR:
			w *= 1.5
	for id in story.people:
		if int(id) >= 0 and View.toward_player(v, int(id)).met:
			w *= 1.3
			break
	return w



# ---------- what the board (news/board.gd) and the edge cues (news/edge_cues.gd) ask ----------

func header() -> String:
	var v = VillageSession.village
	return "%s  ·  %s" % [str(v.name), UnboundNews.mood(v)] if v != null else ""


## A story's lines, oldest first, and what someone there saw or heard (the rules' cue).
func thread(sid: int) -> Array[String]:
	var out: Array[String] = []
	var s: Dictionary = news.stories.get(sid, {})
	for item: Dictionary in s.get("items", []):
		var h := str(item.get("headline", ""))
		if not h.is_empty() and (out.is_empty() or out.back() != h):
			out.append(h)
	var first: Array = s.get("items", [])
	if not first.is_empty() and not str(first[0].get("line", "")).is_empty():
		out.append(str(first[0].line))
	return out


func read(sid: int) -> void:
	news.read(sid)


## The sounds the player can hear now (residents.gd stimuli: the happenings' voices, the bell).
func sounds() -> Array:
	var reg = get_parent().get("registry") if get_parent() != null else null
	if reg == null or _player == null or reg.get("stimuli") == null:
		return []
	var eye := Vector2(_player.global_position.x, _player.global_position.z)
	var out: Array = []
	for s: Dictionary in reg.stimuli.heard(eye):
		out.append({"id": int(s.id), "at": s.at, "kind": str(s.kind)})
	return out
