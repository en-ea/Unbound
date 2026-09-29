extends Node
## Opt-in integrated measurement; includes cold arrival, body construction and ordinary game rendering.
var frames: Array[float] = []
var cold: Array[float] = []
var stage_cost: Array[float] = []
var draw_calls: Array[float] = []
var _last := 0
var _start := 0
var _seconds := 120.0
var _label := "integrated"
var _events := {}
var _opening := -1
var _samples := []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--village-measure="):
			_seconds = clampf(float(arg.trim_prefix("--village-measure=")), 30.0, 1200.0)
		if arg.begins_with("--measure-label="):
			_label = arg.trim_prefix("--measure-label=").validate_filename()
	if "--measure-uncapped" in OS.get_cmdline_user_args():
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# A bounded diagnostic only; normal settings remain untouched.
	if "--measure-no-msaa" in OS.get_cmdline_user_args():
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	_start = Time.get_ticks_usec()
	_last = _start
	var player := get_tree().get_first_node_in_group("player") as Node3D
	player.global_position = Vector3(1.5, WorldShape.new().height_at(1.5, 24.0), 24.0)
	get_tree().call_group("camera_rig", "snap")
	print("MEASURE start label=", _label, " boot_us=", _start, " device=", OS.get_model_name(), " cap=", Engine.max_fps,
		" viewport=", get_viewport().get_visible_rect().size, " scale=", get_viewport().scaling_3d_scale)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := float(now - _last) / 1000.0
	_last = now
	var elapsed := float(now - _start) / 1000000.0
	if elapsed < 20.0:
		cold.append(ms)
	else:
		frames.append(ms)
	var live := get_tree().current_scene.get_node_or_null("VillageLive")
	if live != null:
		if live._stage != null:
			stage_cost.append(float(live._stage.last_cost_us()) / 1000.0)
			if _opening != live._event:
				_opening = live._event
				_events[_opening] = {"real_seconds": elapsed, "minute": VillageSession.village.runtime.now}
		if int(elapsed / 10.0) >= _samples.size():
			var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			draw_calls.append(float(draws))
			var sample := {"seconds": elapsed, "draws": draws, "bodies": live.registry.bodies.size(), "event": live._event,
				"minute": VillageSession.village.runtime.now, "background": VillageSession.background,
				"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
				"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				"video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), "msaa": get_viewport().msaa_3d,
				"viewport": str(get_viewport().get_visible_rect().size)}
			_samples.append(sample)
			print("MEASURE sample ", JSON.stringify(sample)) # survives even a driver/process failure
	if elapsed < _seconds:
		return
	var result := {"label": _label, "seconds": elapsed, "device": OS.get_model_name(), "godot": Engine.get_version_info().string,
		"cap": Engine.max_fps, "cold_first_20s_ms": stats(cold), "steady_frame_ms": stats(frames),
		"stage_including_acquisition_ms": stats(stage_cost), "draw_calls": stats(draw_calls), "samples": _samples, "events": _events,
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "render_method": RenderingServer.get_current_rendering_method()}
	if live != null:
		result["resident_build_us"] = stats(live.registry.build_usec)
		result["resident_frame_us"] = stats(live.registry.frame_usec)
	var text := JSON.stringify(result, "  ")
	FileAccess.open("user://studio-measure-" + _label + ".json", FileAccess.WRITE).store_string(text)
	print("MEASURE result ", JSON.stringify(result))
	get_tree().quit()

static func stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0}
	var sorted := values.duplicate()
	sorted.sort()
	return {"count": sorted.size(), "p50": sorted[sorted.size() / 2], "p95": sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], "max": sorted[-1]}
