extends Node
## Dev-only command-line helpers (after `--`):
##   --shot=path.png   save a screenshot after ~180 frames, then quit
##   --time=0.5        start at this time of day
##   --walk=x,y        hold the joystick in this direction

@export var day_night: Node

var _shot_path := ""
var _frames := 0


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--time="):
			day_night.time_of_day = float(arg.trim_prefix("--time="))
		elif arg.begins_with("--walk="):
			var v := arg.trim_prefix("--walk=").split(",")
			Controls.joystick = Vector2(float(v[0]), float(v[1]))
	if _shot_path == "":
		set_process(false)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 180:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()
