extends SceneTree
## Headless runner for the world kernel (no window, no game):
##   godot --headless --path game --script res://scripts/studio/kernel/run.gd -- [--conform] [--bench] [--chronicle=path] [--out=path]
## With no flags it runs --conform and --bench. Exits 1 if conformance fails.

const Bench := preload("res://scripts/studio/kernel/bench.gd")
const History := preload("res://scripts/studio/kernel/history.gd")
const Chronicle := preload("res://scripts/studio/kernel/chronicle.gd")
const Golden := preload("res://scripts/studio/kernel/golden.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var lines := PackedStringArray()
	var say := func(s: String) -> void:
		lines.append(s)
		print(s)
	var all := not (args.has("--conform") or args.has("--bench"))
	var ok := true
	say.call("Unbound world kernel (GDScript) - Godot %s, %s, %s" % [Engine.get_version_info()["string"], OS.get_name(), OS.get_processor_name()])
	if all or args.has("--conform"):
		ok = Bench.conform(say)
	if all or args.has("--bench"):
		Bench.bench(say)
	for arg in args:
		if arg.begins_with("--chronicle="):
			var f := FileAccess.open(arg.trim_prefix("--chronicle="), FileAccess.WRITE)
			f.store_string(Chronicle.text(History.new(Golden.CHRONICLE_SEED).run(Golden.YEARS)))
			f.close()
		elif arg.begins_with("--out="):
			var f := FileAccess.open(arg.trim_prefix("--out="), FileAccess.WRITE)
			f.store_string("\n".join(lines) + "\n")
			f.close()
	quit(0 if ok else 1)
