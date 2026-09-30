extends Node
## Survives region replacement; live.gd owns disposable presentation.
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
var village: S.Village
var active := false
var background := false
var initial_minute := 432
var recovery_notice := ""

var _scene: Node = null   # the current region scene (for the Living village switch)

func _ready() -> void:
	process_priority = -50
	Settings.changed.connect(_on_settings)

## The Living village switch (Settings): off leaves Enea's village as it is; the village waits, unchanged.
func _on_settings() -> void:
	if not is_instance_valid(_scene):
		return
	if Settings.living_village and not active:
		attach(_scene)
	elif not Settings.living_village and active:
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
		Runtime.attach(village, initial_minute)
		if "--village-soon" in OS.get_cmdline_user_args():
			for _i in 150:
				Runtime.advance(village, Runtime.next_dawn(village))
				var chosen := -1
				for pending in village.pending:
					if pending.kind in ["pillory", "stocks", "hanging", "bonfire"]:
						chosen = pending.staging
						break
				if chosen >= 0:
					var e := Runtime.event_by_id(village, chosen)
					Runtime.advance(village, maxi(int(village.runtime.now), int(e.from)))
					break
	active = true
	var day_night := scene.get_node("WorldEnvironment")
	day_night.village_clock = true
	day_night.time_of_day = float(int(village.runtime.now) % 1440) / 1440.0
	if Region.current == "meadow":
		var live: Node = load("res://scripts/studio/village/live.gd").new()
		live.name = "VillageLive"
		scene.add_child(live)
	if "--village-rescue-test" in OS.get_cmdline_user_args() and not has_node("RescueProbe"):
		var probe: Node = load("res://scripts/studio/village/rescue_probe.gd").new()
		probe.name = "RescueProbe"
		add_child(probe)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--village-capture=") and not has_node("CaptureProbe"):
			var capture: Node = load("res://scripts/studio/village/capture_probe.gd").new()
			capture.name = "CaptureProbe"
			add_child(capture)
		if arg == "--village-checks" and not has_node("ChecksProbe"):
			var checks: Node = load("res://scripts/studio/village/checks_probe.gd").new()
			checks.name = "ChecksProbe"
			add_child(checks)
		if arg.begins_with("--village-webprobe=") and not has_node("WebProbe"):
			var web: Node = load("res://scripts/studio/village/web_probe.gd").new()
			web.name = "WebProbe"
			add_child(web)
		if arg.begins_with("--village-measure=") and not has_node("MeasureProbe"):
			var measure: Node = load("res://scripts/studio/village/measure_probe.gd").new()
			measure.name = "MeasureProbe"
			add_child(measure)

func _process(delta: float) -> void:
	if not active or village == null or background or Controls.locked or SaveGame.paused:
		return
	var r := village.runtime
	r.fraction += delta * 2.0 # One day = twelve real minutes.
	var minutes := int(r.fraction)
	if minutes > 0:
		r.fraction -= minutes
		Runtime.advance(village, int(r.now) + minutes)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		background = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		background = false

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
