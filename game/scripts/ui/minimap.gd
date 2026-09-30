extends Control
## A small map in the top-right corner: the whole meadow (painted once from WorldShape: grass,
## hill, pond, path, trees), you as an arrow, the landmark, and creatures close by.
## It turns with the camera, so up on the map is always the way the camera looks; an N marks north.

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
	clip_contents = true            # the turned map stays inside the frame
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
	var mid := Vector2(SIZE, SIZE) * 0.5
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(0.1, 0.12, 0.1, 0.75))
	# Everything on the map is drawn turned about its centre by the camera's turn.
	draw_set_transform(mid - mid.rotated(Controls.cam_yaw), Controls.cam_yaw)
	draw_texture_rect(_tex, Rect2(Vector2(3, 3), Vector2(SIZE - 6, SIZE - 6)), false, Color(1, 1, 1, 0.9))
	# All the fills first, then all the outlines as one line list, so they draw in two batches.
	var edges := PackedVector2Array()
	for n: Node3D in get_tree().get_nodes_in_group("map_building"):     # houses, workbench...
		var s: Vector2 = n.get_meta("map_size", Vector2(4, 4)) / SPAN * (SIZE - 6)
		var r := Rect2(_to_map(n.global_position) - s * 0.5, s)
		draw_rect(r, Color(0.86, 0.62, 0.42))
		var q := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			edges.append_array([q[i], q[(i + 1) % 4]])
	if not edges.is_empty():
		draw_multiline(edges, Color(0.3, 0.2, 0.15), 1.0)
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
	draw_set_transform(Vector2.ZERO)
	draw_style_box(_frame, Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)))
	var north := mid + Vector2(0, -1).rotated(Controls.cam_yaw) * (SIZE * 0.5 - 12.0)
	draw_string(get_theme_default_font(), north + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.84))


## Map fraction (0..1) to world x/z.
func _to_world(f: Vector2) -> Vector2:
	return (f - Vector2(0.5, 0.5)) * SPAN


func _to_map(p: Vector3) -> Vector2:
	var f := Vector2(p.x, p.z) / SPAN + Vector2(0.5, 0.5)
	return Vector2(3, 3) + f.clamp(Vector2.ZERO, Vector2.ONE) * (SIZE - 6)
