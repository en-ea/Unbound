extends RefCounted
## Stories, and what the player knows of them (plan VILLAGE-LIFE-AND-NEWS section 5, #7). Generic: items with causes
## in, stories out, and a desk that decides what to show and when. It knows ids, kinds, severities and time, not
## villages: an adapter (news/unbound_news.gd) turns a game's events into items, and says how the player could know each.
##
## An item (one thing that happened):
##   {id: int (unique, rising: the source event's), causes: [ids], key: String (a story it belongs to whatever its causes,
##    e.g. "crime:12"; "" none), kind: String ("argument", "theft", "death", ...: the story's kind is its first item's),
##    phase: String, severity: 0..4, at: Vector2 (INF: nowhere in particular), people: [ids], minute: int (game),
##    headline: String (the story as it stands, after this), how: String (how the player knows of it: "seen", "heard",
##    "announced", "word"; "" not (yet)), until: int (game minute it goes on until; -1 over)}
##
##   var news := Stories.new()
##   news.add(item) -> story id     threads it: the story of its key, else of the first cause already in a story, else
##                                  a new one (its id: the item's id). A story: {id, kind, items: [item...], severity
##                                  (its worst), people, at, began, updated, headline, key}
##   news.know(story, how, minute)  the player knows it (the first way they knew is kept; a better one replaces word)
##   news.desk(now, worth_extra := Callable()) -> Array   what to show now, newest first: [{story, headline, how,
##                                  when (minute known or updated), kind, severity, at, until, new: bool}]; paces new
##                                  lines (GAP game minutes apart; grave ones sooner) and holds the rest back
##   news.read(story)               the player has seen its line (it is no longer new)
##   news.known_state() / news.restore_known(d)   what to save: only what the player knew and read; the stories
##                                  themselves are rebuilt from the game's log by adding its items again, with
##                                  news.rebuilding = true meanwhile (nothing is queued as new)
const KEEP := 60               # stories kept (the oldest go)
const ITEMS_KEPT := 12         # items kept in a story (its first, and the latest)
const GAP := 20                # game minutes between new lines on the board (ten real seconds) ...
const GRAVE_GAP := 20          # ... and for a grave one (severity 3 and up) the same: it goes before the others, but
                               # never sooner than the gap (two lines within ten seconds read as noise)
const SHOWN_FOR := 1440        # game minutes a story stays on the desk after it last changed (a game day)
const WORTH_BY_SEVERITY := [1.0, 2.0, 4.0, 7.0, 10.0]
const HOW_RANK := {"": 0, "word": 1, "announced": 2, "heard": 3, "seen": 4}

var stories := {}              # story id -> story
var _of_item := {}             # item id -> story id
var _of_key := {}              # key -> story id
var _order: Array[int] = []    # story ids, oldest first
var known := {}                # story id -> {how, at, read_upto (the minute of the last change the player saw), shown}
var _last_line := -1000000     # the minute the last new line went on the desk
var _queue: Array[int] = []    # story ids waiting for their new line
var rebuilding := false        # adding the log's items again after a load: what the player knew comes from the save


func add(item: Dictionary) -> int:
	var id := int(item.id)
	if _of_item.has(id):
		return int(_of_item[id])
	var sid := -1
	var key := str(item.get("key", ""))
	if not key.is_empty() and _of_key.has(key):
		sid = int(_of_key[key])
	if sid < 0:
		for c in item.get("causes", []):
			if _of_item.has(int(c)) and stories.has(int(_of_item[int(c)])):
				sid = int(_of_item[int(c)])
				break
	if sid < 0 or not stories.has(sid):
		sid = id
		stories[sid] = {"id": sid, "kind": str(item.kind), "items": [], "severity": 0, "people": [], "at": Vector2.INF,
			"began": int(item.minute), "updated": int(item.minute), "headline": "", "headline_at": -1000000, "key": key, "until": -1}
		_order.append(sid)
		while _order.size() > KEEP:
			var old: int = _order.pop_front()
			stories.erase(old)
			known.erase(old)
			_queue.erase(old)
	var s: Dictionary = stories[sid]
	var items: Array = s.items
	items.append(item)
	if items.size() > ITEMS_KEPT:
		items.remove_at(1)                  # the first stays (how it began), the latest stay
	s.severity = maxi(int(s.severity), int(item.get("severity", 0)))
	s.updated = maxi(int(s.updated), int(item.minute))
	if not str(item.get("headline", "")).is_empty() and int(item.minute) >= int(s.headline_at):
		s.headline = str(item.headline)      # the story as it stands: its latest item's (whatever order they came in)
		s.headline_at = int(item.minute)
	var at: Variant = item.get("at", Vector2.INF)
	if at is Vector2 and at != Vector2.INF:
		s.at = at
	s.until = int(item.get("until", -1))
	for p in item.get("people", []):
		if not (s.people as Array).has(int(p)):
			(s.people as Array).append(int(p))
	if not key.is_empty():
		_of_key[key] = sid
	_of_item[id] = sid
	var how := str(item.get("how", ""))
	if rebuilding:
		return sid
	if not how.is_empty():
		know(sid, how, int(item.minute))
	elif known.has(sid):
		_wants_line(sid)                    # a story the player knows changed: its new line waits its turn
	return sid


func know(sid: int, how: String, minute: int) -> void:
	if not stories.has(sid):
		return
	var k: Dictionary = known.get(sid, {})
	if k.is_empty():
		known[sid] = {"how": how, "at": minute, "read_upto": -1, "shown": -1}
		_wants_line(sid)
		return
	if int(HOW_RANK.get(how, 0)) > int(HOW_RANK.get(str(k.how), 0)):
		k.how = how                          # saw it after hearing word of it: now it is "seen"
	_wants_line(sid)


func read(sid: int) -> void:
	if known.has(sid) and stories.has(sid):
		known[sid].read_upto = int(stories[sid].updated)


## The notices to show now, newest first. `worth_extra` (story) -> float: the game's own weight (someone the player
## knows is in it, it is near): multiplies the worth that orders what is held back.
func desk(now: int, worth_extra := Callable()) -> Array:
	# one new line at a time: the worthiest waiting goes when its gap has passed (grave ones need a shorter gap)
	if not _queue.is_empty():
		var best := -1
		var best_worth := -INF
		for sid: int in _queue:
			if not stories.has(sid):
				continue
			var w := worth(sid, now, worth_extra)
			if w > best_worth:
				best_worth = w
				best = sid
		var grave := best >= 0 and int(stories[best].severity) >= 3
		if best >= 0 and now - _last_line >= (GRAVE_GAP if grave else GAP):
			_queue.erase(best)
			_last_line = now
			known[best].shown = int(stories[best].updated)
	var out: Array = []
	for sid: int in known:
		if not stories.has(sid):
			continue
		var s: Dictionary = stories[sid]
		var k: Dictionary = known[sid]
		if int(k.shown) < 0 or now - int(s.updated) > SHOWN_FOR:
			continue                         # not yet given its turn, or old news
		out.append({"story": sid, "headline": s.headline, "how": k.how, "when": maxi(int(k.at), int(k.shown)),
			"kind": s.kind, "severity": s.severity, "at": s.at, "until": s.until, "new": int(k.read_upto) < int(k.shown),
			"people": s.people})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.when) > int(y.when) or (int(x.when) == int(y.when) and int(x.story) > int(y.story)))
	return out


## How much a story is worth showing now: its severity, whether the player has not seen its latest, the game's weight,
## less for a kind shown lately (the same thing twice running reads as noise).
func worth(sid: int, now: int, worth_extra := Callable()) -> float:
	var s: Dictionary = stories[sid]
	var w: float = WORTH_BY_SEVERITY[clampi(int(s.severity), 0, 4)]
	var k: Dictionary = known.get(sid, {})
	if not k.is_empty() and int(k.read_upto) < int(s.updated):
		w *= 2.0
	if worth_extra.is_valid():
		w *= float(worth_extra.call(s))
	for other: int in known:
		if other != sid and stories.has(other) and stories[other].kind == s.kind and now - int(known[other].shown) < 240 \
				and int(known[other].shown) >= 0:
			w *= 0.6
	return w


func waiting() -> int:
	return _queue.size()


func known_state() -> Dictionary:
	var out := {}
	for sid: int in known:
		out[str(sid)] = known[sid].duplicate()
	return {"known": out, "last_line": _last_line}


func restore_known(d: Dictionary) -> void:
	known.clear()
	_queue.clear()
	for key: String in d.get("known", {}):
		var k: Dictionary = d.known[key]
		known[int(key)] = {"how": str(k.how), "at": int(k.at), "read_upto": int(k.read_upto), "shown": int(k.shown)}
	_last_line = int(d.get("last_line", -1000000))


func _wants_line(sid: int) -> void:
	if not _queue.has(sid):
		_queue.append(sid)
