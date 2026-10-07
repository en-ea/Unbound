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
const DRAWN := ["sword", "heavy", "shield", "roll", "bow", "sneak"] # the symbols _icon_shapes paints
const SOFT := 64 # the soft round light's cell: 64 px from its centre to its edge
static var off := false # dev A/B only (hud_draws --hud-native): his own drawing
static var _image: Image
static var _texture: ImageTexture
static var _dirty := false
static var _cells := {} # key -> Rect2i
static var _x := 0
static var _y := 0
static var _row := 0


## His _draw (merge-fix's look: each button in its own colour, a metal ring, glass and gloss), with every soft light,
## disc and ring from the shared texture, tinted. Returns false (his own drawing runs) if a cell doesn't fit.
## merge-fix: the look matched to action_button.gd's _draw again (this skin had kept the older plain look).
static func draw(b: Control, editing: bool) -> bool:
	if off:
		return false
	var c: Vector2 = b.center() + Vector2(sin(b._shake * 40.0) * 6.0 * b._shake, 0)
	var active: bool = (b.verb != "" or b.icon != "") and not b.dim
	var pressed: bool = b._held != -1 and not editing
	var r: float = b.radius * (1.0 - 0.08 * b._pulse - (0.04 if pressed else 0.0))
	var big: bool = b.home_radius >= 60.0 # the main action button gets the gold bezel
	var alpha := 1.0 if active else 0.55
	var accent: Color = b.accent
	var hue: Color = accent if not b.dim else accent.lerp(Color(0.5, 0.5, 0.55), 0.6)
	var cooling: bool = b.sweep and b.meter < 1.0
	var base := roundi(b.radius)
	var band := 6.0 if big else 3.5
	var soft := _cell("soft", SOFT, _paint_soft)
	var disc := _cell("disc:%d" % base, base, _paint_disc.bind(float(base)))
	var metal := _cell("ring:%d:%.1f" % [base, band], ceili(base + band), _paint_ring.bind(float(base), band))
	var shine := _cell("shine:%d:%.1f" % [base, band], ceili(base + band), _paint_shine.bind(float(base), band))
	var trim := _cell("trim:%d:%s" % [base, big], base + 7, _paint_trim.bind(float(base), big))
	for cell: Rect2 in [soft, disc, metal, shine, trim]:
		if cell.size == Vector2.ZERO:
			return false
	var tex := texture()
	var k := r / float(base)
	var at := func(centre: Vector2, cell: Rect2, scale: float) -> Rect2:
		return Rect2(centre - cell.size * 0.5 * scale, cell.size * scale)
	var blob := func(centre: Vector2, radii: Vector2, col: Color) -> void: # Look.blob, from the shared texture
		b.draw_texture_rect_region(tex, Rect2(centre - radii, radii * 2.0), soft.grow(-2.0), col)
	# Shadow underneath, and a soft glow in its colour while it's ready (abilities) or lit.
	blob.call(c + Vector2(0, r * 0.1), Vector2.ONE * r * 1.32, Color(0, 0, 0, 0.42 * alpha))
	if (b.sweep and not cooling and active) or (b.lit and not b.sweep):
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		blob.call(c, Vector2.ONE * r * (1.45 + 0.08 * beat), Color(hue, 0.3 + 0.2 * beat))
	# Body: dark glass with a glow of its colour in the middle, deeper at the edge.
	var body := Color(0.05, 0.06, 0.09, 0.9 if active else 0.7)
	if b.lit and not b.sweep:
		body = Color(b.lit_fill.darkened(0.2), 0.92)
	b.draw_texture_rect_region(tex, at.call(c, disc, k), disc, body)
	blob.call(c + Vector2(0, r * 0.12), Vector2.ONE * r * 0.98, Color(hue.darkened(0.15), (0.5 if active else 0.22) + (0.25 if pressed else 0.0)))
	blob.call(c + Vector2(0, -r * 0.05), Vector2.ONE * r * 0.55, Color(hue.lightened(0.3), 0.18 if active else 0.05))
	blob.call(c + Vector2(0, -r * 0.5), Vector2(r * 0.7, r * 0.36), Color(1, 1, 1, 0.16 if active else 0.06)) # gloss
	# The ring: a metal band lit from the top left (gold and thick on the main button): its dark colour all round,
	# then its light one where the light falls (Look.metal_ring's blend), then the dark edges and the glint.
	var light := Color(1.0, 0.93, 0.66, alpha) if big else Color(hue.lightened(0.55), 0.95 * alpha)
	var dark := Color(0.5, 0.31, 0.1, alpha) if big else Color(hue.darkened(0.55), 0.9 * alpha)
	b.draw_texture_rect_region(tex, at.call(c, metal, k), metal, dark)
	b.draw_texture_rect_region(tex, at.call(c, shine, k), shine, light)
	b.draw_texture_rect_region(tex, at.call(c, trim, k), trim, Color(1, 1, 1, alpha))
	if cooling: # cooldown: a dark wedge over what's still to wait, the ring refilling in colour (polygons, only while cooling)
		var pts := PackedVector2Array([c])
		var steps := maxi(int(48 * (1.0 - b.meter)), 2)
		for i in steps + 1:
			var a: float = -PI * 0.5 + TAU * b.meter + TAU * (1.0 - b.meter) * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * (r - 1.5))
		b.draw_colored_polygon(pts, Color(0.01, 0.02, 0.04, 0.62))
		if b.meter > 0.0:
			b.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * b.meter, maxi(int(64 * b.meter), 2), accent.lightened(0.2), 4.0, true)
	elif b.meter < 1.0: # stamina: the rim empties anticlockwise from the top
		b.draw_arc(c, r + 1.0, 0.0, TAU, 64, Color(0.02, 0.03, 0.05, 0.85), 6.0, true)
		if b.meter > 0.0:
			b.draw_arc(c, r + 1.0, -PI * 0.5, -PI * 0.5 + TAU * b.meter, maxi(int(64 * b.meter), 2), b.meter_color, 5.0, true)
	if b._ready_ring > 0.0:
		var t: float = 1.0 - b._ready_ring
		blob.call(c, Vector2.ONE * r * (1.2 + 0.5 * t), Color(accent.lightened(0.3), 0.5 * b._ready_ring))
		b.draw_arc(c, r * (1.0 + 0.45 * t), 0.0, TAU, 48, Color(accent.lightened(0.5), b._ready_ring), 4.0 * b._ready_ring + 1.0, true)
	var font: Font = b.get_theme_default_font()
	var ink := Color(CREAM, 1.0 if active else 0.45)
	if cooling and b.seconds > 0:
		_glyph(b, c + Vector2(0, -r * 0.08), base * 0.4, k, Color(CREAM, 0.22), false)
		b._text(font, c + Vector2(0, r * 0.2), str(b.seconds), int(r * 0.66), Color(1, 1, 1, 0.97))
	elif b.icon != "":
		var label: bool = b.verb != "" and not b.sweep # abilities show just their symbol (the name is in the class screen)
		var glyph_at := c + Vector2(0, -r * 0.12 if label else 0.0)
		_glyph(b, glyph_at, base * (0.42 if label else 0.56), k, ink, true)
		if label:
			b._text(font, c + Vector2(0, r * 0.62), b.verb, int(maxf(r * 0.25, 11.0)), Color(CREAM, 0.88 if active else 0.4))
	else:
		var size := int(b.font_size * b.radius / maxf(b.home_radius, 1.0))
		var up := size * 0.3 if b.sub != "" else 0.0
		b._text(font, c + Vector2(0, size * 0.35 - up), b.verb if b.verb != "" else "·", size, ink)
		if b.sub != "":
			b._text(font, c + Vector2(0, size * 0.35 + size * 0.45), b.sub, int(size * 0.6), Color(CREAM, 0.6 if active else 0.3))
	b._draw_flicks(c, r, font)
	if editing:
		b.draw_arc(c, r + 8.0, 0.0, TAU, 48, Color(GOLD, 0.9), 2.0, true)
	return true


## His symbol at `at` (`s` at the button's own size, scaled by `k`), with a drop shadow when `shadow`: the drawn ones
## from the shared texture; a class power's from ability_icons.gd (drawn as shapes); else his own _icon.
static func _glyph(b: Control, at: Vector2, s: float, k: float, ink: Color, shadow: bool) -> void:
	var drop := Vector2(0, maxf(roundi(b.radius) * k * 0.05, 2.0)) # (the button's r * 0.05)
	if b.icon in DRAWN:
		var cell := _cell("icon:%s:%d" % [b.icon, roundi(s * 4.0)], ceili(s * 1.4) + 2, _paint_icon.bind(str(b.icon), s))
		if cell.size != Vector2.ZERO:
			var tex := texture()
			var rect := Rect2(at - cell.size * 0.5 * k, cell.size * k)
			if shadow:
				b.draw_texture_rect_region(tex, Rect2(rect.position + drop, rect.size), cell, Color(0, 0, 0, 0.5 * ink.a))
			b.draw_texture_rect_region(tex, rect, cell, Color(1, 1, 1, ink.a))
			return
	var icons := preload("res://scripts/ui/ability_icons.gd")
	var cut := Color(0.05, 0.06, 0.09, ink.a)
	if shadow:
		icons.draw(b, b.icon, at + drop, s * k, Color(0, 0, 0, 0.5 * ink.a), cut)
	if not icons.draw(b, b.icon, at, s * k, ink, cut):
		b._icon(at, s * k, ink)


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


## A soft round light (Look.blob's gradient): full in the middle, fading out to the edge of radius `SOFT`.
static func _paint_soft(image: Image, rect: Rect2i) -> void:
	var o := Vector2(rect.position) + Vector2(rect.size) * 0.5
	var stops := [[0.0, 1.0], [0.35, 0.78], [0.7, 0.3], [1.0, 0.0]]
	for y in rect.size.y:
		for x in rect.size.x:
			var t := (Vector2(rect.position.x + x, rect.position.y + y) + Vector2(0.5, 0.5)).distance_to(o) / SOFT
			var a := 0.0
			for i in 3:
				if t <= stops[i + 1][0]:
					a = lerpf(stops[i][1], stops[i + 1][1], (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0]))
					break
			image.set_pixel(rect.position.x + x, rect.position.y + y, Color(1, 1, 1, a))


## The metal ring's light: white where the light falls (from the top left), fading out underneath (Look.metal_ring's
## blend, t squared), so the light colour drawn over the dark one makes the same shaded band.
static func _paint_shine(image: Image, rect: Rect2i, r: float, w: float) -> void:
	var o := Vector2(rect.position) + Vector2(rect.size) * 0.5
	var sun := Vector2(-0.45, -0.9).normalized()
	for y in rect.size.y:
		for x in rect.size.x:
			var p := Vector2(rect.position.x + x, rect.position.y + y) + Vector2(0.5, 0.5) - o
			var t := 0.5 + 0.5 * p.normalized().dot(sun)
			_put(image, rect.position.x + x, rect.position.y + y, Color(1, 1, 1, t * t), w * 0.5 - absf(p.length() - r) + 0.5)


## The ring's fixed trim, in its own colours: the dark line outside it, the dark line inside the gold bezel (`big`),
## and the white glint at its top left.
static func _paint_trim(image: Image, rect: Rect2i, r: float, big: bool) -> void:
	var o := Vector2(rect.position) + Vector2(rect.size) * 0.5
	var edge := r + (4.5 if big else 2.5)
	var glint := r + (2.4 if big else 1.4)
	var from := PI * 1.08
	var to := PI * 1.62
	var ends := [Vector2.from_angle(from) * glint, Vector2.from_angle(to) * glint]
	for y in rect.size.y:
		for x in rect.size.x:
			var p := Vector2(rect.position.x + x, rect.position.y + y) + Vector2(0.5, 0.5) - o
			var d := p.length()
			_put(image, rect.position.x + x, rect.position.y + y, Color(0, 0, 0, 0.55), 1.0 - absf(d - edge) + 0.5)
			if big:
				_put(image, rect.position.x + x, rect.position.y + y, Color(0.15, 0.08, 0.02, 0.6), 0.75 - absf(d - (r - 3.5)) + 0.5)
			var a := fposmod(p.angle(), TAU)
			var off := absf(d - glint) if a >= from and a <= to else minf(p.distance_to(ends[0]), p.distance_to(ends[1]))
			_put(image, rect.position.x + x, rect.position.y + y, Color(1, 1, 1, 0.45), 0.6 - off + 0.5)


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
