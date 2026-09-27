extends CanvasLayer
## Development HUD: FPS and worst frame, the 30/60 FPS toggle and a skip-time button.

@export var day_night: Node

const MARGIN := Vector2(64, 24)   # clear of the iPhone's rounded corners and Dynamic Island

var _fps_label: Label
var _cap_button: Button
var _worst := 0.0
var _worst_shown := 0.0
var _timer := 0.0


func _ready() -> void:
	var joystick := Control.new()
	joystick.set_script(preload("res://scripts/ui/joystick.gd"))
	add_child(joystick)

	_fps_label = Label.new()
	_fps_label.position = MARGIN
	_fps_label.add_theme_font_size_override("font_size", 22)
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_fps_label.add_theme_constant_override("outline_size", 6)
	add_child(_fps_label)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.position = Vector2(-MARGIN.x, MARGIN.y)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_cap_button = _make_button(row, "")
	_cap_button.pressed.connect(_toggle_cap)
	_make_button(row, "Time +").pressed.connect(func() -> void: day_night.skip(0.125))
	_refresh_cap()


func _process(delta: float) -> void:
	_worst = maxf(_worst, delta)
	_timer += delta
	if _timer >= 1.0:
		_worst_shown = _worst
		_worst = 0.0
		_timer = 0.0
	_fps_label.text = "%d fps · worst %d ms" % [Engine.get_frames_per_second(), roundi(_worst_shown * 1000.0)]


func _toggle_cap() -> void:
	Settings.set_fps_cap(60 if Settings.fps_cap == 30 else 30)
	_refresh_cap()


func _refresh_cap() -> void:
	_cap_button.text = "%d FPS" % Settings.fps_cap


func _make_button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(120, 56)
	b.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.05, 0.07, 0.12, 0.55 if state != "pressed" else 0.8)
		box.set_corner_radius_all(16)
		box.border_color = Color(1, 1, 1, 0.25)
		box.set_border_width_all(1)
		b.add_theme_stylebox_override(state, box)
	parent.add_child(b)
	return b
