extends SceneTree
## Runs a studio spike headless and prints its report:
##   godot --headless --path game --script res://scripts/studio/run.gd -- village/decision_bench
## A spike is a script with `static func report() -> PackedStringArray` (and, for phones,
## `static func on_device(tree)`, reached with the dev argument --studio=<name>).
## Always quits, even when the spike has an error (exit code 1), so a broken spike can't hang.

var _ok := false


func _init() -> void:
	(func() -> void: quit(0 if _ok else 1)).call_deferred()
	var args := OS.get_cmdline_user_args()
	var spike: GDScript = load("res://scripts/studio/%s.gd" % args[0])
	for line: String in spike.report():
		print(line)
	_ok = true
