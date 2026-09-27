extends CanvasLayer
## HUD: the joystick, FPS stats, and a small "Dev" menu (30/60 FPS, skip time, looks).

const LOOK_PICKER := preload("res://scripts/ui/look_picker.gd")
const MARGIN := Vector2(64, 24)   # clear of the iPhone's rounded corners and Dynamic Island

@export var day_night: Node
@export var character: CharacterVisual
@export var camera_rig: Node3D

var _fps_label: Label
var _joystick: Control
var _cap_button: Button
var _column: VBoxContainer
var _menu: VBoxContainer
var _worst := 0.0
var _worst_shown := 0.0
var _timer := 0.0


func _ready() -> void:
	_joystick = Control.new()
	_joystick.set_script(preload("res://scripts/ui/joystick.gd"))
	add_child(_joystick)

	_fps_label = Label.new()
	_fps_label.position = MARGIN
	_fps_label.add_theme_font_size_override("font_size", 18)
	_fps_label.modulate = Color(1, 1, 1, 0.8)
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_fps_label.add_theme_constant_override("outline_size", 6)
	add_child(_fps_label)

	_column = VBoxContainer.new()
	_column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_column.position = Vector2(-MARGIN.x, MARGIN.y)
	_column.add_theme_constant_override("separation", 10)
	add_child(_column)
	var toggle := UIStyle.button(_column, "Dev", Vector2(86, 48))
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	_menu.visible = false
	_column.add_child(_menu)
	toggle.pressed.connect(func() -> void: _menu.visible = not _menu.visible)
	_cap_button = UIStyle.button(_menu, "")
	_cap_button.pressed.connect(_toggle_cap)
	UIStyle.button(_menu, "Time +").pressed.connect(func() -> void: day_night.skip(0.125))
	UIStyle.button(_menu, "Look").pressed.connect(open_look_picker)
	UIStyle.button(_menu, "Swap look").pressed.connect(func() -> void: character.next_look())
	_refresh_cap()


func _process(delta: float) -> void:
	_worst = maxf(_worst, delta)
	_timer += delta
	if _timer < 1.0:
		return
	_worst_shown = _worst
	_worst = 0.0
	_timer = 0.0
	_fps_label.text = "%d fps · worst %d ms\n%d draws · %dk tris" % [
		Engine.get_frames_per_second(), roundi(_worst_shown * 1000.0),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000]


func open_look_picker() -> void:
	_menu.visible = false
	_column.visible = false
	_joystick.visible = false
	var picker := Control.new()
	picker.set_script(LOOK_PICKER)
	add_child(picker)
	picker.open(character, camera_rig)
	picker.closed.connect(func() -> void:
		_column.visible = true
		_joystick.visible = true)


func _toggle_cap() -> void:
	var caps := [30, 40, 60]
	Settings.set_fps_cap(caps[(caps.find(Settings.fps_cap) + 1) % caps.size()])
	_refresh_cap()


func _refresh_cap() -> void:
	_cap_button.text = "%d FPS" % Settings.fps_cap
