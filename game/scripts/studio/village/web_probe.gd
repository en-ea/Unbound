extends Node
## Web performance probe: what ordinary meadow play with the village on costs, for the phone's browser.
## Reached with the dev argument --village-webprobe=<seconds>, the length of the measurement after the warm-up
## (session.gd wires it like the other probes).
## In a web export the arguments come from GODOT_CONFIG in index.html: "args":["--","--village-webprobe=60"].
## It watches; it does not steer. Play (or stand) in the meadow for the length asked.
##
## Records, after a 10 s warm-up (its worst frame is kept as cold_max): frame times (median, p95, worst, how many
## over 50 ms), static and video memory, draw calls, how many resident bodies are visible (in the tree and in the
## camera's frustum), the residents' own cost (residents.gd frame_usec and build_usec) and the stage's
## (last_cost_us) while an act plays. At the end it also saves and reloads the village once, on this platform,
## and reports what that took (the autosave's cost, in bytes and milliseconds).
## When the time is up it prints one line to the console (a browser console shows it):
##   WEBPROBE {"frame_ms":{"p50":..,"p95":..,"max":..,"over50":..},"static_mb":..,...}
## and writes the same JSON to user://studio-webprobe-<label>.json. On desktop it then quits; in a browser it
## keeps running so the player is not thrown out (--webprobe-keep does the same on desktop).
## Options: --webprobe-label=<name>, --webprobe-at=x,z (put the player there first: the village square is 1.5,18),
## --webprobe-longsave=<days> (also drives a separate village that many game days, seed 1, and reports what saving
## and loading it costs here: the autosave of a long game, on this platform).
const WARMUP := 10.0

var frames: Array[float] = []
var cold_worst := 0.0
var process_ms: Array[float] = []
var draws: Array[float] = []
var visible_bodies: Array[float] = []
var resident_us: Array[float] = []
var stage_ms: Array[float] = []
var static_peak := 0.0
var video_peak := 0.0

var _seconds := 60.0
var _label := "web"
var _keep := false
var _long_days := 0
var _last := 0
var _start := 0
var _done := false


func _ready() -> void:
	process_priority = 1000   # after everything else in the frame, so the residents' cost for this frame is in
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--village-webprobe="):
			_seconds = clampf(float(arg.trim_prefix("--village-webprobe=")), 10.0, 3600.0)
		elif arg.begins_with("--webprobe-label="):
			_label = arg.trim_prefix("--webprobe-label=").validate_filename()
		elif arg.begins_with("--webprobe-longsave="):
			_long_days = clampi(int(arg.trim_prefix("--webprobe-longsave=")), 0, 1000)
		elif arg == "--webprobe-keep":
			_keep = true
		elif arg.begins_with("--webprobe-at="):
			var xz := arg.trim_prefix("--webprobe-at=").split(",")
			var player := get_tree().get_first_node_in_group("player") as Node3D
			if player != null and xz.size() == 2:
				player.global_position = Vector3(float(xz[0]), WorldShape.new().height_at(float(xz[0]), float(xz[1])), float(xz[1]))
				get_tree().call_group("camera_rig", "snap")
	_keep = _keep or OS.has_feature("web")
	_start = Time.get_ticks_usec()
	_last = _start


func _process(_delta: float) -> void:
	if _done:
		return
	var now := Time.get_ticks_usec()
	var ms := float(now - _last) / 1000.0
	_last = now
	var elapsed := float(now - _start) / 1000000.0
	if elapsed < WARMUP:
		cold_worst = maxf(cold_worst, ms)
		return
	frames.append(ms)
	process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	draws.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	static_peak = maxf(static_peak, Performance.get_monitor(Performance.MEMORY_STATIC))
	video_peak = maxf(video_peak, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var live := get_tree().current_scene.get_node_or_null("VillageLive") if get_tree().current_scene != null else null
	if live != null:
		visible_bodies.append(float(_count_visible(live)))
		var registry: Node = live.get("registry")
		var cost: Variant = registry.get("frame_usec") if registry != null else null
		if cost is Array and not cost.is_empty():
			resident_us.append(float(cost[-1]))
		var stage: Node = live.get("_stage")
		if stage != null and stage.has_method("last_cost_us"):
			stage_ms.append(float(stage.last_cost_us()) / 1000.0)
	if elapsed >= WARMUP + _seconds:
		_finish(live)


## Resident bodies you could see now: in the tree, and inside the camera's frustum.
func _count_visible(live: Node) -> int:
	var registry: Node = live.get("registry")
	var bodies: Variant = registry.get("bodies") if registry != null else null
	if not bodies is Dictionary:
		return 0
	var camera := get_viewport().get_camera_3d()
	var count := 0
	for id: Variant in bodies:
		var body := bodies[id] as Node3D
		if body == null or not is_instance_valid(body) or not body.is_visible_in_tree():
			continue
		if camera == null or camera.is_position_in_frustum(body.global_position + Vector3(0, 1.0, 0)):
			count += 1
	return count


func _finish(live: Node) -> void:
	_done = true
	var over := 0
	for ms in frames:
		if ms > 50.0:
			over += 1
	var session := VillageSession
	var builds: Array = []
	var registry: Node = live.get("registry") if live != null else null
	if registry != null and registry.get("build_usec") is Array:
		builds = registry.get("build_usec")
	var build_total := 0
	var build_worst := 0
	for us: int in builds:
		build_total += us
		build_worst = maxi(build_worst, us)
	var seconds := float(Time.get_ticks_usec() - _start) / 1000000.0 - WARMUP
	var summary := {
		"label": _label, "seconds": snappedf(seconds, 0.1), "frames": frames.size(), "fps": snappedf(frames.size() / maxf(seconds, 0.001), 0.1),
		"frame_ms": {"p50": _q(frames, 0.5), "p95": _q(frames, 0.95), "max": _q(frames, 1.0), "over50": over, "cold_max": snappedf(cold_worst, 0.1)},
		"process_ms": {"p50": _q(process_ms, 0.5), "p95": _q(process_ms, 0.95), "max": _q(process_ms, 1.0)},
		"static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1), "static_peak_mb": snappedf(static_peak / 1048576.0, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1), "video_peak_mb": snappedf(video_peak / 1048576.0, 0.1),
		"draws": {"p50": _q(draws, 0.5), "max": _q(draws, 1.0)},
		"bodies": {"resident": registry.get("bodies").size() if registry != null and registry.get("bodies") is Dictionary else 0,
			"visible_p50": _q(visible_bodies, 0.5), "visible_max": _q(visible_bodies, 1.0)},
		"residents_us": {"p50": _q(resident_us, 0.5), "p95": _q(resident_us, 0.95), "max": _q(resident_us, 1.0)},
		"build_us": {"n": builds.size(), "total": build_total, "max": build_worst},
		"stage_ms": {"n": stage_ms.size(), "p50": _q(stage_ms, 0.5), "max": _q(stage_ms, 1.0)},
		"village": {"active": session.active, "seed": session.village.seed if session.village != null else -1,
			"day": session.village.day if session.village != null else -1, "live_node": live != null},
		"platform": OS.get_name(), "model": OS.get_model_name(), "godot": Engine.get_version_info().string, "debug": OS.is_debug_build(),
		"renderer": RenderingServer.get_current_rendering_method(), "viewport": str(get_viewport().get_visible_rect().size),
	}
	summary["save"] = _save_cost(VillageSession.village)
	if _long_days > 0:
		var runtime: GDScript = VillageSession.Runtime
		var long_village: Object = runtime.create(1)
		var t := Time.get_ticks_usec()
		while int(long_village.runtime.now) < _long_days * 1440:
			runtime.advance(long_village, mini(_long_days * 1440, int(long_village.runtime.now) + 1440))
		var drive_ms := float(Time.get_ticks_usec() - t) / 1000.0
		summary["long_save"] = _save_cost(long_village)
		summary["long_save"]["days"] = _long_days
		summary["long_save"]["people"] = long_village.people.size()
		summary["long_save"]["events"] = long_village.events.size()
		summary["long_save"]["drive_ms"] = snappedf(drive_ms, 1.0)
	var text := JSON.stringify(summary)
	print("WEBPROBE ", text)
	var file := FileAccess.open("user://studio-webprobe-%s.json" % _label, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(summary, "  "))
		file.close()
	if _keep:
		queue_free()
	else:
		get_tree().quit()


## One save and one load of a village, as the game does them (SaveGame writes the JSON text of to_data).
func _save_cost(village: Object) -> Dictionary:
	if village == null:
		return {}
	var t := Time.get_ticks_usec()
	var text := JSON.stringify(VillageSession.Save.to_data(village))
	var save_ms := float(Time.get_ticks_usec() - t) / 1000.0
	var parsed: Variant = JSON.parse_string(text)
	t = Time.get_ticks_usec()
	var back: Object = null
	if parsed is Dictionary and VillageSession.Save.valid(parsed):
		back = VillageSession.Save.from_data(parsed)
	var load_ms := float(Time.get_ticks_usec() - t) / 1000.0
	return {"bytes": text.length(), "save_ms": snappedf(save_ms, 0.1), "load_ms": snappedf(load_ms, 0.1), "roundtrip": back != null}


## The q-quantile of the values (0 when there are none), to one decimal.
static func _q(values: Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return snappedf(sorted[mini(sorted.size() - 1, int(sorted.size() * q))], 0.1)
