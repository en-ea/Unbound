extends Control
## "Move buttons": drag any touch button to a new spot; the bar on top makes them all bigger or smaller,
## puts them back where they started, or saves the layout (Settings.button_spots / button_scale).

signal closed

var buttons: Array[ActionButton] = []
var defaults := {}               # id -> [default spot, default radius] (hud.gd BUTTONS)

var _scale := 1.0
var _size_label: Label
var _bar: PanelContainer
var _grab: ActionButton
var _finger := -1
var _offset := Vector2.ZERO
const SCALES := [0.8, 0.9, 1.0, 1.1, 1.2, 1.3]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scale = Settings.button_scale
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	move_to_front()
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", UIStyle.panel(18))
	_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.position.y = 20
	add_child(_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_bar.add_child(row)
	UIStyle.label(row, "Drag a button to move it", 20)
	UIStyle.button(row, "−", Vector2(52, 48)).pressed.connect(_resize.bind(-1))
	_size_label = UIStyle.label(row, "", 20)
	_size_label.custom_minimum_size.x = 64
	_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.button(row, "+", Vector2(52, 48)).pressed.connect(_resize.bind(1))
	UIStyle.button(row, "Reset", Vector2(100, 48), 20).pressed.connect(_reset)
	UIStyle.button(row, "Done", Vector2(100, 48), 20).pressed.connect(_done)
	_show_size()


func _show_size() -> void:
	_size_label.text = "%d%%" % roundi(_scale * 100.0)
	for b in buttons:
		b.radius = b.home_radius * _scale
		b.queue_redraw()


func _resize(step: int) -> void:
	var i := SCALES.find(snappedf(_scale, 0.1))
	_scale = SCALES[clampi((i if i != -1 else 2) + step, 0, SCALES.size() - 1)]
	_show_size()


func _reset() -> void:
	_scale = 1.0
	for b in buttons:
		b.margin = defaults[b.id][0]
	_show_size()


func _done() -> void:
	var spots := {}
	for b in buttons:
		if b.margin != defaults[b.id][0]:
			spots[b.id] = b.margin
	Settings.set_button_layout(spots, _scale)
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1 and not _bar.get_global_rect().has_point(touch.position):
			for k in range(buttons.size() - 1, -1, -1):
				var b := buttons[k]
				if b.is_visible_in_tree() and touch.position.distance_to(b.center()) < b.radius * 1.1:
					_grab = b
					_finger = touch.index
					_offset = b.center() - touch.position
					get_viewport().set_input_as_handled()
					break
		elif not touch.pressed and touch.index == _finger:
			_finger = -1
			_grab = null
	elif event is InputEventScreenDrag and event.index == _finger and _grab:
		var view := get_viewport().get_visible_rect().size
		var at: Vector2 = (event.position + _offset).clamp(Vector2(_grab.radius, _bar.get_global_rect().end.y + _grab.radius),
			view - Vector2(_grab.radius, _grab.radius))
		_grab.margin = view - at
		_grab.queue_redraw()
		get_viewport().set_input_as_handled()
