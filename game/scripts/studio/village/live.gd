extends Node
## The living village in the running game (studio): the village simulation runs a day at a time on the
## game's own clock, and every public act it makes is played on the stage at its hour, where the player can
## walk up to it and, while a rescue window is open, step in.
##
##   game clock (day_night.gd: 12 real minutes a day)
##        | midnight
##        v
##   Village.step_day(V) --> today's stagings --> queued by start minute
##        | the hour comes (start - LEAD)
##        v
##   stage.play(staging)    the player walks up; in a rescue phase: free / shield --> player_intervened
##        | finished
##        v
##   Justice.resolve_public(V, staging id, what the player did)    deaths, exiles and grudges land now
##
## The village runs live (V.live): its public acts wait for the stage (village-reference justice.mjs,
## resolvePublic). A month of history is lived first, a day per frame, so the village has its grudges and
## its dead before the player arrives.
## Dev argument --studio=village/live, with --village-seed=N, --village-days=30 (history), --village-soon
## (today's first event starts in a minute of game time) and --village-caption (a line naming what is on).

const Village := preload("res://scripts/studio/village/sim/village.gd")
const Content := preload("res://scripts/studio/village/sim/content.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")
const Stage := preload("res://scripts/studio/village/stage.gd")

const LEAD := 20              # game minutes before a staging's start that the stage opens (people leave home)
const MINUTES := 1440

var V                          # the village (sim/state.gd Village)
var _day_night: Node
var _history_left := 30
var _soon := false
var _last_tod := -1.0
var _queue: Array[Dictionary] = []
var _stage: Node3D = null
var _playing := -1             # the staging on the stage
var _did := {}                 # staging id -> what the player did ("free" outranks "shield")
var _caption: Label = null
var _log: PackedStringArray = []


static func on_device(tree: SceneTree) -> void:
	var live: Node = (load("res://scripts/studio/village/live.gd") as GDScript).new()
	live.name = "VillageLive"
	tree.root.add_child.call_deferred(live)


func _ready() -> void:
	var seed := 16838
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--village-seed="):
			seed = int(arg.trim_prefix("--village-seed="))
		elif arg.begins_with("--village-days="):
			_history_left = int(arg.trim_prefix("--village-days="))
		elif arg == "--village-soon":
			_soon = true
		elif arg == "--village-caption":
			_make_caption()
	V = Village.create_village(seed, {"pace": Content.LIVE_PACE, "live": true})
	_day_night = get_tree().current_scene.get_node_or_null("WorldEnvironment")
	_say("village %s (seed %d): living %d days of history" % [V.name, seed, _history_left])


func _process(_delta: float) -> void:
	if _day_night == null:
		_day_night = get_tree().current_scene.get_node_or_null("WorldEnvironment")
		return
	if _history_left > 0:
		_step_unseen()
		_history_left -= 1
		if _history_left == 0:
			_say("history done: day %d, %d people ever, %d events" % [V.day, V.people.size(), V.events.size()])
			if _soon:
				_new_day()
				if not _queue.is_empty():   # bring the clock to just before the first event
					_day_night.time_of_day = float(maxi(0, int(_queue[0]["start"]) - LEAD - 1)) / MINUTES
			_last_tod = _day_night.time_of_day
		return
	var tod: float = _day_night.time_of_day
	if tod < _last_tod:
		_new_day()
	_last_tod = tod
	var minute := int(tod * MINUTES)
	if _stage == null and not _queue.is_empty() and minute >= int(_queue[0]["start"]) - LEAD:
		_open(_queue.pop_front(), minute)
	if _caption != null:
		_caption.text = _caption_text(minute)


## A day nobody watches: every public act resolves as it was going to.
func _step_unseen() -> void:
	Village.step_day(V)
	while not V.pending.is_empty():
		Justice.resolve_public(V, int(V.pending[0]["staging"]), "")


func _new_day() -> void:
	var before: int = V.staging_count
	Village.step_day(V)
	_queue.clear()
	for st: Dictionary in V.stagings:
		if int(st["id"]) >= before:
			_queue.append(st)
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["start"]) < int(b["start"]) or (int(a["start"]) == int(b["start"]) and int(a["id"]) < int(b["id"])))
	_say("day %d: %d events today%s" % [V.day, _queue.size(), "" if _queue.is_empty() else " - first: %s at %s" % [_queue[0]["kind"], _clock(int(_queue[0]["start"]))]])


func _open(st: Dictionary, minute: int) -> void:
	_stage = Stage.new()
	_playing = int(st["id"])
	get_tree().current_scene.add_child(_stage)
	_stage.player_intervened.connect(_on_intervened.bind(_playing))
	_stage.finished.connect(_on_finished.bind(_playing))
	_stage.play(st, st["people"], 1.0)
	if minute > int(st["start"]):
		_stage.skip_to(float(minute))
	_say("on stage: %s at the %s (%s), %d people" % [st["kind"], st["place"], st["outcome"], (st["people"] as Array).size()])


func _on_intervened(kind: String, minute: int, id: int) -> void:
	if _did.get(id, "") != "free":
		_did[id] = kind
	_say("the player stepped in: %s at %s" % [kind, _clock(minute)])


func _on_finished(id: int) -> void:
	var did: String = _did.get(id, "")
	var resolved: bool = Justice.resolve_public(V, id, did)
	_say("staging %d ends; %s%s" % [id, "resolved" if resolved else "nothing pending (a festival or a rite)", "" if did.is_empty() else " - the player: " + did])
	_stage.queue_free()
	_stage = null
	_playing = -1


func _make_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	_caption = Label.new()
	_caption.position = Vector2(24, 140)
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.modulate = Color(1, 1, 1, 0.8)
	layer.add_child(_caption)
	add_child(layer)


func _caption_text(minute: int) -> String:
	var now := "%s day %d, %s" % [V.name, V.day, _clock(minute)]
	if _stage != null:
		return now + " - on now"
	if not _queue.is_empty():
		return now + " - next: %s at %s" % [_queue[0]["kind"], _clock(int(_queue[0]["start"]))]
	return now


func _clock(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


func _say(line: String) -> void:
	print("VILLAGE ", line)
	_log.append(line)
