extends Node
## What a player dragging the camera around costs: spins the camera rig a full turn twice at a fast
## drag speed and records every frame (raw timestamps). Lap 1 catches first-sight stutters (a
## material's shader compiling the first time it comes into view); lap 2 shows the steady cost of
## the heaviest direction. Dev argument --turntable[=deg_per_s] (debug builds), then quits.
## Result: log lines "TURNTABLE ..." and user://studio-turntable.txt.

const SETTLE := 8.0   # seconds for the game to load before turning

var rig: Node3D
var speed := 90.0     # degrees a second: a brisk drag
var _t := 0.0
var _last := 0
var _turned := 0.0
var _laps: Array = [[], []]            # frame ms per lap
var _by_sector: Array = [[], []]       # worst frame ms per 45-degree sector, per lap
var _slow: PackedStringArray = []      # every frame over 50 ms, and when


var _prev_objects := 0
var _prev_faded := 0
var _fader: Node        # the game's see-through fade for trees between camera and player
var _budget := {"scripts": [], "physics": [], "render cpu": []}   # every frame, for the medians


func _ready() -> void:
	_fader = get_tree().current_scene.get_node_or_null("OcclusionFader")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for lap in 2:
		var s: Array[float] = []
		s.resize(8)
		s.fill(0.0)
		_by_sector[lap] = s


func _process(delta: float) -> void:
	_t += delta
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last) / 1000.0
	_last = now
	if _t < SETTLE:
		return
	var lap := int(_turned / 360.0)
	if lap >= 2:
		_report()
		get_tree().quit()
		set_process(false)
		return
	_laps[lap].append(frame_ms)
	var objects := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	_budget["scripts"].append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_budget["physics"].append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_budget["render cpu"].append(RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()))
	var faded: int = _fader.get("_faded").size() if _fader and _fader.get("_faded") != null else -1
	if frame_ms > 50.0:
		# Where the slow frame went. The monitors describe the previous frame, which is the slow one.
		var vp := get_viewport().get_viewport_rid()
		_slow.append("%.0f ms at lap %d, %.0f deg, %.1f s: scripts %.1f, physics %.1f, render cpu %.1f, gpu %.1f, frame setup %.1f ms; objects %d (was %d), trees faded %d (was %d), nodes %d, video mem %d MB" % [
			frame_ms, lap + 1, fmod(_turned, 360.0), Time.get_ticks_msec() / 1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp),
			RenderingServer.get_frame_setup_time_cpu(), objects, _prev_objects, faded, _prev_faded,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576])
	_prev_objects = objects
	_prev_faded = faded
	var sector := int(fmod(_turned, 360.0) / 45.0)
	_by_sector[lap][sector] = maxf(_by_sector[lap][sector], frame_ms)
	_turned += speed * delta
	rig.rotation.y = deg_to_rad(_turned)


@warning_ignore("integer_division")
static func _stats(ms: Array) -> String:
	var v := ms.duplicate()
	v.sort()
	var n := v.size()
	return "%d frames, median %.1f ms, 95th %.1f ms, worst %.1f ms, over 50 ms: %d" % [n, v[n / 2], v[int(n * 0.95)], v[n - 1], v.filter(func(x: float) -> bool: return x > 50.0).size()]


func _report() -> void:
	var info := "draws %d, triangles %dk (at the end)" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000]
	# The game's own save, timed on its own. In play it runs on the main thread every 15 s; dev runs
	# switch it off (so none ran during the laps above), so it is switched on just for this.
	var saves := PackedStringArray()
	SaveGame.set("_enabled", true)
	for i in 3:
		var t0 := Time.get_ticks_usec()
		SaveGame.save_game()
		saves.append("%.1f" % ((Time.get_ticks_usec() - t0) / 1000.0))
	SaveGame.set("_enabled", false)
	var lines := PackedStringArray([
		"device: %s; %s; turning %.0f deg/s; %s" % [OS.get_model_name(), RenderingServer.get_current_rendering_method(), speed, info],
		"lap 1 (first sight): " + _stats(_laps[0]),
		"lap 2 (seen before): " + _stats(_laps[1]),
		"worst frame per 45-degree sector, lap 1: " + " ".join(PackedStringArray(_by_sector[0].map(func(x: float) -> String: return "%.0f" % x))),
		"worst frame per 45-degree sector, lap 2: " + " ".join(PackedStringArray(_by_sector[1].map(func(x: float) -> String: return "%.0f" % x))),
		"frames over 50 ms: " + ("none" if _slow.is_empty() else "; ".join(_slow)),
		"SaveGame.save_game() timed alone, 3 calls: %s ms" % ", ".join(saves),
		"every frame, median / 95th (ms): " + ", ".join(PackedStringArray(_budget.keys().map(func(k: String) -> String:
			var v: Array = _budget[k].duplicate()
			v.sort()
			return "%s %.1f / %.1f" % [k, v[v.size() / 2], v[int(v.size() * 0.95)]]))),
	])
	for s in lines:
		print("TURNTABLE ", s)
	var f := FileAccess.open("user://studio-turntable.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
