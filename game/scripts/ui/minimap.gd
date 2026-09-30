extends Control
## A round map in the top-right corner, centred on you: the region (painted once from WorldShape: grass,
## hill, pond, path, trees) scrolls under you as you move and turns around you with the camera, so up is
## always the way the camera looks. You are the arrow in the middle; buildings, the landmark and creatures
## close by show on it, and an N on the rim points north.

const SIZE := 150.0
const RADIUS := SIZE * 0.5 - 3.0
const SPAN := 200.0             # metres the painted texture covers (the play area plus a rim)
const VIEW := 64.0              # metres across the round map
const ENEMY_RANGE := 22.0       # creatures show only when this close
const RIM_POINTS := 40

var player: Node3D
var visual: Node3D              # the player's model (its rotation is where you face)
var landmark: Node3D
var _tex: ImageTexture
var _buildings: Array[Node3D] = []
var _refresh := 0.0
var _circle := PackedVector2Array()


func setup(shape: WorldShape, trees: Array[Vector2]) -> void:
	const PX := 160
	var img := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	for y in PX:
		for x in PX:
			var p := (Vector2(x + 0.5, y + 0.5) / PX - Vector2(0.5, 0.5)) * SPAN
			var h := shape.height_at(p.x, p.y)
			var c := Color(0.4, 0.6, 0.3).lightened(clampf(h * 0.05, 0.0, 0.3))
			if h < WorldShape.WATER_Y:
				c = Color(0.36, 0.58, 0.78)
			elif shape.path_distance(p) < 1.6:
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
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for i in RIM_POINTS:
		_circle.append(Vector2.from_angle(TAU * i / RIM_POINTS) * RADIUS)


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:                 # the building list changes rarely (home building)
		_refresh = 1.0
		_buildings.assign(get_tree().get_nodes_in_group("map_building"))
	queue_redraw()


func _draw() -> void:
	if _tex == null or player == null:
		return
	var mid := Vector2(SIZE, SIZE) * 0.5
	var yaw := Controls.cam_yaw
	var here := Vector2(player.global_position.x, player.global_position.z)
	var scale_px := RADIUS * 2.0 / VIEW
	draw_circle(mid, RADIUS + 3.0, Color(0.1, 0.12, 0.1, 0.8))
	# The ground: a round polygon whose corners look up the painted texture at the world spot under them.
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for c in _circle:
		pts.append(mid + c)
		var world := here + c.rotated(-yaw) / scale_px
		uvs.append(world / SPAN + Vector2(0.5, 0.5))
	draw_colored_polygon(pts, Color(1, 1, 1, 0.92), uvs, _tex)
	# Everything else is placed in world metres around you, turned with the camera.
	draw_set_transform(mid, yaw, Vector2.ONE * scale_px)
	var edges := PackedVector2Array()
	var reach := VIEW * 0.5
	for n in _buildings:
		if not is_instance_valid(n):
			continue
		var s: Vector2 = n.get_meta("map_size", Vector2(4, 4))
		var p := Vector2(n.global_position.x, n.global_position.z) - here
		if p.length() + s.length() * 0.5 > reach:
			continue
		var r := Rect2(p - s * 0.5, s)
		draw_rect(r, Color(0.86, 0.62, 0.42))
		var q := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i in 4:
			edges.append_array([q[i], q[(i + 1) % 4]])
	if not edges.is_empty():
		draw_multiline(edges, Color(0.3, 0.2, 0.15), 1.0 / scale_px)
	var dot := 1.0 / scale_px
	if landmark:
		_dot_or_edge(Vector2(landmark.global_position.x, landmark.global_position.z) - here, 4.0 * dot, Color(1.0, 0.85, 0.4), reach)
	for e in get_tree().get_nodes_in_group("enemy"):
		var n := e as Node3D
		if e.is_alive() and n.visible and n.global_position.distance_to(player.global_position) < ENEMY_RANGE:
			draw_circle(Vector2(n.global_position.x, n.global_position.z) - here, 3.5 * dot, Color(0.9, 0.25, 0.2))
	draw_set_transform(mid, yaw)
	var fwd := Vector2(sin(visual.rotation.y), cos(visual.rotation.y))
	var side := fwd.orthogonal()
	var arrow := PackedVector2Array([fwd * 8.0, -fwd * 5.0 + side * 5.0, -fwd * 2.5, -fwd * 5.0 - side * 5.0])
	draw_colored_polygon(arrow, Color.WHITE)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0.1, 0.1, 0.15), 1.5, true)
	draw_set_transform(Vector2.ZERO)
	draw_arc(mid, RADIUS + 1.5, 0.0, TAU, 48, Color(1.0, 0.95, 0.84, 0.85), 3.0, true)
	var north := mid + Vector2(0, -1).rotated(yaw) * RADIUS
	draw_circle(north, 9.0, Color(0.12, 0.13, 0.16, 0.95))
	draw_string(get_theme_default_font(), north + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.84))


## A marker inside the map, or pinned to the rim (pointing its way) when it is farther.
func _dot_or_edge(p: Vector2, r: float, color: Color, reach: float) -> void:
	if p.length() > reach - r:
		p = p.normalized() * (reach - r)
	draw_circle(p, r, color)
