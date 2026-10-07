extends Node
## Survives region replacement; live.gd owns disposable presentation.
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const UnboundNotes := preload("res://scripts/studio/notes/unbound_notes.gd")
var village: S.Village
var active := false
var background := false
var _background_saved := false
var initial_minute := 432
var recovery_notice := ""

var _scene: Node = null   # the current region scene (for the Living village switch)

func _ready() -> void:
	process_priority = -50
	Settings.changed.connect(_on_settings)
	UnboundNotes.install(get_tree())   # the note tool's log and recorder, for the whole game (notes/)

## The Living village switch (Settings): off leaves Enea's village as it is; the village waits, unchanged.
func _on_settings() -> void:
	if not is_instance_valid(_scene):
		return
	if Settings.living_village and not active:
		attach(_scene)
	elif not Settings.living_village and active:
		var checked := checked_save()
		if checked.get("handled",false) and not checked.get("accepted",false):return
		active = false
		var live := _scene.get_node_or_null("VillageLive")
		if live != null:
			live.queue_free()
		_scene.get_node("WorldEnvironment").village_clock = false

func attach(scene: Node) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--studio=") and arg != "--studio=village/live":
			return
	_scene = scene
	if not Settings.living_village:
		return
	if village == null:
		village = Runtime.Village.create_village(Save.new_seed(OS.get_cmdline_user_args()), {"pace": 10, "focus": true, "live": true})
		Runtime.attach(village, WorldClock.minute % 1440) # merge-enea: a new village joins at the world clock's time of day
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--village-day="):    # a probe from another weekday (plan LIVELY-VILLAGE 2.1)
				Runtime.advance(village, int(arg.trim_prefix("--village-day=")) * 1440 + initial_minute)
		var soon := _soon_kinds(OS.get_cmdline_user_args())
		if not soon.is_empty():
			for _i in 150:
				Runtime.advance(village, Runtime.next_dawn(village))
				var chosen := -1
				for pending in village.pending:
					if pending.kind in soon:
						chosen = pending.staging
						break
				if chosen >= 0:
					var e := Runtime.event_by_id(village, chosen)
					var lead := _soon_lead(OS.get_cmdline_user_args())
					Runtime.advance(village, maxi(int(village.runtime.now), int(e.from) if lead < 0 else int(e.deadline) - lead))
					break
	active = true
	var day_night := scene.get_node("WorldEnvironment")
	day_night.village_clock = true
	day_night.time_of_day = float(int(village.runtime.now) % 1440) / 1440.0
	if Region.current == "meadow":
		var live: Node = load("res://scripts/studio/village/live.gd").new()
		live.name = "VillageLive"
		scene.add_child(live)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--note-replay=") and not has_node("NoteReplay"):
			var replay: Node = load("res://scripts/studio/notes/note_replay.gd").new()
			replay.name = "NoteReplay"
			replay.folder = arg.trim_prefix("--note-replay=")
			add_child(replay)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--news-probe=") and not has_node("NewsProbe"):
			_probe("res://scripts/studio/news/news_probe.gd", "NewsProbe")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--body-probe=") and not has_node("BodyProbe"):
			_probe("res://scripts/studio/player/body_probe.gd", "BodyProbe")
		if arg.begins_with("--look-at=") and not has_node("LookAt"):
			_probe("res://scripts/studio/village/look_at.gd", "LookAt")
		if arg.begins_with("--stuck-probe") and not has_node("StuckProbe"):
			_probe("res://scripts/studio/creatures/stuck_probe.gd", "StuckProbe")
	if "--note-test" in OS.get_cmdline_user_args() and not has_node("NoteProbe"):
		_probe("res://scripts/studio/notes/note_probe.gd", "NoteProbe")
	if "--village-rescue-test" in OS.get_cmdline_user_args() and not has_node("RescueProbe"):
		_probe("res://scripts/studio/village/rescue_probe.gd", "RescueProbe")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--village-capture=") and not has_node("CaptureProbe"):
			_probe("res://scripts/studio/village/capture_probe.gd", "CaptureProbe")
		if arg == "--village-checks" and not has_node("ChecksProbe"):
			_probe("res://scripts/studio/village/checks_probe.gd", "ChecksProbe")
		if arg.begins_with("--village-webprobe=") and not has_node("WebProbe"):
			_probe("res://scripts/studio/village/web_probe.gd", "WebProbe")
		if arg.begins_with("--village-measure=") and not has_node("MeasureProbe"):
			_probe("res://scripts/studio/village/measure_probe.gd", "MeasureProbe")


## A probe's node from its script; a script that does not load ends the run at once (a parse error would otherwise
## leave a headless job waiting for its time limit with nothing running).
func _probe(path: String, node_name: String) -> void:
	var script := load(path) as Script
	if script == null or not script.can_instantiate():
		print("PROBE FAILED TO LOAD %s" % path)
		get_tree().quit(3)
		return
	var n: Node = script.new()
	n.name = node_name
	add_child(n)

func _process(delta: float) -> void:
	if not active or village == null or background or Controls.locked or SaveGame.paused:
		return
	# merge-enea: the world clock (studio/world/world_clock.gd) owns time; the village catches up to it, and a
	# village a probe moved ahead pulls the clock with it. One day is still twelve real minutes.
	var r := village.runtime
	var target: int = WorldClock.village_minute(str(r.village), int(r.now))
	if int(r.now) > target:
		WorldClock.not_behind(int(r.now) - (target - WorldClock.minute), float(r.fraction))
	elif int(r.now) < target:
		Runtime.advance(village, target)
	r.fraction = WorldClock.fraction

## `--village-soon`: the village is advanced to its first public act of these kinds (`--village-soon=pillory,stocks`:
## those only), for a probe or a look at one (plan LIVELY-VILLAGE: a pillory's end, watched). [] when not asked.
static func _soon_kinds(args: PackedStringArray) -> Array:
	for arg in args:
		if arg == "--village-soon":
			return ["pillory", "stocks", "hanging", "bonfire"]
		if arg.begins_with("--village-soon="):
			return Array(arg.trim_prefix("--village-soon=").split(",", false))
	return []

## `--village-soon-lead=<game minutes>`: with --village-soon, to that long before the act's end (its release, its
## fall) instead of its start: a look at how it ends. -1 when not asked.
static func _soon_lead(args: PackedStringArray) -> int:
	for arg in args:
		if arg.begins_with("--village-soon-lead="):
			return int(arg.trim_prefix("--village-soon-lead="))
	return -1

## Probe runs (they set `background` themselves when they test it): on the desktop, a click in another window must
## not freeze the village mid-check. Ordinary play and the phone keep freezing on focus out.
const PROBE_ARGS := ["--village-lively-test", "--village-provoke-test", "--village-rescue-test", "--village-checks",
	"--people-probe", "--people-targets", "--village-webprobe", "--village-capture", "--village-measure", "--note-test", "--note-replay", "--news-probe", "--news-meeting", "--look-at"]

func _probe_run() -> bool:
	for arg in OS.get_cmdline_user_args():
		for probe: String in PROBE_ARGS:
			if arg.begins_with(probe):
				return true
	return false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _probe_run():
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		quiesce_background()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		background = false
		_background_saved=false

## Both notification owners call here; whichever arrives first checks before availability flips.
## OS suspension cannot be refused: failure parks the original session queues for an honest retry.
func quiesce_background() -> void:
	if not _background_saved:
		_background_saved=SaveGame.save_game()==OK
	background=true

## Shared acceptance hook for normal saves and controlled exits. No truth/presentation export.
func checked_save() -> Dictionary:
	if village==null:return {"handled":false}
	var bridge := get_tree().get_first_node_in_group("people_bridge")
	if not is_instance_valid(bridge):return {"handled":false}
	var result: Dictionary=bridge.quiesce()
	result.handled=true
	return result

func to_data() -> Dictionary:
	return Save.to_data(village) if village != null else {}

func load_data(data: Dictionary) -> void:
	if village == null and not data.is_empty():
		village = Save.from_data(data)
		if village == null:
			push_warning("Village payload could not be restored; player progress retained.")

func reset() -> void:
	village = null
	active = false
