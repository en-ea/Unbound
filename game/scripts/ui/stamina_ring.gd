extends Control
## The stamina ring: a small round gauge beside the player that shows while stamina is used and
## fades once it is full again. Green-gold normally; orange and pulsing while winded; it gives a
## little shake when a roll or heavy attack is refused.

const RADIUS := 17.0
const WIDTH := 6.0
const OFFSET := Vector2(44, -34)     # from the player's chest on screen
const FULL := Color(0.62, 0.9, 0.38)
const LOW := Color(0.98, 0.78, 0.3)
const WINDED := Color(1.0, 0.42, 0.26)

var player: Node3D
var _value := 1.0             # 0..1
var _winded := false
var _alpha := 0.0
var _full_for := 0.0
var _shake := 0.0
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.stamina.changed.connect(_on_changed)
	player.stamina.refused.connect(func() -> void: _shake = 1.0; _alpha = 1.0; _full_for = 0.0)


func _on_changed(value: float, max_value: float, winded: bool) -> void:
	_value = value / max_value
	_winded = winded
	if _value < 1.0:
		_full_for = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _value >= 1.0:
		_full_for += delta
	var want := 0.0 if _full_for > 0.5 else 1.0
	var alpha := move_toward(_alpha, want, delta * (6.0 if want > 0.0 else 2.5))
	_shake = maxf(_shake - delta * 4.0, 0.0)
	if alpha > 0.0 or _alpha > 0.0:
		_alpha = alpha
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(player.global_position):
		return
	var c := cam.unproject_position(player.global_position + Vector3(0, 1.1, 0)) + OFFSET
	c.x += sin(_time * 60.0) * 5.0 * _shake
	var a := _alpha
	var color := WINDED if _winded else LOW.lerp(FULL, clampf(_value * 2.0 - 0.3, 0.0, 1.0))
	if _winded:
		a *= 0.7 + 0.3 * sin(_time * 12.0)
	draw_circle(c + Vector2(0, 2), RADIUS + WIDTH * 0.5 + 1.5, Color(0, 0, 0, 0.18 * a), true, -1.0, true)
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(0.08, 0.1, 0.14, 0.55 * a), WIDTH + 3.0, true)
	if _value > 0.0:
		draw_arc(c, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * _value, maxi(int(48 * _value), 2),
			Color(color, a), WIDTH, true)
		# A soft highlight on the gauge.
		draw_arc(c, RADIUS + 1.2, -PI * 0.5, -PI * 0.5 + TAU * _value, maxi(int(48 * _value), 2),
			Color(1, 1, 1, 0.22 * a), 1.5, true)
