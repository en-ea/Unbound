extends Control
## A small map in the top-right corner: the whole meadow (painted once from WorldShape: grass,
## hill, pond, path, trees), you as an arrow, the landmark, and creatures close by.
## Up on the map is up on screen (the camera never turns).

const SIZE := 150.0
const SPAN := 120.0             # metres shown across the map (the play area plus a rim)
const ENEMY_RANGE := 22.0       # creatures show only when this close

var player: Node3D
var visual: Node3D              # the player's model (its rotation is where you face)
var landmark: Node3D
var _tex: ImageTexture
var _frame := StyleBoxFlat.new()
var _timer := 0.0


func setup(shape: WorldShape, trees: Array[Vector2]) -> void:
	const PX := 120
	var img := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	for y in PX:
		for x in PX:
			var p := _to_world(Vector2(x + 0.5, y + 0.5) / PX)
			var h := shape.height_at(p.x, p.y)
			var c := Color(0.4, 0.6, 0.3).lightened(clampf(h * 0.05, 0.0, 0.3))
			if h < WorldShape.WATER_Y:
				c = Color(0.36, 0.58, 0.78)
			elif shape.path_distance(p) < 1.2:
				c = Color(0.82, 0.72, 0.52)
			elif shape.in_clearing(p):
				c = Color(0.62, 0.66, 0.4)
			if maxf(absf(p.x), absf(p.y)) > WorldShape.PLAY_HALF:
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
	for t in trees:
		var m := Vector2i(((t + Vector2.ONE * SPAN * 0.5) / SPAN * PX).floor())
		img.fill_rect(Rect2i(m, Vector2i(2, 2)), Color(0.18, 0.34, 0.16))
	_tex = ImageTexture.create_from_image(img)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	_frame.bg_color = Color(0, 0, 0, 0)
	_frame.border_color = Color(1.0, 0.95, 0.84, 0.85)
	_frame.set_border_width_all(3)
	_frame.set_corner_radius_all(12)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.1
		queue_redraw()


func _draw() -> void:
	if _tex == null or player == null:
		return
	draw_texture_rect(_tex, Rect2(Vector2(3, 3), Vector2(SIZE - 6, SIZE - 6)), false, Color(1, 1, 1, 0.9))
	draw_style_box(_frame, Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)))
	for n: Node3D in get_tree().get_nodes_in_group("map_building"):     # houses, workbench...
		var s: Vector2 = n.get_meta("map_size", Vector2(4, 4)) / SPAN * (SIZE - 6)
		var r := Rect2(_to_map(n.global_position) - s * 0.5, s)
		draw_rect(r, Color(0.86, 0.62, 0.42))
		draw_rect(r, Color(0.3, 0.2, 0.15), false, 1.0)
	if landmark:
		draw_circle(_to_map(landmark.global_position), 4.0, Color(1.0, 0.85, 0.4))
	for e in get_tree().get_nodes_in_group("enemy"):
		var n := e as Node3D
		if e.is_alive() and n.visible and n.global_position.distance_to(player.global_position) < ENEMY_RANGE:
			draw_circle(_to_map(n.global_position), 3.5, Color(0.9, 0.25, 0.2))
	var at := _to_map(player.global_position)
	var fwd := Vector2(sin(visual.rotation.y), cos(visual.rotation.y))
	var side := fwd.orthogonal()
	var arrow := PackedVector2Array([at + fwd * 8.0, at - fwd * 5.0 + side * 5.0, at - fwd * 2.5, at - fwd * 5.0 - side * 5.0])
	draw_colored_polygon(arrow, Color.WHITE)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0.1, 0.1, 0.15), 1.5, true)


## Map fraction (0..1) to world x/z.
func _to_world(f: Vector2) -> Vector2:
	return (f - Vector2(0.5, 0.5)) * SPAN


func _to_map(p: Vector3) -> Vector2:
	var f := Vector2(p.x, p.z) / SPAN + Vector2(0.5, 0.5)
	return Vector2(3, 3) + f.clamp(Vector2.ZERO, Vector2.ONE) * (SIZE - 6)
