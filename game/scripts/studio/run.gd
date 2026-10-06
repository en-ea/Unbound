extends SceneTree
## Runs a studio spike headless and prints its report:
##   godot --headless --path game --script res://scripts/studio/run.gd -- village/decision_bench
## A spike is a script with `static func report() -> PackedStringArray` (and, for phones,
## `static func on_device(tree)`, reached with the dev argument --studio=<name>).
## Always quits, even when the spike has an error (exit code 1), so a broken spike can't hang.

var _ok := false


var _ran := false


## (Run in the first frame, the tree up and running, so a spike can put nodes in it: Engine.get_main_loop().root.)
## It quits after the run, with the run's result: an error inside the spike ends _run early with _ok still false.
## (Quitting from _init, as this once did, fixed the status at 1 before anything had run.)
func _process(_delta: float) -> bool:
	if not _ran:
		_ran = true
		_run()
		quit(0 if _ok else 1)
	return false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var spike: GDScript = load("res://scripts/studio/%s.gd" % args[0])
	var lines: PackedStringArray = spike.report()
	_ok = not lines.is_empty()
	var failed := 0
	for line: String in lines:
		print(line)
		if "FAIL" in line:
			_ok = false
			failed += 1
	print("RUN %s complete: %d lines, %d failed" % [args[0], lines.size(), failed])   # (a runner's completion marker:
	                                                                                # a spike that broke never prints it)
