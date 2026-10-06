extends Node
## The recent past, kept for a note: the last FRAMES frame times, the last SAMPLES ticks of whatever the game
## samples (twice a second: who is where, doing what), the last EVENTS things that happened, and the process's
## memory every MEMORY_EVERY seconds for the last MEMORY_KEPT samples. Every list is a fixed-size ring, so it costs
## the same after an hour as after a minute. Game-agnostic: the game hands it a sampler and calls event().
##
##   var rec := NoteRecorder.new(); rec.sampler = func() -> Variant: return [...]; add_child(rec)
##   rec.event("meeting", "Bram greets Wren")      ...   rec.snapshot()
##
## The OS's count of the process's memory (what shows a driver's allocations) is read on a worker thread: on Android
## it takes a child process and about 35 ms, which the game's own frames must never wait for. Each memory sample
## carries the latest such reading, at most one interval old ("os_s" says when it was read).

const FRAMES := 600            # 10 s at 60 fps
const SAMPLE_EVERY := 0.5      # s
const SAMPLES := 40            # 20 s
const EVENTS := 50
const MEMORY_EVERY := 10.0     # s
const MEMORY_KEPT := 60        # 10 minutes

var sampler: Callable          # () -> Variant: a small, JSON-friendly picture of now (or leave unset)

var _frames := PackedFloat32Array()
var _frame_at := 0
var _frames_seen := 0
var _samples: Array = []       # [seconds, sampler()]
var _events: Array = []        # [seconds, kind, text, data]
var _memory: Array = []        # see memory_now()
var _sample_left := 0.0
var _memory_left := 0.0
var _start_ms := Time.get_ticks_msec()
var _os_task := -1             # the worker reading the OS's numbers (-1: none)
var _os_last := {}             # its latest reading (behind _os_lock)
var _os_lock := Mutex.new()


func _ready() -> void:
	_frames.resize(FRAMES)
	process_mode = Node.PROCESS_MODE_PAUSABLE    # a frozen game (a note being written) adds nothing


func _exit_tree() -> void:
	if _os_task != -1:
		WorkerThreadPool.wait_for_task_completion(_os_task)
		_os_task = -1


func _process(delta: float) -> void:
	_frames[_frame_at] = delta * 1000.0
	_frame_at = (_frame_at + 1) % FRAMES
	_frames_seen += 1
	_sample_left -= delta
	if _sample_left <= 0.0:
		_sample_left += SAMPLE_EVERY      # (carried over, so the beat keeps time)
		if sampler.is_valid():
			_push(_samples, [seconds(), sampler.call()], SAMPLES)
	_memory_left -= delta
	if _memory_left <= 0.0:
		_memory_left += MEMORY_EVERY
		var m := memory_now(seconds(), false)
		_os_lock.lock()
		m.merge(_os_last)
		_os_lock.unlock()
		_push(_memory, m, MEMORY_KEPT)
		_read_os_later()


## Something worth knowing happened: kind (a short word), what (a line), data (small, JSON-friendly).
func event(kind: String, what: String, data: Variant = null) -> void:
	_push(_events, [seconds(), kind, what, data], EVENTS)


func seconds() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0


## Everything kept, oldest first, with the frame times summarised and listed. (Reads the OS's numbers now: a note
## is taken with the game frozen.)
func snapshot() -> Dictionary:
	var n := mini(_frames_seen, FRAMES)
	var times := PackedFloat32Array()
	for i in n:
		times.append(_frames[(_frame_at - n + i + FRAMES) % FRAMES])
	var sorted := times.duplicate()
	sorted.sort()
	return {"seconds": seconds(), "frames": {"count": n, "p50": _at(sorted, 0.5), "p90": _at(sorted, 0.9),
			"p99": _at(sorted, 0.99), "max": _at(sorted, 1.0), "ms": Array(times).map(func(x: float) -> float: return snappedf(x, 0.01))},
		"memory": _memory.duplicate(true), "memory_now": memory_now(seconds()),
		"samples": _samples.duplicate(true), "events": _events.duplicate(true)}


## The engine's own counters, and (with_os) what the OS counts for the process (os_memory()).
static func memory_now(at: float, with_os := true) -> Dictionary:
	var out := {"s": snappedf(at, 0.1), "static_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}
	if with_os:
		out.merge(os_memory())
	return out


## The process's resident and swapped memory as the OS counts it, in MB, where the OS says (Linux and Android:
## /proc/<pid>/status), else {}. Godot's file reader can see a /proc file as empty on Android, so there it asks cat.
## Blocking (about 35 ms on the S24 through cat): call it off the main thread, or while frozen.
static func os_memory() -> Dictionary:
	if not OS.get_name() in ["Android", "Linux"]:
		return {}
	var t0 := Time.get_ticks_usec()
	var out := {"os_from": "file"}
	var lines := PackedStringArray()
	var f := FileAccess.open("/proc/self/status", FileAccess.READ)
	if f != null:
		while not f.eof_reached():
			lines.append(f.get_line())
	if not "\n".join(lines).contains("VmRSS"):
		var said := []
		OS.execute("cat", ["/proc/%d/status" % OS.get_process_id()], said)
		lines = "\n".join(said).split("\n")
		out["os_from"] = "cat"
	for line in lines:
		for key: String in ["VmRSS", "VmSwap"]:
			if line.begins_with(key + ":"):
				out[key.to_lower() + "_mb"] = snappedf(int(line.get_slice(":", 1).strip_edges().get_slice(" ", 0)) / 1024.0, 0.1)
	out["os_ms"] = snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.01)
	return out


func _read_os_later() -> void:
	if not OS.get_name() in ["Android", "Linux"]:
		return
	if _os_task != -1:
		if not WorkerThreadPool.is_task_completed(_os_task):
			return                                  # the last one is still reading
		WorkerThreadPool.wait_for_task_completion(_os_task)
	var at := seconds()
	_os_task = WorkerThreadPool.add_task(func() -> void:
		var r := os_memory()
		r["os_s"] = snappedf(at, 0.1)
		_os_lock.lock()
		_os_last = r
		_os_lock.unlock())


static func _push(ring: Array, item: Variant, most: int) -> void:
	ring.append(item)
	if ring.size() > most:
		ring.pop_front()


static func _at(sorted: PackedFloat32Array, q: float) -> float:
	return snappedf(sorted[mini(sorted.size() - 1, int(sorted.size() * q))], 0.01) if sorted.size() > 0 else -1.0
