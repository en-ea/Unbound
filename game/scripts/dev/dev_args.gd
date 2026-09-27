extends Node
## Dev-only command-line helpers (after `--`):
##   --shot=path.png   save a screenshot after ~180 frames, then quit
##   --time=0.5        start at this time of day
##   --walk=x,y        hold the joystick in this direction
##   --touchtest       fake a finger drag on the left half, print the result, quit

@export var day_night: Node

var _shot_path := ""
var _frames := 0
var _touch_test := false


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
		elif arg == "--touchtest":
			_touch_test = true
	if _shot_path == "" and not _touch_test:
		set_process(false)


func _process(_delta: float) -> void:
	_frames += 1
	if _touch_test:
		_run_touch_test()
		return
	if _frames == 180:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _run_touch_test() -> void:
	var start := Vector2(250, 500)
	if _frames == 30:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = start
		t.pressed = true
		Input.parse_input_event(t)
	elif _frames > 30 and _frames < 40:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = start + Vector2(0, -10) * (_frames - 30)
		d.relative = Vector2(0, -10)
		Input.parse_input_event(d)
	elif _frames == 45:
		print("TOUCHTEST joystick=", Controls.joystick, " player=", get_node("../Player").global_position)
	elif _frames == 90:
		print("TOUCHTEST joystick=", Controls.joystick, " player=", get_node("../Player").global_position)
		get_tree().quit()
