extends Control
## The player's hearts, top left. A heart that is lost pops; they refill as health comes back.

const POS := Vector2(66, 76)
const SIZE := 26.0
const GAP := 34.0
const SafeArea := preload("res://scripts/ui/safe_area.gd")

var _health := 5
var _max := 5
var _pop := 0.0
var _push := Vector2.ZERO   # further in on phones with a notch or camera hole
var _tex: ImageTexture


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_push = SafeArea.push(get_viewport())


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
	if _tex == null:
		_tex = _make_heart()
	# Every heart is the same small white picture, tinted: the renderer draws them all in one batch.
	for i in _max:
		var c := POS + _push + Vector2(i * GAP + SIZE * 0.5, SIZE * 0.5)
		var full := i < _health
		var s := SIZE * (1.0 + (0.3 * _pop if i == _health else 0.0))
		draw_texture_rect(_tex, Rect2(c + Vector2(0, 2) - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(0, 0, 0, 0.25))
		draw_texture_rect(_tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false,
			Color(0.9, 0.24, 0.26) if full else Color(0.15, 0.12, 0.16, 0.55))
	for i in mini(_health, _max):
		var c := POS + _push + Vector2(i * GAP + SIZE * 0.5, SIZE * 0.5)
		var d := SIZE * 0.16
		draw_texture_rect(_tex, Rect2(c + Vector2(-SIZE * 0.16, -SIZE * 0.14) - Vector2(d, d) * 0.5, Vector2(d, d)), false, Color(1, 1, 1, 0.55))


## A white heart (two round lobes over a point, as before), drawn once into a small texture.
static func _make_heart() -> ImageTexture:
	const N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var r := 0.27
	var lobes := [Vector2(-r * 0.9, -r * 0.35), Vector2(r * 0.9, -r * 0.35)]
	var tri := PackedVector2Array([Vector2(-r * 1.85, -r * 0.1), Vector2(r * 1.85, -r * 0.1), Vector2(0, 0.5)])
	for y in N:
		for x in N:
			var hits := 0
			for sy in 4:                      # 4x4 samples per pixel for soft edges
				for sx in 4:
					var p := Vector2((x + (sx + 0.5) / 4.0) / N - 0.5, (y + (sy + 0.5) / 4.0) / N - 0.5)
					if p.distance_to(lobes[0]) < r or p.distance_to(lobes[1]) < r or Geometry2D.is_point_in_polygon(p, tri):
						hits += 1
			img.set_pixel(x, y, Color(1, 1, 1, hits / 16.0))
	return ImageTexture.create_from_image(img)
