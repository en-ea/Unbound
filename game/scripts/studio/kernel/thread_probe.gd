extends Node
## The kernel on its own thread while the game plays (the intended architecture): records the
## game's frame times for a baseline window, then again while 500-year histories run back to back on
## a worker thread, and reports both. Dev argument --kernel-thread (debug builds), then quits.
## Result: log lines "KERNEL-THREAD ..." and user://studio-kernel-thread.txt.

const History := preload("res://scripts/studio/kernel/history.gd")
const Golden := preload("res://scripts/studio/kernel/golden.gd")

const SETTLE := 8.0      # seconds for the game to load and settle before measuring
const BASELINE := 10.0   # seconds measured without the kernel
const LOADED := 20.0     # seconds measured with the kernel running on a worker thread

var _t := 0.0
var _base: Array[float] = []
var _loaded: Array[float] = []
var _task := -1
var _stop := false
var _runs := 0
var _run_usec := 0
var _last := 0          # raw timestamps: Godot smooths `delta` by default, which can hide jitter
var _task_frame := 0


func _process(delta: float) -> void:
	_t += delta
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last) / 1000.0
	_last = now
	if _t < SETTLE:
		return
	if _t < SETTLE + BASELINE:
		_base.append(frame_ms)
		return
	if _task < 0:
		_task = WorkerThreadPool.add_task(_work, false, "world kernel")
		_task_frame = _loaded.size()
	if _t < SETTLE + BASELINE + LOADED:
		_loaded.append(frame_ms)
		return
	_stop = true
	WorkerThreadPool.wait_for_task_completion(_task)
	_report()
	get_tree().quit()
	set_process(false)


func _work() -> void:
	var i := 0
	while not _stop:
		var t0 := Time.get_ticks_usec()
		History.new(Golden.SEEDS[i % Golden.SEEDS.size()]).run(Golden.YEARS)
		_run_usec += Time.get_ticks_usec() - t0
		_runs += 1
		i += 1


@warning_ignore("integer_division")
static func _stats(ms: Array[float]) -> String:
	var v := ms.duplicate()
	v.sort()
	var n := v.size()
	return "%d frames, median %.1f ms, 95th %.1f ms, worst %.1f ms, over 50 ms: %d" % [n, v[n / 2], v[int(n * 0.95)], v[n - 1], v.filter(func(x: float) -> bool: return x > 50.0).size()]


func _report() -> void:
	var lines := PackedStringArray([
		"device: %s, %d cores; Godot %s" % [OS.get_model_name(), OS.get_processor_count(), Engine.get_version_info()["string"]],
		"frames without the kernel: " + _stats(_base),
		"frames with the kernel on a worker thread: " + _stats(_loaded),
		"kernel on the thread meanwhile: %d histories of 500 years, %.0f ms each on average" % [_runs, _run_usec / 1000.0 / maxi(_runs, 1)],
		"slowest loaded frame: #%d of %d (the thread started at #%d)" % [_loaded.find(_loaded.max()), _loaded.size(), _task_frame],
	])
	for s in lines:
		print("KERNEL-THREAD ", s)
	var f := FileAccess.open("user://studio-kernel-thread.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
