extends RefCounted
## The touch controls' shared look (ActionButton and the studio thumb area): soft lights, metal rings, a hand.

static var _soft: GradientTexture2D  # the soft round light behind glows, gloss and shadows


## A soft round light (or shadow): full in the middle, fading out to `radii`.
static func blob(ci: CanvasItem, at: Vector2, radii: Vector2, col: Color) -> void:
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.78), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.width = 128
		_soft.height = 128
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(0.5, 0.0)
	ci.draw_texture_rect(_soft, Rect2(at - radii, radii * 2.0), false, col)


## A ring shaded like metal: bright where the light falls (top left), dark underneath.
static func metal_ring(ci: CanvasItem, c: Vector2, r: float, width: float, light: Color, dark: Color) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var sun := Vector2(-0.45, -0.9).normalized()
	for k in 73:
		var d := Vector2.from_angle(TAU * k / 72.0)
		pts.append(c + d * r)
		var t := 0.5 + 0.5 * d.dot(sun)
		cols.append(dark.lerp(light, t * t))
	ci.draw_polyline_colors(pts, cols, width, true)


## An open hand, palm towards you; `s` is about half its height.
static func hand(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var palm := PackedVector2Array()
	for k in 17:                               # a rounded palm, wider at the knuckles
		var a := PI * k / 16.0
		palm.append(c + Vector2(cos(a) * s * 0.5, s * 0.15 + sin(a) * s * 0.62))
	palm.append(c + Vector2(-s * 0.52, -s * 0.15))
	palm.append(c + Vector2(s * 0.52, -s * 0.15))
	ci.draw_colored_polygon(palm, col)
	var w := s * 0.22
	for f: Array in [[-0.37, 0.62], [-0.12, 0.85], [0.13, 0.82], [0.37, 0.62]]:   # x, length
		var root := c + Vector2(s * f[0], -s * 0.05)
		var tip := root + Vector2(s * f[0] * 0.12, -s * f[1])
		ci.draw_line(root, tip, col, w, true)
		ci.draw_circle(tip, w * 0.5, col, true, -1.0, true)
	var base := c + Vector2(-s * 0.42, s * 0.3)          # the thumb, out to the side
	var thumb := base + Vector2(-s * 0.42, -s * 0.36)
	ci.draw_line(base, thumb, col, w * 1.05, true)
	ci.draw_circle(thumb, w * 0.52, col, true, -1.0, true)
