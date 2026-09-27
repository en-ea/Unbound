extends Control
## The player's hearts, top left. A heart that is lost pops; they refill as health comes back.

const POS := Vector2(66, 76)
const SIZE := 26.0
const GAP := 34.0

var _health := 5
var _max := 5
var _pop := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_health(health: int, max_health: int) -> void:
	if health < _health:
		_pop = 1.0
	_health = health
	_max = max_health
	queue_redraw()


func _process(delta: float) -> void:
	if _pop > 0.0:
		_pop = maxf(_pop - delta * 3.0, 0.0)
		queue_redraw()


func _draw() -> void:
	for i in _max:
		var c := POS + Vector2(i * GAP + SIZE * 0.5, SIZE * 0.5)
		var full := i < _health
		var s := SIZE * (1.0 + (0.3 * _pop if i == _health else 0.0))
		_heart(c + Vector2(0, 2), s, Color(0, 0, 0, 0.25))
		_heart(c, s, Color(0.9, 0.24, 0.26) if full else Color(0.15, 0.12, 0.16, 0.55))
		if full:
			draw_circle(c + Vector2(-s * 0.16, -s * 0.14), s * 0.08, Color(1, 1, 1, 0.55))


func _heart(c: Vector2, s: float, color: Color) -> void:
	var r := s * 0.27
	draw_circle(c + Vector2(-r * 0.9, -r * 0.35), r, color, true, -1.0, true)
	draw_circle(c + Vector2(r * 0.9, -r * 0.35), r, color, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.85, -r * 0.1), c + Vector2(r * 1.85, -r * 0.1),
		c + Vector2(0, s * 0.5)]), color)
