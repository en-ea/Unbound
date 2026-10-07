extends RefCounted
## C1 (Body, 6 Oct): his round buttons (ui/action_button.gd) drawn the same, in fewer draw calls. The GL Compatibility
## canvas sends every circle, arc and icon polygon as a draw call of its own, but batches textured rectangles: so the
## discs, the rim and the drawn symbol are painted once, at the size they are shown, into one shared texture, and a
## button draws them as rectangles from it (one draw), then its words (the font's draw). The cooldown wedge, the meter
## arcs and the flick marks stay his own polygons: they show only while they are needed.
## Called from one marked line at the top of ActionButton._draw; his drawing below that line is the fallback.
const SIZE := 1024
const CREAM := Color(1, 0.97, 0.9) # his ActionButton.CREAM and GOLD
const GOLD := Color(1.0, 0.82, 0.42)
const PAD := 2
static var off := false # dev A/B only (hud_draws --hud-native): his own drawing
static var _image: Image
static var _texture: ImageTexture
static var _dirty := false
static var _cells := {} # key -> Rect2i
static var _x := 0
static var _y := 0
static var _row := 0


## His _draw, with the discs, rim and symbol from the shared texture. Returns false (his own drawing runs) if no cell fits.
static func draw(b: Control, editing: bool) -> bool:
	if off:
		return false
	var c: Vector2 = b.center() + Vector2(sin(b._shake * 40.0) * 6.0 * b._shake, 0)
	var active: bool = (b.verb != "" or b.icon != "") and not b.dim
	var r: float = b.radius * (1.0 - 0.08 * b._pulse)
	var fill := Color(0.07, 0.09, 0.14, 0.6 if active else 0.32)
	if b.lit:
		fill = b.lit_fill
	var base := roundi(b.radius)
	var disc := _cell("disc:%d" % base, base, _paint_disc.bind(float(base)))
	var rim_cell := _cell("rim:%d" % base, base, _paint_ring.bind(float(base), 3.0))
	if disc.size == Vector2.ZERO or rim_cell.size == Vector2.ZERO:
		return false
	var tex := texture()
	var k := r / float(base)
	var at := func(centre: Vector2, cell: Rect2, scale: float) -> Rect2:
		return Rect2(centre - cell.size * 0.5 * scale, cell.size * scale)
	b.draw_texture_rect_region(tex, at.call(c + Vector2(0, 4), disc, k), disc, Color(0, 0, 0, 0.22))
	b.draw_texture_rect_region(tex, at.call(c, disc, k), disc, fill)
	if active:
		b.draw_texture_rect_region(tex, at.call(c, disc, k * 0.86), disc, Color(1, 1, 1, 0.04))
	if b._held != -1 and not editing:
		b.draw_texture_rect_region(tex, at.call(c, disc, k), disc, Color(1, 1, 1, 0.1))
	var rim := Color(1, 0.95, 0.8, 0.85 if active else 0.25)
	if b.lit and b.sweep:
		rim = b.meter_color.lightened(0.35)
	b.draw_texture_rect_region(tex, at.call(c, rim_cell, k), rim_cell, rim)
	var cooling: bool = b.sweep and b.meter < 1.0
	if cooling: # his cooldown wedge and its arc (polygons, only while cooling)
		var pts := PackedVector2Array([c])
		var steps := maxi(int(48 * (1.0 - b.meter)), 2)
		for i in steps + 1:
			var a: float = -PI * 0.5 + TAU * b.meter + TAU * (1.0 - b.meter) * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * (r - 2.0))
		b.draw_colored_polygon(pts, Color(0.02, 0.03, 0.06, 0.55))
		b.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * maxf(b.meter, 0.01), maxi(int(64 * b.meter), 2), b.meter_color, 4.0, true)
	elif b.meter < 1.0: # his meter rim
		b.draw_arc(c, r, 0.0, TAU, 64, Color(0.05, 0.06, 0.1, 0.8), 5.0, true)
		if b.meter > 0.0:
			b.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * b.meter, maxi(int(64 * b.meter), 2), b.meter_color, 5.0, true)
	if b._ready_ring > 0.0:
		var t: float = 1.0 - b._ready_ring
		b.draw_arc(c, r * (1.0 + 0.45 * t), 0.0, TAU, 48, Color(b.meter_color.lightened(0.4), b._ready_ring), 4.0 * b._ready_ring + 1.0, true)
	var font: Font = b.get_theme_default_font()
	var ink := Color(CREAM, 1.0 if active else 0.4)
	if cooling and b.seconds > 0:
		b._text(font, c + Vector2(0, r * 0.12), str(b.seconds), int(r * 0.62), Color(1, 1, 1, 0.95))
		b._text(font, c + Vector2(0, r * 0.52), b.verb, int(maxf(r * 0.24, 11.0)), Color(CREAM, 0.55))
	elif b.icon != "":
		var s: float = b.radius * 0.42
		var glyph := _cell("icon:%s:%d" % [b.icon, roundi(s * 4.0)], ceili(s * 1.4) + 2, _paint_icon.bind(str(b.icon), s))
		if glyph.size != Vector2.ZERO:
			b.draw_texture_rect_region(tex, at.call(c + Vector2(0, -r * 0.12), glyph, k), glyph, Color(1, 1, 1, ink.a))
		else:
			b._icon(c + Vector2(0, -r * 0.12), r * 0.42, ink)
		if b.verb != "":
			b._text(font, c + Vector2(0, r * 0.58), b.verb, int(maxf(r * 0.26, 11.0)), Color(CREAM, 0.85 if active else 0.35))
	else:
		var size := int(b.font_size * b.radius / maxf(b.home_radius, 1.0))
		var up := size * 0.3 if b.sub != "" else 0.0
		b._text(font, c + Vector2(0, size * 0.35 - up), b.verb if b.verb != "" else "·", size, ink)
		if b.sub != "":
			b._text(font, c + Vector2(0, size * 0.35 + size * 0.45), b.sub, int(size * 0.6), Color(CREAM, 0.6 if active else 0.3))
	b._draw_flicks(c, r, font)
	if editing:
		b.draw_arc(c, r + 7.0, 0.0, TAU, 48, Color(GOLD, 0.9), 2.0, true)
	return true


static func texture() -> Texture2D:
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	elif _dirty:
		_texture.update(_image)
	_dirty = false
	return _texture


## A cell `half` px from its centre to each edge (plus a pixel of margin), painted once by `paint(image, rect)`.
static func _cell(key: String, half: int, paint: Callable) -> Rect2:
	if _cells.has(key):
		return Rect2(_cells[key])
	if _image == null:
		_image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var side := half * 2 + 4
	if _x + side > SIZE:
		_x = 0
		_y += _row + PAD
		_row = 0
	if _y + side > SIZE or side > SIZE:
		return Rect2() # full: the caller draws his own way
	var rect := Rect2i(_x, _y, side, side)
	_x += side + PAD
	_row = maxi(_row, side)
	paint.call(_image, rect)
	_cells[key] = rect
	_dirty = true
	return Rect2(rect)


static func _put(image: Image, x: int, y: int, color: Color, cover: float) -> void:
	if cover <= 0.0:
		return
	var under := image.get_pixel(x, y)
	var a := color.a * clampf(cover, 0.0, 1.0)
	var out_a := a + under.a * (1.0 - a)
	if out_a <= 0.0:
		return
	var rgb := (Vector3(color.r, color.g, color.b) * a + Vector3(under.r, under.g, under.b) * under.a * (1.0 - a)) / out_a
	image.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, out_a))


## White disc of radius `r`, edge antialiased over one pixel (tinted by the draw's modulate).
static func _paint_disc(image: Image, rect: Rect2i, r: float) -> void:
	var o := Vector2(rect.position) + Vector2(rect.size) * 0.5
	for y in rect.size.y:
		for x in rect.size.x:
			var d := (Vector2(rect.position.x + x, rect.position.y + y) + Vector2(0.5, 0.5)).distance_to(o)
			_put(image, rect.position.x + x, rect.position.y + y, Color.WHITE, r - d + 0.5)


## White ring of radius `r`, `w` px wide (his rim: draw_arc(c, r, 0, TAU, 64, rim, 3.0)).
static func _paint_ring(image: Image, rect: Rect2i, r: float, w: float) -> void:
	var o := Vector2(rect.position) + Vector2(rect.size) * 0.5
	for y in rect.size.y:
		for x in rect.size.x:
			var d := (Vector2(rect.position.x + x, rect.position.y + y) + Vector2(0.5, 0.5)).distance_to(o)
			_put(image, rect.position.x + x, rect.position.y + y, Color.WHITE, w * 0.5 - absf(d - r) + 0.5)


## His symbols (ActionButton._icon), the same shapes and colours, painted in cream at full strength (the draw's
## modulate dims them). Each shape: [kind, colour, ...]; polygons 4x4 supersampled, lines and arcs by distance.
static func _paint_icon(image: Image, rect: Rect2i, name: String, s: float) -> void:
	var o := Vector2(rect.position) + Vector2(rect.size) * 0.5
	var shapes := _icon_shapes(name, s)
	for shape: Array in shapes:
		var kind: String = shape[0]
		var col: Color = shape[1]
		for y in rect.size.y:
			for x in rect.size.x:
				var p := Vector2(rect.position.x + x, rect.position.y + y) + Vector2(0.5, 0.5) - o
				var cover := 0.0
				match kind:
					"poly":
						var hits := 0
						for sy in 4:
							for sx in 4:
								if Geometry2D.is_point_in_polygon(p + Vector2((sx + 0.5) / 4.0 - 0.5, (sy + 0.5) / 4.0 - 0.5), shape[2]):
									hits += 1
						cover = hits / 16.0
					"line":
						cover = float(shape[4]) * 0.5 - _to_segment(p, shape[2], shape[3]) + 0.5
					"circle":
						cover = float(shape[3]) - p.distance_to(shape[2]) + 0.5
					"arc":
						var pts: PackedVector2Array = shape[2]
						var best := INF
						for i in pts.size() - 1:
							best = minf(best, _to_segment(p, pts[i], pts[i + 1]))
						cover = float(shape[3]) * 0.5 - best + 0.5
				_put(image, rect.position.x + x, rect.position.y + y, col, cover)


static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


static func _arc(c: Vector2, r: float, from: float, to: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## ActionButton._icon's geometry around (0, 0), as shapes.
static func _icon_shapes(name: String, s: float) -> Array:
	var cream := Color(1, 0.97, 0.9)
	var gold := Color(1.0, 0.82, 0.42)
	var dark := Color(0.07, 0.09, 0.14, 0.7)
	var out := []
	match name:
		"sword", "heavy":
			var d := Vector2(1, -1).normalized()
			var n := Vector2(d.y, -d.x)
			var base := -d * s * 0.55
			var tip := d * s * 1.05
			out.append(["poly", cream, PackedVector2Array([base + n * s * 0.16, tip - d * s * 0.22 + n * s * 0.16, tip,
				tip - d * s * 0.22 - n * s * 0.16, base - n * s * 0.16])])
			out.append(["line", cream, base + n * s * 0.42, base - n * s * 0.42, s * 0.16])
			out.append(["line", cream, base, base - d * s * 0.42, s * 0.13])
			out.append(["circle", cream, base - d * s * 0.5, s * 0.1])
			if name == "heavy":
				out.append(["arc", gold, _arc(Vector2(-s * 0.15, s * 0.15), s * 1.15, PI * 0.62, PI * 1.12, 16), s * 0.12])
				out.append(["arc", Color(gold, 0.7), _arc(Vector2(-s * 0.15, s * 0.15), s * 0.85, PI * 0.68, PI * 1.05, 12), s * 0.08])
		"shield":
			var pts := PackedVector2Array([Vector2(-s * 0.8, -s * 0.85), Vector2(0, -s * 1.0), Vector2(s * 0.8, -s * 0.85)])
			for k in range(1, 9):
				var t := k / 8.0
				pts.append(Vector2(s * 0.8 * (1.0 - t) * (1.0 - t * 0.3), s * (-0.85 + 1.95 * sin(t * PI * 0.5))))
			for k in range(7, 0, -1):
				var t := k / 8.0
				pts.append(Vector2(-s * 0.8 * (1.0 - t) * (1.0 - t * 0.3), s * (-0.85 + 1.95 * sin(t * PI * 0.5))))
			out.append(["poly", cream, pts])
			out.append(["line", dark, Vector2(0, -s * 0.7), Vector2(0, s * 0.7), s * 0.12])
		"roll":
			out.append(["arc", cream, _arc(Vector2.ZERO, s * 0.8, -PI * 0.35, PI * 1.25, 24), s * 0.2])
			var a := -PI * 0.35
			var p := Vector2(cos(a), sin(a)) * s * 0.8
			var fwd := Vector2(-sin(a), cos(a)) * -1.0
			var o := Vector2(cos(a), sin(a))
			out.append(["poly", cream, PackedVector2Array([p + fwd * s * 0.45, p + o * s * 0.35, p - o * s * 0.35])])
		"bow":
			var bc := Vector2(-s * 0.35, 0)
			out.append(["arc", cream, _arc(bc, s * 0.95, -PI * 0.42, PI * 0.42, 18), s * 0.17])
			out.append(["line", cream, bc + Vector2(cos(-PI * 0.42), sin(-PI * 0.42)) * s * 0.95, bc + Vector2(cos(PI * 0.42), sin(PI * 0.42)) * s * 0.95, s * 0.06])
			out.append(["line", cream, Vector2(-s * 0.5, 0), Vector2(s * 0.75, 0), s * 0.08])
			out.append(["poly", cream, PackedVector2Array([Vector2(s * 0.95, 0), Vector2(s * 0.62, -s * 0.16), Vector2(s * 0.62, s * 0.16)])])
		"sneak":
			var lid := PackedVector2Array()
			for k in 13:
				var t := k / 12.0
				lid.append(Vector2(lerpf(-s, s, t), -sin(t * PI) * s * 0.25))
			for k in range(1, 12):
				var t := 1.0 - k / 12.0
				lid.append(Vector2(lerpf(-s, s, t), sin(t * PI) * s * 0.55))
			out.append(["poly", cream, lid])
			out.append(["circle", Color(0.07, 0.09, 0.14, 0.9), Vector2(0, s * 0.12), s * 0.3])
			out.append(["line", cream, Vector2(-s * 1.1, -s * 0.05), Vector2(s * 1.1, -s * 0.05), s * 0.14])
	return out
